# Liga os comandos ao menu e à luta, e desenha as telas.
extends Node2D

const Data = preload("res://scripts/data.gd")
const Fight = preload("res://scripts/fight.gd")
const Fighter = preload("res://scripts/fighter.gd")
const Controls = preload("res://scripts/controls.gd")
const Cpu = preload("res://scripts/cpu.gd")
const Menu = preload("res://scripts/menu.gd")
const Sprites = preload("res://scripts/sprites.gd")
const Look = preload("res://scripts/theme.gd")
const Screens = preload("res://scripts/screens.gd")
const Finisher = preload("res://scripts/finisher.gd")
const Audio = preload("res://scripts/audio.gd")
const Supers = preload("res://scripts/supers.gd")
const SuperView = preload("res://scripts/super_view.gd")
const Extras = preload("res://scripts/hud_extras.gd")
const FormView = preload("res://scripts/form_view.gd")

# Tecla -> [ação do menu, teclado de onde vem ("" = qualquer)]
const MENU_KEYS := {
	KEY_A: ["left", "main"], KEY_D: ["right", "main"], KEY_W: ["up", "main"], KEY_S: ["down", "main"],
	KEY_J: ["confirm", "main"], KEY_SPACE: ["confirm", "main"], KEY_K: ["back", "main"],
	KEY_LEFT: ["left", "arrows"], KEY_RIGHT: ["right", "arrows"], KEY_UP: ["up", "arrows"], KEY_DOWN: ["down", "arrows"],
	KEY_COMMA: ["confirm", "arrows"], KEY_KP_1: ["confirm", "arrows"], KEY_PERIOD: ["back", "arrows"], KEY_KP_2: ["back", "arrows"],
	KEY_ENTER: ["confirm", ""], KEY_ESCAPE: ["back", ""],
}
const MENU_BUTTONS := {
	JOY_BUTTON_DPAD_LEFT: "left", JOY_BUTTON_DPAD_RIGHT: "right",
	JOY_BUTTON_DPAD_UP: "up", JOY_BUTTON_DPAD_DOWN: "down",
	JOY_BUTTON_A: "confirm", JOY_BUTTON_START: "confirm", JOY_BUTTON_B: "back",
}

var sprites = Sprites.new()
var menu = Menu.new()
var cpu = Cpu.new()
var fight = null # null enquanto o menu está aberto
var show_boxes := false
var time := 0
var my_input := {} # o que o jogador 1 está apertando
var feedback := "" # resultado do último pedido de especial
const IMPACT_FRAMES := 30
var impacts: Array = []
var shake := 0
const VERSUS_FRAMES := 180
var versus_age := VERSUS_FRAMES # menor que o total enquanto a tela de VS aparece
var finisher_age := 0
var audio = Audio.new()
var paused := false
var ghost := [0.0, 0.0] # rastro da vida perdida na barra
var stick := {} # última direção do analógico de cada controle, no menu

func _ready() -> void:
	Controls.load_choices()
	_refresh_devices()
	add_child(audio)
	audio.play_music("menu")

func _physics_process(_delta: float) -> void:
	time += 1
	_refresh_devices()
	if fight != null and versus_age < VERSUS_FRAMES:
		versus_age += 1
		if versus_age == VERSUS_FRAMES:
			audio.play_music(Data.FIGHTERS[fight.ids[1]].clan)
			_ignore_held_buttons()
	elif fight != null and not paused:
		var second: Dictionary = cpu.read(fight, 1) if menu.versus_cpu else Controls.read(1)
		var first: Dictionary = Controls.read(0)
		var asked: bool = first.special and not my_input.get("special", false)
		my_input = first
		fight.step([first, second])
		audio.watch(fight)
		if asked:
			feedback = _explain_special(first)
		if not fight.finisher.is_empty():
			finisher_age += 1
			audio.finisher(fight.finisher.element, finisher_age)
			if Finisher.shakes(fight.finisher.id, finisher_age):
				shake = 14
	if not paused:
		_update_impacts()
		_update_ghost()
	queue_redraw()

# Diz o que aconteceu quando o jogador 1 apertou o botão de especial.
func _explain_special(input: Dictionary) -> String:
	var me = fight.fighters[0]
	var forward: bool = input.right if me.facing > 0 else input.left
	var key := "down" if input.down else ("forward" if forward else "neutral")
	var button: String = Controls.name_of("special", 0)
	var command: String = {"neutral": button, "forward": "frente + " + button, "down": "baixo + " + button}[key]
	if not me.stats.specials.has(key):
		command += " (%s ainda só tem o golpe principal)" % me.stats.name
		key = "neutral"
	var name: String = me.stats.specials[key].name
	if me.state == Fighter.State.SUPER:
		return "meia-lua + %s: %s" % [button, Supers.SUPERS[me.id].name]
	if me.state == Fighter.State.SPECIAL and me.slot == key and me.frame <= 1:
		return "%s: %s" % [command, name]
	if me.cooldowns[key] > 0:
		return "%s: %s em recarga (%.1f s)" % [command, name, me.cooldowns[key] / 60.0]
	return "%s: não saiu, o lutador estava ocupado ou no ar" % command

