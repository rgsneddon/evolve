"""Generate the blue swirl app icon for all Evolve platforms."""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

EMOJI = "\U0001F300"
FONT_PATH = Path(r"C:\Windows\Fonts\seguiemj.ttf")
ROOT = Path(__file__).resolve().parents[1]
BACKGROUND = (12, 18, 32, 255)
ICO_SIZES = (16, 24, 32, 48, 64, 128, 256)

ANDROID_SIZES = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}

IOS_ICONS = {
    "Icon-App-20x20@1x.png": 20,
    "Icon-App-20x20@2x.png": 40,
    "Icon-App-20x20@3x.png": 60,
    "Icon-App-29x29@1x.png": 29,
    "Icon-App-29x29@2x.png": 58,
    "Icon-App-29x29@3x.png": 87,
    "Icon-App-40x40@1x.png": 40,
    "Icon-App-40x40@2x.png": 80,
    "Icon-App-40x40@3x.png": 120,
    "Icon-App-60x60@2x.png": 120,
    "Icon-App-60x60@3x.png": 180,
    "Icon-App-76x76@1x.png": 76,
    "Icon-App-76x76@2x.png": 152,
    "Icon-App-83.5x83.5@2x.png": 167,
    "Icon-App-1024x1024@1x.png": 1024,
}


def render_emoji(
    size: int,
    *,
    background: tuple[int, int, int, int] = BACKGROUND,
    emoji_scale: float = 0.78,
) -> Image.Image:
    image = Image.new("RGBA", (size, size), background)
    draw = ImageDraw.Draw(image)
    font_size = max(8, int(size * emoji_scale))
    font = ImageFont.truetype(str(FONT_PATH), font_size)
    bbox = draw.textbbox((0, 0), EMOJI, font=font)
    width = bbox[2] - bbox[0]
    height = bbox[3] - bbox[1]
    position = (
        (size - width) / 2 - bbox[0],
        (size - height) / 2 - bbox[1],
    )
    draw.text(position, EMOJI, font=font, embedded_color=True)
    return image


def render_maskable(size: int) -> Image.Image:
    # Keep the swirl inside the adaptive-icon safe zone.
    return render_emoji(size, emoji_scale=0.58)


def save_png(path: Path, image: Image.Image) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, format="PNG")
    print(f"Wrote {path}")


def write_windows_icon() -> None:
    frames = [render_emoji(size) for size in ICO_SIZES]
    ico_path = ROOT / "windows" / "runner" / "resources" / "app_icon.ico"
    ico_path.parent.mkdir(parents=True, exist_ok=True)
    frames[0].save(
        ico_path,
        format="ICO",
        sizes=[(size, size) for size in ICO_SIZES],
        append_images=frames[1:],
    )
    print(f"Wrote {ico_path}")


def write_web_icons() -> None:
    save_png(ROOT / "web" / "favicon.png", render_emoji(32))
    for size in (192, 512):
        save_png(ROOT / "web" / "icons" / f"Icon-{size}.png", render_emoji(size))
        save_png(
            ROOT / "web" / "icons" / f"Icon-maskable-{size}.png",
            render_maskable(size),
        )


def write_android_icons() -> None:
    for folder, size in ANDROID_SIZES.items():
        save_png(
            ROOT / "android" / "app" / "src" / "main" / "res" / folder / "ic_launcher.png",
            render_emoji(size),
        )


def write_ios_icons() -> None:
    for filename, size in IOS_ICONS.items():
        save_png(
            ROOT
            / "ios"
            / "Runner"
            / "Assets.xcassets"
            / "AppIcon.appiconset"
            / filename,
            render_emoji(size),
        )


def main() -> None:
    write_windows_icon()
    write_web_icons()
    write_android_icons()
    write_ios_icons()
    print("Swirl icon applied across Windows, web, Android, and iOS.")


if __name__ == "__main__":
    main()