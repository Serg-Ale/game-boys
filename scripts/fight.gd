# Regras da partida: golpes, projéteis, rounds e tempo. Um step() = um frame.
extends RefCounted

const Data = preload("res://scripts/data.gd")
const Fighter = preload("res://scripts/fighter.gd")
const Supers = preload("res://scripts/supers.gd")

const STAGE_WIDTH := 960.0
const ROUND_FRAMES := 99 * 60
const ROUND_PAUSE := 180
const HITSTOP := 8
const WINS_NEEDED := 2
const FORM_FREEZE := 80 # pausa da transformação

var ids: Array # lutadores escolhidos
var fighters: Array = []
var projectiles: Array = []
var combo := [{"hits": 0, "damage": 0, "age": 999}, {"hits": 0, "damage": 0, "age": 999}] # por atacante
var events: Array = [] # impactos para a tela desenhar; quem desenha esvazia
var wins := [0, 0]
var timer := ROUND_FRAMES
var hitstop := 0
var pause := 0
var message := ""
var match_over := false
var ko_by_special := [false, false] # quem caiu, caiu por um especial?
var cast := {} # supremo em andamento
var transforming := {} # transformação em andamento
var freeze := 0 # pausa cinematográfica
var energy := [0.0, 0.0] # passa de um round para o outro
var finisher := {} # preenchido quando a luta termina com um especial

func _init(first := "fire", second := "water") -> void:
	ids = [first, second]
	start_round()

func start_round() -> void:
	fighters = [Fighter.new(ids[0], 280, 1), Fighter.new(ids[1], 680, -1)]
	projectiles = []
	timer = ROUND_FRAMES
	hitstop = 0
	pause = 0
	message = ""
	ko_by_special = [false, false]
	cast = {}
	freeze = 0
	transforming = {}
	combo = [{"hits": 0, "damage": 0, "age": 999}, {"hits": 0, "damage": 0, "age": 999}]
	for i in 2:
		fighters[i].energy = energy[i]
		fighters[i].can_transform = wins[i] >= 1

func step(inputs: Array) -> void:
	if match_over:
		_settle() # o perdedor termina de cair e o vencedor comemora
		return
	if pause > 0:
		pause -= 1
		_settle()
		if pause == 0:
			start_round()
		return
	if not transforming.is_empty():
		transforming.age += 1
		if transforming.age >= FORM_FREEZE:
			_shockwave(transforming.owner)
			transforming = {}
		return
	if freeze > 0:
		freeze -= 1
		return
	if hitstop > 0:
		hitstop -= 1
		return

	for entry in combo:
		entry.age += 1
	for i in 2:
		var me = fighters[i]
		me.super_locked = not cast.is_empty()
		me.step(inputs[i], fighters[1 - i].pos.x, _has_projectile(i))
		if me.wants_super:
			cast = {"owner": i, "id": me.id, "element": me.element, "x": me.pos.x, "facing": me.facing, "target": fighters[1 - i].pos.x, "age": 0, "hits": 0, "last": -99}
			freeze = Supers.FREEZE
		if me.wants_projectile:
			_spawn(i)
		if me.wants_form:
			transforming = {"owner": i, "age": 0}
	_separate()
	_resolve_throws()
	_resolve_attacks()
	_move_projectiles()
	_run_super()
	for i in 2:
		energy[i] = fighters[i].energy
	for f in fighters:
		f.tick_burn()
		# Seiva: recupera vida aos poucos.
		if f.stats.passive == "sap" and f.health > 0 and timer % 24 == 0:
			f.health = mini(f.health + 1, f.stats.health)
	timer -= 1
	_check_round_end()

# A onda de energia da transformação afasta quem está perto.
func _shockwave(owner: int) -> void:
	var me = fighters[owner]
	var other = fighters[1 - owner]
	if absf(other.pos.x - me.pos.x) < 220:
		other.vel.x = 0
		other.pos.x += (1 if other.pos.x >= me.pos.x else -1) * 110.0
		_separate()

