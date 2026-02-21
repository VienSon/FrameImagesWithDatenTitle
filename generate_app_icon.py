#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont


def rounded_rect_mask(size: int, radius: int) -> Image.Image:
    mask = Image.new("L", (size, size), 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle((0, 0, size - 1, size - 1), radius=radius, fill=255)
    return mask


def main() -> None:
    root = Path(__file__).resolve().parent
    assets = root / "assets"
    iconset = assets / "AppIcon.iconset"
    assets.mkdir(parents=True, exist_ok=True)
    iconset.mkdir(parents=True, exist_ok=True)

    size = 1024
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))

    # Backplate with subtle gradient.
    back = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(back)
    d.rounded_rectangle((32, 32, size - 32, size - 32), radius=210, fill=(24, 37, 62, 255))
    glow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.ellipse((120, 90, 880, 660), fill=(68, 143, 255, 170))
    glow = glow.filter(ImageFilter.GaussianBlur(60))
    back = Image.alpha_composite(back, glow)

    # White photo frame.
    fd = ImageDraw.Draw(back)
    fd.rounded_rectangle((210, 180, 820, 820), radius=48, fill=(249, 250, 252, 255))
    fd.rounded_rectangle((280, 245, 750, 630), radius=18, fill=(190, 218, 255, 255))
    fd.rectangle((308, 274, 722, 600), fill=(107, 154, 220, 255))
    fd.polygon([(360, 580), (500, 420), (610, 530), (720, 380), (722, 600), (308, 600)], fill=(72, 122, 194, 255))
    fd.ellipse((625, 300, 690, 365), fill=(244, 246, 250, 255))

    # Caption lines.
    fd.rectangle((305, 675, 490, 694), fill=(66, 72, 86, 230))
    fd.rectangle((305, 708, 675, 725), fill=(88, 96, 112, 180))

    # Monogram in corner.
    font = ImageFont.load_default()
    fd.text((720, 690), "F", font=font, fill=(35, 44, 60, 255))

    mask = rounded_rect_mask(size, 220)
    canvas.paste(back, (0, 0), mask)

    src_png = assets / "AppIcon-1024.png"
    canvas.save(src_png, format="PNG")

    sizes = [
        16, 32, 64, 128, 256, 512, 1024,
    ]
    for px in sizes:
        out = canvas.resize((px, px), Image.Resampling.LANCZOS)
        if px <= 512:
            out.save(iconset / f"icon_{px}x{px}.png", format="PNG")
        if px >= 32:
            half = px // 2
            if half in {16, 32, 64, 128, 256, 512}:
                out.resize((half, half), Image.Resampling.LANCZOS).save(
                    iconset / f"icon_{half}x{half}@2x.png",
                    format="PNG",
                )

    print(f"Wrote {src_png}")
    print(f"Wrote iconset at {iconset}")


if __name__ == "__main__":
    main()
