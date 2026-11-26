# Lógica da corrida: direção, derrapagem, turbo e voltas. Não desenha: um step() = um frame.
extends RefCounted

const Data = preload("res://scripts/data.gd")

const LAPS := 3
const COUNTDOWN := 180
const DRIFT_LEVELS := [40.0, 95.0, 165.0] # carga para turbo azul, laranja e roxo
const DRIFT_BOOSTS := [32, 55, 85]        # frames de turbo de cada nível
const PERFECT_START := [20, 55]           # acelerar quando faltam esses frames dá arrancada
const PAD_BOOST := 40
const BOOST_FACTOR := 1.38
const OFFROAD_FACTOR := 0.5
const WALL := 185.0                       # além da borda da pista, uma parede invisível

var track: Dictionary
var path := PackedVector2Array()
var id: String
var pos := Vector2.ZERO
var heading := 0.0
var travel := 0.0        # direção em que a montaria realmente anda (derrapando, difere)
var speed := 0.0
var steer := 0.0
var max_speed := 7.0
var accel := 0.12
var turn := 0.04
var drift := 0           # -1 esquerda, 1 direita
var charge := 0.0
var boost := 0
var hop := 0
var offroad := false
var index := 0
var lap := 0
var halfway := false
var countdown := COUNTDOWN
var time := 0
var lap_started := 0
var lap_times: Array = []
var finished := false
var wrong_way := 0
var distance_run := 0.0
var events: Array = []   # sons e avisos; quem desenha esvazia
var _was_accel := false
var _was_drift := false
var _early := false
var _perfect := false

func _init(track_data: Dictionary, fighter_id: String) -> void:
	track = track_data
	id = fighter_id
	for point in track.path:
		path.append(Vector2(point[0], point[1]))
	var stats: Dictionary = Data.FIGHTERS[fighter_id]
	var weight: float = stats.get("weight", 0)
	# Pesados correm mais; leves aceleram e viram melhor.
	max_speed = 7.0 + weight * 0.13
	accel = 0.12 - weight * 0.01
	turn = 0.041 - weight * 0.0013 + (stats.walk - 4.3) * 0.0012
	index = path.size() - 5
	pos = path[index]
	heading = (path[(index + 3) % path.size()] - pos).angle()
	travel = heading

# input: accel, brake, drift (bool) e steer (-1 a 1).
func step(input: Dictionary) -> void:
	var gas: bool = input.get("accel", false)
	var drifting: bool = input.get("drift", false)
	steer = clampf(input.get("steer", 0.0), -1.0, 1.0)
	if countdown > 0:
		_count_down(gas)
		_was_accel = gas
		_was_drift = drifting
		return
	if not finished:
		time += 1
	else:
		gas = false
		drifting = false
		steer = clampf(angle_difference(heading, _aim(8)) * 2.5, -1.0, 1.0) # segue sozinho depois da chegada
		speed = move_toward(speed, 3.5, 0.08)
	hop = maxi(hop - 1, 0)

	var top := max_speed * (OFFROAD_FACTOR if offroad and boost == 0 else 1.0)
	if boost > 0:
		boost -= 1
		top = max_speed * BOOST_FACTOR
		speed = move_toward(speed, top, 0.35)
	elif gas:
		if speed < top:
			speed = move_toward(speed, top, accel * (1.0 - clampf(speed / top, 0.0, 1.0) * 0.65))
	elif input.get("brake", false):
		speed = maxf(speed - 0.22, -2.2)
	elif not finished:
		speed = move_toward(speed, 0.0, 0.05)
	if speed > top and boost == 0:
		speed = move_toward(speed, top, 0.28 if offroad else 0.08)

	_drift_step(drifting)
	if drift != 0:
		heading += drift * turn * (1.0 + 0.65 * steer * drift)
	else:
		var grip := clampf(speed / 2.5, -1.0, 1.0)
		heading += steer * turn * grip * (1.0 - 0.22 * clampf(absf(speed) / max_speed, 0.0, 1.0))
	heading = wrapf(heading, -PI, PI)
	travel = lerp_angle(travel, heading - drift * 0.3, 0.12 if drift != 0 else 0.35)
	pos += Vector2.from_angle(travel) * speed
	distance_run += absf(speed)
	_follow_track()
	_was_accel = gas
	_was_drift = drifting

