# Tela da corrida: chão em pseudo-3D (como no Super Nintendo), céu, objetos, montaria e HUD.
extends Node2D

const Data = preload("res://scripts/data.gd")
const Race = preload("res://scripts/kart/race.gd")
const Controls = preload("res://scripts/controls.gd")
const Look = preload("res://scripts/theme.gd")
const GrandPrix = preload("res://scripts/kart/grand_prix.gd")

const HORIZON := 190.0
const HEIGHT := 74.0       # altura da câmera, em unidades da pista
const BACK := 135.0        # distância da câmera até a montaria
const FAR := 2300.0
const FOCAL := 430.0
const FRAME := Vector2(96, 72)
const RIDER_SCALE := 2.5
const PROP_HEIGHT := {"torch": 105.0, "rock": 46.0, "spire": 150.0}
const FOG := Color(0.55, 0.16, 0.08)

const FLOOR_SHADER := """
shader_type canvas_item;
uniform sampler2D map : filter_nearest_mipmap, repeat_disable;
uniform vec2 cam;
uniform float angle;
uniform float focal;
uniform float height;
uniform float horizon;
uniform float map_size;
uniform vec3 fog_color;
void fragment() {
	vec2 screen = vec2(UV.x * 960.0, horizon + UV.y * (540.0 - horizon));
	float depth = height * focal / max(screen.y - horizon, 0.5);
	float side = (screen.x - 480.0) * depth / focal;
	vec2 forward = vec2(cos(angle), sin(angle));
	vec2 world = cam + forward * depth + vec2(-forward.y, forward.x) * side;
	vec2 uv = world / map_size;
	vec3 color = texture(map, clamp(uv, vec2(0.0), vec2(1.0))).rgb;
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) {
		color = vec3(0.2, 0.09, 0.09);
	}
	COLOR = vec4(mix(color, fog_color, clamp((depth - 700.0) / 1900.0, 0.0, 0.88)), 1.0);
}
"""

var gp               # o grande prêmio
var race             # o corredor do jogador
var sprites
var riders := {}
var flash := 0
var cut_in := -1     # quem está usando o supremo
var cut_age := 999
var shake := 0
var audio
var paused := false
var ticks := 0
var camera_angle := 0.0
var focal := FOCAL
var banner := ""
var banner_age := 999
var props := {}
var ground := ColorRect.new()
var front := Node2D.new() # tudo que fica na frente do chão
var track_name := "fire"

func setup(fighter_id: String, audio_player, sprite_sheets, seed_value := 0) -> void:
	audio = audio_player
	sprites = sprite_sheets
	gp = GrandPrix.new(Race.load_track(track_name), fighter_id, seed_value)
	race = gp.racers[0]
	camera_angle = race.heading
	for key in Data.ROSTER:
		riders[key] = load("res://assets/kart/rider_%s.png" % key)
	for kind in PROP_HEIGHT:
		props[kind] = load("res://assets/kart/prop_%s.png" % kind)
	var image: Image = load("res://assets/kart/track_%s.png" % track_name).get_image()
	image.generate_mipmaps()
	var shader := Shader.new()
	shader.code = FLOOR_SHADER
	var material_ := ShaderMaterial.new()
	material_.shader = shader
	material_.set_shader_parameter("map", ImageTexture.create_from_image(image))
	material_.set_shader_parameter("map_size", float(race.track.size))
	material_.set_shader_parameter("height", HEIGHT)
	material_.set_shader_parameter("horizon", HORIZON)
	material_.set_shader_parameter("fog_color", Vector3(FOG.r, FOG.g, FOG.b))
	ground.material = material_
	ground.position = Vector2(0, HORIZON)
	ground.size = Vector2(960, 540 - HORIZON)
	add_child(ground)
	add_child(front)
	front.draw.connect(_draw_front)
	_update_camera()

# Um frame da corrida com o comando dado.
func tick(input: Dictionary) -> void:
	if paused:
		return
	ticks += 1
	banner_age += 1
	cut_age += 1
	flash = maxi(flash - 1, 0)
	shake = maxi(shake - 1, 0)
	gp.step(input)
	for event in gp.events:
		_react(event)
	gp.events.clear()
	audio.race_sounds(race)
	_update_camera()
	position = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake * 0.5
	queue_redraw()
	front.queue_redraw()

