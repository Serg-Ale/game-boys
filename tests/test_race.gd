# Testes da corrida sem janela: timeout 110 godot --headless --path . --script res://tests/test_race.gd
extends SceneTree

const Race = preload("res://scripts/kart/race.gd")
const Data = preload("res://scripts/data.gd")
const Menu = preload("res://scripts/menu.gd")

var failures := 0

func check(condition: bool, label: String) -> void:
	print(("ok    " if condition else "FALHA ") + label)
	if not condition:
		failures += 1

func run(race, frames: int, input := {}) -> void:
	for n in frames:
		race.step(input)

func ready_race(id := "fire"):
	var race = Race.new(Race.load_track("fire"), id)
	run(race, Race.COUNTDOWN)
	return race

func _init() -> void:
	var track := Race.load_track("fire")
	var r = Race.new(track, "fire")
	var start: Vector2 = r.pos
	run(r, 100, {"accel": true})
	check(r.pos == start, "ninguém sai antes da largada")

	for id in Data.ROSTER:
		r = Race.new(track, id)
		var frames := 0
		while not r.finished and frames < 20000:
			r.step(r.autopilot())
			frames += 1
		check(r.finished and r.lap_times.size() == Race.LAPS, "%s completa 3 voltas (%s)" % [Data.FIGHTERS[id].name, Race.format_time(r.time)])

	var plain = ready_race()
	run(plain, 90, {"accel": true})
	var boosted = Race.new(track, "fire")
	run(boosted, Race.COUNTDOWN - 40)
	run(boosted, 40, {"accel": true})
	check(boosted.boost > 0, "acelerar na hora certa dá arrancada")

	r = ready_race()
	run(r, 90, {"accel": true})
	var straight: float = r.heading
	run(r, 20, {"accel": true, "steer": 1.0})
	var normal := absf(angle_difference(straight, r.heading))
	r = ready_race()
	run(r, 90, {"accel": true})
	run(r, 20, {"accel": true, "steer": 1.0, "drift": true})
	check(r.drift == 1 and absf(angle_difference(straight, r.heading)) > normal, "derrapando a curva é mais fechada")

	r = ready_race()
	run(r, 90, {"accel": true})
	r.drift = 1
	r.charge = Race.DRIFT_LEVELS[1] + 1
	r._was_drift = true
	r.step({"accel": true})
	check(r.drift == 0 and r.boost >= Race.DRIFT_BOOSTS[1] - 1, "soltar a derrapagem carregada dá turbo")
	run(r, 20, {"accel": true})
	check(r.speed > r.max_speed * 1.2, "o turbo passa da velocidade máxima")

	r = ready_race()
	run(r, 150, {"accel": true})
	r.pos += Vector2(-170, 0) # joga para fora, à esquerda do retão
	run(r, 60, {"accel": true})
	check(r.offroad and r.speed < r.max_speed * 0.75, "fora da pista fica lento")
	r.pos += Vector2(-600, 0)
	r.step({"accel": true})
	check(r.pos.x > 100, "a parede invisível segura a montaria")

	r = ready_race()
	run(r, 200, {"brake": true})
	check(r.lap <= 0 and r.lap_times.is_empty(), "andar de ré pela linha não conta volta")

	var light = Race.new(track, "ash")
	var heavy = Race.new(track, "earth")
	check(heavy.max_speed > light.max_speed and light.accel > heavy.accel and light.turn > heavy.turn, "leves aceleram e viram mais; pesados correm mais")

	var menu = Menu.new()
	menu.handle("down", 0)
	menu.handle("down", 0)
	menu.handle("confirm", 0)
	check(menu.screen == "select" and menu.racing, "o menu abre a escolha do corredor")
	check(menu.handle("confirm", 0) == "race", "escolher um ninja começa a corrida")

	print("falhas: %d" % failures)
	quit(1 if failures else 0)
