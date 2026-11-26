# Tela da corrida: chão em pseudo-3D (como no Super Nintendo), céu, objetos, montaria e HUD.
extends Node2D

const Data = preload("res://scripts/data.gd")
const Race = preload("res://scripts/kart/race.gd")
const Controls = preload("res://scripts/controls.gd")
const Look = preload("res://scripts/theme.gd")

const HORIZON := 190.0
const HEIGHT := 74.0       # altura da câmera, em unidades da pista
const BACK := 130.0        # distância da câmera até a montaria
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
	COLOR = vec4(mix(color, fog_color, clamp((depth - 450.0) / 1300.0, 0.0, 0.9)), 1.0);
}
"""

var race
var audio
var paused := false
var ticks := 0
var camera_angle := 0.0
var focal := FOCAL
var banner := ""
var banner_age := 999
var rider: Texture2D
var props := {}
var ground := ColorRect.new()
var front := Node2D.new() # tudo que fica na frente do chão
var track_name := "fire"

func setup(fighter_id: String, audio_player) -> void:
	audio = audio_player
	race = Race.new(Race.load_track(track_name), fighter_id)
	camera_angle = race.heading
	rider = load("res://assets/kart/rider_%s.png" % fighter_id)
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
	race.step(input)
	for event in race.events:
		_react(event)
	race.events.clear()
	audio.race_sounds(race)
	_update_camera()
	queue_redraw()
	front.queue_redraw()

func _react(event: String) -> void:
	match event:
		"count", "go":
			audio.play(event)
		"boost":
			audio.play("kart_boost")
		"charge":
			audio.play("kart_charge", -4.0, 1.0 + 0.2 * race.drift_level())
		"bump":
			audio.play("kart_bump")
		"lap":
			audio.play("lap")
			_say("ÚLTIMA VOLTA!" if race.lap == Race.LAPS else "VOLTA %d" % race.lap)
		"finish":
			audio.play("victory")
			_say("CHEGADA!")

func _say(text: String) -> void:
	banner = text
	banner_age = 0

func _update_camera() -> void:
	camera_angle = lerp_angle(camera_angle, race.heading - race.drift * 0.12, 0.14)
	focal = lerpf(focal, FOCAL * (0.82 if race.boost > 0 else 1.0), 0.12)
	var eye: Vector2 = race.pos - Vector2.from_angle(camera_angle) * BACK
	var shader: ShaderMaterial = ground.material
	shader.set_shader_parameter("cam", eye)
	shader.set_shader_parameter("angle", camera_angle)
	shader.set_shader_parameter("focal", focal)

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

# Posição na tela de um ponto da pista: [x, y do chão, escala], ou vazio se estiver atrás.
func _project(point: Vector2) -> Array:
	var forward := Vector2.from_angle(camera_angle)
	var relative: Vector2 = point - (race.pos - forward * BACK)
	var depth := relative.dot(forward)
	if depth < 45.0 or depth > 1500.0:
		return []
	var side := relative.dot(Vector2(-forward.y, forward.x))
	var scale_ := focal / depth
	return [480.0 + side * scale_, HORIZON + HEIGHT * scale_, scale_, depth]

func _draw_front() -> void:
	var far: Array = []
	for prop in race.track.props:
		var on_screen := _project(Vector2(prop[0], prop[1]))
		if on_screen.is_empty() or on_screen[0] < -200 or on_screen[0] > 1160:
			continue
		if on_screen[3] < BACK * 1.15: # perto demais da câmera, tamparia a corrida
			continue
		far.append([on_screen, prop[2]])
	far.sort_custom(func(a, b): return a[0][3] > b[0][3])
	for item in far:
		_draw_prop(item)
	_draw_rider()
	_draw_hud()

func _draw_prop(item: Array) -> void:
	var at: Array = item[0]
	var texture: Texture2D = props[item[1]]
	var tall: float = PROP_HEIGHT[item[1]] * at[2]
	var wide := tall * texture.get_width() / texture.get_height()
	var haze := clampf((at[3] - 450.0) / 1300.0, 0.0, 0.9)
	front.draw_texture_rect(texture, Rect2(at[0] - wide / 2, at[1] - tall, wide, tall), false, Color.WHITE.lerp(FOG, haze))

func _draw_rider() -> void:
	var turning: float = race.drift if race.drift != 0 else (signf(race.steer) if absf(race.steer) > 0.3 else 0.0)
	var column := 1 + int(turning)
	var step := int(race.distance_run / 34.0) % 2
	var bounce := sin(race.hop / 12.0 * PI) * 22.0
	var shake := Vector2.ZERO
	if race.offroad and absf(race.speed) > 1.0:
		shake = Vector2(ticks % 2 * 4 - 2, ticks % 3 * 3 - 3)
	var feet := Vector2(480 - race.drift * 18, 478) + shake
	front.draw_set_transform(Vector2(feet.x, feet.y - 6), 0, Vector2(1, 0.25))
	front.draw_circle(Vector2.ZERO, 76, Color(0, 0, 0, 0.4))
	front.draw_set_transform(Vector2.ZERO)
	if race.boost > 0:
		for n in 3:
			var tail := feet + Vector2((n - 1) * 46, -34)
			var length := 40.0 + (ticks * 7 + n * 13) % 34
			front.draw_colored_polygon(PackedVector2Array([tail + Vector2(-16, 0), tail + Vector2(0, length), tail + Vector2(16, 0)]), Color(1.0, 0.55, 0.1, 0.9))
			front.draw_colored_polygon(PackedVector2Array([tail + Vector2(-7, 0), tail + Vector2(0, length * 0.6), tail + Vector2(7, 0)]), Color(1.0, 0.95, 0.5))
	var size := FRAME * RIDER_SCALE
	var lean: float = race.drift * 0.09
	front.draw_set_transform(feet + Vector2(0, -bounce), lean, Vector2.ONE)
	front.draw_texture_rect_region(rider, Rect2(-size.x / 2, -68 * RIDER_SCALE, size.x, size.y), Rect2(Vector2(column, step) * FRAME, FRAME))
	front.draw_set_transform(Vector2.ZERO)
	_draw_dust(feet)

# Faíscas da derrapagem (a cor mostra o turbo carregado) e poeira fora da pista.
func _draw_dust(feet: Vector2) -> void:
	if race.drift != 0:
		var color: Color = [Color(0.85, 0.8, 0.75), Color(0.35, 0.75, 1.0), Color(1.0, 0.6, 0.1), Color(0.85, 0.35, 1.0)][race.drift_level()]
		for side in [-1.0, 1.0]:
			for n in 7:
				var age := float((ticks * 3 + n * 11) % 28)
				var at := feet + Vector2(side * 56 - race.drift * age * 2.6, -6 - sin(age / 28.0 * PI) * (16 + n % 3 * 10))
				front.draw_rect(Rect2(at, Vector2(11, 11) * (1.0 - age / 40.0)), color)
	elif race.offroad and absf(race.speed) > 1.5:
		for n in 8:
			var age := float((ticks * 2 + n * 9) % 24)
			front.draw_circle(feet + Vector2((n - 3.5) * 22, -4 + age * 0.8), 9.0 - age * 0.3, Color(0.55, 0.4, 0.34, 0.8 - age / 34.0))

func _text(value: String, x: float, y: float, size: int, color := Color.WHITE) -> void:
	Look.text(front, value, x, y, size, color)

func _draw_hud() -> void:
	var info: Dictionary = Data.FIGHTERS[race.id]
	if race.boost > 0: # riscos de velocidade nas bordas
		for n in 16:
			var side := -1.0 if n % 2 else 1.0
			var y := 90.0 + fposmod(n * 71.0 + ticks * 23.0, 420.0)
			front.draw_line(Vector2(480 + side * 480, y), Vector2(480 + side * (330 + n % 3 * 40), y - 6 + (y - 270) * 0.12), Color(1, 1, 1, 0.55), 3)
	_text("VOLTA  %d/%d" % [clampi(race.lap, 1, Race.LAPS), Race.LAPS], 100, 40, 30, Color(1, 0.85, 0.35))
	_text(Race.format_time(race.time), 100, 70, 24)
	if not race.lap_times.is_empty():
		_text("melhor %s" % Race.format_time(race.lap_times.min()), 100, 94, 15, Color(0.6, 1, 0.7))
	_text("%s  •  %s" % [info.name.to_upper(), Data.CREATURES[race.id].to_upper()], 480, 28, 20, info.color.lightened(0.3))
	_text("%d km/h" % roundi(absf(race.speed) * 22), 860, 510, 30)
	var needed: float = Race.DRIFT_LEVELS[2]
	front.draw_rect(Rect2(380, 508, 200, 14), Color(0, 0, 0, 0.7))
	var colors := [Color(0.8, 0.8, 0.8), Color(0.35, 0.75, 1.0), Color(1.0, 0.6, 0.1), Color(0.85, 0.35, 1.0)]
	front.draw_rect(Rect2(382, 510, 196 * minf(race.charge / needed, 1.0), 10), colors[race.drift_level()])
	for mark in [Race.DRIFT_LEVELS[0], Race.DRIFT_LEVELS[1]]:
		front.draw_rect(Rect2(382 + 196 * mark / needed, 508, 2, 14), Color.WHITE)
	_draw_map()
	if race.countdown > 0:
		var number := ceili(race.countdown / 60.0)
		_text(str(number), 480, 250, 110 + (race.countdown % 60) / 2, Color(1, 0.85, 0.35))
		var drift_key := "RB" if Controls.uses_pad(0) else "K"
		var gas_key := "A ou RT" if Controls.uses_pad(0) else "W"
		_text("%s acelera    %s derrapa na curva (segure e solte para o turbo)" % [gas_key, drift_key], 480, 300, 18)
		_text("Dica: aperte para acelerar quando aparecer o 1", 480, 326, 15, Color(0.7, 0.9, 1))
	elif race.time < 45:
		_text("JÁ!", 480, 240, 100, Color(0.45, 1, 0.55))
	if banner_age < 100 and not race.finished:
		_text(banner, 480, 150, 52 + maxi(0, 10 - banner_age) * 4, Color(1, 0.85, 0.35))
	if race.wrong_way > 45 and ticks / 12 % 2 == 0:
		_text("CONTRAMÃO!", 480, 200, 50, Color(1, 0.3, 0.2))
	if race.finished:
		front.draw_rect(Rect2(280, 90, 400, 260), Color(0, 0, 0, 0.82))
		_text("CHEGADA!", 480, 140, 48, Color(1, 0.85, 0.35))
		for n in race.lap_times.size():
			_text("Volta %d    %s" % [n + 1, Race.format_time(race.lap_times[n])], 480, 185 + n * 30, 20)
		var total := 0
		for lap_time in race.lap_times:
			total += lap_time
		_text("Total  %s" % Race.format_time(total), 480, 290, 28, Color(0.45, 1, 0.55))
		_text("Start / Enter: correr de novo    Select / Esc: sair", 480, 330, 15)
	if paused:
		front.draw_rect(Rect2(0, 0, 960, 540), Color(0, 0, 0, 0.7))
		_text("PAUSA", 480, 240, 60, Color(1, 0.85, 0.35))
		_text("Start / Enter: continuar    Select / Esc: sair", 480, 300, 20)

func _draw_map() -> void:
	var origin := Vector2(786, 8)
	var factor := 166.0 / float(race.track.size)
	var line := PackedVector2Array()
	for point in race.path:
		line.append(origin + point * factor)
	line.append(line[0])
	front.draw_rect(Rect2(origin, Vector2(166, 166)), Color(0, 0, 0, 0.55))
	front.draw_polyline(line, Color(0.75, 0.72, 0.78), 7)
	front.draw_rect(Rect2(line[0] - Vector2(7, 2), Vector2(14, 4)), Color.WHITE)
	front.draw_circle(origin + race.pos * factor, 5, Data.FIGHTERS[race.id].color)
	front.draw_arc(origin + race.pos * factor, 6, 0, TAU, 10, Color.WHITE, 2)
