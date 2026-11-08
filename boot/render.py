#!/usr/bin/env python3
"""Render the Ion assets. Requires python-fonttools and librsvg, only when editing art."""
from pathlib import Path
import shutil
import subprocess
import xml.etree.ElementTree as ET

from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.boundsPen import BoundsPen
from fontTools.pens.transformPen import TransformPen
from fontTools.ttLib import TTFont
from fontTools.varLib.instancer import instantiateVariableFont

HERE = Path(__file__).resolve().parent
REPO = HERE.parent
OUT = HERE / 'ion'
NS = '{http://www.w3.org/2000/svg}'
MARK = ET.parse(REPO / 'branding/neon/diamant.svg').find(f'.//{NS}polyline').attrib['points']

GRADIENTS = '''
<linearGradient id="ion" x1="0" y1="0" x2="1" y2="1" gradientUnits="objectBoundingBox">
  <stop stop-color="#76d9fa"/><stop offset="1" stop-color="#b59aff"/>
</linearGradient>
<linearGradient id="rainbow" x1="0" y1="0.3" x2="1" y2="0.7">
  <stop stop-color="#6cebd7"/><stop offset=".22" stop-color="#76d9fa"/>
  <stop offset=".45" stop-color="#a5a0ff"/><stop offset=".65" stop-color="#ed91e7"/>
  <stop offset=".83" stop-color="#ffadad"/><stop offset="1" stop-color="#ffe29a"/>
</linearGradient>
<filter id="glow" x="-50%" y="-50%" width="200%" height="200%">
  <feGaussianBlur stdDeviation="8"/>
</filter>
<radialGradient id="veil"><stop stop-color="#3e6c91" stop-opacity=".23"/>
  <stop offset="1" stop-color="#101019" stop-opacity="0"/></radialGradient>
'''


def diamond(x, y, size, glow=False):
    line = f'<polyline points="{MARK}" fill="none" stroke="url(#ion)" stroke-width="9" stroke-linejoin="miter" stroke-linecap="square"/>'
    if glow:
        line = f'<g filter="url(#glow)">{line}</g>'
    return f'<g transform="translate({x} {y}) scale({size / 256})">{line}</g>'


def wordmark(text):
    # Outlines keep the exact lettering in Limine and the early boot environment.
    font = instantiateVariableFont(TTFont(REPO / 'branding/fonts/Inter-Variable.ttf'), {'wght': 850})
    glyphs = font.getGlyphSet()
    cmap = font.getBestCmap()
    pen, bounds, advance = SVGPathPen(glyphs), BoundsPen(glyphs), 0
    for letter in text:
        name = cmap[ord(letter)]
        glyphs[name].draw(TransformPen(pen, (1, 0, 0, 1, advance, 0)))
        glyphs[name].draw(TransformPen(bounds, (1, 0, 0, 1, advance, 0)))
        advance += glyphs[name].width - 55
    path = f'<path d="{pen.getCommands()}" fill="url(#rainbow)"/>'
    left, _, right, _ = bounds.bounds
    x = (470 - (right - left) * .055) / 2 - left * .055
    return f'<g transform="translate({x:g} 100) scale(.055 -.055)">{path}</g>'


# Plymouth uses capitals; Limine, SDDM and the lock screen use 'Yunagi'
WORD = wordmark('Yunagi')
WORD_CAPS = wordmark('YUNAGI')


def lettering(x, y, width):
    return f'<svg x="{x}" y="{y}" width="{width}" height="{width * 140 / 470}" viewBox="0 0 470 140">{WORD}</svg>'


def atmosphere():
    return '''<rect width="1920" height="1080" fill="#08090e"/>
<ellipse cx="1270" cy="510" rx="1000" ry="500" fill="url(#veil)" transform="rotate(-21 1270 510)"/>
<path d="M-200 910 L2120 -50" stroke="#66c3ed" stroke-opacity=".045" stroke-width="100" filter="url(#glow)"/>
<path d="M-200 910 L2120 -50" stroke="#76d9fa" stroke-opacity=".37" stroke-width="2"/>'''


def write(name, width, height, body):
    path = OUT / name
    path.parent.mkdir(parents=True, exist_ok=True)
    path.with_suffix('.svg').write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}"><defs>{GRADIENTS}</defs>{body}</svg>\n')
    subprocess.run(['rsvg-convert', str(path.with_suffix('.svg')), '-o', str(path.with_suffix('.png'))], check=True)


write('limine', 1920, 1080, atmosphere() + diamond(1352, 367, 216, True) + diamond(1352, 367, 216) + lettering(1290, 616, 340))
write('plymouth/wordmark', 470, 140, WORD_CAPS)
write('wordmark', 470, 140, WORD)
for target in ('sddm/yunagi/wordmark.png', 'home/.config/hypr/lock/wordmark.png'):
    shutil.copyfile(OUT / 'wordmark.png', REPO / target)
# Password field for the disk unlock prompt
write('plymouth/field', 420, 56, '<rect x=".5" y=".5" width="419" height="55" rx="10" fill="#0e0e14" fill-opacity=".9" stroke="#2a2a35"/>')
# Orbit around the wordmark: ellipse a=300, b=90, tilted -10 degrees, in a 680x300 canvas
write('plymouth/orbit', 680, 300, '<ellipse cx="340" cy="150" rx="300" ry="90" transform="rotate(-10 340 150)" '
      'fill="none" stroke="url(#ion)" stroke-opacity=".45" stroke-width="2"/>')
write('plymouth/dot', 48, 48, '<radialGradient id="d"><stop stop-color="#e8f8ff"/><stop offset=".25" stop-color="#76d9fa"/>'
      '<stop offset="1" stop-color="#76d9fa" stop-opacity="0"/></radialGradient><circle cx="24" cy="24" r="24" fill="url(#d)"/>')
write('plymouth/pulse', 64, 4, '<rect width="64" height="4" rx="2" fill="url(#ion)"/>')
write('plymouth/track', 64, 4, '<rect width="64" height="4" rx="2" fill="#2c293b"/>')
