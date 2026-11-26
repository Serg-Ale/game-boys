# Desenho do título, da seleção e da tela de VS, cada um com a cara dos elementos escolhidos.
extends RefCounted

const Data = preload("res://scripts/data.gd")
const Menu = preload("res://scripts/menu.gd")
const Look = preload("res://scripts/theme.gd")
const Supers = preload("res://scripts/supers.gd")
const Controls = preload("res://scripts/controls.gd")
const COMMANDS := {"neutral": "", "forward": "→ ", "down": "↓ "}

static func idle(time: int) -> String:
	return "idle_%d" % (time / 10 % 4)

static func sheet(i: int, picks: Array) -> String:
	return picks[i] + "_alt" if i == 1 and picks[0] == picks[1] else picks[i]

static func _slant(canvas: CanvasItem, x: float, y: float, width: float, height: float, color: Color, lean := 18.0) -> void:
	canvas.draw_colored_polygon(PackedVector2Array([Vector2(x + lean, y), Vector2(x + width + lean, y), Vector2(x + width - lean, y + height), Vector2(x - lean, y + height)]), color)

static func title(canvas: CanvasItem, sprites, menu, time: int) -> void:
	# O título passa pelos cinco elementos.
	var key: String = Data.ROSTER[time / 240 % Data.ROSTER.size()]
	var info: Dictionary = Data.FIGHTERS[key]
	var theme: Dictionary = Look.THEMES[info.clan]
	canvas.draw_texture_rect(sprites.stages[info.clan], Rect2(0, 0, 960, 540), false)
	canvas.draw_rect(Rect2(0, 0, 960, 540), Color(theme.dark, 0.35))
	_slant(canvas, -40, 0, 500, 540, Color(theme.dark, 0.88), 70)
	Look.particles(canvas, info.clan, time, Rect2(0, 0, 960, 540), 45)
	canvas.draw_rect(Rect2(0, 36, 960, 120), Color(0, 0, 0, 0.55))
	canvas.draw_rect(Rect2(0, 156, 960, 5), theme.accent)
	Look.text(canvas, "ELEMENTAL", 480, 92, 56, Color.WHITE, theme.mid)
	Look.text(canvas, "FIGHTERS", 480, 146, 62, theme.accent, theme.dark)
	Look.text(canvas, "O TORNEIO DOS SEIS CLÃS", 480, 185, 20)
	for i in Menu.OPTIONS.size():
		var chosen: bool = i == menu.option
		var y := 208.0 + i * 56
		var push := 24.0 if chosen else 0.0
		_slant(canvas, 60 + push, y, 340, 46, theme.accent if chosen else Color(0, 0, 0, 0.6))
		Look.text(canvas, Menu.OPTIONS[i].to_upper(), 230 + push, y + 31, 22, theme.dark if chosen else Color(0.8, 0.8, 0.85), Color.WHITE if chosen else Color.BLACK)
	sprites.draw(canvas, key, idle(time), Vector2(700, 480), -1, 6.0)
	Look.text(canvas, "%s  •  %s" % [info.name.to_upper(), Data.CLAN_NAMES[info.clan].to_upper()], 700, 515, 22, theme.accent)
	Look.text(canvas, "Direcional / WASD escolhe    A / J / Enter confirma", 230, 522, 15, Color.WHITE, Color.BLACK, false)

