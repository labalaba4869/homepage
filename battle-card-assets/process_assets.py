from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter


ROOT = Path(r"D:\Homepage Dev\battle-card-assets")
CARD_RAW = ROOT / "cards" / "raw"
CARD_FINAL = ROOT / "cards" / "final"
STATUS_KEYED = ROOT / "status" / "keyed"
STATUS_FINAL = ROOT / "status" / "final"

CARD_NAMES = {
    1: "Bandage",
    2: "Healing Spell",
    3: "Life Bloom",
    4: "Holy Blessing",
    5: "Stand Firm",
    6: "Rally",
    7: "Mend",
    8: "Inspire",
    9: "Agility",
    10: "Pierce",
    11: "Combo",
    12: "Seal",
}


def center_crop_aspect(image: Image.Image, aspect: float) -> Image.Image:
    width, height = image.size
    current = width / height
    if current > aspect:
        new_width = round(height * aspect)
        left = (width - new_width) // 2
        return image.crop((left, 0, left + new_width, height))
    new_height = round(width / aspect)
    top = (height - new_height) // 2
    return image.crop((0, top, width, top + new_height))


def process_cards() -> None:
    CARD_FINAL.mkdir(parents=True, exist_ok=True)
    for card_id in range(1, 13):
        source = Image.open(CARD_RAW / f"card_art_{card_id}.png").convert("RGB")
        cropped = center_crop_aspect(source, 160 / 150)
        final = cropped.resize((160, 150), Image.Resampling.LANCZOS)
        final = final.filter(ImageFilter.UnsharpMask(radius=0.6, percent=60, threshold=2))
        final.save(CARD_FINAL / f"card_art_{card_id}.png", optimize=True)


def crop_alpha_square(image: Image.Image, padding_ratio: float = 0.12) -> Image.Image:
    alpha = image.getchannel("A")
    bbox = alpha.getbbox()
    if bbox is None:
        raise ValueError("transparent image has no visible pixels")
    left, top, right, bottom = bbox
    width = right - left
    height = bottom - top
    side = max(width, height)
    padding = round(side * padding_ratio)
    side += padding * 2
    center_x = (left + right) / 2
    center_y = (top + bottom) / 2
    crop_left = round(center_x - side / 2)
    crop_top = round(center_y - side / 2)
    canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    source_left = max(0, crop_left)
    source_top = max(0, crop_top)
    source_right = min(image.width, crop_left + side)
    source_bottom = min(image.height, crop_top + side)
    fragment = image.crop((source_left, source_top, source_right, source_bottom))
    canvas.alpha_composite(
        fragment,
        (source_left - crop_left, source_top - crop_top),
    )
    return canvas


def process_statuses() -> None:
    STATUS_FINAL.mkdir(parents=True, exist_ok=True)
    for source_path in sorted(STATUS_KEYED.glob("status_*.png")):
        source = Image.open(source_path).convert("RGBA")
        cropped = crop_alpha_square(source)
        final = cropped.resize((32, 32), Image.Resampling.LANCZOS)
        final = final.filter(ImageFilter.UnsharpMask(radius=0.45, percent=75, threshold=1))
        if final.getpixel((0, 0))[3] != 0:
            raise ValueError(f"{source_path.name} does not have a transparent corner")
        final.save(STATUS_FINAL / source_path.name, optimize=True)


def make_card_contact_sheet() -> None:
    cell_width, cell_height = 180, 182
    sheet = Image.new("RGB", (cell_width * 4, cell_height * 3), "#101a18")
    draw = ImageDraw.Draw(sheet)
    for index, card_id in enumerate(range(1, 13)):
        x = (index % 4) * cell_width
        y = (index // 4) * cell_height
        art = Image.open(CARD_FINAL / f"card_art_{card_id}.png").convert("RGB")
        sheet.paste(art, (x + 10, y + 8))
        draw.text((x + 10, y + 161), f"{card_id:02d}  {CARD_NAMES[card_id]}", fill="#f2d47c")
    sheet.save(ROOT / "function_cards_contact_sheet.png", optimize=True)


def make_status_contact_sheet() -> None:
    names = [path.stem.removeprefix("status_") for path in sorted(STATUS_FINAL.glob("*.png"))]
    cell = 96
    sheet = Image.new("RGBA", (cell * 3, cell * 3), "#101a18")
    draw = ImageDraw.Draw(sheet)
    for index, name in enumerate(names):
        x = (index % 3) * cell
        y = (index // 3) * cell
        icon = Image.open(STATUS_FINAL / f"status_{name}.png").convert("RGBA")
        preview = icon.resize((48, 48), Image.Resampling.NEAREST)
        sheet.alpha_composite(preview, (x + 24, y + 8))
        draw.text((x + 6, y + 62), name, fill="#d8e7dc")
    sheet.save(ROOT / "status_icons_contact_sheet.png", optimize=True)


process_cards()
process_statuses()
make_card_contact_sheet()
make_status_contact_sheet()
print("PROCESSED_CARD_ASSETS")
