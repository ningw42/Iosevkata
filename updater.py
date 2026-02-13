#!/usr/bin/env python3

import difflib
import os
import re
import subprocess
import tempfile
from pathlib import Path
from typing import Dict, List, Optional
from datetime import datetime, timezone

import requests
from rich import box
import typer
from rich.console import Console
from rich.prompt import Confirm, Prompt
from rich.syntax import Syntax
from rich.table import Table
from typing_extensions import Annotated

# --- Configuration ---
FLAKE_NIX_PATH = Path("flake.nix")
VERSIONS_MD_PATH = Path("versions.md")
# Lines in flake.nix where metadata for versions/hashes is defined.
# These are 1-based and inclusive.
FLAKE_METADATA_START_LINE = 20
FLAKE_METADATA_END_LINE = 27
FLAKE_METADATA_INDENT = "      "  # 6 spaces
ERROR_ICON = "󰅙 "
WARNING_ICON = " "
SUCCESS_ICON = "󰗠 "
INFO_ICON = "󰋼 "
HINT_ICON = "󰌵 "
SPINNER_ICON = " "


console = Console()


def get_latest_github_release(github_repo: str) -> str:
    repo_url = f"https://api.github.com/repos/{github_repo}/releases/latest"
    console.print(
        f"[dim]{SPINNER_ICON}Fetching latest tag for [blue][link={repo_url}]{github_repo}[/link][/blue][white]...[/white][/dim]"
    )
    try:
        response = requests.get(repo_url, timeout=10)
        response.raise_for_status()
        tag = response.json()["tag_name"]
        return tag.lstrip("v")
    except requests.Timeout:
        console.print(
            f"[red]{ERROR_ICON}Timeout while fetching tag for {github_repo} from {repo_url}[/red]"
        )
        raise typer.Exit(1)
    except requests.RequestException as e:
        console.print(
            f"[red]{ERROR_ICON}Error fetching tag for {github_repo}: {e}[/red]"
        )
        raise typer.Exit(1)
    except KeyError:
        console.print(
            f"[red]{ERROR_ICON}Error: 'tag_name' not found in response for {github_repo}. Response: {response.text}[/red]"
        )
        raise typer.Exit(1)


def get_next_version(current_version: str, utc_now: datetime) -> str:
    current_version_segments = current_version.split(".")
    current_minor = int(current_version_segments[-1])
    current_year_month = ".".join(current_version_segments[0:2])
    year_month = utc_now.strftime("%y.%m")
    minor = 0
    if current_year_month == year_month:
        minor = current_minor + 1
    return f"{year_month}.{minor}"


def extract_metadata(nix_content: str) -> Dict[str, Optional[str]]:
    """
    Extract specific values from a Nix configuration snippet.

    Args:
        nix_content (str): The Nix configuration content as a string

    Returns:
        dict: Dictionary containing extracted values with keys:
              - version
              - iosevka.version
              - iosevka.hash
              - iosevka.npm_deps_hash
    """
    result = {}

    # Extract main version
    version_match = re.search(r'version\s*=\s*"([^"]+)"', nix_content)
    if version_match:
        result["version"] = version_match.group(1)

    # Extract iosevka section values
    iosevka_section = re.search(r"iosevka\s*=\s*{([^}]+)}", nix_content, re.DOTALL)
    if iosevka_section:
        iosevka_content = iosevka_section.group(1)

        # Extract iosevka version
        iosevka_version = re.search(r'version\s*=\s*"([^"]+)"', iosevka_content)
        if iosevka_version:
            result["iosevka.version"] = iosevka_version.group(1)

        # Extract iosevka hash
        iosevka_hash = re.search(r'hash\s*=\s*"([^"]+)"', iosevka_content)
        if iosevka_hash:
            result["iosevka.hash"] = iosevka_hash.group(1)

        # Extract iosevka npmDepsHash
        npm_deps_hash = re.search(r'npmDepsHash\s*=\s*"([^"]+)"', iosevka_content)
        if npm_deps_hash:
            result["iosevka.npm_deps_hash"] = npm_deps_hash.group(1)

    return result


def extract_value(regex: str, flake_content: str) -> Optional[str]:
    """Extracts single value by key."""
    match = re.search(regex, flake_content)
    return match.group(1) if match else None


def extract_version(key: str, flake_content: str) -> Optional[str]:
    """Extracts a version string (e.g., "X.Y.Z" or "X.Y.Z-suffix") for a given key."""
    return extract_value(
        rf'{key}\s*=\s*"([0-9]+\.[0-9]+\.[0-9]+(?:-[a-zA-Z0-9.]+)?)"\s*;',
        flake_content,
    )