func _react(event: Dictionary) -> void:
	match event.type:
		"count", "go":
			audio.play(event.type)
		"boost", "slipstream":
			audio.play("kart_boost")
			if event.type == "slipstream":
				_say("VÁCUO!")
		"charge":
			audio.play("kart_charge", -4.0, 1.0 + 0.2 * race.drift_level())
		"bump":
			audio.play("kart_bump")
			_rumble(0.4, 0.1)
		"lap":
			audio.play("lap")
			_say("ÚLTIMA VOLTA!" if race.lap == Race.LAPS else "VOLTA %d" % race.lap)
		"finish":
			audio.play("victory")
		"orb":
			audio.play("move")
		"got":
			audio.play("confirm")
		"ready":
			audio.play("finish_title", -6.0)
			_say("SUPREMO PRONTO!")
		"use":
			if event.who == 0:
				audio.play({"fireball": "special_fire", "ice": "special_water", "sand": "special_earth", "gust": "special_air", "bolt": "special_electric", "shell": "special_plant"}[event.item])
		"hit":
			if event.who == 0:
				audio.play("hit_heavy")
				shake = 18
				_rumble(1.0, 0.35)
				_say("%s TE ACERTOU!" % _name(event.by) if event.by != 0 else "OPS!")
			elif event.by == 0:
				audio.play("hit")
				_say("VOCÊ ACERTOU %s!" % _name(event.who))
		"blocked":
			if event.who == 0:
				audio.play("block")
				_say("A CASCA SEGUROU!")
		"lightning":
			audio.play("special_electric")
			flash = 14
		"transform":
			if event.who == 0:
				audio.play("transform")
				flash = 20
				_say(Data.FORMS[race.id].to_upper() + "!")
		"super":
			var element: String = Data.FIGHTERS[gp.racers[event.who].id].clan
			if event.who == 0:
				cut_in = 0
				cut_age = 0
				flash = 16
				audio.play("roar_%s" % element)
			elif cut_age > 90:
				cut_in = event.who
				cut_age = 0
				audio.play("roar_%s" % element, -8.0)

func _name(i: int) -> String:
	return Data.FIGHTERS[gp.racers[i].id].name.to_upper()

func _rumble(strength: float, seconds: float) -> void:
	if Controls.uses_pad(0):
		Input.start_joy_vibration(Controls.devices[0].pad, strength * 0.6, strength, seconds)

func _say(text: String) -> void:
	banner = text
	banner_age = 0

func _update_camera() -> void:
	camera_angle = lerp_angle(camera_angle, race.heading - race.drift * 0.12, 0.14)
	# Quanto mais rápido, mais aberta a lente: o chão passa voando.
	var wanted := FOCAL * (1.0 - 0.16 * clampf(absf(race.speed) / race.max_speed, 0.0, 1.0))
	if race.boost > 0:
		wanted = FOCAL * 0.7
	focal = lerpf(focal, wanted, 0.1)
	var shader: ShaderMaterial = ground.material
	shader.set_shader_parameter("cam", _eye())
	shader.set_shader_parameter("angle", camera_angle)
	shader.set_shader_parameter("focal", focal)

# A distância acompanha a lente, para a montaria ficar sempre do mesmo tamanho.
func _back() -> float:
	return focal * BACK / FOCAL

func _eye() -> Vector2:
	return race.pos - Vector2.from_angle(camera_angle) * _back()

