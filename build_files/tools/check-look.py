#!/usr/bin/env python3
"""Static checks of the Pixel Guild look (docs/specs/0001-pixel-guild-look.md, "Acceptance"), driven by check-look.sh.

Nothing here renders anything: the checks read the files. Each subcommand prints what it checked and exits 1 with the
reasons on failure.

  check-look.py --root DIR colours            no colour literal in eww.scss / eww.yuck, no radius, no gap/clip-path/...
  check-look.py --root DIR tokens             _tokens.scss holds exactly the spec's table
  check-look.py --root DIR yuck --base REF    eww.yuck: balanced, widgets defined and used, windows kept, icons resolved
  check-look.py --root DIR svg                every icon on its grid, whole coordinates, token colours only
  check-look.py --root DIR sway --base REF    bindings identical to REF, no blur, square corners, no layer effects
  check-look.py --root DIR palette            no old palette value left under etc/skel/.config
  check-look.py png-size FILE W H             the PNG's size
"""
import argparse
import ast
import os
import re
import struct
import subprocess
import sys
import xml.etree.ElementTree as ET

SKEL = "build_files/system_files/etc/skel/.config"
EWW = SKEL + "/eww"
SWAY = SKEL + "/sway/config"

# the spec's table, dark theme of the pixel register (inkunome-design tokens.json at 7fe3a1f, plus the spec's extras)
TOKENS = {
    "bg": "#150F28",
    "surface": "#20173A",
    "sunken": "#0C0818",
    "fg": "#F3ECFF",
    "muted": "#A99BC9",
    "line": "#4A3B7A",
    "accent": "#FF7AA8",
    "on-accent": "#150F28",
    "accent-tint": "#3A1630",
    "px-body": "#7B66C8",
    "px-highlight": "#B8A9F0",
    "gold": "#F2B84B",
    "warn": "#F2B84B",
    "warn-tint": "#33270C",
    "bad": "#FF8A80",
    "ok": "#6FD6A0",
    "info": "#A9B8FF",
}

OLD_PALETTE = ["1c1424", "2a1d36", "5b4570", "f6eaf4", "b9a3c4", "c8a2f0", "ff9ccf", "ff8fc4", "e0566f", "ffd1e6",
               "f0d4ff", "ffc8e2"]

CSS_COLOUR_NAMES = set("""
aliceblue antiquewhite aqua aquamarine azure beige bisque black blanchedalmond blue blueviolet brown burlywood cadetblue
chartreuse chocolate coral cornflowerblue cornsilk crimson cyan darkblue darkcyan darkgoldenrod darkgray darkgreen darkgrey
darkkhaki darkmagenta darkolivegreen darkorange darkorchid darkred darksalmon darkseagreen darkslateblue darkslategray
darkslategrey darkturquoise darkviolet deeppink deepskyblue dimgray dimgrey dodgerblue firebrick floralwhite forestgreen
fuchsia gainsboro ghostwhite gold goldenrod gray green greenyellow grey honeydew hotpink indianred indigo ivory khaki
lavender lavenderblush lawngreen lemonchiffon lightblue lightcoral lightcyan lightgoldenrodyellow lightgray lightgreen
lightgrey lightpink lightsalmon lightseagreen lightskyblue lightslategray lightslategrey lightsteelblue lightyellow lime
limegreen linen magenta maroon mediumaquamarine mediumblue mediumorchid mediumpurple mediumseagreen mediumslateblue
mediumspringgreen mediumturquoise mediumvioletred midnightblue mintcream mistyrose moccasin navajowhite navy oldlace olive
olivedrab orange orangered orchid palegoldenrod palegreen paleturquoise palevioletred papayawhip peachpuff peru pink plum
powderblue purple rebeccapurple red rosybrown royalblue saddlebrown salmon sandybrown seagreen seashell sienna silver
skyblue slateblue slategray slategrey snow springgreen steelblue tan teal thistle tomato turquoise violet wheat white
whitesmoke yellow yellowgreen transparent currentcolor
""".split())

# eww 0.6 built-in widgets, and the forms that are not widgets
BUILTINS = {
    "box", "centerbox", "label", "button", "eventbox", "image", "scale", "progress", "calendar", "scroll", "input",
    "systray", "circular-progress", "for", "revealer", "overlay", "stack", "transform", "graph", "checkbox",
    "combo-box-text", "expander", "color-button", "color-chooser", "literal", "tooltip", "geometry",
}
TOP_FORMS = {"defwidget", "defwindow", "defvar", "defpoll", "deflisten", "include"}

