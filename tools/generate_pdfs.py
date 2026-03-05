"""
Generate one PDF per folder inside lib/.
Each PDF will contain the source code of .dart files inside that folder (non-recursive by default, but it will include files in subfolders too grouped by subpath).

Output directory: C:\projects\generated_pdfs

Requires: reportlab (will be installed by the runner if missing)
"""
import os
import sys
import textwrap
from pathlib import Path

try:
    from reportlab.pdfgen import canvas
    from reportlab.lib.pagesizes import A4, landscape, portrait
    from reportlab.lib.units import mm
except Exception as e:
    print("Missing reportlab; please install with: pip install reportlab")
    raise

ROOT = Path(__file__).resolve().parents[1]  # C:/projects
LIB_DIR = ROOT / 'lib'
OUT_DIR = ROOT / 'generated_pdfs'
OUT_DIR.mkdir(parents=True, exist_ok=True)

PAGE_WIDTH, PAGE_HEIGHT = A4  # portrait
LEFT_MARGIN = 15 * mm
RIGHT_MARGIN = 15 * mm
TOP_MARGIN = 20 * mm
BOTTOM_MARGIN = 20 * mm
FONT_NAME = 'Courier'
FONT_SIZE = 8
LINE_HEIGHT = FONT_SIZE * 1.2

def wrap_line(s, max_chars):
    # Preserve tabs by expanding to 4 spaces
    s = s.replace('\t', '    ')
    if len(s) <= max_chars:
        return [s]
    # Use textwrap to wrap, but keep indentation
    stripped = s.lstrip()
    indent = s[:len(s)-len(stripped)]
    wrapped = textwrap.wrap(stripped, width=max_chars - len(indent), replace_whitespace=False, drop_whitespace=False)
    return [(indent + w) for w in wrapped]


def write_pdf_for_folder(folder_path: Path):
    # Collect .dart files under folder_path (recursively)
    dart_files = [p for p in folder_path.rglob('*.dart') if p.is_file()]
    if not dart_files:
        print(f"No .dart files found in {folder_path}; skipping")
        return None

    out_pdf = OUT_DIR / f"{folder_path.name}.pdf"
    c = canvas.Canvas(str(out_pdf), pagesize=portrait(A4))
    c.setFont(FONT_NAME, FONT_SIZE)

    max_text_width = PAGE_WIDTH - LEFT_MARGIN - RIGHT_MARGIN
    # approximate char width for Courier at FONT_SIZE: ~0.6 * FONT_SIZE pts
    approx_char_width = FONT_SIZE * 0.6
    max_chars = int(max_text_width / approx_char_width)

    for file_path in sorted(dart_files):
        # File header
        x = LEFT_MARGIN
        y = PAGE_HEIGHT - TOP_MARGIN
        header = f"File: {file_path.relative_to(ROOT)}"
        c.setFont(FONT_NAME, FONT_SIZE + 2)
        c.drawString(x, y, header)
        y -= LINE_HEIGHT * 1.5
        c.setFont(FONT_NAME, FONT_SIZE)

        # Read file
        try:
            text = file_path.read_text(encoding='utf-8')
        except Exception:
            text = file_path.read_text(encoding='latin-1')

        lines = text.splitlines()

        # Draw lines with wrapping and pagination
        text_obj = c.beginText()
        text_obj.setTextOrigin(x, y)
        text_obj.setFont(FONT_NAME, FONT_SIZE)

        for ln in lines:
            wrapped = wrap_line(ln, max_chars)
            for wln in wrapped:
                if text_obj.getY() < BOTTOM_MARGIN + LINE_HEIGHT:
                    c.drawText(text_obj)
                    c.showPage()
                    c.setFont(FONT_NAME, FONT_SIZE)
                    text_obj = c.beginText()
                    text_obj.setTextOrigin(LEFT_MARGIN, PAGE_HEIGHT - TOP_MARGIN)
                    text_obj.setFont(FONT_NAME, FONT_SIZE)
                text_obj.textLine(wln)

        # after file, add an empty line and continue (may cause page break)
        text_obj.textLine('')
        c.drawText(text_obj)
        c.showPage()

    c.save()
    print(f"Wrote: {out_pdf}")
    return out_pdf


def main():
    if not LIB_DIR.exists() or not LIB_DIR.is_dir():
        print(f"lib/ directory not found at expected path: {LIB_DIR}")
        sys.exit(1)

    # iterate immediate subdirectories of lib
    folders = [p for p in LIB_DIR.iterdir() if p.is_dir()]
    if not folders:
        print("No folders found inside lib/")
        sys.exit(0)

    written = []
    for f in sorted(folders):
        res = write_pdf_for_folder(f)
        if res:
            written.append(res)

    print('\nSummary:')
    for w in written:
        print(f" - {w}")


if __name__ == '__main__':
    main()

