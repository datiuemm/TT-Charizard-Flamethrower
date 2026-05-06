from PIL import Image

im = Image.open("Charizard Gif Pixel.gif")

target_w = 272
target_h = 168

w, h = im.size

left = 0
right = target_w

top = h - target_h
bottom = h

frames = []

for i in range(getattr(im, "n_frames", 1)):
    im.seek(i)
    frame = im.copy()
    frame = frame.crop((left, top, right, bottom))
    frames.append(frame.copy())

frames[0].save(
    "crop.gif",
    save_all=True,
    append_images=frames[1:],
    loop=0,
    duration=im.info.get("duration", 100)
)