# where the data-driven icon names of eww.yuck come from (expression -> source); anything else must be a literal
ICON_DATA = {"bat.icon": "battery", "d.icon": "battery"}

GRIDS = {"inkwell": (11, 8), "vine-bottom": (48, 12)}
ROOT_ATTRS = {"width", "height", "viewBox", "shape-rendering"}
NS = "{http://www.w3.org/2000/svg}"

errors = []


def err(msg):
    errors.append(msg)


def finish(what):
    if errors:
        for e in errors:
            print(f"  - {e}", file=sys.stderr)
        sys.exit(1)
    print(f"  ok: {what}")


def read(root, rel):
    with open(os.path.join(root, rel), encoding="utf-8") as f:
        return f.read()


def git_show(root, ref, rel):
    try:
        return subprocess.run(["git", "-C", root, "show", f"{ref}:{rel}"], capture_output=True, text=True,
                              check=True).stdout
    except subprocess.CalledProcessError as e:
        print(f"  cannot read {rel} at {ref}: {e.stderr.strip()} (set BASE_REF)", file=sys.stderr)
        sys.exit(1)


def line_of(text, pos):
    return text.count("\n", 0, pos) + 1


# ── 2. colours ──
def strip_css_comments(text):
    text = re.sub(r"/\*.*?\*/", " ", text, flags=re.S)
    return re.sub(r"//[^\n]*", " ", text)


def declarations(css):
    for m in re.finditer(r"([A-Za-z-]+)\s*:\s*([^;{}]+);", css):
        yield m.group(1).lower(), m.group(2)


def colour_names_in(value):
    # quoted strings (font names) and Sass variables ($gold is a token, not the CSS colour name) are not colours
    value = re.sub(r"\"[^\"]*\"|'[^']*'|\$[A-Za-z0-9_-]+", " ", value)
    return [w for w in re.findall(r"[A-Za-z]+", value) if w.lower() in CSS_COLOUR_NAMES]


def literal_scan(text, where):
    for m in re.finditer(r"#[0-9A-Fa-f]{3,8}\b", text):
        err(f"{where}:{line_of(text, m.start())}: colour literal {m.group(0)}")
    for m in re.finditer(r"\b(rgba?|hsla?)\(", text, flags=re.I):
        err(f"{where}:{line_of(text, m.start())}: colour function {m.group(0)}")


def cmd_colours(root):
    scss = read(root, EWW + "/eww.scss")
    literal_scan(scss, "eww.scss")
    css = strip_css_comments(scss)
    for prop, value in declarations(css):
        for name in colour_names_in(value):
            err(f"eww.scss: colour name '{name}' in '{prop}: {value.strip()}'")
        if prop == "border-radius" and value.strip() not in ("0", "0px"):
            err(f"eww.scss: border-radius {value.strip()}")
        if prop in ("gap", "display", "clip-path"):
            err(f"eww.scss: '{prop}' is not GTK 3 CSS")
    if re.search(r"\bvar\(", css):
        err("eww.scss: var( is not GTK 3 CSS")
    if re.search(r"clip-path", css):
        err("eww.scss: clip-path is not GTK 3 CSS")
    yuck = read(root, EWW + "/eww.yuck")
    literal_scan(yuck, "eww.yuck")
    for m in re.finditer(r':style\s+"([^"]*)"', yuck):
        for prop, value in declarations(m.group(1) if m.group(1).rstrip().endswith(";") else m.group(1) + ";"):
            for name in colour_names_in(value):
                err(f"eww.yuck:{line_of(yuck, m.start())}: colour name '{name}' in :style")
    finish("no colour literal or name in eww.scss and eww.yuck; no radius, gap, clip-path, display or var()")


# ── 3. tokens ──
def cmd_tokens(root):
    text = read(root, EWW + "/_tokens.scss")
    found = {}
    for n, line in enumerate(text.splitlines(), 1):
        s = line.strip()
        if not s or s.startswith("//"):
            continue
        m = re.fullmatch(r"\$([a-z-]+):\s*(#[0-9A-Fa-f]{6});", s)
        if not m:
            err(f"_tokens.scss:{n}: not a token line: {s}")
            continue
        if m.group(1) in found:
            err(f"_tokens.scss:{n}: {m.group(1)} defined twice")
        found[m.group(1)] = m.group(2)
    for k, v in TOKENS.items():
        if found.get(k) != v:
            err(f"_tokens.scss: ${k} is {found.get(k)}, the spec says {v}")
    for k in found.keys() - TOKENS.keys():
        err(f"_tokens.scss: ${k} is not in the spec's table")
    finish(f"_tokens.scss holds exactly the {len(TOKENS)} values of the table")


