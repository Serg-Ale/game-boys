# Testes sem janela: godot --headless --path . --script res://tests/test_combat.gd
extends SceneTree

const Fight = preload("res://scripts/fight.gd")
const Fighter = preload("res://scripts/fighter.gd")
const Data = preload("res://scripts/data.gd")
const Cpu = preload("res://scripts/cpu.gd")
const Menu = preload("res://scripts/menu.gd")

var failures := 0

func check(condition: bool, label: String) -> void:
	print(("ok    " if condition else "FALHA ") + label)
	if not condition:
		failures += 1

func run(fight, frames: int, first := {}, second := {}) -> void:
	for n in frames:
		fight.step([first, second])

func close_fight():
	var fight = Fight.new()
	fight.fighters[0].pos.x = 400
	fight.fighters[1].pos.x = 470
	return fight

# Meia-lua para a direita + Y, com a energia cheia.
func cast_super(fight, defense := {}) -> void:
	fight.fighters[0].energy = 100.0
	for part in [{"left": true}, {"down": true}, {"right": true}]:
		run(fight, 2, part, defense)
	run(fight, 1, {"right": true, "special": true}, defense)

func _init() -> void:
	for a in Data.BEATS:
		var wins := 0
		var losses := 0
		for b in Data.BEATS:
			wins += int(Data.multiplier(a, b) > 1.0)
			losses += int(Data.multiplier(a, b) < 1.0)
		check(wins == 2 and losses == 2, "%s: 2 vantagens e 2 desvantagens" % a)

	var f = close_fight()
	run(f, 30, {"punch": true})
	check(f.fighters[1].health == f.fighters[1].stats.health - 60, "soco acerta uma única vez, mesmo com o botão preso")

	f = close_fight()
	run(f, 30, {"punch": true}, {"right": true})
	check(f.fighters[1].health == f.fighters[1].stats.health, "segurar para trás defende o soco")

	f = close_fight()
	run(f, 30, {"punch": true}, {"left": true})
	check(f.fighters[1].health == f.fighters[1].stats.health - 60, "segurar para a frente não defende")

	f = close_fight()
	run(f, 30, {}, {"punch": true})
	check(f.fighters[0].health == f.fighters[0].stats.health - 60, "jogador 2 também acerta")

	f = close_fight()
	run(f, 30, {"left": true}, {"punch": true})
	check(f.fighters[0].health == f.fighters[0].stats.health, "jogador 1 defende segurando para a esquerda")

	f = close_fight()
	run(f, 2, {"down": true})
	run(f, 30, {"down": true, "punch": true}, {"down": true, "right": true})
	check(f.fighters[1].health == f.fighters[1].stats.health, "defesa agachada segura o soco baixo")

	f = close_fight()
	run(f, 30, {"punch": true}, {"down": true})
	check(f.fighters[1].health == f.fighters[1].stats.health, "soco em pé passa por cima de quem está agachado")

	f = close_fight()
	run(f, 2, {"down": true})
	run(f, 30, {"down": true, "punch": true}, {"right": true})
	check(f.fighters[1].health == f.fighters[1].stats.health - 60, "soco baixo exige defesa agachada")

	f = Fight.new()
	run(f, 120, {"special": true})
	check(f.fighters[1].health < f.fighters[1].stats.health - 60, "especial de Fogo acerta Água")

	f = Fight.new()
	run(f, 120, {}, {"special": true})
	check(f.fighters[0].health == f.fighters[0].stats.health - roundi(Data.FIGHTERS.water.specials.neutral.damage * 1.15), "especial de Água causa 15% a mais em Fogo")

	f = Fight.new()
	run(f, 3, {"down": true})
	run(f, 3, {"down": true, "right": true})
	run(f, 3, {"right": true})
	run(f, 1, {"right": true, "punch": true})
	check(f.fighters[0].state == Fighter.State.SPECIAL, "comando ↓ ↘ → + soco solta o especial")

	f = Fight.new()
	run(f, 1, {"jump": true})
	run(f, 80)
	check(f.fighters[0].on_ground() and f.fighters[0].state == Fighter.State.IDLE, "pulo volta ao chão")

	f = Fight.new()
	run(f, 400, {"right": true}, {"left": true})
	check(absf(f.fighters[0].pos.x - f.fighters[1].pos.x) >= 59.9, "lutadores não se atravessam")

	f = close_fight()
	f.fighters[1].health = 10
	run(f, 30, {"punch": true})
	check(f.wins[0] == 1, "nocaute dá o round")
	run(f, 200)
	check(f.fighters[1].health == f.fighters[1].stats.health, "próximo round recomeça com vida cheia")
	f.fighters[0].pos.x = 400
	f.fighters[1].pos.x = 470
	f.fighters[1].health = 10
	run(f, 30, {"punch": true})
	check(f.match_over, "dois rounds vencem a luta")

	f = close_fight()
	run(f, 40, {"kick": true})
	check(f.fighters[1].health == f.fighters[1].stats.health - 90, "chute causa 90 de dano")

	f = close_fight()
	f.fighters[1].pos.x = 530
	run(f, 40, {"punch": true})
	check(f.fighters[1].health == f.fighters[1].stats.health, "soco não alcança a distância de chute")
	run(f, 1)
	run(f, 40, {"kick": true})
	check(f.fighters[1].health == f.fighters[1].stats.health - 90, "chute alcança mais longe")

	f = close_fight()
	run(f, 40, {"kick": true}, {"right": true})
	check(f.fighters[1].health == f.fighters[1].stats.health, "chute pode ser defendido")

	# A CPU precisa conseguir vencer um adversário parado.
	f = Fight.new()
	var cpu = Cpu.new(1)
	for n in 20000:
		if f.match_over:
			break
		f.step([{}, cpu.read(f, 1)])
	check(f.match_over and f.wins[1] == 2, "CPU vence um adversário parado")

	# Duas CPUs jogam lutas inteiras sem travar.
	var finished := 0
	for seed_value in range(1, 11):
		f = Fight.new()
		var one = Cpu.new(seed_value)
		var two = Cpu.new(seed_value + 100)
		for n in 40000:
			if f.match_over:
				break
			f.step([one.read(f, 0), two.read(f, 1)])
		finished += int(f.match_over)
		print("      CPU x CPU %d: %d a %d" % [seed_value, f.wins[0], f.wins[1]])
	check(finished == 10, "dez lutas entre CPUs chegam ao fim")

	f = Fight.new("plant", "water")
	run(f, 120, {"special": true})
	check(f.fighters[1].root > 0, "especial de Planta prende")
	var x: float = f.fighters[1].pos.x
	run(f, 5, {}, {"left": true})
	check(f.fighters[1].pos.x == x, "quem está preso não anda")

	f = Fight.new("earth", "water")
	f.fighters[0].pos.x = 400
	f.fighters[1].pos.x = 470
	run(f, 30, {"punch": true})
	check(f.fighters[1].health == f.fighters[1].stats.health - roundi(60 * Data.FIGHTERS.earth.power), "Terra soca mais forte")

	# Todo confronto entre CPUs precisa terminar.
	var stuck := 0
	for a in Data.ROSTER:
		for b in Data.ROSTER:
			f = Fight.new(a, b)
			var one = Cpu.new(3)
			var two = Cpu.new(4)
			for n in 40000:
				if f.match_over:
					break
				f.step([one.read(f, 0), two.read(f, 1)])
			stuck += int(not f.match_over)
	check(stuck == 0, "os 144 confrontos entre CPUs terminam")

	var menu = Menu.new()
	menu.handle("confirm", 0)
	check(menu.screen == "select" and menu.versus_cpu, "menu abre a seleção contra a CPU")
	menu.handle("right", 0)
	menu.handle("confirm", 0)
	menu.handle("left", 0)
	check(menu.handle("confirm", 0) == "fight", "escolher os dois começa a luta")
	check(menu.picks == ["water", "fire"], "escolhas do jogador e da CPU são guardadas")
	menu = Menu.new()
	menu.handle("down", 0)
	menu.handle("confirm", 0)
	check(not menu.versus_cpu, "menu abre o modo de dois jogadores")
	menu.handle("back", 0)
	check(menu.screen == "title", "voltar retorna ao título")

	f = Fight.new()
	run(f, 1, {"special": true})
	run(f, 100)
	run(f, 1, {"special": true})
	check(f.fighters[0].state != Fighter.State.SPECIAL, "especial em recarga não sai")
	run(f, 100)
	run(f, 1, {"special": true})
	check(f.fighters[0].state == Fighter.State.SPECIAL, "especial volta depois da recarga")

	f = Fight.new()
	run(f, 1, {"special": true})
	run(f, 60)
	run(f, 1, {"special": true, "right": true})
	check(f.fighters[0].state == Fighter.State.SPECIAL and f.fighters[0].slot == "forward", "recargas são separadas")

	f = Fight.new()
	f.fighters[0].pos.x = 350
	f.fighters[1].pos.x = 540
	run(f, 1, {"special": true, "right": true})
	run(f, 60)
	check(f.fighters[1].health <= f.fighters[1].stats.health - roundi(Data.FIGHTERS.fire.specials.forward.damage * 0.85), "Investida Flamejante avança e acerta")

	f = close_fight()
	f.fighters[1].pos.x = 480
	run(f, 1, {"special": true, "down": true})
	run(f, 60)
	check(f.fighters[1].health == f.fighters[1].stats.health - roundi(Data.FIGHTERS.fire.specials.down.damage * 0.85), "Erupção acerta de perto")

	f = close_fight()
	f.fighters[1].pos.x = 480
	f.fighters[1].pos.y = 300
	f.fighters[1].state = Fighter.State.JUMP
	run(f, 1, {"special": true, "down": true})
	run(f, 15)
	check(f.fighters[1].health < f.fighters[1].stats.health, "Erupção acerta quem está no ar")

	f = Fight.new()
	f.fighters[0].pos.x = 350
	f.fighters[1].pos.x = 520
	run(f, 1, {}, {"special": true, "left": true})
	run(f, 60, {"left": true})
	check(f.fighters[0].health < f.fighters[0].stats.health, "Deslize passa por defesa em pé")

	f = Fight.new()
	f.fighters[0].pos.x = 350
	f.fighters[1].pos.x = 520
	run(f, 1, {}, {"special": true, "left": true})
	run(f, 60, {"left": true, "down": true})
	check(f.fighters[0].health == f.fighters[0].stats.health, "Deslize é defendido agachado")

	f = Fight.new()
	run(f, 1, {"special": true})
	var cast := false
	for n in 150:
		var mirror := {}
		if not cast and not f.projectiles.is_empty() and f.projectiles[0].x > 570:
			mirror = {"special": true, "down": true}
			cast = true
		f.step([{}, mirror])
	check(f.fighters[1].health == f.fighters[1].stats.health and f.fighters[0].health < f.fighters[0].stats.health, "Espelho d'Água devolve o projétil")

	f = Fight.new()
	f.fighters[0].pos.x = 300
	f.fighters[1].pos.x = 540
	run(f, 1, {"special": true, "down": true})
	run(f, 60)
	check(f.fighters[1].health < f.fighters[1].stats.health, "Erupção avança até um adversário distante")
	check(f.events.size() == 1 and f.events[0].damage > 0, "o acerto gera um impacto com o dano")

	f = close_fight()
	run(f, 1, {}, {"special": true, "down": true})
	run(f, 30)
	check(f.fighters[0].health < f.fighters[0].stats.health, "Espelho d'Água fere quem está colado")

	f = Fight.new()
	f.wins = [1, 0]
	f.fighters[1].health = 10
	run(f, 150, {"special": true})
	check(f.match_over and f.finisher.get("element") == "fire", "luta decidida com especial tem finalização")
	check(f.fighters[1].on_ground() and f.fighters[0].state == Fighter.State.IDLE, "depois do fim, o perdedor cai e o vencedor se recompõe")

	f = close_fight()
	f.wins = [1, 0]
	f.fighters[1].health = 10
	run(f, 60, {"punch": true})
	check(f.match_over and f.finisher.is_empty(), "vitória com soco não tem finalização")

	f = Fight.new()
	f.fighters[1].health = 10
	run(f, 100, {"special": true})
	check(not f.match_over and f.finisher.is_empty(), "especial no primeiro round não finaliza")

	f = close_fight()
	f.wins = [1, 0]
	f.fighters[1].pos.x = 480
	f.fighters[1].health = 10
	run(f, 60, {"special": true, "down": true})
	check(f.finisher.get("winner") == 0, "especial de corpo também finaliza")

	var Audio = load("res://scripts/audio.gd")
	var missing: Array = []
	var names: Array = Audio.EFFECTS.duplicate()
	names.append("music_menu")
	for key in Data.ELEMENTS:
		names.append("music_" + key)
	for sound in names:
		var stream = load("res://assets/sounds/%s.wav" % sound)
		if stream == null or stream.get_length() <= 0.0:
			missing.append(sound)
	check(missing.is_empty(), "todos os sons carregam %s" % str(missing))

	f = Fight.new()
	for part in [{"left": true}, {"down": true}, {"right": true}]:
		run(f, 2, part)
	run(f, 1, {"right": true, "special": true})
	check(f.fighters[0].state == Fighter.State.SPECIAL and f.cast.is_empty(), "sem energia, a meia-lua não solta o supremo")

	f = Fight.new()
	cast_super(f)
	check(f.fighters[0].state == Fighter.State.SUPER and f.freeze > 0 and f.fighters[0].energy == 0.0, "meia-lua + Y solta o supremo e gasta a energia")

	for key in Data.ROSTER:
		f = Fight.new(key, "water" if key != "water" else "fire")
		var full: int = f.fighters[1].health
		cast_super(f)
		run(f, 260)
		var lost: int = full - f.fighters[1].health
		check(lost >= 200 and f.cast.is_empty(), "supremo de %s acerta parado (%d de dano)" % [key, lost])

	f = Fight.new()
	cast_super(f)
	run(f, 220, {}, {"right": true})
	check(f.fighters[1].health < f.fighters[1].stats.health and f.fighters[1].health > f.fighters[1].stats.health - 150, "Dragão Solar defendido tira pouco")

	f = Fight.new("plant", "fire")
	cast_super(f)
	run(f, 220, {}, {"down": true, "right": true})
	check(f.fighters[1].health > f.fighters[1].stats.health - 150, "Fúria da Floresta é defendida agachado")

	f = Fight.new("water", "fire")
	cast_super(f)
	var jumped := false
	for n in 220:
		var second := {}
		if not jumped and f.freeze == 0 and not f.cast.is_empty() and absf(preload("res://scripts/supers.gd").wave_x(f.cast) - f.fighters[1].pos.x) < 190:
			second = {"jump": true}
			jumped = true
		f.step([{}, second])
	check(f.fighters[1].health == f.fighters[1].stats.health, "dá para pular o Maremoto")

	f = Fight.new("electric", "fire")
	cast_super(f)
	run(f, 220, {}, {"right": true})
	check(f.fighters[1].health == f.fighters[1].stats.health, "dá para sair da marca do Céu Partido")

	f = Fight.new("earth", "fire")
	cast_super(f)
	for n in 220:
		var second := {}
		if not f.cast.is_empty() and f.fighters[1].pos.x < f.cast.target + 100:
			second = {"right": true}
		f.step([{}, second])
	check(f.fighters[1].health > f.fighters[1].stats.health - 150, "dá para ficar no vão das pedras do Cataclismo")

	f = close_fight()
	run(f, 30, {"punch": true})
	check(f.fighters[0].energy > 0 and f.fighters[1].energy > f.fighters[0].energy, "acertar e apanhar enchem a barra")
	var kept: float = f.fighters[0].energy
	f.fighters[1].health = 10
	run(f, 30)
	run(f, 1, {"punch": true})
	run(f, 250)
	check(f.fighters[0].energy >= kept, "energia passa para o próximo round")

	f = Fight.new()
	f.wins = [1, 0]
	f.fighters[1].health = 100
	cast_super(f)
	run(f, 260)
	check(f.match_over and f.finisher.get("element") == "fire", "supremo decisivo gera finalização")

	for key in Data.ROSTER:
		var info: Dictionary = Data.FIGHTERS[key]
		check(info.specials.size() == 3 and info.clan in Data.ELEMENTS, "%s tem três especiais e um clã" % info.name)
	for clan in Data.ELEMENTS:
		check(Data.ROSTER.filter(func(k): return Data.FIGHTERS[k].clan == clan).size() == 2, "clã %s tem dois ninjas" % clan)

	# Cada especial que fere precisa acertar um adversário parado, na distância certa.
	var distance := {"dive": 200, "push": 150, "cyclone": 70, "vortex": 170, "phase": 120, "barrage": 75, "dig": 260, "wall": 105, "quicksand": 190, "rain": 300, "pounce": 230, "whip": 230, "burst": 80, "uppercut": 80, "quake": 280, "trap": 0, "mirror": 70, "pillar": 200,
		"rush": 180, "armor": 170, "slide": 170, "projectile": 250}
	for key in Data.ROSTER:
		for slot in Data.FIGHTERS[key].specials:
			var data: Dictionary = Data.FIGHTERS[key].specials[slot]
			if data.type in ["teleport", "counter"]:
				continue
			f = Fight.new(key, "water")
			var gap: float = distance[data.type]
			if data.type in ["trap", "wall", "vortex"]:
				gap = data.distance
			elif data.has("gravity"):
				gap = 305
			f.fighters[0].pos.x = 250
			f.fighters[1].pos.x = 250 + gap
			var command := {"special": true}
			if slot == "forward":
				command.right = true
			elif slot == "down":
				command.down = true
			run(f, 1, command)
			run(f, 150)
			check(f.fighters[1].health < f.fighters[1].stats.health, "%s: %s acerta" % [Data.FIGHTERS[key].name, data.name])

	for key in ["electric"]:
		f = Fight.new(key, "water")
		run(f, 1, {"special": true, "right": true})
		run(f, 60)
		check(f.fighters[0].pos.x > f.fighters[1].pos.x and f.fighters[0].facing == -1, "%s teleporta para as costas" % Data.FIGHTERS[key].name)

	f = Fight.new("plant", "water")
	f.fighters[0].pos.x = 300
	f.fighters[1].pos.x = 530
	run(f, 1, {"special": true, "right": true})
	run(f, 60)
	check(f.fighters[1].pos.x < 500, "o Chicote de Cipó puxa o adversário")

	f = close_fight()
	f = Fight.new("frost", "fire")
	f.fighters[0].pos.x = 400
	f.fighters[1].pos.x = 470
	run(f, 4, {"special": true, "down": true})
	run(f, 30, {}, {"punch": true})
	check(f.fighters[0].health == 1100 and f.fighters[1].health < f.fighters[1].stats.health, "Contra-Gelo anula o soco e pune")

	f = Fight.new("water", "earth")
	f.fighters[0].pos.x = 300
	f.fighters[1].pos.x = 440
	run(f, 15, {}, {"special": true, "left": true})
	run(f, 1, {"punch": true}, {"left": true})
	check(f.fighters[1].special_data().type == "armor", "Rocha começa a Ombrada")

	f = Fight.new("earth", "water")
	run(f, 1, {"special": true, "down": true})
	for n in 70:
		var second := {"jump": true} if n == 14 else {}
		f.step([{}, second])
	check(f.fighters[1].health == f.fighters[1].stats.health, "dá para pular o Tremor")

	f = Fight.new("ash", "water")
	run(f, 1, {"jump": true})
	run(f, 14)
	var height: float = f.fighters[0].pos.y
	run(f, 1, {"jump": true})
	run(f, 8)
	check(f.fighters[0].pos.y < height - 20, "Cinza pula duas vezes")

	f = Fight.new("thorn", "water")
	f.fighters[0].health = 500
	run(f, 120, {"special": true})
	check(f.fighters[0].health > 500, "Espinho recupera vida com o especial")

	f = Fight.new("frost", "water")
	f.fighters[0].pos.x = 400
	f.fighters[1].pos.x = 470
	run(f, 20, {"punch": true})
	check(f.fighters[1].slow > 0, "golpes de Geada deixam o rival lento")

	var picker = Menu.new()
	picker.handle("confirm", 0)
	picker.handle("down", 0)
	check(picker.picks[0] == "ash", "baixo na seleção vai para o segundo ninja do clã")

	# ---- combate: correntes, lançador, rasteira, agarrão, dash e queda
	f = close_fight()
	for n in 3:
		run(f, 1, {"punch": true})
		run(f, 12)
	check(f.combo[0].hits == 3, "três socos encadeados contam como combo (%d)" % f.combo[0].hits)
	check(f.combo[0].damage < 180, "o combo escalona o dano (%d)" % f.combo[0].damage)

	f = close_fight()
	run(f, 1, {"punch": true})
	run(f, 12)
	run(f, 1, {"special": true})
	run(f, 4)
	check(f.fighters[0].state == Fighter.State.SPECIAL, "soco que acerta cancela em especial")

	f = Fight.new()
	run(f, 1, {"punch": true})
	run(f, 8)
	run(f, 1, {"special": true})
	run(f, 3)
	check(f.fighters[0].state == Fighter.State.ATTACK, "soco no vazio não cancela")

	f = close_fight()
	run(f, 1, {"kick": true, "right": true})
	run(f, 22)
	check(f.fighters[1].falling and not f.fighters[1].on_ground(), "frente + chute lança para o alto")
	var downed := false
	for n in 120:
		run(f, 1)
		downed = downed or f.fighters[1].state == Fighter.State.DOWN
	check(downed and f.fighters[1].state == Fighter.State.IDLE, "quem foi lançado cai e se levanta")

	f = close_fight()
	run(f, 1, {"kick": true, "down": true}, {"right": true})
	run(f, 40, {"down": true}, {"right": true})
	check(f.fighters[1].health < f.fighters[1].stats.health, "rasteira passa por defesa em pé")

	f = close_fight()
	run(f, 1, {"grab": true}, {"right": true})
	run(f, 20, {}, {"right": true})
	check(f.fighters[1].health == f.fighters[1].stats.health - 110, "agarrão não pode ser defendido")

	f = close_fight()
	run(f, 1, {"grab": true})
	run(f, 2)
	run(f, 20, {}, {"grab": true})
	check(f.fighters[1].health == f.fighters[1].stats.health, "dá para escapar do agarrão")

	f = Fight.new()
	var start_x: float = f.fighters[0].pos.x
	run(f, 2, {"right": true})
	run(f, 2)
	run(f, 1, {"right": true})
	check(f.fighters[0].state == Fighter.State.DASH, "dois toques para frente dão dash")
	run(f, 20)
	check(f.fighters[0].pos.x - start_x > 120, "o dash cobre distância")

	f = Fight.new()
	start_x = f.fighters[0].pos.x
	run(f, 1, {"dash": true, "left": true})
	check(f.fighters[0].invulnerable(), "recuo é invulnerável no começo")
	run(f, 25)
	check(f.fighters[0].pos.x < start_x, "RB com trás recua")

	f = close_fight()
	run(f, 1, {"punch": true})
	run(f, 14)
	run(f, 1, {"kick": true})
	run(f, 40)
	check(f.combo[0].hits == 2, "soco emenda no chute pelo buffer")

	# ---- transformação
	f = close_fight()
	run(f, 3, {"transform": true})
	check(not f.fighters[0].transformed, "sem vencer um round, não transforma")
	f = Fight.new()
	f.wins = [1, 0]
	f.start_round()
	check(f.fighters[0].can_transform and not f.fighters[1].can_transform, "só quem venceu um round pode transformar")
	run(f, 1, {"transform": true})
	check(f.fighters[0].transformed and not f.transforming.is_empty(), "L3/R3 transforma")
	var clock: int = f.timer
	run(f, Fight.FORM_FREEZE)
	check(f.transforming.is_empty() and f.timer >= clock - 1, "a cena para o relógio e termina")
	var before_x: float = f.fighters[0].pos.x
	run(f, 20, {"right": true})
	check(f.fighters[0].pos.x - before_x > 20 * f.fighters[0].stats.walk * 1.1, "transformado anda mais rápido")
	f.fighters[0].pos.x = 400
	f.fighters[1].pos.x = 470
	run(f, 30, {"punch": true})
	check(f.fighters[1].health < f.fighters[1].stats.health - 60, "transformado bate mais forte")
	f.start_round()
	check(not f.fighters[0].transformed, "a forma dura até o fim do round")

	# ---- quem usa teclado e quem usa controle
	var Controls = preload("res://scripts/controls.gd")
	var d = Controls.resolve(["auto", "auto"], [], false)
	check(d[0] == {"layout": "main", "pad": -1} and d[1] == {"layout": "arrows", "pad": -1}, "sem controle: J1 em WASD, J2 nas setas")
	d = Controls.resolve(["auto", "auto"], [0], false)
	check(d[0] == {"layout": "", "pad": 0} and d[1] == {"layout": "main", "pad": -1}, "um controle: J1 no controle, J2 em WASD")
	d = Controls.resolve(["keyboard", "auto"], [0], false)
	check(d[0] == {"layout": "main", "pad": -1} and d[1] == {"layout": "", "pad": 0}, "J1 no teclado deixa o controle para o J2")
	d = Controls.resolve(["auto", "pad"], [0], false)
	check(d[1].pad == 0 and d[0].layout == "main", "quem pede controle tem prioridade")
	d = Controls.resolve(["auto", "auto"], [0, 1], false)
	check(d[0].pad == 0 and d[1].pad == 1, "dois controles: um para cada")
	d = Controls.resolve(["auto", "auto"], [0], true)
	check(d[0] == {"layout": "main", "pad": 0}, "contra a CPU, controle e teclado valem")
	d = Controls.resolve(["pad", "keyboard"], [], false)
	check(d[0].layout == "main" and d[1].layout == "arrows", "sem controle ligado, cai no teclado")
	var panel = Menu.new()
	panel.handle("down", 0)
	panel.handle("down", 0)
	panel.handle("down", 0)
	panel.handle("confirm", 0)
	check(panel.screen == "controls", "o menu abre a tela de controles")
	panel.handle("right", 0)
	check(Controls.choices[0] == "keyboard" and panel.handle("back", 0) == "saved" and panel.screen == "title", "trocar o aparelho e voltar salva")
	Controls.choices[0] = "auto"

	print("falhas: %d" % failures)
	quit(1 if failures else 0)
