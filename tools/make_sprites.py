#!/usr/bin/env python3
"""Gera a pixel art do jogo (original) em assets/. Uso: python3 tools/make_sprites.py

Cada lutador é um esqueleto de juntas; as poses valem para todos e o visual muda por personagem.
Escala no jogo: 3x. Coordenadas: x para a frente, y para cima, a partir dos pés.
"""
import random
from pathlib import Path
from PIL import Image, ImageDraw

OUT = Path(__file__).resolve().parent.parent / "assets"
W, H, AX, AY = 96, 72, 48, 68  # quadro e ponto dos pés
INK = (16, 12, 22, 255)
SKIN = (222, 168, 122, 255)

CHARACTERS = {
    #            tecido principal, tecido escuro (roupa), detalhe
    "fire":     {"main": (224, 70, 34),   "suit": (52, 30, 34), "trim": (255, 190, 50), "gear": "scarf",  "bulk": 0},
    "water":    {"main": (38, 122, 224),  "suit": (28, 32, 58), "trim": (150, 232, 255), "gear": "tail",  "bulk": 0},
    "plant":    {"main": (54, 150, 66),   "suit": (38, 50, 32), "trim": (190, 224, 92), "gear": "hat",    "bulk": 0},
    "electric": {"main": (238, 200, 30),  "suit": (40, 36, 54), "trim": (255, 250, 170), "gear": "spikes", "bulk": -1},
    "earth":    {"main": (156, 100, 56),  "suit": (60, 48, 42), "trim": (208, 176, 128), "gear": "armor", "bulk": 2},
    # Segundo ninja de cada clã
    "ash":      {"main": (118, 104, 116), "suit": (36, 26, 34), "trim": (255, 92, 60),   "gear": "pony",  "bulk": -1},
    "frost":    {"main": (190, 228, 248), "suit": (52, 74, 108), "trim": (120, 196, 240), "gear": "crown", "bulk": 1},
    "thorn":    {"main": (150, 36, 76),   "suit": (34, 54, 30), "trim": (170, 214, 70),  "gear": "hood",  "bulk": -1},
    "thunder":  {"main": (112, 84, 200),  "suit": (34, 30, 50), "trim": (255, 222, 60),  "gear": "gloves", "bulk": 1},
    "sand":     {"main": (224, 186, 118), "suit": (108, 78, 56), "trim": (60, 170, 166), "gear": "turban", "bulk": 0},
    # Clã do Vento
    "air":      {"main": (150, 232, 204), "suit": (42, 78, 84), "trim": (244, 255, 250), "gear": "ribbons", "bulk": -1},
    "gale":     {"main": (176, 190, 92),  "suit": (70, 52, 40), "trim": (240, 232, 196), "gear": "beak",   "bulk": 0},
}
# Formas transformadas: cores novas, cabelo e um adereço próprio de cada ninja.
FORMS = {
    #          tecido, roupa, detalhe, cabelo, penteado, extra
    "fire":     ((255, 130, 20), (120, 20, 10), (255, 240, 120), (255, 214, 50), "mane", "tails"),
    "water":    ((60, 200, 255), (10, 20, 100), (210, 255, 255), (80, 240, 255), "flow", "fins"),
    "plant":    ((120, 200, 60), (70, 46, 22), (255, 214, 120), (60, 160, 60), "mane", "antlers"),
    "electric": ((255, 244, 110), (60, 30, 130), (255, 255, 255), (255, 255, 170), "tall", "bolts"),
    "earth":    ((220, 170, 100), (90, 56, 32), (255, 196, 70), (120, 78, 46), "tall", "pauldrons"),
    "air":      ((220, 255, 240), (60, 140, 150), (255, 230, 140), (240, 255, 250), "flow", "halo"),
    "ash":      ((90, 70, 100), (18, 10, 24), (255, 70, 60), (232, 226, 236), "flow", "tails"),
    "frost":    ((226, 248, 255), (60, 110, 180), (120, 240, 255), (200, 244, 255), "tall", "crystals"),
    "thorn":    ((230, 40, 100), (30, 80, 40), (255, 180, 200), (200, 20, 60), "mane", "vines"),
    "thunder":  ((190, 140, 255), (36, 20, 76), (255, 232, 60), (255, 232, 60), "tall", "fists"),
    "sand":     ((255, 214, 90), (40, 90, 110), (60, 240, 220), (30, 50, 90), "nemes", "halo"),
    "gale":     ((240, 220, 110), (110, 60, 30), (255, 255, 240), (250, 244, 220), "mane", "wings"),
}
ALT = {  # segunda paleta, para quando os dois escolhem o mesmo lutador
    "fire": (150, 40, 90), "water": (40, 176, 170), "plant": (130, 140, 40),
    "electric": (232, 126, 30), "earth": (116, 108, 108),
    "ash": (80, 90, 130), "frost": (220, 190, 240), "thorn": (60, 90, 140),
    "thunder": (60, 150, 140), "sand": (200, 130, 110), "air": (200, 170, 240), "gale": (130, 150, 170),
}

