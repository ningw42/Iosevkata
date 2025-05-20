#!/usr/bin/env python3

import difflib
import os
import re
import subprocess
import tempfile
from pathlib import Path
from typing import Dict, List, Optional

import requests
import typer
from rich.console import Console
from rich.panel import Panel
from rich.prompt import Confirm, Prompt
from rich.syntax import Syntax
from typing_extensions import Annotated

# --- Configuration ---
FLAKE_NIX_PATH = Path("flake.nix")
VERSIONS_MD_PATH = Path("versions.md")
# Lines in flake.nix where metadata for versions/hashes is defined.
# These are 1-based and inclusive.
FLAKE_METADATA_START_LINE = 18
FLAKE_METADATA_END_LINE = 23

# Rich console
console = Console()
app = typer.Typer(
    add_completion=False,
    pretty_exceptions_show_locals=False,
    rich_markup_mode="markdown",
)

# --- Helper Functions ---


def get_latest_github_tag(owner_repo: str) -> str:
    """Fetches the latest release tag from a GitHub repository."""
    console.print(
        f":hourglass_not_done: Fetching latest tag for [cyan]{owner_repo}[/cyan]..."
    )
    try:
        api_url = f"https://api.github.com/repos/{owner_repo}/releases/latest"
        response = requests.get(api_url, timeout=10)
        response.raise_for_status()
        tag = response.json()["tag_name"]
        return tag.lstrip("v")
    except requests.Timeout:
        console.print(
            f"[red]Error: Timeout while fetching tag for {owner_repo} from {api_url}[/red]"
        )
        raise typer.Exit(1)
    except requests.RequestException as e:
        console.print(f"[red]Error fetching tag for {owner_repo}: {e}[/red]")
        raise typer.Exit(1)
    except KeyError:
        console.print(
            f"[red]Error: 'tag_name' not found in response for {owner_repo}. Response: {response.text}[/red]"
        )
        raise typer.Exit(1)


def extract_version_from_flake(field_name: str, flake_content: str) -> Optional[str]:
    """Extracts a version string (e.g., "X.Y.Z" or "X.Y.Z-suffix") for a given field."""
    match = re.search(
        rf'{field_name}\s*=\s*"([0-9]+\.[0-9]+\.[0-9]+(?:-[a-zA-Z0-9.]+)?)"\s*;',
        flake_content,
    )
    return match.group(1) if match else None


def get_current_versions_from_flake(flake_path: Path) -> Dict[str, Optional[str]]:
    """Reads flake.nix and extracts current versions."""
    if not flake_path.exists():
        console.print(f"[red]Error: {flake_path} not found.[/red]")
        raise typer.Exit(1)
    content = flake_path.read_text()
    return {
        "iosevkata": extract_version_from_flake("version", content),
        "iosevka_lib": extract_version_from_flake("iosevkaVersion", content),
        "nerdfont_patcher": extract_version_from_flake("fontPatcherVersion", content),
    }


def run_nix_command(command_parts: List[str]) -> str:
    """Runs a Nix command and returns its stripped stdout."""
    try:
        # For debugging: console.print(f"[dim]$ {' '.join(command_parts)}[/dim]")
        result = subprocess.run(
            command_parts, capture_output=True, text=True, check=True, shell=False
        )
        return result.stdout.strip()
    except subprocess.CalledProcessError as e:
        console.print(f"[red]Error running command: {' '.join(command_parts)}[/red]")
        if e.stdout:
            console.print(f"[bold red]Stdout:[/bold red]\n{e.stdout}")
        if e.stderr:
            console.print(f"[bold red]Stderr:[/bold red]\n{e.stderr}")
        raise typer.Exit(1)
    except FileNotFoundError:
        console.print(
            f"[red]Error: Command '{command_parts[0]}' not found. Is it installed and in PATH?[/red]"
        )
        raise typer.Exit(1)


