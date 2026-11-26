#!/usr/bin/env python3
"""Cada ninja montado na própria criatura, visto de costas: virando à esquerda, reto e à direita,
cada um com dois quadros de galope. Uso: python3 tools/make_riders.py
"""
from PIL import Image
from make_sprites import OUT, W, H, CHARACTERS, SKIN, capsule, layer, shade

def c(r, g, b):
    return (r, g, b, 255)

# corpo, escuro, detalhe, cauda, costas, cabeça
MOUNTS = {
    "fire":     (c(214, 58, 30), c(130, 28, 24), c(255, 228, 90), "spike", "wings", "horns"),
    "water":    (c(40, 136, 226), c(22, 70, 150), c(235, 252, 255), "fin", "fins", "crest"),
    "plant":    (c(122, 86, 48), c(78, 54, 34), c(76, 170, 62), "leaf", "bush", "antlers"),
    "electric": (c(246, 208, 36), c(180, 126, 16), c(255, 252, 200), "feathers", "wings", "crest"),
    "earth":    (c(150, 132, 78), c(84, 54, 34), c(196, 170, 128), "stub", "shell", "plain"),
    "air":      (c(130, 222, 204), c(46, 128, 134), c(236, 255, 250), "whip", "wide", "antennae"),
    "ash":      (c(112, 100, 112), c(58, 48, 62), c(255, 108, 60), "three", "none", "ears"),
    "frost":    (c(220, 238, 250), c(70, 108, 160), c(130, 200, 236), "brush", "spikes", "ears"),
    "thorn":    (c(86, 128, 48), c(60, 100, 40), c(196, 36, 78), "leaf", "leaves", "flower"),
    "thunder":  (c(116, 88, 196), c(64, 46, 124), c(255, 232, 60), "stub", "mane", "crown"),
    "sand":     (c(214, 168, 90), c(138, 96, 48), c(80, 220, 190), "sting", "plates", "claws"),
    "gale":     (c(190, 168, 84), c(112, 80, 40), c(246, 240, 212), "tuft", "wings", "ears"),
}

