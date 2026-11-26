# Lógica de um lutador. Não lê teclado nem desenha: recebe os comandos a cada frame.
extends RefCounted

const Data = preload("res://scripts/data.gd")
const Supers = preload("res://scripts/supers.gd")

enum State { IDLE, WALK, CROUCH, JUMP, ATTACK, SPECIAL, HITSTUN, BLOCKSTUN, KO, SUPER, DASH, DOWN, THROW }

const FLOOR_Y := 450.0
const GRAVITY := 0.9
const JUMP_SPEED := 17.0
const HALF_WIDTH := 30.0
const ERUPTION_STEP := 6 # frames de cada labareda da Erupção
const ERUPTION_FIRST := 70.0
const ERUPTION_GAP := 85.0
const SPLASH_FRAMES := 8 # parte do Espelho que fere quem está colado
const HALF_CIRCLE_WINDOW := 30 # frames para completar ← ↓ → + Y
const MAX_ENERGY := 100.0
const MOTION_WINDOW := 15 # frames para completar ↓ → + soco

const FORM_SPEED := 1.18 # bônus da transformação
const FORM_POWER := 1.12
const DIVE_TURN := 14 # frames subindo antes de mergulhar
const DIG_EMERGE := 8 # frames finais do mergulho, já atacando fora da areia
const BARRAGE_STEP := 6 # frames entre os golpes da metralhadora
const BUFFER := 8 # um botão apertado um pouco antes da hora ainda vale
const DOUBLE_TAP := 14 # frames entre os dois toques do dash
const DASH_FRAMES := 14
const BACKDASH_FRAMES := 16
const DOWN_FRAMES := 38 # no chão, sem poder ser atingido
const MAX_JUGGLE := 4 # acertos no ar antes de ficar invulnerável até cair
const THROW := {"startup": 3, "active": 3, "recovery": 24, "range": 100.0, "damage": 110}

# Frame data
# "stand", "crouch" e "air" são a altura da hitbox em relação aos pés.
const MOVES := {
	"punch": {"startup": 5, "active": 3, "recovery": 10, "damage": 60, "hitstun": 18, "blockstun": 10, "push": 4.0,
		"reach": 70.0, "height_px": 25.0, "stand": -135.0, "crouch": -45.0, "air": -80.0},
	"kick": {"startup": 9, "active": 4, "recovery": 16, "damage": 90, "hitstun": 22, "blockstun": 13, "push": 10.0,
		"reach": 95.0, "height_px": 30.0, "stand": -90.0, "crouch": -30.0, "air": -70.0},
	# frente + chute: joga o adversário para o alto, abrindo o combo aéreo
	"launch": {"startup": 11, "active": 4, "recovery": 18, "damage": 70, "hitstun": 40, "blockstun": 13, "push": 3.0,
		"reach": 85.0, "height_px": 120.0, "stand": -165.0, "crouch": -165.0, "air": -165.0, "launch": -15.0},
	# baixo + chute: rasteira que derruba
	"sweep": {"startup": 10, "active": 4, "recovery": 20, "damage": 80, "hitstun": 30, "blockstun": 14, "push": 6.0,
		"reach": 105.0, "height_px": 28.0, "stand": -28.0, "crouch": -28.0, "air": -28.0, "knockdown": true},
}
const SPECIAL_HITSTUN := 24
const SPECIAL_BLOCKSTUN := 14
const FLURRY_BONUS := 3 # frames a menos de recuperação (passiva "flurry")
const SLOW_FACTOR := 0.55
const ROOTED_TYPES := ["rush", "slide", "armor", "teleport", "uppercut", "pounce", "phase", "dig", "dive"]