# Céu de fim de mundo, que gira junto com a curva.
func _draw() -> void:
	var bands := [Color(0.1, 0.02, 0.05), Color(0.2, 0.04, 0.06), Color(0.34, 0.07, 0.06), Color(0.5, 0.13, 0.06), Color(0.72, 0.26, 0.08)]
	for i in bands.size():
		draw_rect(Rect2(0, i * HORIZON / bands.size(), 960, HORIZON / bands.size() + 1), bands[i])
	var turn := camera_angle * FOCAL
	for layer in [[250.0, 80.0, 0.7, Color(0.28, 0.07, 0.08)], [330.0, 120.0, 1.0, Color(0.13, 0.04, 0.06)]]:
		var gap: float = layer[0]
		var span := ceilf(TAU * FOCAL * layer[2] / gap) * gap
		for n in int(span / gap):
			var x := fposmod(n * gap - turn * layer[2], span) - 200.0
			if x > 1160:
				continue
			var peak: float = layer[1] * (0.6 + 0.4 * fposmod(n * 0.37, 1.0))
			draw_colored_polygon(PackedVector2Array([Vector2(x - 190, HORIZON), Vector2(x - 22, HORIZON - peak), Vector2(x + 22, HORIZON - peak), Vector2(x + 190, HORIZON)]), layer[3])
			if n % 4 == 0:
				draw_colored_polygon(PackedVector2Array([Vector2(x - 22, HORIZON - peak), Vector2(x + 22, HORIZON - peak), Vector2(x + 6, HORIZON - peak + 40)]), Color(1.0, 0.5, 0.1))

# Posição na tela de um ponto da pista: [x, y do chão, escala, distância], ou vazio se estiver fora.
func _project(point: Vector2, nearest := 45.0) -> Array:
	var forward := Vector2.from_angle(camera_angle)
	var relative: Vector2 = point - _eye()
	var depth := relative.dot(forward)
	if depth < nearest or depth > FAR:
		return []
	var side := relative.dot(Vector2(-forward.y, forward.x))
	var scale_ := focal / depth
	return [480.0 + side * scale_, HORIZON + HEIGHT * scale_, scale_, depth]

func _haze(depth: float) -> Color:
	return Color.WHITE.lerp(FOG, clampf((depth - 700.0) / 1900.0, 0.0, 0.85))

# Tudo que está na pista é desenhado do mais longe para o mais perto.
func _draw_front() -> void:
	var things: Array = [] # [distância, tipo, tela, dado]
	var add := func(point: Vector2, kind: String, data, nearest: float):
		var at := _project(point, nearest)
		if not at.is_empty() and at[0] > -250 and at[0] < 1210:
			things.append([at[3], kind, at, data])
	for hazard in gp.hazards:
		add.call(hazard.pos, "hazard", hazard, 70.0)
	for prop in race.track.props:
		add.call(Vector2(prop[0], prop[1]), "prop", prop[2], _back() * 1.15)
	for orb in gp.orbs:
		if orb.wait == 0:
			add.call(orb.pos, "orb", orb, 70.0)
	for shot in gp.shots:
		add.call(shot.pos, "shot", shot, 70.0)
	for i in range(1, gp.racers.size()):
		add.call(gp.racers[i].pos, "rival", i, 75.0)
	for i in race.track.arches:
		var at := _project(race.path[int(i)], _back() * 0.9)
		if not at.is_empty():
			things.append([at[3], "arch", at, int(i)])
	var own := _project(race.pos)
	if not own.is_empty():
		things.append([own[3], "player", own, 0])
	things.sort_custom(func(a, b): return a[0] > b[0])
	for thing in things:
		match thing[1]:
			"prop":
				_draw_prop([thing[2], thing[3]])
			"hazard":
				_draw_hazard(thing[2], thing[3])
			"orb":
				_draw_orb(thing[2])
			"shot":
				_draw_shot(thing[2])
			"rival":
				_draw_racer(thing[3], Vector2(thing[2][0], thing[2][1]), thing[2][3])
			"player":
				_draw_racer(0, Vector2(thing[2][0], thing[2][1]), thing[2][3])
			"arch":
				_draw_arch(thing[3])
	_draw_embers()
	_draw_hud()

func _draw_prop(item: Array) -> void:
	var at: Array = item[0]
	var texture: Texture2D = props[item[1]]
	var tall: float = PROP_HEIGHT[item[1]] * at[2]
	var wide := tall * texture.get_width() / texture.get_height()
	front.draw_texture_rect(texture, Rect2(at[0] - wide / 2, at[1] - tall, wide, tall), false, _haze(at[3]))

func _disc(center: Vector2, radius: float, squash: float, color: Color) -> void:
	front.draw_set_transform(center, 0, Vector2(1, squash))
	front.draw_circle(Vector2.ZERO, maxf(radius, 1.0), color)
	front.draw_set_transform(Vector2.ZERO)