# ── 4. yuck ──
class YuckError(Exception):
    pass


def scan_quoted(src, i):
    """src[i] is a quote; return the index of the closing quote. `${...}` inside is skipped as an expression."""
    q = src[i]
    j = i + 1
    while j < len(src):
        c = src[j]
        if c == "\\":
            j += 2
            continue
        if c == q:
            return j
        if src.startswith("${", j):
            j = scan_expr(src, j + 1) + 1
            continue
        if c == "\n" and q == "'":
            raise YuckError(f"line {line_of(src, i)}: unterminated ' string")
        j += 1
    raise YuckError(f"line {line_of(src, i)}: unterminated string")


def scan_expr(src, i):
    """src[i] is '{'; return the index of the matching '}'."""
    depth = 0
    j = i
    while j < len(src):
        c = src[j]
        if c in "\"'":
            j = scan_quoted(src, j) + 1
            continue
        if c == "{":
            depth += 1
        elif c == "}":
            depth -= 1
            if depth == 0:
                return j
        j += 1
    raise YuckError(f"line {line_of(src, i)}: unterminated {{ expression")


def tokenize(src):
    toks = []
    i = 0
    while i < len(src):
        c = src[i]
        if c == ";":
            i = src.find("\n", i)
            i = len(src) if i < 0 else i
        elif c in "()[]":
            toks.append((c, c, i))
            i += 1
        elif c == '"':
            j = scan_quoted(src, i)
            toks.append(("str", src[i + 1:j], i))
            i = j + 1
        elif c == "{":
            j = scan_expr(src, i)
            toks.append(("expr", src[i + 1:j], i))
            i = j + 1
        elif c == "}":
            raise YuckError(f"line {line_of(src, i)}: '}}' without '{{'")
        elif c.isspace():
            i += 1
        else:
            m = re.match(r"[^\s()\[\]\"{};]+", src[i:])
            toks.append(("sym", m.group(0), i))
            i += len(m.group(0))
    return toks


def parse(src):
    """A list of top-level forms; a form is ('list'|'vec', [items], pos), an item is a form or a token."""
    stack = [("top", [], 0)]
    closers = {")": "(", "]": "["}
    for kind, text, pos in tokenize(src):
        if kind in ("(", "["):
            stack.append(("list" if kind == "(" else "vec", [], pos))
        elif kind in (")", "]"):
            if len(stack) == 1:
                raise YuckError(f"line {line_of(src, pos)}: '{kind}' without an opening")
            form = stack.pop()
            if (form[0] == "list") != (closers[kind] == "("):
                raise YuckError(f"line {line_of(src, pos)}: '{kind}' closes a '{'(' if form[0] == 'list' else '['}'")
            stack[-1][1].append(form)
        else:
            stack[-1][1].append((kind, text, pos))
    if len(stack) != 1:
        raise YuckError(f"line {line_of(src, stack[-1][2])}: '(' never closed")
    return stack[0][1]


def is_form(x):
    return x[0] in ("list", "vec")


def head(form):
    items = form[1]
    if form[0] == "list" and items and not is_form(items[0]) and items[0][0] == "sym":
        return items[0][1]
    return None


def walk(form):
    yield form
    for x in form[1]:
        if is_form(x):
            yield from walk(x)


def kwargs(form):
    """The :key value pairs of a call (items after the head)."""
    out = {}
    items = form[1][1:]
    i = 0
    while i < len(items):
        x = items[i]
        if not is_form(x) and x[0] == "sym" and x[1].startswith(":"):
            out[x[1][1:]] = items[i + 1] if i + 1 < len(items) else None
            i += 2
        else:
            i += 1
    return out


def defs(forms, kind):
    """name -> (params, form) for defwidget / defwindow."""
    out = {}
    for f in forms:
        if is_form(f) and head(f) == kind:
            name = f[1][1][1]
            params = []
            if len(f[1]) > 2 and is_form(f[1][2]) and f[1][2][0] == "vec":
                params = [t[1] for t in f[1][2][1]]
            out[name] = (params, f)
    return out