var id: String # qual lutador
var element: String # o clã
var stats: Dictionary
var health: int
var pos: Vector2
var vel := Vector2.ZERO
var facing := 1
var state: State = State.IDLE
var frame := 0
var stun := 0
var burn := 0
var root := 0 # frames sem poder andar nem pular
var slow := 0
var air_jumped := false
var armor_used := false
var opponent := 0.0 # posição do adversário, para o teleporte
var energy := 0.0 # enche ao acertar e ao apanhar; cheia, libera o supremo
var super_locked := false # já há um supremo em andamento
var wants_super := false
var slot := "neutral" # especial em uso
var cooldowns := {"neutral": 0, "forward": 0, "down": 0}
var crouching := false
var has_hit := false # o golpe atual já tocou o adversário (acerto ou defesa)
var wants_projectile := false
var input := {}
var previous := {}
var history: Array = [] # direções recentes, relativas ao lado que o lutador encara
var move := "punch"
var can_transform := false # venceu um round
var transformed := false
var wants_form := false
var air_attack := false # o golpe atual começou no ar
var chain := 0 # socos já encadeados
var falling := false # foi lançado ou derrubado: vai cair no chão
var juggle := 0
var back_dash := false
var grab_age := 99 # há quantos frames apertou agarrar (para escapar de agarrão)
var _buffer := {}
var _taps := {"forward": -99, "back": -99}
var _clock := 0
var _flow := 0

func _init(fighter_id: String, x: float, face: int) -> void:
	id = fighter_id
	stats = Data.FIGHTERS[fighter_id]
	element = stats.clan
	health = stats.health
	pos = Vector2(x, FLOOR_Y)
	facing = face

func held(action: String) -> bool:
	return input.get(action, false)

func pressed(action: String) -> bool:
	return input.get(action, false) and not previous.get(action, false)

func buffered(action: String) -> bool:
	return _buffer.get(action, 0) > 0

func forward() -> bool:
	return held("right") if facing > 0 else held("left")

func back() -> bool:
	return held("left") if facing > 0 else held("right")

func on_ground() -> bool:
	return pos.y >= FLOOR_Y

func is_free() -> bool:
	return state in [State.IDLE, State.WALK, State.CROUCH]

func invulnerable() -> bool:
	if state == State.DOWN or (falling and juggle > MAX_JUGGLE):
		return true
	if special_active("phase") or underground():
		return true
	return state == State.DASH and back_dash and frame <= 8

# Debaixo da areia: do mergulho até pouco antes de emergir.
func underground() -> bool:
	return special_active("dig") and frame <= special_data().startup + special_data().active - DIG_EMERGE

func step(new_input: Dictionary, opponent_x: float, has_projectile: bool) -> void:
	previous = input
	input = new_input
	wants_projectile = false
	wants_super = false
	wants_form = false
	_clock += 1
	root = maxi(root - 1, 0)
	slow = maxi(slow - 1, 0)
	opponent = opponent_x
	for action in ["punch", "kick", "special", "jump", "grab", "dash", "transform"]:
		_buffer[action] = BUFFER if pressed(action) else maxi(_buffer.get(action, 0) - 1, 0)
	grab_age = 0 if pressed("grab") else grab_age + 1
	var recharge := 1
	if stats.passive == "flow":
		_flow += 1
		recharge = 2 if _flow % 5 == 0 else 1
	if transformed and _clock % 2 == 0:
		recharge += 1
	for key in cooldowns:
		cooldowns[key] = maxi(cooldowns[key] - recharge, 0)
	if is_free() and opponent_x != pos.x:
		facing = 1 if opponent_x > pos.x else -1
	history.push_back({"down": held("down"), "forward": forward(), "back": back()})
	if history.size() > HALF_CIRCLE_WINDOW:
		history.pop_front()
	frame += 1
	var double_tap := _read_double_tap()

	match state:
		State.IDLE, State.WALK, State.CROUCH:
			_control(has_projectile, double_tap)
		State.JUMP:
			if buffered("jump") and stats.passive == "double" and not air_jumped and frame > 4:
				_buffer.jump = 0
				air_jumped = true
				vel = Vector2((int(held("right")) - int(held("left"))) * stats.walk, -stats.get("jump", JUMP_SPEED) * 0.85)
			elif buffered("punch"):
				_attack("punch")
			elif buffered("kick"):
				_attack("kick")
		State.ATTACK:
			if not _cancel(has_projectile):
				var data: Dictionary = MOVES[move]
				var bonus := FLURRY_BONUS if stats.passive == "flurry" else 0
				if frame > data.startup + data.active + data.recovery + stats.get("weight", 0) - bonus:
					_enter(State.JUMP if not on_ground() else State.IDLE)
		State.SPECIAL:
			_special_step()
		State.SUPER:
			vel.x = 0
			if frame > Supers.duration(id):
				_enter(State.IDLE)
		State.DASH:
			var length := BACKDASH_FRAMES if back_dash else DASH_FRAMES
			vel.x = facing * (-10.0 if back_dash else 11.5)
			if not back_dash and frame > 5 and (buffered("punch") or buffered("kick")):
				vel.x = 0
				_attack("punch" if buffered("punch") else "kick")
			elif frame >= length:
				vel.x = 0
				_enter(State.IDLE)
		State.THROW:
			vel.x = 0
			if frame > THROW.startup + THROW.active + THROW.recovery:
				_enter(State.IDLE)
		State.DOWN:
			vel.x = 0
			if frame >= DOWN_FRAMES:
				juggle = 0
				_enter(State.IDLE)
		State.HITSTUN, State.BLOCKSTUN:
			stun -= 1
			# Quem foi lançado só se recupera depois de cair.
			if stun <= 0 and not falling:
				_enter(State.JUMP if not on_ground() else State.IDLE)
	_physics()

