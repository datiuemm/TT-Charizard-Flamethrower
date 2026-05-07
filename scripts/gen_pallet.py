import numpy as np
from PIL import Image
import os
from gamma import gamma_correct, dither_correct

# -------------------------------------------------------
# Config
# -------------------------------------------------------
NAMES = ["mander", "melon", "zizard", "fire"]
DATA_DIR = "../data"
WHITE_THRESH = 220
NUM_FRAMES = 6
TILE_W, TILE_H = 64, 32
NUM_COLORS = 8
NUM_QUANT = NUM_COLORS - 1

# Màu nền (Background)
bgr, bgg, bgb = 0xff, 0xff, 0xff

# -------------------------------------------------------
# 1. Tìm Palette Chung
# -------------------------------------------------------
all_pixels = []
valid_gifs = []

for name in NAMES:
    path = f"{name}.gif"
    if os.path.exists(path):
        valid_gifs.append(name)
        gif = Image.open(path)
        indices = [int(round(i * (gif.n_frames - 1) / (NUM_FRAMES - 1))) for i in range(NUM_FRAMES)]
        for fi in indices:
            gif.seek(fi)
            arr = np.array(gif.convert("RGB")).reshape(-1, 3)
            # Chỉ lấy các pixel không phải màu trắng
            valid_pixels = arr[np.any(arr < WHITE_THRESH, axis=1)]
            all_pixels.append(valid_pixels)

if not all_pixels:
    print("No GIF files found!"); exit()

all_data = np.vstack(all_pixels)
mega_image = Image.fromarray(all_data.reshape(-1, 1, 3).astype(np.uint8))
mega_q = mega_image.quantize(colors=NUM_QUANT, method=1)
raw_pal = mega_q.getpalette()

# Xây dựng palette 8 màu (Index 0 = White)
palette_rgb = np.zeros((NUM_COLORS, 3), dtype=np.uint8)
palette_rgb[0] = [bgr, bgg, bgb]
for i in range(1, NUM_COLORS):
    palette_rgb[i] = [raw_pal[(i-1)*3], raw_pal[(i-1)*3+1], raw_pal[(i-1)*3+2]]

# Gamma correction & Lưu palette_*.hex
flat_pal = gamma_correct(palette_rgb.flatten().astype(np.int32))
flat_pal = dither_correct(flat_pal)
pal_r, pal_g, pal_b = flat_pal[0::3], flat_pal[1::3], flat_pal[2::3]

for c, data in zip(['r', 'g', 'b'], [pal_r, pal_g, pal_b]):
    with open(f"{DATA_DIR}/palette_{c}.hex", "w") as f:
        f.write(' '.join(f'{v:02x}' for v in data) + '\n')

# -------------------------------------------------------
# 2. Convert từng con rồng theo Palette vừa tạo
# -------------------------------------------------------
# Tạo PIL palette image để dùng hàm quantize nhanh
pal_flat_pil = [0] * 768
for i in range(NUM_COLORS):
    pal_flat_pil[i*3:i*3+3] = palette_rgb[i]
pal_img = Image.new("P", (1, 1))
pal_img.putpalette(pal_flat_pil)

for name in valid_gifs:
    gif = Image.open(f"{name}.gif")
    indices = [int(round(i * (gif.n_frames - 1) / (NUM_FRAMES - 1))) for i in range(NUM_FRAMES)]
    
    with open(f"{DATA_DIR}/{name}.hex", "w") as f:
        for fi in indices:
            gif.seek(fi)
            # Resize & Center
            src_w, src_h = gif.size
            scale = min(TILE_W/src_w, TILE_H/src_h)
            sw, sh = int(src_w*scale), int(src_h*scale)
            frame_small = gif.convert("RGB").resize((sw, sh), Image.NEAREST)
            
            canvas = Image.new("RGB", (TILE_W, TILE_H), (bgr, bgg, bgb))
            canvas.paste(frame_small, ((TILE_W-sw)//2, (TILE_H-sh)//2))
            
            # Map pixel sang index của palette chung (dither=0 để giữ nét pixel art)
            quant = canvas.quantize(palette=pal_img, dither=0)
            pixels = np.array(quant, dtype=np.uint8)
            
            # Cưỡng ép pixel trắng về index 0
            is_white = np.all(np.array(canvas) >= WHITE_THRESH, axis=2)
            pixels[is_white] = 0
            
            for row in pixels:
                f.write(' '.join(f'{v:01x}' for v in row) + '\n')
        
        # Pad cho đủ 16384 entries (yêu cầu của Verilog ROM)
        f.write('0 ' * (16384 - (NUM_FRAMES * TILE_W * TILE_H)) + '\n')

print(f"Done! Created global palette and converted: {valid_gifs}")
