# Finalizações: quando o golpe que decide a luta é um especial. Uma por ninja, sem sangue.
extends RefCounted

const Data = preload("res://scripts/data.gd")
const Fighter = preload("res://scripts/fighter.gd")
const Look = preload("res://scripts/theme.gd")

const START := 30 # escurece e anuncia antes do efeito
const CLIMAX := 130 # momento do golpe final
const LOCK := 170 # antes disso não aceita revanche
const NAMES := {"fire": "CINZAS", "water": "REDEMOINHO", "plant": "JARDIM FINAL", "electric": "MIL VOLTS", "earth": "SEPULTURA DE PEDRA",
	"ash": "SOMBRA PARTIDA", "frost": "ESQUIFE DE GELO", "thorn": "ÚLTIMO PERFUME", "thunder": "NOCAUTE ORBITAL", "sand": "AREIA MOVEDIÇA",
	"air": "ALÉM DAS NUVENS", "gale": "PRESA ABATIDA"}

static func background(canvas: CanvasItem, element: String, t: int) -> void:
	var theme: Dictionary = Look.THEMES[element]
	var fade := minf(t / 25.0, 1.0)
	canvas.draw_rect(Rect2(-20, -20, 1000, 580), Color(theme.dark, 0.78 * fade))
	for n in 18:
		var angle := n * TAU / 18 + t * 0.004
		var center := Vector2(480, 330)
		canvas.draw_colored_polygon(PackedVector2Array([center, center + Vector2.from_angle(angle) * 800, center + Vector2.from_angle(angle + 0.09) * 800]), Color(theme.mid, 0.28 * fade))
	Look.particles(canvas, element, t * 2, Rect2(0, 0, 960, 540), 60, 0.8 * fade)

# Verdadeiro nos frames em que a tela deve tremer.
static func shakes(id: String, t: int) -> bool:
	if id in ["electric", "ash", "thunder"]:
		return t > START and t < CLIMAX and t % 24 < 6
	return t >= CLIMAX and t < CLIMAX + 14

