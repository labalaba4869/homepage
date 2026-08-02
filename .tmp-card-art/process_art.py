import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(r"D:\Homepage Dev\.tmp-card-art")
RAW_DIR = ROOT / "raw"
FINAL_DIR = ROOT / "final"
CARDS_PATH = ROOT / "cards.json"
FRAME_DIR = Path(
    r"D:\GameDevelop\Godot\card-search-and-attack\assets\art\cards\frames"
)

QUALITY_FRAME = {
    0: "card_frame_0_white.png",
    1: "card_frame_1_green.png",
    2: "card_frame_2_blue.png",
    3: "card_frame_3_purple.png",
    4: "card_frame_4_gold.png",
}


def crop_to_ratio(image: Image.Image, width_ratio: int, height_ratio: int) -> Image.Image:
    target_ratio = width_ratio / height_ratio
    source_ratio = image.width / image.height
    if source_ratio > target_ratio:
        crop_width = round(image.height * target_ratio)
        left = (image.width - crop_width) // 2
        return image.crop((left, 0, left + crop_width, image.height))
    crop_height = round(image.width / target_ratio)
    top = (image.height - crop_height) // 2
    return image.crop((0, top, image.width, top + crop_height))


def main() -> None:
    cards = json.loads(CARDS_PATH.read_text(encoding="utf-8"))
    FINAL_DIR.mkdir(parents=True, exist_ok=True)

    frames = {
        quality: Image.open(FRAME_DIR / filename).convert("RGBA")
        for quality, filename in QUALITY_FRAME.items()
    }
    previews = []
    manifest = []

    for card in cards:
        card_id = int(card["card_id"])
        source_path = RAW_DIR / f"card_art_{card_id}.png"
        output_path = FINAL_DIR / f"card_art_{card_id}.png"
        source = Image.open(source_path).convert("RGB")
        cropped = crop_to_ratio(source, 16, 15)
        final = cropped.resize((160, 150), Image.Resampling.NEAREST)
        final.save(output_path, optimize=True)

        frame = frames[int(card["card_equality"])]
        preview = Image.new("RGBA", frame.size, (18, 22, 28, 255))
        preview.alpha_composite(final.convert("RGBA"), (16, 14))
        preview.alpha_composite(frame, (0, 0))
        previews.append((card_id, card["card_name"], preview))
        manifest.append(
            {
                "card_id": card_id,
                "card_name": card["card_name"],
                "card_equality": int(card["card_equality"]),
                "asset": f"card_art_{card_id}.png",
                "size": [160, 150],
            }
        )

    columns = 5
    cell_width = 208
    cell_height = 302
    rows = (len(previews) + columns - 1) // columns
    sheet = Image.new(
        "RGB",
        (columns * cell_width, rows * cell_height),
        (32, 36, 43),
    )
    draw = ImageDraw.Draw(sheet)
    font = ImageFont.load_default()
    for index, (card_id, card_name, preview) in enumerate(previews):
        x = (index % columns) * cell_width + 8
        y = (index // columns) * cell_height + 8
        sheet.paste(preview.convert("RGB"), (x, y))
        draw.text(
            (x, y + 278),
            f"{card_id} {card_name}",
            fill=(235, 238, 242),
            font=font,
        )

    sheet.save(ROOT / "card_art_contact_sheet.png", optimize=True)
    (ROOT / "manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    print(
        json.dumps(
            {
                "count": len(manifest),
                "final_dir": str(FINAL_DIR),
                "contact_sheet": str(ROOT / "card_art_contact_sheet.png"),
            },
            ensure_ascii=False,
        )
    )


if __name__ == "__main__":
    main()
