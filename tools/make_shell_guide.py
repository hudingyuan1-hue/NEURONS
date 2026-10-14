"""Generate a geometry-only reference, not a production art asset."""
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "art/guides/bedroom_shell_layout_v001.png"
OUT.parent.mkdir(parents=True, exist_ok=True)
im = Image.new("RGB", (1280, 720), "#222c30")
draw = ImageDraw.Draw(im)

def point(x, z, up=0):
    return ((45 + 80*x + 28*z)*2, (132 + 46*z-up)*2)

floor = [point(0,0), point(5.6,0), point(5.6,3.8), point(0,3.8)]
draw.polygon(floor, fill="#b6a483")
for row in range(20):
    z = row*.2
    if z <= 3.8:
        draw.line([point(0,z),point(5.6,z)], fill="#a59475", width=1)
    for column in range(6):
        x = column + .5*(row%2)
        if x < 5.6 and z+.2 <= 3.8:
            draw.line([point(x,z),point(x,z+.2)],fill="#a08e71",width=1)
draw.polygon([point(0,0),point(5.6,0),point(5.6,0,84),point(0,0,84)], fill="#b0b1a1")
draw.polygon([point(0,0),point(0,3.8),point(0,3.8,84),point(0,0,84)], fill="#c6c1ae")
draw.line([point(0,0,4),point(5.6,0,4)], fill="#6d7067",width=8)
draw.line([point(0,0,4),point(0,3.8,4)], fill="#898977",width=8)
im.save(OUT)
print(OUT)