func _count_down(gas: bool) -> void:
	if countdown % 60 == 0:
		events.append("count")
	if gas and not _was_accel:
		_early = countdown > PERFECT_START[1]
		_perfect = countdown <= PERFECT_START[1] and countdown >= PERFECT_START[0]
	elif not gas:
		_perfect = false
	countdown -= 1
	if countdown == 0:
		events.append("go")
		if _perfect and gas:
			boost = PAD_BOOST
			speed = max_speed * 0.6
			events.append("boost")

# Segurar derrapagem virando carrega o turbo; soltar dispara.
func _drift_step(held: bool) -> void:
	if held and not _was_drift and speed > 2.0:
		hop = 12
	if drift == 0:
		if held and absf(steer) > 0.25 and speed > 3.5 and not offroad:
			drift = 1 if steer > 0 else -1
			charge = 0.0
		return
	if speed < 2.5 or offroad: # perdeu a derrapagem, sem turbo
		drift = 0
		charge = 0.0
		return
	if not held:
		var level := drift_level()
		if level > 0:
			boost = maxi(boost, DRIFT_BOOSTS[level - 1])
			events.append("boost")
		drift = 0
		charge = 0.0
		return
	var before := drift_level()
	charge += 1.0 + 0.6 * maxf(steer * drift, 0.0)
	if drift_level() > before:
		events.append("charge")

func drift_level() -> int:
	var level := 0
	for needed in DRIFT_LEVELS:
		if charge >= needed:
			level += 1
	return level

# Ponto do traçado mais próximo, borda da pista, setas de turbo e voltas.
func _follow_track() -> void:
	var n := path.size()
	var best := index
	var best_distance := INF
	for offset in range(-14, 15):
		var i := wrapi(index + offset, 0, n)
		var d := pos.distance_squared_to(path[i])
		if d < best_distance:
			best = i
			best_distance = d
	var previous := index
	index = best
	var next := path[(index + 1) % n]
	var closest := Geometry2D.get_closest_point_to_segment(pos, path[wrapi(index - 1, 0, n)], path[index])
	var other := Geometry2D.get_closest_point_to_segment(pos, path[index], next)
	if pos.distance_squared_to(other) < pos.distance_squared_to(closest):
		closest = other
	var away := pos.distance_to(closest)
	offroad = away > track.half + 16
	var limit: float = track.half + WALL
	if away > limit:
		pos = closest + (pos - closest).normalized() * limit
		if absf(speed) > 2.0:
			events.append("bump")
		speed *= 0.5
	for pad in track.boosts:
		if absi(index - int(pad)) <= 2 and away < 55.0:
			if boost < PAD_BOOST - 10:
				events.append("boost")
			boost = maxi(boost, PAD_BOOST)

	if index > n * 0.4 and index < n * 0.6:
		halfway = true
	if previous > n * 0.75 and index < n * 0.25 and (lap == 0 or halfway):
		_cross_line()
	elif previous < n * 0.25 and index > n * 0.75 and lap > 0: # voltou de ré pela linha
		lap -= 1
		halfway = true
	var along := (next - path[index]).angle()
	wrong_way = wrong_way + 1 if absf(angle_difference(along, travel)) > 2.0 and speed > 1.5 else 0

func _cross_line() -> void:
	halfway = false
	lap += 1
	if lap == 1 or finished:
		lap_started = time
		return
	if lap - 1 > lap_times.size():
		lap_times.append(time - lap_started)
		lap_started = time
		if lap > LAPS:
			finished = true
			events.append("finish")
		else:
			events.append("lap")

func _aim(ahead: int) -> float:
	return (path[(index + ahead) % path.size()] - pos).angle()

# Piloto automático: usado nos testes e, depois, pelos corredores da CPU.
func autopilot() -> Dictionary:
	var difference := angle_difference(heading, _aim(9))
	return {"accel": not (absf(difference) > 0.9 and speed > 4.5), "brake": absf(difference) > 0.9 and speed > 4.5,
		"steer": clampf(difference * 3.0, -1.0, 1.0), "drift": false}

static func format_time(frames: int) -> String:
	var hundredths := frames * 100 / 60
	return "%d:%02d.%02d" % [hundredths / 6000, hundredths / 100 % 60, hundredths % 100]

static func load_track(name: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://assets/kart/track_%s.json" % name))
