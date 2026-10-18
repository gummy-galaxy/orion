"""Post-processing for the concept gallery: a film finish, riso prints, and pixel art.

Usage:
  treat.py film <in> <out>
  treat.py riso <in> <out> [inks]
  treat.py pixel <in> <out> [width]
"""
import sys

import numpy as np
from PIL import Image, ImageFilter

RNG = np.random.default_rng(7)


def load(path):
    return np.asarray(Image.open(path).convert("RGB")).astype(np.float32) / 255.0


def save(array, path, quality=88):
    image = Image.fromarray((np.clip(array, 0, 1) * 255).astype(np.uint8))
    if path.endswith(".jpg"):
        image.save(path, quality=quality, optimize=True, progressive=True)
    else:
        image.save(path, optimize=True)


def film(source, target):
    """Bloom on the highlights, a soft vignette, and fine grain, the way a concept frame gets finished."""
    image = load(source)
    height, width, _ = image.shape
    luminance = image @ np.array([0.2126, 0.7152, 0.0722], dtype=np.float32)
    highlights = image * np.clip((luminance - 0.62) / 0.38, 0, 1)[..., None]
    bloom_image = Image.fromarray((highlights * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(width / 60))
    bloom = np.asarray(bloom_image).astype(np.float32) / 255.0
    image = 1 - (1 - image) * (1 - bloom * 0.55)
    y, x = np.mgrid[0:height, 0:width].astype(np.float32)
    distance = np.sqrt(((x - width / 2) / (width / 2)) ** 2 + ((y - height / 2) / (height / 2)) ** 2)
    image *= (1 - 0.32 * np.clip(distance - 0.45, 0, 1) ** 1.6)[..., None]
    image += (RNG.standard_normal((height, width, 1)).astype(np.float32)) * 0.018
    save(image, target)


INK_SETS = {
    "pink-blue-yellow": [("#ff48b0", 15), ("#0078bf", 75), ("#ffe800", 0)],
    "pink-teal": [("#ff48b0", 15), ("#00838a", 75)],
    "orange-violet": [("#ff6c2f", 20), ("#765ba7", 70)],
}


def hex_rgb(value):
    return np.array([int(value[i:i + 2], 16) / 255 for i in (1, 3, 5)], dtype=np.float32)


def halftone(coverage, angle, period, shift):
    height, width = coverage.shape
    y, x = np.mgrid[0:height, 0:width].astype(np.float32)
    x += shift[0]
    y += shift[1]
    theta = np.radians(angle)
    u = (x * np.cos(theta) + y * np.sin(theta)) / period
    v = (-x * np.sin(theta) + y * np.cos(theta)) / period
    du, dv = u - np.floor(u) - 0.5, v - np.floor(v) - 0.5
    distance = np.sqrt(du * du + dv * dv)
    radius = np.sqrt(np.clip(coverage, 0, 1)) * 0.62
    edge = 1.2 / period
    return np.clip((radius - distance) / edge + 0.5, 0, 1)


def riso(source, target, inks="pink-blue-yellow"):
    """Separate a render into spot inks, screen each one, knock it a few pixels out of register, and print on cream."""
    image = load(source)
    height, width, _ = image.shape
    paper = hex_rgb("#f3ede2")
    out = np.ones_like(image) * paper
    out *= (1 - RNG.random((height, width, 1)).astype(np.float32) * 0.05)
    period = max(5.0, width / 190)
    for index, (ink_hex, angle) in enumerate(INK_SETS[inks]):
        ink = hex_rgb(ink_hex)
        absorbed = 1 - ink
        channel = int(np.argmax(absorbed))
        coverage = np.clip(1 - image[..., channel] * 1.05, 0, 1) ** 1.15
        if len(INK_SETS[inks]) == 2 and index == 1:
            coverage = np.clip(1 - image.mean(axis=2) * 1.1, 0, 1) ** 1.2
        shift = RNG.uniform(-4, 4, 2) * (width / 1080)
        mask = halftone(coverage, angle, period, shift)
        mask *= 0.86 + RNG.random((height, width)).astype(np.float32) * 0.14
        out *= 1 - mask[..., None] * (1 - ink) * 0.92
    save(out, target)


BAYER = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]], dtype=np.float32) / 16 - 0.5


def pixel(source, target, small_width=180):
    """Shrink to a pixel canvas, order-dither into a small palette, and scale back up crisp."""
    image = Image.open(source).convert("RGB")
    small_height = round(image.height * small_width / image.width)
    small = np.asarray(image.resize((small_width, small_height), Image.BOX)).astype(np.float32) / 255.0
    tiled = np.tile(BAYER, (small_height // 4 + 1, small_width // 4 + 1))[:small_height, :small_width]
    small = np.clip(small + tiled[..., None] * 0.14, 0, 1)
    quantized = Image.fromarray((small * 255).astype(np.uint8)).quantize(colors=14, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert("RGB")
    scale = max(1, round(1080 / small_width))
    quantized.resize((small_width * scale, small_height * scale), Image.NEAREST).save(target, optimize=True)


def gc(source, target, small_width=640):
    """Sixth-generation console output: a 480p framebuffer in 16-bit color, dithered, scaled back up soft, with bloom."""
    image = Image.open(source).convert("RGB")
    small_height = round(image.height * small_width / image.width)
    small = np.asarray(image.resize((small_width, small_height), Image.BILINEAR)).astype(np.float32) / 255.0
    tiled = np.tile(BAYER, (small_height // 4 + 1, small_width // 4 + 1))[:small_height, :small_width][..., None]
    levels = np.array([31, 63, 31], dtype=np.float32)
    small = np.round(np.clip(small + tiled / levels, 0, 1) * levels) / levels
    big = Image.fromarray((small * 255).astype(np.uint8)).resize((image.width, image.height), Image.BILINEAR)
    array = np.asarray(big).astype(np.float32) / 255.0
    luminance = array @ np.array([0.2126, 0.7152, 0.0722], dtype=np.float32)
    highlights = array * np.clip((luminance - 0.86) / 0.14, 0, 1)[..., None]
    bloom = np.asarray(Image.fromarray((highlights * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(image.width / 70))).astype(np.float32) / 255.0
    array = 1 - (1 - array) * (1 - bloom * 0.35)
    rows = (np.arange(image.height) // max(1, round(image.height / small_height))) % 2
    array *= (1 - rows * 0.06)[:, None, None]
    save(array, target)


if __name__ == "__main__":
    mode, source, destination, *rest = sys.argv[1:]
    {"film": film, "riso": riso, "pixel": pixel, "gc": gc}[mode](source, destination, *[int(value) if value.isdigit() else value for value in rest])
