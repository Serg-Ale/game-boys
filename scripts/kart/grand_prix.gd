# O grande prêmio: doze corredores, batidas, vácuo, orbes, poderes, supremo e transformação.
extends RefCounted

const Data = preload("res://scripts/data.gd")
const Race = preload("res://scripts/kart/race.gd")
const Supers = preload("res://scripts/supers.gd")

const RADIUS := 34.0          # tamanho de cada montaria nas batidas
const ORB_RESPAWN := 240
const ROULETTE := 55
const ORBS_PER_ROW := 5
const MAX_ENERGY := 100.0
const FORM_FRAMES := 480
const FORM_FACTOR := 1.15
const SLIPSTREAM := 80        # frames no vácuo de alguém para ganhar impulso
const SPIN := 75

# Cada poder tem um elemento: vantagem faz o rival rodar por mais tempo.
const ITEMS := {
	"fireball": {"name": "Bola de Fogo", "element": "fire"},
	"ice": {"name": "Poça de Gelo", "element": "water"},
	"sand": {"name": "Areia Movediça", "element": "earth"},
	"gust": {"name": "Rajada (turbo)", "element": "air"},
	"bolt": {"name": "Raio no Líder", "element": "electric"},
	"shell": {"name": "Casca de Raízes", "element": "plant"},
}

var racers: Array = []      # o primeiro é o jogador
var states: Array = []      # poder, energia e transformação de cada um
var orbs: Array = []        # {pos, wait}
var hazards: Array = []     # {kind, pos, owner, age}
var shots: Array = []       # bolas de fogo {pos, index, owner, age}
var events: Array = []      # para sons, avisos e vibração
var order: Array = []       # índices dos corredores, do primeiro ao último
var rng := RandomNumberGenerator.new()
var track: Dictionary
var frame := 0

