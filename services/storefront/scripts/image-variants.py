#!/usr/bin/env python3
"""Writes a small WebP beside every photograph, for the storefront's srcset.

Run at image build time (see the Dockerfile's `variants` stage), not committed:
the photographs are the source of truth and a variant is derived from them, so
keeping both in Git would be a second copy that drifts the first time a photo
is replaced under the same name -- which this shop does (context_summary.md,
26 September 2026: six photos replaced, "the files kept their names").

For `species/demasoni.jpg` it writes `variants/480/species/demasoni.webp` and
`variants/960/species/demasoni.webp`. A product card is ~340 CSS px wide, so
480 covers a 1x screen and 960 a 2x one; the original stays in the srcset as
the largest candidate for the product page's hero.

Why it exists: before this, a card showed the full 1600px JPEG -- 200-690 KB
each -- in a slot a sixth that wide, so the Lake Malawi page fetched ~4 MB of
photographs to draw fifteen thumbnails. Measured before and after in
RELEASE-NOTES.md.

Usage: image-variants.py <public-dir> <out-dir>
"""
import sys
from pathlib import Path

from PIL import Image

WIDTHS = (480, 960)
QUALITY = 78          # WebP q78 is visually lossless at card size on these photos
SOURCES = ("species", "sections", "collections")


def main(public: Path, out: Path) -> int:
    written = 0
    for folder in SOURCES:
        for src in sorted((public / folder).glob("*.jpg")):
            with Image.open(src) as im:
                im = im.convert("RGB")
                for w in WIDTHS:
                    # Never upscale: a variant wider than its source is the
                    # same pixels in a bigger file.
                    target = im if im.width <= w else im.resize(
                        (w, round(im.height * w / im.width)), Image.LANCZOS)
                    dest = out / str(w) / folder / (src.stem + ".webp")
                    dest.parent.mkdir(parents=True, exist_ok=True)
                    target.save(dest, "WEBP", quality=QUALITY, method=6)
                    written += 1
    print(f"image-variants: wrote {written} files")
    # Zero is a build error, not a quiet success: IMAGE_VARIANTS=1 in the
    # image promises these files exist, and every card would fall back to its
    # placeholder if they did not.
    return 0 if written else 1


if __name__ == "__main__":
    sys.exit(main(Path(sys.argv[1]), Path(sys.argv[2])))