# Desenha o perdedor sofrendo a finalização.
static func loser(canvas: CanvasItem, sprites, id: String, sheet: String, spot: Vector2, facing: int, t: int) -> void:
	var progress := clampf(float(t - START) / (CLIMAX - START), 0.0, 1.0)
	var feet := Vector2(clampf(spot.x, 110, 850), Fighter.FLOOR_Y)
	if t < START:
		sprites.draw(canvas, sheet, "hit", feet, facing)
		return
	var element: String = Data.FIGHTERS[id].clan
	match id:
		"fire":
			if t < CLIMAX:
				var burnt := 1.0 - progress * 0.92
				sprites.draw(canvas, sheet, "hit", feet + Vector2(t % 4 - 2, 0), facing, 3.0, Color(burnt + 0.1, burnt * 0.8, burnt * 0.7))
				for n in 3:
					sprites.draw_column(canvas, element, feet + Vector2((n - 1) * 34, 6), t + n * 7, 60 + progress * 40, 60 + progress * (150 + (n % 2) * 60), Color(1, 1, 1, 0.85))
			else:
				var left := maxf(0.0, 1.0 - (t - CLIMAX) / 30.0)
				sprites.draw(canvas, sheet, "hit", feet, facing, 3.0, Color(0.05, 0.04, 0.04, left))
				for n in 40: # monte de cinzas
					var x := fmod(n * 37.0, 96.0) - 48
					var height := (48 - absf(x)) * 0.5 * fmod(n * 0.37, 1.0)
					canvas.draw_rect(Rect2(feet.x + x, feet.y - height - 5, 6, 6), Color(0.2, 0.18, 0.18) if n % 5 else Color(1, 0.45, 0.1))
		"water":
			var lift := sin(minf(progress * 1.4, 1.0) * PI / 2) * 190
			if t < CLIMAX:
				for n in 7: # funil do redemoinho
					var y := feet.y - n * 36
					var width := 40.0 + n * 18
					canvas.draw_arc(Vector2(feet.x + sin(t * 0.2 + n) * 10, y), width * progress, 0, TAU, 20, Color(0.55, 0.85, 1.0, 0.85), 7)
				sprites.draw_turned(canvas, sheet, "hit", feet + Vector2(0, -70 - lift), (t - START) * 0.22, facing)
			else:
				var fall := minf((t - CLIMAX) / 8.0, 1.0)
				if fall < 1.0:
					sprites.draw_turned(canvas, sheet, "hit", feet + Vector2(0, -260 * (1 - fall) - 30), PI * fall, facing)
				else:
					sprites.draw(canvas, sheet, "ko", feet, facing)
				var wave := minf((t - CLIMAX) / 40.0, 1.0)
				for n in 7:
					sprites.draw_column(canvas, element, feet + Vector2((n - 3) * (20 + wave * 50), 8), t + n, 56, (1.0 - wave) * 170 + 18, Color(1, 1, 1, 0.8))
		"plant":
			sprites.draw(canvas, sheet, "hit", feet, facing)
			for n in 9: # cipós subindo
				var height := minf(progress * 1.5, 1.0) * (80 + n % 4 * 28)
				var base := feet.x + (n - 4) * 11
				var points := PackedVector2Array()
				for step_index in 9:
					var part := step_index / 8.0
					points.append(Vector2(base + sin(part * 9 + n) * 16, feet.y - part * height))
				canvas.draw_polyline(points, Color(0.16, 0.5, 0.18), 7)
				canvas.draw_circle(points[points.size() - 1], 7, Color(0.55, 0.85, 0.3))
			if t >= CLIMAX: # a árvore cobre tudo
				var grow := minf((t - CLIMAX) / 20.0, 1.0)
				canvas.draw_rect(Rect2(feet.x - 24 * grow, feet.y - 180 * grow, 48 * grow, 180 * grow), Color(0.35, 0.22, 0.12))
				for leaf in [Vector2(0, -210), Vector2(-55, -170), Vector2(55, -170), Vector2(-30, -225), Vector2(34, -220)]:
					canvas.draw_circle(feet + leaf * grow, 52 * grow, Color(0.14, 0.45, 0.18))
					canvas.draw_circle(feet + (leaf + Vector2(-10, -12)) * grow, 28 * grow, Color(0.3, 0.65, 0.25))
				for n in 6:
					canvas.draw_circle(feet + Vector2((n - 3) * 30 + 14, -165 - n % 3 * 30) * grow, 8 * grow, Color(1, 0.5, 0.65))
		"electric":
			if t < CLIMAX:
				var flash := t % 8 < 4
				sprites.draw(canvas, sheet, "hit", feet + Vector2(t % 6 - 3, -progress * 60), facing, 3.0, Color(4, 4, 3) if flash else Color(0.05, 0.05, 0.1))
				if t % 24 < 10:
					_bolt(canvas, feet + Vector2(0, -90 - progress * 60), t)
			else:
				if t < CLIMAX + 12:
					canvas.draw_rect(Rect2(-20, -20, 1000, 580), Color(1, 1, 0.85, 0.8 - (t - CLIMAX) / 16.0))
					for n in 3:
						_bolt(canvas, feet + Vector2((n - 1) * 40, -10), t + n * 5)
				sprites.draw(canvas, sheet, "ko", feet, facing, 3.0, Color(0.25, 0.22, 0.2))
				if t % 20 < 8:
					sprites.draw_spark(canvas, "hit", feet + Vector2((t * 13) % 120 - 60, -25), t % 8, 1.8)
		"earth":
			var drop := clampf((t - CLIMAX + 28) / 28.0, 0.0, 1.0)
			if t < CLIMAX:
				sprites.draw(canvas, sheet, "hit", feet + Vector2(t % 4 - 2, 0), facing)
				canvas.draw_rect(Rect2(feet.x - 90 * progress, feet.y - 4, 180 * progress, 9), Color(0, 0, 0, 0.55)) # sombra crescendo
			if drop > 0.0:
				sprites.draw_falling(canvas, element, Vector2(feet.x, lerpf(-220.0, feet.y - 72, drop * drop)), 8.0)
			if t >= CLIMAX:
				var dust := minf((t - CLIMAX) / 35.0, 1.0)
				for n in 10:
					var side := -1.0 if n % 2 else 1.0
					canvas.draw_circle(feet + Vector2(side * (50 + dust * (40 + n * 18)), -8 - n % 3 * 10), 22 * (1 - dust) + 3, Color(0.75, 0.62, 0.45, 1.0 - dust * 0.8))
		"ash": # cortes na sombra; o corpo vira fumaça
			if t < CLIMAX:
				sprites.draw(canvas, sheet, "hit", feet + Vector2(t % 6 - 3, 0), facing, 3.0, Color(0.12, 0.08, 0.12))
				for n in int(progress * 9) + 1:
					var along := Vector2.from_angle(n * 2.4) * 105
					var center := feet + Vector2(0, -80)
					canvas.draw_line(center - along, center + along, Color(1, 0.5, 0.45, 0.9), 7)
					canvas.draw_line(center - along, center + along, Color.WHITE, 2)
			else:
				var drift := minf((t - CLIMAX) / 40.0, 1.0)
				sprites.draw(canvas, sheet, "hit", feet, facing, 3.0, Color(0.1, 0.06, 0.1, 1.0 - drift))
				for n in 28:
					var at := feet + Vector2((n % 7 - 3) * (12 + drift * 26), -20 - (n / 7) * 34 - drift * (50 + n % 5 * 22))
					canvas.draw_circle(at, 15 * (1.0 - drift * 0.6), Color(0.2, 0.14, 0.2, 0.9 - drift * 0.7))
		"frost": # preso no gelo, que se estilhaça
			if t < CLIMAX:
				sprites.draw(canvas, sheet, "hit", feet, facing, 3.0, Color(0.6, 0.85, 1.2))
				var height := 190.0 * minf(progress * 1.6, 1.0)
				canvas.draw_rect(Rect2(feet.x - 62, feet.y - height, 124, height), Color(0.7, 0.92, 1.0, 0.5))
				canvas.draw_rect(Rect2(feet.x - 62, feet.y - height, 124, height), Color.WHITE, false, 4)
				canvas.draw_line(feet + Vector2(-44, -height + 20), feet + Vector2(-20, -height + 80), Color(1, 1, 1, 0.8), 6)
			else:
				sprites.draw(canvas, sheet, "ko", feet, facing, 3.0, Color(0.7, 0.9, 1.2))
				var burst := minf((t - CLIMAX) / 30.0, 1.0)
				for n in 22:
					var from := Vector2((n % 5 - 2) * 28.0, -30.0 - (n / 5) * 36.0)
					var at := feet + from * (1.0 + burst * 2.2) + Vector2(0, burst * burst * 190)
					var turn := n + burst * 7
					canvas.draw_colored_polygon(PackedVector2Array([at + Vector2.from_angle(turn) * 18, at + Vector2.from_angle(turn + 2.2) * 12, at + Vector2.from_angle(turn + 4.3) * 15]), Color(0.8, 0.95, 1.0, 1.0 - burst * 0.7))
		"thorn": # uma rosa gigante se fecha sobre o rival
			var shut := clampf((t - CLIMAX + 40) / 40.0, 0.0, 1.0)
			if t < CLIMAX:
				sprites.draw(canvas, sheet, "hit", feet, facing)
			var center := feet + Vector2(0, -85)
			for n in 8:
				var angle := n * TAU / 8 - PI / 2
				var at := center + Vector2.from_angle(angle) * lerpf(165.0, 24.0, shut) * Vector2(0.9, 1.0)
				if progress > 0.1:
					canvas.draw_circle(at, 34 + shut * 22, Color(0.62, 0.05, 0.28))
					canvas.draw_circle(at + Vector2(-6, -8), 18 + shut * 12, Color(0.9, 0.16, 0.42))
			if shut >= 1.0:
				canvas.draw_circle(center, 36, Color(0.98, 0.45, 0.6))
				canvas.draw_rect(Rect2(feet.x - 9, feet.y - 40, 18, 40), Color(0.24, 0.5, 0.16))
				for n in 14: # pétalas
					var at := feet + Vector2(fmod(n * 83.0, 300.0) - 150, -250 + fmod((t - CLIMAX) * 3.0 + n * 41, 250.0))
					canvas.draw_circle(at, 6, Color(0.95, 0.3, 0.5, 0.85))
		"thunder": # socos e um último que manda para o céu
			if t < CLIMAX:
				var side := -1.0 if t % 12 < 6 else 1.0
				sprites.draw(canvas, sheet, "hit", feet + Vector2(side * 14, 0), facing)
				sprites.draw_spark(canvas, "hit", feet + Vector2(side * 30, -70 - t % 36 * 2), t % 6, 3.5)
			else:
				var fly := minf((t - CLIMAX) / 30.0, 1.0)
				if fly < 1.0:
					var at := feet + Vector2(facing * -230 * fly, -80 - 520 * fly)
					sprites.draw_turned(canvas, sheet, "hit", at, (t - CLIMAX) * 0.7, facing)
					for n in 6:
						canvas.draw_line(at + Vector2(0, n * 26 + 40), at + Vector2(0, n * 26 + 60), Color(1, 0.9, 0.2, 0.8), 8)
				else: # estrela no céu
					var star := Vector2(clampf(feet.x - facing * 230, 90, 870), 90)
					var size := 20.0 + absf(sin(t * 0.18)) * 26
					for n in 4:
						canvas.draw_line(star, star + Vector2.from_angle(n * TAU / 4) * size, Color.WHITE, 5)
					canvas.draw_circle(star, 7, Color(1, 0.9, 0.2))
		"sand": # afunda devagar
			var sink := progress * 130 + (30.0 if t >= CLIMAX else 0.0)
			if sink < 135:
				sprites.draw(canvas, sheet, "hit", feet + Vector2(t % 4 - 2, sink), facing)
			canvas.draw_rect(Rect2(feet.x - 130, feet.y, 260, 90), Color(0.66, 0.5, 0.28))
			for n in 3:
				canvas.draw_set_transform(feet, 0, Vector2(1, 0.22))
				canvas.draw_arc(Vector2.ZERO, 105.0 - fposmod(t * 1.2 + n * 34, 100.0), 0, TAU, 28, Color(0.95, 0.8, 0.5), 12)
				canvas.draw_set_transform(Vector2.ZERO)
			if t >= CLIMAX:
				canvas.draw_rect(Rect2(feet.x - 5, feet.y - 34, 10, 34), Color(0.2, 0.75, 0.7)) # o lenço fica
				canvas.draw_colored_polygon(PackedVector2Array([feet + Vector2(5, -34), feet + Vector2(36 + sin(t * 0.2) * 8, -28), feet + Vector2(5, -18)]), Color(0.2, 0.75, 0.7))
		"air": # sobe girando até sumir no céu
			var rise := progress * 120 + (maxf(t - CLIMAX, 0) * 11.0)
			var gone := clampf((t - CLIMAX) / 35.0, 0.0, 1.0)
			for n in 8:
				var width := (30.0 + n * 12) * minf(progress * 2.0, 1.0) * (1.0 - gone)
				canvas.draw_set_transform(feet + Vector2(sin(t * 0.3 + n) * 12, -10 - n * 34), 0, Vector2(1, 0.28))
				canvas.draw_arc(Vector2.ZERO, width, t * 0.4 + n, t * 0.4 + n + 5.0, 24, Color(0.8, 1.0, 0.94, 0.9), 10)
				canvas.draw_set_transform(Vector2.ZERO)
			if rise < 520:
				sprites.draw_turned(canvas, sheet, "hit", feet + Vector2(0, -80 - rise), (t - START) * 0.18, facing)
		"gale": # a grande ave mergulha e leva o rival embora
			var swoop := clampf((t - CLIMAX + 36) / 36.0, 0.0, 1.0)
			var carried := maxf(t - CLIMAX, 0) * 12.0
			var direction := -facing
			var bird := Vector2(feet.x - direction * 420 * (1.0 - swoop) + direction * carried, lerpf(40.0, feet.y - 80, swoop) - carried * 0.55)
			if t < CLIMAX:
				sprites.draw(canvas, sheet, "hit", feet, facing)
			else:
				sprites.draw_turned(canvas, sheet, "hit", bird + Vector2(0, 60), 0.5, facing)
			if swoop > 0:
				sprites.draw_creature(canvas, "gale", bird + Vector2(0, 40), direction, int(t / 8 % 2), 3.6)
			if t >= CLIMAX:
				for n in 12: # penas caindo
					var at := feet + Vector2((n - 6) * 24 + sin(t * 0.08 + n) * 18, -190 + fmod((t - CLIMAX) * 1.6 + n * 31, 190.0))
					canvas.draw_line(at, at + Vector2(10, 5), Color(0.98, 0.95, 0.82), 5)

