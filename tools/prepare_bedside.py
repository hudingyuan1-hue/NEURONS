"""Resize the opaque material source; never alter/crop the only original.
Run with the workspace bundled Python (Pillow). No alpha threshold or palette
quantization; the in-engine geometry controls projection and silhouette.
"""
from pathlib import Path
from PIL import Image

root = Path(__file__).resolve().parents[1]
source = root / "art/source/bedside_wood_v001.png"
target = root / "neurons/assets/environment/bedside_wood_v001.png"
with Image.open(source) as image:
    assert image.mode == "RGB", "This material contract is fully opaque"
    image.resize((64, 64), Image.Resampling.BOX).save(target)
print(target.relative_to(root))