func _draw_hazard(at: Array, hazard: Dictionary) -> void:
	var center := Vector2(at[0], at[1])
	var ice: bool = hazard.kind == "ice"
	_disc(center, 70 * at[2], 0.22, Color(0.6, 0.9, 1.0, 0.85) if ice else Color(0.72, 0.55, 0.25, 0.9))
	_disc(center, 44 * at[2], 0.22, Color(0.92, 0.98, 1.0, 0.9) if ice else Color(0.5, 0.36, 0.16, 0.9))

# Orbe de poder: um cristal flutuante.
func _draw_orb(at: Array) -> void:
	var scale_: float = at[2]
	var float_up := (34.0 + sin(ticks * 0.1 + at[0] * 0.02) * 6.0) * scale_
	var center := Vector2(at[0], at[1] - float_up)
	var half := 20.0 * scale_ * (0.65 + 0.35 * absf(sin(ticks * 0.07)))
	var color := Color.from_hsv(fposmod(ticks * 0.01, 1.0), 0.6, 1.0)
	_disc(Vector2(at[0], at[1]), 18 * scale_, 0.25, Color(0, 0, 0, 0.35))
	_disc(center, 30 * scale_, 1.0, Color(color, 0.25))
	var tall := 26.0 * scale_
	front.draw_colored_polygon(PackedVector2Array([center + Vector2(0, -tall), center + Vector2(maxf(half, 1.0), 0), center + Vector2(0, tall), center + Vector2(-maxf(half, 1.0), 0)]), color)
	front.draw_line(center + Vector2(0, -tall), center + Vector2(0, tall), Color.WHITE, maxf(2.0 * scale_, 1.0))

func _draw_shot(at: Array) -> void:
	var scale_: float = at[2]
	var center := Vector2(at[0], at[1] - 30 * scale_)
	for ring in [[34.0, Color(1, 0.3, 0.05, 0.6)], [24.0, Color(1, 0.6, 0.1)], [13.0, Color(1, 0.95, 0.6)]]:
		_disc(center + Vector2(sin(ticks * 0.9) * 3, cos(ticks * 0.7) * 3) * scale_, ring[0] * scale_, 1.0, ring[1])

# Portal sobre a pista: dá a noção de velocidade quando passa por cima.
func _draw_arch(index: int) -> void:
	var path: PackedVector2Array = race.path
	var side := (path[(index + 1) % path.size()] - path[index]).normalized().orthogonal() * (float(race.track.half) + 34.0)
	var left := _project(path[index] - side, 40.0)
	var right := _project(path[index] + side, 40.0)
	if left.is_empty() or right.is_empty():
		return
	var haze := _haze(left[3])
	var top_left := Vector2(left[0], left[1] - 190 * left[2])
	var top_right := Vector2(right[0], right[1] - 190 * right[2])
	for pillar in [[left, top_left], [right, top_right]]:
		var width: float = 20.0 * pillar[0][2]
		front.draw_line(Vector2(pillar[0][0], pillar[0][1]), pillar[1], Color(0.16, 0.06, 0.07) * haze, width)
		front.draw_line(Vector2(pillar[0][0], pillar[0][1]), pillar[1], Color(1.0, 0.5, 0.1) * haze, width * 0.2)
	front.draw_line(top_left, top_right, Color(0.2, 0.07, 0.07) * haze, 36 * left[2])
	front.draw_line(top_left, top_right, (Color(1.0, 0.9, 0.5) if index == 0 else Color(1.0, 0.45, 0.1)) * haze, 9 * left[2])
	if index == 0 and left[3] < 1100:
		var middle := (top_left + top_right) / 2
		_text("VULCÃO DA CHAMA", middle.x, middle.y - 18 * left[2], clampi(int(26 * left[2]), 8, 30), Color(1, 0.85, 0.35))

