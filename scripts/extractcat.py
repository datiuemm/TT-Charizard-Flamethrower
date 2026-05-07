import numpy as np
from PIL import Image
from gamma import gamma_correct, dither_correct

# -------------------------------------------------------
# Config
# -------------------------------------------------------
NAME = os.environ.get("NYAN_NAME", "mander")

GIF_PATH = f"{NAME}.gif"
# Background color (white) – index 0 in our 8-color palette
bgr = 0xff
bgg = 0xff
bgb = 0xff

# VGA tile constraints
NUM_FRAMES  = 6   # hardware wired to 6 frames
TILE_W      = 64  # columns
TILE_H      = 32 # rows
NUM_COLORS  = 8   # 3-bit palette index  (indices 0-7)
NUM_QUANT   = NUM_COLORS - 1  # 7 quantized colors (index 0 is reserved for bg)

# -------------------------------------------------------
# Load GIF
# -------------------------------------------------------
gif = Image.open(GIF_PATH)
n_frames = gif.n_frames
print(f"Source GIF: {gif.size[0]}x{gif.size[1]}, {n_frames} frames, mode={gif.mode}")

# Pick NUM_FRAMES evenly-spaced frames
frame_indices = [int(round(i * (n_frames - 1) / (NUM_FRAMES - 1))) for i in range(NUM_FRAMES)]
print(f"Using frames: {frame_indices}")

# -------------------------------------------------------
# Build an 8-color palette from ALL selected frames
# -------------------------------------------------------
# Mosaic all selected frames as RGB, then quantize to NUM_QUANT colors
all_frames_rgb = []
for fi in frame_indices:
    gif.seek(fi)
    all_frames_rgb.append(gif.convert("RGB"))

mosaic_w = gif.size[0] * NUM_FRAMES
mosaic_h = gif.size[1]
mosaic = Image.new("RGB", (mosaic_w, mosaic_h))
for i, fr in enumerate(all_frames_rgb):
    mosaic.paste(fr, (i * gif.size[0], 0))

mosaic_rgb = np.array(mosaic)   # shape (H, W, 3)

# Mask near-white pixels with a placeholder (pure black) so they don't
# consume one of our precious 7 color slots. We'll remap them back to
# palette index 0 (background/white) later during frame processing.
WHITE_THRESH = 220
is_nearly_white = np.all(mosaic_rgb >= WHITE_THRESH, axis=2)  # (H, W) bool
mosaic_masked = mosaic_rgb.copy()
mosaic_masked[is_nearly_white] = [0, 0, 0]  # placeholder for quantization

mosaic_no_white = Image.fromarray(mosaic_masked.astype(np.uint8))
mosaic_q = mosaic_no_white.quantize(colors=NUM_QUANT, method=1)  # 1 = MEDIANCUT
raw_pal = mosaic_q.getpalette()  # flat [R,G,B, R,G,B, ...] × 256

# -------------------------------------------------------
# Build our 8-entry palette
#   index 0 = background (white)
#   indices 1-7 = quantized colors from the GIF
# -------------------------------------------------------
palette_rgb = np.zeros((NUM_COLORS, 3), dtype=np.uint8)
palette_rgb[0] = [bgr, bgg, bgb]
for i in range(1, NUM_COLORS):
    palette_rgb[i] = [raw_pal[(i-1)*3], raw_pal[(i-1)*3+1], raw_pal[(i-1)*3+2]]

print("\nRaw palette (before gamma):")
for i, (r, g, b) in enumerate(palette_rgb):
    print(f"  [{i}] #{r:02x}{g:02x}{b:02x}  ({r},{g},{b})")

# Apply gamma/dither correction
flat_pal = palette_rgb.flatten().astype(np.int32)
flat_pal = gamma_correct(flat_pal)
flat_pal = dither_correct(flat_pal)

print("\nGamma-corrected palette (4-bit per channel after scale):")
for i in range(NUM_COLORS):
    r, g, b = flat_pal[i*3], flat_pal[i*3+1], flat_pal[i*3+2]
    print(f"  [{i}] #{r:02x}{g:02x}{b:02x}")

pal_r = flat_pal[0::3]
pal_g = flat_pal[1::3]
pal_b = flat_pal[2::3]

with open("../data/palette_r.hex", "w") as f:
    f.write(' '.join(f'{v:02x}' for v in pal_r) + '\n')
with open("../data/palette_g.hex", "w") as f:
    f.write(' '.join(f'{v:02x}' for v in pal_g) + '\n')
with open("../data/palette_b.hex", "w") as f:
    f.write(' '.join(f'{v:02x}' for v in pal_b) + '\n')

print("\nWrote palette_r/g/b.hex")

# -------------------------------------------------------
# Build PIL palette image to remap frames to our 8 colors
# -------------------------------------------------------
# PIL palette must be 256 colors (768 bytes); fill unused with 0
pal_flat_pil = [0] * 768
for i in range(NUM_COLORS):
    pal_flat_pil[i*3]   = int(palette_rgb[i, 0])
    pal_flat_pil[i*3+1] = int(palette_rgb[i, 1])
    pal_flat_pil[i*3+2] = int(palette_rgb[i, 2])

pal_img = Image.new("P", (1, 1))
pal_img.putpalette(pal_flat_pil)

# -------------------------------------------------------
# Process each selected frame
# -------------------------------------------------------
src_w, src_h = gif.size
scale = min(TILE_W / src_w, TILE_H / src_h)
scaled_w = int(src_w * scale)
scaled_h = int(src_h * scale)
offset_x = (TILE_W - scaled_w) // 2
offset_y = (TILE_H - scaled_h) // 2

print(f"\nResizing {src_w}x{src_h} → {scaled_w}x{scaled_h}, offset ({offset_x},{offset_y}) on {TILE_W}x{TILE_H} canvas")

bg_color = (int(palette_rgb[0, 0]), int(palette_rgb[0, 1]), int(palette_rgb[0, 2]))
datasiz = NUM_FRAMES * TILE_W * TILE_H

with open(f"../data/{NAME}.hex", "w") as nyanhex:
    for fi in frame_indices:
        gif.seek(fi)
        frame_rgb = gif.convert("RGB")

        # Resize (nearest-neighbor preserves pixel art hard edges)
        frame_small = frame_rgb.resize((scaled_w, scaled_h), Image.NEAREST)

        # Place on background-colored canvas
        canvas = Image.new("RGB", (TILE_W, TILE_H), bg_color)
        canvas.paste(frame_small, (offset_x, offset_y))

        # Map canvas pixels to our 8-color palette (no dithering)
        canvas_rgb = np.array(canvas)  # (H, W, 3)
        quant = canvas.quantize(palette=pal_img, dither=0)
        pixels = np.array(quant, dtype=np.uint8)  # shape (TILE_H, TILE_W)

        # Force near-white pixels → palette index 0 (background)
        is_white = np.all(canvas_rgb >= WHITE_THRESH, axis=2)
        pixels[is_white] = 0

        for row in pixels:
            nyanhex.write(' '.join(f'{int(v):01x}' for v in row) + '\n')

    # Pad to 16384 entries total
    pad = 16384 - datasiz
    print(f"Padding nyan.hex with {pad} x's")
    nyanhex.write('x ' * pad + '\n')

print("\nWrote ../data/fire.hex")
print("Done!")
