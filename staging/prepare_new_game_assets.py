from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parent
SHEET = Path(r"C:\Users\laba\.codex\generated_images\019f3c7c-aeac-7840-9ff6-2c55ff7c97eb\exec-9b3bf7b4-f8f7-4dac-9659-710b55e147d9.png")
PORTAL = Path(r"C:\Users\laba\.codex\generated_images\019f3c7c-aeac-7840-9ff6-2c55ff7c97eb\exec-00652aa1-bd70-4441-84f4-85c7da514cb6.png")


def is_magenta(pixel: tuple[int, int, int, int]) -> bool:
    red, green, blue, _alpha = pixel
    return red > 220 and green < 80 and blue > 170


def contiguous_ranges(values: list[bool]) -> list[tuple[int, int]]:
    ranges: list[tuple[int, int]] = []
    start = -1
    for index, enabled in enumerate(values + [False]):
        if enabled and start < 0:
            start = index
        elif not enabled and start >= 0:
            ranges.append((start, index))
            start = -1
    return ranges


def crop_card_sheet() -> None:
    image = Image.open(SHEET).convert("RGBA")
    width, height = image.size
    pixels = image.load()
    columns = [
        sum(is_magenta(pixels[x, y]) for y in range(height)) / height < 0.8
        for x in range(width)
    ]
    rows = [
        sum(is_magenta(pixels[x, y]) for x in range(width)) / width < 0.8
        for y in range(height)
    ]
    x_ranges = contiguous_ranges(columns)
    y_ranges = contiguous_ranges(rows)
    if len(x_ranges) != 3 or len(y_ranges) != 2:
        raise RuntimeError("The generated card sheet has an unexpected grid layout.")

    output_dir = ROOT / "card_art"
    output_dir.mkdir(parents=True, exist_ok=True)
    preview = Image.new("RGBA", (480, 300), (20, 25, 24, 255))
    card_ids = [101, 102, 103, 104, 105, 106]
    for index, card_id in enumerate(card_ids):
        column = index % 3
        row = index // 3
        left, right = x_ranges[column]
        top, bottom = y_ranges[row]
        panel = image.crop((left, top, right, bottom)).resize((160, 150), Image.Resampling.LANCZOS)
        panel.save(output_dir / f"card_art_{card_id}.png")
        preview.alpha_composite(panel, ((index % 3) * 160, (index // 3) * 150))
    preview.convert("RGB").save(ROOT / "card_art_preview.png")


def remove_portal_background() -> None:
    image = Image.open(PORTAL).convert("RGBA")
    pixels = image.load()
    for y in range(image.height):
        for x in range(image.width):
            red, green, blue, alpha = pixels[x, y]
            if red > 205 and green < 90 and blue > 150:
                pixels[x, y] = (red, green, blue, 0)
            elif red > 175 and blue > 125 and red > green * 2.3:
                pixels[x, y] = (red, green, blue, int(alpha * 0.18))
    image.thumbnail((256, 256), Image.Resampling.LANCZOS)
    image.save(ROOT / "return_portal.png")


if __name__ == "__main__":
    crop_card_sheet()
    remove_portal_background()
