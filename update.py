#!/usr/bin/env python3

import argparse
import difflib
import json
import os
import re
import subprocess
import tempfile
from pathlib import Path

import requests
from rich.console import Console
from rich.prompt import Prompt, Confirm
from rich.syntax import Syntax

console = Console()
FLAKE_PATH = Path("flake.nix")
METADATA_BEGIN = 18
METADATA_END = 23


def get_latest_github_tag(repo: str) -> str:
    url = f"https://api.github.com/repos/{repo}/releases/latest"
    response = requests.get(url)
    response.raise_for_status()
    return response.json()["tag_name"].lstrip("v")


def extract_version(field: str, content: str) -> str:
    match = re.search(fr'{field} = "([0-9]+\.[0-9]+\.[0-9]+)"', content)
    return match.group(1) if match else ""


def get_current_versions(flake_path: Path) -> dict:
    content = flake_path.read_text()
    return {
        "version": extract_version("version", content),
        "iosevka": extract_version("iosevkaVersion", content),
        "nerdfont": extract_version("fontPatcherVersion", content),
    }


def run_command(command: str) -> str:
    result = subprocess.run(command, shell=True, capture_output=True, text=True, check=True)
    return result.stdout.strip()


def fetch_hash(url: str, strip_root: bool = True) -> str:
    flag = "" if strip_root else "--no-stripRoot"
    return run_command(
        f"nix-prefetch --option extra-experimental-features flakes fetchzip "
        f"--url {url} {flag} --check-store --silent"
    )


def fetch_npm_deps_hash(version: str) -> str:
    with tempfile.NamedTemporaryFile(delete=False, suffix=".json") as tmp:
        url = f"https://raw.githubusercontent.com/be5invis/Iosevka/v{version}/package-lock.json"
        response = requests.get(url)
        response.raise_for_status()
        tmp.write(response.content)
        tmp_path = tmp.name

    hash_ = run_command(f"prefetch-npm-deps {tmp_path}")
    os.unlink(tmp_path)
    return hash_


def read_metadata_lines(path: Path, start: int, end: int) -> str:
    lines = path.read_text().splitlines()
    return "\n".join(lines[start - 1:end])


def write_updated_flake(path: Path, start: int, end: int, new_metadata: str) -> None:
    lines = path.read_text().splitlines()
    updated = lines[:start - 1] + new_metadata.strip("\n").splitlines() + lines[end:]
    path.write_text("\n".join(updated) + "\n")


def show_diff(original: str, updated: str):
    diff = difflib.unified_diff(
        original.strip("\n").splitlines(),
        updated.strip("\n").splitlines(),
        fromfile="original",
        tofile="updated",
        lineterm=""
    )
    console.print(Syntax("\n".join(diff), "diff", theme="ansi_dark"))


def main():
    parser = argparse.ArgumentParser(description="Prefetch checksums for Iosevka and nerd-fonts")
    parser.add_argument("versions", nargs="*", help="Optional iosevka_version and nerdfontpatcher_version")
    args = parser.parse_args()

    if args.versions and len(args.versions) != 2:
        console.print("[red]Error:[/red] Provide either 0 or 2 arguments.")
        parser.print_help()
        return

    if not args.versions:
        console.print("[gray]Fetching latest versions...[/gray]")
        iosevka_version = get_latest_github_tag("be5invis/Iosevka")
        nerdfont_version = get_latest_github_tag("ryanoasis/nerd-fonts")
    else:
        iosevka_version, nerdfont_version = args.versions

    current = get_current_versions(FLAKE_PATH)

    update_needed = False

    if current["iosevka"] != iosevka_version:
        console.print(f"Iosevka: [red]{current['iosevka']}[/red] → [green]{iosevka_version}[/green]")
        update_needed = True
    else:
        console.print(f"Iosevka: {current['iosevka']} → {iosevka_version}")

    if current["nerdfont"] != nerdfont_version:
        console.print(f"nerd-fonts: [red]{current['nerdfont']}[/red] → [green]{nerdfont_version}[/green]")
        update_needed = True
    else:
        console.print(f"nerd-fonts: {current['nerdfont']} → {nerdfont_version}")

    if not update_needed:
        console.print("[yellow]Nothing to update, exiting without any change to flake.nix[/yellow]")
        return

    console.print("[gray]Calculating hashes...[/gray]")
    iosevka_hash = fetch_hash(f"https://github.com/be5invis/Iosevka/archive/refs/tags/v{iosevka_version}.zip")
    nerdfont_hash = fetch_hash(
        f"https://github.com/ryanoasis/nerd-fonts/releases/download/v{nerdfont_version}/FontPatcher.zip",
        strip_root=False
    )

    console.print("[gray]Calculating dependency (NPM packages) hashes...[/gray]")
    npm_deps_hash = fetch_npm_deps_hash(iosevka_version)

    new_version = Prompt.ask(f"Name the new version (currently at {current['version']})")

    updated_metadata = f"""
      version = "{new_version}";
      iosevkaVersion = "{iosevka_version}";
      hash = "{iosevka_hash}";
      npmDepsHash = "{npm_deps_hash}";
      fontPatcherVersion = "{nerdfont_version}";
      fontPatcherHash = "{nerdfont_hash}";"""

    original_metadata = read_metadata_lines(FLAKE_PATH, METADATA_BEGIN, METADATA_END)

    console.print("[gray]Changes to flake.nix[/gray]")
    show_diff(original_metadata, updated_metadata)

    if Confirm.ask("Apply the changes above to flake.nix?", default=False):
        write_updated_flake(FLAKE_PATH, METADATA_BEGIN, METADATA_END, updated_metadata)
        console.print("[green]Updated flake.nix[/green]")
    else:
        console.print("[yellow]Aborted without any change to flake.nix[/yellow]")


if __name__ == "__main__":
    main()