# Brasas voando contra a câmera: quanto mais rápido, mais riscam a tela.
func _draw_embers() -> void:
	var rush := clampf(absf(race.speed) / race.max_speed, 0.0, 1.5)
	var center := Vector2(480, HORIZON + 40)
	for n in 28:
		var phase := fposmod(n * 0.137 + race.distance_run * 0.0016 * (1.0 + n % 3 * 0.3), 1.0)
		var direction := Vector2.from_angle(n * 2.39996)
		var at := center + direction * (60.0 + phase * phase * 640.0)
		var tail := direction * (4.0 + phase * 46.0 * rush)
		front.draw_line(at, at + tail, Color(1.0, 0.65 + n % 3 * 0.1, 0.2, phase * 0.8 * minf(rush, 1.0)), 1.5 + phase * 2.5)

# Um corredor visto por trás, com turbo, escudo, aura, derrapagem e rodopio.
func _draw_racer(i: int, feet: Vector2, depth: float) -> void:
	var racer = gp.racers[i]
	var state: Dictionary = gp.states[i]
	var size_factor := _back() / depth
	if size_factor > 1.9: # colado na câmera, atravessaria a tela
		return
	var column := 1
	if i == 0:
		var turning: float = racer.drift if racer.drift != 0 else (signf(racer.steer) if absf(racer.steer) > 0.3 else 0.0)
		column = 1 + int(turning)
	else:
		var relative := angle_difference(camera_angle, racer.heading)
		column = 2 if relative > 0.16 else (0 if relative < -0.16 else 1)
	var step := int(racer.distance_run / 40.0) % 2
	var bounce: float = sin(racer.hop / 12.0 * PI) * 22.0
	var squeeze := 1.0
	if racer.stun > 0:
		squeeze = cos(racer.stun * 0.42)
		column = 1
	if i == 0 and racer.offroad and absf(racer.speed) > 1.0:
		feet += Vector2(ticks % 2 * 4 - 2, ticks % 3 * 3 - 3)
	var scale_ := RIDER_SCALE * size_factor
	var element: String = Data.FIGHTERS[racer.id].clan
	var accent: Color = Look.THEMES[element].accent
	_disc(feet + Vector2(0, -6 * size_factor), 76 * size_factor, 0.25, Color(0, 0, 0, 0.4))
	if state.form > 0 or state.super > 0:
		for n in 14:
			var rise := fposmod(ticks * 3.0 + n * 23.0, 110.0)
			var at := feet + Vector2((n - 6.5) * 13.0 + sin(ticks * 0.2 + n) * 6.0, -rise) * size_factor
			_disc(at, (13.0 - rise * 0.09) * size_factor, 1.4, Color(accent, 0.65))
	if racer.boost > 0:
		for n in 3:
			var tail := feet + Vector2((n - 1) * 46, -34) * size_factor
			var length := (40.0 + (ticks * 7 + n * 13) % 34) * size_factor
			var wide := 16.0 * size_factor
			front.draw_colored_polygon(PackedVector2Array([tail + Vector2(-wide, 0), tail + Vector2(0, length), tail + Vector2(wide, 0)]), Color(1.0, 0.55, 0.1, 0.9))
			front.draw_colored_polygon(PackedVector2Array([tail + Vector2(-wide * 0.45, 0), tail + Vector2(0, length * 0.6), tail + Vector2(wide * 0.45, 0)]), Color(1.0, 0.95, 0.5))
	var lean: float = racer.drift * 0.09
	var tint := _haze(depth) if i > 0 else Color.WHITE
	if state.form > 0:
		tint *= Color.WHITE.lerp(accent, 0.45) * 1.25
	if racer.slowed > 0:
		tint *= Color(0.85, 0.7, 0.45)
	tint.a = 1.0
	if absf(squeeze) < 0.12:
		squeeze = 0.12
	front.draw_set_transform(feet + Vector2(0, -bounce * size_factor), lean, Vector2(squeeze, 1) * scale_)
	front.draw_texture_rect_region(riders[racer.id], Rect2(-48, -68, FRAME.x, FRAME.y), Rect2(Vector2(column, step) * FRAME, FRAME), tint)
	front.draw_set_transform(Vector2.ZERO)
	if racer.shield > 0:
		front.draw_arc(feet + Vector2(0, -70 * size_factor), 105 * size_factor, 0, TAU, 28, Color(0.45, 1.0, 0.5, 0.75), maxf(5 * size_factor, 1.0))
	if i == 0:
		_draw_dust(feet)
	elif depth < 900:
		var label := feet + Vector2(0, -182 * size_factor)
		_text("%dº %s" % [gp.place_of(i), Data.FIGHTERS[racer.id].name], label.x, label.y, clampi(int(17 * size_factor), 10, 18), accent.lightened(0.3))

