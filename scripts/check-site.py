#!/usr/bin/env python3
"""
Checks the Loopd website in Firebase/hosting. Reads files only.

    python3 scripts/check-site.py

It catches things that quietly go wrong when a page is edited:
  - the example map's numbers no longer match its drawing
  - a gradient, glow, script or inline style sneaks in (the site's security rules block them)
  - a link points at a page that does not exist
  - dashes or semicolons in the visible text
  - missing alt text, titles or headings
"""
import os
import re
import sys
from html.parser import HTMLParser

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
SITE = os.path.join(ROOT, "Firebase", "hosting")
BLOCK_PX = 40            # one street block is 40 drawing units, which stands for 1/8 mile
BLOCK_SQMI = 1 / 64      # an eighth of a mile on each side

fails = []


def ok(msg):
    print("  ok    " + msg)


def fail(msg):
    print("  FAIL  " + msg)
    fails.append(msg)


class Page(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.text = []
        self.tags = []
        self.ids = set()
        self.links = []
        self.imgs = []
        self.attrs_seen = []
        self._skip = 0
        self.stack = []

    def handle_starttag(self, tag, attrs):
        d = dict(attrs)
        self.tags.append((tag, d))
        if "id" in d:
            self.ids.add(d["id"])
        if tag == "a" and "href" in d:
            self.links.append(d["href"])
        if tag == "link" and "href" in d:
            self.links.append(d["href"])
        if tag == "img":
            self.imgs.append(d)
        if tag in ("style", "script"):
            self._skip += 1
        if tag not in ("meta", "link", "br", "img", "hr", "input", "path", "rect", "circle", "polygon", "source"):
            self.stack.append(tag)

    def handle_endtag(self, tag):
        if tag in ("style", "script") and self._skip:
            self._skip -= 1
        if self.stack and self.stack[-1] == tag:
            self.stack.pop()
        elif tag in self.stack:
            self.stack.remove(tag)

    def handle_data(self, data):
        if not self._skip:
            self.text.append(data)


def read(name):
    with open(os.path.join(SITE, name), encoding="utf-8") as f:
        return f.read()


def parse(name):
    p = Page()
    p.feed(read(name))
    return p


def shoelace(points):
    s = 0.0
    for i in range(len(points)):
        x1, y1 = points[i]
        x2, y2 = points[(i + 1) % len(points)]
        s += x1 * y2 - x2 * y1
    return abs(s) / 2


def polygon_points(html, element_id):
    m = re.search(r'<polygon id="%s"[^>]*points="([^"]+)"' % element_id, html)
    if not m:
        return None
    return [tuple(float(n) for n in pair.split(",")) for pair in m.group(1).split()]


pages = [f for f in sorted(os.listdir(SITE)) if f.endswith(".html")]
print("Pages:", ", ".join(pages))

# ------------------------------------------------------------------ rules for every page
print("\nEvery page")
for name in pages:
    html, p = read(name), parse(name)
    visible = " ".join(p.text)
    if "style=" in html or "<style" in html:
        fail(f"{name}: has inline styles, which the site's security rules block")
    if "<script" in html:
        fail(f"{name}: has a script, which the site's security rules block")
    if re.search(r"gradient|box-shadow:[^;]*rgba\([^)]*,\s*0?\.\d+\)[^;]*0 0 \d+px|text-shadow", html, flags=re.I):
        fail(f"{name}: has a gradient or glow")
    if "\u2014" in visible or ";" in visible:
        fail(f"{name}: has a dash or semicolon in the visible text")
    if not re.search(r"<title>[^<]+</title>", html):
        fail(f"{name}: no title")
    if '<html lang="' not in html:
        fail(f"{name}: no language set")
    if sum(1 for t, _ in p.tags if t == "h1") != 1:
        fail(f"{name}: needs exactly one h1")
    for img in p.imgs:
        if "alt" not in img:
            fail(f"{name}: an image has no alt attribute")
    if p.stack:
        fail(f"{name}: unclosed tags {p.stack}")
    if "YOUR-" in html:
        fail(f"{name}: still has a YOUR- placeholder")

css = re.sub(r"/\*.*?\*/", "", read("styles.css"), flags=re.S)   # comments may talk about gradients
if re.search(r"gradient|text-shadow", css, flags=re.I):
    fail("styles.css: has a gradient or text shadow")
if not fails:
    ok("no inline styles, scripts, gradients, glows, dashes or placeholders, and every page is well formed")

# ------------------------------------------------------------------ links
print("\nLinks")
GENERATED = {"/logo.png", "/favicon.png", "/apple-touch-icon.png"}   # made by scripts/add-logo.sh
known = {"/": "index.html"}
for g in GENERATED:
    known[g] = g
for f in pages:
    known["/" + f[:-5]] = f
for f in os.listdir(SITE):
    known["/" + f] = f
bad_links = []
for name in pages:
    p = parse(name)
    for href in p.links:
        if href.startswith(("mailto:", "http://", "https://", "data:")):
            continue
        target = href.split("#")[0] or ("/" + name)
        if target not in known:
            bad_links.append(f"{name} -> {href}")
        if "#" in href and target in ("/", "/" + name) and href.split("#")[1] not in p.ids:
            bad_links.append(f"{name} -> {href} (no element with that id)")
if bad_links:
    for b in bad_links:
        fail("broken link: " + b)
else:
    ok("every link points at something that exists")

assets_missing = [f for f in ("logo.png", "favicon.png", "apple-touch-icon.png") if not os.path.exists(os.path.join(SITE, f))]
if assets_missing:
    print("  note  not there yet: " + ", ".join(assets_missing) + "  (bash scripts/add-logo.sh makes them)")
else:
    ok("logo and icons are present")

# ------------------------------------------------------------------ the example map
print("\nThe example map on the home page")
home = read("index.html")
mine = polygon_points(home, "my-land")
friend_left = polygon_points(home, "friend-land")
if not mine or not friend_left:
    fail("could not find the two land shapes in index.html")
else:
    my_blocks = shoelace(mine) / BLOCK_PX ** 2
    left_blocks = shoelace(friend_left) / BLOCK_PX ** 2
    # The friend's land was a 6 by 5 block rectangle before the loop took a piece of it.
    friend_before = 6 * 5
    taken_blocks = friend_before - left_blocks
    sq_mi = my_blocks * BLOCK_SQMI
    points = round(sq_mi * 1000)   # the app and the server both round like this
    taken_sq_mi = taken_blocks * BLOCK_SQMI

    text = re.sub(r"\s+", " ", " ".join(parse("index.html").text))
    claims = {
        "blocks in the loop": (re.search(r"loop of (\d+) blocks", text), str(int(my_blocks))),
        "square miles": (re.search(r"([\d.]+) square miles, ?\s*([\d,]+) points", text), "%.2f" % sq_mi),
        "points": (re.search(r"([\d.]+) square miles, ?\s*([\d,]+) points", text), str(points)),
        "square miles taken": (re.search(r"([\d.]+) square miles, were a friend", text), "%.2f" % taken_sq_mi),
    }
    all_ok = True
    for label, (match, expected) in claims.items():
        if not match:
            fail(f"could not find the {label} in the page text")
            all_ok = False
            continue
        found = match.group(2) if label == "points" else match.group(1)
        if found.replace(",", "") != expected:
            fail(f"{label}: the page says {found} but the drawing works out to {expected}")
            all_ok = False
    taken_rect = re.search(r'<rect id="taken"[^>]*width="(\d+)"[^>]*height="(\d+)"', home)
    if taken_rect:
        rect_blocks = int(taken_rect.group(1)) * int(taken_rect.group(2)) / BLOCK_PX ** 2
        if rect_blocks != taken_blocks:
            fail(f"the taken piece is drawn as {rect_blocks:g} blocks but the friend lost {taken_blocks:g}")
            all_ok = False
    if all_ok:
        ok(f"loop = {my_blocks:g} blocks = {sq_mi:.4f} square miles = {points} points")
        ok(f"friend lost {taken_blocks:g} blocks = {taken_sq_mi:.4f} square miles, and the drawn piece matches")

# ------------------------------------------------------------------ the numbers that come from the real app
print("\nFacts that must match the app")
social = open(os.path.join(ROOT, "Firebase", "functions", "social.js")).read()
rate = re.search(r"POINTS_PER_SQ_MILE = (\d+)", social)
if rate and "1,000 points" in home and int(rate.group(1)) == 1000:
    ok("1,000 points per square mile matches the server")
else:
    fail("the page's points rate does not match social.js")
index_js = open(os.path.join(ROOT, "Firebase", "functions", "index.js")).read()
min_area = re.search(r"MIN_NEW_SQ_MILES = ([\d.]+)", index_js)
if min_area and "0.02 square miles" in home and float(min_area.group(1)) == 0.02 and round(0.02 * 1000) == 20:
    ok("0.02 square miles (20 points) matches the server")
else:
    fail("the page's minimum loop size does not match index.js")

print()
if fails:
    print(f"{len(fails)} problem(s).")
    sys.exit(1)
print("Site checks passed.")
