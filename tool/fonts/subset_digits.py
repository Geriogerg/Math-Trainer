"""Digit typeface for the app (Phase 5 commit 1, doc/plan.md section 6.2).

Cuts a variable font from google/fonts (SIL OFL) down to what the game
draws in it: a static weight-500 instance (doc/design.md: digits at 500),
only the digits and the operator glyphs, tabular figures kept. A few KB
instead of 100+, so the first load barely moves (budget: +50 KB).

    pip install --user fonttools brotli
    python -P -E tool/fonts/subset_digits.py <Font[wght].ttf> <out.ttf>

Other letters ("Level", "Top") are not in the subset: the theme names
Inter as the fallback family, which draws them. The "of" of "25% of 80"
is, and the "de" of "25 % de 80" (Phase 6d): a prompt drawn in two faces gets a line 1 px taller (mixed metrics),
which would move the answer below it during the beta
(`session_layout_pin_test.dart`).
"""
import io
import sys

from fontTools import subset
from fontTools.ttLib import TTFont
from fontTools.varLib import instancer

# Digits; + − × ÷ √ % as doc/design.md writes them; what scores and times
# print (= . , space); the "of" of a percentage prompt, and its French "de"
# (Phase 6d); the thin space (U+2009) that groups digits.
GLYPHS = "0123456789+−×÷√%=., ofde\u2009"

# The group separator the app writes is the narrow no-break space (U+202F,
# number_format.dart): Space Grotesk has no glyph for it, so it is mapped
# to the thin space's — same width, and it never breaks a line.
ALIASES = {0x202F: 0x2009}


def main(src: str, out: str) -> None:
    static = instancer.instantiateVariableFont(TTFont(src), {"wght": 500})
    buffer = io.BytesIO()
    static.save(buffer)
    buffer.seek(0)
    font = TTFont(buffer)
    options = subset.Options()
    # `tnum`: FontFeature.tabularFigures() in the theme picks it up.
    options.layout_features = ["tnum", "kern"]
    options.name_IDs = ["*"]  # keeps the OFL notice in the name table
    options.notdef_outline = True
    options.hinting = False
    subsetter = subset.Subsetter(options)
    subsetter.populate(text=GLYPHS)
    subsetter.subset(font)
    for table in font["cmap"].tables:
        if table.isUnicode():
            for alias, target in ALIASES.items():
                if target in table.cmap:
                    table.cmap[alias] = table.cmap[target]
    font.save(out)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
