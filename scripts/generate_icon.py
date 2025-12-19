#!/usr/bin/env python3
"""
Generate CardPro App Icon
Design: Two overlapping business cards on gradient background
"""

from PIL import Image, ImageDraw, ImageFilter, ImageFont
import os

def create_app_icon(size=1024):
    """Create a modern app icon for CardPro"""

    # Create base image with gradient background
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Gradient background (deep blue to teal)
    for y in range(size):
        # Gradient from top-left to bottom-right
        ratio = y / size
        r = int(20 + (40 - 20) * ratio)      # 20 -> 40
        g = int(60 + (140 - 60) * ratio)     # 60 -> 140
        b = int(120 + (160 - 120) * ratio)   # 120 -> 160
        draw.line([(0, y), (size, y)], fill=(r, g, b, 255))

    # Add subtle radial gradient overlay for depth
    center_x, center_y = size // 2, size // 2
    for y in range(size):
        for x in range(size):
            # Distance from center
            dist = ((x - center_x) ** 2 + (y - center_y) ** 2) ** 0.5
            max_dist = (size // 2) * 1.2
            if dist < max_dist:
                # Lighter in center
                factor = 1 - (dist / max_dist) * 0.3
                pixel = img.getpixel((x, y))
                new_pixel = tuple(min(255, int(c * factor + 30 * (1 - dist/max_dist))) for c in pixel[:3]) + (255,)
                img.putpixel((x, y), new_pixel)

    # Card dimensions
    card_width = int(size * 0.55)
    card_height = int(card_width * 0.6)  # Business card ratio ~1.67:1
    corner_radius = int(size * 0.03)

    # Create card shape function
    def draw_rounded_rect(draw, xy, radius, fill, outline=None, width=1):
        x1, y1, x2, y2 = xy
        draw.rounded_rectangle(xy, radius=radius, fill=fill, outline=outline, width=width)

    # Back card (slightly rotated effect - offset)
    back_card_img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    back_draw = ImageDraw.Draw(back_card_img)

    back_x = int(size * 0.28)
    back_y = int(size * 0.32)

    # Back card shadow
    shadow_offset = int(size * 0.015)
    draw_rounded_rect(back_draw,
                     (back_x + shadow_offset, back_y + shadow_offset,
                      back_x + card_width + shadow_offset, back_y + card_height + shadow_offset),
                     corner_radius, fill=(0, 0, 0, 60))

    # Back card (white with slight gray)
    draw_rounded_rect(back_draw,
                     (back_x, back_y, back_x + card_width, back_y + card_height),
                     corner_radius, fill=(240, 240, 245, 255))

    # Back card accent line
    accent_height = int(card_height * 0.15)
    back_draw.rounded_rectangle(
        (back_x, back_y, back_x + card_width, back_y + accent_height),
        radius=corner_radius, fill=(100, 160, 200, 255)
    )
    # Fix bottom corners of accent
    back_draw.rectangle(
        (back_x, back_y + accent_height - corner_radius, back_x + card_width, back_y + accent_height),
        fill=(100, 160, 200, 255)
    )

    # Rotate back card slightly
    back_card_img = back_card_img.rotate(-8, resample=Image.BICUBIC, center=(size//2, size//2))

    # Front card
    front_card_img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    front_draw = ImageDraw.Draw(front_card_img)

    front_x = int(size * 0.22)
    front_y = int(size * 0.38)

    # Front card shadow
    draw_rounded_rect(front_draw,
                     (front_x + shadow_offset * 2, front_y + shadow_offset * 2,
                      front_x + card_width + shadow_offset * 2, front_y + card_height + shadow_offset * 2),
                     corner_radius, fill=(0, 0, 0, 80))

    # Front card (white)
    draw_rounded_rect(front_draw,
                     (front_x, front_y, front_x + card_width, front_y + card_height),
                     corner_radius, fill=(255, 255, 255, 255))

    # Front card accent (left bar - modern style)
    bar_width = int(card_width * 0.04)
    front_draw.rounded_rectangle(
        (front_x, front_y, front_x + bar_width + corner_radius, front_y + card_height),
        radius=corner_radius, fill=(30, 100, 160, 255)
    )
    front_draw.rectangle(
        (front_x + bar_width, front_y, front_x + bar_width + corner_radius, front_y + card_height),
        fill=(30, 100, 160, 255)
    )

    # Add some placeholder lines on front card (representing text)
    line_color = (180, 180, 190, 255)
    line_x = front_x + int(card_width * 0.15)
    line_y = front_y + int(card_height * 0.25)
    line_width = int(card_width * 0.5)
    line_height = int(card_height * 0.08)

    # Name line (thicker)
    front_draw.rounded_rectangle(
        (line_x, line_y, line_x + line_width, line_y + line_height),
        radius=line_height//2, fill=(60, 60, 70, 255)
    )

    # Title line
    line_y += int(card_height * 0.18)
    front_draw.rounded_rectangle(
        (line_x, line_y, line_x + line_width * 0.7, line_y + line_height * 0.6),
        radius=line_height//3, fill=line_color
    )

    # Contact lines
    line_y += int(card_height * 0.22)
    front_draw.rounded_rectangle(
        (line_x, line_y, line_x + line_width * 0.6, line_y + line_height * 0.5),
        radius=line_height//4, fill=line_color
    )

    line_y += int(card_height * 0.12)
    front_draw.rounded_rectangle(
        (line_x, line_y, line_x + line_width * 0.75, line_y + line_height * 0.5),
        radius=line_height//4, fill=line_color
    )

    # Rotate front card slightly
    front_card_img = front_card_img.rotate(5, resample=Image.BICUBIC, center=(size//2, size//2))

    # Composite layers
    img = Image.alpha_composite(img, back_card_img)
    img = Image.alpha_composite(img, front_card_img)

    # Add subtle exchange arrows or wireless symbol
    # Small NFC/wireless indicator in corner
    indicator_size = int(size * 0.12)
    indicator_x = int(size * 0.78)
    indicator_y = int(size * 0.12)

    indicator_draw = ImageDraw.Draw(img)

    # Draw wireless/NFC waves
    wave_color = (255, 255, 255, 180)
    center_x = indicator_x
    center_y = indicator_y + indicator_size // 2

    for i, radius in enumerate([indicator_size * 0.3, indicator_size * 0.5, indicator_size * 0.7]):
        # Draw arc
        bbox = (center_x - radius, center_y - radius, center_x + radius, center_y + radius)
        indicator_draw.arc(bbox, start=300, end=60, fill=wave_color, width=int(size * 0.012))

    # Small dot at center
    dot_radius = int(size * 0.015)
    indicator_draw.ellipse(
        (center_x - dot_radius, center_y - dot_radius, center_x + dot_radius, center_y + dot_radius),
        fill=wave_color
    )

    return img


def main():
    # Output directory
    script_dir = os.path.dirname(os.path.abspath(__file__))
    project_dir = os.path.dirname(script_dir)
    output_dir = os.path.join(project_dir, 'CardPro', 'Resources', 'Assets.xcassets', 'AppIcon.appiconset')

    print("Generating CardPro App Icon...")

    # Generate 1024x1024 icon
    icon = create_app_icon(1024)

    # Save
    output_path = os.path.join(output_dir, 'AppIcon.png')
    icon.save(output_path, 'PNG')
    print(f"Saved: {output_path}")

    # Update Contents.json to reference the file
    contents_json = '''{
  "images" : [
    {
      "filename" : "AppIcon.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}'''

    contents_path = os.path.join(output_dir, 'Contents.json')
    with open(contents_path, 'w') as f:
        f.write(contents_json)
    print(f"Updated: {contents_path}")

    print("Done! App icon generated successfully.")


if __name__ == '__main__':
    main()
