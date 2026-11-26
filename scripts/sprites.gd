# Carrega a pixel art e escolhe o quadro de cada lutador.
extends RefCounted

const Data = preload("res://scripts/data.gd")
const Fighter = preload("res://scripts/fighter.gd")
const Supers = preload("res://scripts/supers.gd")

const SIZE := Vector2(96, 72)
const ANCHOR := Vector2(48, 68) # ponto dos pés dentro do quadro
const SCALE := 3.0

var frames: PackedStringArray
var sheets := {}
var projectiles := {}
var columns := {}
var sparks := {}
var stages := {}
var creatures := {}
var riders := {}

func _init() -> void:
	frames = FileAccess.get_file_as_string("res://assets/frames.txt").split("\n", false)
	for key in Data.ROSTER:
		sheets[key] = load("res://assets/sprites/%s.png" % key)
		sheets[key + "_alt"] = load("res://assets/sprites/%s_alt.png" % key)
		sheets[key + "_form"] = load("res://assets/sprites/%s_form.png" % key)
	for key in Data.ROSTER:
		creatures[key] = load("res://assets/sprites/%s_creature.png" % key)
		riders[key] = load("res://assets/kart/rider_%s.png" % key)
	for kind in ["hit", "block"]:
		sparks[kind] = load("res://assets/sprites/spark_%s.png" % kind)
	for key in Data.ELEMENTS:
		projectiles[key] = load("res://assets/sprites/%s_projectile.png" % key)
		columns[key] = load("res://assets/sprites/%s_column.png" % key)
		stages[key] = load("res://assets/stage_%s.png" % key)

func draw(canvas: CanvasItem, sheet: String, frame: String, feet: Vector2, facing: int, scale := SCALE, tint := Color.WHITE) -> void:
	var source := Rect2(Vector2(frames.find(frame) * SIZE.x, 0), SIZE)
	canvas.draw_set_transform(feet, 0, Vector2(facing * scale, scale))
	canvas.draw_texture_rect_region(sheets[sheet], Rect2(-ANCHOR, SIZE), source, tint)
	canvas.draw_set_transform(Vector2.ZERO)

# "anchor" é o ponto do quadro (em pixels da arte) que fica em "at".
func _effect(canvas: CanvasItem, texture: Texture2D, size: Vector2, frame: int, at: Vector2, anchor: Vector2, scale: Vector2, tint := Color.WHITE, angle := 0.0) -> void:
	canvas.draw_set_transform(at, angle, scale)
	canvas.draw_texture_rect_region(texture, Rect2(-anchor, size), Rect2(Vector2((frame % 4) * size.x, 0), size), tint)
	canvas.draw_set_transform(Vector2.ZERO)

# A cabeça do projétil fica no centro da hitbox; o rastro vai para trás.
func draw_projectile(canvas: CanvasItem, key: String, center: Vector2, facing: int, time: int, scale := 2.5) -> void:
	_effect(canvas, projectiles[key], Vector2(48, 32), time / 4, center, Vector2(35, 16), Vector2(facing * scale, scale))

# Boneco girado, usado nas finalizações.
func draw_turned(canvas: CanvasItem, sheet: String, frame: String, center: Vector2, angle: float, facing: int) -> void:
	var source := Rect2(Vector2(frames.find(frame) * SIZE.x, 0), SIZE)
	canvas.draw_set_transform(center, angle, Vector2(facing * SCALE, SCALE))
	canvas.draw_texture_rect_region(sheets[sheet], Rect2(Vector2(-48, -44), SIZE), source)
	canvas.draw_set_transform(Vector2.ZERO)

# Projétil caindo de cima, com o rastro para o alto.
func draw_falling(canvas: CanvasItem, key: String, center: Vector2, scale: float) -> void:
	_effect(canvas, projectiles[key], Vector2(48, 32), 0, center, Vector2(35, 16), Vector2(scale, scale), Color.WHITE, PI / 2)

# Criatura invocada: "feet" é o ponto no chão; frame 1 é o ataque.
func draw_creature(canvas: CanvasItem, key: String, feet: Vector2, facing: int, frame: int, scale: float, tint := Color.WHITE) -> void:
	_effect(canvas, creatures[key], SIZE, frame, feet, ANCHOR, Vector2(facing * scale, scale), tint)

func draw_column(canvas: CanvasItem, key: String, feet: Vector2, time: int, width: float, height: float, tint := Color.WHITE) -> void:
	_effect(canvas, columns[key], Vector2(32, 80), time / 3, feet, Vector2(16, 80), Vector2(width / 32.0, height / 80.0), tint)

func draw_spark(canvas: CanvasItem, kind: String, at: Vector2, age: int, scale: float) -> void:
	_effect(canvas, sparks[kind], Vector2(40, 40), mini(age / 4, 3), at, Vector2(20, 20), Vector2(scale, scale))

static func frame_for(f, time: int, won: bool) -> String:
	match f.state:
		Fighter.State.IDLE:
			return "victory" if won else "idle_%d" % (time / 10 % 4)
		Fighter.State.WALK:
			return "walk_%d" % (f.frame / 7 % 4)
		Fighter.State.CROUCH:
			return "crouch"
		Fighter.State.JUMP:
			return "jump"
		Fighter.State.ATTACK:
			var data: Dictionary = Fighter.MOVES[f.move]
			var stance: String = "air" if f.air_attack else ("crouch" if f.crouching else "stand")
			var extended: bool = f.frame > data.startup and f.frame <= data.startup + data.active + 3
			match f.move:
				"launch":
					return "victory" if extended else "crouch"
				"sweep":
					return "crouch_kick_%d" % int(extended)
			return "%s_%s_%d" % [stance, f.move, int(extended)]
		Fighter.State.SPECIAL:
			var data: Dictionary = f.special_data()
			var released: bool = f.frame >= data.startup
			match data.type:
				"rush":
					return "stand_punch_1" if released else "special_0"
				"slide":
					return "crouch_kick_1" if released else "crouch"
				"pillar":
					return "victory" if released else "crouch"
				"mirror", "counter":
					return "block"
				"whip", "armor":
					return "stand_punch_1" if released else "special_0"
				"burst", "uppercut":
					return "victory" if released else "crouch"
				"quake", "trap":
					return "crouch_punch_1" if released else "special_0"
				"pounce":
					return "air_kick_1" if released else "crouch"
				"teleport":
					return "idle_0" if released else "crouch"
				_:
					return "special_%d" % int(released)
		Fighter.State.DASH:
			return "jump" if f.back_dash else "walk_0"
		Fighter.State.DOWN:
			return "ko" if f.frame < Fighter.DOWN_FRAMES - 10 else "crouch"
		Fighter.State.THROW:
			return "special_1" if f.frame > Fighter.THROW.startup else "special_0"
		Fighter.State.SUPER:
			if Supers.SUPERS[f.id].pattern in ["beam", "wave"]:
				return "special_%d" % int(f.frame > 10)
			return "victory"
		Fighter.State.HITSTUN:
			return "hit"
		Fighter.State.BLOCKSTUN:
			return "block_low" if f.crouching else "block"
		_:
			return "ko" if f.on_ground() and f.frame > 15 else "hit"
