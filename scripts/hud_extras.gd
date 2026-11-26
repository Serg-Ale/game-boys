# Interface da luta: contador de combo, anúncio de round e pausa com a lista de golpes.
extends RefCounted

const Data = preload("res://scripts/data.gd")
const Fight = preload("res://scripts/fight.gd")
const Supers = preload("res://scripts/supers.gd")
const Look = preload("res://scripts/theme.gd")
const Controls = preload("res://scripts/controls.gd")

const COMBO_SHOW := 70
const INTRO := 90

static func combo(canvas: CanvasItem, fight) -> void:
	for i in 2:
		var entry: Dictionary = fight.combo[i]
		if entry.hits < 2 or entry.age >= COMBO_SHOW:
			continue
		var accent: Color = Look.THEMES[fight.fighters[i].element].accent
		var x := 130.0 if i == 0 else 830.0
		var pop := maxi(0, 8 - entry.age) * 3
		var praise := "BOM!" if entry.hits < 4 else ("FEROZ!" if entry.hits < 6 else "LENDÁRIO!")
		Look.text(canvas, "%d HITS" % entry.hits, x, 160, 44 + pop, accent)
		Look.text(canvas, "%d de dano" % entry.damage, x, 188, 20)
		Look.text(canvas, praise, x, 214, 22, Color.WHITE)

static func intro(canvas: CanvasItem, fight) -> void:
	var age: int = Fight.ROUND_FRAMES - fight.timer
	if age >= INTRO or fight.message != "":
		return
	var number: int = fight.wins[0] + fight.wins[1] + 1
	if age < 55:
		Look.text(canvas, "ROUND %d" % number, 480, 230, 64 + maxi(0, 12 - age) * 4, Color(1, 0.85, 0.35))
	else:
		Look.text(canvas, "LUTE!", 480, 235, 84, Color(1, 0.4, 0.25))

static func pause(canvas: CanvasItem, fight) -> void:
	canvas.draw_rect(Rect2(-20, -20, 1000, 580), Color(0, 0, 0, 0.88))
	Look.text(canvas, "PAUSA", 480, 52, 40, Color(1, 0.85, 0.35))
	for i in 2:
		var f = fight.fighters[i]
		var theme: Dictionary = Look.THEMES[f.element]
		var x := 40.0 if i == 0 else 500.0
		_line(canvas, x, 100, f.stats.name.to_upper(), 28, theme.accent)
		_line(canvas, x, 122, f.stats.passive_text, 13, Color(0.9, 0.9, 0.9))
		var y := 156.0
		var button: String = Controls.name_of("special", i)
		for entry in [[button, "neutral"], ["→ + " + button, "forward"], ["↓ + " + button, "down"]]:
			_line(canvas, x, y, entry[0], 16, theme.accent)
			_line(canvas, x + 90, y, f.stats.specials[entry[1]].name, 16, Color.WHITE)
			y += 26
		_line(canvas, x, y, "← ↓ → + " + button, 14, theme.accent)
		_line(canvas, x + 90, y, "%s (%s)" % [Supers.SUPERS[f.id].name, Data.CREATURES[f.id]], 16, theme.accent)
	# Os comandos de combate aparecem com os botões de cada jogador.
	var rows := [
		["{punch}, {punch}, {punch}", "sequência de socos"], ["{punch}, depois {kick}", "soco emendado no chute"],
		["golpe + {special}", "cancela em especial, se tocou"], ["→ + {kick}", "lançador (pule em seguida para ir atrás)"],
		["↓ + {kick}", "rasteira: derruba"], ["{grab}  ou  {punch} + {kick}", "agarrão (aperte na hora para escapar)"],
		["{dash}  ou  → →", "dash  (para trás: recua)"], ["←  (e ↓ ←)", "defender em pé e agachado"],
		["{transform}", "transformar (depois de vencer um round)"],
	]
	_line(canvas, 40, 310, "COMBATE", 20, Color(1, 0.85, 0.35))
	for i in 2:
		var names := {}
		for action in Controls.PAD_NAMES:
			names[action] = Controls.name_of(action, i)
		var x := 40.0 + i * 230
		_line(canvas, x, 330, "J%d: %s" % [i + 1, Controls.describe(i)], 12, Color(0.75, 0.75, 0.8))
		for n in rows.size():
			_line(canvas, x, 352 + n * 18, rows[n][0].format(names), 14, Color(0.45, 1, 0.55))
	for n in rows.size():
		_line(canvas, 520, 352 + n * 18, rows[n][1], 14, Color.WHITE)
	Look.text(canvas, "Start / Enter: voltar à luta     Select / Esc: trocar lutadores", 480, 522, 18)

static func _line(canvas: CanvasItem, x: float, y: float, value: String, size: int, color: Color) -> void:
	canvas.draw_string(ThemeDB.fallback_font, Vector2(x, y), value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
