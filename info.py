from PIL import Image

im = Image.open("original.gif")

print("format:", im.format)
print("size:", im.size)        # (width, height)
print("mode:", im.mode)
print("frames:", getattr(im, "n_frames", 1))
print("duration:", im.info.get("duration"), "ms/frame")