# Faíscas da derrapagem (a cor mostra o turbo carregado) e poeira fora da pista.
func _draw_dust(feet: Vector2) -> void:
	if race.drift != 0:
		var color: Color = [Color(0.85, 0.8, 0.75), Color(0.35, 0.75, 1.0), Color(1.0, 0.6, 0.1), Color(0.85, 0.35, 1.0)][race.drift_level()]
		for side in [-1.0, 1.0]:
			for n in 9:
				var age := float((ticks * 3 + n * 11) % 28)
				var at := feet + Vector2(side * 66 - race.drift * age * 3.4, -6 - sin(age / 28.0 * PI) * (20 + n % 3 * 14))
				front.draw_rect(Rect2(at, Vector2(14, 14) * (1.0 - age / 40.0)), color)
	elif race.offroad and absf(race.speed) > 1.5:
		for n in 8:
			var age := float((ticks * 2 + n * 9) % 24)
			front.draw_circle(feet + Vector2((n - 3.5) * 22, -4 + age * 0.8), 9.0 - age * 0.3, Color(0.55, 0.4, 0.34, 0.8 - age / 34.0))

func _text(value: String, x: float, y: float, size: int, color := Color.WHITE) -> void:
	Look.text(front, value, x, y, size, color)

func _draw_hud() -> void:
	var gold := Color(1, 0.85, 0.35)
	var state: Dictionary = gp.states[0]
	var info: Dictionary = Data.FIGHTERS[race.id]
	var pad := Controls.uses_pad(0)
	if race.boost > 0: # riscos de velocidade nas bordas
		for n in 18:
			var side := -1.0 if n % 2 else 1.0
			var y := 90.0 + fposmod(n * 71.0 + ticks * 29.0, 420.0)
			front.draw_line(Vector2(480 + side * 480, y), Vector2(480 + side * (300 + n % 3 * 40), y - 6 + (y - 270) * 0.14), Color(1, 1, 1, 0.6), 3)
	if flash > 0:
		front.draw_rect(Rect2(0, 0, 960, 540), Color(1, 0.97, 0.85, flash / 28.0))
	_draw_cut_in()
	_text("VOLTA %d/%d" % [clampi(race.lap, 1, Race.LAPS), Race.LAPS], 78, 32, 24, gold)
	_text(Race.format_time(race.time), 78, 56, 19)
	_draw_ranking()
	_text("%dº" % gp.place_of(0), 878, 452, 78, [gold, Color(0.85, 0.9, 1.0), Color(1.0, 0.65, 0.4), Color.WHITE][mini(gp.place_of(0) - 1, 3)])
	_text("de %d" % gp.racers.size(), 878, 476, 17)
	_text("%d km/h" % roundi(absf(race.speed) * 19), 878, 514, 24)

	# Poder guardado.
	front.draw_rect(Rect2(430, 8, 100, 62), Color(0, 0, 0, 0.7))
	front.draw_rect(Rect2(430, 8, 100, 62), gold, false, 3)
	var shown: String = state.item
	if state.roulette > 0:
		shown = GrandPrix.ITEMS.keys()[(state.roulette / 5) % GrandPrix.ITEMS.size()]
	if shown != "":
		_draw_icon(shown, Vector2(480, 39))
		if state.roulette == 0:
			_text("%s   [%s]" % [GrandPrix.ITEMS[shown].name, "X" if pad else "J"], 480, 90, 15)

	# Barra do supremo, turbo da derrapagem e transformação.
	var full: bool = state.energy >= GrandPrix.MAX_ENERGY
	front.draw_rect(Rect2(14, 496, 236, 22), Color(0, 0, 0, 0.75))
	front.draw_rect(Rect2(17, 499, 230 * state.energy / GrandPrix.MAX_ENERGY, 16), gold if full and ticks / 8 % 2 else info.color)
	_text("SUPREMO  [%s]" % ("Y" if pad else "L") if full else "SUPREMO", 132, 512, 14)
	_text("%s e %s" % [info.name, Data.CREATURES[race.id]], 132, 488, 15, info.color.lightened(0.35))
	if gp.can_transform(0):
		_text("[%s]  TRANSFORMAR" % ("L3/R3" if pad else "O"), 132, 466, 15, Color.WHITE if ticks / 15 % 2 else gold)
	elif state.form > 0:
		_text("%s  %d" % [Data.FORMS[race.id], state.form / 60 + 1], 132, 466, 15, gold)
	if race.drift != 0:
		var needed: float = Race.DRIFT_LEVELS[2]
		var colors := [Color(0.8, 0.8, 0.8), Color(0.35, 0.75, 1.0), Color(1.0, 0.6, 0.1), Color(0.85, 0.35, 1.0)]
		front.draw_rect(Rect2(380, 508, 200, 14), Color(0, 0, 0, 0.7))
		front.draw_rect(Rect2(382, 510, 196 * minf(race.charge / needed, 1.0), 10), colors[race.drift_level()])
		for mark in [Race.DRIFT_LEVELS[0], Race.DRIFT_LEVELS[1]]:
			front.draw_rect(Rect2(382 + 196 * mark / needed, 508, 2, 14), Color.WHITE)
	_draw_map()

	if race.countdown > 0:
		_text(str(ceili(race.countdown / 60.0)), 480, 220, 110 + (race.countdown % 60) / 2, gold)
		front.draw_rect(Rect2(190, 246, 580, 76), Color(0, 0, 0, 0.6))
		_text("%s acelera    %s derrapa (segure na curva e solte)" % (["A ou RT", "RB"] if pad else ["W", "K"]), 480, 270, 17)
		_text("%s usa o poder    %s supremo    %s transforma" % (["X", "Y", "L3/R3"] if pad else ["J", "L", "O"]), 480, 292, 17)
		_text("Acelere quando aparecer o 1 para largar com turbo", 480, 314, 14, Color(0.7, 0.9, 1))
	elif race.time < 45:
		_text("JÁ!", 480, 230, 100, Color(0.45, 1, 0.55))
	if banner_age < 90 and not race.finished:
		_text(banner, 480, 140, 34 + maxi(0, 10 - banner_age) * 3, gold)
	if race.wrong_way > 45 and ticks / 12 % 2 == 0:
		_text("CONTRAMÃO!", 480, 190, 50, Color(1, 0.3, 0.2))
	if race.finished:
		_draw_results()
	if paused:
		front.draw_rect(Rect2(0, 0, 960, 540), Color(0, 0, 0, 0.7))
		_text("PAUSA", 480, 240, 60, gold)
		_text("Start / Enter: continuar    Select / Esc: sair", 480, 300, 20)

