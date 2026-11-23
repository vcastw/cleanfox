#!/usr/bin/env python3
"""Gera os ícones e wordmarks do CleanFox em branding/ a partir de branding/logo.svg.

Os arquivos gerados ficam commitados; rode de novo só se o logo mudar.
Requer Pillow, CairoSVG e a fonte DejaVu Sans Bold:  python3 tools/gen-branding.py
"""
import io
import re
from pathlib import Path

import cairosvg
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
LOGO = ROOT / "branding/logo.svg"
INK = (28, 27, 34, 255)  # fundo escuro dos ícones do Android: o logo tem partes brancas
INK_HEX = "#1C1B22"
ORANGE = (254, 99, 1, 255)  # texto dos wordmarks: legível em tema claro e escuro
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
SS = 4  # supersampling das formas de fundo


def render(size):
    """Rasteriza o logo SVG em size x size, fundo transparente."""
    png = cairosvg.svg2png(url=str(LOGO), output_width=size, output_height=size)
    return Image.open(io.BytesIO(png)).convert("RGBA")


def logo(size, shape="none"):
    """Logo puro (shape="none") ou sobre fundo escuro arredondado/circular (Android)."""
    if shape == "none":
        return render(size)
    big = size * SS
    im = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    if shape == "circle":
        d.ellipse([0, 0, big - 1, big - 1], fill=INK)
    else:
        d.rounded_rectangle([0, 0, big - 1, big - 1], radius=big * 0.22, fill=INK)
    im = im.resize((size, size), Image.LANCZOS)
    inner = round(size * 0.74)
    im.alpha_composite(render(inner), ((size - inner) // 2, (size - inner) // 2))
    return im


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
    d.text((x + icon_w + gap - left, (height - (bottom - top)) // 2 - top), text, font=font, fill=ORANGE)
    return im


def search_widget(width, height):
    im = Image.new("RGBA", (width * SS, height * SS), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle([0, 0, width * SS - 1, height * SS - 1], radius=height * SS // 2, fill=INK)
    im = im.resize((width, height), Image.LANCZOS)
    pad = height // 6
    im.alpha_composite(logo(height - 2 * pad), (pad * 2, pad))
    return im


def vector_foreground():
    """Ícone adaptativo do Android: os paths do SVG (viewBox 512) na zona segura de 108x108."""
    paths = re.findall(r'<path fill="(#[0-9A-Fa-f]{6})" fill-rule="evenodd" d="([^"]+)"', LOGO.read_text())
    assert paths, "nenhum <path> encontrado em logo.svg"
    scale = 60 / 512
    body = "\n".join(
        f'    <path android:fillColor="{color}" android:fillType="evenOdd" android:pathData="{d}" />'
        for color, d in paths
    )
    return (
        '<?xml version="1.0" encoding="utf-8"?>\n'
        "<!-- Gerado por tools/gen-branding.py a partir de branding/logo.svg -->\n"
        '<vector xmlns:android="http://schemas.android.com/apk/res/android"\n'
        '    android:width="108dp"\n    android:height="108dp"\n'
        '    android:viewportWidth="108"\n    android:viewportHeight="108">\n'
        f'  <group android:translateX="24" android:translateY="24" android:scaleX="{scale:.6f}" android:scaleY="{scale:.6f}">\n'
        + body
        + "\n  </group>\n</vector>\n"
    )


def save(im, path):
    path.parent.mkdir(parents=True, exist_ok=True)
    im.save(path, lossless=True) if path.suffix == ".webp" else im.save(path)


def main():
    # Desktop: substitui os PNGs genéricos do branding "unofficial".
    for size in (16, 22, 24, 32, 48, 64, 128, 256):
        save(logo(size), ROOT / f"branding/default{size}.png")
    # Ícone principal do Windows (.ico) e do macOS (.icns).
    ico_sizes = [(n, n) for n in (16, 24, 32, 48, 64, 128, 256)]
    for name in ("firefox.ico", "firefox64.ico"):
        logo(256).save(ROOT / "branding" / name, sizes=ico_sizes)
    # No macOS os ícones ocupam ~80% do quadro, com margem transparente.
    icns = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    icns.alpha_composite(render(824), (100, 100))
    icns.save(ROOT / "branding/firefox.icns")

    # Android: mesmos nomes e dimensões dos recursos de marca do Fenix (variante release).
    res = ROOT / "branding/android/res"
    launcher = {"mdpi": 48, "hdpi": 76, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
    for density, size in launcher.items():
        save(logo(size, "rounded"), res / f"mipmap-{density}/ic_launcher.webp")
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
        f'<resources>\n    <color name="ic_launcher_background">{INK_HEX}</color>\n</resources>\n'
    )


if __name__ == "__main__":
    main()
