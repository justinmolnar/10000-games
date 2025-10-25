#!/usr/bin/env python3
"""
Placeholder Sprite Generator
Generates simple placeholder sprites for testing Phase 2.3 integration
Run with: python scripts/generate_placeholders.py
"""

from PIL import Image, ImageDraw
import os

def create_image(width, height, bg_color=(0, 0, 0, 0)):
    """Create a new RGBA image with transparent background"""
    return Image.new('RGBA', (width, height), bg_color)

def save_image(img, path):
    """Save image to path, creating directories if needed"""
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path)
    print(f"Created: {path}")

def generate_dodge_placeholders():
    """Generate all placeholder sprites for dodge/base_1"""
    base_path = "assets/sprites/games/dodge/base_1/"
    size = 16

    # Canonical colors: Red (255,0,0), Dark Red (200,0,0), Yellow (255,255,0)
    RED = (255, 0, 0, 255)
    DARK_RED = (200, 0, 0, 255)
    YELLOW = (255, 255, 0, 255)
    DARK_BLUE = (10, 10, 30, 255)
    WHITE = (255, 255, 255, 255)

    # Player: Red circle with yellow center
    img = create_image(size, size)
    draw = ImageDraw.Draw(img)
    draw.ellipse([2, 2, 13, 13], fill=RED)
    draw.ellipse([5, 5, 10, 10], fill=YELLOW)
    save_image(img, base_path + "player.png")

    # Obstacle: Red square
    img = create_image(size, size)
    draw = ImageDraw.Draw(img)
    draw.rectangle([2, 2, 13, 13], fill=DARK_RED)
    save_image(img, base_path + "obstacle.png")

    # Enemy Chaser: Solid red circle
    img = create_image(size, size)
    draw = ImageDraw.Draw(img)
    draw.ellipse([2, 2, 13, 13], fill=RED)
    save_image(img, base_path + "enemy_chaser.png")

    # Enemy Shooter: Red square with yellow rectangle (gun)
    img = create_image(size, size)
    draw = ImageDraw.Draw(img)
    draw.rectangle([3, 3, 12, 12], fill=DARK_RED)
    draw.rectangle([11, 6, 13, 9], fill=YELLOW)
    save_image(img, base_path + "enemy_shooter.png")

    # Enemy Bouncer: Red diamond
    img = create_image(size, size)
    draw = ImageDraw.Draw(img)
    draw.polygon([(7, 2), (13, 7), (7, 13), (2, 7)], fill=RED)
    save_image(img, base_path + "enemy_bouncer.png")

    # Enemy Zigzag: Red triangle
    img = create_image(size, size)
    draw = ImageDraw.Draw(img)
    draw.polygon([(7, 2), (13, 13), (2, 13)], fill=RED)
    save_image(img, base_path + "enemy_zigzag.png")

    # Enemy Teleporter: Red cross/plus
    img = create_image(size, size)
    draw = ImageDraw.Draw(img)
    draw.rectangle([6, 2, 9, 13], fill=RED)
    draw.rectangle([2, 6, 13, 9], fill=RED)
    save_image(img, base_path + "enemy_teleporter.png")

    # Background: Dark blue starfield (32x32 tileable)
    img = create_image(32, 32, DARK_BLUE)
    draw = ImageDraw.Draw(img)
    # Add some white stars
    stars = [
        (2, 5), (8, 12), (15, 3), (22, 18), (28, 9),
        (5, 25), (18, 28), (11, 8), (25, 22), (7, 15)
    ]
    for x, y in stars:
        draw.point((x, y), fill=WHITE)
        # Make some stars slightly bigger
        if x % 3 == 0:
            draw.point((x+1, y), fill=WHITE)
    save_image(img, base_path + "background.png")

    print("\nDodge base_1 placeholders generated successfully!")

def main():
    print("=== Placeholder Sprite Generator ===")
    print("Generating sprites for dodge/base_1...")
    print("")

    try:
        generate_dodge_placeholders()
        print("")
        print("All placeholders generated!")
        print("Sprites use canonical red+yellow palette for palette swapping.")
        print("Next: Implement Phase 2.3 integration code.")
    except Exception as e:
        print(f"Error: {e}")
        print("Make sure PIL (Pillow) is installed: pip install Pillow")

if __name__ == "__main__":
    main()