# O golpe final termina de acontecer, sem aceitar comandos.
func _settle() -> void:
	for i in 2:
		fighters[i].step({}, fighters[1 - i].pos.x, true)
	_separate()

func _has_projectile(owner: int) -> bool:
	return projectiles.any(func(p): return p.owner == owner and p.kind == "shot")

# Impede que os corpos se atravessem no chão ou saiam da arena.
func _separate() -> void:
	var a = fighters[0]
	var b = fighters[1]
	var half: float = Fighter.HALF_WIDTH
	for f in fighters:
		f.pos.x = clampf(f.pos.x, half, STAGE_WIDTH - half)
	if a.invulnerable() or b.invulnerable() or not a.body_box().intersects(b.body_box()):
		return
	var side := 1.0 if a.pos.x <= b.pos.x else -1.0
	var overlap: float = half * 2 - absf(a.pos.x - b.pos.x)
	a.pos.x = clampf(a.pos.x - side * overlap / 2, half, STAGE_WIDTH - half)
	b.pos.x = clampf(a.pos.x + side * half * 2, half, STAGE_WIDTH - half)
	a.pos.x = b.pos.x - side * half * 2

# Todo dano passa por aqui, onde entram as passivas.
func _damage(attacker: int, target_index: int, hit: Dictionary, direction: int, special: bool, at: Vector2) -> bool:
	var source = fighters[attacker]
	var target = fighters[target_index]
	var damage: float = hit.damage
	if source.stats.passive == "fury" and source.health < source.stats.health * 0.3:
		damage *= 1.15
	if target.stats.passive == "shell":
		damage *= 0.9
	if source.transformed:
		damage *= Fighter.FORM_POWER
	if source.stats.passive == "hunter" and not target.on_ground():
		damage *= 1.2
	var before: int = target.health
	# Combo: acertar quem ainda está atordoado ou caindo. Cada acerto seguinte rende um pouco menos.
	var chained: bool = target.state == Fighter.State.HITSTUN or target.falling
	if chained and not hit.get("unscaled", false):
		damage *= maxf(0.4, 1.0 - 0.1 * combo[attacker].hits)
	var blocked: bool = target.take_hit(roundi(damage), hit.get("height", "mid"), direction, hit.get("push", 6.0),
		hit.get("hitstun", Fighter.SPECIAL_HITSTUN), hit.get("blockstun", Fighter.SPECIAL_BLOCKSTUN), hit.get("burn", 0), hit.get("root", 0))
	var lost: int = before - target.health
	if not blocked and target.state == Fighter.State.HITSTUN:
		target.knock(hit.get("launch", 0.0), hit.get("knockdown", false))
	if not blocked:
		var entry: Dictionary = combo[attacker]
		entry.hits = entry.hits + 1 if chained else 1
		entry.damage = entry.damage + lost if chained else lost
		entry.age = 0
		if source.stats.passive == "chill":
			target.slow = 90
		if source.stats.passive == "drain" and special and source.health > 0:
			source.health = mini(source.health + roundi(lost * 0.25), source.stats.health)
	if target.health == 0 and before > 0:
		ko_by_special[target_index] = special
	_impact(at, blocked, lost, special or damage >= 90)
	hitstop = 12 if lost >= 100 else (9 if lost >= 70 else 6)
	return blocked

# Agarrão: não pode ser defendido, mas pode ser escapado apertando agarrar na hora.
func _resolve_throws() -> void:
	for i in 2:
		var me = fighters[i]
		var other = fighters[1 - i]
		if me.state != Fighter.State.THROW or me.has_hit or me.frame <= Fighter.THROW.startup or me.frame > Fighter.THROW.startup + Fighter.THROW.active:
			continue
		if not other.on_ground() or other.invulnerable() or other.state in [Fighter.State.HITSTUN, Fighter.State.BLOCKSTUN, Fighter.State.KO]:
			continue
		if absf(other.pos.x - me.pos.x) > Fighter.THROW.range:
			continue
		me.has_hit = true
		var toward := 1 if other.pos.x >= me.pos.x else -1
		if other.grab_age <= 8:
			me.pos.x -= toward * 40.0
			other.pos.x += toward * 40.0
			other.has_hit = true
			_impact(Vector2((me.pos.x + other.pos.x) / 2, me.pos.y - 100), true, 0, false)
			continue
		var hit := {"damage": roundi(Fighter.THROW.damage * me.stats.power), "height": "unblockable", "push": 12.0,
			"hitstun": 30, "knockdown": true}
		var before: int = other.health
		_damage(i, 1 - i, hit, toward, false, Vector2(other.pos.x, other.pos.y - 90))
		_charge(i, false, before - other.health)

