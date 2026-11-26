# Golpes supremos: regras de cada um. "age" conta os frames depois da pausa cinematográfica.
extends RefCounted

const Data = preload("res://scripts/data.gd")

const FREEZE := 84 # pausa cinematográfica
const FLOOR_Y := 450.0
const CHIP := 0.2 # parte do dano que passa pela defesa, sem nocautear
const ROCK_COLUMNS := [-400.0, -200.0, 0.0, 200.0, 400.0] # em relação à posição marcada

# Cada ninja tem o seu formato de ataque ("pattern").
const SUPERS := {
	"air": {"name": "Olho do Furacão", "pattern": "hurricane", "startup": 20, "length": 80, "damage": 72, "max_hits": 4, "interval": 16,
		"height": "mid", "push": 0.0, "hitstun": 22, "blockstun": 14, "burn": 0, "root": 0},
	"gale": {"name": "Revoada", "pattern": "swoop", "startup": 16, "length": 78, "damage": 95, "max_hits": 3, "interval": 12,
		"height": "high", "push": 4.0, "hitstun": 22, "blockstun": 14, "burn": 0, "root": 0},
	"fire": {"name": "Dragão Solar", "pattern": "beam", "startup": 12, "length": 50, "damage": 55, "max_hits": 5, "interval": 6,
		"height": "mid", "push": 3.0, "hitstun": 14, "blockstun": 12, "burn": 60, "root": 0},
	"water": {"name": "Maremoto", "pattern": "wave", "startup": 14, "length": 80, "damage": 260, "max_hits": 1, "interval": 1,
		"height": "mid", "push": 18.0, "hitstun": 40, "blockstun": 20, "burn": 0, "root": 0},
	"plant": {"name": "Fúria da Floresta", "pattern": "roots", "startup": 10, "length": 76, "damage": 260, "max_hits": 1, "interval": 1,
		"height": "low", "push": 8.0, "hitstun": 36, "blockstun": 20, "burn": 0, "root": 60},
	"electric": {"name": "Céu Partido", "pattern": "strike", "startup": 40, "length": 16, "damage": 270, "max_hits": 1, "interval": 1,
		"height": "mid", "push": 10.0, "hitstun": 40, "blockstun": 20, "burn": 0, "root": 0},
	"earth": {"name": "Cataclismo", "pattern": "rocks", "startup": 34, "length": 30, "damage": 280, "max_hits": 1, "interval": 1,
		"height": "mid", "push": 10.0, "hitstun": 40, "blockstun": 20, "burn": 0, "root": 0},
	"ash": {"name": "Mil Lâminas", "pattern": "slashes", "startup": 18, "length": 72, "damage": 55, "max_hits": 5, "interval": 8,
		"height": "mid", "push": 1.0, "hitstun": 14, "blockstun": 12, "burn": 0, "root": 0},
	"frost": {"name": "Era Glacial", "pattern": "pincer", "startup": 24, "length": 56, "damage": 250, "max_hits": 1, "interval": 1,
		"height": "mid", "push": 2.0, "hitstun": 40, "blockstun": 20, "burn": 0, "root": 90},
	"thorn": {"name": "Abraço Carmesim", "pattern": "garden", "startup": 30, "length": 48, "damage": 230, "max_hits": 2, "interval": 20,
		"height": "low", "push": 2.0, "hitstun": 30, "blockstun": 18, "burn": 100, "root": 0},
	"thunder": {"name": "Punho do Trovão", "pattern": "fists", "startup": 12, "length": 66, "damage": 95, "max_hits": 3, "interval": 8,
		"height": "mid", "push": 5.0, "hitstun": 20, "blockstun": 14, "burn": 0, "root": 0},
	"sand": {"name": "Tempestade do Deserto", "pattern": "tornado", "startup": 14, "length": 110, "damage": 78, "max_hits": 4, "interval": 14,
		"height": "mid", "push": 0.0, "hitstun": 22, "blockstun": 14, "burn": 0, "root": 20},
}

static func duration(id: String) -> int:
	return SUPERS[id].startup + SUPERS[id].length

static func wave_x(cast: Dictionary) -> float:
	return cast.x + cast.facing * (60.0 + maxi(cast.age - SUPERS[cast.id].startup, 0) * 13.0)

# Quantas raízes já brotaram, e onde fica cada uma.
static func roots_up(cast: Dictionary) -> int:
	return clampi((cast.age - SUPERS[cast.id].startup) / 7 + 1, 0, 10)

static func root_x(cast: Dictionary, index: int) -> float:
	return cast.x + cast.facing * (80.0 + index * 90.0)

static func rock_y(cast: Dictionary) -> float:
	var progress := clampf((cast.age - SUPERS[cast.id].startup) / 22.0, 0.0, 1.0)
	return lerpf(-120.0, FLOOR_Y - 40, progress * progress)

