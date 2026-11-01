"""CRT XR pixel logo, for the menus' 2x2-pixel grid: a hand-drawn small mark (40x35)
and a large one traced from the artwork (128x126), each with the spectrum stripe as
stepped 15-bit bands. Writes assets/branding/logo/logo-small.png and logo-large.png."""
from PIL import Image
import sys
from pathlib import Path
OUT = sys.argv[1] if len(sys.argv) > 1 else str(Path(__file__).resolve().parents[1] / 'assets/branding/logo')
WHITE = (248, 248, 248)
src = Image.open(Path(__file__).resolve().parents[1] / 'assets/branding/logo/crt-xr-logo-source.png').convert('RGB')
grey = src.convert('L')
q5 = lambda c: tuple(round(v / 255 * 31) * 255 // 31 for v in c)
BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]

def stripe_colour(t):
    return q5(src.getpixel((round(148 + t * (1293 - 148)), 1329)))

# 40 x 38: drawn by hand, a pixel at a time.
SMALL = """
    #####      #######       #            #
  ##     ##      ##   ##     ##############
 ##        #     ##    ##          ##
##               ##    ##          ##
##               ##    ##          ##
##               ##   ##           ##
##               ######            ##
##               ##  ##            ##
##               ##   ##           ##
##               ##   ##           ##
##               ##    ##          ##
 ##              ##    ##          ##
  ##      #      ##     ##         ##
   ##   ##       ##     ###        ##
    #####      ######     ###    ######


######      ######    ################  
 ######    ######     ################# 
  ######  ######      ##################
   ############       #####       ######
    ##########        #####        #####
     ########         #####        #####
      ######          #####       ######
      ######          ################# 
     ########         ################  
    ##########        #####      ###### 
   ############       #####       ######
  ######  ######      #####       ######
 ######    ######     #####       ######
######      ######    #####       ######
"""

def from_art(art, width):
    rows = art.strip('\n').split('\n')
    return [r.ljust(width)[:width] for r in rows]

def stripe(img, y0, height, bands, dither_width):
    px = img.load(); w = img.width
    for y in range(y0, y0 + height):
        for x in range(w):
            # Equal bands across the width; f runs from band centre to band centre.
            f = max(0.0, (x + 0.5) / w * bands - 0.5)
            i = int(f); frac = f - i
            if not dither_width: i = x * bands // w; frac = 0.0
            # Hard steps, with a short dithered seam between neighbours.
            edge = (frac - (1 - dither_width)) / dither_width if dither_width else -1
            if edge > 0 and (BAYER[y % 4][x % 4] + 0.5) / 16 < edge: i += 1
            px[x, y] = stripe_colour(min(i, bands - 1) / (bands - 1))

def save(img, name):
    img.save(f'{OUT}/{name}.png')

# Small.
rows = from_art(SMALL, 40)
small = Image.new('RGBA', (40, len(rows) + 4), (0, 0, 0, 0))
for y, row in enumerate(rows):
    for x, ch in enumerate(row):
        if ch == '#': small.putpixel((x, y), WHITE + (255,))
stripe(small, len(rows) + 1, 3, 8, 0)
save(small, 'logo-small')

# Large: traced from the artwork at 128 wide, then tidied.
W = 128
large_rows = []
for (y0, y1), h in [((287, 722), 51), ((819, 1211), 46)]:
    band = grey.crop((148, y0, 1295, y1)).resize((W, h), Image.BOX)
    large_rows.append([[band.getpixel((x, y)) >= 110 for x in range(W)] for y in range(h)])
large = Image.new('RGBA', (W, 51 + 11 + 46 + 9 + 9), (0, 0, 0, 0))
for y, row in enumerate(large_rows[0]):
    for x, on in enumerate(row):
        if on: large.putpixel((x, y), WHITE + (255,))
for y, row in enumerate(large_rows[1]):
    for x, on in enumerate(row):
        if on: large.putpixel((x, 62 + y), WHITE + (255,))
stripe(large, 62 + 46 + 9, 9, 16, 0.5)
save(large, 'logo-large')
print(small.size, large.size)
