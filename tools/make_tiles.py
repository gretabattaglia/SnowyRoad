"""Genera assets/tiles/terrain.png: tileset pixelart 32x32 (8 tile in una riga).

Uso:  python tools/make_tiles.py
Richiede Pillow (pip install pillow).

Indici tile (colonna nell'atlas):
  0 neve A   1 neve B   2 neve C (piccolo cumulo)   3 strada
  4 bordo strada alto (neve sopra)   5 bordo strada basso (neve sotto)
  6 neve con sassi   7 chiazza di ghiaccio
"""
import math
import random
from pathlib import Path

from PIL import Image

T = 32

SNOW = (236, 244, 250)
SNOW_LIGHT = (250, 253, 255)
SNOW_SHADE = (208, 224, 238)
SNOW_DEEP = (180, 200, 222)

ROAD = (124, 112, 106)
ROAD_DARK = (100, 90, 88)
ROAD_LIGHT = (148, 136, 128)
ROAD_TRACK = (88, 80, 80)

ICE = (200, 228, 244)
ICE_LIGHT = (232, 247, 255)
ROCK = (110, 112, 122)
ROCK_DARK = (78, 80, 92)


def snow_tile(rng, dots_light=10, dots_shade=8):
    im = Image.new("RGBA", (T, T), SNOW + (255,))
    px = im.load()
    for _ in range(dots_light):
        px[rng.randrange(T), rng.randrange(T)] = SNOW_LIGHT + (255,)
    for _ in range(dots_shade):
        x, y = rng.randrange(T), rng.randrange(T)
        px[x, y] = SNOW_SHADE + (255,)
        if rng.random() < 0.5:
            px[(x + 1) % T, y] = SNOW_SHADE + (255,)
    return im


def snow_drift(rng):
    im = snow_tile(rng, 6, 4)
    px = im.load()
    # piccolo cumulo: arco d'ombra periodico (si ripete bene tra tile)
    for x in range(6, 26):
        y = 20 - int(round(4 * math.sin((x - 6) / 19 * math.pi)))
        px[x, y] = SNOW_LIGHT + (255,)
        px[x, y + 1] = SNOW_SHADE + (255,)
        px[x, y + 2] = SNOW_SHADE + (255,)
    for x in range(8, 24):
        px[x, 23] = SNOW_DEEP + (255,)
    return im


def road_tile(rng):
    im = Image.new("RGBA", (T, T), ROAD + (255,))
    px = im.load()
    for y in (10, 11, 21, 22):  # solchi delle ruote
        for x in range(T):
            px[x, y] = ROAD_TRACK + (255,)
    for _ in range(40):
        px[rng.randrange(T), rng.randrange(T)] = ROAD_DARK + (255,)
    for _ in range(26):
        px[rng.randrange(T), rng.randrange(T)] = ROAD_LIGHT + (255,)
    for _ in range(6):  # fiocchi di neve sulla strada
        px[rng.randrange(T), rng.randrange(T)] = SNOW + (255,)
    return im


def edge_profile(x):
    # periodica con periodo 16 -> i tile affiancati si raccordano senza giunture
    return int(round(1.5 * math.sin(2 * math.pi * x / 16)))


def road_edge(rng, top=True):
    base = road_tile(rng)
    px = base.load()
    for x in range(T):
        depth = 8 + edge_profile(x)  # quanti pixel di neve dal bordo
        for i in range(depth + 3):
            y = i if top else T - 1 - i
            if i < depth:
                px[x, y] = SNOW + (255,)
                if rng.random() < 0.12:
                    px[x, y] = SNOW_LIGHT + (255,)
            elif i == depth:
                px[x, y] = SNOW_SHADE + (255,)
            elif i == depth + 1:
                px[x, y] = SNOW_DEEP + (255,)
            else:
                px[x, y] = ROAD_DARK + (255,)
    return base


def snow_rocks(rng):
    im = snow_tile(rng, 6, 4)
    px = im.load()
    for (cx, cy, r) in ((11, 14, 3), (20, 20, 2)):
        for dy in range(-r, r + 1):
            for dx in range(-r - 1, r + 2):
                if dx * dx / ((r + 1) ** 2) + dy * dy / (r ** 2) <= 1:
                    px[cx + dx, cy + dy] = ROCK + (255,)
        for dx in range(-r, r + 1):
            px[cx + dx, cy + r] = ROCK_DARK + (255,)
        px[cx - 1, cy - r + 1] = SNOW_LIGHT + (255,)
    return im


def ice_patch(rng):
    im = snow_tile(rng, 4, 4)
    px = im.load()
    for y in range(8, 24):
        for x in range(5, 27):
            if ((x - 16) / 11) ** 2 + ((y - 16) / 8) ** 2 <= 1:
                px[x, y] = ICE + (255,)
    for x in range(10, 18):
        px[x, 13] = ICE_LIGHT + (255,)
    for x in range(14, 22):
        px[x, 17] = ICE_LIGHT + (255,)
    return im


def main():
    rng = random.Random(42)
    tiles = [
        snow_tile(rng),
        snow_tile(rng, 14, 10),
        snow_drift(rng),
        road_tile(rng),
        road_edge(rng, top=True),
        road_edge(rng, top=False),
        snow_rocks(rng),
        ice_patch(rng),
    ]
    atlas = Image.new("RGBA", (T * len(tiles), T))
    for i, t in enumerate(tiles):
        atlas.paste(t, (i * T, 0))
    out = Path(__file__).resolve().parent.parent / "assets" / "tiles" / "terrain.png"
    out.parent.mkdir(parents=True, exist_ok=True)
    atlas.save(out)
    print("scritto", out)


if __name__ == "__main__":
    main()
