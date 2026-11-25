#!/usr/bin/env python3
"""Gera os ícones e wordmarks do ColdFox em branding/ a partir de branding/logo.svg.

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
INK = (11, 20, 38, 255)  # fundo escuro dos ícones do Android: o logo tem partes brancas
INK_HEX = "#0B1426"
BLUE = (20, 140, 255, 255)
VIOLET = (128, 0, 215, 255)  # cor da navegação privativa do Firefox  # texto dos wordmarks: legível em tema claro e escuro
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


def text_image(width, height, text="ColdFox", icon=False):
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
    d.text((x + icon_w + gap - left, (height - (bottom - top)) // 2 - top), text, font=font, fill=BLUE)
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
    """Ícone adaptativo do Android: os paths e degradês do SVG (viewBox 512) na zona segura de 108x108."""
    svg = LOGO.read_text()
    grads = {}
    for gid, x1, y1, x2, y2, stops in re.findall(
        r'<linearGradient id="(\w+)" gradientUnits="userSpaceOnUse" x1="([\d.-]+)" y1="([\d.-]+)" x2="([\d.-]+)" y2="([\d.-]+)">(.*?)</linearGradient>', svg
    ):
        items = "".join(
            f'\n            <item android:offset="{off}" android:color="#FF{color[1:]}" />'
            for off, color in re.findall(r'<stop offset="([\d.]+)" stop-color="(#[0-9A-Fa-f]{6})"/>', stops)
        )
        grads[gid] = (
            '      <aapt:attr name="android:fillColor">\n'
            f'        <gradient android:type="linear" android:startX="{x1}" android:startY="{y1}" android:endX="{x2}" android:endY="{y2}">'
            f"{items}\n        </gradient>\n      </aapt:attr>\n"
        )
    paths = re.findall(r'<path fill="(#[0-9A-Fa-f]{6}|url\(#\w+\))" fill-rule="evenodd" d="([^"]+)"/>', svg)
    assert paths and len(paths) == svg.count("<path"), "paths de logo.svg fora do formato esperado"
    scale = 60 / 512
    body = ""
    for fill, d in paths:
        if fill.startswith("#"):
            body += f'    <path android:fillColor="{fill}" android:fillType="evenOdd" android:pathData="{d}" />\n'
        else:
            body += f'    <path android:fillType="evenOdd" android:pathData="{d}">\n{grads[fill[5:-1]]}    </path>\n'
    return (
        '<?xml version="1.0" encoding="utf-8"?>\n'
        "<!-- Gerado por tools/gen-branding.py a partir de branding/logo.svg -->\n"
        '<vector xmlns:android="http://schemas.android.com/apk/res/android"\n'
        '    xmlns:aapt="http://schemas.android.com/aapt"\n'
        '    android:width="108dp"\n    android:height="108dp"\n'
        '    android:viewportWidth="108"\n    android:viewportHeight="108">\n'
        f'  <group android:translateX="24" android:translateY="24" android:scaleX="{scale:.6f}" android:scaleY="{scale:.6f}">\n'
        + body
        + "  </group>\n</vector>\n"
    )


def wordmark_svg(fallback):
    """"ColdFox" em curvas (sem depender de fonte instalada), na cor do contexto do Firefox."""
    import cairocffi as cairo

    ctx = cairo.Context(cairo.RecordingSurface(cairo.CONTENT_ALPHA, None))
    ctx.select_font_face("DejaVu Sans", cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_BOLD)
    ctx.set_font_size(100)
    xb, yb, w, h, _, _ = ctx.text_extents("ColdFox")
    ctx.move_to(-xb, -yb)
    ctx.text_path("ColdFox")
    f = lambda *v: " ".join(f"{x:.2f}".rstrip("0").rstrip(".") for x in v)
    cmds = {cairo.PATH_MOVE_TO: "M", cairo.PATH_LINE_TO: "L", cairo.PATH_CURVE_TO: "C", cairo.PATH_CLOSE_PATH: "Z"}
    d = "".join(cmds[k] + f(*pts) for k, pts in ctx.copy_path())
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w:g} {h:g}" fill="context-fill {fallback}">'
        f'<title>ColdFox</title><path d="{d}"/></svg>\n'
    )


def private_badge(size):
    """Selo da navegação privativa: máscara branca num círculo violeta."""
    big = size * SS
    im = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.ellipse([0, 0, big - 1, big - 1], fill=VIOLET)
    cx, cy = big / 2, big * 0.5
    mw, mh = big * 0.62, big * 0.32
    d.rounded_rectangle([cx - mw / 2, cy - mh / 2, cx + mw / 2, cy + mh / 2], radius=mh * 0.45, fill=(255, 255, 255, 255))
    for side in (-1, 1):  # olhos
        ex = cx + side * mw * 0.24
        d.ellipse([ex - mw * 0.14, cy - mh * 0.2, ex + mw * 0.14, cy + mh * 0.16], fill=VIOLET)
    return im.resize((size, size), Image.LANCZOS)


def private_icon(size):
    """Selo grande com o logo no canto inferior direito (como o ícone do Firefox)."""
    im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    b = round(size * 0.86)
    im.alpha_composite(private_badge(b), (0, 0))
    lg = round(size * 0.5)
    im.alpha_composite(render(lg), (size - lg, size - lg))
    return im


def centered(size, inner, bg=(0, 0, 0, 0), image=None):
    im = Image.new("RGBA", size, bg)
    image = image or render(inner)
    im.alpha_composite(image, ((size[0] - image.width) // 2, (size[1] - image.height) // 2))
    return im


def banner(size, logo_size, text_size, bg=INK, fg=(255, 255, 255, 255), logo_y=None):
    """Fundo escuro, logo centralizado e "ColdFox" embaixo."""
    w, h = size
    im = Image.new("RGBA", size, bg)
    font = ImageFont.truetype(FONT, text_size)
    d = ImageDraw.Draw(im)
    left, top, right, bottom = d.textbbox((0, 0), "ColdFox", font=font)
    gap = text_size // 2
    y = logo_y if logo_y is not None else (h - logo_size - gap - (bottom - top)) // 2
    im.alpha_composite(render(logo_size), ((w - logo_size) // 2, y))
    d.text(((w - (right - left)) // 2 - left, y + logo_size + gap - top), "ColdFox", font=font, fill=fg)
    return im


def document_icon(size):
    """Página com a ponta dobrada e o logo dentro (arquivos .html associados ao ColdFox)."""
    big = size * SS
    im = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    x0, x1, y0, y1, fold = big * 0.14, big * 0.86, big * 0.04, big * 0.96, big * 0.2
    d.polygon([(x0, y0), (x1 - fold, y0), (x1, y0 + fold), (x1, y1), (x0, y1)], fill=(245, 248, 252, 255), outline=(150, 160, 175, 255), width=max(SS, big // 128))
    d.polygon([(x1 - fold, y0), (x1 - fold, y0 + fold), (x1, y0 + fold)], fill=(200, 208, 220, 255))
    im = im.resize((size, size), Image.LANCZOS)
    lg = round(size * 0.56)
    im.alpha_composite(render(lg), ((size - lg) // 2, round(size * 0.3)))
    return im


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

    # Telas secundárias do desktop (no branding "unofficial" mostravam "Nightly" e um globo).
    br = ROOT / "branding"
    content = br / "content"
    for name, size in (("about-logo.png", 192), ("about-logo@2x.png", 384)):
        save(render(size), content / name)
    for name, size in (("about-logo-private.png", 192), ("about-logo-private@2x.png", 384)):
        save(private_icon(size), content / name)
    (content / "about-logo.svg").write_text(LOGO.read_text())
    (content / "about-wordmark.svg").write_text(wordmark_svg("#fff"))  # janela "Sobre"
    (content / "firefox-wordmark.svg").write_text(wordmark_svg(INK_HEX))  # nova aba
    save(banner((300, 236), 128, 30).convert("RGB"), content / "about.png")
    # Windows: bloco do menu Iniciar, navegação privativa, documentos e instalador.
    for name, size in (("VisualElements_70.png", 142), ("VisualElements_150.png", 300)):
        save(centered((size, size), round(size * 0.62)), br / name)
    for name, size in (("PrivateBrowsing_70.png", 142), ("PrivateBrowsing_150.png", 300)):
        save(centered((size, size), 0, image=private_icon(round(size * 0.62))), br / name)
    private_icon(256).save(br / "pbmode.ico", sizes=[(n, n) for n in (16, 32, 48, 256)])
    document_icon(256).save(br / "document.ico", sizes=[(n, n) for n in (16, 32, 48, 256)])
    save(banner((164, 314), 120, 22, logo_y=70).convert("RGB"), br / "wizWatermark.bmp")
    header = centered((57, 57), 48, bg=(255, 255, 255, 255))
    for name, x in (("wizHeader.bmp", 150 - 57), ("wizHeaderRTL.bmp", 0)):
        im = Image.new("RGBA", (150, 57), (255, 255, 255, 255))
        im.alpha_composite(header, (x, 0))
        save(im.convert("RGB"), br / name)
    doc = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    doc.alpha_composite(document_icon(824), (100, 100))
    doc.save(br / "document.icns")

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
