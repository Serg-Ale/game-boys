#!/usr/bin/env python3
"""Sintetiza os efeitos e as músicas (originais, estilo arcade dos anos 90) em assets/sounds/.
Uso: python3 tools/make_sounds.py   (requer numpy)
"""
import wave
from pathlib import Path
import numpy as np

OUT = Path(__file__).resolve().parent.parent / "assets" / "sounds"
RATE = 22050
rng = np.random.default_rng(1990)

def times(seconds):
    return np.arange(int(RATE * seconds)) / RATE

def decay(n, power=2.0, attack=0.004):
    env = (1 - np.linspace(0, 1, n)) ** power
    rise = min(n, int(RATE * attack))
    env[:rise] *= np.linspace(0, 1, rise)
    return env

def tone(start, end, seconds, shape="square", power=1.5, duty=0.5):
    """Nota que desliza de uma frequência a outra."""
    n = int(RATE * seconds)
    phase = np.cumsum(np.linspace(start, end, n)) / RATE % 1.0
    if shape == "square":
        wave_ = np.where(phase < duty, 1.0, -1.0)
    elif shape == "saw":
        wave_ = 2 * phase - 1
    elif shape == "triangle":
        wave_ = 4 * np.abs(phase - 0.5) - 1
    else:
        wave_ = np.sin(2 * np.pi * phase)
    return wave_ * decay(n, power)

def noise(seconds, brightness=1.0, power=2.0, attack=0.002):
    """Ruído; brightness < 1 abafa (passa-baixa simples)."""
    n = int(RATE * seconds)
    raw = rng.uniform(-1, 1, n)
    width = max(1, int(1 / max(brightness, 0.02)))
    if width > 1:
        raw = np.convolve(raw, np.ones(width) / width, mode="same") * np.sqrt(width)
    return raw * decay(n, power, attack)

def mix(*parts):
    """Cada parte é (sinal, volume, atraso em segundos)."""
    length = max(int(RATE * delay) + len(sig) for sig, _, delay in parts)
    out = np.zeros(length)
    for sig, volume, delay in parts:
        a = int(RATE * delay)
        out[a:a + len(sig)] += sig * volume
    return out

