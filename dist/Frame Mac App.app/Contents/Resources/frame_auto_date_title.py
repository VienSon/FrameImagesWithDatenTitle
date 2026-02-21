#!/usr/bin/env python3
from __future__ import annotations

import argparse
import re
import logging
from pathlib import Path
from datetime import datetime
from collections.abc import Callable

from PIL import Image, ImageDraw, ImageFont, ImageOps
import piexif

SCRIPT_DIR = Path(__file__).resolve().parent
FONTS_DIR = SCRIPT_DIR / "fonts"
DATE_FONT_FILE = FONTS_DIR / "JetBrainsMono-Regular.ttf"
TITLE_FONT_FILE = FONTS_DIR / "CormorantGaramond-Regular.ttf"
LOGGER = logging.getLogger(__name__)


# ---------- EXIF: capture date ----------
def read_exif_date(path: Path) -> str | None:
    """
    Return EXIF DateTimeOriginal as 'YYYY-MM-DD' if present.
    """
    try:
        exif = piexif.load(str(path))
        dt = exif.get("Exif", {}).get(piexif.ExifIFD.DateTimeOriginal)
        if not dt:
            dt = exif.get("0th", {}).get(piexif.ImageIFD.DateTime)  # fallback
        if not dt:
            return None
        if isinstance(dt, bytes):
            dt = dt.decode("utf-8", errors="ignore")
        d = datetime.strptime(dt.strip(), "%Y:%m:%d %H:%M:%S")
        return d.strftime("%Y-%m-%d")
    except Exception as e:
        LOGGER.warning("Failed to read EXIF date for %s: %s", path, e)
        return None


# ---------- XMP: Lightroom Title ----------
_XMP_TITLE_RE = re.compile(
    rb"<dc:title>\s*<rdf:Alt>\s*<rdf:li[^>]*>(.*?)</rdf:li>\s*</rdf:Alt>\s*</dc:title>",
    re.DOTALL,
)

def _strip_xml_text(b: bytes) -> str:
    # Remove simple XML tags if any appear, and decode entities minimally
    s = b.decode("utf-8", errors="ignore")
    s = re.sub(r"<[^>]+>", "", s)
    s = s.replace("&amp;", "&").replace("&lt;", "<").replace("&gt;", ">").replace("&quot;", '"').replace("&apos;", "'")
    return " ".join(s.split()).strip()

def read_xmp_title_from_bytes(data: bytes) -> str | None:
    """
    Extract dc:title from XMP packet in a JPEG/TIFF/PNG byte stream.
    """
    m = _XMP_TITLE_RE.search(data)
    if not m:
        return None
    title = _strip_xml_text(m.group(1))
    return title or None

def read_title(path: Path) -> str | None:
    """
    Tries, in order:
      1) Sidecar XMP: filename.xmp
      2) Embedded XMP inside image file (common for JPEG)
    """
    sidecar = path.with_suffix(".xmp")
    try:
        if sidecar.exists():
            data = sidecar.read_bytes()
            t = read_xmp_title_from_bytes(data)
            if t:
                return t
    except Exception as e:
        LOGGER.warning("Failed to read XMP sidecar for %s: %s", path, e)

    try:
        data = path.read_bytes()
        t = read_xmp_title_from_bytes(data)
        if t:
            return t
    except Exception as e:
        LOGGER.warning("Failed to read embedded XMP for %s: %s", path, e)

    return None


# ---------- Drawing helpers ----------
def pick_font(
    preferred_path: Path,
    fallback_paths: list[str],
    font_size: int,
) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    candidates = [str(preferred_path), *fallback_paths]
    for p in candidates:
        try:
            return ImageFont.truetype(p, font_size)
        except Exception:
            pass
    return ImageFont.load_default()