def extract_sri_hash(key: str, flake_content: str) -> Optional[str]:
    """Extracts a SRI hash string for a given key."""
    return extract_value(
        rf'{key}\s*=\s*"(sha256-[A-Za-z0-9+\/]{{43}}={{0,2}})"\s*;',
        flake_content,
    )


def get_nerdfonts_version(flake_path: Path) -> str:
    """Extracts the nerd-fonts version from the nerd-font-patcher input URL tag in flake.nix."""
    with open(flake_path, "r") as flake:
        content = flake.read()
    match = re.search(
        r'nerd-font-patcher\.url\s*=\s*"github:ningw42/nerd-font-patcher/v([^"]+)"',
        content,
    )
    if not match:
        console.print(
            f"[red]{ERROR_ICON}Could not extract nerd-font-patcher version from {flake_path}. "
            f"Expected input URL format: github:ningw42/nerd-font-patcher/vX.Y.Z[/red]"
        )
        raise typer.Exit(1)
    return match.group(1)


def get_current_metadata(flake_path: Path) -> Dict[str, Optional[str]]:
    if not flake_path.exists():
        console.print(f"[red]{ERROR_ICON}Error: {flake_path} not found.[/red]")
        raise typer.Exit(1)
    with open(flake_path, "r") as flake:
        metadata_lines = flake.readlines()[
            FLAKE_METADATA_START_LINE - 1 : FLAKE_METADATA_END_LINE
        ]
        metadata_content = "".join(metadata_lines)
        metadata = extract_metadata(metadata_content)
        metadata["raw"] = metadata_content
        return metadata


def get_highlighted_metadata_row(
    name: str, current_value: str, target_value: str
) -> tuple[str, str, str]:
    if current_value == target_value:
        return (name, f"[dim]{current_value}[/dim]", f"[dim]{target_value}[/dim]")
    else:
        return (
            name,
            f"[red]{current_value}[/red]",
            f"[green]{target_value}[/green]",
        )


def run_nix_command(command_parts: List[str]) -> str:
    """Runs a Nix command and returns its stripped stdout."""
    try:
        # For debugging: console.print(f"[dim]$ {' '.join(command_parts)}[/dim]")
        result = subprocess.run(
            command_parts, capture_output=True, text=True, check=True, shell=False
        )
        return result.stdout.strip()
    except subprocess.CalledProcessError as e:
        console.print(
            f"[red]{ERROR_ICON}Error running command: {' '.join(command_parts)}[/red]"
        )
        if e.stdout:
            console.print(f"[bold red]Stdout:[/bold red]\n{e.stdout}")
        if e.stderr:
            console.print(f"[bold red]Stderr:[/bold red]\n{e.stderr}")
        raise typer.Exit(1)
    except FileNotFoundError:
        console.print(
            f"[red]{ERROR_ICON}Error: Command '{command_parts[0]}' not found. Is it installed and in PATH?[/red]"
        )
        raise typer.Exit(1)


def fetch_sri_hash_with_nix_prefetch(
    name: str, version: str, url: str, strip_root: bool
) -> str:
    """
    Fetches SRI hash for an archive's content using nix-prefetch fetchzip.
    Reproduces the behavior of the original script's nix-prefetch call.
    Returns an SRI hash string (e.g., "sha256-Abc...=").
    """
    console.print(
        f"[dim]{SPINNER_ICON}Calculating SRI hash for [link={url}][blue]{name}[/blue][/link] [yellow not bold]v{version}[/yellow not bold] (strip_root={strip_root}) using nix-prefetch fetchzip[white]...[/white][/dim]"
    )
    command_parts = [
        "nix-prefetch",
        "--option",
        "extra-experimental-features",
        "flakes",  # As per original script
        "fetchzip",
        "--url",
        url,
        "--check-store",  # As per original script
        "--silent",  # As per original script
    ]
    if not strip_root:
        command_parts.append("--no-stripRoot")

    sri_hash = run_nix_command(command_parts)
    return sri_hash


def fetch_sri_hash_with_nix_prefetch_url(
    name: str, version: str, url: str, strip_root: bool
) -> str:
    """
    Fetches SRI hash for an archive's content using nix-prefetch-url.
    Reproduces the behavior of the original script's nix-prefetch call.
    Returns an SRI hash string (e.g., "sha256-Abc...=").
    """
    console.print(
        f"[dim]{SPINNER_ICON}Calculating SRI hash for [link={url}][blue]{name}[/blue][/link] [yellow not bold]v{version}[/yellow not bold] (strip_root={strip_root}) using nix-prefetch-url and nix hash convert[white]...[/white][/dim]"
    )
    command_parts = [
        "nix-prefetch-url",
        "--unpack",
        url,
    ]

    sha_hash = run_nix_command(command_parts)
    return run_nix_command(["nix", "hash", "convert", f"sha256:{sha_hash}"])