def pose(**changes):
    base = dict(head=(1, 45), chest=(0, 37), hip=(-1, 26),
                fe=(8, 33), fh=(11, 40), be=(-5, 31), bh=(4, 36),
                fk=(7, 14), ff=(10, 2), bk=(-7, 13), bf=(-10, 2))
    base.update(changes)
    return base

def bob(p, dy):
    return {k: (x, y if k in ("ff", "bf") else y + dy) for k, (x, y) in p.items()}

STAND = pose()
CROUCH = pose(head=(3, 28), chest=(1, 20), hip=(-3, 11), fe=(9, 17), fh=(12, 24), be=(-4, 15), bh=(5, 20),
              fk=(9, 11), ff=(11, 2), bk=(-11, 7), bf=(-8, 2))
AIR = pose(head=(2, 45), chest=(1, 37), hip=(-1, 27), fk=(8, 23), ff=(5, 13), bk=(-6, 19), bf=(-11, 12))

def merge(base, **changes):
    p = dict(base)
    p.update(changes)
    return p

POSES = {
    "idle_0": STAND, "idle_1": bob(STAND, -1), "idle_2": bob(STAND, -2), "idle_3": bob(STAND, -1),
    "walk_0": pose(fk=(8, 15), ff=(14, 2), bk=(-7, 14), bf=(-13, 2)),
    "walk_1": pose(head=(1, 46), chest=(0, 38), hip=(-1, 27), fk=(3, 15), ff=(3, 2), bk=(4, 17), bf=(-2, 8)),
    "walk_2": pose(fk=(-1, 13), ff=(-8, 2), bk=(6, 15), bf=(11, 2)),
    "walk_3": pose(head=(1, 46), chest=(0, 38), hip=(-1, 27), fk=(7, 18), ff=(4, 9), bk=(-2, 14), bf=(-2, 2)),
    "crouch": CROUCH,
    "jump": AIR,
    "stand_punch_0": merge(STAND, fe=(0, 36), fh=(6, 39), be=(5, 37), bh=(11, 41)),
    "stand_punch_1": merge(STAND, head=(4, 45), chest=(4, 37), fe=(16, 40), fh=(28, 41), be=(-5, 34), bh=(1, 36)),
    "crouch_punch_0": merge(CROUCH, fe=(-2, 15), fh=(7, 14)),
    "crouch_punch_1": merge(CROUCH, fe=(15, 14), fh=(28, 11)),
    "air_punch_0": merge(AIR, fe=(0, 36), fh=(7, 35)),
    "air_punch_1": merge(AIR, fe=(14, 30), fh=(27, 22)),
    "stand_kick_0": pose(head=(-2, 45), chest=(-2, 37), hip=(0, 27), fk=(11, 27), ff=(9, 15), bk=(-2, 14), bf=(-3, 2)),
    "stand_kick_1": pose(head=(-9, 42), chest=(-6, 35), hip=(2, 26), fe=(-1, 31), fh=(5, 35), be=(-13, 30), bh=(-9, 36),
                         fk=(18, 26), ff=(35, 25), bk=(-1, 13), bf=(-3, 2)),
    "crouch_kick_0": merge(CROUCH, fk=(10, 10), ff=(10, 4)),
    "crouch_kick_1": merge(CROUCH, head=(-5, 27), chest=(-5, 19), hip=(-3, 9), fe=(2, 15), fh=(5, 21),
                           be=(-12, 11), bh=(-12, 3), fk=(16, 6), ff=(35, 4)),
    "air_kick_0": merge(AIR, fk=(12, 26), ff=(8, 17)),
    "air_kick_1": merge(AIR, head=(-5, 44), chest=(-4, 36), hip=(0, 28), fk=(16, 23), ff=(34, 17), bk=(-8, 20), bf=(-14, 26)),
    "special_0": pose(head=(-2, 43), chest=(-3, 35), hip=(-2, 25), fe=(-8, 30), fh=(-12, 33), be=(-12, 31), bh=(-14, 35),
                      fk=(9, 14), ff=(13, 2), bk=(-9, 12), bf=(-13, 2)),
    "special_1": pose(head=(4, 43), chest=(3, 35), hip=(-2, 25), fe=(11, 34), fh=(20, 35), be=(8, 31), bh=(19, 31),
                      fk=(10, 14), ff=(14, 2), bk=(-10, 13), bf=(-15, 2)),
    "hit": pose(head=(-9, 43), chest=(-6, 36), hip=(-1, 26), fe=(2, 32), fh=(9, 29), be=(-14, 34), bh=(-17, 41)),
    "block": pose(head=(-2, 44), chest=(-2, 36), fe=(8, 31), fh=(7, 43), be=(5, 30), bh=(9, 40)),
    "block_low": merge(CROUCH, fe=(10, 14), fh=(9, 27), be=(7, 13), bh=(11, 23)),
    "ko": pose(head=(-20, 5), chest=(-12, 4), hip=(-1, 4), fe=(-8, 2), fh=(-2, 2), be=(-17, 2), bh=(-24, 2),
               fk=(10, 7), ff=(21, 2), bk=(9, 3), bf=(19, 2)),
    "victory": pose(head=(0, 46), chest=(0, 38), hip=(-1, 26), fe=(9, 43), fh=(8, 54), be=(-8, 31), bh=(-4, 27),
                    fk=(4, 14), ff=(6, 2), bk=(-5, 14), bf=(-7, 2)),
}

