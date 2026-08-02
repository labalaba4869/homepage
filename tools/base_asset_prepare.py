from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image


def fit_to_canvas(
    source: Image.Image,
    canvas_size: tuple[int, int],
    content_size: tuple[int, int],
) -> Image.Image:
    bbox = source.getbbox()
    if bbox is None:
        raise ValueError("asset crop is empty")
    crop = source.crop(bbox)
    ratio = min(content_size[0] / crop.width, content_size[1] / crop.height)
    target = (
        max(1, round(crop.width * ratio)),
        max(1, round(crop.height * ratio)),
    )
    crop = crop.resize(target, Image.Resampling.NEAREST)
    canvas = Image.new("RGBA", canvas_size, (0, 0, 0, 0))
    x = (canvas_size[0] - target[0]) // 2
    y = canvas_size[1] - target[1]
    canvas.alpha_composite(crop, (x, y))
    return canvas


def crop_region(source: Image.Image, box: tuple[int, int, int, int]) -> Image.Image:
    return source.crop(box)


def prepare_props(source: Image.Image, output_dir: Path) -> None:
    specs = {
        "merchant_tent.png": ((75, 35, 590, 540), (256, 224), (232, 208)),
        "bedroll_green.png": ((620, 190, 885, 465), (96, 96), (88, 80)),
        "bedroll_dark.png": ((880, 190, 1145, 465), (96, 96), (88, 80)),
        "wood_bench.png": ((1155, 255, 1505, 475), (160, 96), (150, 76)),
        "merchant_crates.png": ((120, 535, 455, 930), (160, 160), (148, 148)),
        "lantern_post.png": ((540, 525, 770, 930), (96, 160), (88, 150)),
        "signpost.png": ((830, 585, 1085, 925), (96, 128), (88, 118)),
        "campfire_unlit.png": ((1125, 650, 1465, 940), (128, 96), (118, 88)),
    }
    for filename, (box, canvas, content) in specs.items():
        prepared = fit_to_canvas(crop_region(source, box), canvas, content)
        prepared.save(output_dir / filename)


def prepare_fire(source: Image.Image, output_dir: Path) -> None:
    frames: list[Image.Image] = []
    frame_width = source.width / 6.0
    for index in range(6):
        left = round(index * frame_width)
        right = round((index + 1) * frame_width)
        region = source.crop((left, 0, right, source.height))
        frames.append(fit_to_canvas(region, (128, 128), (118, 112)))
    sheet = Image.new("RGBA", (128 * len(frames), 128), (0, 0, 0, 0))
    for index, frame in enumerate(frames):
        sheet.alpha_composite(frame, (index * 128, 0))
    sheet.save(output_dir / "campfire_6_frames.png")
    frames[2].save(output_dir / "campfire_icon.png")


def prepare_icons(source: Image.Image, output_dir: Path) -> None:
    midpoint = source.width // 2
    regions = {
        "backpack.png": source.crop((0, 0, midpoint, source.height)),
        "deck.png": source.crop((midpoint, 0, source.width, source.height)),
    }
    for filename, region in regions.items():
        fit_to_canvas(region, (64, 64), (58, 58)).save(output_dir / filename)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--props", type=Path, required=True)
    parser.add_argument("--fire", type=Path, required=True)
    parser.add_argument("--icons", type=Path, required=True)
    parser.add_argument("--scene-out", type=Path, required=True)
    parser.add_argument("--ui-out", type=Path, required=True)
    args = parser.parse_args()

    args.scene_out.mkdir(parents=True, exist_ok=True)
    args.ui_out.mkdir(parents=True, exist_ok=True)
    prepare_props(Image.open(args.props).convert("RGBA"), args.scene_out)
    prepare_fire(Image.open(args.fire).convert("RGBA"), args.scene_out)
    prepare_icons(Image.open(args.icons).convert("RGBA"), args.ui_out)


if __name__ == "__main__":
    main()
