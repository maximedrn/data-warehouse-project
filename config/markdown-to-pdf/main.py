#!/usr/bin/env python3
"""Convert a Markdown file to PDF."""

from __future__ import annotations

from argparse import ArgumentParser, Namespace
from logging import INFO, Logger, basicConfig, getLogger
from pathlib import Path
from re import Match, sub
from shutil import copy, move, rmtree
from tempfile import mkdtemp
from typing import cast

from pypandoc import convert_text, get_pandoc_path, download_pandoc  # type: ignore[import-untyped]
from pytinytex import CompileResult, compile as compile_tinytex, download_tinytex  # type: ignore[import-untyped]

basicConfig(level=INFO, format="%(asctime)s %(levelname)s %(message)s")
logger: Logger = getLogger(__name__)


class Arguments(Namespace):
    """Typed CLI arguments."""

    input: Path
    output: Path
    cls: Path


def parse_args() -> Arguments:
    """Parse CLI arguments.

    :returns: Parsed arguments.
    :rtype: Arguments
    """
    parser = ArgumentParser(description="Convert Markdown to PDF via pypandoc + LaTeX.")
    parser.add_argument("--input", type=Path, help="Input Markdown file")
    parser.add_argument(
        "--output",
        nargs="?",
        type=Path,
        help="Output PDF path.",
    )
    parser.add_argument(
        "--cls",
        type=Path,
        help="Path to .cls file.",
    )
    return parser.parse_args(namespace=Arguments())


def compile_pdf(tex_path: Path, output_pdf: Path, working_directory: Path) -> None:
    """Compile `.tex` to PDF using PyTinyTeX.

    :param Path tex_path: Path to the .tex file to compile.
    :param Path output_pdf: Desired output PDF path.
    :param Path working_directory: Directory to use for compilation.
    :returns: None
    :rtype: None
    """
    working_directory.mkdir(parents=True, exist_ok=True)
    download_tinytex(variation=2, download_folder=".temp")

    try:
        result: CompileResult = compile_tinytex(  # type: ignore[no-any-unimported,misc]
            str(tex_path),
            output_dir=str(working_directory),
            auto_install=True,
        )
        if result.pdf_path is None:  # type: ignore[misc]
            raise RuntimeError("Invalid PDF path result.")
    except Exception as exception:
        raise RuntimeError("LaTeX compilation failed.") from exception

    generated_pdf: Path = Path(result.pdf_path)  # type: ignore[misc]
    if not generated_pdf.exists():
        raise RuntimeError("Compilation succeeded but PDF not found.")
    move(generated_pdf, output_pdf)


def main() -> None:
    """Entry point.

    :returns: None
    :rtype: None
    """
    arguments: Arguments = parse_args()

    if not arguments.cls.exists():
        raise FileNotFoundError(f".cls not found: {arguments.cls}")

    try:  # Check if pandoc is available before doing any work.
        get_pandoc_path()
    except OSError as exception:
        logger.info("Downloading Pandoc...", exc_info=exception)
        download_pandoc()

    lua_filter: Path = Path(__file__).parent / "mermaid.lua"

    working_directory: Path = Path(mkdtemp())
    logger.info("Work directory: %s", working_directory)

    try:
        # Copy .cls so pdflatex finds it.
        copy(arguments.cls, working_directory / arguments.cls.name)

        # pypandoc: body only (no --standalone), --listings for code blocks
        extra_args: list[str] = ["--listings"]
        if lua_filter.exists():
            extra_args.append(f"--lua-filter={lua_filter}")

        # Pre-process: pandoc requires a blank line before bullet/ordered
        # lists. Insert one when a list marker follows a non-blank line.
        raw_md: str = arguments.input.read_text(encoding="utf-8")
        raw_md = sub(r"([^\n])\n(\s*[-*+]\s)", r"\1\n\n\2", raw_md)
        raw_md = sub(r"([^\n])\n(\s*\d+[.)]\s)", r"\1\n\n\2", raw_md)

        # Pandoc escapes _ → \_ inside \lstinline!…! but lstinline is
        # verbatim, so the backslash would show up in the PDF.  Undo it.
        def _fix_lstinline(match: Match[str]) -> str:
            return match.group(0).replace("\\_", "_")

        latex_body: str = sub(
            r"\\lstinline!.*?!",
            _fix_lstinline,
            cast(
                str,
                convert_text(
                    raw_md,
                    "latex",
                    format="md",
                    extra_args=extra_args,
                ),
            ),
        )

        # Assemble full document (.cls handles the preamble)
        document: str = "\n".join(
            [
                f"\\documentclass{{{arguments.cls.stem}}}",
                "",
                "\\begin{document}",
                latex_body,
                "\\end{document}",
            ]
        )

        tex_path: Path = working_directory / "document.tex"
        tex_path.write_text(document, encoding="utf-8")
        compile_pdf(tex_path, arguments.output, working_directory)

    finally:
        rmtree(working_directory, ignore_errors=True)


if __name__ == "__main__":
    main()
