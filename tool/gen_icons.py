#!/usr/bin/env python3
"""Derive every launcher / splash / web icon from the two committed masters.

Masters (hand-authored, never generated — replace these to rebrand):

    assets/images/hmr_launcher.png   512x512  the mark on a dark navy squircle.
                                              The ONLY artwork with a background.
    assets/images/hmr-mark.png      1024x1024 the bare mark, transparent.

Everything else is a derivative. Regenerate with:

    python tool/gen_icons.py
    dart run flutter_launcher_icons       # Android + iOS, from the two masters
    dart run flutter_native_splash:create # splash, from the files written here

Requires Python 3 + Pillow (`pip install Pillow`). The generated files are
committed, so an ordinary checkout never has to run this.

Why the web icons are built here instead of by flutter_launcher_icons: that
tool feeds a single source image to every web output, but a maskable icon has
requirements a favicon must not have — opaque, full-bleed, padded into a safe
zone. One image cannot satisfy both, so the web set is generated here and
`web: generate: false` is set in pubspec.yaml.
"""

from __future__ import annotations

import sys
from pathlib import Path

try:
    from PIL import Image, ImageDraw, ImageFilter, ImageMath
except ImportError:  # pragma: no cover - developer convenience
    sys.exit('Pillow is required: pip install Pillow')

ROOT = Path(__file__).resolve().parent.parent
MARK = ROOT / 'assets' / 'images' / 'hmr-mark.png'

# Brand navy. Identical to HmrTokens.navy950, to the background baked into
# hmr_launcher.png, and to manifest.json's background_color / theme_color.
NAVY = (5, 7, 15, 255)

# How wide the mark sits, as a fraction of the canvas.
#
# MASKED is for any surface the OS crops to a shape we do not control: Android
# adaptive icons, PWA maskable icons, and the Android 12+ splash. The strictest
# of those is the adaptive icon, which only guarantees the middle 66.7% circle
# survives. The mark's circumscribed circle is ~1.00x its own width (the ear
# tips at mid-height are its extreme points), so 0.62 clears that circle with
# margin and keeps all three surfaces visually consistent.
#
# PLAIN is for surfaces nothing crops — the favicon and the "any" web icons.
MASKED_W = 0.62
PLAIN_W = 0.80


def _unpremultiply(channel: Image.Image, alpha: Image.Image) -> Image.Image:
    """Recover a straight-alpha colour channel from a premultiplied one."""
    return ImageMath.lambda_eval(
        lambda args: args['convert'](
            args['min'](
                args['float'](args['c']) * 255.0 / args['max'](args['a'], 1),
                255.0,
            )
            * (args['a'] > 0),
            'L',
        ),
        c=channel,
        a=alpha,
    )


def _resize(img: Image.Image, size: tuple[int, int]) -> Image.Image:
    """Resize RGBA without letting invisible pixels bleed into visible edges.

    Fully transparent pixels in the master still carry colour, and a few pixels
    out from the mark that colour decays to black. A naive resample averages
    those invisible pixels into their visible neighbours, which shows up as a
    dark halo once the mark is scaled down to favicon size. Premultiplying by
    alpha first weights every colour by its own visibility, so invisible pixels
    contribute nothing; dividing it back out afterwards restores straight alpha.
    """
    src = img.convert('RGBA')
    alpha = src.getchannel('A')
    black = Image.new('L', src.size, 0)
    premultiplied = Image.merge(
        'RGBA',
        tuple(Image.composite(band, black, alpha) for band in src.split()[:3])
        + (alpha,),
    )
    scaled = premultiplied.resize(size, Image.Resampling.LANCZOS)
    out_alpha = scaled.getchannel('A')
    return Image.merge(
        'RGBA',
        tuple(_unpremultiply(band, out_alpha) for band in scaled.split()[:3])
        + (out_alpha,),
    )


