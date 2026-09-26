"""Export the rendered reveal.js deck to PDF.

Uses reveal's ?print-pdf view in the locally installed Google Chrome and waits
until every slide has been laid out as a PDF page before printing.

Run from the repo root after copying the rendered deck to slides.html:
    python3 slides/export_pdf.py
"""
from pathlib import Path

from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "slides.html"
OUT = ROOT / "slides.pdf"

with sync_playwright() as p:
    browser = p.chromium.launch(channel="chrome")
    page = browser.new_page(viewport={"width": 1280, "height": 720})
    page.goto(f"{SRC.as_uri()}?print-pdf", wait_until="load")
    # Reveal reports 0 slides until it has initialized, so require a positive
    # count and one .pdf-page per slide before printing.
    page.wait_for_function(
        """() => window.Reveal && Reveal.isReady() && Reveal.getTotalSlides() > 0 &&
                 document.querySelectorAll('.pdf-page').length === Reveal.getTotalSlides()""",
        timeout=60_000,
    )
    page.evaluate("async () => { await document.fonts.ready; }")
    page.wait_for_timeout(1_000)  # let print layout settle after fonts load
    n = page.evaluate("document.querySelectorAll('.pdf-page').length")
    page.pdf(path=str(OUT), prefer_css_page_size=True, print_background=True)
    browser.close()

print(f"Wrote {OUT.relative_to(ROOT)} ({n} pages)")
