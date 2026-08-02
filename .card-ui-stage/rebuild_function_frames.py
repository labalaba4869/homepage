from pathlib import Path

from PIL import Image


PROJECT = Path(r"D:\GameDevelop\Godot\card-search-and-attack")
FRAME_ROOT = PROJECT / "assets" / "art" / "cards" / "frames"
OUTPUT_ROOT = Path(r"D:\Homepage Dev\.card-ui-stage\function-v3")
OUTPUT_ROOT.mkdir(parents=True, exist_ok=True)

QUALITY_NAMES = ("white", "green", "blue", "purple", "gold")
TOP_SECTION_HEIGHT = 146
BOUNDARY_SAMPLE_Y = 150


def alpha_bounds_at_row(image: Image.Image, y: int) -> tuple[int, int]:
    xs = [
        x
        for x in range(image.width)
        if image.getpixel((x, y))[3] > 32
    ]
    if not xs:
        raise RuntimeError(f"No visible frame pixels at row {y}")
    return min(xs), max(xs)


for quality, quality_name in enumerate(QUALITY_NAMES):
    hero_path = FRAME_ROOT / f"card_frame_{quality}_{quality_name}.png"
    function_path = (
        FRAME_ROOT / "function" / f"card_frame_function_{quality}.png"
    )
    output_path = OUTPUT_ROOT / f"card_frame_function_{quality}.png"

    hero_frame = Image.open(hero_path).convert("RGBA")
    function_frame = Image.open(function_path).convert("RGBA")
    if hero_frame.size != function_frame.size:
        raise RuntimeError(
            f"Frame size mismatch: {hero_path.name} {hero_frame.size} != "
            f"{function_path.name} {function_frame.size}"
        )

    # Preserve the shipped frame's complete top geometry pixel-for-pixel.
    top = hero_frame.crop((0, 0, hero_frame.width, TOP_SECTION_HEIGHT))
    function_frame.paste(top, (0, 0))

    source_left, source_right = alpha_bounds_at_row(
        function_frame,
        BOUNDARY_SAMPLE_Y,
    )
    target_left, target_right = alpha_bounds_at_row(
        hero_frame,
        BOUNDARY_SAMPLE_Y,
    )
    lower = function_frame.crop(
        (
            0,
            TOP_SECTION_HEIGHT,
            function_frame.width,
            function_frame.height,
        )
    )
    source_span = source_right - source_left
    target_span = target_right - target_left
    best_lower = None
    best_score = float("inf")
    for span_adjustment in range(-2, 3):
        adjusted_target_span = target_span + span_adjustment
        horizontal_scale = source_span / adjusted_target_span
        base_offset = source_left - horizontal_scale * target_left
        for offset_step in range(-4, 5):
            horizontal_offset = base_offset + offset_step * 0.25
            candidate = lower.transform(
                (function_frame.width, lower.height),
                Image.Transform.AFFINE,
                (
                    horizontal_scale,
                    0,
                    horizontal_offset,
                    0,
                    1,
                    0,
                ),
                Image.Resampling.NEAREST,
            )
            candidate_left, candidate_right = alpha_bounds_at_row(
                candidate,
                BOUNDARY_SAMPLE_Y - TOP_SECTION_HEIGHT,
            )
            score = (
                abs(candidate_left - target_left)
                + abs(candidate_right - target_right)
                + abs(span_adjustment) * 0.01
                + abs(offset_step) * 0.001
            )
            if score < best_score:
                best_score = score
                best_lower = candidate
    if best_lower is None:
        raise RuntimeError(f"Unable to align {function_path.name}")
    lower = best_lower
    clear = Image.new(
        "RGBA",
        (function_frame.width, function_frame.height - TOP_SECTION_HEIGHT),
        (0, 0, 0, 0),
    )
    function_frame.paste(clear, (0, TOP_SECTION_HEIGHT))
    function_frame.paste(lower, (0, TOP_SECTION_HEIGHT))
    function_frame.save(output_path, optimize=True)
    output_left, output_right = alpha_bounds_at_row(
        function_frame,
        BOUNDARY_SAMPLE_Y,
    )
    print(
        f"{output_path}: source={source_left}..{source_right}, "
        f"target={target_left}..{target_right}, "
        f"output={output_left}..{output_right}"
    )