def fetch_npm_deps_hash_for_iosevka(iosevka_version: str) -> str:
    """Fetches Iosevka's package-lock.json and calculates its prefetch hash using prefetch-npm-deps."""
    url = f"https://raw.githubusercontent.com/be5invis/Iosevka/v{iosevka_version}/package-lock.json"
    console.print(
        f"[dim]{SPINNER_ICON}Calculating NPM dependencies hash for [link={url}][blue]be5invis/Iosevka[/blue][/link] [yellow not bold]v{iosevka_version}[/yellow not bold] using prefetch-npm-deps[white]...[/white][/dim]"
    )

    try:
        response = requests.get(url, timeout=10)
        response.raise_for_status()
        package_lock_content = response.content
    except requests.Timeout:
        console.print(f"[red]{ERROR_ICON}Error: Timeout while fetching {url}[/red]")
        raise typer.Exit(1)
    except requests.RequestException as e:
        console.print(
            f"[red]{ERROR_ICON}Error fetching package-lock.json for Iosevka v{iosevka_version}: {e}[/red]"
        )
        raise typer.Exit(1)

    tmp_file_path = None
    try:
        with tempfile.NamedTemporaryFile(
            mode="wb", delete=False, suffix=".json"
        ) as tmp_file:
            tmp_file.write(package_lock_content)
            tmp_file_path = tmp_file.name
        sri_hash = run_nix_command(["prefetch-npm-deps", tmp_file_path])
    finally:
        if tmp_file_path and os.path.exists(tmp_file_path):
            os.unlink(tmp_file_path)
    return sri_hash


def show_diff(old_content: str, new_content: str, from_file: str, to_file: str):
    diff_lines = difflib.unified_diff(
        old_content.strip("\n").splitlines(),
        new_content.strip("\n").splitlines(),
        fromfile=from_file,
        tofile=to_file,
        lineterm="",
    )
    console.print(
        Syntax(
            "\n".join(diff_lines),
            "diff",
            theme="ansi_dark",
            line_numbers=False,
            background_color="default",
        )
    )


def update_flake_metadata(metadata_content: str):
    with open(FLAKE_NIX_PATH, "r") as flake:
        lines = flake.readlines()
    with open(FLAKE_NIX_PATH, "w") as flake:
        lines[FLAKE_METADATA_START_LINE - 1 : FLAKE_METADATA_END_LINE] = (
            metadata_content.splitlines(keepends=True)
        )
        flake.writelines(lines)


def patch_flake(
    current_metadata_str: str,
    target_iosevkata_version: str,
    target_iosevka_version: str,
    target_iosevka_hash: str,
    target_iosevka_npm_deps_hash: str,
    no_confirm: bool = False,
):
    target_metadata_str = f"""\
{FLAKE_METADATA_INDENT}version = "{target_iosevkata_version}";
{FLAKE_METADATA_INDENT}dependencies = {{
{FLAKE_METADATA_INDENT}  iosevka = {{
{FLAKE_METADATA_INDENT}    version = "{target_iosevka_version}";
{FLAKE_METADATA_INDENT}    hash = "{target_iosevka_hash}";
{FLAKE_METADATA_INDENT}    npmDepsHash = "{target_iosevka_npm_deps_hash}";
{FLAKE_METADATA_INDENT}  }};
{FLAKE_METADATA_INDENT}}};
"""
    show_diff(
        current_metadata_str,
        target_metadata_str,
        "current flake.nix",
        "target flake.nix",
    )
    if not no_confirm and not Confirm.ask(
        "Apply these changes to flake.nix?", default=True
    ):
        console.print(
            f"[yellow]{WARNING_ICON}Aborted. flake.nix wasn't changed.[/yellow]"
        )
        raise typer.Exit()
    update_flake_metadata(target_metadata_str)
    console.print(f"\n[green]{SUCCESS_ICON}Successfully updated flake.nix.[/green]")


def patch_versions(
    iosevkata_version: str,
    iosevka_version: str,
    nerdfonts_version: str,
    no_confirm: bool = False,
):
    with open(VERSIONS_MD_PATH, "r") as versions:
        versions_lines = versions.readlines()
    current_versions_str = "".join(versions_lines)
    line_to_insert = (
        f"| v{iosevkata_version}  | v{iosevka_version} | v{nerdfonts_version}     |\n"
    )
    versions_lines.insert(2, line_to_insert)
    target_versions_str = "".join(versions_lines)
    show_diff(
        current_versions_str,
        target_versions_str,
        "current versions.md",
        "target versions.md",
    )
    if not no_confirm and not Confirm.ask(
        "Apply these changes to versions.md?", default=True
    ):
        console.print(
            f"[yellow]{WARNING_ICON}Aborted. versions.md wasn't changed.[/yellow]"
        )
        raise typer.Exit()
    with open(VERSIONS_MD_PATH, "w") as versions:
        versions.writelines(versions_lines)
        console.print(
            f"\n[green]{SUCCESS_ICON}Successfully updated versions.md.[/green]"
        )


