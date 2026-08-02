from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(r"D:\Homepage Dev\active-item-icons")
SOURCE = ROOT / "keyed"
OUTPUT = ROOT / "final"
OUTPUT.mkdir(parents=True, exist_ok=True)

NAMES = {
    10000: "绷带",
    10001: "磨砺油膏",
    10002: "轻足薄荷糖",
    10003: "粗制幸运符",
    10004: "幸运卡套",
    10005: "急救包",
    10006: "祈愿签",
    10007: "满溢祝福",
    10008: "护身符",
    10009: "疾风药剂",
    10010: "蓝羽",
    10011: "秘藏卡匣",
    10012: "医疗箱",
    10013: "命运卡册",
    10014: "生命结晶",
}


def make_icon(source_path: Path, output_path: Path) -> Image.Image:
    image = Image.open(source_path).convert("RGBA")
    alpha = image.getchannel("A")
    mask = alpha.point(lambda value: 255 if value >= 12 else 0)
    bbox = mask.getbbox()
    if bbox is None:
        raise ValueError(f"No opaque subject in {source_path.name}")

    cropped = image.crop(bbox)
    longest = max(cropped.size)
    padding = max(4, round(longest * 0.12))
    square_size = longest + padding * 2
    square = Image.new("RGBA", (square_size, square_size), (0, 0, 0, 0))
    square.alpha_composite(
        cropped,
        ((square_size - cropped.width) // 2, (square_size - cropped.height) // 2),
    )
    icon = square.resize((64, 64), Image.Resampling.LANCZOS)
    icon.save(output_path, optimize=True)

    corners = [
        icon.getpixel((0, 0))[3],
        icon.getpixel((63, 0))[3],
        icon.getpixel((0, 63))[3],
        icon.getpixel((63, 63))[3],
    ]
    if any(corner > 8 for corner in corners):
        raise ValueError(f"Non-transparent corner in {output_path.name}")
    return icon


icons: dict[int, Image.Image] = {}
for item_id in sorted(NAMES):
    icons[item_id] = make_icon(
        SOURCE / f"active_item_{item_id}.png",
        OUTPUT / f"active_item_{item_id}.png",
    )

cell_width = 148
cell_height = 118
sheet = Image.new(
    "RGBA",
    (cell_width * 5, cell_height * 3),
    (18, 31, 25, 255),
)
draw = ImageDraw.Draw(sheet)
font = ImageFont.truetype(r"C:\Windows\Fonts\msyh.ttc", 14)
small_font = ImageFont.truetype(r"C:\Windows\Fonts\msyh.ttc", 11)

for index, item_id in enumerate(sorted(NAMES)):
    col = index % 5
    row = index // 5
    x = col * cell_width
    y = row * cell_height
    for yy in range(y + 8, y + 80, 8):
        for xx in range(x + 42, x + 114, 8):
            color = (58, 70, 64, 255) if ((xx + yy) // 8) % 2 else (43, 54, 49, 255)
            draw.rectangle((xx, yy, xx + 7, yy + 7), fill=color)
    sheet.alpha_composite(icons[item_id], (x + 46, y + 12))
    draw.text((x + 8, y + 84), NAMES[item_id], font=font, fill=(240, 222, 167, 255))
    draw.text((x + 8, y + 103), str(item_id), font=small_font, fill=(148, 174, 156, 255))

sheet.save(ROOT / "active_items_contact_sheet.png", optimize=True)
print(f"Processed {len(icons)} icons")