# "forward" ou "back" quando a direção foi tocada duas vezes seguidas.
func _read_double_tap() -> String:
	var result := ""
	for side in ["forward", "back"]:
		var now: bool = forward() if side == "forward" else back()
		var before: bool = history.size() > 1 and history[history.size() - 2][side]
		if now and not before:
			if _clock - _taps[side] <= DOUBLE_TAP:
				result = side
				_taps[side] = -99
			else:
				_taps[side] = _clock
	return result

func _control(has_projectile: bool, double_tap: String) -> void:
	crouching = held("down")
	if buffered("transform") and can_transform and not transformed:
		_buffer.transform = 0
		transformed = true
		wants_form = true
		crouching = false
		vel.x = 0
		_enter(State.IDLE)
		return
	if _try_super() or _try_special(has_projectile):
		return
	if buffered("grab") or (buffered("punch") and buffered("kick")):
		_buffer.grab = 0
		vel.x = 0
		crouching = false
		_enter(State.THROW)
	elif buffered("punch") or buffered("kick"):
		vel.x = 0
		chain = 0
		_attack("punch" if buffered("punch") else "kick")
	elif root == 0 and (buffered("dash") or double_tap != ""):
		_buffer.dash = 0
		crouching = false
		back_dash = double_tap == "back" if double_tap != "" else back()
		_enter(State.DASH)
	elif buffered("jump") and root == 0:
		_buffer.jump = 0
		crouching = false
		air_jumped = false
		vel = Vector2((int(held("right")) - int(held("left"))) * stats.walk, -stats.get("jump", JUMP_SPEED))
		_enter(State.JUMP)
	elif crouching:
		vel.x = 0
		_set_state(State.CROUCH)
	else:
		var direction := 0 if root > 0 else int(held("right")) - int(held("left"))
		vel.x = direction * stats.walk * (SLOW_FACTOR if slow > 0 else 1.0) * (FORM_SPEED if transformed else 1.0)
		_set_state(State.WALK if direction != 0 else State.IDLE)

func _try_super() -> bool:
	# "super" é o atalho da CPU; o jogador faz a meia-lua.
	var asked := held("super") or (buffered("special") and _did_half_circle())
	if not asked or energy < MAX_ENERGY or super_locked:
		return false
	energy = 0.0
	_buffer.special = 0
	wants_super = true
	crouching = false
	vel.x = 0
	_enter(State.SUPER)
	return true

func _try_special(has_projectile: bool) -> bool:
	var wanted := _wanted_special()
	if wanted == "" or not can_use(wanted, has_projectile):
		return false
	_buffer.special = 0
	_buffer.punch = 0
	slot = wanted
	cooldowns[slot] = special_data().cooldown
	crouching = false
	vel.x = 0
	_enter(State.SPECIAL)
	return true

