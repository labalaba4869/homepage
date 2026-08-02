from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parent
FRAME_SIZE = (192, 272)


def prepare_frame(index: int) -> None:
    source = ROOT / f"card_frame_function_{index}_large.png"
    target = ROOT / f"card_frame_function_{index}.png"
    image = Image.open(source).convert("RGBA")
    image = image.resize(FRAME_SIZE, Image.Resampling.LANCZOS)

    # Keep the artwork window transparent while preserving the name bar below it.
    pixels = image.load()
    for y in range(20, 150):
        for x in range(27, 166):
            red, green, blue, _alpha = pixels[x, y]
            pixels[x, y] = (red, green, blue, 0)

    image.save(target, optimize=True)


def prepare_hourglass() -> None:
    source = ROOT / "card_use_hourglass_large.png"
    target = ROOT / "card_use_hourglass.png"
    image = Image.open(source).convert("RGBA")
    alpha = image.getchannel("A")
    bounds = alpha.getbbox()
    if bounds is None:
        raise RuntimeError("Hourglass has no opaque pixels")

    left, top, right, bottom = bounds
    width = right - left
    height = bottom - top
    padding = max(width, height) // 20
    side = max(width, height) + padding * 2
    center_x = (left + right) // 2
    center_y = (top + bottom) // 2
    crop = (
        center_x - side // 2,
        center_y - side // 2,
        center_x - side // 2 + side,
        center_y - side // 2 + side,
    )
    image = image.crop(crop).resize((96, 96), Image.Resampling.LANCZOS)
    image.save(target, optimize=True)


for quality_index in range(5):
    prepare_frame(quality_index)
prepare_hourglass()