def battery_icons(root):
    src = read(root, EWW + "/scripts/battery")
    tree = ast.parse(src)
    fn = [n for n in tree.body if isinstance(n, ast.FunctionDef) and n.name == "icon"]
    if not fn:
        err("scripts/battery: no icon() function to read the icon names from")
        return set()
    ns = {}
    exec(compile(ast.Module(body=fn, type_ignores=[]), "battery", "exec"), ns)
    names = {ns["icon"](p, s) for p in range(0, 101)
             for s in ("charging", "pending-charge", "discharging", "fully-charged", "pending-discharge", "unknown")}
    in_fstring = {id(v) for n in ast.walk(tree) if isinstance(n, ast.JoinedStr) for v in n.values}
    for n in ast.walk(tree):
        if isinstance(n, ast.Constant) and isinstance(n.value, str) and id(n) not in in_fstring \
                and re.fullmatch(r"battery-[a-z0-9-]+", n.value):
            names.add(n.value)
    return names


def builtin_dock_ids(root):
    src = read(root, EWW + "/scripts/apps")
    m = re.search(r"^BUILTIN\s*=\s*(\{.*?\})", src, flags=re.M)
    if not m:
        err("scripts/apps: no BUILTIN table to read the built-in dock ids from")
        return set()
    return set(ast.literal_eval(m.group(1)))


def cmd_yuck(root, base):
    src = read(root, EWW + "/eww.yuck")
    try:
        forms = parse(src)
    except YuckError as e:
        err(f"eww.yuck: {e}")
        finish("")
    widgets = defs(forms, "defwidget")
    windows = defs(forms, "defwindow")
    used = set()
    calls = {}
    for top in forms:
        if not is_form(top):
            err(f"eww.yuck:{line_of(src, top[2])}: stray token at top level: {top[1]}")
            continue
        h = head(top)
        if h not in TOP_FORMS:
            err(f"eww.yuck:{line_of(src, top[2])}: unknown top-level form {h}")
            continue
        if h not in ("defwidget", "defwindow"):
            continue
        body = top[1][3:] if h == "defwidget" else top[1][2:]
        for x in body:
            if not is_form(x):
                continue
            for f in walk(x):
                w = head(f)
                if f[0] != "list":
                    continue
                if w is None:
                    err(f"eww.yuck:{line_of(src, f[2])}: a list without a widget name")
                elif w in widgets:
                    used.add(w)
                    calls.setdefault(w, []).append(f)
                elif w not in BUILTINS:
                    err(f"eww.yuck:{line_of(src, f[2])}: widget '{w}' is not defined")
    for w, (params, f) in widgets.items():
        if w not in used:
            err(f"eww.yuck:{line_of(src, f[2])}: widget '{w}' is defined and never used")
        required = {p for p in params if not p.startswith("?")}
        known = {p.lstrip("?") for p in params}
        for c in calls.get(w, []):
            given = set(kwargs(c))
            if required - given:
                err(f"eww.yuck:{line_of(src, c[2])}: ({w}) misses {sorted(required - given)}")
            if given - known:
                err(f"eww.yuck:{line_of(src, c[2])}: ({w}) has unknown {sorted(given - known)}")

    # the windows the scripts open by name: same names and arguments as on the base branch
    try:
        old_windows = {n: p for n, (p, _) in defs(parse(git_show(root, base, EWW + "/eww.yuck")), "defwindow").items()}
    except YuckError as e:
        err(f"eww.yuck at {base}: {e}")
        old_windows = {}
    new_windows = {n: p for n, (p, _) in windows.items()}
    if old_windows != new_windows:
        err(f"eww.yuck: windows changed: {base} has {sorted(old_windows.items())}, now {sorted(new_windows.items())}")

    # icons the file can produce
    sources = {"battery": battery_icons(root)}
    referenced = set()

    def resolve(expr, widget):
        """The values an expression can take: a param of `widget` (its call sites) or a known data source."""
        expr = expr.strip()
        if widget and expr in widgets[widget][0]:
            vals = set()
            for c in calls.get(widget, []):
                arg = kwargs(c).get(expr)
                if arg is None or is_form(arg):
                    err(f"eww.yuck:{line_of(src, c[2])}: ({widget}) :{expr} cannot be resolved to icon names")
                elif arg[0] in ("str", "sym"):
                    vals.add(arg[1])
                else:
                    vals |= resolve(arg[1], None)
            return vals
        if expr in ICON_DATA:
            return sources[ICON_DATA[expr]]
        err(f"eww.yuck: icon name from '{expr}' has no known source (add it to ICON_DATA in check-look.py)")
        return set()

    for top in forms:
        if head(top) != "defwidget" and head(top) != "defwindow":
            continue
        widget = top[1][1][1] if head(top) == "defwidget" else None
        for f in walk(top):
            for tok in f[1]:
                if is_form(tok) or tok[0] not in ("str", "expr") or "/icons/" not in tok[1]:
                    continue
                text = tok[1]
                if tok[0] == "expr" and re.search(r'/icons/"\s*\+', text):
                    strings = re.findall(r'"((?:[^"\\]|\\.)*)"', text)
                    names = {s for s in strings if re.fullmatch(r"[a-z0-9-]+", s)}
                    if not names:
                        err(f"eww.yuck:{line_of(src, tok[2])}: cannot read the icon names of {text}")
                    referenced |= names
                    continue
                for m in re.finditer(r"/icons/([a-z0-9-]*)(?:\$\{([^}]*)\})?([a-z0-9-]*)\.svg", text):
                    pre, var, post = m.groups()
                    if var is None:
                        referenced.add(pre)
                    else:
                        referenced |= {pre + v + post for v in resolve(var, widget)}
                if not re.search(r"/icons/[^\"']*\.svg", text):
                    err(f"eww.yuck:{line_of(src, tok[2])}: an icon path without a .svg name: {text}")
    referenced |= builtin_dock_ids(root)

    files = {f[:-4] for f in os.listdir(os.path.join(root, EWW, "icons")) if f.endswith(".svg")}
    for n in sorted(referenced - files):
        err(f"icon '{n}.svg' can be asked for by eww.yuck and does not exist")
    for n in sorted(files - referenced):
        err(f"icon '{n}.svg' exists and nothing references it")
    finish(f"eww.yuck parses ({len(widgets)} widgets, {len(windows)} windows, the windows of {base} kept); "
           f"{len(referenced)} icon names resolved, all present, all {len(files)} files referenced")


