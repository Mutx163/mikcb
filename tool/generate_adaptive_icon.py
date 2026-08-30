"""Generate Android adaptive icon layers from the REAL shipped app icon.

Source of truth: assets/branding/launcher_icon.png (pixel-identical to the
mipmap ic_launcher.png set). Produces background (edge-color continuation)
and foreground (artwork centered with safe-zone margin) layers for all
densities, plus preview composites for human review before committing.

Startup branding is NOT generated here anymore: the Android 12+ system
splash is stripped to a bare background color (values-v31 styles) and the
startup branding is drawn by the app's own Flutter splash
(lib/widgets/app_startup_splash.dart) using the source image directly.
System-side splash icon/branding resources were removed after three device
failures traced to the OS icon mask/scale pipeline (double-plate ghost,
cropped-artwork blur).
"""

from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "assets" / "branding" / "launcher_icon.png"
RES = ROOT / "android" / "app" / "src" / "main" / "res"
PREVIEW = ROOT / ".tmp_adaptive_preview"
BASE = 1024
# 108dp adaptive canvas; only the central 72dp safe zone is visible.
# 72/108 = 0.667 maps the full artwork exactly onto the visible area,
# matching how the legacy full-bleed bitmap filled the launcher mask.
FG_SCALE = 0.67
DENSITIES = {"mdpi": 1.0, "hdpi": 1.5, "xhdpi": 2.0, "xxhdpi": 3.0, "xxxhdpi": 4.0}


def build_background(src: Image.Image) -> Image.Image:
    """Bilinear gradient from the four edge midpoints of the artwork."""
    arr = np.asarray(src.convert("RGB"), dtype=np.float64)
    mid = BASE // 2
    top_mid = arr[0, mid]
    bottom_mid = arr[-1, mid]
    left_mid = arr[mid, 0]
    right_mid = arr[mid, -1]
    s = np.linspace(0.0, 1.0, BASE)[:, None, None]
    t = np.linspace(0.0, 1.0, BASE)[None, :, None]
    vert = top_mid[None, None, :] * (1.0 - s) + bottom_mid[None, None, :] * s
    horz = left_mid[None, None, :] * (1.0 - t) + right_mid[None, None, :] * t
    out = 0.5 * vert + 0.5 * horz
    # Keep the original artwork pixels where it is opaque.
    alpha = np.asarray(src.convert("RGBA"), dtype=np.float64)[:, :, 3:4] / 255.0
    rgb = np.asarray(src.convert("RGB"), dtype=np.float64)
    final = out * (1.0 - alpha) + rgb * alpha
    return Image.fromarray(np.clip(final, 0, 255).astype(np.uint8), "RGB").convert("RGBA")


def scale_centered(img: Image.Image, scale: float) -> Image.Image:
    size = int(BASE * scale)
    small = img.resize((size, size), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (BASE, BASE), (0, 0, 0, 0))
    off = (BASE - size) // 2
    canvas.alpha_composite(small, (off, off))
    return canvas


def rounded_mask(size: int, radius_ratio: float) -> Image.Image:
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, size - 1, size - 1), radius=int(size * radius_ratio), fill=255
    )
    return mask


def circle_mask(size: int) -> Image.Image:
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).ellipse((0, 0, size - 1, size - 1), fill=255)
    return mask


Q = chr(39)
D = chr(34)
ADAPTIVE_XML = (
    "<?xml version=" + Q + "1.0" + Q + " encoding=" + Q + "utf-8" + Q + "?>" + chr(10) +
    "<adaptive-icon xmlns:android=" + D + "http://schemas.android.com/apk/res/android" + D + ">" + chr(10) +
    "    <background android:drawable=" + D + "@mipmap/ic_launcher_background" + D + "/>" + chr(10) +
    "    <foreground android:drawable=" + D + "@mipmap/ic_launcher_foreground" + D + "/>" + chr(10) +
    "</adaptive-icon>" + chr(10)
)


def main() -> None:
    src = Image.open(SRC).convert("RGBA").resize((BASE, BASE), Image.Resampling.LANCZOS)
    background = build_background(src)
    foreground = scale_centered(src, FG_SCALE)

    for density, factor in DENSITIES.items():
        layer = int(round(108 * factor))
        d = RES / ("mipmap-" + density)
        d.mkdir(parents=True, exist_ok=True)
        background.resize((layer, layer), Image.Resampling.LANCZOS).save(d / "ic_launcher_background.png")
        foreground.resize((layer, layer), Image.Resampling.LANCZOS).save(d / "ic_launcher_foreground.png")

    xml_dir = RES / "mipmap-anydpi-v26"
    xml_dir.mkdir(parents=True, exist_ok=True)
    (xml_dir / "ic_launcher.xml").write_text(ADAPTIVE_XML, encoding="utf-8")

    # Previews for human review BEFORE trusting the result on device.
    PREVIEW.mkdir(parents=True, exist_ok=True)
    comp = Image.alpha_composite(background, foreground)
    size = 256
    comp_r = comp.resize((size, size), Image.Resampling.LANCZOS)
    real_r = src.resize((size, size), Image.Resampling.LANCZOS)
    squircle = rounded_mask(BASE, 0.24).resize((size, size))
    circle = circle_mask(BASE).resize((size, size))

    def save_masked(img, mask, name):
        out = Image.new("RGBA", (size, size), (238, 238, 238, 255))
        out.paste(img, (0, 0), mask)
        out.save(PREVIEW / name)

    save_masked(comp_r, squircle, "preview_hyperos_squircle.png")
    save_masked(comp_r, circle, "preview_circle.png")

    side = Image.new("RGBA", (size * 2 + 30, size + 20), (255, 255, 255, 255))
    old_tile = Image.new("RGBA", (size, size), (238, 238, 238, 255))
    old_tile.paste(real_r, (0, 0), squircle)
    new_tile = Image.new("RGBA", (size, size), (238, 238, 238, 255))
    new_tile.paste(comp_r, (0, 0), squircle)
    side.paste(old_tile, (10, 10))
    side.paste(new_tile, (size + 20, 10))
    side.save(PREVIEW / "preview_old_vs_new.png")
    print("layers written; previews in .tmp_adaptive_preview/")


if __name__ == "__main__":
    main()
