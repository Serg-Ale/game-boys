# Transformação: a cena da mudança e a aura de quem está transformado.
extends RefCounted

const Data = preload("res://scripts/data.gd")
const Fight = preload("res://scripts/fight.gd")
const Look = preload("res://scripts/theme.gd")

const BURST := 48 # frame em que o visual novo aparece
const SCALE := 3.25 # transformado fica um pouco maior

# Labaredas de energia subindo ao redor do corpo.
static func aura(canvas: CanvasItem, element: String, feet: Vector2, time: int, power := 1.0) -> void:
	var theme: Dictionary = Look.THEMES[element]
	for layer in [[74.0, 215.0, Color(theme.accent, 0.28)], [52.0, 180.0, Color(theme.accent, 0.4)], [34.0, 150.0, Color(1, 1, 1, 0.25)]]:
		var points := PackedVector2Array()
		var width: float = layer[0] * power
		points.append(feet + Vector2(-width, 4))
		for n in 9:
			var part := n / 8.0
			var tongue: float = (n % 2) * 34.0 + sin(time * 0.5 + n * 2.1) * 16.0
			var height: float = (layer[1] * (0.45 + 0.55 * sin(part * PI)) + tongue) * power
			points.append(feet + Vector2(lerpf(-width, width, part), -height))
		points.append(feet + Vector2(width, 4))
		canvas.draw_colored_polygon(points, layer[2])
	for n in 8: # faíscas subindo
		var rise := fposmod(time * 4.0 + n * 41.0, 190.0 * power)
		canvas.draw_rect(Rect2(feet.x + sin(n * 2.7 + time * 0.1) * 48 * power, feet.y - rise, 5, 9), theme.accent)

static func cinematic(canvas: CanvasItem, sprites, f, base_sheet: String, age: int, time: int) -> void:
	var theme: Dictionary = Look.THEMES[f.element]
	canvas.draw_rect(Rect2(-20, -20, 1000, 580), Color(0, 0, 0, 0.78))
	var center := Vector2(480, 330)
	for n in 20: # raios convergindo e depois explodindo
		var angle := n * TAU / 20 + age * 0.03
		var reach := 800.0 if age >= BURST else 120.0 + (BURST - age) * 8.0
		canvas.draw_colored_polygon(PackedVector2Array([center, center + Vector2.from_angle(angle) * reach, center + Vector2.from_angle(angle + 0.07) * reach]), Color(theme.mid, 0.55))
	Look.particles(canvas, f.element, time * 4, Rect2(0, 0, 960, 540), 70)
	var feet := Vector2(480, 440)
	aura(canvas, f.element, feet, time, 0.6 + minf(age / float(BURST), 1.0) * 1.1)
	var changed: bool = age >= BURST or (age > BURST - 20 and age % 6 < 3)
	var shaking := Vector2((age % 2 * 2 - 1) * 5.0, 0) if age < BURST else Vector2.ZERO
	sprites.draw(canvas, f.id + "_form" if changed else base_sheet, "victory" if age >= BURST else "crouch", feet + shaking, 1, 5.4 if age >= BURST else 4.6)
	if age >= BURST and age < BURST + 12:
		canvas.draw_rect(Rect2(-20, -20, 1000, 580), Color(1, 1, 1, 1.0 - (age - BURST) / 12.0))
	for n in 3: # ondas de choque
		var radius := (age - BURST - n * 7) * 22.0
		if radius > 0:
			canvas.draw_arc(center, radius, 0, TAU, 40, Color(theme.accent, 0.8 - n * 0.2), 10)
	if age >= BURST:
		Look.text(canvas, "TRANSFORMAÇÃO!", 480, 70, 34, Color.WHITE, theme.mid)
		Look.text(canvas, Data.FORMS[f.id].to_upper(), 480, 505, 50 + maxi(0, BURST + 8 - age) * 4, theme.accent, theme.dark)
