# Torneio entre CPUs para achar desequilíbrios grosseiros (não substitui o teste com pessoas).
# godot --headless --path . --script res://tools/balance.gd
extends SceneTree

const Data = preload("res://scripts/data.gd")
const Fight = preload("res://scripts/fight.gd")
const Cpu = preload("res://scripts/cpu.gd")
const SEEDS := 6

func _init() -> void:
	var score := {}
	for key in Data.ROSTER:
		score[key] = 0
	for seed_value in SEEDS:
		for a in Data.ROSTER:
			for b in Data.ROSTER:
				if a == b:
					continue
				var f = Fight.new(a, b)
				var one = Cpu.new(seed_value * 17 + 1)
				var two = Cpu.new(seed_value * 31 + 2)
				for n in 40000:
					if f.match_over:
						break
					f.step([one.read(f, 0), two.read(f, 1)])
				score[a] += int(f.wins[0] > f.wins[1])
				score[b] += int(f.wins[1] > f.wins[0])
	var games: int = SEEDS * (Data.ROSTER.size() - 1) * 2
	for key in Data.ROSTER:
		print("vitórias %-8s %d%%" % [Data.FIGHTERS[key].name, roundi(100.0 * score[key] / games)])
	quit()