def fetch_sri_hash_with_nix_prefetch(url: str, strip_root: bool) -> str:
    """
    Fetches SRI hash for an archive's content using nix-prefetch fetchzip.
    Reproduces the behavior of the original script's nix-prefetch call.
    Returns an SRI hash string (e.g., "sha256-Abc...=").
    """
    console.print(
        f":package: Calculating SRI hash for [link={url}]{url}[/link] (strip_root={strip_root}) using nix-prefetch fetchzip..."
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


def fetch_npm_deps_hash_for_iosevka(iosevka_version: str) -> str:
    """Fetches Iosevka's package-lock.json and calculates its prefetch hash using prefetch-npm-deps."""
    console.print(
        f":floppy_disk: Calculating NPM dependencies hash for Iosevka v{iosevka_version}..."
    )
    url = f"https://raw.githubusercontent.com/be5invis/Iosevka/v{iosevka_version}/package-lock.json"

    try:
        response = requests.get(url, timeout=10)
        response.raise_for_status()
        package_lock_content = response.content
    except requests.Timeout:
        console.print(f"[red]Error: Timeout while fetching {url}[/red]")
        raise typer.Exit(1)
    except requests.RequestException as e:
        console.print(
            f"[red]Error fetching package-lock.json for Iosevka v{iosevka_version}: {e}[/red]"
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


def generate_diff(
    old_content: str, new_content: str, from_file: str, to_file: str
) -> str:
    """Generates a unified diff string."""
    diff_lines = difflib.unified_diff(
        old_content.strip("\n").splitlines(),
        new_content.strip("\n").splitlines(),
        fromfile=from_file,
        tofile=to_file,
        lineterm="",
    )
    return "\n".join(diff_lines)


def get_flake_metadata_block(
    flake_content: str, start_line_num: int, end_line_num: int
) -> str:
    """Extracts the specified block of lines from flake_content."""
    lines = flake_content.splitlines()
    block_lines = lines[start_line_num - 1 : end_line_num]
    return "\n".join(block_lines)


def create_updated_full_content(
    original_full_content: str,
    start_line_num: int,
    end_line_num: int,
    new_block_content: str,
) -> str:
    """Replaces a block of lines in content string and returns new full content string."""
    lines = original_full_content.splitlines()
    start_idx = start_line_num - 1
    lines_after_block_starts_at_idx = end_line_num
    new_block_lines = new_block_content.strip("\n").splitlines()
    updated_lines = (
        lines[:start_idx] + new_block_lines + lines[lines_after_block_starts_at_idx:]
    )
    return "\n".join(updated_lines).strip() + "\n"


def generate_versions_md_update(
    current_md_content: str,
    iosevkata_version: str,
    iosevka_lib_version: str,
    nerdfont_patcher_version: str,
) -> str:
    """Inserts a new version row into the versions.md markdown table content."""
    new_row = f"| v{iosevkata_version:<8} | v{iosevka_lib_version:<6} | v{nerdfont_patcher_version:<9} |"
    lines = current_md_content.splitlines()
    try:
        separator_index = next(
            i
            for i, line in enumerate(lines)
            if line.strip().startswith("|") and "---" in line
        )
    except StopIteration:
        console.print(
            "[red]Error: Markdown table in versions.md is missing or has an invalid format (header separator not found).[/red]"
        )
        raise typer.Exit(1)
    insert_index = separator_index + 1
    new_lines = lines[:insert_index] + [new_row] + lines[insert_index:]
    return "\n".join(new_lines).strip() + "\n"


# --- Main CLI Command ---


@app.command()
def main(
    iosevka_version_arg: Annotated[
        Optional[str],
        typer.Argument(
            help="Specific Iosevka library version (e.g., 29.0.0). Fetches latest if not provided."
        ),
    ] = None,
    nerdfont_patcher_version_arg: Annotated[
        Optional[str],
        typer.Argument(
            help="Specific Nerd Fonts Patcher version (e.g., 3.2.1). Fetches latest if not provided."
        ),
    ] = None,
):
    """Updates Iosevka and Nerd Font patcher versions and hashes in flake.nix and versions.md."""

    console.rule("[bold blue]Iosevkata Updater[/bold blue]")

    if iosevka_version_arg and nerdfont_patcher_version_arg:
        target_iosevka_lib_version = iosevka_version_arg
        target_nerdfont_patcher_version = nerdfont_patcher_version_arg
        console.print(
            f":dart: Using provided versions: Iosevka lib [yellow]v{target_iosevka_lib_version}[/yellow], Nerd Font Patcher [yellow]v{target_nerdfont_patcher_version}[/yellow]"
        )
    elif iosevka_version_arg or nerdfont_patcher_version_arg:
        console.print(
            "[red]Error: Please provide both Iosevka and Nerd Font versions, or neither (to fetch latest).[/red]"
        )
        raise typer.Exit(1)
    else:
        target_iosevka_lib_version = get_latest_github_tag("be5invis/Iosevka")
        target_nerdfont_patcher_version = get_latest_github_tag("ryanoasis/nerd-fonts")
        console.print(
            f":sparkles: Latest versions determined: Iosevka lib [green]v{target_iosevka_lib_version}[/green], Nerd Font Patcher [green]v{target_nerdfont_patcher_version}[/green]"
        )

    console.print(
        f":page_facing_up: Reading current versions from `[file://{FLAKE_NIX_PATH.resolve()}]`..."
    )
    current_versions = get_current_versions_from_flake(FLAKE_NIX_PATH)

    if (
        not all(current_versions.values())
        or current_versions["iosevkata"] is None
        or current_versions["iosevka_lib"] is None
        or current_versions["nerdfont_patcher"] is None
    ):
        console.print(
            f"[red]Error: Could not extract all required current versions from {FLAKE_NIX_PATH}. Check metadata format or line number constants.[/red]"
        )
        console.print(f"Extracted: {current_versions}")
        raise typer.Exit(1)

    console.print(
        Panel(
            f"Iosevkata  : [dim]v{current_versions['iosevkata']}[/dim]\n"
            f"Iosevka    : [cyan]v{current_versions['iosevka_lib']}[/cyan] -> [yellow]v{target_iosevka_lib_version}[/yellow]\n"
            f"nerd-fonts : [cyan]v{current_versions['nerdfont_patcher']}[/cyan] -> [yellow]v{target_nerdfont_patcher_version}[/yellow]",
            title="Version Comparison",
            expand=False,
            border_style="blue",
        )
    )

    if (
        current_versions["iosevka_lib"] == target_iosevka_lib_version
        and current_versions["nerdfont_patcher"] == target_nerdfont_patcher_version
    ):
        console.print(
            "\n[green]:heavy_check_mark: All versions are already up-to-date. Nothing to do.[/green]"
        )
        raise typer.Exit()

    new_iosevkata_version = Prompt.ask(
        f":label: Enter new version for your custom font package (currently [bold cyan]v{current_versions['iosevkata']}[/bold cyan])",
        default=current_versions["iosevkata"],
    )

    console.rule("[bold]Calculating Hashes[/bold]")
    iosevka_lib_hash = fetch_sri_hash_with_nix_prefetch(
        f"https://github.com/be5invis/Iosevka/archive/refs/tags/v{target_iosevka_lib_version}.zip",
        strip_root=True,
    )
    nerdfont_patcher_hash = fetch_sri_hash_with_nix_prefetch(
        f"https://github.com/ryanoasis/nerd-fonts/releases/download/v{target_nerdfont_patcher_version}/FontPatcher.zip",
        strip_root=False,
    )
    iosevka_npm_deps_hash = fetch_npm_deps_hash_for_iosevka(target_iosevka_lib_version)

    console.print(f"  :key: Iosevka Hash          : [green]{iosevka_lib_hash}[/green]")
    console.print(
        f"  :key: Iosevka NPM Deps Hash : [green]{iosevka_npm_deps_hash}[/green]"
    )
    console.print(
        f"  :key: nerd-fonts Hash       : [green]{nerdfont_patcher_hash}[/green]"
    )

    flake_metadata_indent = "      "
    new_flake_metadata_block_str = f"""\
{flake_metadata_indent}version = "{new_iosevkata_version}";
{flake_metadata_indent}iosevkaVersion = "{target_iosevka_lib_version}";
{flake_metadata_indent}hash = "{iosevka_lib_hash}";
{flake_metadata_indent}npmDepsHash = "{iosevka_npm_deps_hash}";
{flake_metadata_indent}fontPatcherVersion = "{target_nerdfont_patcher_version}";
{flake_metadata_indent}fontPatcherHash = "{nerdfont_patcher_hash}";"""

    original_flake_full_content = FLAKE_NIX_PATH.read_text()
    original_flake_metadata_block_str = get_flake_metadata_block(
        original_flake_full_content, FLAKE_METADATA_START_LINE, FLAKE_METADATA_END_LINE
    )
    new_flake_full_content = create_updated_full_content(
        original_flake_full_content,
        FLAKE_METADATA_START_LINE,
        FLAKE_METADATA_END_LINE,
        new_flake_metadata_block_str,
    )

    original_versions_md_content = None
    new_versions_md_content = None
    if not VERSIONS_MD_PATH.exists():
        console.print(
            f"[yellow]Warning: {VERSIONS_MD_PATH} not found. Skipping update for this file.[/yellow]"
        )
    else:
        original_versions_md_content = VERSIONS_MD_PATH.read_text()
        new_versions_md_content = generate_versions_md_update(
            original_versions_md_content,
            new_iosevkata_version,
            target_iosevka_lib_version,
            target_nerdfont_patcher_version,
        )

    console.rule("[bold]Proposed Changes[/bold]")
    console.print(
        Panel(
            f"Changes for `[file://{FLAKE_NIX_PATH.resolve()}]` (metadata block)",
            expand=False,
            border_style="magenta",
        )
    )
    flake_diff = generate_diff(
        original_flake_metadata_block_str,
        new_flake_metadata_block_str,
        "flake.nix (original_metadata)",
        "flake.nix (new_metadata)",
    )
    console.print(
        Syntax(
            flake_diff,
            "diff",
            theme="ansi_dark",
            line_numbers=False,
            background_color="default",
        )
    )

    if new_versions_md_content and original_versions_md_content:
        console.print(
            Panel(
                f"Changes for `[file://{VERSIONS_MD_PATH.resolve()}]`",
                expand=False,
                border_style="magenta",
            )
        )
        versions_md_diff = generate_diff(
            original_versions_md_content,
            new_versions_md_content,
            str(VERSIONS_MD_PATH),
            str(VERSIONS_MD_PATH) + " (new)",
        )
        console.print(
            Syntax(
                versions_md_diff,
                "diff",
                theme="ansi_dark",
                line_numbers=False,
                background_color="default",
            )
        )

    console.print("")
    confirm_message = (
        f":rocket: Apply these changes to `[file://{FLAKE_NIX_PATH.resolve()}]`"
    )
    if new_versions_md_content:
        confirm_message += f" and `[file://{VERSIONS_MD_PATH.resolve()}]`"
    confirm_message += "?"

    if not Confirm.ask(confirm_message, default=False):
        console.print("[yellow]Aborted. No files were changed.[/yellow]")
        raise typer.Exit()

    FLAKE_NIX_PATH.write_text(new_flake_full_content)
    console.print(f"[green]:heavy_check_mark: Updated {FLAKE_NIX_PATH}[/green]")

    if new_versions_md_content:
        VERSIONS_MD_PATH.write_text(new_versions_md_content)
        console.print(f"[green]:heavy_check_mark: Updated {VERSIONS_MD_PATH}[/green]")

    console.print("\n[bold green]Successfully updated versions![/bold green]")


if __name__ == "__main__":
    app()
