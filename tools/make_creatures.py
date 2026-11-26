#!/usr/bin/env python3
"""Criaturas invocadas pelos supremos (originais), uma por clã: dois quadros (parada e atacando).
Uso: python3 tools/make_creatures.py
"""
from PIL import Image
from make_sprites import OUT, W, H, capsule, layer

def c(r, g, b):
    return (r, g, b, 255)

def eye(img, x, y, color):
    layer(img, lambda d: (d.rectangle((x, y, x + 2, y + 1), fill=color), d.point((x + 2, y), fill=c(20, 10, 20))))

def dragon(img, attack):
    red, dark, belly, flame = c(214, 58, 30), c(130, 28, 24), c(255, 180, 70), c(255, 228, 90)
    lift = 6 if attack else 0
    layer(img, lambda d: d.polygon([(34, 36), (4, 6 - lift // 2), (14, 18), (4, 24), (18, 28), (12, 40), (34, 44)], fill=dark))
    layer(img, lambda d: (capsule(d, (30, 54), (12, 62), 7, 3, red), capsule(d, (12, 62), (4, 50), 3, 1.5, red),
                          d.polygon([(4, 52), (0, 40), (8, 46)], fill=flame)))
    layer(img, lambda d: d.ellipse((24, 34, 56, 64), fill=red))
    layer(img, lambda d: d.ellipse((36, 42, 54, 62), fill=belly))
    layer(img, lambda d: (capsule(d, (46, 42), (58, 22), 8, 5.5, red), capsule(d, (49, 44), (61, 26), 3, 2, belly)))
    layer(img, lambda d: d.polygon([(40, 34), (14, 14 - lift), (26, 24), (18, 34), (30, 36), (26, 46), (42, 44)], fill=c(240, 96, 36)))
    layer(img, lambda d: d.polygon([(56, 16), (46, 3), (62, 11)], fill=flame))
    layer(img, lambda d: d.polygon([(54, 14), (72, 11), (86, 18), (84, 22), (68, 23), (56, 27)], fill=red))
    jaw = 10 if attack else 3
    layer(img, lambda d: d.polygon([(60, 23), (82, 23 + jaw), (78, 27 + jaw), (60, 30)], fill=dark))
    if attack:
        layer(img, lambda d: d.polygon([(70, 24), (95, 22), (88, 27), (95, 33), (74, 31)], fill=flame))
    eye(img, 66, 15, flame)
    for x in (36, 48):
        layer(img, lambda d: capsule(d, (x, 58), (x + 4, 67), 4.5, 3, red))

def serpent(img, attack):
    blue, dark, belly, foam = c(40, 136, 226), c(22, 70, 150), c(170, 232, 255), c(235, 252, 255)
    path = [(6, 58), (18, 66), (34, 62), (36, 48), (24, 40), (30, 28), (46, 30), (56, 22), (64, 16)]
    for i in range(len(path) - 1):
        a, b = path[i], path[i + 1]
        layer(img, lambda d: d.polygon([(a[0] - 4, a[1] - 3), (a[0] + 1, a[1] - 13), (a[0] + 6, a[1] - 3)], fill=dark) if i % 2 else None)
        layer(img, lambda d: capsule(d, a, b, 3 + i * 0.7, 3.7 + i * 0.7, blue))
        layer(img, lambda d: capsule(d, (a[0] + 2, a[1] + 3), (b[0] + 2, b[1] + 3), 1 + i * 0.2, 1.2 + i * 0.2, belly))
    layer(img, lambda d: d.polygon([(60, 12), (46, 1), (56, 9), (50, 12), (62, 18)], fill=foam))
    layer(img, lambda d: d.polygon([(58, 10), (74, 8), (88, 16), (84, 20), (70, 20), (60, 24)], fill=blue))
    jaw = 11 if attack else 3
    layer(img, lambda d: d.polygon([(64, 20), (84, 20 + jaw), (80, 24 + jaw), (62, 27)], fill=dark))
    layer(img, lambda d: d.polygon([(60, 20), (52, 36), (64, 28)], fill=belly))
    if attack:
        layer(img, lambda d: d.ellipse((78, 20, 94, 34), fill=foam))
    eye(img, 70, 12, foam)
    layer(img, lambda d: [d.ellipse((x, 62 - x % 7, x + 14, 70), fill=c(90, 180, 240)) for x in range(0, 60, 11)])

def stag(img, attack):
    bark, dark, leaf, glow = c(122, 86, 48), c(78, 54, 34), c(76, 170, 62), c(210, 250, 120)
    rise = 4 if attack else 0
    for x in (28, 54):
        layer(img, lambda d: capsule(d, (x, 46), (x - 3, 67), 4, 2.5, dark))
    layer(img, lambda d: d.ellipse((18, 30, 62, 54), fill=bark))
    layer(img, lambda d: [d.ellipse((x, y, x + 15, y + 11), fill=leaf) for x, y in ((18, 26), (28, 22), (40, 26), (12, 34))])
    layer(img, lambda d: capsule(d, (56, 38), (66, 26 - rise), 8, 5, bark))
    layer(img, lambda d: d.polygon([(62, 20 - rise), (76, 19 - rise), (88, 30 - rise), (82, 34 - rise), (66, 32 - rise)], fill=bark))
    for sign, base in ((-1, 66), (1, 72)):
        top = (base + sign * 12, 4 - rise // 2)
        layer(img, lambda d: (capsule(d, (base, 22 - rise), top, 2, 1.2, dark),
                              capsule(d, (base + sign * 6, 13 - rise), (base + sign * 15, 14 - rise), 1.4, 0.8, dark)))
        layer(img, lambda d: (d.ellipse((top[0] - 5, top[1] - 3, top[0] + 5, top[1] + 5), fill=leaf),
                              d.ellipse((top[0] - 2, top[1] - 1, top[0] + 2, top[1] + 3), fill=c(255, 130, 170))))
    eye(img, 73, 23 - rise, glow)
    if attack:
        layer(img, lambda d: [d.ellipse((x, y, x + 4, y + 4), fill=glow) for x, y in ((90, 20), (84, 8), (92, 40), (80, 46))])
    for x in (36, 60):
        layer(img, lambda d: capsule(d, (x, 48), (x + 3, 67), 4.5, 3, bark))

def bird(img, attack):
    gold, dark, white = c(246, 208, 36), c(180, 126, 16), c(255, 252, 200)
    tip = 2 if attack else 30
    layer(img, lambda d: d.polygon([(42, 34), (10, tip), (20, tip + 8), (6, tip + 12), (22, tip + 18), (12, tip + 24), (40, 46)], fill=dark))
    layer(img, lambda d: d.polygon([(32, 44), (4, 54), (18, 52), (8, 66), (28, 56), (26, 68), (44, 50)], fill=gold))
    layer(img, lambda d: d.ellipse((32, 28, 62, 52), fill=gold))
    layer(img, lambda d: d.ellipse((44, 34, 60, 50), fill=white))
    layer(img, lambda d: d.polygon([(48, 34), (24, tip - 2), (34, tip + 8), (24, tip + 14), (40, tip + 18), (34, tip + 26), (54, 42)], fill=gold))
    layer(img, lambda d: d.polygon([(60, 18), (44, 4), (54, 14), (42, 14), (58, 26)], fill=white))
    layer(img, lambda d: d.ellipse((54, 18, 76, 38), fill=gold))
    gap = 7 if attack else 1
    layer(img, lambda d: d.polygon([(72, 23), (90, 28), (72, 29)], fill=c(236, 120, 30)))
    layer(img, lambda d: d.polygon([(72, 30), (84, 30 + gap), (70, 34)], fill=c(190, 90, 24)))
    eye(img, 66, 24, white)
    for x in (42, 52):
        layer(img, lambda d: capsule(d, (x, 50), (x + 3, 62), 2, 1.5, dark))
    if attack:
        layer(img, lambda d: d.line([(80, 36), (90, 46), (82, 48), (94, 64)], fill=white, width=3))

def turtle(img, attack):
    skin, shell, dark, stone = c(150, 132, 78), c(128, 86, 50), c(84, 54, 34), c(196, 170, 128)
    rise = 5 if attack else 0
    for x in (14, 50):
        layer(img, lambda d: capsule(d, (x, 52), (x - 2, 66), 7, 6, dark))
    layer(img, lambda d: d.pieslice((4, 14 - rise, 70, 90 - rise), 180, 360, fill=shell))
    for x, y, s in ((14, 34, 14), (28, 18, 18), (48, 30, 15), (34, 36, 12)):
        layer(img, lambda d: d.polygon([(x, y + s - rise), (x + s // 2, y - rise), (x + s, y + s - rise)], fill=stone))
    layer(img, lambda d: d.rectangle((4, 50 - rise, 70, 56 - rise), fill=dark))
    layer(img, lambda d: capsule(d, (64, 48), (76, 40 - rise), 8, 7, skin))
    layer(img, lambda d: d.ellipse((68, 28 - rise, 92, 48 - rise), fill=skin))
    layer(img, lambda d: d.polygon([(70, 32 - rise), (80, 22 - rise), (90, 32 - rise)], fill=stone))
    if attack:
        layer(img, lambda d: d.polygon([(74, 43), (92, 40), (88, 52), (76, 50)], fill=c(60, 30, 26)))
        layer(img, lambda d: [d.ellipse((x, 60, x + 9, 69), fill=stone) for x in (72, 84)])
    eye(img, 80, 33 - rise, c(255, 226, 120))
    for x in (26, 60):
        layer(img, lambda d: capsule(d, (x, 54), (x + 2, 66), 8, 7, skin))

def fox(img, attack):
    fur, dark, pale, ember = c(112, 100, 112), c(58, 48, 62), c(214, 202, 206), c(255, 108, 60)
    for i, (tx, ty) in enumerate(((2, 14), (4, 34), (12, 52))):
        layer(img, lambda d: capsule(d, (34, 50), (tx + 8, ty + 8), 7, 5, fur if i % 2 else dark))
        layer(img, lambda d: d.ellipse((tx, ty - (3 if attack else 0), tx + 14, ty + 13), fill=ember))
    for x in (36, 58):
        layer(img, lambda d: capsule(d, (x, 50), (x - 2, 67), 3.5, 2, dark))
    layer(img, lambda d: d.ellipse((28, 38, 64, 56), fill=fur))
    layer(img, lambda d: capsule(d, (58, 44), (68, 28), 8, 6, fur))
    layer(img, lambda d: d.polygon([(60, 24), (58, 4), (70, 18)], fill=dark))
    layer(img, lambda d: d.polygon([(70, 20), (78, 3), (80, 22)], fill=dark))
    layer(img, lambda d: d.polygon([(62, 18), (78, 18), (92, 32), (76, 34), (62, 32)], fill=fur))
    layer(img, lambda d: d.polygon([(68, 30), (92, 32), (74, 38)], fill=pale))
    if attack:
        layer(img, lambda d: d.polygon([(72, 36), (95, 38), (82, 42), (95, 50), (70, 44)], fill=ember))
    eye(img, 73, 23, ember)
    for x in (42, 64):
        layer(img, lambda d: capsule(d, (x, 52), (x + 3, 67), 4, 2.5, fur))

def wolf(img, attack):
    snow, ice, dark, glow = c(220, 238, 250), c(130, 200, 236), c(70, 108, 160), c(120, 255, 255)
    layer(img, lambda d: capsule(d, (28, 40), (6, 22), 8, 3, ice))
    for x in (26, 56):
        layer(img, lambda d: capsule(d, (x, 46), (x - 4, 67), 5, 3, dark))
    layer(img, lambda d: d.ellipse((20, 30, 62, 54), fill=snow))
    layer(img, lambda d: d.ellipse((44, 24, 70, 52), fill=snow))
    layer(img, lambda d: [d.polygon([(x, 34), (x + 2, y), (x + 10, 32)], fill=ice) for x, y in ((24, 18), (34, 10), (46, 6), (56, 12))])
    layer(img, lambda d: d.polygon([(62, 24), (62, 8), (72, 22)], fill=ice))
    layer(img, lambda d: d.polygon([(60, 22), (76, 20), (92, 30), (90, 35), (64, 40)], fill=snow))
    jaw = 9 if attack else 2
    layer(img, lambda d: d.polygon([(70, 36), (90, 36 + jaw), (84, 40 + jaw), (66, 42)], fill=dark))
    if attack:
        layer(img, lambda d: [d.polygon([(84, y), (95, y + 2), (86, y + 6)], fill=glow) for y in (34, 44)])
    eye(img, 74, 26, glow)
    for x in (34, 62):
        layer(img, lambda d: capsule(d, (x, 48), (x + 2, 67), 5.5, 3.5, snow))

def maw(img, attack):
    stem, leaf, petal, dark, tooth = c(86, 128, 48), c(60, 150, 60), c(196, 36, 78), c(96, 14, 44), c(255, 240, 190)
    layer(img, lambda d: [d.polygon([(46, 66), (x, y), (x + 8, y + 10)], fill=leaf) for x, y in ((4, 50), (78, 52), (16, 38))])
    for x, tip in ((40, 18), (52, 76)):
        layer(img, lambda d: capsule(d, (x, 60), (tip, 68), 5, 2, stem))
    layer(img, lambda d: capsule(d, (46, 64), (38, 46), 6, 5, stem))
    layer(img, lambda d: capsule(d, (38, 46), (54, 32), 5, 7, stem))
    gap = 14 if attack else 5
    layer(img, lambda d: d.polygon([(44, 30), (34, 8), (50, 14), (58, 0), (68, 12), (88, 6 - gap // 2), (92, 22 - gap // 2), (58, 32)], fill=petal))
    layer(img, lambda d: d.polygon([(56, 32), (92, 26 + gap), (80, 42 + gap), (58, 46), (42, 40)], fill=petal))
    layer(img, lambda d: d.polygon([(56, 31), (90, 22 - gap // 2), (90, 28 + gap)], fill=dark))
    layer(img, lambda d: [d.polygon([(x, 26 - (x - 60) // 6 - gap // 4), (x + 3, 33 - gap // 4), (x + 6, 25 - (x - 60) // 6 - gap // 4)], fill=tooth) for x in (64, 74, 82)])
    layer(img, lambda d: [d.polygon([(x, 33 + gap // 2 + (x - 60) // 8), (x + 3, 26 + gap // 3), (x + 6, 34 + gap // 2 + (x - 60) // 8)], fill=tooth) for x in (68, 78)])
    eye(img, 60, 14, tooth)

def ape(img, attack):
    fur, dark, face, volt = c(116, 88, 196), c(64, 46, 124), c(196, 170, 220), c(255, 232, 60)
    raise_ = 18 if attack else 0
    for x in (30, 52):
        layer(img, lambda d: capsule(d, (x, 52), (x - 2, 66), 7, 5, dark))
    layer(img, lambda d: capsule(d, (30, 30), (14, 52), 8, 7, dark))
    layer(img, lambda d: d.ellipse((6, 46, 24, 66), fill=fur))
    layer(img, lambda d: d.polygon([(24, 24), (62, 22), (58, 56), (32, 56)], fill=fur))
    layer(img, lambda d: d.ellipse((36, 34, 54, 52), fill=face))
    layer(img, lambda d: d.ellipse((42, 8, 66, 32), fill=fur))
    layer(img, lambda d: d.ellipse((50, 16, 68, 32), fill=face))
    layer(img, lambda d: d.polygon([(44, 12), (38, 0), (52, 8), (56, 0), (60, 10)], fill=volt))
    hand = (80, 44 - raise_ * 2)
    layer(img, lambda d: capsule(d, (60, 30), hand, 8, 8, fur))
    layer(img, lambda d: d.ellipse((hand[0] - 10, hand[1] - 8, hand[0] + 12, hand[1] + 12), fill=volt if attack else fur))
    if attack:
        layer(img, lambda d: d.line([(86, 2), (92, 14), (86, 16), (95, 30)], fill=volt, width=3))
    eye(img, 60, 20, volt)

def scorpion(img, attack):
    sand, dark, pale, venom = c(214, 168, 90), c(138, 96, 48), c(246, 218, 156), c(80, 220, 190)
    for x, tip in ((26, 14), (36, 28), (48, 54), (58, 70)):
        layer(img, lambda d: capsule(d, (x, 56), (tip, 67), 3, 1.5, dark))
    sting = (78, 30) if attack else (52, 10)
    path = [(24, 52), (10, 40), (10, 22), (24, 8), (40, 4), sting]
    for i in range(len(path) - 1):
        layer(img, lambda d: capsule(d, path[i], path[i + 1], 7 - i, 6 - i * 0.8, sand if i % 2 else pale))
    layer(img, lambda d: d.polygon([(sting[0] - 2, sting[1] - 4), (sting[0] + 12, sting[1] + 8), (sting[0] - 4, sting[1] + 4)], fill=venom))
    layer(img, lambda d: d.ellipse((18, 42, 62, 62), fill=sand))
    layer(img, lambda d: [d.arc((x, 40, x + 20, 62), 200, 340, fill=dark, width=2) for x in (22, 32, 42)])
    layer(img, lambda d: d.ellipse((52, 40, 74, 60), fill=pale))
    for y in (46, 56):
        claw = (84, y - (8 if attack and y == 46 else 0))
        layer(img, lambda d: capsule(d, (66, y), claw, 3.5, 4, sand))
        layer(img, lambda d: d.polygon([(claw[0] - 4, claw[1] - 4), (claw[0] + 11, claw[1] - 7), (claw[0] + 3, claw[1]),
                                        (claw[0] + 11, claw[1] + 5), (claw[0] - 4, claw[1] + 4)], fill=dark))
    eye(img, 66, 44, venom)

def manta(img, attack):
    skin, dark, pale, glow = c(130, 222, 204), c(46, 128, 134), c(236, 255, 250), c(255, 236, 140)
    flap = -10 if attack else 8
    layer(img, lambda d: capsule(d, (30, 40), (2, 56), 4, 0.8, dark))
    layer(img, lambda d: d.polygon([(46, 28), (18, 8 + flap), (34, 30), (14, 40), (40, 42)], fill=dark))
    layer(img, lambda d: d.ellipse((28, 26, 76, 48), fill=skin))
    layer(img, lambda d: d.ellipse((44, 36, 74, 48), fill=pale))
    layer(img, lambda d: d.polygon([(58, 32), (30, 62 - flap), (40, 44), (22, 42 - flap // 2), (50, 38)], fill=skin))
    layer(img, lambda d: [capsule(d, (68, 30), (86, y), 3, 1, pale) for y in (20, 40)])
    layer(img, lambda d: d.arc((20, 4, 84, 66), 300, 350, fill=glow, width=2))
    if attack:
        layer(img, lambda d: [d.arc((x, 16, x + 22, 52), 290, 70, fill=pale, width=2) for x in (64, 72)])
    eye(img, 66, 31, glow)

def griffin(img, attack):
    gold, dark, white, beak = c(190, 168, 84), c(112, 80, 40), c(246, 240, 212), c(238, 160, 40)
    tip = 4 if attack else 24
    layer(img, lambda d: capsule(d, (20, 48), (4, 34), 3, 1.5, dark))
    layer(img, lambda d: d.ellipse((1, 28, 10, 38), fill=white))
    layer(img, lambda d: d.polygon([(40, 36), (10, tip), (22, tip + 4), (14, tip + 12), (28, tip + 14), (22, tip + 22), (46, 46)], fill=dark))
    for x in (22, 54):
        layer(img, lambda d: capsule(d, (x, 50), (x - 3, 66), 4.5, 3, dark))
    layer(img, lambda d: d.ellipse((18, 36, 62, 56), fill=gold))
    layer(img, lambda d: d.ellipse((46, 28, 68, 54), fill=white))
    layer(img, lambda d: d.polygon([(46, 38), (30, tip - 3), (42, tip + 3), (36, tip + 10), (50, tip + 14), (46, tip + 22), (60, 40)], fill=gold))
    layer(img, lambda d: d.ellipse((56, 14, 78, 36), fill=white))
    layer(img, lambda d: d.polygon([(58, 18), (46, 8), (62, 14)], fill=gold))
    gap = 7 if attack else 1
    layer(img, lambda d: d.polygon([(74, 20), (90, 24), (86, 32), (82, 27), (74, 28)], fill=beak))
    layer(img, lambda d: d.polygon([(72, 29), (82, 29 + gap), (70, 33)], fill=c(188, 112, 24)))
    for x in (34, 62):
        layer(img, lambda d: capsule(d, (x, 52), (x + 4, 66), 4, 2.5, gold))
        layer(img, lambda d: d.polygon([(x + 2, 64), (x + 10, 68), (x + 1, 69)], fill=beak))
    eye(img, 68, 20, beak)

# Uma criatura por ninja.
CREATURES = {"fire": dragon, "water": serpent, "plant": stag, "electric": bird, "earth": turtle,
             "ash": fox, "frost": wolf, "thorn": maw, "thunder": ape, "sand": scorpion, "air": manta, "gale": griffin}

def main():
    for key, paint in CREATURES.items():
        sheet = Image.new("RGBA", (W * 2, H))
        for n in range(2):
            img = Image.new("RGBA", (W, H))
            paint(img, n == 1)
            sheet.paste(img, (W * n, 0))
        sheet.save(OUT / "sprites" / f"{key}_creature.png")

if __name__ == "__main__":
    main()