def pick_date_font(font_size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    return pick_font(
        preferred_path=DATE_FONT_FILE,
        fallback_paths=[
            "/System/Library/Fonts/Supplemental/Menlo.ttc",
            "/System/Library/Fonts/Supplemental/Courier New.ttf",
        ],
        font_size=font_size,
    )


def pick_title_font(font_size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    return pick_font(
        preferred_path=TITLE_FONT_FILE,
        fallback_paths=[
            "/System/Library/Fonts/Supplemental/Georgia.ttf",
            "/System/Library/Fonts/Supplemental/Times New Roman.ttf",
            "/System/Library/Fonts/Supplemental/Arial.ttf",
        ],
        font_size=font_size,
    )

def wrap_text(draw: ImageDraw.ImageDraw, text: str, font: ImageFont.ImageFont, max_width: int) -> list[str]:
    if max_width <= 0:
        return [text] if text else [""]

    def split_long_word(word: str) -> list[str]:
        if draw.textlength(word, font=font) <= max_width:
            return [word]
        parts: list[str] = []
        current = ""
        for ch in word:
            test = current + ch
            if current and draw.textlength(test, font=font) > max_width:
                parts.append(current)
                current = ch
            else:
                current = test
        if current:
            parts.append(current)
        return parts

    words = text.split()
    if not words:
        return [""]

    normalized_words: list[str] = []
    for w in words:
        normalized_words.extend(split_long_word(w))

    lines, line = [], normalized_words[0]
    for w in normalized_words[1:]:
        test = f"{line} {w}"
        if draw.textlength(test, font=font) <= max_width:
            line = test
        else:
            lines.append(line)
            line = w
    lines.append(line)
    return lines


def line_height(draw: ImageDraw.ImageDraw, font: ImageFont.ImageFont) -> int:
    bbox = draw.textbbox((0, 0), "Ag", font=font)
    return max(1, bbox[3] - bbox[1])

def add_frame_date_title(
    img: Image.Image,
    date_text: str,
    title: str,
    border_px: int,
    bottom_extra_px: int,
    pad_px: int,
    font_size_date: int,
    font_size_title: int,
) -> Image.Image:
    img = ImageOps.exif_transpose(img).convert("RGB")
    w, h = img.size

    # Prepare text and fonts first so the needed bottom space can be measured.
    date_text = date_text.strip()
    title = title.strip()
    new_w = w + border_px * 2
    temp_canvas = Image.new("RGB", (new_w, 10), "white")
    temp_draw = ImageDraw.Draw(temp_canvas)

    font_date = pick_date_font(font_size_date)
    font_title = pick_title_font(font_size_title)

    left = border_px + pad_px
    right = border_px + w - pad_px
    text_max_w = right - left

    gap = max(4, int(font_size_title * 0.35))
    top_offset = max(0, int(bottom_extra_px * 0.18))
    date_h = line_height(temp_draw, font_date)
    title_h = line_height(temp_draw, font_title)
    title_lines = wrap_text(temp_draw, title, font_title, text_max_w) if title else []
    title_block_h = len(title_lines) * title_h + max(0, len(title_lines) - 1) * gap

    content_h = top_offset
    if date_text:
        content_h += date_h
        if title_lines:
            content_h += gap
    content_h += title_block_h
    content_h += max(0, top_offset // 2)

    actual_bottom_extra = max(bottom_extra_px, content_h)
    new_h = h + border_px * 2 + actual_bottom_extra
    canvas = Image.new("RGB", (new_w, new_h), "white")
    canvas.paste(img, (border_px, border_px))

    draw = ImageDraw.Draw(canvas)
    y = border_px + h + top_offset

    # Date (top line)
    if date_text:
        draw.text((left, y), date_text, fill=(40, 40, 40), font=font_date)
        y += date_h + gap

    # Title (wrapped)
    if title_lines:
        for ln in title_lines:
            draw.text((left, y), ln, fill=(40, 40, 40), font=font_title)
            y += title_h + gap

    return canvas


def save_with_quality_preserved(
    framed: Image.Image,
    src_image: Image.Image,
    src_path: Path,
    out_dir: Path,
) -> Path:
    suffix = src_path.suffix.lower()
    if suffix in {".jpg", ".jpeg"}:
        out_path = out_dir / src_path.with_suffix(".jpg").name
        save_kwargs = {
            "format": "JPEG",
            "quality": 100,
            "subsampling": 0,
            "optimize": False,
        }
        icc = src_image.info.get("icc_profile")
        if icc:
            save_kwargs["icc_profile"] = icc
        exif = src_image.info.get("exif")
        if exif:
            save_kwargs["exif"] = exif
        framed.save(out_path, **save_kwargs)
        return out_path

    if suffix in {".tif", ".tiff"}:
        out_path = out_dir / src_path.with_suffix(".tif").name
        save_kwargs = {"format": "TIFF", "compression": "tiff_lzw"}
        icc = src_image.info.get("icc_profile")
        if icc:
            save_kwargs["icc_profile"] = icc
        framed.save(out_path, **save_kwargs)
        return out_path

    if suffix == ".png":
        out_path = out_dir / src_path.with_suffix(".png").name
        save_kwargs = {"format": "PNG", "compress_level": 1}
        icc = src_image.info.get("icc_profile")
        if icc:
            save_kwargs["icc_profile"] = icc
        framed.save(out_path, **save_kwargs)
        return out_path

    out_path = out_dir / src_path.with_suffix(".jpg").name
    framed.save(out_path, format="JPEG", quality=100, subsampling=0, optimize=False)
    return out_path


def process_folder(
    in_dir: Path,
    out_dir: Path,
    border_px: int,
    bottom_extra_px: int,
    pad_px: int,
    font_size_date: int,
    font_size_title: int,
    metadata_overrides: dict[Path, tuple[str, str]] | None = None,
    progress_cb: Callable[[int, int, Path | None], None] | None = None,
    log_cb: Callable[[str], None] | None = None,
) -> tuple[int, int]:
    if not in_dir.exists() or not in_dir.is_dir():
        raise ValueError(f"Input folder does not exist or is not a directory: {in_dir}")

    out_dir.mkdir(parents=True, exist_ok=True)

    exts = {".jpg", ".jpeg", ".tif", ".tiff", ".png"}
    files = [p for p in sorted(in_dir.iterdir()) if p.suffix.lower() in exts]
    total = len(files)
    success = 0

    if progress_cb:
        progress_cb(0, total, None)

    for idx, p in enumerate(files, start=1):
        try:
            override = None
            if metadata_overrides:
                override = metadata_overrides.get(p)

            if override is not None:
                date_str, title = override
            else:
                date_str = read_exif_date(p) or ""
                title = read_title(p) or ""  # Lightroom Title (XMP dc:title)

            with Image.open(p) as im:
                framed = add_frame_date_title(
                    im,
                    date_text=date_str,
                    title=title,
                    border_px=border_px,
                    bottom_extra_px=bottom_extra_px,
                    pad_px=pad_px,
                    font_size_date=font_size_date,
                    font_size_title=font_size_title,
                )
                out_path = save_with_quality_preserved(
                    framed=framed,
                    src_image=im,
                    src_path=p,
                    out_dir=out_dir,
                )
            success += 1
            msg = f"Saved: {out_path}"
            if log_cb:
                log_cb(msg)
            else:
                print(msg)
        except Exception as e:
            msg = f"Failed processing {p}: {e}"
            LOGGER.error(msg)
            if log_cb:
                log_cb(f"ERROR: {msg}")
        finally:
            if progress_cb:
                progress_cb(idx, total, p)

    done_msg = f"Done. Processed {total} file(s), succeeded {success}, failed {total - success}."
    if log_cb:
        log_cb(done_msg)
    else:
        print(done_msg)
    return success, total


def main():
    logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")
    ap = argparse.ArgumentParser()
    ap.add_argument("--input", required=True, help="Folder with images")
    ap.add_argument("--output", required=True, help="Output folder")
    ap.add_argument("--border", type=int, default=80, help="Border thickness px")
    ap.add_argument("--bottom", type=int, default=240, help="Extra bottom space px")
    ap.add_argument("--pad", type=int, default=40, help="Text padding px")
    ap.add_argument("--date_font", type=int, default=60, help="Date font size px")
    ap.add_argument("--title_font", type=int, default=80, help="Title font size px")
    args = ap.parse_args()

    in_dir = Path(args.input)
    out_dir = Path(args.output)
    process_folder(
        in_dir=in_dir,
        out_dir=out_dir,
        border_px=args.border,
        bottom_extra_px=args.bottom,
        pad_px=args.pad,
        font_size_date=args.date_font,
        font_size_title=args.title_font,
    )


if __name__ == "__main__":
    main()