# ── 5. svg ──
def path_points(d, where):
    tokens = re.findall(r"[MmHhVvZz]|-?\d+(?:\.\d+)?|\S", d)
    pts = []
    x = y = sx = sy = 0
    i = 0

    def num():
        nonlocal i
        if i >= len(tokens) or not re.fullmatch(r"-?\d+(?:\.\d+)?", tokens[i]):
            raise ValueError(f"{where}: number expected in path at token {i}")
        t = tokens[i]
        i += 1
        if not re.fullmatch(r"-?\d+", t):
            raise ValueError(f"{where}: {t} is not a whole coordinate")
        return int(t)

    while i < len(tokens):
        c = tokens[i]
        i += 1
        if c == "M":
            x, y = num(), num()
            sx, sy = x, y
        elif c == "m":
            x, y = x + num(), y + num()
            sx, sy = x, y
        elif c == "H":
            x = num()
        elif c == "h":
            x += num()
        elif c == "V":
            y = num()
        elif c == "v":
            y += num()
        elif c in "Zz":
            x, y = sx, sy
        else:
            raise ValueError(f"{where}: '{c}' is not an axis-aligned path command")
        pts.append((x, y))
    return pts


def cmd_svg(root):
    colours = {v.upper() for v in TOKENS.values()}
    folder = os.path.join(root, EWW, "icons")
    names = sorted(f for f in os.listdir(folder) if f.endswith(".svg"))
    for name in names:
        where = f"icons/{name}"
        try:
            svg = ET.parse(os.path.join(folder, name)).getroot()
        except ET.ParseError as e:
            err(f"{where}: not well-formed: {e}")
            continue
        if svg.tag != NS + "svg":
            err(f"{where}: the root is {svg.tag}, not svg")
            continue
        w, h = GRIDS.get(name[:-4], (12, 12))
        if svg.get("viewBox") != f"0 0 {w} {h}":
            err(f"{where}: viewBox {svg.get('viewBox')}, expected 0 0 {w} {h}")
        if svg.get("width") != str(w) or svg.get("height") != str(h):
            err(f"{where}: width/height {svg.get('width')}x{svg.get('height')}, expected {w}x{h}")
        if svg.get("shape-rendering") != "crispEdges":
            err(f"{where}: shape-rendering is not crispEdges")
        for a in set(svg.attrib) - ROOT_ATTRS:
            err(f"{where}: attribute {a} on svg")
        children = list(svg)
        if not children:
            err(f"{where}: empty")
        for el in children:
            if el.tag != NS + "path":
                err(f"{where}: element {el.tag.replace(NS, '')} (only path)")
                continue
            if list(el):
                err(f"{where}: a path with children")
            for a in set(el.attrib) - {"fill", "d", "fill-rule"}:
                err(f"{where}: attribute {a} on path")
            if (el.get("fill") or "").upper() not in colours:
                err(f"{where}: fill {el.get('fill')} is not a token colour")
            if el.get("fill-rule", "nonzero") not in ("nonzero", "evenodd"):
                err(f"{where}: fill-rule {el.get('fill-rule')}")
            try:
                for px, py in path_points(el.get("d") or "", where):
                    if not (0 <= px <= w and 0 <= py <= h):
                        err(f"{where}: point {px},{py} is off the {w}x{h} grid")
            except ValueError as e:
                err(str(e))
    finish(f"{len(names)} icons well-formed, on their grid, whole coordinates, token colours only")


