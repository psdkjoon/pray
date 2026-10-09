#!/usr/bin/env python3
"""Builds the lightweight Noto fonts in assets/fonts/noto.

The full Noto families are huge (the CJK ones are ~16 MB each), and the app
only ever draws a small part of them. This script keeps just:

  * the scripts a language needs (Latin/Cyrillic, Arabic/Persian, kana, ...)
  * every non-ASCII character that appears anywhere in lib/*.dart, so all
    translations render with the bundled font

Anything else (for example a CJK character inside a server name) is drawn by
the system fonts through Flutter's normal fallback.

Re-run it after adding translations that use new characters:

    python3 scripts/subset_fonts.py --src <dir with the original fonts>

--src must contain:
    NotoSans[wdth,wght].ttf          (google/fonts: ofl/notosans)
    NotoSansArabic[wdth,wght].ttf    (google/fonts: ofl/notosansarabic)
    NotoSansCJKsc-{Regular,Bold}.otf (notofonts/noto-cjk: Sans/OTF/SimplifiedChinese)
    NotoSansCJKjp-{Regular,Bold}.otf (notofonts/noto-cjk: Sans/OTF/Japanese)

Requires: pip install fonttools
"""
import argparse
import pathlib
import sys

from fontTools import subset
from fontTools.ttLib import TTFont
from fontTools.varLib import instancer

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "fonts" / "noto"


def used_chars() -> set[int]:
    chars: set[int] = set()
    for path in (ROOT / "lib").rglob("*.dart"):
        for ch in path.read_text(encoding="utf-8"):
            if ord(ch) > 0x7F and ch not in "​﻿":
                chars.add(ord(ch))
    return chars


def rng(*ranges: tuple[int, int]) -> set[int]:
    out: set[int] = set()
    for lo, hi in ranges:
        out.update(range(lo, hi + 1))
    return out


ASCII = rng((0x20, 0x7E))
PUNCT = rng((0xA0, 0xFF), (0x2000, 0x206F), (0x20A0, 0x20CF), (0x2190, 0x21FF),
            (0x2212, 0x2212), (0x2022, 0x2022), (0x2026, 0x2026))
LATIN = ASCII | PUNCT | rng((0x100, 0x17F), (0x218, 0x21B))
CYRILLIC = rng((0x400, 0x4FF), (0x500, 0x52F), (0x1C80, 0x1C8F))
ARABIC = (ASCII | rng((0xA0, 0xFF), (0x600, 0x6FF), (0x750, 0x77F),
                      (0x8A0, 0x8FF), (0x200C, 0x200F), (0x2010, 0x2027),
                      (0x202F, 0x2030), (0x2039, 0x203A), (0xFB50, 0xFDFF),
                      (0xFE70, 0xFEFF)))
CJK_COMMON = (ASCII | PUNCT | rng((0x3000, 0x303F), (0x3040, 0x309F),
                                  (0x30A0, 0x30FF), (0x31F0, 0x31FF),
                                  (0xFF00, 0xFFEF), (0x2460, 0x24FF),
                                  (0x25A0, 0x25FF)))

LAYOUT = ["kern", "liga", "clig", "calt", "ccmp", "locl", "mark", "mkmk",
          "curs", "init", "medi", "fina", "isol", "rlig", "rclt", "dist",
          "vert", "vrt2", "palt", "ss01", "case"]


def subset_font(font: TTFont, unicodes: set[int], out: pathlib.Path,
                *, hinting: bool) -> None:
    opts = subset.Options()
    opts.layout_features = LAYOUT
    opts.hinting = hinting
    opts.name_IDs = [1, 2, 3, 4, 6]
    opts.name_languages = [0x409]
    opts.notdef_outline = True
    opts.glyph_names = False
    opts.legacy_kern = False
    opts.drop_tables += ["DSIG", "FFTM", "meta", "STAT", "vhea", "vmtx"]
    sub = subset.Subsetter(opts)
    sub.populate(unicodes=sorted(unicodes))
    sub.subset(font)
    out.parent.mkdir(parents=True, exist_ok=True)
    font.save(out)
    print(f"{out.name:28} {out.stat().st_size / 1024:8.1f} KiB")


def static_from_variable(src: pathlib.Path, weight: int) -> TTFont:
    var = TTFont(src)
    return instancer.instantiateVariableFont(
        var, {"wght": weight, "wdth": 100}, inplace=False, updateFontNames=False)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", required=True, type=pathlib.Path)
    args = ap.parse_args()
    src: pathlib.Path = args.src
    extra = used_chars()
    print(f"{len(extra)} non-ASCII characters used by lib/*.dart")

    for name, weight in (("Regular", 400), ("Medium", 500), ("Bold", 700)):
        font = static_from_variable(src / "NotoSans[wdth,wght].ttf", weight)
        subset_font(font, LATIN | CYRILLIC | extra & (LATIN | CYRILLIC),
                    OUT / f"NotoSans-{name}.ttf", hinting=False)
        font = static_from_variable(src / "NotoSansArabic[wdth,wght].ttf", weight)
        subset_font(font, ARABIC | extra & ARABIC,
                    OUT / f"NotoSansArabic-{name}.ttf", hinting=False)

    for code, folder in (("sc", "SC"), ("jp", "JP")):
        for name in ("Regular", "Bold"):
            font = TTFont(src / f"NotoSansCJK{code}-{name}.otf")
            subset_font(font, CJK_COMMON | extra,
                        OUT / f"NotoSans{folder}-{name}.otf", hinting=False)
    return 0


if __name__ == "__main__":
    sys.exit(main())
