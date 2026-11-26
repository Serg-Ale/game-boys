#!/usr/bin/env python3
"""Gera as pistas de corrida: a imagem do chão (vista de cima) e os dados da pista.
Uso: python3 tools/make_track.py
"""
import json
import math
import random
from PIL import Image, ImageDraw
from make_sprites import OUT

SIZE = 4096
HALF = 172      # meia largura da pista
STEP = 16       # distância entre os pontos do traçado

# Vulcão da Chama: retão, curvas abertas, "S" duplo, grampo e volta pelo sul.
VOLCANO = [(560, 3250), (560, 2350), (540, 1500), (600, 850), (950, 480), (1500, 440), (1920, 700), (2200, 1120),
           (2580, 1180), (2830, 820), (3150, 440), (3590, 540), (3730, 980), (3520, 1430), (3080, 1700), (2900, 2100),
           (3170, 2420), (3600, 2640), (3720, 3150), (3450, 3600), (2900, 3660), (2540, 3330), (2380, 2820), (1980, 2580),
           (1600, 2830), (1480, 3340), (1150, 3680), (730, 3650)]

def spline(points):
    """Catmull-Rom fechado, depois reamostrado em passos iguais."""
    dense = []
    n = len(points)
    for i in range(n):
        p0, p1, p2, p3 = (points[(i + k - 1) % n] for k in range(4))
        for s in range(40):
            t = s / 40
            dense.append(tuple(0.5 * (2 * p1[a] + (-p0[a] + p2[a]) * t + (2 * p0[a] - 5 * p1[a] + 4 * p2[a] - p3[a]) * t * t
                                      + (-p0[a] + 3 * p1[a] - 3 * p2[a] + p3[a]) * t ** 3) for a in (0, 1)))
    out = [dense[0]]
    carry = 0.0
    for a, b in zip(dense, dense[1:] + dense[:1]):
        seg = math.dist(a, b)
        while carry + seg >= STEP:
            t = (STEP - carry) / seg
            a = (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)
            out.append(a)
            seg = math.dist(a, b)
            carry = 0.0
        carry += seg
    if math.dist(out[-1], out[0]) < STEP * 0.6:
        out.pop()
    return out

def normal(path, i):
    a, b = path[i - 1], path[(i + 1) % len(path)]
    dx, dy = b[0] - a[0], b[1] - a[1]
    length = math.hypot(dx, dy)
    return (-dy / length, dx / length), (dx / length, dy / length)