# Cancelamento: um golpe que tocou o adversário pode virar o próximo do combo.
func _cancel(has_projectile: bool) -> bool:
	if not has_hit or air_attack:
		return false
	var data: Dictionary = MOVES[move]
	if frame <= data.startup + 1:
		return false
	if _try_super() or _try_special(has_projectile):
		return true
	if move == "punch" and buffered("punch") and chain < 2:
		chain += 1
		_attack("punch")
		return true
	if move == "punch" and buffered("kick"):
		_attack("kick")
		return true
	if move == "kick" and buffered("kick") and forward() and chain >= 0:
		chain = -1
		_attack("kick")
		return true
	# O lançador permite saltar atrás do adversário.
	if move == "launch" and buffered("jump"):
		_buffer.jump = 0
		air_jumped = false
		vel = Vector2(facing * stats.walk * 0.6, -stats.get("jump", JUMP_SPEED))
		_enter(State.JUMP)
		return true
	return false

# Qual especial o jogador pediu: o botão com direção, ou o comando ↓ → + soco.
func _wanted_special() -> String:
	if buffered("special"):
		if held("down") and stats.specials.has("down"):
			return "down"
		if forward() and not held("down") and stats.specials.has("forward"):
			return "forward"
		return "neutral"
	if buffered("punch") and _did_motion():
		return "neutral"
	return ""

func can_use(key: String, has_projectile: bool) -> bool:
	if not stats.specials.has(key) or cooldowns[key] > 0:
		return false
	var type: String = stats.specials[key].type
	if type == "projectile":
		return not has_projectile
	return root == 0 or not type in ROOTED_TYPES

func special_data() -> Dictionary:
	return stats.specials[slot]

# Verdadeiro durante os frames ativos de um especial do tipo pedido.
func special_active(type: String) -> bool:
	if state != State.SPECIAL or special_data().type != type:
		return false
	var data := special_data()
	return frame > data.startup and frame <= data.startup + data.active

func _special_step() -> void:
	var data := special_data()
	var released: bool = frame == data.startup
	match data.type:
		"dive":
			if released:
				vel = Vector2(facing * 4.0, -15.0)
			elif frame == data.startup + DIVE_TURN:
				vel = Vector2(facing * 11.0, 9.0)
		"projectile", "trap", "wall", "rain", "quicksand", "vortex":
			wants_projectile = released
		"barrage":
			if special_active("barrage") and (frame - data.startup) % BARRAGE_STEP == 0:
				has_hit = false
		"teleport":
			if released: # reaparece do outro lado do adversário
				pos.x = clampf(opponent + facing * 90.0, HALF_WIDTH, 960.0 - HALF_WIDTH)
				facing = 1 if opponent > pos.x else -1
		"uppercut":
			if released:
				vel.y = -12.0
		"pounce": # salto em arco para cima do adversário
			if released:
				vel = Vector2(facing * data.speed, -13.0)
	if data.type in ["pounce", "dive"]:
		if on_ground() and frame > data.startup:
			vel.x = 0.0
	elif data.type in ["rush", "slide", "armor"]:
		var moving: bool = special_active(data.type) and not has_hit
		vel.x = facing * data.speed if moving else 0.0
	elif data.type == "phase": # atravessa o adversário e para do outro lado
		vel.x = facing * data.speed if special_active("phase") else 0.0
		if frame == data.startup + data.active + 1:
			facing = 1 if opponent > pos.x else -1
	elif data.type == "dig":
		var chasing: bool = underground() and absf(opponent - pos.x) > data.speed
		vel.x = signf(opponent - pos.x) * data.speed if chasing else 0.0
	elif data.type == "barrage":
		vel.x = facing * 2.0 if special_active("barrage") else 0.0
	else:
		vel.x = 0.0
	if frame > data.startup + data.active + data.recovery and on_ground():
		_enter(State.IDLE)