const SLASH_EVERY := 14 # corte novo; fica ativo nos primeiros frames
const FIST_EVERY := 18
const FIST_HEIGHTS := [-120.0, -55.0, -95.0]
const GARDEN_STEP := 24 # a segunda leva de espinhos nasce nos vãos da primeira
const TORNADO_SPEED := 4.2

# Centro das duas paredes de gelo, que se fecham sobre a marca.
static func pincer_offset(cast: Dictionary) -> float:
	var progress := clampf((cast.age - SUPERS[cast.id].startup) / 44.0, 0.0, 1.0)
	return lerpf(430.0, 0.0, progress)

# Quantos punhos já saíram, e onde está cada um.
static func fist_at(cast: Dictionary, index: int) -> Vector2:
	var flight: int = cast.age - SUPERS[cast.id].startup - index * FIST_EVERY
	return Vector2(cast.x + cast.facing * (50.0 + flight * 24.0), FLOOR_Y + FIST_HEIGHTS[index])

# Colunas de espinhos da leva atual (0 ou 1), alternadas.
static func garden_columns(cast: Dictionary) -> Array:
	var wave := clampi((cast.age - SUPERS[cast.id].startup) / GARDEN_STEP, 0, 1)
	var result: Array = []
	for n in range(-3, 4):
		result.append(cast.target + n * 190.0 + wave * 95.0)
	return result

const SWOOP_EVERY := 24
const SWOOP_FLIGHT := 20 # frames do céu até o alvo

# Posição da ave atual da revoada; ela desce na diagonal até a marca.
static func swoop_at(cast: Dictionary) -> Vector2:
	var progress: float = ((cast.age - SUPERS[cast.id].startup) % SWOOP_EVERY) / float(SWOOP_FLIGHT)
	var mark: float = cast.get("track", cast.target)
	return Vector2(mark - cast.facing * 300.0, 60.0).lerp(Vector2(mark, FLOOR_Y - 85.0), progress)

# Áreas que ferem neste frame.
static func zones(cast: Dictionary) -> Array:
	var data: Dictionary = SUPERS[cast.id]
	var age: int = cast.age
	if age <= data.startup or age > data.startup + data.length:
		return []
	match data.pattern:
		"beam":
			var from: float = cast.x + cast.facing * 40.0
			var reach := minf((age - data.startup) * 70.0, 1000.0)
			return [Rect2(from if cast.facing > 0 else from - reach, FLOOR_Y - 135, reach, 75)]
		"wave":
			return [Rect2(wave_x(cast) - 55, FLOOR_Y - 90, 110, 90)]
		"roots":
			var last := roots_up(cast) - 1
			# Cada raiz fica ativa só enquanto está brotando.
			if (age - data.startup) % 7 > 4 or (age - data.startup) / 7 > 9:
				return []
			return [Rect2(root_x(cast, last) - 50, FLOOR_Y - 70, 100, 70)]
		"strike":
			return [Rect2(cast.target - 65, 0, 130, FLOOR_Y)]
		"hurricane":
			return [Rect2(cast.target - 120, FLOOR_Y - 260, 240, 260)]
		"swoop":
			var bird := swoop_at(cast)
			return [Rect2(bird.x - 45, bird.y - 40, 90, 80)]
		"slashes": # cortes que caçam o adversário
			if (age - data.startup) % SLASH_EVERY > 4:
				return []
			return [Rect2(cast.get("track", cast.target) - 55, FLOOR_Y - 170, 110, 170)]
		"pincer": # duas paredes se fechando; dá para saltar
			var gap := pincer_offset(cast)
			return [Rect2(cast.target - gap - 35, FLOOR_Y - 85, 70, 85), Rect2(cast.target + gap - 35, FLOOR_Y - 85, 70, 85)]
		"garden":
			if (age - data.startup) % GARDEN_STEP < 6 or (age - data.startup) % GARDEN_STEP > 14:
				return []
			return garden_columns(cast).map(func(x): return Rect2(x - 38, FLOOR_Y - 95, 76, 95))
		"fists":
			var result: Array = []
			for n in 3:
				if age - data.startup > n * FIST_EVERY:
					var at := fist_at(cast, n)
					result.append(Rect2(at.x - 40, at.y - 30, 80, 60))
			return result
		"tornado": # anda atrás do adversário
			return [Rect2(cast.get("pos", cast.x) - 50, FLOOR_Y - 210, 100, 210)]
		_:
			var y := rock_y(cast)
			var result: Array = []
			for offset in ROCK_COLUMNS:
				result.append(Rect2(cast.target + offset - 40, y - 40, 80, 80))
			return result