# ── 6. sway ──
def binding_lines(text):
    return [l for l in text.splitlines() if re.match(r"\s*(bindsym|bindcode|mode)\b", l)]


def cmd_sway(root, base):
    cur = read(root, SWAY)
    old = git_show(root, base, SWAY)
    a, b = binding_lines(old), binding_lines(cur)
    if a != b:
        for l in sorted(set(a) - set(b)):
            err(f"sway: binding gone or changed: {l.strip()}")
        for l in sorted(set(b) - set(a)):
            err(f"sway: binding added or changed: {l.strip()}")
        if set(a) == set(b):
            err("sway: the binding lines are the same but in another order")
    if "layer_effects" in cur:
        err("sway: layer_effects is still there")
    blur_disable = False
    for n, line in enumerate(cur.splitlines(), 1):
        s = line.split("#", 1)[0].strip() if not line.lstrip().startswith("bind") else line.strip()
        if not s:
            continue
        if re.match(r"blur\b", s):
            if s == "blur disable":
                blur_disable = True
            else:
                err(f"sway:{n}: {s} (only 'blur disable')")
        if re.search(r"\bblur\s+(enable|on|true|yes)\b", s) or re.search(r"\bblur_(?!disable)[a-z]+\b", s):
            err(f"sway:{n}: blur setting: {s}")
        for m in re.finditer(r"\bcorner_radius\s+([^\s;]+)", s):
            if m.group(1) != "0":
                err(f"sway:{n}: corner_radius {m.group(1)}")
    if not blur_disable:
        err("sway: no 'blur disable'")
    finish(f"sway: {len(b)} bindsym/bindcode/mode lines identical to {base}; blur disabled, corners square, "
           "no layer effects")


# ── 7. palette ──
def cmd_palette(root):
    base = os.path.join(root, SKEL)
    count = 0
    for d, _, files in os.walk(base):
        for f in files:
            p = os.path.join(d, f)
            count += 1
            with open(p, "rb") as fh:
                text = fh.read().decode("utf-8", "replace").lower()
            for v in OLD_PALETTE:
                if v in text:
                    err(f"{os.path.relpath(p, root)}: old palette value {v}")
    finish(f"no old palette value in the {count} files under etc/skel/.config")


def cmd_png_size(path, w, h):
    with open(path, "rb") as f:
        data = f.read(33)
    if data[:8] != b"\x89PNG\r\n\x1a\n" or data[12:16] != b"IHDR":
        err(f"{path}: not a PNG")
    else:
        pw, ph = struct.unpack(">II", data[16:24])
        if (pw, ph) != (w, h):
            err(f"{path}: {pw}x{ph}, expected {w}x{h}")
    finish(f"{os.path.basename(path)} is {w}x{h}")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--root", default=".")
    ap.add_argument("--base", default="main")
    ap.add_argument("check")
    ap.add_argument("args", nargs="*")
    a = ap.parse_args()
    root = os.path.abspath(a.root)
    if a.check == "colours":
        cmd_colours(root)
    elif a.check == "tokens":
        cmd_tokens(root)
    elif a.check == "yuck":
        cmd_yuck(root, a.base)
    elif a.check == "svg":
        cmd_svg(root)
    elif a.check == "sway":
        cmd_sway(root, a.base)
    elif a.check == "palette":
        cmd_palette(root)
    elif a.check == "png-size":
        cmd_png_size(a.args[0], int(a.args[1]), int(a.args[2]))
    else:
        ap.error(f"unknown check {a.check}")


if __name__ == "__main__":
    main()