func _start_fight() -> void:
	paused = false
	ghost = [0.0, 0.0]
	feedback = ""
	my_input = {}
	impacts = []
	versus_age = 0
	finisher_age = 0
	audio.reset_fight()
	audio.play_music("")
	audio.play("versus")
	fight = Fight.new(menu.picks[0], menu.picks[1])
	cpu = Cpu.new()
func _refresh_devices() -> void:
	Controls.refresh(menu.versus_cpu and menu.screen != "controls")

# De qual jogador veio um comando de menu. Contra a CPU, tudo é do jogador 1.
func _key_owner(layout: String) -> int:
	if menu.versus_cpu:
		return 0
	for i in 2:
		if Controls.devices[i].layout == layout:
			return i
	# Sem dono para as setas, elas navegam como quem tem o teclado principal.
	for i in 2:
		if Controls.devices[i].layout != "":
			return i
	return 0

func _pad_owner(pad: int) -> int:
	if menu.versus_cpu:
		return 0
	return 1 if Controls.devices[1].pad == pad else 0

# O botão que confirmou a tela anterior não deve virar um golpe no primeiro frame.
func _ignore_held_buttons() -> void:
	for i in 2:
		fight.fighters[i].input = Controls.read(i)

# A barra vermelha desce devagar até a vida atual.
func _update_ghost() -> void:
	if fight == null:
		return
	for i in 2:
		var health: float = fight.fighters[i].health
		var recent: bool = fight.combo[1 - i].age < 30
		if ghost[i] < health:
			ghost[i] = health
		elif not recent:
			ghost[i] = maxf(health, ghost[i] - 5.0)

# Start ou Enter pausam a luta em andamento.
func _toggle_pause(event: InputEvent) -> bool:
	var asked: bool = (event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ENTER) \
		or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_START)
	if not asked or fight == null or versus_age < VERSUS_FRAMES or fight.match_over:
		return false
	paused = not paused
	if not paused:
		_ignore_held_buttons()
	audio.play("confirm")
	return true

func _unhandled_input(event: InputEvent) -> void:
	if _toggle_pause(event):
		return
	var action := ""
	var player := 0
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_M:
			audio.toggle_music()
		elif event.physical_keycode == KEY_F2 and fight != null:
			# Atalho de teste: enche a barra de supremo do jogador 1.
			fight.fighters[0].energy = Fighter.MAX_ENERGY
			fight.energy[0] = Fighter.MAX_ENERGY
		elif event.physical_keycode == KEY_F3 and fight != null:
			# Atalho de teste: libera a transformação do jogador 1.
			fight.fighters[0].can_transform = true
		elif event.physical_keycode == KEY_F1:
			show_boxes = not show_boxes
		elif MENU_KEYS.has(event.physical_keycode):
			action = MENU_KEYS[event.physical_keycode][0]
			player = _key_owner(MENU_KEYS[event.physical_keycode][1])
			# Na luta, só Enter e Esc comandam; as outras teclas são golpes.
			if fight != null and MENU_KEYS[event.physical_keycode][1] != "" and not (action == "confirm" and versus_age < VERSUS_FRAMES):
				action = ""
	elif event is InputEventJoypadButton and event.pressed:
		player = _pad_owner(event.device)
		if fight != null:
			if event.button_index == JOY_BUTTON_BACK:
				action = "back"
			elif event.button_index == JOY_BUTTON_START or (event.button_index == JOY_BUTTON_A and versus_age < VERSUS_FRAMES):
				action = "confirm"
		else:
			action = MENU_BUTTONS.get(event.button_index, "")
	elif event is InputEventJoypadMotion and fight == null:
		action = _stick_action(event)
		player = _pad_owner(event.device)
	if action == "":
		return
	if fight != null:
		if action == "back":
			paused = false
			fight = null
			menu.open_select()
			audio.play("back")
			audio.play_music("menu")
		elif action == "confirm" and versus_age < VERSUS_FRAMES:
			versus_age = VERSUS_FRAMES - 1 # pula a tela de VS
		elif action == "confirm" and fight.match_over and (fight.finisher.is_empty() or finisher_age > Finisher.LOCK):
			_start_fight()
		return
	var before := [menu.screen, menu.option, menu.cursor, menu.side, menu.row, Controls.choices.duplicate()]
	var result: String = menu.handle(action, player)
	if result != "fight" and before != [menu.screen, menu.option, menu.cursor, menu.side, menu.row, Controls.choices]:
		audio.play({"confirm": "confirm", "back": "back"}.get(action, "move"))
	match result:
		"saved":
			Controls.save_choices()
		"fight":
			_start_fight()
		"quit":
			get_tree().quit()