func _init(track_data: Dictionary, player_id: String, seed_value := 0, rivals := 11) -> void:
	track = track_data
	if seed_value:
		rng.seed = seed_value
	else:
		rng.randomize()
	var ids: Array = Data.ROSTER.filter(func(k): return k != player_id)
	for i in range(ids.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap = ids[i]
		ids[i] = ids[j]
		ids[j] = swap
	ids = [player_id] + ids.slice(0, rivals)
	var path: Array = track.path
	var count := ids.size()
	for i in count:
		var racer = Race.new(track, ids[i])
		# Grid de largada: fileiras de três; o jogador sai do fundo.
		var slot: int = count - 1 if i == 0 else i - 1
		var back := 4 + (slot / 3) * 6
		var side := (slot % 3 - 1) * 105.0
		var at: int = wrapi(-back, 0, path.size())
		var forward: Vector2 = (racer.path[(at + 2) % path.size()] - racer.path[at]).normalized()
		racer.index = at
		racer.pos = racer.path[at] + forward.orthogonal() * side
		racer.heading = forward.angle()
		racer.travel = racer.heading
		racer.lane = side * 0.8
		racers.append(racer)
		states.append({"item": "", "roulette": 0, "energy": 0.0, "form": 0, "formed": false, "slip": 0, "super": 0,
			"held": 0, "skill": 1.0 if i == 0 else rng.randf_range(0.9, 0.995), "previous": {}, "finish_time": 0})
	for row in track.orbs:
		var i := int(row)
		var forward: Vector2 = (racers[0].path[(i + 1) % path.size()] - racers[0].path[i]).normalized()
		for n in ORBS_PER_ROW:
			orbs.append({"pos": racers[0].path[i] + forward.orthogonal() * (n - (ORBS_PER_ROW - 1) / 2.0) * 62.0, "wait": 0})
	_rank()

# input do jogador: accel, brake, drift, steer, item, super, transform.
func step(input: Dictionary) -> void:
	frame += 1
	var player = racers[0]
	for i in racers.size():
		var racer = racers[i]
		var state: Dictionary = states[i]
		var command: Dictionary = input if i == 0 else _pilot(i)
		_buttons(i, command)
		var boost_factor := FORM_FACTOR if state.form > 0 else 1.0
		var elastic := 1.0
		if i != 0 and not player.finished:
			# Elástico: quem ficou para trás corre um pouco mais; quem disparou, um pouco menos.
			var gap: float = racer.progress() - player.progress()
			elastic = clampf(1.0 - gap / 700.0, 0.9, 1.09)
		racer.factor = state.skill * elastic * boost_factor
		racer.step(command)
		state.form = maxi(state.form - 1, 0)
		state.super = maxi(state.super - 1, 0)
		if state.roulette > 0:
			state.roulette -= 1
			if state.roulette == 0:
				state.item = _roll(i)
				if i == 0:
					events.append({"type": "got"})
		if racer.drift != 0:
			_energy(i, 0.09 + racer.drift_level() * 0.05)
		if racer.finished and state.finish_time == 0:
			state.finish_time = racer.time
		for event in racer.events:
			if i == 0:
				events.append({"type": event})
		racer.events.clear()
	if player.countdown == 0:
		_collide()
		_slipstream()
		_orbs()
		_hazards()
		_shots()
	_rank()

# Usar poder, supremo e transformação, na borda do botão.
func _buttons(i: int, command: Dictionary) -> void:
	var state: Dictionary = states[i]
	var before: Dictionary = state.previous
	state.previous = command.duplicate()
	if racers[i].countdown > 0 or racers[i].finished or racers[i].stun > 0:
		return
	if command.get("item", false) and not before.get("item", false) and state.item != "":
		_use_item(i)
	if command.get("super", false) and not before.get("super", false) and state.energy >= MAX_ENERGY:
		_use_super(i)
	if command.get("transform", false) and not before.get("transform", false) and can_transform(i):
		state.formed = true
		state.form = FORM_FRAMES
		racers[i].boost = maxi(racers[i].boost, 60)
		events.append({"type": "transform", "who": i})

# Uma vez por corrida, a partir da segunda volta.
func can_transform(i: int) -> bool:
	return not states[i].formed and racers[i].lap >= 2 and not racers[i].finished

func _pilot(i: int) -> Dictionary:
	var racer = racers[i]
	var state: Dictionary = states[i]
	if rng.randf() < 0.006:
		racer.lane = rng.randf_range(-115.0, 115.0)
	var command: Dictionary = racer.autopilot()
	if state.item != "":
		state.held += 1
		command.item = state.held > 40 and rng.randf() < 0.03
		if command.item:
			state.held = 0
	command.super = state.energy >= MAX_ENERGY and rng.randf() < 0.02
	command.transform = can_transform(i) and rng.randf() < 0.004
	# Turbos ocasionais imitam a derrapagem.
	if racer.countdown == 0 and racer.stun == 0 and rng.randf() < 0.0022:
		racer.boost = maxi(racer.boost, 32)
	return command

func _energy(i: int, amount: float) -> void:
	var before: float = states[i].energy
	states[i].energy = minf(before + amount, MAX_ENERGY)
	if i == 0 and before < MAX_ENERGY and states[i].energy >= MAX_ENERGY:
		events.append({"type": "ready"})

func place_of(i: int) -> int:
	return order.find(i) + 1

func _rank() -> void:
	order = range(racers.size())
	order.sort_custom(func(a, b):
		var x: Dictionary = states[a]
		var y: Dictionary = states[b]
		if x.finish_time > 0 or y.finish_time > 0:
			if x.finish_time > 0 and y.finish_time > 0:
				return x.finish_time < y.finish_time
			return x.finish_time > 0
		return racers[a].progress() > racers[b].progress())

# Batidas: o mais pesado empurra mais.
func _collide() -> void:
	for i in racers.size():
		for j in range(i + 1, racers.size()):
			var a = racers[i]
			var b = racers[j]
			var between: Vector2 = b.pos - a.pos
			var distance := between.length()
			if distance >= RADIUS * 2 or distance < 0.01:
				continue
			var push := between / distance * (RADIUS * 2 - distance)
			var heavy_a: float = 5.0 + Data.FIGHTERS[a.id].get("weight", 0)
			var heavy_b: float = 5.0 + Data.FIGHTERS[b.id].get("weight", 0)
			a.pos -= push * (heavy_b / (heavy_a + heavy_b))
			b.pos += push * (heavy_a / (heavy_a + heavy_b))
			# Com supremo ou transformado, quem encosta roda.
			for pair in [[i, j], [j, i]]:
				if states[pair[0]].super > 0 and states[pair[1]].super == 0:
					_hit(pair[1], Data.FIGHTERS[racers[pair[0]].id].clan, pair[0])
			if (i == 0 or j == 0) and distance < RADIUS * 1.7 and frame % 12 == 0:
				events.append({"type": "bump"})

# Andar colado atrás de alguém dá um impulso.
func _slipstream() -> void:
	for i in racers.size():
		var me = racers[i]
		var tucked := false
		for j in racers.size():
			if i == j:
				continue
			var to: Vector2 = racers[j].pos - me.pos
			var distance := to.length()
			if distance > 80 and distance < 330 and absf(angle_difference(me.travel, to.angle())) < 0.16 and me.speed > me.max_speed * 0.7:
				tucked = true
				break
		states[i].slip = states[i].slip + 1 if tucked else maxi(states[i].slip - 3, 0)
		if states[i].slip >= SLIPSTREAM:
			states[i].slip = 0
			me.boost = maxi(me.boost, 45)
			if i == 0:
				events.append({"type": "slipstream"})

func _orbs() -> void:
	for orb in orbs:
		if orb.wait > 0:
			orb.wait -= 1
			continue
		for i in racers.size():
			if racers[i].pos.distance_to(orb.pos) > RADIUS + 18:
				continue
			orb.wait = ORB_RESPAWN
			_energy(i, 6.0)
			if states[i].item == "" and states[i].roulette == 0:
				states[i].roulette = ROULETTE
				if i == 0:
					events.append({"type": "orb"})
			break

# Na frente saem defesas; atrás, ajuda para alcançar.
func _roll(i: int) -> String:
	var rank := float(place_of(i) - 1) / maxf(racers.size() - 1, 1.0)
	var pool: Array = ["ice", "sand", "shell", "fireball"] if rank < 0.25 else (
		["fireball", "fireball", "gust", "ice", "shell", "sand"] if rank < 0.65 else ["gust", "gust", "bolt", "fireball", "gust"])
	return pool[rng.randi() % pool.size()]

func _use_item(i: int) -> void:
	var kind: String = states[i].item
	states[i].item = ""
	var racer = racers[i]
	var back := Vector2.from_angle(racer.heading) * -90.0
	match kind:
		"fireball":
			shots.append({"pos": racer.pos + Vector2.from_angle(racer.heading) * 70.0, "index": racer.index, "owner": i, "age": 0})
		"ice", "sand":
			hazards.append({"kind": kind, "pos": racer.pos + back, "owner": i, "age": 0})
		"gust":
			racer.boost = maxi(racer.boost, 90)
		"shell":
			racer.shield = 420
		"bolt":
			var leader: int = order[0] if order[0] != i else order[1]
			_hit(leader, "electric", i)
			events.append({"type": "lightning", "who": leader})
	events.append({"type": "use", "who": i, "item": kind})

# A criatura aparece: quem está logo à frente roda, e o dono dispara.
func _use_super(i: int) -> void:
	states[i].energy = 0.0
	states[i].super = 200
	var racer = racers[i]
	racer.boost = maxi(racer.boost, 200)
	racer.stun = 0
	var element: String = Data.FIGHTERS[racer.id].clan
	var mine := place_of(i) - 1
	for step_ahead in range(1, 5):
		if mine - step_ahead >= 0:
			_hit(order[mine - step_ahead], element, i)
	events.append({"type": "super", "who": i})

# Faz um corredor rodar, se não estiver protegido.
func _hit(i: int, element: String, by: int) -> bool:
	var racer = racers[i]
	if racer.finished or states[i].super > 0 or racer.stun > 0:
		return false
	if racer.shield > 0:
		racer.shield = 0
		events.append({"type": "blocked", "who": i})
		return false
	var scale := Data.multiplier(element, Data.FIGHTERS[racer.id].clan)
	racer.stun = roundi(SPIN * scale * (0.8 if Data.FIGHTERS[racer.id].passive == "shell" else 1.0))
	_energy(i, 14.0)
	if by != i:
		_energy(by, 16.0)
	events.append({"type": "hit", "who": i, "by": by})
	return true

func _hazards() -> void:
	var gone: Array = []
	for hazard in hazards:
		hazard.age += 1
		if hazard.age > 900:
			gone.append(hazard)
			continue
		for i in racers.size():
			if (i == hazard.owner and hazard.age < 60) or racers[i].pos.distance_to(hazard.pos) > 70:
				continue
			if hazard.kind == "sand":
				if states[i].super == 0:
					racers[i].slowed = maxi(racers[i].slowed, 50)
			elif _hit(i, "water", hazard.owner):
				gone.append(hazard)
				break
	hazards = hazards.filter(func(h): return not h in gone)

# A bola de fogo segue o traçado até pegar alguém.
func _shots() -> void:
	var gone: Array = []
	var path: PackedVector2Array = racers[0].path
	var n := path.size()
	for shot in shots:
		shot.age += 1
		for k in range(1, 6):
			var i: int = (shot.index + k) % n
			if shot.pos.distance_to(path[i]) < shot.pos.distance_to(path[shot.index]):
				shot.index = i
		var aim: Vector2 = path[(shot.index + 6) % n]
		# Perto de um rival, corrige o rumo na direção dele.
		for i in racers.size():
			if i != shot.owner and shot.pos.distance_to(racers[i].pos) < 240:
				aim = racers[i].pos
				break
		shot.pos = shot.pos.move_toward(aim, 18.0)
		for i in racers.size():
			if i != shot.owner and racers[i].pos.distance_to(shot.pos) < RADIUS + 26:
				_hit(i, "fire", shot.owner)
				gone.append(shot)
				break
		if shot.age > 240:
			gone.append(shot)
	shots = shots.filter(func(s): return not s in gone)