static func select(canvas: CanvasItem, sprites, menu, time: int) -> void:
	var rival := "CPU" if menu.versus_cpu else "JOGADOR 2"
	var focus: String = Data.ROSTER[menu.cursor]
	var info: Dictionary = Data.FIGHTERS[focus]
	var theme: Dictionary = Look.THEMES[info.clan]
	# Metade esquerda com o clã do jogador 1; direita com o do adversário.
	for i in 2:
		var clan: String = Data.FIGHTERS[menu.picks[i]].clan
		var half := Rect2(i * 480, 0, 480, 540)
		canvas.draw_rect(half, Look.THEMES[clan].dark)
		for band in 6:
			_slant(canvas, i * 480 + band * 90 - fmod(time * 0.6, 90.0), 0, 36, 540, Color(Look.THEMES[clan].mid, 0.35), 60)
		Look.particles(canvas, clan, time, half, 22, 0.7)
	for i in 2:
		if menu.racing and i == 1: # do outro lado, a montaria
			canvas.draw_texture_rect_region(sprites.riders[menu.picks[0]], Rect2(822 - 144, 345 - 204, 288, 216), Rect2(96, 72 * (time / 14 % 2), 96, 72))
			Look.text(canvas, "MONTARIA: %s" % Data.CREATURES[menu.picks[0]].to_upper(), 822, 366, 17, Look.THEMES[Data.FIGHTERS[menu.picks[0]].clan].accent)
			continue
		var waiting: bool = i == 1 and menu.side == 0
		var x := 138.0 if i == 0 else 822.0
		var key: String = menu.picks[i]
		sprites.draw(canvas, sheet(i, menu.picks), idle(time), Vector2(x, 345), 1 if i == 0 else -1, 4.6, Color(0.15, 0.15, 0.18) if waiting else Color.WHITE)
		Look.text(canvas, "VOCÊ" if i == 0 else rival, x, 366, 18, Look.THEMES[Data.FIGHTERS[key].clan].accent)

	Look.text(canvas, "ESCOLHA SEU CORREDOR" if menu.racing else ("ESCOLHA SEU NINJA" if menu.side == 0 else "ESCOLHA O ADVERSÁRIO"), 480, 34, 27, Color.WHITE, theme.mid)
	var panel := Rect2(272, 46, 416, 330)
	canvas.draw_rect(panel, Color(0, 0, 0, 0.76))
	canvas.draw_rect(panel, theme.accent, false, 3)
	Look.text(canvas, info.name.to_upper(), 480, 86, 38, theme.accent, theme.dark)
	Look.text(canvas, "%s  •  %s" % [info.title, Data.CLAN_NAMES[info.clan]], 480, 107, 14, Color.WHITE, Color.BLACK, false)
	var strong: Array = Data.BEATS[info.clan].map(func(k): return Data.ELEMENT_NAMES[k])
	Look.text(canvas, "%s  •  vantagem sobre %s" % [Data.ELEMENT_NAMES[info.clan], " e ".join(PackedStringArray(strong))], 480, 127, 13, theme.accent, Color.BLACK, false)
	Look.text(canvas, info.style, 480, 148, 13, Color(0.85, 0.85, 0.9), Color.BLACK, false)
	var stats := [["VIDA", info.health / 1200.0], ["VELOCIDADE", info.walk / 5.6], ["FORÇA", info.power / 1.2]]
	for n in stats.size():
		var y := 160.0 + n * 18
		canvas.draw_string(Look.font(), Vector2(302, y + 10), stats[n][0], HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
		for block in 10:
			_slant(canvas, 435 + block * 22, y, 18, 10, theme.accent if block < roundi(stats[n][1] * 10) else Color(1, 1, 1, 0.15), 3)
	Look.text(canvas, info.passive_text, 480, 228, 13, Color(1, 0.92, 0.55), Color.BLACK, false)
	var y := 254.0
	var button: String = Controls.name_of("special", 0 if menu.versus_cpu else menu.side)
	for key in info.specials:
		_slant(canvas, 300, y - 14, 48, 18, theme.mid, 5)
		canvas.draw_string(Look.font(), Vector2(304, y), COMMANDS[key] + button, HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
		canvas.draw_string(ThemeDB.fallback_font, Vector2(386, y), info.specials[key].name, HORIZONTAL_ALIGNMENT_LEFT, -1, 15)
		y += 23
	_slant(canvas, 300, y - 14, 70, 19, theme.accent, 5)
	canvas.draw_string(Look.font(), Vector2(302, y + 1), "← ↓ → " + button, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, theme.dark)
	canvas.draw_string(Look.font(), Vector2(386, y + 1), "%s (%s)" % [Supers.SUPERS[focus].name.to_upper(), Data.CREATURES[focus]], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, theme.accent)
	Look.text(canvas, "\"%s\"" % info.intro, 480, 364, 13, Color(0.8, 0.8, 0.86), Color.BLACK, false)

	# Grade: uma coluna por clã, dois ninjas em cada.
	for i in Data.ROSTER.size():
		var key: String = Data.ROSTER[i]
		var clan: String = Data.FIGHTERS[key].clan
		var chosen: bool = i == menu.cursor
		var columns := Data.ELEMENTS.size()
		var x := 84.0 + (i % columns) * 134
		var top := 383.0 + (i / columns) * 68
		_slant(canvas, x, top, 118, 63, Look.THEMES[clan].mid if chosen else Color(0, 0, 0, 0.75), 7)
		if chosen:
			canvas.draw_rect(Rect2(x - 7, top + 60, 118, 4), Look.THEMES[clan].accent)
		sprites.draw(canvas, key, idle(time) if chosen else "idle_0", Vector2(x + 32, top + 62), 1, 1.0)
		canvas.draw_string(Look.font(), Vector2(x + 54, top + 37), Data.FIGHTERS[key].name, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE if chosen else Color(0.75, 0.75, 0.8))
	Look.text(canvas, "Controle: A confirma, B volta   •   Teclado: J confirma, K volta   •   na luta, Start / Enter mostra os golpes", 480, 533, 13, Color.WHITE, Color.BLACK, false)

# Quem joga com o teclado e quem joga com o controle.
static func controls(canvas: CanvasItem, sprites, menu, time: int) -> void:
	canvas.draw_rect(Rect2(0, 0, 960, 540), Color(0.05, 0.05, 0.1))
	Look.particles(canvas, "air", time, Rect2(0, 0, 960, 540), 26, 0.35)
	Look.text(canvas, "CONTROLES", 480, 52, 40, Color(1, 0.85, 0.35))
	var pads := Input.get_connected_joypads()
	var found := "nenhum controle ligado"
	if not pads.is_empty():
		found = "Controle ligado: " + ", ".join(PackedStringArray(pads.map(func(p): return Input.get_joy_name(p))))
	Look.text(canvas, found, 480, 80, 14, Color(0.7, 0.9, 1.0), Color.BLACK, false)
	for i in 2:
		var chosen: bool = menu.row == i
		var top := 100.0 + i * 82
		_slant(canvas, 130, top, 700, 68, Color(0.2, 0.2, 0.34) if chosen else Color(0, 0, 0, 0.6), 12)
		if chosen:
			canvas.draw_rect(Rect2(124, top + 65, 700, 4), Color(1, 0.85, 0.35))
		Look.text(canvas, "JOGADOR %d" % (i + 1), 240, top + 42, 24, Color.WHITE)
		Look.text(canvas, "◀  %s  ▶" % Controls.CHOICE_NAMES[Controls.choices[i]], 480, top + 34, 24, Color(1, 0.85, 0.35) if chosen else Color(0.8, 0.8, 0.85))
		Look.text(canvas, "usando: " + Controls.describe(i), 480, top + 56, 14, Color(0.55, 1, 0.65), Color.BLACK, false)
		if Controls.choices[i] == "pad" and not Controls.uses_pad(i):
			Look.text(canvas, "sem controle livre", 720, top + 42, 14, Color(1, 0.45, 0.35))
	var columns := [["AÇÃO", ""], ["CONTROLE", "pad"], ["TECLADO", "main"], ["2º NO TECLADO", "arrows"]]
	var rows := [["andar / abaixar", "direcional", "A D / S", "setas"], ["pular", "jump"], ["soco", "punch"], ["chute", "kick"],
		["especial", "special"], ["agarrão", "grab"], ["dash", "dash"], ["transformar", "transform"]]
	for n in columns.size():
		canvas.draw_string(Look.font(), Vector2(190 + n * 170, 292), columns[n][0], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1, 0.85, 0.35))
	for r in rows.size():
		var y := 316.0 + r * 21
		var values: Array = rows[r]
		if rows[r].size() == 2:
			var action: String = rows[r][1]
			values = [rows[r][0], Controls.PAD_NAMES[action], Controls.KEY_NAMES.main[action], Controls.KEY_NAMES.arrows[action]]
		for n in values.size():
			canvas.draw_string(ThemeDB.fallback_font, Vector2(190 + n * 170, y), values[n], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE if n == 0 else Color(0.8, 0.85, 0.95))
	Look.text(canvas, "↑ ↓ escolhe o jogador    ← → troca o aparelho    confirmar ou voltar: salva", 480, 512, 15)
	Look.text(canvas, "Automático: o controle é do jogador 1 e o teclado do jogador 2. Contra a CPU, os dois valem.", 480, 534, 12, Color(0.75, 0.75, 0.8), Color.BLACK, false)

static func versus(canvas: CanvasItem, sprites, picks: Array, time: int, age: int) -> void:
	var slide := maxf(0.0, 1.0 - age / 18.0) * 500
	for i in 2:
		var info: Dictionary = Data.FIGHTERS[picks[i]]
		var theme: Dictionary = Look.THEMES[info.clan]
		var side := -1.0 if i == 0 else 1.0
		var points := PackedVector2Array([Vector2(0, 0), Vector2(540, 0), Vector2(420, 540), Vector2(0, 540)])
		if i == 1:
			points = PackedVector2Array([Vector2(540, 0), Vector2(960, 0), Vector2(960, 540), Vector2(420, 540)])
		for n in points.size():
			points[n].x += side * slide
		canvas.draw_colored_polygon(points, theme.mid)
		var x := 480 + side * (260 + slide)
		Look.particles(canvas, info.clan, time, Rect2(i * 480, 0, 480, 540), 30)
		sprites.draw(canvas, sheet(i, picks), idle(time), Vector2(x, 405), 1 if i == 0 else -1, 6.2)
		Look.text(canvas, info.name.to_upper(), x, 452, 44, theme.accent, theme.dark)
		Look.text(canvas, info.title, x, 478, 18)
		Look.text(canvas, "\"%s\"" % info.intro, x, 510, 16, Color.WHITE, Color.BLACK, false)
	canvas.draw_line(Vector2(540, 0), Vector2(420, 540), Color.WHITE, 6)
	if age > 14:
		Look.text(canvas, "VS", 480, 270, 96, Color.WHITE, Color.BLACK)
	if Data.FIGHTERS[picks[0]].clan == Data.FIGHTERS[picks[1]].clan and picks[0] != picks[1]:
		Look.text(canvas, "DUELO INTERNO • %s" % Data.CLAN_NAMES[Data.FIGHTERS[picks[0]].clan].to_upper(), 480, 40, 26)
