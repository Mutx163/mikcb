"""Generate Android adaptive icon layers from the REAL shipped app icon.

Source of truth: assets/branding/launcher_icon.png (pixel-identical to the
mipmap ic_launcher.png set). Produces background (edge-color continuation)
and foreground (artwork centered with safe-zone margin) layers for all
densities, plus preview composites for human review before committing.
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
# Splash icon artwork: 0.40 x 108dp canvas -> ~60% of the 72dp visible zone
# (the launcher's 0.67 maps artwork onto the full visible area and read huge).
SPLASH_FG_SCALE = 0.40
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

ADAPTIVE_SPLASH_XML = (
    "<?xml version=" + Q + "1.0" + Q + " encoding=" + Q + "utf-8" + Q + "?>" + chr(10) +
    "<adaptive-icon xmlns:android=" + D + "http://schemas.android.com/apk/res/android" + D + ">" + chr(10) +
    "    <background android:drawable=" + D + "@mipmap/splash_icon_background" + D + "/>" + chr(10) +
    "    <foreground android:drawable=" + D + "@mipmap/splash_icon_foreground" + D + "/>" + chr(10) +
    "</adaptive-icon>" + chr(10)
)


# --- Bottom branding image (windowSplashScreenBrandingImage, 200x80dp) ---
BRAND_TEXT = "轻屿课表"
BRAND_COLOR_LIGHT = (0, 0, 0, 255)  # black ink on the white light-mode well
BRAND_COLOR_NIGHT = (255, 255, 255, 255)  # white ink on the #121212 night well
# Regular weight only — msyhbd read heavy at splash size (user feedback).
FONT_CANDIDATES = [
    Path("C:/Windows/Fonts/msyh.ttc"),
    Path("C:/Windows/Fonts/simhei.ttf"),
]


def find_font() -> Path:
    for p in FONT_CANDIDATES:
        if p.exists():
            return p
    raise SystemExit("no CJK font found for branding text")


def build_branding(text_color: tuple) -> Image.Image:
    """Render BRAND_TEXT on a transparent 200x80dp canvas (5x supersampled).

    Text is enlarged (50% of canvas height vs 30%) and shifted upward
    (vertical center at 38% vs 50%) so the system splash branding reads
    larger and sits higher instead of hugging the bottom edge. Emitted in
    both inks: black for the white light well, white for the #121212 night
    well (drawable-night-*).
    """
    from PIL import ImageFont
    w, h = 1000, 400
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    font = ImageFont.truetype(str(find_font()), int(h * 0.50))
    draw.text((w / 2, h * 0.38), BRAND_TEXT, font=font, fill=text_color, anchor="mm")
    return img


def emit_branding() -> None:
    buckets = {
        "mdpi": (200, 80),
        "hdpi": (300, 120),
        "xhdpi": (400, 160),
        "xxhdpi": (600, 240),
        "xxxhdpi": (800, 320),
    }
    for ink, qualifier in (
        (BRAND_COLOR_LIGHT, "drawable-"),
        (BRAND_COLOR_NIGHT, "drawable-night-"),
    ):
        branding = build_branding(ink)
        for density, (w, h) in buckets.items():
            d = RES / (qualifier + density)
            d.mkdir(parents=True, exist_ok=True)
            branding.resize((w, h), Image.Resampling.LANCZOS).save(d / "splash_branding.png")


def build_plate() -> Image.Image:
    """Soft gradient plate sampled from artwork edges (no artwork pixels)."""
    src = Image.open(SRC).convert("RGBA").resize((BASE, BASE), Image.Resampling.LANCZOS)
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
    return Image.fromarray(np.clip(out, 0, 255).astype(np.uint8), "RGB").convert("RGBA")


def emit_splash_adaptive() -> None:
    """Emit the dedicated splash icon as an adaptive icon (XML + layers).

    The system mask shapes the composite exactly like the launcher icon, so
    the splash silhouette matches the app icon on every ROM. A flat PNG here
    instead gets scaled UNMASKED over the ROM's own icon plate (288dp vs
    240dp), which is how the "square plate + circle" double-shape ghost
    happened.
    """
    background = build_plate()
    foreground = scale_centered(
        Image.open(SRC).convert("RGBA").resize((BASE, BASE), Image.Resampling.LANCZOS),
        SPLASH_FG_SCALE,
    )
    for density, factor in DENSITIES.items():
        layer = int(round(108 * factor))
        d = RES / ("mipmap-" + density)
        d.mkdir(parents=True, exist_ok=True)
        background.resize((layer, layer), Image.Resampling.LANCZOS).save(d / "splash_icon_background.png")
        foreground.resize((layer, layer), Image.Resampling.LANCZOS).save(d / "splash_icon_foreground.png")
    d = RES / "drawable"
    d.mkdir(parents=True, exist_ok=True)
    (d / "splash_icon.xml").write_text(ADAPTIVE_SPLASH_XML, encoding="utf-8")


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

    emit_branding()
    emit_splash_adaptive()

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

    # Splash icon under a HyperOS-like squircle mask + branding text on both
    # wells, so ink/weight/plate can be reviewed without installing.
    splash = Image.alpha_composite(background, foreground)
    save_masked(splash.resize((size, size), Image.Resampling.LANCZOS), squircle, "preview_splash_icon.png")
    brand_light = build_branding(BRAND_COLOR_LIGHT)
    for name, well in (
        ("preview_splash_branding_light.png", (255, 255, 255, 255)),
        ("preview_splash_branding_night.png", (18, 18, 18, 255)),
    ):
        tile = Image.new("RGBA", brand_light.size, well)
        tile.alpha_composite(brand_light)
        tile.resize(
            (brand_light.size[0] // 2, brand_light.size[1] // 2), Image.Resampling.LANCZOS
        ).save(PREVIEW / name)
    print("layers written; previews in .tmp_adaptive_preview/")


if __name__ == "__main__":
    main()