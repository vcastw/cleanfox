#!/usr/bin/env python3
"""Gera a arte do CleanFox (ícones e wordmarks) em branding/.

Os arquivos gerados ficam commitados; rode de novo só para mudar o desenho.
Requer Pillow e a fonte DejaVu Sans Bold:  python3 tools/gen-branding.py
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
TEAL = (15, 118, 110, 255)  # fundo
MINT = (20, 184, 166, 255)  # texto: legível em tema claro e escuro
WHITE = (255, 255, 255, 255)
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
SS = 4  # supersampling

# Cabeça de raposa geométrica, em coordenadas 0..1.
HEAD = [(0.16, 0.14), (0.40, 0.34), (0.60, 0.34), (0.84, 0.14), (0.82, 0.54), (0.50, 0.88), (0.18, 0.54)]
DETAILS = [  # recortes na cor do fundo: olhos e focinho
    [(0.30, 0.50), (0.42, 0.54), (0.33, 0.60)],
    [(0.70, 0.50), (0.58, 0.54), (0.67, 0.60)],
    [(0.44, 0.76), (0.56, 0.76), (0.50, 0.88)],
]


def scale(points, size, inset=0.0):
    span = size * (1 - 2 * inset)
    return [(size * inset + x * span, size * inset + y * span) for x, y in points]


def logo(size, shape="rounded"):
    """Ícone quadrado: fundo teal (arredondado, círculo ou transparente) + raposa branca."""
    big = size * SS
    im = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    if shape == "circle":
        d.ellipse([0, 0, big - 1, big - 1], fill=TEAL)
    elif shape == "rounded":
        d.rounded_rectangle([0, 0, big - 1, big - 1], radius=big * 0.22, fill=TEAL)
    inset = 0.14 if shape != "none" else 0.0
    d.polygon(scale(HEAD, big, inset), fill=WHITE)
    for poly in DETAILS:
        d.polygon(scale(poly, big, inset), fill=TEAL)
    return im.resize((size, size), Image.LANCZOS)


def text_image(width, height, text="CleanFox", icon=False):
    """Wordmark: texto (com o ícone à esquerda, se icon=True) centralizado em width x height."""
    im = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    icon_w = height if icon else 0
    gap = height // 6 if icon else 0
    font_size = int(height * 0.62)
    while True:
        font = ImageFont.truetype(FONT, font_size)
        left, top, right, bottom = d.textbbox((0, 0), text, font=font)
        if icon_w + gap + (right - left) <= width or font_size <= 8:
            break
        font_size -= 1
    total = icon_w + gap + (right - left)
    x = (width - total) // 2
    if icon:
        im.alpha_composite(logo(height), (x, 0))
    d.text((x + icon_w + gap - left, (height - (bottom - top)) // 2 - top), text, font=font, fill=MINT)
    return im


def search_widget(width, height):
    im = Image.new("RGBA", (width * SS, height * SS), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle([0, 0, width * SS - 1, height * SS - 1], radius=height * SS // 2, fill=(240, 240, 244, 255))
    im = im.resize((width, height), Image.LANCZOS)
    pad = height // 6
    im.alpha_composite(logo(height - 2 * pad), (pad * 2, pad))
    return im


def vector_foreground():
    """Ícone adaptativo do Android: raposa na zona segura do viewport 108x108."""
    def path(points):
        pts = [(24 + x * 60, 24 + y * 60) for x, y in points]
        return "M" + " L".join(f"{x:.2f},{y:.2f}" for x, y in pts) + " Z"

    paths = [f'  <path android:fillColor="#FFFFFF" android:pathData="{path(HEAD)}" />']
    paths += [f'  <path android:fillColor="#0F766E" android:pathData="{path(p)}" />' for p in DETAILS]
    return (
        '<?xml version="1.0" encoding="utf-8"?>\n'
        "<!-- Gerado por tools/gen-branding.py -->\n"
        '<vector xmlns:android="http://schemas.android.com/apk/res/android"\n'
        '    android:width="108dp"\n    android:height="108dp"\n'
        '    android:viewportWidth="108"\n    android:viewportHeight="108">\n'
        + "\n".join(paths)
        + "\n</vector>\n"
    )


def save(im, path):
    path.parent.mkdir(parents=True, exist_ok=True)
    im.save(path, lossless=True) if path.suffix == ".webp" else im.save(path)


def main():
    # Desktop: substitui os PNGs genéricos do branding "unofficial".
    for size in (16, 22, 24, 32, 48, 64, 128, 256):
        save(logo(size), ROOT / f"branding/default{size}.png")

    # Android: mesmos nomes e dimensões dos recursos de marca do Fenix (variante release).
    res = ROOT / "branding/android/res"
    launcher = {"mdpi": 48, "hdpi": 76, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
    for density, size in launcher.items():
        save(logo(size), res / f"mipmap-{density}/ic_launcher.webp")
        save(logo(size, "circle"), res / f"mipmap-{density}/ic_launcher_round.webp")
    wordmark = {"mdpi": (277, 80), "hdpi": (414, 120), "xhdpi": (552, 160), "xxhdpi": (828, 239), "xxxhdpi": (1103, 319)}
    for density, (w, h) in wordmark.items():
        for variant in ("normal", "private"):
            save(text_image(w, h, icon=True), res / f"drawable-{density}/ic_logo_wordmark_{variant}.webp")
    widget = {"mdpi": (338, 60), "hdpi": (507, 90), "xhdpi": (676, 120), "xxhdpi": (1014, 180)}
    for density, (w, h) in widget.items():
        save(search_widget(w, h), res / f"drawable-{density}/fenix_search_widget.webp")
    save(logo(160).crop((2, 0, 157, 160)), res / "drawable-nodpi/ic_wordmark_logo.webp")
    for variant in ("normal", "private"):
        save(text_image(419, 93), res / f"drawable-nodpi/ic_wordmark_text_{variant}.webp")
    (res / "drawable").mkdir(parents=True, exist_ok=True)
    (res / "drawable/ic_launcher_foreground.xml").write_text(vector_foreground())
    (res / "values").mkdir(parents=True, exist_ok=True)
    (res / "values/colors.xml").write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n<!-- Gerado por tools/gen-branding.py -->\n'
        '<resources>\n    <color name="ic_launcher_background">#0F766E</color>\n</resources>\n'
    )


if __name__ == "__main__":
    main()
