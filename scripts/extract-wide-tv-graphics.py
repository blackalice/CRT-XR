"""Extract only the vector printing from the PDF-compatible artwork/TV.ai.

Requires pypdf. The embedded reference screenshot is deliberately excluded.
SVG retains the original outlined lettering and power symbol, without fonts.
"""
from pathlib import Path
from pypdf import PdfReader
from pypdf.generic import ContentStream

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'artwork/widescreen-crt/graphics.svg'


def extract():
    reader = PdfReader(ROOT / 'artwork/TV.ai')
    page = reader.pages[0]
    parts, path = [], []
    width = 1.0
    stack = []
    # Keep the PDF's graphics-state nesting, but discard its placed screenshot.
    for args, op in ContentStream(page.get_contents(), reader).operations:
        values = ' '.join(str(float(v)) for v in args) if op in [b'cm', b'm', b'l', b'c', b're'] else ''
        if op == b'q': parts.append('<g>'); stack.append(1)
        elif op == b'Q': parts.extend(['</g>'] * stack.pop())
        elif op == b'cm':
            parts.append(f'<g transform="matrix({values})">')
            stack[-1] += 1
        elif op in [b'm', b'l', b'c']: path.append({b'm':'M', b'l':'L', b'c':'C'}[op] + values)
        elif op == b'h': path.append('Z')
        elif op == b're':
            x,y,w,h = map(float,args)
            path.append(f'M{x} {y}h{w}v{h}h{-w}Z')
        elif op == b'w': width = float(args[0])
        elif op in [b'f', b'f*', b'S']:
            style = f'fill="none" stroke="white" stroke-width="{width}"' if op == b'S' else 'fill="white" fill-rule="' + ('evenodd' if op == b'f*' else 'nonzero') + '"'
            parts.append(f'<path d="{" ".join(path)}" {style}/>')
            path = []
        elif op == b'n': path = []
    # Coordinates from the reference: 0.700m cabinet spans x=62..2962;
    # its LED centre is (1105,584.5) at z=-0.234855m.
    # Crop to the printed band, with empty border texels for clamped UVs.
    svg = '<svg xmlns="http://www.w3.org/2000/svg" width="2048" height="384" viewBox="62 335 2900 544">\n'
    svg += '<g transform="translate(0 828) scale(1 -1)">\n' + '\n'.join(parts) + '\n</g></svg>\n'
    OUT.write_text(svg, encoding='utf-8')
    print(OUT.relative_to(ROOT))


if __name__ == '__main__': extract()
