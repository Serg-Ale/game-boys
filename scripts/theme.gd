# Identidade visual de cada elemento: cores, partículas e texto com contorno.
extends RefCounted

const THEMES := {
	"fire": {"dark": Color(0.22, 0.04, 0.03), "mid": Color(0.55, 0.12, 0.04), "accent": Color(1.0, 0.55, 0.1)},
	"water": {"dark": Color(0.02, 0.07, 0.2), "mid": Color(0.05, 0.24, 0.5), "accent": Color(0.45, 0.85, 1.0)},
	"plant": {"dark": Color(0.03, 0.12, 0.06), "mid": Color(0.1, 0.33, 0.14), "accent": Color(0.65, 0.95, 0.35)},
	"electric": {"dark": Color(0.08, 0.05, 0.18), "mid": Color(0.28, 0.2, 0.45), "accent": Color(1.0, 0.9, 0.2)},
	"earth": {"dark": Color(0.14, 0.08, 0.04), "mid": Color(0.4, 0.24, 0.12), "accent": Color(0.95, 0.74, 0.45)},
	"air": {"dark": Color(0.04, 0.15, 0.18), "mid": Color(0.14, 0.42, 0.44), "accent": Color(0.75, 1.0, 0.9)},
}

static var _font: FontVariation

static func font() -> Font:
	if _font == null:
		_font = FontVariation.new()
		_font.base_font = ThemeDB.fallback_font
		_font.variation_embolden = 0.9
		_font.variation_transform = Transform2D(Vector2(1, 0), Vector2(-0.18, 1), Vector2.ZERO) # inclinado
	return _font

static func text(canvas: CanvasItem, value: String, center_x: float, y: float, size: int, color := Color.WHITE, outline := Color.BLACK, bold := true) -> void:
	var used: Font = font() if bold else ThemeDB.fallback_font
	var at := Vector2(center_x - 480, y)
	canvas.draw_string_outline(used, at, value, HORIZONTAL_ALIGNMENT_CENTER, 960, size, maxi(6, size / 6), outline)
	canvas.draw_string(used, at, value, HORIZONTAL_ALIGNMENT_CENTER, 960, size, color)

# Brasas sobem, bolhas ondulam, folhas caem, faíscas piscam e pedrinhas flutuam.
static func particles(canvas: CanvasItem, element: String, time: int, area: Rect2, count: int, alpha := 0.9) -> void:
	var color: Color = THEMES[element].accent
	color.a = alpha
	for i in count:
		var seed_x := fmod(i * 137.51, area.size.x)
		var seed_y := fmod(i * 71.93, area.size.y)
		var size := 3.0 + i % 3 * 2
		var at := Vector2.ZERO
		match element:
			"fire":
				at = Vector2(seed_x + sin((time + i * 20) * 0.05) * 12, fposmod(seed_y - time * (1.0 + i % 3 * 0.5), area.size.y))
			"water":
				at = Vector2(seed_x + sin((time + i * 33) * 0.04) * 18, fposmod(seed_y - time * 0.7, area.size.y))
			"plant":
				at = Vector2(fposmod(seed_x - time * 0.8, area.size.x), fposmod(seed_y + time * (0.6 + i % 2 * 0.4), area.size.y))
			"electric":
				if (time / 5 + i) % 4 != 0:
					continue
				at = Vector2(seed_x, seed_y)
			"air":
				at = Vector2(fposmod(seed_x + time * (2.4 + i % 3), area.size.x), seed_y + sin((time + i * 17) * 0.04) * 10)
			_:
				at = Vector2(fposmod(seed_x + time * 0.9, area.size.x), seed_y + sin((time + i * 11) * 0.03) * 8)
		at += area.position
		match element:
			"air":
				canvas.draw_line(at, at + Vector2(14 + size * 2, -2), color, 2)
			"water":
				canvas.draw_arc(at, size, 0, TAU, 8, color, 2)
			"plant":
				var turn := sin((time + i * 9) * 0.08) * 4
				canvas.draw_colored_polygon(PackedVector2Array([at + Vector2(-size * 1.5, turn), at + Vector2(0, -size * 0.7), at + Vector2(size * 1.5, -turn), at + Vector2(0, size * 0.7)]), color)
			"electric":
				canvas.draw_polyline(PackedVector2Array([at, at + Vector2(6, 8), at + Vector2(-2, 10), at + Vector2(5, 20)]), color, 2)
			_:
				canvas.draw_rect(Rect2(at, Vector2(size, size)), color)
