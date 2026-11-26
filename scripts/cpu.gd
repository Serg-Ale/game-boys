# Adversário controlado pelo computador. Produz os mesmos comandos que um jogador.
extends RefCounted

const Fighter = preload("res://scripts/fighter.gd")
const Supers = preload("res://scripts/supers.gd")

const THINK_FRAMES := 12 # tempo de reação: quanto maior, mais fácil
const BLOCK_CHANCE := 0.55

var rng := RandomNumberGenerator.new()
var plan := {}
var timer := 0

func _init(seed_value := 0) -> void:
	if seed_value:
		rng.seed = seed_value
	else:
		rng.randomize()

func read(fight, index: int) -> Dictionary:
	var me = fight.fighters[index]
	if me.can_transform and not me.transformed and me.is_free() and rng.randf() < 0.02:
		return {"transform": true}
	# Emenda o combo quando o golpe toca.
	if me.state == Fighter.State.ATTACK and me.has_hit and rng.randf() < 0.18:
		plan = {"kick": true} if me.move == "punch" else {"special": true}
		return plan
	timer -= 1
	if timer <= 0:
		timer = THINK_FRAMES
		plan = _decide(fight, index)
		return plan
	# Botões de ataque e pulo valem um frame só, para poderem ser apertados de novo.
	var held := plan.duplicate()
	for action in ["punch", "kick", "special", "jump", "super", "grab", "dash", "transform"]:
		held.erase(action)
	return held

func _decide(fight, index: int) -> Dictionary:
	var me = fight.fighters[index]
	var foe = fight.fighters[1 - index]
	var distance := absf(foe.pos.x - me.pos.x)
	var toward := "right" if foe.pos.x > me.pos.x else "left"
	var away := "left" if toward == "right" else "right"
	var roll := rng.randf()

	# Defesa contra o supremo do adversário.
	if not fight.cast.is_empty() and fight.cast.owner != index:
		match Supers.SUPERS[fight.cast.id].pattern:
			"strike":
				return {away: true} if absf(me.pos.x - fight.cast.target) < 130 and roll < 0.7 else {}
			"wave":
				return {"jump": true} if absf(me.pos.x - foe.pos.x) < 330 and roll < 0.5 else {away: true}
			"hurricane":
				return {away: true} if roll < 0.8 else {}
			"swoop":
				return {away: true} if roll < 0.7 else {}
			"slashes":
				return {away: true} if roll < 0.75 else {}
			"pincer":
				return {"jump": true} if roll < 0.5 else {away: true}
			"garden":
				return {away: true, "down": true} if roll < 0.65 else {}
			"tornado":
				return {"jump": true, away: true} if roll < 0.4 else {away: true}
			"roots":
				return {away: true, "down": true} if roll < 0.7 else {}
			_:
				return {away: true} if roll < 0.7 else {}
	if me.energy >= Fighter.MAX_ENERGY and distance > 110 and roll < 0.3:
		return {"super": true}

	for p in fight.projectiles:
		if p.owner == index or absf(p.x - me.pos.x) > (110 if p.kind != "shot" else 220):
			continue
		if p.kind != "shot":
			return {"jump": true, toward: true}
		var mirror := _special(me, ["mirror"], toward)
		if not mirror.is_empty() and roll < 0.4:
			return mirror
		if roll < 0.35:
			return {"jump": true, toward: true}
		return {away: true} if roll < 0.35 + BLOCK_CHANCE else {}

	if foe.state == Fighter.State.ATTACK and distance < 150:
		var counter := _special(me, ["counter"], toward)
		if not counter.is_empty() and rng.randf() < 0.35:
			return counter
		if roll < BLOCK_CHANCE:
			return {away: true, "down": foe.attack_height() == "low"}
	if foe.state == Fighter.State.SPECIAL and foe.special_data().has("height") and distance < 270 and roll < BLOCK_CHANCE:
		return {away: true, "down": foe.special_data().height == "low"}

	# Cada tipo de especial tem a distância em que vale a pena.
	var useful: Array = []
	if distance < 115:
		useful = ["burst", "uppercut", "quake", "barrage", "cyclone", "push"]
	elif distance < 260:
		useful = ["rush", "slide", "armor", "whip", "pillar", "quake", "teleport", "phase", "pounce", "dig", "wall", "quicksand", "rain", "push", "dive", "vortex", "cyclone"]
	else:
		useful = ["projectile", "trap", "teleport", "rain", "quicksand", "dig", "dive", "vortex"]
	if rng.randf() < (0.4 if distance >= 260 else 0.22):
		var move := _special(me, useful, toward)
		if not move.is_empty():
			return move

	if distance > 125:
		if distance > 260 or roll < 0.7:
			return {toward: true}
		return {"jump": true, toward: true} if roll < 0.82 else {}
	if distance < 85 and rng.randf() < 0.14:
		return {"grab": true}
	if distance > 90 and distance < 120 and rng.randf() < 0.2:
		return {"kick": true, toward: true}
	if distance > 270 and rng.randf() < 0.2:
		return {"dash": true, toward: true}
	if distance > 90:
		return {"kick": true, "down": rng.randf() < 0.3} if roll < 0.6 else {toward: true}
	if roll < 0.4:
		return {"punch": true, "down": rng.randf() < 0.3}
	if roll < 0.65:
		return {"kick": true, "down": rng.randf() < 0.3}
	return {away: true} if roll < 0.85 else {}

# Comando de um especial pronto, de um dos tipos pedidos; vazio se não houver.
func _special(me, types: Array, toward: String) -> Dictionary:
	var options: Array = []
	for key in me.stats.specials:
		if me.stats.specials[key].type in types and me.cooldowns[key] == 0:
			options.append(key)
	if options.is_empty():
		return {}
	match options[rng.randi() % options.size()]:
		"forward":
			return {"special": true, toward: true}
		"down":
			return {"special": true, "down": true}
		_:
			return {"special": true}
