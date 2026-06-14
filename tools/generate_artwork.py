"""Generates all BrickRain channel artwork required by the Roku manifest.

Pixel-art wordmark built from rectangles (no fonts needed), tetromino rain
decoration. Original artwork, no copyright concerns.

Outputs (Roku manifest requirements):
  icon_focus_fhd.png  540x405  (mm_icon_focus_fhd)
  icon_focus_hd.png   290x218  (mm_icon_focus_hd)
  icon_focus_sd.png   246x140  (mm_icon_focus_sd)
  splash_fhd.png     1920x1080 (splash_screen_fhd)
  splash_hd.png      1280x720  (splash_screen_hd)
  splash_sd.png       720x480  (splash_screen_sd)
"""

import random
from pathlib import Path

from PIL import Image, ImageDraw

OUTPUT_DIR = Path(__file__).resolve().parent.parent / "assets" / "images"

# Classic falling-blocks palette (one color per tetromino type)
PALETTE = [
    (0, 240, 240),   # cyan / I
    (240, 240, 0),   # yellow / O
    (160, 0, 240),   # purple / T
    (0, 240, 0),     # green / S
    (240, 0, 0),     # red / Z
    (60, 120, 255),  # blue / J
    (240, 160, 0),   # orange / L
]
BG_TOP = (8, 10, 34)
BG_BOTTOM = (26, 22, 64)
WHITE = (245, 245, 250)

PIXEL_FONT = {
    "B": ["XXXX.", "X...X", "X...X", "XXXX.", "X...X", "X...X", "XXXX."],
    "R": ["XXXX.", "X...X", "X...X", "XXXX.", "X.X..", "X..X.", "X...X"],
    "I": ["XXXXX", "..X..", "..X..", "..X..", "..X..", "..X..", "XXXXX"],
    "C": [".XXXX", "X....", "X....", "X....", "X....", "X....", ".XXXX"],
    "K": ["X...X", "X..X.", "X.X..", "XX...", "X.X..", "X..X.", "X...X"],
    "A": [".XXX.", "X...X", "X...X", "XXXXX", "X...X", "X...X", "X...X"],
    "N": ["X...X", "XX..X", "XX..X", "X.X.X", "X..XX", "X..XX", "X...X"],
}
GLYPH_W, GLYPH_H, TRACKING = 5, 7, 1

TETROMINOES = {
    "I": [(0, 0), (1, 0), (2, 0), (3, 0)],
    "O": [(0, 0), (1, 0), (0, 1), (1, 1)],
    "T": [(0, 0), (1, 0), (2, 0), (1, 1)],
    "S": [(1, 0), (2, 0), (0, 1), (1, 1)],
    "Z": [(0, 0), (1, 0), (1, 1), (2, 1)],
    "J": [(0, 0), (0, 1), (1, 1), (2, 1)],
    "L": [(2, 0), (0, 1), (1, 1), (2, 1)],
}


def text_width(text: str, scale: int) -> int:
    return (len(text) * (GLYPH_W + TRACKING) - TRACKING) * scale


def draw_block(draw: ImageDraw.ImageDraw, x: int, y: int, size: int, color) -> None:
    """One brick with a lighter top-left bevel for the retro look."""
    draw.rectangle([x, y, x + size - 1, y + size - 1], fill=color)
    bevel = tuple(min(255, c + 70) for c in color)
    edge = max(1, size // 6)
    draw.rectangle([x, y, x + size - 1, y + edge - 1], fill=bevel)
    draw.rectangle([x, y, x + edge - 1, y + size - 1], fill=bevel)


def draw_pixel_text(draw, text, origin_x, origin_y, scale, colors) -> None:
    cursor_x = origin_x
    for index, letter in enumerate(text):
        color = colors[index % len(colors)]
        for row, line in enumerate(PIXEL_FONT[letter]):
            for col, cell in enumerate(line):
                if cell == "X":
                    draw_block(draw, cursor_x + col * scale,
                               origin_y + row * scale, scale, color)
        cursor_x += (GLYPH_W + TRACKING) * scale


def draw_background(image: Image.Image) -> None:
    draw = ImageDraw.Draw(image)
    width, height = image.size
    for y in range(height):
        blend = y / height
        color = tuple(int(t + (b - t) * blend) for t, b in zip(BG_TOP, BG_BOTTOM))
        draw.line([(0, y), (width, y)], fill=color)


def draw_tetromino_rain(image: Image.Image, count: int, block_size: int, seed: int = 7) -> None:
    rng = random.Random(seed)
    draw = ImageDraw.Draw(image, "RGBA")
    width, height = image.size
    shapes = list(TETROMINOES.values())
    for _ in range(count):
        shape = rng.choice(shapes)
        color = rng.choice(PALETTE) + (70,)  # translucent, stays in background
        ox = rng.randint(0, width - 4 * block_size)
        oy = rng.randint(0, height - 2 * block_size)
        for bx, by in shape:
            x, y = ox + bx * block_size, oy + by * block_size
            draw.rectangle([x, y, x + block_size - 1, y + block_size - 1], fill=color)


def compose(width: int, height: int, scale: int, rain_blocks: int, rain_size: int) -> Image.Image:
    image = Image.new("RGB", (width, height))
    draw_background(image)
    draw_tetromino_rain(image, rain_blocks, rain_size)
    draw = ImageDraw.Draw(image)

    line1, line2 = "BRICK", "RAIN"
    block_gap = 2 * scale
    total_height = GLYPH_H * scale * 2 + block_gap
    top = (height - total_height) // 2
    draw_pixel_text(draw, line1, (width - text_width(line1, scale)) // 2, top,
                    scale, PALETTE)
    draw_pixel_text(draw, line2, (width - text_width(line2, scale)) // 2,
                    top + GLYPH_H * scale + block_gap, scale,
                    [WHITE, WHITE, WHITE, WHITE])
    return image


def main() -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    targets = {
        "icon_focus_fhd.png": (540, 405, 11, 8, 18),
        "icon_focus_hd.png": (290, 218, 6, 6, 10),
        "icon_focus_sd.png": (246, 140, 4, 5, 9),
        "splash_fhd.png": (1920, 1080, 22, 26, 34),
        "splash_hd.png": (1280, 720, 15, 22, 24),
        "splash_sd.png": (720, 480, 9, 16, 16),
    }
    for name, (width, height, scale, rain, rain_size) in targets.items():
        compose(width, height, scale, rain, rain_size).save(OUTPUT_DIR / name)
        print(f"  {name} ({width}x{height})")


if __name__ == "__main__":
    main()