# Transforma o analógico em um único passo por movimento.
func _stick_action(event: InputEventJoypadMotion) -> String:
	if event.axis != JOY_AXIS_LEFT_X and event.axis != JOY_AXIS_LEFT_Y:
		return ""
	var key := "%d:%d" % [event.device, event.axis]
	var direction := 0
	if absf(event.axis_value) > 0.6:
		direction = int(signf(event.axis_value))
	if direction == stick.get(key, 0):
		return ""
	stick[key] = direction
	if direction == 0:
		return ""
	if event.axis == JOY_AXIS_LEFT_X:
		return "right" if direction > 0 else "left"
	return "down" if direction > 0 else "up"

func _draw() -> void:
	if fight == null:
		if menu.screen == "title":
			Screens.title(self, sprites, menu, time)
		elif menu.screen == "controls":
			Screens.controls(self, sprites, menu, time)
		else:
			Screens.select(self, sprites, menu, time)
	elif versus_age < VERSUS_FRAMES:
		Screens.versus(self, sprites, fight.ids, time, versus_age)
	else:
		_draw_fight()

func _draw_fight() -> void:
	# A luta acontece no cenário do adversário.
	var home: String = Data.FIGHTERS[fight.ids[1]].clan
	var finishing: bool = not fight.finisher.is_empty()
	draw_texture_rect(sprites.stages[home], Rect2(-12, -9, 984, 558), false)
	Look.particles(self, home, time, Rect2(0, 100, 960, 350), 22, 0.55)
	if finishing:
		Finisher.background(self, fight.finisher.element, finisher_age)
	for i in 2:
		var f = fight.fighters[i]
		var tag: String = ("VOCÊ" if i == 0 else "CPU") if menu.versus_cpu else "J%d" % (i + 1)
		if (finishing and i != fight.finisher.winner) or f.underground():
			continue
		var won: bool = fight.message != "" and f.health > fight.fighters[1 - i].health
		var tint := Color.WHITE
		if f.state == Fighter.State.HITSTUN and fight.hitstop > 0:
			tint = Color(2.5, 2.5, 2.5)
		elif f.burn > 0 and time / 4 % 2 == 0:
			tint = Color(1.5, 0.8, 0.5)
		draw_rect(Rect2(f.pos.x - 36, Fighter.FLOOR_Y - 3, 72, 7), Color(0, 0, 0, 0.35)) # sombra
		if f.transformed and f.state != Fighter.State.KO:
			FormView.aura(self, f.element, f.pos.round(), time)
		sprites.draw(self, _sheet(i), Sprites.frame_for(f, time, won), f.pos.round(), f.facing, FormView.SCALE if f.transformed else Sprites.SCALE, tint)
		if f.slow > 0:
			for n in 5:
				draw_rect(Rect2(f.pos.x - 34 + n * 15, f.pos.y - 20 - (time + n * 13) % 90, 6, 6), Color(0.75, 0.93, 1.0, 0.8))
		if f.root > 0:
			for n in 3:
				draw_rect(Rect2(f.pos.x - 33, f.pos.y - 12 - n * 12, 66, 4), Color(0.3, 0.7, 0.25))
		if show_boxes:
			draw_rect(f.hurtbox(), Color.GREEN, false, 2)
			var box: Rect2 = f.hitbox()
			if box.has_area():
				draw_rect(box, Color.RED, false, 2)
		if not finishing:
			_text(tag, f.pos.x, f.pos.y - 172, 16, Color(0.4, 1, 0.5) if i == 0 else Color.WHITE)
	if finishing:
		var down: int = 1 - fight.finisher.winner
		var victim = fight.fighters[down]
		Finisher.loser(self, sprites, fight.finisher.id, _sheet(down), victim.pos, victim.facing, finisher_age)
		Finisher.banner(self, fight.finisher.id, finisher_age)
	else:
		for i in 2:
			_draw_special_effect(fight.fighters[i], _sheet(i))
		if not fight.cast.is_empty() and fight.freeze == 0:
			SuperView.effect(self, sprites, fight.cast, time)
			# Os lutadores continuam visíveis sobre o efeito escurecido.
			for i in 2:
				var f = fight.fighters[i]
				if f.underground():
					continue
				sprites.draw(self, _sheet(i), Sprites.frame_for(f, time, false), f.pos.round(), f.facing, FormView.SCALE if f.transformed else Sprites.SCALE, Color(1, 1, 1, 0.9))
	for p in fight.projectiles:
		_draw_projectile(p)
		if show_boxes:
			draw_rect(fight.projectile_box(p), Color.RED, false, 2)
	_draw_impacts()
	for i in 2:
		_draw_hud(i)
		_draw_energy(i)
	draw_rect(Rect2(448, 18, 64, 44), Color(0, 0, 0, 0.75))
	Look.text(self, str(ceili(fight.timer / 60.0)), 480, 51, 32, Look.THEMES[home].accent)
	if show_boxes:
		_draw_input_help()
	var ready: bool = not finishing or finisher_age > Finisher.LOCK
	if fight.match_over and not finishing:
		var winner: int = 0 if fight.fighters[0].health > fight.fighters[1].health else 1
		_text("\"%s\"" % Data.FIGHTERS[fight.ids[winner]].win, 480, 262, 20, Look.THEMES[fight.fighters[winner].element].accent)
	if not finishing:
		Look.text(self, fight.message, 480, 190, 38, Color(1, 0.85, 0.35))
	if fight.match_over and ready:
		_text("Start / Enter: revanche    Select / Esc: trocar lutadores", 480, 256 if finishing else 230, 20)
	if fight.freeze > 0:
		SuperView.cinematic(self, sprites, fight.cast, _sheet(fight.cast.owner), fight.freeze, time)
	if not fight.transforming.is_empty():
		var who: int = fight.transforming.owner
		FormView.cinematic(self, sprites, fight.fighters[who], Screens.sheet(who, fight.ids), fight.transforming.age, time)
	if not finishing and fight.freeze == 0:
		Extras.combo(self, fight)
		Extras.intro(self, fight)
	if paused:
		Extras.pause(self, fight)
		return
	_text("%s    Start / Enter: golpes    Select / Esc: voltar    M: música" % ("Contra a CPU" if menu.versus_cpu else "Dois jogadores"), 480, 528, 13)