# Procura ↓ e, depois dele, → sem ↓.
func _did_motion() -> bool:
	var saw_down := false
	for entry in history.slice(-MOTION_WINDOW):
		if entry.down:
			saw_down = true
		elif saw_down and entry.forward:
			return true
	return false

# Meia-lua: ← depois ↓ depois → (sem ↓).
func _did_half_circle() -> bool:
	var stage := 0
	for entry in history:
		if stage == 0 and entry.back:
			stage = 1
		if stage == 1 and entry.down:
			stage = 2
		elif stage == 2 and entry.forward and not entry.down:
			return true
	return false

func gain_energy(amount: float) -> void:
	energy = minf(energy + amount, MAX_ENERGY)

func _physics() -> void:
	if not on_ground() or vel.y < 0:
		vel.y += GRAVITY
		# Leveza: planar segurando o pulo.
		if stats.passive == "glide" and held("jump") and state in [State.JUMP, State.ATTACK]:
			vel.y = minf(vel.y, 1.8)
	pos += vel
	if pos.y >= FLOOR_Y and vel.y >= 0:
		pos.y = FLOOR_Y
		vel.y = 0
		air_jumped = false
		if state == State.JUMP or (state == State.ATTACK and air_attack):
			vel.x = 0
			_enter(State.IDLE)
		elif falling and state == State.HITSTUN:
			falling = false
			vel.x = 0
			_enter(State.DOWN)
	if on_ground() and state in [State.HITSTUN, State.BLOCKSTUN, State.KO]:
		vel.x *= 0.8

func _attack(name: String) -> void:
	if name == "kick" and on_ground():
		if held("down"):
			name = "sweep"
		elif forward():
			name = "launch"
	_buffer.punch = 0
	_buffer.kick = 0
	move = name
	air_attack = not on_ground()
	crouching = on_ground() and held("down")
	_enter(State.ATTACK)

func _enter(new_state: State) -> void:
	state = new_state
	frame = 0
	has_hit = false
	armor_used = false

func _set_state(new_state: State) -> void:
	if state != new_state:
		_enter(new_state)

func hurtbox() -> Rect2:
	if invulnerable():
		return Rect2(-9999, -9999, 0, 0)
	return body_box()

# Corpo do lutador, mesmo quando não pode ser atingido.
func body_box() -> Rect2:
	var height := 100.0 if crouching else 150.0
	if special_active("slide"):
		height = 60.0
	return Rect2(pos.x - HALF_WIDTH, pos.y - height, HALF_WIDTH * 2, height)

# Área do golpe normal atual, mesmo que já tenha acertado.
func attack_box() -> Rect2:
	var data: Dictionary = MOVES[move]
	var height: String = "air" if air_attack else ("crouch" if crouching else "stand")
	var reach: float = data.reach * stats.get("reach", 1.0)
	var left: float = pos.x + 20.0 if facing > 0 else pos.x - 20.0 - reach
	return Rect2(left, pos.y + data[height], reach, data.height_px)

# Hitbox do golpe de corpo (normal ou especial), ou retângulo vazio fora dos frames ativos.
func hitbox() -> Rect2:
	if has_hit:
		return Rect2()
	if state == State.SPECIAL:
		var type: String = special_data().type
		if not special_active(type):
			return Rect2()
		match type:
			"rush", "armor":
				return _front_box(0.0, 90.0, -135.0, 105.0)
			"slide":
				return _front_box(10.0, 70.0, -35.0, 35.0)
			"pillar":
				return _front_box(eruption_distance() - 35.0, 70.0, -230.0, 230.0)
			"mirror":
				return _front_box(0.0, 85.0, -150.0, 140.0) if frame <= special_data().startup + SPLASH_FRAMES else Rect2()
			"whip":
				return _front_box(20.0, 240.0, -115.0, 30.0)
			"uppercut":
				return _front_box(0.0, 80.0, -220.0, 180.0)
			"push": # sopro largo
				return _front_box(0.0, 210.0, -150.0, 140.0)
			"cyclone":
				return _front_box(10.0, 110.0, -240.0, 240.0)
			"dive": # só fere na descida
				return _front_box(-20.0, 95.0, -110.0, 130.0) if vel.y > 0 else Rect2()
			"phase":
				return _front_box(-40.0, 100.0, -135.0, 110.0)
			"barrage":
				return _front_box(0.0, 95.0, -140.0, 90.0)
			"dig":
				return Rect2() if underground() else Rect2(pos.x - 70, pos.y - 150, 140, 150)
			"pounce":
				return _front_box(-10.0, 90.0, -110.0, 120.0)
			"burst": # em volta do corpo, dos dois lados
				return Rect2(pos.x - 115, pos.y - 170, 230, 170)
			"quake": # rente ao chão; quem está no ar escapa
				return Rect2(pos.x - 340, pos.y - 18, 680, 18)
		return Rect2()
	if state != State.ATTACK:
		return Rect2()
	var data: Dictionary = MOVES[move]
	if frame <= data.startup or frame > data.startup + data.active:
		return Rect2()
	return attack_box()

