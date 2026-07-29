#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Uygulama simgesini üretir.

Web sitesindeki favicon.svg ile aynı tasarım: köşegen degrade zemin ve
beyaz "Y" işareti. İki platformun simgesi aynı olsun diye aynı renk ve
aynı geometri kullanılıyor.

iOS kuralları:
  * 1024x1024, kare
  * ALFA KANALI OLMAMALI — saydamlık içeren simge App Store Connect
    tarafından reddedilir, üstelik hata mesajı yükleme bittikten
    sonra e-postayla gelir.
  * Köşeler yuvarlatılmaz; maskeyi iOS kendisi uygular.

    pip install pillow && python3 tools/make_appicon.py
"""

from __future__ import annotations

import os

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(ROOT, "Resources", "Assets.xcassets", "AppIcon.appiconset")

SIZE = 1024
START = (0x3B, 0x6F, 0xE0)     # web: --acc
END = (0x9B, 0x6B, 0xFF)       # web: --acc-3

# favicon.svg'deki 64x64 yol, köşe noktalarına açılmış hâli
Y_PATH_64 = [
    (17, 18), (25.4, 18), (32, 29.2), (38.6, 18), (47, 18),
    (36.2, 35.6), (36.2, 46), (27.8, 46), (27.8, 35.6),
]


def diagonal_gradient(size: int) -> Image.Image:
    """Sol üstten sağ alta doğru köşegen degrade."""
    img = Image.new("RGB", (size, size))
    pixels = img.load()
    denom = 2 * (size - 1)
    for y in range(size):
        for x in range(size):
            t = (x + y) / denom
            pixels[x, y] = (
                round(START[0] + (END[0] - START[0]) * t),
                round(START[1] + (END[1] - START[1]) * t),
                round(START[2] + (END[2] - START[2]) * t),
            )
    return img


def build() -> None:
    base = diagonal_gradient(SIZE)

    # "Y"yi 4 katı çözünürlükte çizip küçültüyoruz: PIL'in polygon
    # çizimi kenar yumuşatma yapmaz, bu yolla kenarlar pürüzsüz çıkar.
    scale = 4
    mask = Image.new("L", (SIZE * scale, SIZE * scale), 0)
    factor = (SIZE * scale) / 64
    ImageDraw.Draw(mask).polygon([(x * factor, y * factor) for x, y in Y_PATH_64], fill=255)
    mask = mask.resize((SIZE, SIZE), Image.LANCZOS)

    icon = Image.composite(Image.new("RGB", (SIZE, SIZE), (255, 255, 255)), base, mask)

    os.makedirs(OUT_DIR, exist_ok=True)
    path = os.path.join(OUT_DIR, "AppIcon-1024.png")
    icon.save(path, "PNG")

    # Doğrulama: alfa kanalı kalmamalı.
    check = Image.open(path)
    assert check.mode == "RGB", "simgede alfa kanalı var — App Store reddeder"
    assert check.size == (SIZE, SIZE)
    print("AppIcon-1024.png yazıldı (%dx%d, %s)" % (*check.size, check.mode))


if __name__ == "__main__":
    build()
