"""Inter for the interface, cut to what the app draws (Phase 5.1 commit 1).

Inter 4.001 is a variable font with two axes: optical size (14-32) and
weight (100-900). The app uses neither range: Flutter sets no optical size
(the default, 14, is what renders) and doc/design.md allows two weights,
400 and 500 (the theme caps every style to them). Pinning the optical size
and narrowing the weight axis to 400-500 halves the file — 356 to 174 KB
brotli, about a second on slow 4G — and changes no glyph the app draws:
every character stays (player names may use Latin, Greek, Cyrillic and
Vietnamese letters: name_charset_font_test.dart), outlines at 400 and 500
are the same points, the goldens prove it.

    pip install --user fonttools brotli
    python -P -E tool/fonts/instance_inter.py <Inter[opsz,wght].ttf> app/assets/fonts/Inter.ttf

Source: Inter 4.001 (github.com/rsms/inter, SIL OFL 1.1), the variable
`InterVariable.ttf` — or this repository's Inter.ttf before 21 Nov 2026
(`git show 68c153d:app/assets/fonts/Inter.ttf`).
"""
import sys

from fontTools.ttLib import TTFont
from fontTools.varLib import instancer


def main(src: str, out: str) -> None:
    font = TTFont(src)
    axes = {a.axisTag: a for a in font["fvar"].axes}
    if set(axes) != {"opsz", "wght"} or axes["opsz"].defaultValue != 14:
        raise SystemExit(f"{src}: expected Inter's opsz (default 14) and wght axes")
    # `None` pins an axis at its default; a range keeps it variable within.
    cut = instancer.instantiateVariableFont(font, {"opsz": None, "wght": (400, 500)})
    cut.save(out)


if __name__ == "__main__":
    if len(sys.argv) != 3:
        raise SystemExit(__doc__)
    main(sys.argv[1], sys.argv[2])
