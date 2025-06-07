#!/usr/bin/env python3

import subprocess
import tempfile
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional

import requests
import typer
from rich.console import Console
from rich.progress import Progress, SpinnerColumn, TextColumn
from rich.panel import Panel
from rich.text import Text

ERROR_ICON = "󰅙 "
WARNING_ICON = " "
SUCCESS_ICON = "󰗠 "
INFO_ICON = "󰋼 "
HINT_ICON = "󰌵 "
SPINNER_ICON = " "


app = typer.Typer()
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


def process_source_file(
    source_file: Path, output_dir: Path, comment: str, theme_path: Path
) -> bool:
    """Process a single source file to generate preview image."""

    output_file = output_dir / f"{source_file.stem}.png"

    # Create temporary file with same extension
    with tempfile.NamedTemporaryFile(
        mode="w", suffix=source_file.suffix, delete=False
    ) as tmp_file:
        # Write comment and original content
        tmp_file.write(f"{comment}\n")
        tmp_file.write(source_file.read_text())
        tmp_file_path = tmp_file.name

    try:
        # Run silicon command
        cmd = [
            "silicon",
            tmp_file_path,
            "--output",
            str(output_file),
            "--theme",
            str(theme_path),
            "--pad-horiz",
            "0",
            "--pad-vert",
            "0",
            "--background",
            "#fff0",
            "--font",
            "Iosevkata Nerd Font=48",
            "--no-window-controls",
            "--no-round-corner",
        ]

        result = subprocess.run(cmd, capture_output=True, text=True)
        success = result.returncode == 0

        if not success:
            console.print(f"[red]Silicon error: {result.stderr}[/red]")

        return success

    finally:
        # Clean up temp file
        Path(tmp_file_path).unlink(missing_ok=True)


@app.command()
def main(
    source: str = typer.Option(
        "./preview/sources", "--source", help="Directory containing source files"
    ),
    output: str = typer.Option(
        "./preview/images", "--output", help="Directory for output images"
    ),
    theme: str = typer.Option(
        "./preview/themes/Catppuccin Frappe.tmTheme",
        "--theme",
        help="Theme file",
    ),
    version: Optional[str] = typer.Option(
        None,
        "--version",
        help="Iosevkata version string (e.g. v25.06.0) to prepend in comment",
    ),
    comment_string: str = typer.Option(
        "//",
        "--comment-string",
        help="Comment string for the generated comment line",
    ),
):
    """Generate preview images from source files using Silicon."""

    # Validate paths
    source_path = Path(source)
    output_path = Path(output)
    theme_path = Path(theme)

    if not source_path.exists():
        console.print(
            f"[red]{ERROR_ICON}Source directory not found: {source_path}[/red]"
        )
        raise typer.Exit(1)

    if not theme_path.exists():
        console.print(f"[red]{ERROR_ICON}Theme file not found: {theme_path}[/red]")
        raise typer.Exit(1)

    if version is None:
        version = get_latest_github_release("ningw42/Iosevkata")

    # Create output directory
    output_path.mkdir(parents=True, exist_ok=True)

    # Generate timestamp
    timestamp = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")

    # Assemble the comment to prepend
    comment = f"{comment_string} Generated at {timestamp} with Iosevkata Nerd Font v{version}"

    # Display info
    info_text = Text()
    info_text.append("Source: ", style="bold")
    info_text.append(f"{source_path}\n")
    info_text.append("Output: ", style="bold")
    info_text.append(f"{output_path}\n")
    info_text.append("Theme: ", style="bold")
    info_text.append(f"{theme_path}\n")
    info_text.append("Version: ", style="bold")
    info_text.append(f"{version}\n")
    info_text.append("Comment: ", style="bold")
    info_text.append(f"{comment}")

    console.print(Panel(info_text, title="Configuration", border_style="green"))

    # Get source files
    source_files = [f for f in source_path.iterdir() if f.is_file()]

    if not source_files:
        console.print(
            f"[yellow]{WARNING_ICON}No source files found in {source_path}[/yellow]"
        )
        return

    # Process files with progress bar
    successful = 0
    failed = 0

    with Progress(
        SpinnerColumn(),
        TextColumn("[progress.description]{task.description}"),
        console=console,
    ) as progress:

        for source_file in source_files:
            task = progress.add_task(f"Processing {source_file.name}...", total=None)

            console.print(f"\n[bold]Processing:[/bold] {source_file.name}")
            output_file = output_path / f"{source_file.stem}.png"
            console.print(f"  [dim]Output:[/dim] {output_file}")
            console.print(f"  [dim]Adding comment:[/dim] {comment}")

            success = process_source_file(source_file, output_path, comment, theme_path)

            if success:
                console.print(f"[green]{SUCCESS_ICON}Success[/green]")
                successful += 1
            else:
                console.print(f"[red]{ERROR_ICON}Failed[/red]")
                failed += 1

            progress.remove_task(task)

    # Print summary
    summary_text = Text()
    summary_text.append(f"Processed {len(source_files)} files: ")
    summary_text.append(f"{successful} successful", style="green")
    summary_text.append(", ")
    summary_text.append(f"{failed} failed", style="red" if failed > 0 else "dim")

    console.print(f"\n{summary_text}")


if __name__ == "__main__":
    app()
