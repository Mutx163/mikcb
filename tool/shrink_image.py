#!/usr/bin/env python
"""Downscale a screenshot so it is cheap to look at (and to keep in an agent chat).

A full-resolution phone screenshot (1880x3008 PNG) is 2-5 MB. Every image an
agent "reads" is carried as base64 inside the conversation, so a handful of
them is enough to push the CLI process into a multi-GB heap (observed:
18 screenshots -> 4 GB -> "JavaScript heap out of memory"). A 720px-wide JPEG
of the same frame is ~100 KB, i.e. 20-50x smaller, and is still enough to judge
layout, spacing and colour.

Usage:
  python tool/shrink_image.py shot.png
      -> writes shot-small.jpg next to it
  python tool/shrink_image.py shot.png -o tmp/qa/small.jpg
  python tool/shrink_image.py tmp/qa/*.png -w 900 -q 85
  python tool/shrink_image.py tmp/qa/*.png --keep-only
      -> delete each source once its small copy is written

Requires Pillow (PIL). On this machine the real interpreter is
%LOCALAPPDATA%\\Programs\\Python\\Python312\\python.exe -- do NOT use the
`python3` name, that is the Microsoft Store stub.
"""

import argparse
import os
import sys

try:
    from PIL import Image
except ImportError:
    sys.exit("error: Pillow not installed for this interpreter (%s).\n"
             "Install it, or point at one that has it, e.g.\n"
             "  %%LOCALAPPDATA%%\\Programs\\Python\\Python312\\python.exe" % sys.executable)


def parse_args():
    p = argparse.ArgumentParser(
        description="Downscale screenshots to small JPEGs.",
        usage="python tool/shrink_image.py <src...> [-o OUT] [-w N] [-q N] [--keep-only]",
    )
    p.add_argument("sources", nargs="+", help="image file(s) to shrink")
    p.add_argument("-o", "--out", help="output file or directory (single source only)")
    p.add_argument("-w", "--max-width", type=int, default=720,
                   help="max width in pixels, never upscales (default: 720)")
    p.add_argument("-q", "--quality", type=int, default=80,
                   help="JPEG quality (default: 80)")
    p.add_argument("--keep-only", action="store_true",
                   help="delete each source after its small copy is written")
    return p.parse_args()


def small_name(src):
    stem, _ = os.path.splitext(src)
    return stem + "-small.jpg"


def resolve_out(src, out, count):
    if not out:
        return small_name(src)
    if count > 1:
        sys.exit("error: -o needs exactly one source")
    if os.path.isdir(out):
        return os.path.join(out, os.path.basename(small_name(src)))
    return out


def to_rgb(img):
    # JPEG has no alpha channel: flatten transparency onto white instead of
    # letting Pillow turn it black.
    if img.mode in ("RGBA", "LA", "P"):
        img = img.convert("RGBA")
        flat = Image.new("RGB", img.size, (255, 255, 255))
        flat.paste(img, mask=img.split()[-1])
        return flat
    return img.convert("RGB")


def main():
    args = parse_args()
    if args.max_width < 16:
        sys.exit("error: --max-width must be at least 16")

    total_before = 0
    total_after = 0
    for src in args.sources:
        if not os.path.isfile(src):
            sys.exit("error: no such file: %s" % src)

        before = os.path.getsize(src)
        with Image.open(src) as img:
            img = to_rgb(img)
            if img.width > args.max_width:
                height = max(1, round(img.height * args.max_width / img.width))
                resample = getattr(Image, "Resampling", Image).LANCZOS
                img = img.resize((args.max_width, height), resample)
            dst = resolve_out(src, args.out, len(args.sources))
            parent = os.path.dirname(dst)
            if parent:
                os.makedirs(parent, exist_ok=True)
            img.save(dst, "JPEG", quality=args.quality, optimize=True)

        after = os.path.getsize(dst)
        total_before += before
        total_after += after
        print("%s  %dKB -> %dKB (%dx%d)" % (
            dst, before // 1024, after // 1024, img.width, img.height))

        if args.keep_only:
            os.remove(src)

    if len(args.sources) > 1:
        print("total %dKB -> %dKB" % (total_before // 1024, total_after // 1024))
    return 0


if __name__ == "__main__":
    sys.exit(main())