def shade(color, factor):
    return tuple(max(0, min(255, int(c * factor))) for c in color[:3]) + (255,)

def pt(p):
    return (AX + p[0], AY - p[1])

def capsule(draw, a, b, ra, rb, color):
    """Membro: círculos interpolados de uma junta à outra."""
    steps = 24
    for i in range(steps + 1):
        t = i / steps
        x = a[0] + (b[0] - a[0]) * t
        y = a[1] + (b[1] - a[1]) * t
        r = ra + (rb - ra) * t
        draw.ellipse((x - r, y - r, x + r, y + r), fill=color)

def layer(canvas, paint):
    """Desenha uma parte com contorno escuro e sombra na borda de baixo."""
    part = Image.new("RGBA", (W, H))
    paint(ImageDraw.Draw(part))
    src = part.load()
    out = canvas.load()
    for y in range(H):
        for x in range(W):
            if src[x, y][3]:
                color = src[x, y]
                if y + 1 < H and not src[x, y + 1][3]:
                    color = shade(color, 0.7)
                elif y > 0 and not src[x, y - 1][3]:
                    color = shade(color, 1.25)
                out[x, y] = color
            elif any(0 <= x + dx < W and 0 <= y + dy < H and src[x + dx, y + dy][3]
                     for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                out[x, y] = INK

def fighter_frame(look, p, name):
    img = Image.new("RGBA", (W, H))
    main, suit, trim = (shade(look[k], 1.0) for k in ("main", "suit", "trim"))
    bulk = look["bulk"] * 0.5
    j = {k: pt(v) for k, v in p.items()}
    hx, hy = j["head"]
    cx, cy = j["chest"]
    px, py = j["hip"]
    gear = look["gear"]

    def arm(elbow, hand, dim):
        shoulder = (cx, cy - 1)
        layer(img, lambda d: capsule(d, shoulder, elbow, 2.6 + bulk, 2.0 + bulk, shade(suit, 1.35 * dim)))
        def forearm(d):
            capsule(d, elbow, hand, 2.2 + bulk, 1.7 + bulk, shade(main, dim))
            d.ellipse((hand[0] - 2, hand[1] - 2, hand[0] + 2, hand[1] + 2), fill=shade(SKIN, dim))
        layer(img, forearm)

    def leg(knee, foot, dim):
        layer(img, lambda d: capsule(d, (px, py), knee, 3.6 + bulk, 2.6 + bulk, shade(suit, 1.2 * dim)))
        def shin(d):
            capsule(d, knee, foot, 2.7 + bulk, 1.8 + bulk, shade(main, dim))
            capsule(d, foot, (foot[0] + 3, foot[1]), 1.6, 1.4, shade(suit, 0.8 * dim))
        layer(img, shin)

    # Adereços que ficam atrás do corpo
    sway = 2 if name.endswith(("_1", "_3")) else 0
    if gear == "scarf":
        layer(img, lambda d: (capsule(d, (hx - 3, hy + 5), (hx - 11, hy + 4 + sway), 2, 1.4, main),
                              capsule(d, (hx - 11, hy + 4 + sway), (hx - 18, hy + 7 - sway), 1.4, 0.7, trim)))
    if gear == "tail":
        layer(img, lambda d: capsule(d, (hx - 3, hy - 3), (hx - 10, hy + 9 + sway), 2.2, 0.8, suit))

    if gear == "pony":
        layer(img, lambda d: (capsule(d, (hx - 3, hy - 4), (hx - 12, hy - 2 + sway), 2.6, 1.8, suit),
                              capsule(d, (hx - 12, hy - 2 + sway), (hx - 15, hy + 12 - sway), 1.8, 0.6, suit),
                              d.rectangle((hx - 6, hy - 6, hx - 3, hy - 3), fill=trim)))
    if gear == "turban":
        layer(img, lambda d: capsule(d, (hx - 3, hy + 2), (hx - 13, hy + 13 + sway), 2.4, 1.0, trim))

    if gear == "ribbons":  # fitas longas ao vento
        layer(img, lambda d: (capsule(d, (hx - 3, hy), (hx - 13, hy - 4 + sway * 2), 1.8, 1.2, trim),
                              capsule(d, (hx - 13, hy - 4 + sway * 2), (hx - 22, hy + 3 - sway), 1.2, 0.6, main),
                              capsule(d, (px - 2, py), (px - 15, py + 5 - sway * 2), 1.6, 0.6, trim)))

    form = look.get("form")
    if form:
        behind(img, look, form, j, name, sway)

    arm(j["be"], j["bh"], 0.65)
    leg(j["bk"], j["bf"], 0.65)

    def torso(d):
        capsule(d, (cx, cy), (px, py), 5.0 + bulk, 3.6 + bulk, suit)
        capsule(d, (cx, cy - 1), (px, py - 1), 2.4 + bulk, 1.4 + bulk, main)  # colete
    layer(img, torso)

    def tabard(d):
        d.line((px - 4 - bulk, py - 1, px + 4 + bulk, py - 1), fill=trim, width=2)  # faixa
        if name != "ko":
            drop = min(11, AY - py - 2)
            d.polygon([(px - 2, py), (px + 3, py), (px + 3 + sway, py + drop), (px - 1 + sway, py + drop)], fill=main)
    layer(img, tabard)

    def head(d):
        d.ellipse((hx - 5, hy - 5, hx + 5, hy + 5), fill=main)
        d.rectangle((hx - 1, hy - 2, hx + 5, hy), fill=SKIN)  # fresta dos olhos
        d.point((hx + 3, hy - 1), fill=INK)
        d.rectangle((hx, hy + 1, hx + 5, hy + 3), fill=shade(look["suit"], 1.5))  # máscara
        d.line((hx - 5, hy - 3, hx + 3, hy - 4), fill=trim)
    layer(img, head)

    if gear == "hat":
        layer(img, lambda d: d.polygon([(hx - 10, hy - 2), (hx, hy - 9), (hx + 10, hy - 2)], fill=(196, 164, 90, 255)))
    if gear == "spikes":
        layer(img, lambda d: [d.polygon([(hx + o - 2, hy - 3), (hx + o - 4, hy - 11), (hx + o + 2, hy - 4)], fill=trim)
                              for o in (-2, 1, 4)])

    if gear == "crown":  # diadema de gelo
        layer(img, lambda d: [d.polygon([(hx + o - 2, hy - 4), (hx + o, hy - 10 - (o == 0) * 3), (hx + o + 2, hy - 4)], fill=trim)
                              for o in (-4, 0, 4)])
    if gear == "hood":  # capuz com uma rosa
        layer(img, lambda d: d.polygon([(hx - 7, hy + 4), (hx - 6, hy - 4), (hx, hy - 8), (hx + 5, hy - 4), (hx - 1, hy - 3), (hx - 3, hy + 5)], fill=main))
        layer(img, lambda d: d.ellipse((hx - 5, hy - 8, hx, hy - 3), fill=(236, 66, 96, 255)))
    if gear == "turban":
        layer(img, lambda d: (d.ellipse((hx - 6, hy - 8, hx + 6, hy - 1), fill=main), d.point((hx + 4, hy - 4), fill=trim)))
        layer(img, lambda d: d.rectangle((hx, hy + 1, hx + 5, hy + 4), fill=trim))
    if gear == "gloves":
        layer(img, lambda d: d.line((hx - 5, hy - 4, hx + 5, hy - 4), fill=trim, width=2))

    if gear == "beak":  # capuz de falcão com bico
        layer(img, lambda d: d.polygon([(hx - 7, hy + 2), (hx - 6, hy - 5), (hx + 1, hy - 8), (hx + 7, hy - 4), (hx + 10, hy), (hx + 4, hy - 3), (hx - 2, hy - 3), (hx - 4, hy + 3)], fill=main))
        layer(img, lambda d: d.polygon([(hx + 6, hy - 4), (hx + 11, hy), (hx + 7, hy)], fill=(238, 168, 40, 255)))
        layer(img, lambda d: capsule(d, (hx - 4, hy - 5), (hx - 12, hy - 9 + sway), 1.4, 0.6, trim))

    leg(j["fk"], j["ff"], 1.0)
    arm(j["fe"], j["fh"], 1.0)
    if form:
        front(img, look, form, j, name, sway)

    if gear == "gloves":
        for hand in (j["fh"], j["bh"] if name == "special_1" else j["fh"]):
            layer(img, lambda d: d.ellipse((hand[0] - 4, hand[1] - 4, hand[0] + 3, hand[1] + 3), fill=trim))
    if gear == "armor":
        layer(img, lambda d: d.ellipse((cx - 6, cy - 5, cx + 4, cy + 3), fill=trim))
        layer(img, lambda d: d.ellipse((j["fh"][0] - 3, j["fh"][1] - 3, j["fh"][0] + 3, j["fh"][1] + 3), fill=trim))
    return img

def behind(img, look, form, j, name, sway):
    """Cabelo e adereços que ficam atrás do corpo da forma transformada."""
    hair, style, extra = form
    trim = shade(look["trim"], 1.0)
    hx, hy = j["head"]
    cx, cy = j["chest"]
    px, py = j["hip"]
    if name == "ko":
        return
    if style == "mane":
        layer(img, lambda d: d.polygon([(hx - 2, hy - 8), (hx - 9, hy - 9), (hx - 8, hy - 4), (hx - 17, hy - 3 + sway), (hx - 10, hy + 1),
                                        (hx - 19, hy + 9 - sway), (hx - 8, hy + 7), (hx - 11, hy + 16 + sway), (hx - 2, hy + 6)], fill=hair))
    elif style == "flow":
        layer(img, lambda d: (capsule(d, (hx - 2, hy - 2), (hx - 12, hy + 8 + sway), 5, 3.5, hair),
                              capsule(d, (hx - 12, hy + 8 + sway), (hx - 16, hy + 24 - sway), 3.5, 1, hair)))
    elif style == "nemes":
        layer(img, lambda d: d.polygon([(hx - 3, hy - 9), (hx - 11, hy - 2), (hx - 12, hy + 13), (hx - 4, hy + 11), (hx + 3, hy - 4)], fill=hair))
        layer(img, lambda d: [d.line((hx - 11, hy + o, hx - 4, hy + o - 2), fill=trim) for o in (1, 5, 9)])
    if extra == "tails":  # caudas de chama
        for i, (dx, dy) in enumerate(((-26, -6), (-30, 8), (-24, 20))):
            layer(img, lambda d: capsule(d, (px - 2, py), (px + dx, py + dy + sway * (1 - i)), 3.6, 0.6, hair if i % 2 else trim))
    elif extra == "fins":
        layer(img, lambda d: d.polygon([(cx - 3, cy - 4), (cx - 20, cy - 16 + sway), (cx - 14, cy - 3), (cx - 22, cy + 4), (cx - 4, cy + 6)], fill=trim))
    elif extra == "wings":
        flap = sway * 2
        layer(img, lambda d: d.polygon([(cx - 3, cy - 2), (cx - 18, cy - 24 + flap), (cx - 34, cy - 20 + flap), (cx - 26, cy - 12), (cx - 36, cy - 6),
                                        (cx - 24, cy - 3), (cx - 30, cy + 8), (cx - 8, cy + 5)], fill=hair))
        layer(img, lambda d: [d.line((cx - 6, cy, cx - 28, cy + o + flap), fill=look["main"], width=1) for o in (-18, -9, 1)])
    elif extra == "crystals":  # asas de gelo
        for tip in ((-26, -22), (-32, -6), (-24, 10)):
            layer(img, lambda d: d.polygon([(cx - 3, cy - 3), (cx + tip[0], cy + tip[1] + sway), (cx - 7, cy + 4)], fill=trim))
    elif extra == "vines":
        for end, bud in (((-24, -18), True), ((-30, 6), True), ((-20, 20), False)):
            tip = (cx + end[0], cy + end[1] + sway)
            layer(img, lambda d: (capsule(d, (cx - 3, cy), (cx - 14, cy + end[1] // 3), 2, 1.4, (60, 140, 50, 255)),
                                  capsule(d, (cx - 14, cy + end[1] // 3), tip, 1.4, 0.8, (60, 140, 50, 255))))
            if bud:
                layer(img, lambda d: d.ellipse((tip[0] - 3, tip[1] - 3, tip[0] + 3, tip[1] + 3), fill=hair))
    elif extra == "halo":
        layer(img, lambda d: d.ellipse((hx - 13, hy - 15, hx + 9, hy + 7), outline=trim, width=2))

def front(img, look, form, j, name, sway):
    """Detalhes na frente: cabelo no alto, ombreiras, punhos e olhos acesos."""
    hair, style, extra = form
    trim = shade(look["trim"], 1.0)
    hx, hy = j["head"]
    cx, cy = j["chest"]
    if style == "tall":
        layer(img, lambda d: [d.polygon([(hx + o - 3, hy - 3), (hx + o - 5 - sway, hy - top), (hx + o + 3, hy - 4)], fill=hair)
                              for o, top in ((-4, 13), (0, 18), (4, 12))])
    elif style in ("mane", "flow"):
        layer(img, lambda d: d.polygon([(hx - 6, hy - 1), (hx - 7, hy - 7), (hx - 2, hy - 5), (hx, hy - 10 - sway), (hx + 3, hy - 5), (hx + 8, hy - 7), (hx + 5, hy - 2), (hx - 2, hy - 4)], fill=hair))
    elif style == "nemes":
        layer(img, lambda d: (d.polygon([(hx - 7, hy - 3), (hx - 2, hy - 9), (hx + 6, hy - 3)], fill=hair),
                              d.rectangle((hx + 2, hy - 8, hx + 4, hy - 5), fill=trim)))
    if extra == "antlers":
        layer(img, lambda d: [(capsule(d, (hx + s, hy - 4), (hx + s * 8, hy - 14), 1.4, 0.8, (150, 106, 60, 255)),
                               capsule(d, (hx + s * 5, hy - 10), (hx + s * 10, hy - 9), 0.9, 0.6, (150, 106, 60, 255)),
                               d.ellipse((hx + s * 8 - 2, hy - 17, hx + s * 8 + 2, hy - 13), fill=trim)) for s in (-1, 1)])
    elif extra in ("pauldrons", "wings", "crystals"):
        layer(img, lambda d: d.polygon([(cx - 8, cy - 1), (cx - 5, cy - 9), (cx - 2, cy - 4), (cx + 2, cy - 7), (cx + 4, cy + 1), (cx - 4, cy + 3)], fill=trim))
    if extra in ("pauldrons", "fists"):
        for hand in (j["bh"], j["fh"]):
            layer(img, lambda d: d.ellipse((hand[0] - 5, hand[1] - 5, hand[0] + 4, hand[1] + 4), fill=trim))
    if extra == "bolts":
        for hand in (j["bh"], j["fh"]):
            layer(img, lambda d: d.line([(hand[0] - 5, hand[1] - 7), (hand[0] + 1, hand[1] - 2), (hand[0] - 2, hand[1] + 1), (hand[0] + 5, hand[1] + 6)], fill=trim, width=2))
    # olho aceso e emblema no peito
    layer(img, lambda d: d.rectangle((hx + 2, hy - 2, hx + 4, hy - 1), fill=(255, 255, 255, 255)))
    layer(img, lambda d: d.polygon([(cx, cy - 4), (cx + 3, cy), (cx, cy + 4), (cx - 3, cy)], fill=trim))

def fighter_sheet(look):
    sheet = Image.new("RGBA", (W * len(POSES), H))
    for i, (name, p) in enumerate(POSES.items()):
        sheet.paste(fighter_frame(look, p, name), (W * i, 0))
    return sheet

COLORS = {"fire": [(190, 40, 20), (250, 120, 30), (255, 230, 100)],
          "water": [(30, 80, 190), (60, 170, 245), (225, 250, 255)],
          "plant": [(30, 100, 40), (80, 190, 60), (210, 245, 120)],
          "electric": [(210, 140, 10), (255, 225, 40), (255, 255, 240)],
          "earth": [(80, 52, 32), (150, 104, 60), (220, 188, 136)],
          "air": [(52, 138, 138), (140, 224, 204), (242, 255, 250)]}

def tones(key):
    return [c + (255,) for c in COLORS[key]]

def sheet_of(width, height, paint):
    """Junta quatro quadros de animação lado a lado."""
    sheet = Image.new("RGBA", (width * 4, height))
    for n in range(4):
        img = Image.new("RGBA", (width, height))
        paint(ImageDraw.Draw(img), n)
        sheet.paste(img, (width * n, 0))
    return sheet

def projectile_sheet(key):
    """48x32: cabeça na frente (direita) e rastro atrás, para mostrar o sentido do golpe."""
    dark, mid, light = tones(key)
    rng = random.Random(key)

    def paint(d, n):
        wob = (0, 2, 0, -2)[n]
        for off, length in ((-9, 20), (0, 30), (9, 22)):  # rastro
            end = 30 - length - rng.randint(0, 4)
            if key == "electric":
                d.line([(32, 16 + off // 2), (22, 16 + off + wob), (14, 16 + off // 2 - wob), (end, 16 + off)], fill=mid, width=2)
            else:
                d.polygon([(34, 11 + off // 2), (end, 16 + off + wob), (34, 21 + off // 2)], fill=dark)
                d.polygon([(34, 13 + off // 2), (end + 8, 16 + off + wob), (34, 19 + off // 2)], fill=mid)
        if key == "earth":
            turn = n % 2 * 2
            d.polygon([(24, 8 - turn), (34, 3 + turn), (45, 9), (47, 21), (37, 29 - turn), (25, 24)], fill=mid, outline=dark)
            d.polygon([(29, 9), (36, 7), (40, 14), (31, 15)], fill=light)
        elif key == "plant":
            d.ellipse((24, 5, 46, 27), fill=dark)
            tips = [(47, 16), (35, 4), (23, 16), (35, 28)] if n % 2 == 0 else [(44, 7), (26, 7), (26, 25), (44, 25)]
            for tip in tips:
                d.polygon([(31, 12), tip, (39, 20)], fill=mid)
            d.ellipse((31, 12, 39, 20), fill=light)
        else:
            d.ellipse((23, 5 - wob // 2, 47, 27 + wob // 2), fill=dark)
            d.ellipse((26, 7, 46, 25), fill=mid)
            d.ellipse((33, 11, 44, 21), fill=light)
    return sheet_of(48, 32, paint)

def column_sheet(key):
    """32x80: labareda ou jorro que sobe do chão."""
    dark, mid, light = tones(key)

    def paint(d, n):
        rng = random.Random(n * 31 + 5)
        for color, spread, top in ((dark, 15, 2), (mid, 11, 14), (light, 6, 36)):
            points = [(16 - spread, 79)]
            for i in range(5):
                x = 16 - spread + i * spread / 2
                tip = top + (rng.randint(0, 14) if i != 2 else 0) + abs(i - 2) * 9
                points += [(x - 2, tip + 18), (x + rng.randint(-2, 2), tip)]
            points.append((16 + spread, 79))
            d.polygon(points, fill=color)
        d.ellipse((1, 68, 31, 79), fill=mid)
        for _ in range(7):
            x, y = rng.randint(2, 29), rng.randint(0, 40)
            d.rectangle((x, y, x + 1, y + 1), fill=light)
    return sheet_of(32, 80, paint)

def spark_sheet(inner, outer):
    """40x40: estouro do impacto, crescendo a cada quadro."""
    def paint(d, n):
        radius = (9, 15, 19, 19)[n]
        for i in range(8):
            long = radius if i % 2 == 0 else radius * 0.6
            dx, dy = [(1, 0), (.7, .7), (0, 1), (-.7, .7), (-1, 0), (-.7, -.7), (0, -1), (.7, -.7)][i]
            start = 0 if n < 2 else radius * (0.45 if n == 2 else 0.7)
            d.line((20 + dx * start, 20 + dy * start, 20 + dx * long, 20 + dy * long), fill=outer, width=3 if n < 3 else 1)
        if n < 2:
            d.ellipse((20 - radius / 2, 20 - radius / 2, 20 + radius / 2, 20 + radius / 2), fill=inner)
    return sheet_of(40, 40, paint)

STAGES = {  # céu (de cima para baixo), astro, montanhas, madeira, telhado, chão, linha
    "fire": ([(30, 8, 14), (60, 12, 16), (98, 20, 18), (142, 36, 18), (190, 62, 20), (230, 104, 28)],
             (255, 180, 80), (46, 14, 18), (58, 22, 24), (24, 8, 12), (58, 36, 38), (255, 110, 30)),
    "water": ([(8, 14, 40), (12, 28, 66), (18, 48, 96), (28, 76, 128), (52, 112, 158), (96, 160, 184)],
              (222, 240, 255), (14, 34, 66), (30, 44, 66), (14, 22, 42), (48, 62, 82), (140, 200, 220)),
    "plant": ([(8, 24, 24), (14, 42, 34), (26, 66, 44), (48, 94, 52), (86, 126, 62), (140, 164, 80)],
              (226, 240, 180), (18, 48, 34), (60, 44, 30), (22, 36, 22), (58, 62, 40), (126, 168, 70)),
    "electric": ([(10, 8, 26), (22, 16, 46), (36, 28, 70), (56, 44, 92), (84, 64, 110), (122, 92, 120)],
                 (255, 244, 170), (26, 20, 48), (46, 38, 62), (18, 14, 32), (56, 52, 70), (240, 210, 60)),
    "earth": ([(64, 36, 40), (108, 56, 42), (156, 86, 48), (198, 122, 62), (226, 160, 86), (244, 196, 124)],
              (255, 228, 176), (122, 68, 44), (92, 52, 34), (56, 32, 24), (134, 96, 62), (206, 166, 108)),
    "air": ([(40, 92, 150), (66, 128, 180), (104, 168, 204), (150, 204, 220), (196, 230, 230), (232, 246, 238)],
            (255, 250, 220), (150, 186, 200), (92, 106, 128), (52, 70, 96), (132, 144, 160), (226, 255, 246)),
}

def stage(key):
    """Cenário 320x180 do elemento (chão em y=150)."""
    sky, orb, hills, wood, roof, floor, line = STAGES[key]
    img = Image.new("RGB", (320, 180))
    d = ImageDraw.Draw(img)
    rng = random.Random(key)
    for i, c in enumerate(sky):
        d.rectangle((0, i * 25, 320, i * 25 + 25), fill=c)
    if key not in ("earth", "air"):
        for _ in range(50):
            d.point((rng.randrange(320), rng.randrange(60)), fill=(220, 215, 235))
    d.ellipse((136, 34, 184, 82), fill=orb)
    if key == "electric":  # nuvens carregadas e relâmpagos ao longe
        for x in range(-10, 330, 34):
            d.ellipse((x, rng.randint(-12, 6), x + 56, rng.randint(24, 40)), fill=(34, 28, 56))
        for x in (62, 226, 282):
            points = [(x, 30)]
            for y in range(45, 120, 15):
                points.append((x + rng.randint(-9, 9), y))
            d.line(points, fill=line)
    if key == "earth":  # mesetas
        for x, w, h in [(-10, 90, 70), (96, 60, 46), (190, 74, 62), (268, 70, 84)]:
            d.polygon([(x, 150), (x + 12, 150 - h), (x + w - 12, 150 - h), (x + w, 150)], fill=hills)
    else:
        for x, w, h in [(-20, 150, 62), (90, 170, 44), (200, 160, 70)]:
            d.polygon([(x, 150), (x + w // 2, 150 - h), (x + w, 150)], fill=hills)
    if key == "fire":  # vulcão
        d.polygon([(94, 150), (146, 84), (174, 84), (230, 150)], fill=(34, 10, 14))
        d.polygon([(146, 84), (174, 84), (168, 90), (163, 112), (158, 92), (151, 104)], fill=line)
    if key == "water":  # mar
        d.rectangle((0, 116, 320, 150), fill=(20, 66, 110))
        for _ in range(110):
            x, y = rng.randrange(320), rng.randrange(118, 148)
            d.line((x, y, x + rng.randint(3, 10), y), fill=line)
    for tx in (18, 244):  # dois pagodes
        for level in range(3):
            y, half = 122 - level * 22, 30 - level * 6
            d.rectangle((tx + 30 - half + 6, y, tx + 30 + half - 6, y + 22), fill=wood)
            d.polygon([(tx + 30 - half - 6, y + 4), (tx + 30 - half + 4, y - 5), (tx + 30 + half - 4, y - 5), (tx + 30 + half + 6, y + 4)], fill=roof)
            d.rectangle((tx + 27, y + 9, tx + 33, y + 16), fill=orb)
    if key == "air":  # mar de nuvens e linhas de vento
        for row, (y, color) in enumerate(((112, (214, 234, 240)), (124, (236, 248, 248)))):
            for x in range(-20 - row * 12, 330, 26):
                d.ellipse((x, y + rng.randint(-6, 6), x + 44, y + 30), fill=color)
        for _ in range(16):
            x, y = rng.randrange(300), rng.randrange(14, 100)
            d.arc((x, y, x + 30, y + 12), 180, 330, fill=line)
            d.line((x - 14, y + 6, x + 4, y + 6), fill=line)
    if key == "plant":  # bambuzal
        for x in (4, 14, 88, 100, 112, 206, 220, 304, 314):
            top = rng.randint(20, 80)
            d.rectangle((x, top, x + 3, 150), fill=(74, 118, 52))
            for y in range(top, 150, 14):
                d.line((x, y, x + 3, y), fill=(30, 60, 30))
                d.polygon([(x + 3, y), (x + 14, y - 5), (x + 8, y + 2)], fill=(96, 148, 58))
    d.rectangle((0, 138, 320, 150), fill=roof)
    for x in range(0, 321, 20):
        d.rectangle((x, 132, x + 3, 150), fill=wood)
    d.rectangle((0, 150, 320, 180), fill=floor)
    seam = tuple(int(c * 0.65) for c in floor)
    for row, y in enumerate((150, 156, 164, 174)):
        d.line((0, y, 320, y), fill=seam)
        for x in range(row * 13 % 32, 320, 32):
            d.line((x, y, x, y + 8), fill=seam)
    d.line((0, 150, 320, 150), fill=line)
    if key == "fire":  # rachaduras com lava
        for _ in range(14):
            x, y = rng.randrange(310), rng.randrange(154, 178)
            d.line([(x, y), (x + 5, y + rng.randint(-2, 2)), (x + 10, y + rng.randint(-3, 3))], fill=line)
    return img

def main():
    (OUT / "sprites").mkdir(parents=True, exist_ok=True)
    for key, look in CHARACTERS.items():
        fighter_sheet(look).save(OUT / "sprites" / f"{key}.png")
        fighter_sheet({**look, "main": ALT[key]}).save(OUT / "sprites" / f"{key}_alt.png")
        main_, suit, trim, hair, style, extra = FORMS[key]
        form = {**look, "main": main_, "suit": suit, "trim": trim, "bulk": look["bulk"] + 1, "form": (hair + (255,), style, extra)}
        fighter_sheet(form).save(OUT / "sprites" / f"{key}_form.png")
    spark_sheet((255, 255, 255, 255), (255, 214, 60, 255)).save(OUT / "sprites" / "spark_hit.png")
    spark_sheet((235, 250, 255, 255), (110, 180, 255, 255)).save(OUT / "sprites" / "spark_block.png")
    for key in COLORS:  # um conjunto de efeitos e um cenário por clã
        projectile_sheet(key).save(OUT / "sprites" / f"{key}_projectile.png")
        column_sheet(key).save(OUT / "sprites" / f"{key}_column.png")
        stage(key).save(OUT / f"stage_{key}.png")
    (OUT / "frames.txt").write_text("\n".join(POSES) + "\n")

if __name__ == "__main__":
    main()