def main(
    target_iosevka_version: Annotated[
        Optional[str],
        typer.Option(
            help="Iosevka version (e.g. 33.0.0). Fetches latest if not provided."
        ),
    ] = None,
    no_confirm: Annotated[
        bool,
        typer.Option(
            help="Skip all interactive prompts, auto-accepting defaults. Useful for CI."
        ),
    ] = False,
):
    # figure out target dependency versions
    if not target_iosevka_version:
        target_iosevka_version = get_latest_github_release("be5invis/Iosevka")

    # nerd-fonts version is determined by the nerd-font-patcher flake input tag
    nerdfonts_version = get_nerdfonts_version(FLAKE_NIX_PATH)

    # fetch target dependency hashes
    target_iosevka_hash = fetch_sri_hash_with_nix_prefetch_url(
        "be5invis/Iosevka",
        target_iosevka_version,
        f"https://github.com/be5invis/Iosevka/archive/refs/tags/v{target_iosevka_version}.zip",
        strip_root=True,
    )
    target_iosevka_npm_deps_hash = fetch_npm_deps_hash_for_iosevka(
        target_iosevka_version
    )

    # extract current metadata from flake.nix
    current_metadata = get_current_metadata(FLAKE_NIX_PATH)
    if (
        not all(current_metadata.values())
        or current_metadata["version"] is None
        or current_metadata["iosevka.version"] is None
        or current_metadata["iosevka.hash"] is None
        or current_metadata["iosevka.npm_deps_hash"] is None
        or current_metadata["raw"] is None
    ):
        console.print(
            f"[red]{ERROR_ICON}Could not extract all required current versions from {FLAKE_NIX_PATH}. Check metadata format or line number constants.[/red]"
        )
        console.print(f"Extracted: {current_metadata}")
        raise typer.Exit(1)

    current_iosevkata_version = current_metadata["version"]
    current_iosevka_version = current_metadata["iosevka.version"]
    current_iosevka_hash = current_metadata["iosevka.hash"]
    current_iosevka_npm_deps_hash = current_metadata["iosevka.npm_deps_hash"]

    # print dependency metadata table
    dependency_metadata_table = Table(
        "Dependency", "Current", "Target", title="Dependency Metadata", box=box.ROUNDED
    )
    dependency_metadata_table.add_row(
        *get_highlighted_metadata_row(
            "be5invis/Iosevka", current_iosevka_version, target_iosevka_version
        )
    )
    dependency_metadata_table.add_row(
        *get_highlighted_metadata_row(
            "  Hash", current_iosevka_hash, target_iosevka_hash
        )
    )
    dependency_metadata_table.add_row(
        *get_highlighted_metadata_row(
            "  NPM Deps Hash",
            current_iosevka_npm_deps_hash,
            target_iosevka_npm_deps_hash,
        )
    )
    console.print(dependency_metadata_table)

    # check if we need an update
    # we need to check hashes even if the versions are equal, because sometimes, people update artifacts without bumping version
    if (
        current_iosevka_version == target_iosevka_version
        and current_iosevka_hash == target_iosevka_hash
        and current_iosevka_npm_deps_hash == target_iosevka_npm_deps_hash
    ):
        console.print(
            f"\n[green]{SUCCESS_ICON}All versions and hashes are already up-to-date. Nothing to do.[/green]"
        )
        raise typer.Exit()

    # ask for the target Iosevkata version
    default_version = get_next_version(
        current_iosevkata_version, datetime.now(timezone.utc)
    )
    if no_confirm:
        target_iosevkata_version = default_version
        console.print(
            f"{INFO_ICON}Auto-accepting version [bold cyan]{target_iosevkata_version}[/bold cyan] (--no-confirm)"
        )
    else:
        target_iosevkata_version = Prompt.ask(
            f"{HINT_ICON}Enter a new version for Iosevkata (currently [bold cyan]{current_iosevkata_version}[/bold cyan])",
            default=default_version,
        )

    # edit flake.nix
    patch_flake(
        current_metadata["raw"],
        target_iosevkata_version,
        target_iosevka_version,
        target_iosevka_hash,
        target_iosevka_npm_deps_hash,
        no_confirm,
    )

    # edit versions.md
    patch_versions(
        target_iosevkata_version, target_iosevka_version, nerdfonts_version, no_confirm
    )


if __name__ == "__main__":
    typer.run(main)
