"""Gera os ícones do app (Android) a partir da marca \\O/ na fonte Anton.

🟡 O ícone ainda é decisão em aberto (docs/design.md › Ícone do app). Esta é a sugestão do design
system: fundo `wine` com \\O/ em `peach`. O Clippo Lab inverte as cores e leva "LAB" embaixo, para
não confundir os dois no celular. Para mudar, edite as constantes abaixo e rode de novo:

    cd app
    python tool/make_launcher_icons.py      # precisa do Pillow: pip install pillow

Gera, para cada sabor (main = Clippo, lab = Clippo Lab):
  - mipmap-*/ic_launcher.png             ícone quadrado para Android 7 e anteriores;
  - mipmap-*/ic_launcher_foreground.png  camada da frente do ícone adaptativo (Android 8+);
  - mipmap-anydpi-v26/ic_launcher.xml    ícone adaptativo (fundo de cor + frente + monocromático);
  - values/ic_launcher_colors.xml        a cor de fundo do ícone.
"""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

APP = Path(__file__).resolve().parent.parent
RES = APP / "android" / "app" / "src"
ANTON = APP / "assets" / "fonts" / "Anton-Regular.ttf"
ARCHIVO_BOLD = APP / "assets" / "fonts" / "Archivo-Bold.ttf"

# Mesmos valores de ClippoBrand em lib/core/theme/clippo_tokens.dart.
WINE = "#741A2F"
PEACH = "#FFC6A8"

MARK = "\\O/"

# Densidades do Android: fator sobre 1 dp.
DENSITIES = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}

FLAVORS = {
    # sabor: (fundo, marca, rótulo embaixo da marca)
    "main": (WINE, PEACH, None),
    "lab": (PEACH, WINE, "LAB"),
}


def draw_mark(size: int, box: float, color: str, label: str | None) -> Image.Image:
    """Desenha \\O/ (e o rótulo) centralizado numa imagem transparente `size`×`size`.

    `box` é a fração do lado que a marca ocupa na largura.
    """
    scale = 4  # desenha grande e reduz: bordas mais lisas
    big = size * scale
    img = Image.new("RGBA", (big, big), (0, 0, 0, 0))

    # A marca: mede numa fonte grande e ajusta para caber em `box` da largura.
    probe = ImageFont.truetype(str(ANTON), 1000)
    left, top, right, bottom = probe.getbbox(MARK)
    font_size = 1000 * (big * box) / (right - left)
    font = ImageFont.truetype(str(ANTON), round(font_size))
    left, top, right, bottom = font.getbbox(MARK)
    mark_w, mark_h = right - left, bottom - top

    label_font = label_h = gap = None
    if label:
        label_font = ImageFont.truetype(str(ARCHIVO_BOLD), round(mark_h * 0.26))
        l_left, l_top, l_right, l_bottom = label_font.getbbox(label)
        label_h = l_bottom - l_top
        gap = mark_h * 0.12

    total_h = mark_h + (label_h + gap if label else 0)
    y0 = (big - total_h) / 2
    draw = ImageDraw.Draw(img)
    draw.text(((big - mark_w) / 2 - left, y0 - top), MARK, font=font, fill=color)
    if label:
        l_left, l_top, l_right, l_bottom = label_font.getbbox(label)
        draw.text(
            ((big - (l_right - l_left)) / 2 - l_left, y0 + mark_h + gap - l_top),
            label,
            font=label_font,
            fill=color,
        )
    return img.resize((size, size), Image.LANCZOS)


def write(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")


ADAPTIVE_XML = """<?xml version="1.0" encoding="utf-8"?>
<!-- Gerado por tool/make_launcher_icons.py: edite lá, não aqui. -->
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background" />
    <foreground android:drawable="@mipmap/ic_launcher_foreground" />
    <monochrome android:drawable="@mipmap/ic_launcher_foreground" />
</adaptive-icon>
"""

COLORS_XML = """<?xml version="1.0" encoding="utf-8"?>
<!-- Gerado por tool/make_launcher_icons.py: edite lá, não aqui. -->
<resources>
    <color name="ic_launcher_background">{bg}</color>
</resources>
"""


def main() -> None:
    for flavor, (bg, fg, label) in FLAVORS.items():
        res = RES / flavor / "res"
        for density, factor in DENSITIES.items():
            folder = res / f"mipmap-{density}"
            folder.mkdir(parents=True, exist_ok=True)

            # Adaptivo: 108 dp, e só o círculo central de 66 dp aparece com certeza.
            fg_size = round(108 * factor)
            # Com rótulo, a marca encolhe para o conjunto caber no círculo.
            box = 0.32 if label else 0.38
            draw_mark(fg_size, box, fg, label).save(folder / "ic_launcher_foreground.png")

            # Legado: 48 dp, quadrado arredondado de fundo com a marca.
            size = round(48 * factor)
            scale = 4
            legacy = Image.new("RGBA", (size * scale, size * scale), (0, 0, 0, 0))
            ImageDraw.Draw(legacy).rounded_rectangle(
                (0, 0, size * scale - 1, size * scale - 1), radius=size * scale * 0.18, fill=bg
            )
            legacy = legacy.resize((size, size), Image.LANCZOS)
            legacy.alpha_composite(draw_mark(size, 0.66, fg, label))
            legacy.save(folder / "ic_launcher.png")

        write(res / "mipmap-anydpi-v26" / "ic_launcher.xml", ADAPTIVE_XML)
        write(res / "values" / "ic_launcher_colors.xml", COLORS_XML.format(bg=bg))
        print(f"{flavor}: ok")


if __name__ == "__main__":
    main()
