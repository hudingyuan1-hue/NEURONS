"""Downsample a retained opaque source; geometry masking occurs only in Godot."""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
source = ROOT / "art/source/bedroom_shell_v001.png"
target = ROOT / "neurons/assets/environment/bedroom_shell_v001.png"
target.parent.mkdir(parents=True, exist_ok=True)
with Image.open(source) as im:
    assert im.mode in ("RGB", "RGBA")
    if "A" in im.getbands():
        assert im.getchannel("A").getextrema() == (255, 255), "Source must be opaque"
    print(f"source={im.size} mode={im.mode}")
    im.convert("RGB").resize((640, 360), Image.Resampling.LANCZOS).save(target)
print(target)
