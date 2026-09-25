#!/usr/bin/env python3
"""Bygger docs/index.html (GitHub Pages) ud fra docs/_side.html.

Opsætningsprompten i templates/opsaetning-prompt.md bliver lagt ind i siden,
så knappen "Kopiér opsætningsprompten" altid kopierer den aktuelle version.

Kør fra projektets rodmappe:  python3 scripts/byg-vejledning.py
"""
import html
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
SOURCE = ROOT / "docs" / "_side.html"
PROMPT = ROOT / "templates" / "opsaetning-prompt.md"
TARGET = ROOT / "docs" / "index.html"
MARKER = "<!--OPSAETNINGSPROMPT-->"

DESCRIPTION = (
    "Få en kort mail hver aften om, hvad børnene skal huske i morgen, "
    "hentet direkte fra Aula. Gratis og open source."
)


def prompt_text() -> str:
    lines = PROMPT.read_text(encoding="utf-8").splitlines()
    try:
        start = lines.index("---") + 1
    except ValueError:
        sys.exit("Fandt ikke stregen (---) i opsaetning-prompt.md")
    return "\n".join(lines[start:]).strip() + "\n"


def build_body() -> str:
    body = SOURCE.read_text(encoding="utf-8")
    if MARKER not in body:
        sys.exit(f"Fandt ikke {MARKER} i {SOURCE.name}")
    return body.replace(MARKER, html.escape(prompt_text(), quote=False))


def main() -> None:
    body = build_body()
    # Alt før sidens indhold (<title>, fonte og <style>) hører til i <head>.
    split = body.index('<div class="wrap"')
    head_part, content = body[:split].strip(), body[split:]
    page = (
        "<!doctype html>\n"
        '<html lang="da">\n<head>\n'
        '<meta charset="utf-8">\n'
        '<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">\n'
        f'<meta name="description" content="{html.escape(DESCRIPTION)}">\n'
        f"{head_part}\n"
        "</head>\n<body>\n"
        f"{content}\n"
        "</body>\n</html>\n"
    )
    TARGET.write_text(page, encoding="utf-8")
    print(f"Skrev {TARGET.relative_to(ROOT)} ({len(page) // 1024} KB)")

    if len(sys.argv) > 1:  # valgfri: skriv siden uden html-skelet (til forhåndsvisning)
        out = pathlib.Path(sys.argv[1])
        out.write_text(body, encoding="utf-8")
        print(f"Skrev {out}")


if __name__ == "__main__":
    main()