def mount(key, look, lean, step):
    body, dark, trim, tail, back, head = MOUNTS[key]
    img = Image.new("RGBA", (W, H))
    cx = 48 + lean          # tronco acompanha a curva
    hx = 48 + lean * 3      # a cabeça aponta para onde vira
    bob = step

    # cabeça, lá na frente (atrás de tudo)
    hy = 24 + bob
    layer(img, lambda d: d.ellipse((hx - 11, hy - 9, hx + 11, hy + 11), fill=dark))
    if head == "horns":
        layer(img, lambda d: [d.polygon([(hx + s * 4, hy - 6), (hx + s * 17, hy - 20), (hx + s * 11, hy - 2)], fill=trim) for s in (-1, 1)])
    elif head == "ears":
        layer(img, lambda d: [d.polygon([(hx + s * 3, hy - 6), (hx + s * 12, hy - 19), (hx + s * 12, hy - 2)], fill=body) for s in (-1, 1)])
    elif head == "antlers":
        layer(img, lambda d: [(capsule(d, (hx + s * 6, hy - 6), (hx + s * 18, hy - 19), 1.6, 1, dark), d.ellipse((hx + s * 18 - 4, hy - 23, hx + s * 18 + 4, hy - 15), fill=trim)) for s in (-1, 1)])
    elif head == "crest":
        layer(img, lambda d: d.polygon([(hx - 5, hy - 6), (hx, hy - 21), (hx + 5, hy - 6)], fill=trim))
    elif head == "antennae":
        layer(img, lambda d: [capsule(d, (hx + s * 5, hy - 6), (hx + s * 16, hy - 18), 1.8, 0.8, trim) for s in (-1, 1)])
    elif head == "flower":
        layer(img, lambda d: [d.ellipse((hx + dx - 8, hy + dy - 8, hx + dx + 8, hy + dy + 8), fill=trim) for dx, dy in ((-11, -4), (0, -12), (11, -4))])
    elif head == "crown":
        layer(img, lambda d: d.polygon([(hx - 9, hy - 5), (hx - 11, hy - 18), (hx - 3, hy - 10), (hx, hy - 21), (hx + 3, hy - 10), (hx + 11, hy - 18), (hx + 9, hy - 5)], fill=trim))
    elif head == "claws":
        layer(img, lambda d: [(capsule(d, (cx + s * 18, 42), (cx + s * 36, 30 + bob), 4, 4, body),
                               d.polygon([(cx + s * 32, 32 + bob), (cx + s * 34, 18 + bob), (cx + s * 39, 28 + bob), (cx + s * 45, 20 + bob), (cx + s * 41, 34 + bob)], fill=dark)) for s in (-1, 1)])

    # asas e costas largas, por trás do tronco
    flap = 6 if step else 0
    if back == "wings":
        layer(img, lambda d: [d.polygon([(cx + s * 12, 40), (cx + s * 44, 14 + flap), (cx + s * 38, 28 + flap), (cx + s * 46, 34 + flap), (cx + s * 34, 38), (cx + s * 40, 48), (cx + s * 16, 50)], fill=dark) for s in (-1, 1)])
        layer(img, lambda d: [d.polygon([(cx + s * 14, 41), (cx + s * 36, 24 + flap), (cx + s * 31, 36 + flap), (cx + s * 36, 42), (cx + s * 18, 48)], fill=body) for s in (-1, 1)])
    elif back == "wide":
        layer(img, lambda d: [d.polygon([(cx + s * 8, 36), (cx + s * 47, 36 + flap * 2), (cx + s * 28, 46 + flap), (cx + s * 32, 58), (cx + s * 8, 52)], fill=body) for s in (-1, 1)])
        layer(img, lambda d: [d.line((cx + s * 12, 42, cx + s * 40, 38 + flap * 2), fill=trim, width=2) for s in (-1, 1)])
    elif back == "fins":
        layer(img, lambda d: [d.polygon([(cx + s * 14, 42), (cx + s * 32, 34 + flap), (cx + s * 27, 44), (cx + s * 34, 52 + flap), (cx + s * 14, 54)], fill=trim) for s in (-1, 1)])

    # patas
    for s, up in ((-1, step), (1, 1 - step)):
        if back != "wide":
            layer(img, lambda d: capsule(d, (cx + s * 15, 52), (cx + s * 19, 66 - up * 5), 6.5, 4.5, dark))

    # tronco / ancas
    layer(img, lambda d: d.ellipse((cx - 22, 36 + bob, cx + 22, 63 + bob), fill=body))
    if back == "shell":
        layer(img, lambda d: d.ellipse((cx - 27, 32 + bob, cx + 27, 62 + bob), fill=dark))
        layer(img, lambda d: [d.polygon([(cx + x - 7, y + 9 + bob), (cx + x, y - 5 + bob), (cx + x + 7, y + 9 + bob)], fill=trim) for x, y in ((-17, 42), (17, 42), (-8, 52), (8, 52))])
    elif back == "bush":
        layer(img, lambda d: [d.ellipse((cx + x - 9, y + bob - 6, cx + x + 9, y + bob + 6), fill=trim) for x, y in ((-14, 41), (14, 41), (0, 52))])
    elif back == "leaves":
        layer(img, lambda d: [d.polygon([(cx, 52), (cx + s * 36, 40 + flap), (cx + s * 24, 58)], fill=body) for s in (-1, 1)])
    elif back == "spikes":
        layer(img, lambda d: [d.polygon([(cx + x - 4, y + bob), (cx + x, y - 13 + bob), (cx + x + 4, y + bob)], fill=trim) for x, y in ((-17, 47), (17, 47), (-9, 57), (9, 57))])
    elif back == "mane":
        layer(img, lambda d: d.polygon([(cx - 20, 44), (cx - 24, 30 + bob), (cx - 11, 38), (cx, 28 + bob), (cx + 11, 38), (cx + 24, 30 + bob), (cx + 20, 44)], fill=dark))
    elif back == "plates":
        layer(img, lambda d: [d.arc((cx - 20, y, cx + 20, y + 14), 20, 160, fill=dark, width=2) for y in (38 + bob, 46 + bob)])

    # ninja montado, de costas
    main, suit, accent = (shade(look[k], 1.0) for k in ("main", "suit", "trim"))
    rx = 48 + lean * 2
    gear = look["gear"]
    layer(img, lambda d: [capsule(d, (cx + s * 6, 40), (cx + s * 16, 47), 3.4, 2.4, suit) for s in (-1, 1)])
    layer(img, lambda d: [capsule(d, (rx + s * 7, 24 + bob), (hx + s * 7, 33), 2.8, 2.0, main) for s in (-1, 1)])
    layer(img, lambda d: capsule(d, (rx, 24 + bob), (cx, 40 + bob), 8, 6, suit))
    layer(img, lambda d: (capsule(d, (rx, 25 + bob), (cx, 38 + bob), 3.6, 2.4, main), d.line((cx - 7, 40 + bob, cx + 7, 40 + bob), fill=accent, width=2)))
    layer(img, lambda d: d.ellipse((rx - 6, 10 + bob, rx + 6, 22 + bob), fill=main))
    layer(img, lambda d: d.line((rx - 6, 15 + bob, rx + 6, 15 + bob), fill=accent, width=2))
    if gear in ("scarf", "tail", "pony", "ribbons", "turban"):
        sway = -lean * 3 + (3 if step else -1)
        layer(img, lambda d: capsule(d, (rx, 20 + bob), (rx + sway, 34 + bob), 2.6, 0.8, accent if gear != "tail" else suit))
    if gear == "hat":
        layer(img, lambda d: d.polygon([(rx - 13, 15 + bob), (rx, 5 + bob), (rx + 13, 15 + bob)], fill=(196, 164, 90, 255)))
    if gear in ("spikes", "crown"):
        layer(img, lambda d: [d.polygon([(rx + o - 2, 12 + bob), (rx + o, 3 + bob), (rx + o + 2, 12 + bob)], fill=accent) for o in (-4, 0, 4)])
    if gear == "hood":
        layer(img, lambda d: d.ellipse((rx + 2, 8 + bob, rx + 8, 14 + bob), fill=(236, 66, 96, 255)))
    if gear == "armor":
        layer(img, lambda d: [d.ellipse((rx + s * 9 - 4, 21 + bob, rx + s * 9 + 4, 29 + bob), fill=accent) for s in (-1, 1)])
    if gear == "beak":
        layer(img, lambda d: capsule(d, (rx, 11 + bob), (rx - lean * 3, 3 + bob), 1.6, 0.6, accent))

    # cauda, na frente de tudo
    tx = cx - lean * 4
    if tail == "spike":
        layer(img, lambda d: capsule(d, (cx, 54), (tx, 68), 6, 2.5, body))
        layer(img, lambda d: d.polygon([(tx - 6, 66), (tx, 71), (tx + 6, 66), (tx, 59)], fill=trim))
    elif tail == "fin":
        layer(img, lambda d: (capsule(d, (cx, 54), (tx, 65), 6, 3, body), d.polygon([(tx, 62), (tx - 11, 71), (tx, 67), (tx + 11, 71)], fill=trim)))
    elif tail in ("leaf", "tuft", "brush"):
        layer(img, lambda d: (capsule(d, (cx, 53), (tx, 61), 3, 2, dark), d.ellipse((tx - 7, 56, tx + 7, 71), fill=trim)))
    elif tail == "feathers":
        layer(img, lambda d: [d.polygon([(cx, 52), (tx + o - 5, 71), (tx + o + 5, 69)], fill=trim if o == 0 else dark) for o in (-11, 11, 0)])
    elif tail == "three":
        for o in (-13, 13, 0):
            layer(img, lambda d: (capsule(d, (cx, 53), (tx + o, 62), 4, 3, dark), d.ellipse((tx + o - 5, 59, tx + o + 5, 70), fill=trim)))
    elif tail == "whip":
        layer(img, lambda d: capsule(d, (cx, 52), (tx, 71), 3.5, 0.8, dark))
    elif tail == "sting":
        layer(img, lambda d: (capsule(d, (cx, 56), (tx - 16, 50), 5, 4, body), capsule(d, (tx - 16, 50), (tx - 24, 28), 4, 3, dark),
                              d.polygon([(tx - 28, 30), (tx - 21, 16), (tx - 19, 31)], fill=trim)))
    else:
        layer(img, lambda d: d.ellipse((tx - 5, 56, tx + 5, 66), fill=dark))
    return img

def main():
    (OUT / "kart").mkdir(parents=True, exist_ok=True)
    for key, look in CHARACTERS.items():
        sheet = Image.new("RGBA", (W * 3, H * 2))
        for column, lean in enumerate((-3, 0, 3)):
            for step in (0, 1):
                sheet.paste(mount(key, look, lean, step), (W * column, H * step))
        sheet.save(OUT / "kart" / f"rider_{key}.png")

if __name__ == "__main__":
    main()