# Distância, à frente dos pés, da labareda atual: ela avança em três saltos.
func eruption_distance() -> float:
	var step_index := clampi((frame - special_data().startup - 1) / ERUPTION_STEP, 0, 2)
	return ERUPTION_FIRST + step_index * ERUPTION_GAP

# Retângulo à frente do lutador: começa a "from" dos pés e tem "width" de largura.
func _front_box(from: float, width: float, top: float, height: float) -> Rect2:
	var left := pos.x + from if facing > 0 else pos.x - from - width
	return Rect2(left, pos.y + top, width, height)

# Dano, altura e reação do golpe atual. "power" vale para normais; elemento, para especiais.
func attack_info(defender: String) -> Dictionary:
	if state == State.SPECIAL:
		var info := special_data().duplicate()
		info.damage = roundi(info.damage * Data.multiplier(element, defender))
		return info
	var info: Dictionary = MOVES[move].duplicate()
	info.damage = roundi(info.damage * stats.power)
	info.height = attack_height()
	return info

func attack_height() -> String:
	if air_attack:
		return "high" # defende em pé
	if move == "sweep":
		return "low"
	return "low" if crouching else "mid" # "low" defende agachado

# Defende segurando para trás, ou seja, no mesmo sentido em que o golpe viaja.
func blocks(height: String, from_direction: int) -> bool:
	if not on_ground() or not (is_free() or state == State.BLOCKSTUN):
		return false
	if not held("right" if from_direction > 0 else "left"):
		return false
	if height == "unblockable":
		return false
	if height == "low":
		return held("down")
	if height == "high":
		return not held("down")
	return true

# from_direction: sentido em que o golpe viaja (1 = para a direita).
func take_hit(damage: int, height: String, from_direction: int, push: float, hitstun: int, blockstun: int, burn_frames := 0, root_frames := 0) -> bool:
	# A armadura absorve um golpe sem interromper a investida.
	if state == State.SPECIAL and special_data().type == "armor" and not armor_used and frame <= special_data().startup + special_data().active and health > damage:
		armor_used = true
		health -= damage
		return false
	var blocked := blocks(height, from_direction)
	vel.x = from_direction * push
	if blocked:
		crouching = held("down")
		stun = blockstun
		_enter(State.BLOCKSTUN)
		return true
	health = maxi(health - damage, 0)
	burn = maxi(burn, burn_frames)
	root = maxi(root, root_frames)
	crouching = crouching and on_ground()
	stun = hitstun
	_enter(State.KO if health == 0 else State.HITSTUN)
	return false

# Depois de um acerto: lançado, derrubado ou mantido no ar.
func knock(launch: float, knockdown: bool) -> void:
	if launch < 0.0:
		vel.y = launch
		falling = true
	elif knockdown:
		vel.y = -7.0
		falling = true
	elif not on_ground() or falling:
		vel.y = -7.0
		falling = true
		juggle += 1
	if falling:
		crouching = false

# A queimadura tira vida aos poucos, mas nunca nocauteia.
func tick_burn() -> void:
	if burn > 0:
		burn -= 1
		if burn % 15 == 0 and health > 1:
			health = maxi(health - 3, 1)