# Faixa com a criatura atravessando a tela quando alguém usa o supremo.
func _draw_cut_in() -> void:
	if cut_age >= 80 or cut_in < 0:
		return
	var id: String = gp.racers[cut_in].id
	var element: String = Data.FIGHTERS[id].clan
	var mine := cut_in == 0
	var x := lerpf(-260.0, 300.0, minf(cut_age / 14.0, 1.0)) + maxf(cut_age - 56, 0.0) * 40.0
	var y := 300.0 if mine else 170.0
	var tall := 150.0 if mine else 64.0
	front.draw_rect(Rect2(0, y - tall / 2, 960, tall), Color(Look.THEMES[element].dark, 0.7))
	front.draw_rect(Rect2(0, y - tall / 2, 960, 4), Look.THEMES[element].accent)
	front.draw_rect(Rect2(0, y + tall / 2 - 4, 960, 4), Look.THEMES[element].accent)
	sprites.draw_creature(front, id, Vector2(x, y + tall * 0.6), 1, int(cut_age > 22), 3.2 if mine else 1.3)
	_text("%s — %s!" % [_name(cut_in), Data.CREATURES[id].to_upper()], 700 if mine else 640, y + 10, 30 if mine else 20, Look.THEMES[element].accent)

func _draw_icon(kind: String, at: Vector2) -> void:
	match kind:
		"fireball":
			front.draw_circle(at, 22, Color(1, 0.35, 0.05))
			front.draw_circle(at + Vector2(3, 3), 13, Color(1, 0.85, 0.3))
		"ice":
			for n in 3:
				var arm := Vector2.from_angle(n * PI / 3) * 23
				front.draw_line(at - arm, at + arm, Color(0.7, 0.95, 1.0), 6)
		"sand":
			front.draw_colored_polygon(PackedVector2Array([at + Vector2(-26, 18), at + Vector2(0, -18), at + Vector2(26, 18)]), Color(0.85, 0.65, 0.3))
		"gust":
			for n in 3:
				front.draw_arc(at + Vector2(-8 + n * 4, -12 + n * 12), 14, -PI * 0.8, PI * 0.45, 12, Color(0.75, 1.0, 0.95), 5)
		"bolt":
			front.draw_colored_polygon(PackedVector2Array([at + Vector2(6, -24), at + Vector2(-14, 4), at + Vector2(0, 4), at + Vector2(-6, 24), at + Vector2(15, -6), at + Vector2(1, -6)]), Color(1, 0.92, 0.2))
		"shell":
			front.draw_circle(at, 22, Color(0.3, 0.7, 0.3))
			front.draw_arc(at, 13, 0, TAU, 16, Color(0.75, 1.0, 0.6), 4)