func _resolve_attacks() -> void:
	# Calcula os dois antes de aplicar, para que trocas de golpes sejam justas.
	var hits: Array = []
	for i in 2:
		var box: Rect2 = fighters[i].hitbox()
		if box.has_area() and box.intersects(fighters[1 - i].hurtbox()):
			var direction: int = fighters[i].facing
			# Golpes em volta do corpo empurram para longe, seja qual for o lado.
			if fighters[i].state == Fighter.State.SPECIAL and fighters[i].special_data().type in ["burst", "quake", "dig", "phase"]:
				direction = 1 if fighters[1 - i].pos.x >= fighters[i].pos.x else -1
			hits.append([i, direction, fighters[i].attack_info(fighters[1 - i].element)])
	for hit in hits:
		var i: int = hit[0]
		var info: Dictionary = hit[2]
		var attacker = fighters[i]
		var target = fighters[1 - i]
		attacker.has_hit = true
		var special: bool = info.has("type")
		# Contragolpe: o ataque de corpo é anulado e quem atacou é punido.
		if target.special_active("counter") and not target.has_hit:
			target.has_hit = true
			var counter: Dictionary = target.attack_info(attacker.element)
			counter.height = "unblockable"
			_damage(1 - i, i, counter, -hit[1], true, Vector2(attacker.pos.x, attacker.pos.y - 100))
			_charge(1 - i, false, counter.damage)
			continue
		var before: int = target.health
		var height: float = target.pos.y - (40.0 if info.height == "low" else 100.0)
		var blocked := _damage(i, 1 - i, info, hit[1], special, Vector2(target.pos.x - hit[1] * 20, height))
		_charge(i, blocked, before - target.health)

func _run_super() -> void:
	if cast.is_empty() or freeze > 0:
		return
	var caster = fighters[cast.owner]
	# Quem leva um golpe antes do fim perde o supremo.
	if caster.state != Fighter.State.SUPER and cast.age < Supers.duration(cast.id) - 1:
		cast = {}
		return
	cast.age += 1
	if cast.age > Supers.duration(cast.id):
		cast = {}
		return
	var data: Dictionary = Supers.SUPERS[cast.id]
	var target = fighters[1 - cast.owner]
	# Cortes e tornado perseguem o adversário.
	match data.pattern:
		"slashes":
			if (cast.age - data.startup) % Supers.SLASH_EVERY == 0 or not cast.has("track"):
				cast.track = target.pos.x
		"swoop":
			if (cast.age - data.startup) % Supers.SWOOP_EVERY == 0 or not cast.has("track"):
				cast.track = target.pos.x
		"tornado":
			if not cast.has("pos"):
				cast.pos = cast.x + cast.facing * 70.0
			if cast.age > data.startup:
				cast.pos = move_toward(cast.pos, target.pos.x, Supers.TORNADO_SPEED)
	if cast.hits >= data.max_hits or cast.age - cast.last < data.interval:
		return
	var body: Rect2 = target.hurtbox()
	for zone in Supers.zones(cast):
		if not zone.intersects(body):
			continue
		var hit := data.duplicate()
		hit.damage = roundi(data.damage * Data.multiplier(cast.element, target.element))
		hit.unscaled = true
		var blocked := _damage(cast.owner, 1 - cast.owner, hit, cast.facing, true, Vector2(target.pos.x, target.pos.y - 100))
		if blocked and target.health > 1:
			target.health = maxi(target.health - roundi(hit.damage * Supers.CHIP), 1)
		cast.hits += 1
		cast.last = cast.age
		hitstop = 4
		return