# Folha de sprites atual: a transformação troca o visual.
func _sheet(i: int) -> String:
	return fight.ids[i] + "_form" if fight.fighters[i].transformed else Screens.sheet(i, fight.ids)

# Aparece com F1: o que o controle está enviando e o resultado do último especial.
func _draw_input_help() -> void:
	var arrows := {"left": "←", "right": "→", "down": "↓"}
	for action in Controls.PAD_NAMES:
		arrows[action] = Controls.name_of(action, 0)
	var pressed := ""
	for action in arrows:
		if my_input.get(action, false):
			pressed += arrows[action] + "  "
	_text("Seu comando:  %s" % pressed, 480, 440, 18, Color(0.4, 1, 0.5))
	_text(feedback, 480, 464, 16)

# Cada projétil tem o próprio desenho.
func _draw_projectile(p: Dictionary) -> void:
	if p.wait > 0 and p.kind != "rain":
		return
	var theme: Dictionary = Look.THEMES[p.art]
	var at := Vector2(p.x, p.y)
	var back := Vector2(-p.dir, 0)
	match p.kind:
		"trap": # broto discreto no chão, que cresce quando fica armado
			var height := 10.0 if p.age < 20 else 24.0 + sin(time * 0.15) * 4
			for n in 5:
				var x: float = p.x - 32 + n * 16
				draw_colored_polygon(PackedVector2Array([Vector2(x - 7, p.y), Vector2(x, p.y - height - n % 2 * 8), Vector2(x + 7, p.y)]), theme.accent.darkened(0.35))
			draw_circle(Vector2(p.x, p.y - height - 6), 5, Color(0.95, 0.25, 0.4))
			return
		"wall":
			var height := minf(p.age * 14.0, 130.0)
			for n in 3:
				var x: float = p.x - 22 + n * 15
				draw_colored_polygon(PackedVector2Array([Vector2(x - 8, p.y), Vector2(x - 8, p.y - height + n % 2 * 24), Vector2(x + 2, p.y - height - 18 + n % 2 * 30), Vector2(x + 14, p.y - height + 8), Vector2(x + 14, p.y)]), Color(0.7, 0.92, 1.0, 0.9))
				draw_line(Vector2(x - 3, p.y - 8), Vector2(x - 3, p.y - height + 20), Color.WHITE, 3)
			return
		"sand":
			draw_set_transform(at, 0, Vector2(1, 0.2))
			draw_circle(Vector2.ZERO, 88, Color(0.62, 0.46, 0.26))
			for n in 3:
				draw_arc(Vector2.ZERO, 80.0 - fposmod(time * 0.9 + n * 26, 76.0), 0, TAU, 28, Color(0.95, 0.8, 0.5), 10)
			draw_set_transform(Vector2.ZERO)
			return
		"vortex": # redemoinho que suga
			for n in 6:
				var width := 14.0 + n * 8
				draw_set_transform(Vector2(p.x + sin(time * 0.4 + n) * 6, p.y - 8 - n * 20), 0, Vector2(1, 0.3))
				draw_arc(Vector2.ZERO, width, -time * 0.4 - n, -time * 0.4 - n + 4.6, 18, Color(theme.accent, 0.85), 9)
				draw_set_transform(Vector2.ZERO)
			return
		"rain":
			if p.wait > 0: # marca no chão antes de cair
				if time / 4 % 2 == 0:
					draw_rect(Rect2(p.x - 16, Fighter.FLOOR_Y - 4, 32, 7), Color(0.95, 0.2, 0.4))
				return
			draw_colored_polygon(PackedVector2Array([at + Vector2(-9, -34), at + Vector2(0, 22), at + Vector2(9, -34)]), Color(0.28, 0.55, 0.18))
			draw_line(at + Vector2(0, -52), at + Vector2(0, -36), Color(0.95, 0.3, 0.5), 5)
			return
	match p.data.get("look", ""):
		"boulder": # rola pelo chão
			var turn: float = p.dir * time * 0.25
			draw_circle(at, 29, Color(0.2, 0.12, 0.08))
			draw_circle(at, 24, Color(0.6, 0.45, 0.3))
			for n in 3:
				draw_circle(at + Vector2.from_angle(turn + n * 2.1) * 13, 6, Color(0.4, 0.28, 0.18))
			for n in 3:
				draw_circle(at + back * (30 + n * 16) + Vector2(0, 22 - n * 3), 9 - n * 2, Color(0.75, 0.62, 0.45, 0.6))
		"wave": # crista alta
			for n in 3:
				sprites.draw_column(self, p.art, Vector2(p.x - p.dir * n * 22, p.y + 34), time + n * 3, 54 - n * 8, 76 - n * 18, Color(1, 1, 1, 1.0 - n * 0.25))
		"lance":
			draw_colored_polygon(PackedVector2Array([at + back * 52 + Vector2(0, -8), at - back * 30, at + back * 52 + Vector2(0, 8)]), Color(0.8, 0.95, 1.0))
			draw_line(at + back * 50, at - back * 24, Color.WHITE, 4)
			for n in 3:
				draw_rect(Rect2(at + back * (62 + n * 18) + Vector2(0, sin(time + n * 2) * 7), Vector2(7, 7)), Color(0.7, 0.92, 1.0, 0.8))
		"dart":
			draw_line(at + back * 24, at - back * 14, Color(0.24, 0.5, 0.16), 7)
			draw_colored_polygon(PackedVector2Array([at - back * 12 + Vector2(0, -7), at - back * 28, at - back * 12 + Vector2(0, 7)]), Color(0.9, 0.95, 0.6))
			draw_circle(at + back * 28, 5, Color(0.95, 0.3, 0.5))
		"orb":
			var pulse := 22.0 + sin(time * 0.35) * 5
			draw_circle(at, pulse, Color(theme.accent, 0.55))
			draw_circle(at, 12, Color.WHITE)
			for n in 4:
				var angle := time * 0.2 + n * TAU / 4
				draw_polyline(PackedVector2Array([at + Vector2.from_angle(angle) * 12, at + Vector2.from_angle(angle + 0.4) * 26, at + Vector2.from_angle(angle + 0.1) * 38]), theme.accent, 4)
		"gust":
			for n in 4:
				draw_arc(at + back * n * 15, 21.0 - n * 3, -PI / 2 * p.dir - 0.2, -PI / 2 * p.dir + 3.4, 14, Color(0.95, 0.8, 0.5, 1.0 - n * 0.2), 6)
		"seed":
			draw_circle(at, 14, Color(0.3, 0.18, 0.08))
			draw_circle(at, 10, Color(0.55, 0.38, 0.16))
			for n in 3:
				draw_circle(at + back * (18 + n * 12) + Vector2(0, sin(time * 0.4 + n) * 8), 6 - n, Color(0.45, 0.8, 0.25))
		"bomb":
			draw_circle(at, 15, Color(0.12, 0.08, 0.1))
			sprites.draw_spark(self, "hit", at + Vector2(10, -14), time % 8, 0.9)
		"ember":
			sprites.draw_projectile(self, p.art, at, p.dir, time, 1.5)
		"bolt":
			var points := PackedVector2Array()
			for n in 6:
				points.append(at + back * (n * 16 - 18) + Vector2(0, (n % 2 * 2 - 1) * 9 * (1 if time % 4 < 2 else -1)))
			draw_polyline(points, theme.accent, 10)
			draw_polyline(points, Color.WHITE, 3)
		"crescent": # lâmina de vento girando
			var spin: float = time * 0.5 * p.dir
			draw_arc(at, 22, spin, spin + 3.6, 18, theme.accent, 9)
			draw_arc(at, 22, spin + 0.3, spin + 3.0, 18, Color.WHITE, 3)
			draw_arc(at, 11, spin + 3.1, spin + 6.0, 12, Color(theme.accent, 0.6), 5)
		"feather":
			var tail := back * 34
			draw_colored_polygon(PackedVector2Array([at - back * 24, at + tail * 0.3 + Vector2(0, -11), at + tail + Vector2(0, -5), at + tail * 0.8, at + tail + Vector2(0, 7), at + tail * 0.3 + Vector2(0, 11)]), Color(0.98, 0.95, 0.82))
			draw_line(at - back * 24, at + tail, Color(0.55, 0.4, 0.2), 3)
		_:
			sprites.draw_projectile(self, p.art, at, p.dir, time, 2.5)