def volcano():
    rng = random.Random(7)
    path = spline(VOLCANO)
    n = len(path)
    img = Image.new("RGB", (SIZE, SIZE), (52, 24, 24))
    d = ImageDraw.Draw(img)
    for _ in range(21000):  # rochas no chão
        x, y, r = rng.randrange(SIZE), rng.randrange(SIZE), rng.randint(5, 22)
        d.ellipse((x - r, y - r, x + r, y + r), fill=rng.choice([(66, 30, 28), (40, 18, 20), (76, 38, 30), (58, 28, 26)]))
    for _ in range(340):  # lagos de lava
        x, y, r = rng.randrange(SIZE), rng.randrange(SIZE), rng.randint(26, 80)
        for color, k in (((120, 30, 10), 1.25), ((224, 84, 16), 1.0), ((255, 168, 40), 0.6), ((255, 230, 120), 0.22)):
            d.ellipse((x - r * k, y - r * k * 0.8, x + r * k, y + r * k * 0.8), fill=color)

    def band(width, color, wanted=lambda i: True):
        for i in range(n):
            if not wanted(i):
                continue
            a, b = path[i], path[(i + 1) % n]
            (na, _), (nb, _) = normal(path, i), normal(path, (i + 1) % n)
            d.polygon([(a[0] + na[0] * width, a[1] + na[1] * width), (b[0] + nb[0] * width, b[1] + nb[1] * width),
                       (b[0] - nb[0] * width, b[1] - nb[1] * width), (a[0] - na[0] * width, a[1] - na[1] * width)], fill=color)

    # Nenhum trecho pode encostar em outro.
    for i in range(0, n, 4):
        for j in range(i + 4, n, 4):
            if min(j - i, n - (j - i)) * STEP > 900:
                assert math.dist(path[i], path[j]) > 2 * HALF + 90, ("trechos colados", path[i], path[j], math.dist(path[i], path[j]))
    band(HALF + 54, (96, 66, 52))                            # acostamento de cinzas
    band(HALF + 16, (236, 236, 228))                         # zebras
    band(HALF + 16, (206, 40, 32), lambda i: i % 6 < 3)
    band(HALF, (92, 84, 92))                                 # pista
    band(HALF - 12, (102, 94, 104), lambda i: i % 8 < 4)
    for _ in range(60000):
        i = rng.randrange(n)
        (nx, ny), _t = normal(path, i)
        off = rng.uniform(-HALF + 4, HALF - 4)
        x, y = path[i][0] + nx * off, path[i][1] + ny * off
        d.rectangle((x, y, x + 3, y + 3), fill=rng.choice([(78, 70, 80), (118, 110, 120)]))
    band(4, (255, 196, 60), lambda i: i % 5 < 2)             # faixa central

    def quad(i, along, across, color):
        """Retângulo orientado pela pista: along/across são intervalos em pixels."""
        (nx, ny), (tx, ty) = normal(path, i)
        px, py = path[i]
        d.polygon([(px + tx * a + nx * c, py + ty * a + ny * c) for a, c in
                   ((along[0], across[0]), (along[1], across[0]), (along[1], across[1]), (along[0], across[1]))], fill=color)

    size = HALF / 6
    for row in range(3):  # linha de largada quadriculada
        for col in range(12):
            quad(0, (row * size - 20, (row + 1) * size - 20), (-HALF + col * size, -HALF + (col + 1) * size),
                 (240, 240, 240) if (row + col) % 2 else (20, 18, 24))

    boosts = [int(n * f) for f in (0.07, 0.24, 0.46, 0.63, 0.88)]
    for i in boosts:  # setas de turbo
        for k in range(3):
            (nx, ny), (tx, ty) = normal(path, i)
            px, py = path[i]
            base = k * 44 - 50
            d.polygon([(px + tx * (base + a) + nx * c, py + ty * (base + a) + ny * c) for a, c in
                       ((0, -86), (40, 0), (0, 86), (0, 54), (16, 0), (0, -54))], fill=(80, 230, 255))

    props = []
    for i in range(0, n, 5):  # tochas, rochas e pilares à beira da pista
        (nx, ny), _t = normal(path, i)
        for side in (-1, 1):
            off = side * (HALF + (62 if i % 10 == 0 else rng.randint(80, 230)))
            x, y = path[i][0] + nx * off, path[i][1] + ny * off
            if min(math.dist((x, y), p) for p in path[::2]) > HALF + 50:
                kind = "torch" if i % 10 == 0 else rng.choice(["rock", "rock", "spire"])
                props.append([round(x), round(y), kind])
    img.save(OUT / "kart" / "track_fire.png")
    orbs = [int(n * f) for f in (0.15, 0.35, 0.55, 0.75, 0.94)]  # fileiras de orbes de poder
    arches = [0] + [int(n * f) for f in (0.2, 0.4, 0.6, 0.82)]  # portais sobre a pista
    data = {"name": "Vulcão da Chama", "clan": "fire", "half": HALF, "size": SIZE, "boosts": boosts, "orbs": orbs, "arches": arches,
            "path": [[round(x, 1), round(y, 1)] for x, y in path], "props": props}
    (OUT / "kart" / "track_fire.json").write_text(json.dumps(data))
    print(n, "pontos,", len(props), "objetos, comprimento", n * STEP)

def prop_art():
    """Objetos à beira da pista, desenhados de frente."""
    def save(name, w, h, paint):
        img = Image.new("RGBA", (w, h))
        paint(ImageDraw.Draw(img))
        img.save(OUT / "kart" / f"prop_{name}.png")

    save("torch", 24, 64, lambda d: (d.rectangle((9, 24, 14, 63), fill=(60, 40, 30)), d.rectangle((6, 22, 17, 28), fill=(140, 100, 50)),
                                     d.polygon([(4, 20), (12, 0), (20, 20), (12, 24)], fill=(255, 130, 20)),
                                     d.polygon([(8, 20), (12, 8), (16, 20), (12, 23)], fill=(255, 230, 100))))
    save("rock", 48, 32, lambda d: (d.polygon([(2, 31), (8, 12), (20, 4), (36, 8), (46, 31)], fill=(74, 40, 36)),
                                    d.polygon([(10, 16), (20, 6), (30, 10), (22, 18)], fill=(112, 66, 52)),
                                    d.line((30, 14, 26, 24, 34, 31), fill=(255, 130, 20), width=2)))
    save("spire", 32, 88, lambda d: (d.polygon([(2, 87), (10, 30), (16, 0), (22, 36), (30, 87)], fill=(46, 22, 30)),
                                     d.polygon([(10, 40), (16, 4), (17, 87), (8, 87)], fill=(76, 36, 40)),
                                     d.line((18, 40, 15, 60, 20, 87), fill=(255, 150, 30), width=2)))

if __name__ == "__main__":
    (OUT / "kart").mkdir(parents=True, exist_ok=True)
    volcano()
    prop_art()
