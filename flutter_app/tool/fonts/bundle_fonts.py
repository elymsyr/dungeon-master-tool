"""Bundles the Google Fonts the app uses into assets/fonts/, subsetted.

google_fonts loads `<Family>-<Variant>.ttf` from the assets before it tries
the network, and the app turns runtime fetching off, so every family/weight
the app asks for must be listed here.

  uv run --with fonttools python tool/fonts/bundle_fonts.py

Re-run after adding a palette font (palettes.dart) or a dice look font
(dice_roll_view.dart `diceLooks`). The font file hashes come from the
google_fonts package in the pub cache, so the download is the exact file the
package would fetch.
"""
import glob
import hashlib
import os
import re
import sys
import tempfile
import urllib.request

from fontTools import subset

OUT = os.path.join(os.path.dirname(__file__), '..', '..', 'assets', 'fonts')

# UI text: Google Fonts' own latin + latin-ext ranges (en/tr/de/fr and more).
TEXT = ('U+0000-02FF,U+0304,U+0308,U+0329,U+1D00-1DBF,U+1E00-1EFF,'
        'U+2000-206F,U+20A0-20C0,U+2113,U+2122,U+2190-2199,U+2212,U+2215,'
        'U+2C60-2C7F,U+A720-A7FF,U+FEFF,U+FFFD')
# Die faces: numbers, the 6./9. dot, and the settings chip's "20".
DIGITS = 'U+0020,U+002E,U+0030-0039'

# (family, weight, unicodes). Palette fonts are requested at the default
# weight (palettes.dart), dice fonts at w800 (`diceFont`).
FONTS = [
    *((f, 400, TEXT) for f in
      ['JetBrains Mono', 'PT Serif', 'Noto Serif', 'Playfair Display']),
    *((f, 800, DIGITS) for f in
      ['JetBrains Mono', 'PT Serif', 'Noto Serif', 'Playfair Display',
       'Cinzel', 'Philosopher', 'Cormorant Garamond', 'Rye',
       'IM Fell English SC', 'Audiowide', 'UnifrakturMaguntia', 'Quicksand',
       'Uncial Antiqua', 'Cinzel Decorative']),
]

WEIGHT_PART = {100: 'Thin', 200: 'ExtraLight', 300: 'Light', 400: 'Regular',
               500: 'Medium', 600: 'SemiBold', 700: 'Bold', 800: 'ExtraBold',
               900: 'Black'}


def google_fonts_table():
    parts = sorted(glob.glob(os.path.expanduser(
        '~/.pub-cache/hosted/pub.dev/google_fonts-*/lib/src/google_fonts_parts')))
    if not parts:
        sys.exit('google_fonts not in the pub cache; run flutter pub get')
    src = ''.join(open(f).read() for f in glob.glob(parts[-1] + '/*.g.dart'))
    table = {}
    for m in re.finditer(
            r"specimen/([^\n]+)\n\s*static TextStyle \w+\(.*?"
            r"<GoogleFontsVariant, GoogleFontsFile>\{(.*?)\};", src, re.S):
        table[m.group(1).replace('+', ' ').strip()] = [
            (int(w), h, int(n)) for w, s, h, n in re.findall(
                r"FontWeight\.w(\d+),\s*fontStyle: FontStyle\.(normal),\s*\):"
                r" GoogleFontsFile\(\s*'(\w+)',\s*(\d+),", m.group(2))]
    return table


def main():
    table = google_fonts_table()
    os.makedirs(OUT, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        for family, weight, unicodes in FONTS:
            # google_fonts' _closestMatch: nearest weight, lower on a tie.
            w, sha, length = min(table[family],
                                 key=lambda v: (abs(v[0] - weight), v[0]))
            raw = os.path.join(tmp, sha + '.ttf')
            urllib.request.urlretrieve(
                f'https://fonts.gstatic.com/s/a/{sha}.ttf', raw)
            data = open(raw, 'rb').read()
            if len(data) != length or hashlib.sha256(data).hexdigest() != sha:
                sys.exit(f'{family} w{w}: checksum mismatch')
            name = f"{family.replace(' ', '')}-{WEIGHT_PART[w]}.ttf"
            subset.main([raw, f'--unicodes={unicodes}',
                         f'--output-file={os.path.join(OUT, name)}'])
            print(f'{name:40} {length // 1024:5} KB -> '
                  f'{os.path.getsize(os.path.join(OUT, name)) // 1024:4} KB')

    # OFL 1.1 travels with the fonts; main.dart adds it to the licence page.
    licences = []
    for family in dict.fromkeys(f for f, _, _ in FONTS):
        url = ('https://raw.githubusercontent.com/google/fonts/main/ofl/'
               f"{family.replace(' ', '').lower()}/OFL.txt")
        with urllib.request.urlopen(url) as r:
            licences.append(f'{family}\n\n{r.read().decode().strip()}\n')
    with open(os.path.join(OUT, 'OFL.txt'), 'w') as f:
        f.write(('\n' + '-' * 72 + '\n\n').join(licences))


if __name__ == '__main__':
    main()
