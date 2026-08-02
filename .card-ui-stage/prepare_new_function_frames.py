from pathlib import Path

from PIL import Image, ImageFilter


SOURCE_ROOT = Path(
    r"C:\Users\laba\.codex\generated_images\019eca28-6068-7c90-8dbc-3985e0280b5c"
)
OUTPUT_ROOT = Path(r"D:\Homepage Dev\.card-ui-stage\new-function-frames")
OUTPUT_ROOT.mkdir(parents=True, exist_ok=True)

TARGET_SIZE = (192, 272)
BLACK_THRESHOLD = 18
OUTLINE_DILATION = 9

QUALITY_SOURCES = {
    0: "exec-1c3b0a5c-8d7e-4fa6-8ac1-070906711856.png",  # white
    1: "exec-8569e28d-9bd1-4409-a146-023ab33f4e2c.png",  # green
    2: "exec-fbcbb8da-655a-481e-992d-b50ae0ed3fef.png",  # blue
    3: "exec-8d57f5dc-6544-473e-8c9d-c06c746dd194.png",  # purple
    4: "exec-7beda072-f841-4611-acd6-ba500df6cd08.png",  # gold
}


def recover_alpha(image: Image.Image) -> Image.Image:
    rgb = image.convert("RGB")
    red, green, blue = rgb.split()
    brightness = Image.new("L", rgb.size)
    brightness_pixels = brightness.load()
    red_pixels = red.load()
    green_pixels = green.load()
    blue_pixels = blue.load()

    for y in range(rgb.height):
        for x in range(rgb.width):
            brightness_pixels[x, y] = max(
                red_pixels[x, y],
                green_pixels[x, y],
                blue_pixels[x, y],
            )

    opaque_seed = brightness.point(
        lambda value: 255 if value > BLACK_THRESHOLD else 0
    )
    alpha = opaque_seed.filter(ImageFilter.MaxFilter(OUTLINE_DILATION))
    rgba = rgb.convert("RGBA")
    rgba.putalpha(alpha)
    return rgba


for quality, source_name in QUALITY_SOURCES.items():
    source_path = SOURCE_ROOT / source_name
    output_path = OUTPUT_ROOT / f"card_frame_function_{quality}.png"
    image = recover_alpha(Image.open(source_path))
    image = image.resize(TARGET_SIZE, Image.Resampling.LANCZOS)
    image.save(output_path, optimize=True)
    alpha_bounds = image.getchannel("A").getbbox()
    print(
        f"{quality}: {source_name} -> {output_path.name} "
        f"{image.size}, alpha_bounds={alpha_bounds}"
    )
