from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parent.parent
BASE_SIZE = 1024


def rounded_rect_mask(size: int, radius: int) -> Image.Image:
    mask = Image.new("L", (size, size), 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle((0, 0, size - 1, size - 1), radius=radius, fill=255)
    return mask


def interpolate(c1, c2, t):
    return tuple(int(a + (b - a) * t) for a, b in zip(c1, c2))


def create_base_icon() -> Image.Image:
    img = Image.new("RGBA", (BASE_SIZE, BASE_SIZE), (0, 0, 0, 0))
    pixels = img.load()
    top_left = (37, 99, 235)
    bottom_right = (8, 145, 178)

    for y in range(BASE_SIZE):
      for x in range(BASE_SIZE):
            tx = x / (BASE_SIZE - 1)
            ty = y / (BASE_SIZE - 1)
            t = (tx + ty) / 2
            color = interpolate(top_left, bottom_right, t)
            pixels[x, y] = (*color, 255)

    draw = ImageDraw.Draw(img)
    draw.ellipse((90, 70, 470, 450), fill=(255, 255, 255, 18))
    draw.ellipse((610, 620, 980, 990), fill=(255, 255, 255, 14))

    shadow = Image.new("RGBA", (BASE_SIZE, BASE_SIZE), (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)
    shadow_draw.rounded_rectangle(
        (228, 214, 772, 808),
        radius=120,
        fill=(15, 23, 42, 90),
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(28))
    img.alpha_composite(shadow)

    panel = Image.new("RGBA", (BASE_SIZE, BASE_SIZE), (0, 0, 0, 0))
    panel_draw = ImageDraw.Draw(panel)
    panel_draw.rounded_rectangle(
        (220, 196, 764, 792),
        radius=120,
        fill=(248, 250, 252, 255),
    )
    panel_draw.rounded_rectangle(
        (220, 196, 764, 330),
        radius=120,
        fill=(224, 242, 254, 255),
    )
    panel_draw.rectangle((220, 280, 764, 330), fill=(224, 242, 254, 255))

    line_color = (148, 163, 184, 165)
    accent_color = (249, 115, 22, 255)
    blue_color = (37, 99, 235, 255)

    for idx, top in enumerate((376, 480, 584)):
        fill = accent_color if idx == 1 else blue_color
        panel_draw.rounded_rectangle(
            (330, top, 696, top + 58),
            radius=28,
            fill=fill,
        )
        panel_draw.rounded_rectangle(
            (276, top + 6, 304, top + 34),
            radius=14,
            fill=(100, 116, 139, 190),
        )
        panel_draw.line((330, top + 86, 696, top + 86), fill=line_color, width=6)

    panel_draw.rounded_rectangle(
        (276, 250, 360, 278),
        radius=14,
        fill=(37, 99, 235, 210),
    )
    panel_draw.rounded_rectangle(
        (386, 250, 624, 278),
        radius=14,
        fill=(14, 165, 233, 170),
    )
    panel_draw.rounded_rectangle(
        (652, 250, 708, 278),
        radius=14,
        fill=(37, 99, 235, 210),
    )

    img.alpha_composite(panel)

    dot_shadow = Image.new("RGBA", (BASE_SIZE, BASE_SIZE), (0, 0, 0, 0))
    dot_shadow_draw = ImageDraw.Draw(dot_shadow)
    dot_shadow_draw.ellipse((662, 138, 888, 364), fill=(124, 45, 18, 130))
    dot_shadow = dot_shadow.filter(ImageFilter.GaussianBlur(20))
    img.alpha_composite(dot_shadow)

    draw = ImageDraw.Draw(img)
    draw.ellipse((674, 150, 874, 350), fill=(249, 115, 22, 255))
    draw.ellipse((714, 190, 834, 310), fill=(255, 247, 237, 255))
    draw.arc((694, 170, 854, 330), start=215, end=325, fill=(255, 247, 237, 255), width=16)

    final_mask = rounded_rect_mask(BASE_SIZE, 220)
    output = Image.new("RGBA", (BASE_SIZE, BASE_SIZE), (0, 0, 0, 0))
    output.paste(img, mask=final_mask)
    return output


def save_resized(image: Image.Image, path: Path, size: int):
    path.parent.mkdir(parents=True, exist_ok=True)
    image.resize((size, size), Image.Resampling.LANCZOS).save(path)


def main():
    image = create_base_icon()
    save_resized(image, ROOT / "assets" / "branding" / "app_icon_source.png", 1024)

    android_sizes = {
        "android/app/src/main/res/mipmap-mdpi/ic_launcher.png": 48,
        "android/app/src/main/res/mipmap-hdpi/ic_launcher.png": 72,
        "android/app/src/main/res/mipmap-xhdpi/ic_launcher.png": 96,
        "android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png": 144,
        "android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png": 192,
    }

    for mapping in (android_sizes,):
        for relative, size in mapping.items():
            save_resized(image, ROOT / relative, size)


if __name__ == "__main__":
    main()
