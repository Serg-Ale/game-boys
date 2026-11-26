# Desenho dos golpes supremos e da pausa cinematográfica.
extends RefCounted

const Data = preload("res://scripts/data.gd")
const Supers = preload("res://scripts/supers.gd")
const Look = preload("res://scripts/theme.gd")

static func cinematic(canvas: CanvasItem, sprites, cast: Dictionary, sheet: String, freeze: int, time: int) -> void:
	var element: String = cast.element
	var theme: Dictionary = Look.THEMES[element]
	var age := Supers.FREEZE - freeze
	var slide := maxf(0.0, 1.0 - age / 10.0) * 700
	canvas.draw_rect(Rect2(-20, -20, 1000, 580), Color(0, 0, 0, 0.7))
	var side := -1.0 if cast.owner == 0 else 1.0
	canvas.draw_colored_polygon(PackedVector2Array([Vector2(-20, 150), Vector2(980, 110), Vector2(980, 390), Vector2(-20, 430)]), theme.mid)
	for n in 14: # riscos de velocidade
		var y := 150.0 + n * 18
		var x := fposmod(n * 211.0 - side * time * 38.0, 1100.0) - 100
		canvas.draw_line(Vector2(x, y), Vector2(x + 140, y - 5), Color(theme.accent, 0.7), 3)
	Look.particles(canvas, element, time * 3, Rect2(0, 110, 960, 320), 30)
	var grow := clampf((age - 8) / 18.0, 0.0, 1.0)
	var facing := int(-side)
	# Círculo de invocação e a criatura surgindo do outro lado.
	var circle := Vector2(480 - side * 215, 400)
	canvas.draw_set_transform(circle, 0, Vector2(1, 0.3))
	for n in 3:
		canvas.draw_arc(Vector2.ZERO, (190.0 - n * 45) * minf(age / 12.0, 1.0), time * 0.1 * (n + 1), time * 0.1 * (n + 1) + 5.4, 32, theme.accent, 10)
	canvas.draw_set_transform(Vector2.ZERO)
	if grow > 0.0:
		var tint := Color(3, 3, 3, grow) if grow < 0.6 else Color(1, 1, 1, 1)
		sprites.draw_creature(canvas, cast.id, circle + Vector2(0, 20 + (1.0 - grow) * 90), -facing, int(age > 38), 5.5 * (0.5 + grow * 0.5), tint)
	sprites.draw(canvas, sheet, "victory", Vector2(480 + side * (340 + slide), 470), facing, 6.0)
	Look.text(canvas, "%s INVOCA %s!" % [Data.FIGHTERS[cast.id].name.to_upper(), Data.CREATURES[cast.id].to_upper()], 480, 86, 38, Color.WHITE, theme.mid)
	Look.text(canvas, Supers.SUPERS[cast.id].name.to_upper(), 480, 465, 48, theme.accent, theme.dark)