def compose(
    canvas: int,
    width_frac: float,
    background: tuple | None = None,
    *,
    opaque_eyes: bool = False,
) -> Image.Image:
    """Centre the mark on a square canvas at the requested relative width."""
    mark = Image.open(MARK).convert('RGBA')
    box = mark.getbbox()
    if box is None:
        raise SystemExit(f'{MARK} is fully transparent')
    if opaque_eyes:
        mark = _fill_eyes(mark)
    cropped = mark.crop(box)

    width = round(canvas * width_frac)
    height = max(1, round(cropped.height * width / cropped.width))
    scaled = _resize(cropped, (width, height))

    out = Image.new('RGBA', (canvas, canvas), background or (0, 0, 0, 0))
    out.alpha_composite(scaled, ((canvas - width) // 2, (canvas - height) // 2))
    return out


def _fill_eyes(img: Image.Image) -> Image.Image:
    """Paint the mark's knockout eyes opaque navy, at master resolution.

    On a dark HMR surface a knockout eye just shows the surface behind it,
    which is the intent. A transparent icon can also land on a background it
    knows nothing about, though — a light-theme browser tab strip — and there
    the eyes vanish and the robot reads as a featureless blob. Painting them
    brand navy keeps the icon's background transparent while making the mark
    legible anywhere.

    Only enclosed holes are affected: the area outside the mark is found by
    flooding inwards from a corner, and whatever transparency that flood cannot
    reach must be interior. The navy goes *behind* the artwork rather than
    replacing pixels in it, and the hole mask is grown a couple of pixels first,
    so the anti-aliased rim of each eye blends against navy instead of surviving
    as a translucent ring that turns into a visible halo once downscaled.
    """
    src = img.convert('RGBA')
    # 255 where the mark is drawn, 0 where it is not.
    solid = src.getchannel('A').point(lambda v: 255 if v > 8 else 0)
    if solid.getpixel((0, 0)):
        raise SystemExit('expected a transparent corner to flood from')

    reachable = solid.copy()
    ImageDraw.floodfill(reachable, (0, 0), 128)
    # Still 0 => transparent but unreachable from outside => an eye.
    holes = reachable.point(lambda v: 255 if v == 0 else 0)
    # Grow well inside the surrounding body, which is far thicker than this.
    holes = holes.filter(ImageFilter.MaxFilter(5))

    backing = Image.new('RGBA', src.size, NAVY)
    backing.putalpha(holes)
    return Image.alpha_composite(backing, src)


def write(img: Image.Image, rel: str) -> None:
    path = ROOT / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path, 'PNG', optimize=True)
    print(f'  {rel:44s} {img.width}x{img.height}')


def main() -> None:
    if not MARK.exists():
        raise SystemExit(f'missing master: {MARK}')

    print('Android / splash sources:')
    # Adaptive icon foreground. The safe-zone padding lives here rather than in
    # adaptive_icon_foreground_inset, which pubspec.yaml pins to 0 so that this
    # file is the single place the framing is decided.
    write(compose(1024, MASKED_W), 'assets/images/hmr_launcher_foreground.png')

    # Pre-Android-12 splash: the system draws the image at its natural size on
    # the brand colour and nothing crops it, so the mark keeps its framing.
    write(compose(1024, PLAIN_W), 'assets/images/splash_logo.png')

    # Android 12+ splash: the icon is masked to a circle two thirds the width
    # of a 1152px canvas, so it needs its own padded copy.
    write(compose(1152, MASKED_W), 'assets/images/splash_logo_android12.png')

    print('Web icons:')
    # The "any" icons and the favicon stay transparent, per the rule that only
    # the app launcher carries a background — but with filled eyes, since these
    # can be composited onto a light surface.
    write(compose(512, PLAIN_W, opaque_eyes=True), 'web/icons/Icon-512.png')
    write(compose(192, PLAIN_W, opaque_eyes=True), 'web/icons/Icon-192.png')
    write(compose(64, PLAIN_W, opaque_eyes=True), 'web/favicon.png')

    # Maskable icons must be opaque and full-bleed: the launcher crops them to
    # its own shape, and a transparent one would be cropped to nothing.
    write(compose(512, MASKED_W, NAVY), 'web/icons/Icon-maskable-512.png')
    write(compose(192, MASKED_W, NAVY), 'web/icons/Icon-maskable-192.png')


if __name__ == '__main__':
    main()