# Efeitos na frente dos lutadores, sempre apontando para o adversário.
func _draw_special_effect(f, sheet: String) -> void:
	if f.state != Fighter.State.SPECIAL:
		return
	var data: Dictionary = f.special_data()
	var theme: Dictionary = Look.THEMES[f.element]
	var hand: Vector2 = f.pos + Vector2(f.facing * 55, -100)
	if data.type == "projectile" and f.frame < data.startup:
		# Energia se juntando nas mãos antes do disparo.
		sprites.draw_spark(self, "hit" if f.element in ["fire", "electric", "earth"] else "block", hand, time % 8, 1.0 + f.frame / 10.0)
	elif data.type == "teleport" and f.frame < data.startup + 8:
		for n in 8: # nuvem de fumaça, cinzas ou areia
			var offset := Vector2.from_angle(n * TAU / 8) * (14.0 + absf(f.frame - data.startup) * 3)
			draw_circle(f.pos + Vector2(0, -80) + offset * Vector2(1, 1.8), 14, Color(theme.accent, 0.65))
	elif f.special_active("whip"):
		var points := PackedVector2Array()
		for n in 13:
			points.append(f.pos + Vector2(f.facing * (30 + n * 19), -100 + sin(n * 0.9 + time) * 10))
		draw_polyline(points, theme.mid.lightened(0.15), 9)
		draw_polyline(points, theme.accent, 3)
		sprites.draw_spark(self, "hit", points[12], time % 8, 1.6)
	elif f.special_active("burst"):
		var center: Vector2 = f.pos + Vector2(0, -85)
		for n in 3:
			draw_arc(center, 55.0 + n * 25 + time % 6 * 3, 0, TAU, 28, Color(theme.accent, 0.9 - n * 0.22), 9 - n * 2)
		for n in 6:
			sprites.draw_projectile(self, f.element, center + Vector2.from_angle(time * 0.3 + n * TAU / 6) * 95, f.facing, time + n, 1.4)
	elif f.special_active("quake"):
		for n in range(-5, 6):
			if n != 0:
				var delay: int = absi(n) * 2
				sprites.draw_column(self, f.element, Vector2(f.pos.x + n * 66, 456), time + delay, 52, 30 + maxi(0, 40 - delay * 3))
	elif f.special_active("uppercut"):
		sprites.draw_falling(self, f.element, f.pos + Vector2(f.facing * 45, -175), -3.0)
	elif f.special_active("counter"):
		for n in 2:
			draw_arc(f.pos + Vector2(0, -78), 62.0 + n * 12, time * 0.08 + n, time * 0.08 + n + 4.5, 24, Color(theme.accent, 0.9), 6)
	elif f.special_active("push"): # sopro: arcos que avançam
		for n in 5:
			var reach: float = 40.0 + fposmod(time * 14.0 + n * 40, 190.0)
			var center: Vector2 = f.pos + Vector2(f.facing * reach, -90 + sin(n * 2.0) * 24)
			var open := 0.0 if f.facing > 0 else PI
			draw_arc(center, 26.0 + reach * 0.22, open - 0.9, open + 0.9, 14, Color(theme.accent, 0.95 - reach / 320.0), 7)
	elif f.special_active("cyclone"):
		for n in 10:
			var width := 20.0 + n * 6
			draw_set_transform(f.pos + Vector2(f.facing * 65 + sin(time * 0.5 + n) * 8, -10 - n * 24), 0, Vector2(1, 0.3))
			draw_arc(Vector2.ZERO, width, time * 0.6 + n, time * 0.6 + n + 4.8, 18, Color(theme.accent, 0.9), 10)
			draw_set_transform(Vector2.ZERO)
	elif f.special_active("dive") and f.vel.y > 0:
		for n in 5:
			var from: Vector2 = f.pos + Vector2(-f.facing * (20 + n * 22), -110 - n * 22 + (n % 2) * 24)
			draw_line(from, from + Vector2(f.facing * 30, 28), Color(theme.accent, 0.85 - n * 0.12), 7)
		draw_line(f.pos + Vector2(f.facing * 20, -30), f.pos + Vector2(f.facing * 60, 5), Color.WHITE, 8)
	elif f.special_active("phase"):
		for n in 4: # rastro de sombras
			sprites.draw(self, sheet, "special_1", f.pos - Vector2(f.facing * (38 + n * 34), 0), f.facing, Sprites.SCALE, Color(1, 0.45, 0.4, 0.5 - n * 0.11))
		draw_line(f.pos + Vector2(f.facing * -40, -120), f.pos + Vector2(f.facing * 75, -60), Color.WHITE, 5)
	elif f.special_active("barrage"):
		for n in 5:
			var reach: float = 35.0 + fposmod(time * 23.0 + n * 31, 70.0)
			var fist: Vector2 = f.pos + Vector2(f.facing * reach, -130 + n * 17)
			draw_circle(fist, 10, theme.accent)
			draw_line(fist - Vector2(f.facing * 26, 0), fist, Color(theme.accent, 0.5), 7)
	elif f.special_active("dig"):
		if f.underground():
			for n in 7: # monte de areia andando
				draw_circle(Vector2(f.pos.x + (n - 3) * 13, Fighter.FLOOR_Y - 4 - (3 - absi(n - 3)) * 5 - (time + n * 5) % 8), 11, Color(0.82, 0.66, 0.38))
		else:
			for n in 6:
				sprites.draw_column(self, f.element, f.pos + Vector2((n - 2.5) * 30, 6), time + n * 3, 40, 90 + n % 2 * 50)
	elif f.special_active("armor"):
		draw_rect(f.hurtbox().grow(8), Color(theme.accent, 0.4))
		sprites.draw_projectile(self, f.element, f.pos + Vector2(f.facing * 70, -90), f.facing, time, 4.0)
	elif f.special_active("rush"):
		# O lutador vira um cometa: a cabeça de fogo vai na frente do punho.
		sprites.draw_projectile(self, f.element, f.pos + Vector2(f.facing * 75, -90), f.facing, time, 5.0)
	elif f.special_active("slide"):
		sprites.draw_projectile(self, f.element, f.pos + Vector2(f.facing * 100, -26), f.facing, time, 3.0)
	elif f.special_active("pillar"):
		var distance: float = f.eruption_distance()
		var x: float = Fighter.ERUPTION_FIRST
		while x <= distance:
			var current: bool = x == distance
			sprites.draw_column(self, f.element, f.pos + Vector2(f.facing * x, 4), time + int(x), 96 if current else 64, 240 if current else 110, Color.WHITE if current else Color(1, 1, 1, 0.6))
			x += Fighter.ERUPTION_GAP
	elif f.special_active("mirror"):
		var splash: bool = f.frame <= data.startup + Fighter.SPLASH_FRAMES
		for n in 2:
			sprites.draw_column(self, f.element, f.pos + Vector2(f.facing * (46 + n * 26), 4), time + n * 5, 48, (190 if splash else 160) - n * 40, Color(1, 1, 1, 0.85 - n * 0.3))

