#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import logging
import sys
from pathlib import Path

from frame_auto_date_title import process_folder, read_exif_date, read_title


def _emit(event: dict) -> None:
    print(json.dumps(event, ensure_ascii=False), flush=True)


def _scan(input_dir: Path) -> int:
    if not input_dir.exists() or not input_dir.is_dir():
        _emit({"event": "error", "message": f"Invalid input folder: {input_dir}"})
        return 2

    exts = {".jpg", ".jpeg", ".tif", ".tiff", ".png"}
    rows: list[dict[str, str]] = []
    for p in sorted(input_dir.iterdir()):
        if p.suffix.lower() not in exts:
            continue
        rows.append(
            {
                "filename": p.name,
                "capture_date": read_exif_date(p) or "",
                "title": read_title(p) or "",
            }
        )
    _emit({"event": "scan_result", "images": rows, "count": len(rows)})
    return 0


def _run(
    input_dir: Path,
    output_dir: Path,
    border: int,
    bottom: int,
    pad: int,
    date_font: int,
    title_font: int,
    overrides_json: Path | None,
) -> int:
    overrides: dict[Path, tuple[str, str]] = {}
    if overrides_json:
        data = json.loads(overrides_json.read_text(encoding="utf-8"))
        if not isinstance(data, dict):
            raise ValueError("Overrides JSON must be an object mapping filename to metadata.")
        for filename, vals in data.items():
            if not isinstance(vals, dict):
                continue
            date_val = str(vals.get("capture_date", "") or "")
            title_val = str(vals.get("title", "") or "")
            overrides[input_dir / str(filename)] = (date_val, title_val)

    def progress_cb(done: int, total: int, _: Path | None) -> None:
        _emit({"event": "progress", "done": done, "total": total})

    def log_cb(msg: str) -> None:
        _emit({"event": "log", "message": msg})

    success, total = process_folder(
        in_dir=input_dir,
        out_dir=output_dir,
        border_px=border,
        bottom_extra_px=bottom,
        pad_px=pad,
        font_size_date=date_font,
        font_size_title=title_font,
        metadata_overrides=overrides,
        progress_cb=progress_cb,
        log_cb=log_cb,
    )
    _emit({"event": "done", "success": success, "total": total, "failed": total - success})
    return 0 if success == total else 1


def main() -> int:
    logging.basicConfig(level=logging.ERROR)
    parser = argparse.ArgumentParser(description="JSON backend for Frame app.")
    sub = parser.add_subparsers(dest="cmd", required=True)

    scan = sub.add_parser("scan")
    scan.add_argument("--input", required=True)

    run = sub.add_parser("run")
    run.add_argument("--input", required=True)
    run.add_argument("--output", required=True)
    run.add_argument("--border", type=int, default=80)
    run.add_argument("--bottom", type=int, default=240)
    run.add_argument("--pad", type=int, default=40)
    run.add_argument("--date-font", type=int, default=60)
    run.add_argument("--title-font", type=int, default=80)
    run.add_argument("--overrides-json")

    args = parser.parse_args()
    try:
        if args.cmd == "scan":
            return _scan(Path(args.input))
        if args.cmd == "run":
            return _run(
                input_dir=Path(args.input),
                output_dir=Path(args.output),
                border=args.border,
                bottom=args.bottom,
                pad=args.pad,
                date_font=args.date_font,
                title_font=args.title_font,
                overrides_json=Path(args.overrides_json) if args.overrides_json else None,
            )
    except Exception as e:
        _emit({"event": "error", "message": str(e)})
        return 2
    return 2


if __name__ == "__main__":
    sys.exit(main())
