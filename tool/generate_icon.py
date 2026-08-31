"""Draws the app icon.

Kept as a script rather than a checked-in binary so the icon can be regenerated
at any size, and so its colours stay tied to the ones the app actually uses
(see lib/util/glucose_colors.dart and lib/app.dart).

Renders at 4x and downsamples for anti-aliasing. The trace is stroked by
stamping discs along the path rather than with ImageDraw.line(width=...),
whose mitre/curve joins fringe badly at this thickness.

    python3 tool/generate_icon.py
"""

import math
import pathlib

from PIL import Image, ImageDraw, ImageFont

SIZE = 1024
SS = 4
S = SIZE * SS

# The app's seed colour (#2E7DF6) and in-range green (#3FB86F).
BG_TOP = (24, 68, 152)
BG_BOTTOM = (46, 125, 246)
TRACE = (255, 255, 255)
IN_RANGE = (63, 184, 111)


def glucose_curve(t: float) -> float:
    """A CGM trace over [0, 1] -> roughly [0, 1], 0 = bottom.

    Deliberately calm: a steady stretch, one clear post-meal excursion, and a
    recovery that settles back. Busier shapes turn to mush at 48 px, so the
    undulation is kept small enough to survive downsampling.
    """
    base = 0.30
    drift = 0.04 * math.sin(t * 6.5 + 0.4) + 0.02 * math.sin(t * 15.0)
    spike = 0.60 * math.exp(-(((t - 0.54) / 0.14) ** 2))
    return base + drift + spike


def stroke(draw: ImageDraw.ImageDraw, pts, width: float, fill) -> None:
    """Stroke a path by stamping discs — clean caps and joins, no fringing."""
    r = width / 2
    for i in range(len(pts) - 1):
        (x0, y0), (x1, y1) = pts[i], pts[i + 1]
        dist = math.hypot(x1 - x0, y1 - y0)
        steps = max(1, int(dist / (r * 0.25)))
        for k in range(steps + 1):
            u = k / steps
            cx, cy = x0 + (x1 - x0) * u, y0 + (y1 - y0) * u
            draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=fill)


def draw_icon(with_background: bool) -> Image.Image:
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    if with_background:
        for y in range(S):
            k = y / S
            d.line(
                [(0, y), (S, y)],
                fill=tuple(round(a + (b - a) * k) for a, b in zip(BG_TOP, BG_BOTTOM)),
            )

    # Adaptive-icon foregrounds need a wider margin: many launchers crop to a
    # circle, so anything near the edge is lost.
    margin = 0.19 if with_background else 0.29
    left, right = S * margin, S * (1 - margin)
    span = right - left
    mid = S * 0.52
    height = S * (0.40 if with_background else 0.32)

    def y_at(t: float) -> float:
        return mid + height * 0.42 - glucose_curve(t) * height

    # Target-range band. Tinted white rather than green: green over the blue
    # background alpha-blends to a murky teal, and the band should recede
    # behind the trace anyway.
    band = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(band).rounded_rectangle(
        [left - span * 0.06, mid - height * 0.06,
         right + span * 0.06, mid + height * 0.44],
        radius=S * 0.028,
        fill=(255, 255, 255, 46) if with_background else (255, 255, 255, 60),
    )
    img.alpha_composite(band)

    width = S * (0.052 if with_background else 0.047)
    pts = [(left + span * (i / 200), y_at(i / 200)) for i in range(201)]
    stroke(d, pts, width, TRACE)

    # The newest reading, in the app's in-range green — the one accent, and the
    # only place the palette's meaning shows through.
    cx, cy = pts[-1]
    r = width * 0.92
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=TRACE)
    r *= 0.62
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=IN_RANGE + (255,))

    return img.resize((SIZE, SIZE), Image.LANCZOS)


def feature_graphic() -> Image.Image:
    """Play's 1024x500 listing banner: the icon motif, set beside the name."""
    W, H = 1024 * SS, 500 * SS
    img = Image.new("RGBA", (W, H))
    d = ImageDraw.Draw(img)
    for y in range(H):
        k = y / H
        d.line([(0, y), (W, y)],
               fill=tuple(round(a + (b - a) * k) for a, b in zip(BG_TOP, BG_BOTTOM)))

    # The same trace as the icon, running the full width behind the text.
    left, right = W * 0.04, W * 0.96
    span = right - left
    # Sits below the wordmark; the trace is a backdrop, not a divider.
    mid = H * 0.84
    height = H * 0.30
    pts = [
        (left + span * (i / 240),
         mid + height * 0.42 - glucose_curve(i / 240) * height)
        for i in range(241)
    ]
    stroke(d, pts, H * 0.028, (255, 255, 255, 64))

    for path in (
        "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
        "/System/Library/Fonts/Helvetica.ttc",
    ):
        try:
            title = ImageFont.truetype(path, int(H * 0.155))
            sub = ImageFont.truetype(path, int(H * 0.070))
            break
        except OSError:
            continue
    else:  # pragma: no cover - only if no system font is present
        title = sub = ImageFont.load_default()

    d.text((W * 0.06, H * 0.30), "Glucose Chart", font=title, fill=(255, 255, 255))
    d.text((W * 0.065, H * 0.52), "Your CGM history, at a glance",
           font=sub, fill=(220, 232, 255))

    return img.resize((1024, 500), Image.LANCZOS).convert("RGB")


out = pathlib.Path("assets/icon")
out.mkdir(parents=True, exist_ok=True)

# Full-bleed and flattened — iOS rejects icons carrying an alpha channel.
full = draw_icon(with_background=True).convert("RGB")
full.save(out / "icon.png")
draw_icon(with_background=False).save(out / "icon_foreground.png")
full.resize((512, 512), Image.LANCZOS).save(out / "play_store_512.png")
feature_graphic().save(out / "play_feature_graphic_1024x500.png")
print("wrote icon.png, icon_foreground.png, play_store_512.png, "
      "play_feature_graphic_1024x500.png")