func _draw_impacts() -> void:
	for hit in impacts:
		sprites.draw_spark(self, "block" if hit.blocked else "hit", hit.at, hit.age, 4.0 if hit.strong and not hit.blocked else 2.2)
		var label: String = "DEFENDEU" if hit.blocked else "-%d" % hit.damage
		_text(label, hit.at.x, hit.at.y - 45 - hit.age, 18 if hit.blocked else 28, Color(0.6, 0.85, 1) if hit.blocked else Color(1, 0.35, 0.25))

# Recolhe os impactos novos, envelhece os antigos e treme a tela nos golpes fortes.
func _update_impacts() -> void:
	for hit in impacts:
		hit.age += 1
	impacts = impacts.filter(func(hit): return hit.age < IMPACT_FRAMES)
	if fight != null:
		for hit in fight.events:
			hit.age = 0
			impacts.append(hit)
			audio.impact(hit)
			if hit.strong and not hit.blocked:
				shake = 12
		fight.events.clear()
	shake = maxi(shake - 1, 0)
	position = Vector2((time % 2 * 2 - 1) * shake * 0.6, (time % 3 - 1) * shake * 0.4)

# Uma barra por especial: enche durante a recarga e acende quando está pronto.
func _draw_cooldowns(f, x: float, right_side: bool) -> void:
	var button: String = Controls.name_of("special", 1 if right_side and not menu.versus_cpu else 0)
	var commands := {"neutral": button, "forward": "→" + button, "down": "↓" + button}
	var n := 0
	for key in f.stats.specials:
		var left := x + 390 - 126 - n * 132 if right_side else x + n * 132
		var ready: float = 1.0 - float(f.cooldowns[key]) / f.stats.specials[key].cooldown
		draw_rect(Rect2(left, 82, 126, 8), Color(0.05, 0.04, 0.08))
		draw_rect(Rect2(left, 82, 126 * ready, 8), f.stats.color.lightened(0.35) if ready >= 1.0 else Color(0.45, 0.45, 0.5))
		draw_string(ThemeDB.fallback_font, Vector2(left, 104), "%s %s" % [commands[key], f.stats.specials[key].name], HORIZONTAL_ALIGNMENT_LEFT, 132, 10, Color.WHITE if ready >= 1.0 else Color(0.6, 0.6, 0.65))
		n += 1