static func _bolt(canvas: CanvasItem, target: Vector2, seed_value: int) -> void:
	var points := PackedVector2Array()
	for n in 9:
		var part := n / 8.0
		var jitter := 0.0 if n == 8 else sin(n * 12.9 + seed_value) * 38
		points.append(Vector2(target.x + jitter, target.y * part - 20 * (1 - part)))
	canvas.draw_polyline(points, Color(1, 0.85, 0.1), 16)
	canvas.draw_polyline(points, Color.WHITE, 6)

static func banner(canvas: CanvasItem, id: String, t: int) -> void:
	var theme: Dictionary = Look.THEMES[Data.FIGHTERS[id].clan]
	if t < START + 30:
		var size := 70 + maxi(0, 14 - t) * 5
		Look.text(canvas, "FINALIZE!", 480, 200, size, theme.accent, theme.dark)
	elif t >= CLIMAX + 20:
		canvas.draw_rect(Rect2(-20, 112, 1000, 108), Color(0, 0, 0, 0.7))
		canvas.draw_rect(Rect2(-20, 112, 1000, 4), theme.accent)
		canvas.draw_rect(Rect2(-20, 216, 1000, 4), theme.accent)
		Look.text(canvas, NAMES[id], 480, 164, 50, theme.accent, theme.dark)
		Look.text(canvas, "FINALIZAÇÃO ELEMENTAL", 480, 202, 20)