# Energia para quem acerta e para quem apanha. Os supremos não recarregam a si mesmos.
func _charge(attacker: int, blocked: bool, damage: int) -> void:
	for pair in [[attacker, 0.12], [1 - attacker, 0.18]]:
		var f = fighters[pair[0]]
		f.gain_energy((4.0 if blocked else damage * pair[1]) * (1.5 if f.stats.passive == "focus" else 1.0))

func _impact(at: Vector2, blocked: bool, damage: int, strong: bool) -> void:
	events.append({"at": at, "blocked": blocked, "damage": damage, "strong": strong})

# "kind": shot (voa), trap (armadilha), wall (muralha), sand (areia movediça), rain (cai do céu).
func projectile_box(p: Dictionary) -> Rect2:
	match p.kind:
		"trap":
			return Rect2(p.x - 40, p.y - 30, 80, 30)
		"wall":
			return Rect2(p.x - 22, p.y - 130, 44, 130)
		"sand":
			return Rect2(p.x - 85, p.y - 14, 170, 14)
		"vortex":
			return Rect2(p.x - 45, p.y - 120, 90, 120)
		"rain":
			return Rect2(p.x - 14, p.y - 40, 28, 60)
	if p.data.get("roll", false):
		return Rect2(p.x - 28, p.y - 28, 56, 56)
	var size: float = p.data.get("size", 1.0)
	return Rect2(p.x - 18, p.y - 15 * size, 36, 30 * size)

# Cria o que o especial que acabou de sair solta na arena.
func _spawn(owner: int) -> void:
	var me = fighters[owner]
	var data: Dictionary = me.special_data()
	var kind: String = {"trap": "trap", "wall": "wall", "quicksand": "sand", "rain": "rain", "vortex": "vortex"}.get(data.type, "shot")
	if kind in ["trap", "wall", "sand", "vortex"]: # só um de cada por vez
		projectiles = projectiles.filter(func(p): return not (p.kind == kind and p.owner == owner))
	var base := {"owner": owner, "art": me.element, "dir": me.facing, "kind": kind, "age": 0, "wait": 0,
		"x": me.pos.x + me.facing * 45, "y": me.pos.y - 100, "vx": 0.0, "vy": 0.0, "gravity": 0.0,
		"life": data.get("life", 600), "data": data}
	match kind:
		"trap", "wall", "sand", "vortex":
			base.x = clampf(me.pos.x + me.facing * data.distance, 40, STAGE_WIDTH - 40)
			base.y = Fighter.FLOOR_Y
			base.life = data.get("life", 360)
			projectiles.append(base)
		"rain": # três espinhos sobre onde o adversário está agora
			for n in 3:
				var drop := base.duplicate()
				drop.x = clampf(fighters[1 - owner].pos.x + (n - 1) * 70, 20, STAGE_WIDTH - 20)
				drop.y = 70.0
				drop.wait = 22 + n * 8
				projectiles.append(drop)
		_:
			var fan: Array = data.get("fan", [0.0])
			for n in data.get("volley", fan.size()):
				var shot := base.duplicate()
				shot.vx = data.speed
				shot.vy = data.get("lift", fan[n % fan.size()])
				shot.gravity = data.get("gravity", 0.0)
				shot.wait = n * 7 if data.has("volley") else 0
				if data.get("roll", false):
					shot.y = Fighter.FLOOR_Y - 28
				projectiles.append(shot)