func _draw_ranking() -> void:
	for place in gp.order.size():
		var i: int = gp.order[place]
		var racer = gp.racers[i]
		var y: float = 70.0 + place * 21.0
		front.draw_rect(Rect2(10, y, 126, 19), Color(1, 0.85, 0.35, 0.85) if i == 0 else Color(0, 0, 0, 0.55))
		front.draw_rect(Rect2(10, y, 5, 19), Data.FIGHTERS[racer.id].color)
		var color := Color(0.15, 0.05, 0.02) if i == 0 else Color.WHITE
		front.draw_string(Look.font(), Vector2(21, y + 15), "%2d  %s" % [place + 1, Data.FIGHTERS[racer.id].name], HORIZONTAL_ALIGNMENT_LEFT, 112, 13, color)

func _draw_results() -> void:
	front.draw_rect(Rect2(240, 40, 480, 462), Color(0, 0, 0, 0.86))
	var mine: int = gp.place_of(0)
	_text("VITÓRIA!" if mine == 1 else "%dº LUGAR" % mine, 480, 84, 38, Color(1, 0.85, 0.35))
	for place in gp.order.size():
		var i: int = gp.order[place]
		var state: Dictionary = gp.states[i]
		var color := Color(1, 0.85, 0.35) if i == 0 else Color.WHITE
		var y: float = 118.0 + place * 27.0
		_text("%dº" % (place + 1), 300, y, 18, color)
		_text(Data.FIGHTERS[gp.racers[i].id].name, 430, y, 18, color)
		_text(Race.format_time(state.finish_time) if state.finish_time > 0 else "correndo...", 630, y, 18, color)
	_text("Start / Enter: correr de novo    Select / Esc: sair", 480, 486, 15)

func _draw_map() -> void:
	var origin := Vector2(788, 8)
	var factor := 166.0 / float(race.track.size)
	var line := PackedVector2Array()
	for point in race.path:
		line.append(origin + point * factor)
	line.append(line[0])
	front.draw_rect(Rect2(origin, Vector2(166, 166)), Color(0, 0, 0, 0.55))
	front.draw_polyline(line, Color(0.75, 0.72, 0.78), 5)
	front.draw_rect(Rect2(line[0] - Vector2(7, 2), Vector2(14, 4)), Color.WHITE)
	for i in range(gp.racers.size() - 1, 0, -1):
		front.draw_circle(origin + gp.racers[i].pos * factor, 3.5, Data.FIGHTERS[gp.racers[i].id].color)
	front.draw_circle(origin + race.pos * factor, 5, Data.FIGHTERS[race.id].color)
	front.draw_arc(origin + race.pos * factor, 6, 0, TAU, 10, Color.WHITE, 2)