static func effect(canvas: CanvasItem, sprites, cast: Dictionary, time: int) -> void:
	var element: String = cast.element
	var data: Dictionary = Supers.SUPERS[cast.id]
	var theme: Dictionary = Look.THEMES[element]
	var floor_y := Supers.FLOOR_Y
	var started: bool = cast.age > data.startup
	canvas.draw_rect(Rect2(-20, -20, 1000, floor_y + 20), Color(theme.dark, 0.45))
	var lift: float = {"fire": 20.0, "water": 30.0, "electric": -70.0 + sin(time * 0.2) * 10}.get(cast.id, 10.0)
	# No raio, a boca da criatura fica na altura do disparo.
	if data.pattern == "beam":
		lift = 80.0
	var home := Vector2(clampf(cast.x - cast.facing * 105, 215, 745), floor_y + lift)
	sprites.draw_creature(canvas, cast.id, home, cast.facing, int(started), 4.6)
	match data.pattern:
		"beam":
			var from := Vector2(cast.x + cast.facing * 55, floor_y - 98)
			if not started:
				sprites.draw_spark(canvas, "hit", from, time % 8, 2.0 + cast.age / 4.0)
				return
			var zone: Rect2 = Supers.zones(cast)[0] if not Supers.zones(cast).is_empty() else Rect2()
			var tip: float = from.x + cast.facing * zone.size.x
			for layer in [[96.0, Color(theme.mid, 0.9)], [66.0, theme.accent], [32.0, theme.accent.lightened(0.7)]]:
				var top := PackedVector2Array()
				var bottom := PackedVector2Array()
				for n in 21:
					var x := lerpf(from.x, tip, n / 20.0)
					var wave := sin(n * 1.4 - time * 0.9) * 9
					top.append(Vector2(x, from.y - layer[0] / 2 + wave))
					bottom.append(Vector2(x, from.y + layer[0] / 2 + wave))
				bottom.reverse()
				top.append_array(bottom)
				if zone.size.x > 1:
					canvas.draw_colored_polygon(top, layer[1])
			sprites.draw_projectile(canvas, element, Vector2(clampf(tip, 80, 880), from.y), cast.facing, time, 7.0)
			sprites.draw_spark(canvas, "hit", from, 4, 3.5)
		"wave":
			if not started:
				sprites.draw_column(canvas, element, Vector2(cast.x + cast.facing * 60, floor_y + 6), time, 70, 40 + cast.age * 6)
				return
			var x := Supers.wave_x(cast)
			for n in 5:
				sprites.draw_column(canvas, element, Vector2(x - cast.facing * n * 52, floor_y + 8), time + n * 4, 130 - n * 12, 150 - n * 24, Color(1, 1, 1, 1.0 - n * 0.16))
			canvas.draw_arc(Vector2(x + cast.facing * 18, floor_y - 108), 34, 0, TAU, 16, theme.accent.lightened(0.6), 9)
		"roots":
			if not started:
				return
			for n in Supers.roots_up(cast):
				var current: bool = n == Supers.roots_up(cast) - 1
				var at := Vector2(Supers.root_x(cast, n), floor_y + 6)
				sprites.draw_column(canvas, element, at, time + n * 3, 100 if current else 70, 150 if current else 90)
				canvas.draw_polyline(PackedVector2Array([at, at + Vector2(-20, -50), at + Vector2(14, -90), at + Vector2(-6, -130 if current else -80)]), Color(0.3, 0.2, 0.1), 9)
		"strike":
			var mark := Vector2(cast.target, floor_y)
			if not started:
				if time / 4 % 2 == 0 or cast.age > data.startup - 10:
					canvas.draw_set_transform(mark, 0, Vector2(1, 0.25))
					canvas.draw_arc(Vector2.ZERO, 66, 0, TAU, 24, theme.accent, 12)
					canvas.draw_arc(Vector2.ZERO, 34, 0, TAU, 24, Color.WHITE, 8)
					canvas.draw_set_transform(Vector2.ZERO)
				Look.text(canvas, "!", cast.target, floor_y - 175, 52, theme.accent)
			elif cast.age <= data.startup + data.length:
				canvas.draw_rect(Rect2(cast.target - 65, 0, 130, floor_y), Color(1, 0.95, 0.4, 0.45))
				for bolt in 3:
					var points := PackedVector2Array()
					for n in 11:
						points.append(Vector2(cast.target + (bolt - 1) * 34 + sin(n * 9.7 + time * 2 + bolt) * 28, floor_y * n / 10.0))
					canvas.draw_polyline(points, theme.accent, 18)
					canvas.draw_polyline(points, Color.WHITE, 7)
				sprites.draw_spark(canvas, "hit", mark + Vector2(0, -20), time % 8, 5.0)
		"hurricane":
			var at := Vector2(cast.target, floor_y)
			if not started:
				Look.text(canvas, "!", cast.target, floor_y - 175, 52, theme.accent)
			for n in 11:
				var width := (34.0 + n * 11) * (1.0 if started else 0.4)
				canvas.draw_set_transform(at + Vector2(sin(time * 0.35 + n) * 12, -10 - n * 27), 0, Vector2(1, 0.28))
				canvas.draw_arc(Vector2.ZERO, width, time * 0.45 + n, time * 0.45 + n + 5.0, 26, Color(theme.accent, 0.9) if n % 2 else Color(1, 1, 1, 0.85), 13)
				canvas.draw_set_transform(Vector2.ZERO)
		"swoop":
			if not started:
				Look.text(canvas, "!", cast.target, floor_y - 175, 52, theme.accent)
				return
			if cast.age > data.startup + data.length:
				return
			var bird := Supers.swoop_at(cast)
			for n in 4:
				var past := bird - Vector2(cast.facing * 26, 18) * (n + 1)
				canvas.draw_circle(past, 18.0 - n * 4, Color(theme.accent, 0.5 - n * 0.1))
			sprites.draw_creature(canvas, cast.id, bird + Vector2(0, 55), cast.facing, 1, 2.0)
		"slashes":
			if not started or cast.age > data.startup + data.length:
				return
			var at := Vector2(cast.get("track", cast.target), floor_y - 85)
			var step_age: int = (cast.age - data.startup) % Supers.SLASH_EVERY
			if step_age > 7: # aviso do próximo corte
				canvas.draw_arc(at, 70.0 - step_age * 3, 0, TAU, 24, Color(theme.accent, 0.6), 4)
				return
			var angle: float = (cast.age / Supers.SLASH_EVERY) * 2.2
			for n in 3:
				var along := Vector2.from_angle(angle + n * 0.35) * (130.0 - step_age * 6)
				canvas.draw_line(at - along, at + along, Color(theme.accent, 0.9), 14 - step_age)
				canvas.draw_line(at - along, at + along, Color.WHITE, 5)
		"pincer":
			if not started:
				Look.text(canvas, "!", cast.target, floor_y - 175, 52, theme.accent)
				return
			var gap := Supers.pincer_offset(cast)
			for side in [-1.0, 1.0]:
				var x: float = cast.target + side * gap
				for n in 4:
					var base: float = x + side * n * 30
					var height: float = 125.0 - n * 24
					canvas.draw_colored_polygon(PackedVector2Array([Vector2(base - 24, floor_y), Vector2(base - side * 18, floor_y - height), Vector2(base + 24, floor_y)]), Color(0.72, 0.92, 1.0, 0.95))
					canvas.draw_line(Vector2(base - side * 18, floor_y - height), Vector2(base, floor_y), Color.WHITE, 4)
		"garden":
			var rise: int = (cast.age - data.startup) % Supers.GARDEN_STEP if started else 0
			for x in Supers.garden_columns(cast):
				canvas.draw_rect(Rect2(x - 38, floor_y - 5, 76, 9), Color(0.85, 0.15, 0.35, 0.8 if time / 4 % 2 == 0 else 0.4))
				if started and rise >= 6 and rise <= 18:
					for n in 3:
						var base: float = x + (n - 1) * 22
						canvas.draw_colored_polygon(PackedVector2Array([Vector2(base - 11, floor_y), Vector2(base + (n - 1) * 8, floor_y - 105 + absi(n - 1) * 28), Vector2(base + 11, floor_y)]), Color(0.24, 0.5, 0.16))
					canvas.draw_circle(Vector2(x, floor_y - 108), 14, Color(0.85, 0.12, 0.36))
					canvas.draw_circle(Vector2(x, floor_y - 108), 6, Color(1, 0.7, 0.8))
		"fists":
			if not started:
				sprites.draw_spark(canvas, "hit", Vector2(cast.x + cast.facing * 55, floor_y - 98), time % 8, 2.0 + cast.age / 5.0)
				return
			for n in 3:
				if cast.age - data.startup <= n * Supers.FIST_EVERY:
					continue
				var at := Supers.fist_at(cast, n)
				for trail in 3:
					canvas.draw_circle(at - Vector2(cast.facing * (34.0 + trail * 30), 0), 24.0 - trail * 5, Color(theme.accent, 0.5 - trail * 0.12))
				canvas.draw_circle(at, 38, Color(0.15, 0.08, 0.3))
				canvas.draw_circle(at, 31, Color(0.55, 0.42, 0.92))
				for knuckle in 3:
					canvas.draw_circle(at + Vector2(cast.facing * 26, (knuckle - 1) * 19), 11, theme.accent)
		"tornado":
			var x: float = cast.get("pos", cast.x + cast.facing * 70.0)
			for n in 9:
				var width := 22.0 + n * 8 if started else 14.0 + n * 2
				var center := Vector2(x + sin(time * 0.4 + n) * 9, floor_y - 8 - n * 24)
				canvas.draw_set_transform(center, 0, Vector2(1, 0.3))
				canvas.draw_arc(Vector2.ZERO, width, time * 0.5 + n, time * 0.5 + n + 5.0, 20, Color(0.95, 0.8, 0.5, 0.9), 14)
				canvas.draw_set_transform(Vector2.ZERO)
		"rocks":
			for offset in Supers.ROCK_COLUMNS:
				var x: float = cast.target + offset
				canvas.draw_rect(Rect2(x - 40, floor_y - 5, 80, 10), Color(0, 0, 0, 0.65) if started or time / 4 % 2 == 0 else Color(theme.accent, 0.8))
				if started:
					sprites.draw_falling(canvas, element, Vector2(x, Supers.rock_y(cast)), 3.6)