func _move_projectiles() -> void:
	var gone: Array = []
	for p in projectiles:
		if p.wait > 0: # ainda não saiu
			p.wait -= 1
			continue
		p.age += 1
		if p.kind == "rain":
			p.vy = 15.0
		if p.data.has("stall") and p.kind == "shot" and p.age == p.data.stall:
			p.vx = 0.0 # a esfera para no ar
		p.vy += p.gravity
		if p.data.has("boomerang") and p.kind == "shot": # vai e volta
			p.vx = p.data.speed * (1.0 - p.age / 32.0)
			p.vx = maxf(p.vx, -p.data.speed)
		p.x += p.dir * p.vx
		p.y += p.vy
		if p.data.has("wavy") and p.kind == "shot":
			p.y = Fighter.FLOOR_Y - 100 + sin(p.age * 0.22) * p.data.wavy
		if p.x < -40 or p.x > STAGE_WIDTH + 40 or p.age > p.life or (p.kind == "rain" and p.y > Fighter.FLOOR_Y):
			gone.append(p)
	# Projéteis que se chocam se anulam, menos os que atravessam. A muralha segura os inimigos.
	for p in projectiles:
		for q in projectiles:
			if p.owner == q.owner or p.kind != "shot" or p.wait > 0 or q.wait > 0:
				continue
			if not projectile_box(p).intersects(projectile_box(q)):
				continue
			if q.kind == "wall" or (q.kind == "shot" and not p.data.get("pierce", false)):
				gone.append(p)
	for p in projectiles:
		if p in gone or p.wait > 0:
			continue
		var target = fighters[1 - p.owner]
		var box := projectile_box(p)
		var landed: bool = p.gravity > 0.0 and p.y >= Fighter.FLOOR_Y - 15
		if landed: # a bomba explode no chão
			box = Rect2(p.x - 75, Fighter.FLOOR_Y - 100, 150, 100)
			gone.append(p)
			_impact(Vector2(p.x, Fighter.FLOOR_Y - 40), false, 0, true)
		# O espelho devolve o projétil, que mantém o próprio elemento.
		elif p.kind == "shot" and target.special_active("mirror") and box.intersects(target.hurtbox().grow(24)):
			p.owner = 1 - p.owner
			p.dir = -p.dir
			continue
		if p.kind == "vortex": # puxa o adversário para dentro
			if absf(target.pos.x - p.x) < 260 and not target.invulnerable():
				target.pos.x = move_toward(target.pos.x, p.x, 2.6)
				if p.age % 12 == 0 and box.intersects(target.hurtbox()) and target.health > 1:
					target.health = maxi(target.health - 5, 1)
			continue
		if p.kind == "sand": # não fere de uma vez: prende e desgasta
			if target.on_ground() and box.intersects(target.hurtbox()):
				target.slow = maxi(target.slow, 20)
				target.root = maxi(target.root, 2) if p.age % 40 < 12 else target.root
				if p.age % 10 == 0 and target.health > 1:
					target.health -= 3
			continue
		if p.kind == "trap" and (p.age < 20 or not target.on_ground()):
			continue
		if not box.intersects(target.hurtbox()):
			continue
		var data: Dictionary = p.data
		var low: bool = p.kind == "trap" or data.get("roll", false)
		var hit := {"damage": roundi(data.damage * Data.multiplier(p.art, target.element)), "push": data.get("push", 6.0),
			"burn": data.get("burn", 0), "root": data.get("root", 0), "height": "low" if low else "mid"}
		var before: int = target.health
		var blocked := _damage(p.owner, 1 - p.owner, hit, p.dir, true, Vector2(target.pos.x, target.pos.y - (30.0 if low else 100.0)))
		_charge(p.owner, blocked, before - target.health)
		gone.append(p)
	projectiles = projectiles.filter(func(p): return not p in gone)

func _check_round_end() -> void:
	var a: int = fighters[0].health
	var b: int = fighters[1].health
	if a > 0 and b > 0 and timer > 0:
		return
	projectiles = []
	hitstop = 0
	cast = {}
	if a == b:
		message = "EMPATE"
		pause = ROUND_PAUSE
		return
	var winner := 0 if a > b else 1
	wins[winner] += 1
	var fighter_name: String = Data.FIGHTERS[ids[winner]].name
	if wins[winner] >= WINS_NEEDED:
		match_over = true
		message = "%s venceu a luta!" % fighter_name
		if ko_by_special[1 - winner] and fighters[1 - winner].health == 0:
			finisher = {"winner": winner, "element": fighters[winner].element, "id": fighters[winner].id}
	else:
		message = "%s venceu o round" % fighter_name
		pause = ROUND_PAUSE
