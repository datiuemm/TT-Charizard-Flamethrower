import numpy as np
from PIL import Image
import sys

def convert_gif(path, out_name, n_colors=8, step=8):
    gif = Image.open(path)

    frames = []
    try:
        while True:
            frame = gif.convert("RGB")

            # FIX QUAN TRỌNG: giảm màu đúng cách
            frame = frame.quantize(colors=n_colors, method=Image.FASTOCTREE)

            arr = np.array(frame)[::step, ::step]
            frames.append(arr)

            gif.seek(gif.tell() + 1)

    except EOFError:
        pass

    # flatten all frames
    data = frames[0]  # chỉ lấy frame đầu cho đơn giản

    h, w = data.shape

    print(f"[INFO] {path} -> {h}x{w}, colors={n_colors}")

    # pad về 64x32 (FPGA fixed)
    W, H = 64, 32

    hexfile = open(out_name, "w")

    for y in range(H):
        row = []
        for x in range(W):
            if y < h and x < w:
                row.append(data[y][x] & 0x7)
            else:
                row.append(0)

        hexfile.write(" ".join([f"{v:x}" for v in row]) + "\n")

    hexfile.close()
    print(f"[OK] wrote {out_name}")


if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("usage: python gif_to_hex.py input.gif output.hex")
        exit()

    convert_gif(sys.argv[1], sys.argv[2])
