import os
import sys
import subprocess

try:
    from PIL import Image, ImageDraw, ImageFilter
except ImportError:
    print("[*] Installing Pillow...")
    subprocess.check_call([sys.executable, "-m", "pip", "install", "Pillow", "--break-system-packages"])
    from PIL import Image, ImageDraw, ImageFilter

def create_base_icon():
    # Create a 1024x1024 high-res canvas
    size = 1024
    image = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    
    # 1. Draw macOS squircle rounded background with metallic dark gradient
    # We will approximate a squircle by drawing a rounded rectangle
    margin = 80
    bg_box = [margin, margin, size - margin, size - margin]
    r = 200 # corner radius
    
    # Draw soft shadow
    shadow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    s_draw = ImageDraw.Draw(shadow)
    s_draw.rounded_rectangle(bg_box, radius=r, fill=(0, 0, 0, 100))
    shadow = shadow.filter(ImageFilter.GaussianBlur(30))
    image.paste(shadow, (0, 15), shadow)
    
    # Draw background squircle (glossy dark theme)
    bg = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    b_draw = ImageDraw.Draw(bg)
    # Dark grey glass/metal look
    b_draw.rounded_rectangle(bg_box, radius=r, fill=(30, 30, 35, 255))
    
    # Add a subtle inner border for glassmorphism
    border_box = [margin + 4, margin + 4, size - margin - 4, size - margin - 4]
    b_draw.rounded_rectangle(border_box, radius=r-4, outline=(255, 255, 255, 30), width=6)
    
    # 2. Draw glowing neon vibration waves (concentric curves on sides)
    center_x = size // 2
    center_y = size // 2
    
    # Left waves (neon blue)
    b_draw.arc([center_x - 300, center_y - 200, center_x - 100, center_y + 200], start=120, end=240, fill=(0, 191, 255, 200), width=16)
    b_draw.arc([center_x - 380, center_y - 250, center_x - 60, center_y + 250], start=130, end=230, fill=(0, 191, 255, 100), width=12)
    
    # Right waves (neon purple)
    b_draw.arc([center_x + 100, center_y - 200, center_x + 300, center_y + 200], start=300, end=60, fill=(186, 85, 211, 200), width=16)
    b_draw.arc([center_x + 60, center_y - 250, center_x + 380, center_y + 250], start=310, end=50, fill=(186, 85, 211, 100), width=12)
    
    # 3. Draw minimalist mouse in the center
    # Mouse body dimensions
    mouse_w = 180
    mouse_h = 320
    mx1 = center_x - mouse_w // 2
    my1 = center_y - mouse_h // 2
    mx2 = center_x + mouse_w // 2
    my2 = center_y + mouse_h // 2
    
    # Draw mouse base shadow
    b_draw.rounded_rectangle([mx1-10, my1-10, mx2+10, my2+10], radius=90, fill=(0, 0, 0, 80))
    
    # Draw main mouse body (matte silver/light grey)
    b_draw.rounded_rectangle([mx1, my1, mx2, my2], radius=80, fill=(200, 200, 205, 255))
    
    # Draw scroll wheel slot
    sw_w = 20
    sw_h = 70
    sw_x1 = center_x - sw_w // 2
    sw_y1 = my1 + 60
    sw_x2 = center_x + sw_w // 2
    sw_y2 = sw_y1 + sw_h
    b_draw.rounded_rectangle([sw_x1, sw_y1, sw_x2, sw_y2], radius=10, fill=(40, 40, 45, 255))
    
    # Draw glowing neon blue scroll wheel
    b_draw.rounded_rectangle([sw_x1 + 3, sw_y1 + 10, sw_x2 - 3, sw_y2 - 10], radius=8, fill=(0, 191, 255, 255))
    
    # Draw vertical separator line for left/right click buttons
    b_draw.line([center_x, my1 + 140, center_x, my1], fill=(130, 130, 135, 255), width=4)
    
    # Draw horizontal separator curve for buttons
    b_draw.arc([mx1, my1 + 80, mx2, my1 + 200], start=180, end=360, fill=(130, 130, 135, 255), width=4)
    
    # Add glossy highlight reflection (white gradient arc at the top of the icon)
    b_draw.arc([margin + 20, margin + 20, size - margin - 20, margin + 400], start=200, end=340, fill=(255, 255, 255, 40), width=30)
    
    # Merge layers
    image.paste(bg, (0, 0), bg)
    return image

def build_icns():
    print("[*] Generating base 1024x1024 icon image...")
    base_image = create_base_icon()
    
    iconset_dir = "HapticMouse.iconset"
    os.makedirs(iconset_dir, exist_ok=True)
    
    # Standard macOS icon sizes
    sizes = {
        "icon_16x16.png": 16,
        "icon_16x16@2x.png": 32,
        "icon_32x32.png": 32,
        "icon_32x32@2x.png": 64,
        "icon_128x128.png": 128,
        "icon_128x128@2x.png": 256,
        "icon_256x256.png": 256,
        "icon_256x256@2x.png": 512,
        "icon_512x512.png": 512,
        "icon_512x512@2x.png": 1024
    }
    
    print("[*] Resizing icons for macOS iconset...")
    for filename, target_size in sizes.items():
        resized = base_image.resize((target_size, target_size), Image.Resampling.LANCZOS)
        resized.save(os.path.join(iconset_dir, filename))
        
    print("[*] Running iconutil to generate .icns file...")
    # Compile the iconset into an .icns file
    subprocess.check_call(["iconutil", "-c", "icns", iconset_dir, "-o", "HapticMouse.icns"])
    
    # Clean up iconset folder
    import shutil
    shutil.rmtree(iconset_dir)
    print("[+] Successfully generated HapticMouse.icns!")

if __name__ == "__main__":
    # Adjust python sys path to combined helper
    sys.path.append(os.path.dirname(os.path.realpath(__file__)))
    os.chdir(os.path.dirname(os.path.realpath(__file__)))
    build_icns()