def save(name, signal, peak=0.8):
    signal = signal / (np.max(np.abs(signal)) or 1) * peak
    signal = np.round(signal * 127) / 127  # granulado de 8 bits
    with wave.open(str(OUT / f"{name}.wav"), "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes((signal * 32000).astype("<i2").tobytes())

def arpeggio(notes, step, shape="square", length=None):
    return mix(*[(tone(freq(n), freq(n), length or step * 2, shape, 1.2, 0.25), 0.6, i * step) for i, n in enumerate(notes)])

def freq(midi):
    return 440.0 * 2 ** ((midi - 69) / 12)

def effects():
    save("move", tone(700, 900, 0.05), 0.4)
    save("confirm", arpeggio([72, 76, 79, 84], 0.045), 0.6)
    save("back", arpeggio([76, 69], 0.06), 0.5)
    save("versus", mix((noise(0.7, 0.08, 1.5), 1.0, 0), (tone(110, 55, 0.9, "saw"), 0.8, 0),
                       (arpeggio([57, 64, 69], 0.09, length=0.5), 0.7, 0.15)), 0.85)
    save("punch_swing", noise(0.09, 0.5, 1.5, 0.03), 0.35)
    save("kick_swing", noise(0.16, 0.2, 1.3, 0.06), 0.45)
    save("hit", mix((noise(0.12, 0.35, 3), 1.0, 0), (tone(190, 60, 0.13, "sine"), 1.0, 0)), 0.85)
    save("hit_heavy", mix((noise(0.28, 0.18, 2.5), 1.0, 0), (tone(150, 35, 0.32, "sine"), 1.2, 0),
                          (tone(95, 50, 0.18, "square"), 0.35, 0)), 0.95)
    save("block", mix((tone(1500, 1300, 0.08, "square", 3), 0.5, 0), (tone(2210, 2100, 0.07, "triangle", 3), 0.6, 0),
                      (noise(0.05, 1.0, 3), 0.4, 0)), 0.6)
    save("jump", tone(220, 560, 0.14, "square", 1.0, 0.25), 0.35)
    save("land", mix((noise(0.08, 0.1, 3), 1.0, 0), (tone(110, 60, 0.08, "sine"), 0.8, 0)), 0.45)
    save("ko", mix((noise(0.8, 0.1, 2), 0.9, 0), (tone(420, 40, 1.1, "saw", 1.2), 0.8, 0),
                   (tone(70, 30, 0.9, "sine"), 1.0, 0.1)), 0.95)
    # Um som de especial por elemento.
    t = times(0.6)
    crackle = noise(0.6, 1.0, 1.0) * (rng.uniform(0, 1, len(t)) > 0.97)
    save("special_fire", mix((noise(0.6, 0.12, 1.2, 0.12), 1.0, 0), (tone(120, 320, 0.45, "saw", 1.0), 0.3, 0), (crackle, 1.2, 0)))
    wobble = np.sin(2 * np.pi * np.cumsum(420 + 260 * np.sin(2 * np.pi * 11 * t) - 300 * t) / RATE) * decay(len(t), 1.2, 0.03)
    save("special_water", mix((wobble, 0.8, 0), (noise(0.5, 0.15, 1.0, 0.15), 0.6, 0)))
    save("special_plant", mix((arpeggio([67, 71, 74, 79, 83], 0.05, "triangle"), 1.0, 0), (noise(0.35, 0.4, 1.0, 0.2), 0.4, 0)))
    buzz = tone(90, 70, 0.5, "square", 0.8) * np.sign(np.sin(2 * np.pi * 43 * times(0.5)))
    save("special_electric", mix((buzz, 0.5, 0), (noise(0.5, 1.0, 1.5) * (rng.uniform(0, 1, int(RATE * 0.5)) > 0.7), 0.8, 0),
                                 (tone(2400, 300, 0.25, "saw"), 0.4, 0)))
    save("special_earth", mix((noise(0.7, 0.05, 1.3, 0.08), 1.2, 0), (tone(75, 40, 0.7, "triangle", 1.0), 1.0, 0)), 0.95)
    swirl = np.sin(2 * np.pi * np.cumsum(700 + 380 * np.sin(2 * np.pi * 5 * t)) / RATE) * decay(len(t), 1.0, 0.1)
    save("special_air", mix((noise(0.6, 0.3, 1.0, 0.2), 1.0, 0), (swirl, 0.25, 0)), 0.8)
    # Transformação: carga que sobe, estouro e acorde.
    charge = tone(60, 520, 0.9, "saw", 0.2) * (1 + 0.6 * np.sin(2 * np.pi * np.cumsum(np.linspace(8, 40, int(RATE * 0.9))) / RATE))
    save("transform", mix((charge, 0.6, 0), (noise(0.9, 0.1, 0.3, 0.5), 0.6, 0), (noise(0.7, 0.25, 2), 1.2, 0.9),
                          (tone(160, 30, 0.8, "sine", 1.5), 1.3, 0.9), (arpeggio([62, 69, 74, 81, 86], 0.05), 0.5, 0.95)), 0.95)
    # Finalização: anúncio grave, golpe final e acorde de encerramento.
    save("finish_call", mix(*[(tone(freq(n), freq(n), 0.9, "saw", 0.8), 0.4, 0) for n in (38, 45, 50, 51)],
                            (noise(1.0, 0.06, 1.0, 0.4), 0.7, 0)))
    save("finish_blow", mix((noise(1.2, 0.12, 2.0), 1.0, 0), (tone(130, 25, 1.2, "sine", 1.3), 1.3, 0),
                            (noise(0.2, 1.0, 3), 0.6, 0)), 0.98)
    save("finish_title", mix(*[(tone(freq(n), freq(n), 1.6, "square", 1.0, 0.25), 0.25, 0) for n in (50, 57, 62, 65)],
                             (arpeggio([62, 65, 69, 74], 0.1, "triangle"), 0.6, 0)), 0.8)
    save("victory", mix((arpeggio([67, 72, 76, 79], 0.11), 1.0, 0), (arpeggio([84], 0.4, length=0.7), 1.0, 0.46),
                        (tone(freq(48), freq(48), 1.1, "triangle", 0.8), 0.7, 0)), 0.7)

def roars():
    """Um rugido por criatura."""
    for name, start, end, grit, shape in (("fire", 190, 70, 0.2, "saw"), ("water", 300, 120, 0.1, "triangle"),
                                          ("plant", 130, 190, 0.07, "triangle"), ("electric", 900, 1500, 0.8, "square"),
                                          ("earth", 90, 45, 0.05, "saw"), ("air", 520, 980, 0.2, "sine")):
        n = int(RATE * 0.9)
        trill = 1 + 0.5 * np.sin(2 * np.pi * 27 * times(0.9))
        voice = tone(start, end, 0.9, shape, 0.7) * trill[:n]
        save(f"roar_{name}", mix((voice, 0.7, 0), (noise(0.9, grit, 0.8, 0.15), 0.6, 0)), 0.9)

def kart():
    """Sons da corrida. Os dois primeiros tocam em laço."""
    t = times(1.0)
    gallop = (tone(70, 70, 1.0, "saw", 0.0) * (0.55 + 0.45 * np.sign(np.sin(2 * np.pi * 14 * t)))
              + tone(105, 105, 1.0, "triangle", 0.0) * 0.6)
    save("kart_engine", gallop, 0.5)
    scrape = noise(1.0, 0.35, 0.0, 0.0) * (0.7 + 0.3 * np.sin(2 * np.pi * 31 * t))
    save("kart_drift", scrape, 0.35)
    save("kart_boost", mix((noise(0.8, 0.2, 1.0, 0.1), 1.0, 0), (tone(160, 880, 0.5, "saw", 0.8), 0.6, 0)), 0.8)
    save("kart_charge", arpeggio([79, 86], 0.04), 0.5)
    save("kart_bump", mix((noise(0.15, 0.1, 3), 1.0, 0), (tone(140, 50, 0.16, "sine"), 1.0, 0)), 0.8)
    save("count", tone(440, 440, 0.22, "square", 1.0, 0.25), 0.6)
    save("go", tone(880, 880, 0.6, "square", 1.0, 0.25), 0.7)
    save("lap", arpeggio([76, 79, 83, 88], 0.07), 0.6)

def drum(kind):
    if kind == "kick":
        return tone(140, 40, 0.13, "sine", 2)
    if kind == "snare":
        return mix((noise(0.12, 0.7, 2.5), 0.8, 0), (tone(190, 150, 0.07, "triangle", 2), 0.5, 0))
    return noise(0.03, 1.0, 3)

def song(name, bpm, root, scale, progression, melody, lead="square"):
    """Música em laço: 4 acordes, um compasso cada, em semicolcheias. Repete duas vezes com variação."""
    sixteenth = 60.0 / bpm / 4
    total = int(RATE * sixteenth * 16 * len(progression) * 2)
    out = np.zeros(total)

    def put(sig, volume, step):
        a = int(RATE * sixteenth * step)
        end = min(total, a + len(sig))
        out[a:end] += sig[:end - a] * volume

    def note(degree, octave=0):
        return freq(root + scale[degree % len(scale)] + 12 * (degree // len(scale) + octave))

    for rep in range(2):
        for bar, chord in enumerate(progression):
            start = (rep * len(progression) + bar) * 16
            for s in range(16):
                if s % 2 == 0:  # baixo pulsante
                    pitch = note(chord, -2) * (2 if s % 8 == 6 else 1)
                    put(tone(pitch, pitch, sixteenth * 1.8, "triangle", 0.8), 0.55, start + s)
                    put(drum("hat"), 0.12, start + s)
                if s in (0, 8, 10):
                    put(drum("kick"), 0.6, start + s)
                if s in (4, 12):
                    put(drum("snare"), 0.35, start + s)
                arp = note(chord + (0, 2, 4, 2)[s % 4])
                put(tone(arp, arp, sixteenth * 0.9, "square", 1.0, 0.125), 0.10, start + s)
            # melodia: (passo, duração em semicolcheias, grau relativo ao acorde)
            for step, length, degree in melody[(bar + rep) % len(melody)]:
                pitch = note(chord + degree, rep if bar == len(progression) - 1 else 0)
                put(tone(pitch, pitch, sixteenth * length, lead, 0.7, 0.25), 0.26, start + step)
    save(name, out, 0.6)

def music():
    minor = [0, 2, 3, 5, 7, 8, 10]
    phrygian = [0, 1, 3, 5, 7, 8, 10]
    dorian = [0, 2, 3, 5, 7, 9, 10]
    major = [0, 2, 4, 5, 7, 9, 11]
    m1 = [[(0, 3, 4), (3, 3, 2), (6, 2, 4), (8, 6, 7), (14, 2, 4)], [(0, 2, 7), (2, 2, 6), (4, 4, 4), (8, 4, 2), (12, 4, 0)]]
    m2 = [[(0, 6, 0), (6, 2, 2), (8, 8, 4)], [(0, 4, 4), (4, 4, 5), (8, 2, 4), (10, 6, 2)]]
    m3 = [[(0, 2, 0), (2, 2, 4), (4, 2, 7), (6, 2, 4), (10, 2, 9), (12, 4, 7)], [(0, 3, 4), (4, 3, 2), (8, 3, 4), (12, 4, 0)]]
    song("music_menu", 104, 57, minor, [0, 5, 3, 4], m2, "triangle")
    song("music_fire", 150, 52, phrygian, [0, 1, 0, 6], m1)
    song("music_water", 118, 55, dorian, [0, 3, 0, 6], m2, "triangle")
    song("music_plant", 128, 60, major, [0, 5, 3, 4], m3, "triangle")
    song("music_electric", 164, 54, minor, [0, 5, 6, 4], m3)
    song("music_earth", 108, 48, phrygian, [0, 0, 5, 6], m1, "saw")
    song("music_air", 140, 62, dorian, [0, 3, 4, 3], m3, "triangle")

if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    effects()
    roars()
    kart()
    music()