# Barra de energia do supremo, no rodapé.
func _draw_energy(i: int) -> void:
	var f = fight.fighters[i]
	var theme: Dictionary = Look.THEMES[f.element]
	var x := 30.0 if i == 0 else 630.0
	var full: bool = f.energy >= Fighter.MAX_ENERGY
	var fill: float = 300.0 * f.energy / Fighter.MAX_ENERGY
	draw_rect(Rect2(x - 3, 492, 306, 20), theme.accent if full and time / 8 % 2 == 0 else Color(0.05, 0.04, 0.08))
	draw_rect(Rect2(x, 495, 300, 14), Color(0.18, 0.16, 0.22))
	draw_rect(Rect2(x if i == 0 else x + 300 - fill, 495, fill, 14), theme.accent if full else theme.accent.darkened(0.35))
	var who := 0 if menu.versus_cpu else i
	var label: String = "SUPREMO PRONTO:  ← ↓ → + %s" % Controls.name_of("special", who) if full else "SUPREMO  %d%%" % int(f.energy)
	if i == 1 and menu.versus_cpu and full:
		label = "SUPREMO PRONTO"
	Look.text(self, label, x + 150, 487, 14, theme.accent if full else Color(0.8, 0.8, 0.85))

func _draw_hud(i: int) -> void:
	var f = fight.fighters[i]
	var theme: Dictionary = Look.THEMES[f.element]
	var x := 30.0 if i == 0 else 540.0
	var fill: float = 390.0 * f.health / f.stats.health
	draw_rect(Rect2(x - 5, 20, 400, 32), theme.accent)
	draw_rect(Rect2(x - 2, 23, 394, 26), Color(0.05, 0.04, 0.08))
	draw_rect(Rect2(x, 25, 390, 22), theme.mid.darkened(0.4))
	var trail: float = 390.0 * maxf(ghost[i], f.health) / f.stats.health
	draw_rect(Rect2(x if i == 0 else x + 390 - trail, 25, trail, 22), Color(0.85, 0.15, 0.12))
	var left := x if i == 0 else x + 390 - fill
	draw_rect(Rect2(left, 25, fill, 22), Color(0.95, 0.8, 0.2))
	draw_rect(Rect2(left, 25, fill, 6), Color(1, 0.95, 0.6))
	Look.text(self, "%s • %s" % [f.stats.name.to_upper(), Data.ELEMENT_NAMES[f.element]], x + 90 if i == 0 else x + 300, 75, 19, theme.accent)
	_draw_cooldowns(f, x, i == 1)
	var side := x + 90 if i == 0 else x + 300
	if f.transformed:
		Look.text(self, "★ %s" % Data.FORMS[f.id].to_upper(), side, 126, 15, theme.accent)
	elif f.can_transform and not fight.match_over:
		var ask := "%s: TRANSFORMAR!" % Controls.name_of("transform", 0 if menu.versus_cpu else i) if not (i == 1 and menu.versus_cpu) else "PODE SE TRANSFORMAR"
		Look.text(self, ask, side, 126, 16, theme.accent if time / 10 % 2 == 0 else Color.WHITE)
	for w in Fight.WINS_NEEDED:
		var cx := x + 380 - w * 20 if i == 0 else x + 10 + w * 20
		draw_circle(Vector2(cx, 68), 8, Color.BLACK)
		draw_circle(Vector2(cx, 68), 6, theme.accent if w < fight.wins[i] else Color(0.3, 0.3, 0.3))

func _text(value: String, center_x: float, y: float, size: int, color := Color.WHITE) -> void:
	var at := Vector2(center_x - 480, y)
	draw_string_outline(ThemeDB.fallback_font, at, value, HORIZONTAL_ALIGNMENT_CENTER, 960, size, 6, Color.BLACK)
	draw_string(ThemeDB.fallback_font, at, value, HORIZONTAL_ALIGNMENT_CENTER, 960, size, color)
