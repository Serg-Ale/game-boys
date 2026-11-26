# Traduz teclado e controle para as mesmas ações, e define qual jogador usa o quê.
extends RefCounted

# "main" é o teclado principal (WASD + JKL). "arrows" só é usado quando os dois jogam no teclado.
const LAYOUTS := {
	"main": {"left": [KEY_A], "right": [KEY_D], "jump": [KEY_W, KEY_SPACE], "down": [KEY_S],
		"punch": [KEY_J], "kick": [KEY_K], "special": [KEY_L], "grab": [KEY_U], "dash": [KEY_I], "transform": [KEY_O]},
	"arrows": {"left": [KEY_LEFT], "right": [KEY_RIGHT], "jump": [KEY_UP], "down": [KEY_DOWN],
		"punch": [KEY_KP_1, KEY_COMMA], "kick": [KEY_KP_2, KEY_PERIOD], "special": [KEY_KP_3, KEY_SLASH],
		"grab": [KEY_KP_4, KEY_SEMICOLON], "dash": [KEY_KP_5, KEY_APOSTROPHE], "transform": [KEY_KP_6, KEY_BRACKETRIGHT]},
}
const BUTTONS := {
	"left": [JOY_BUTTON_DPAD_LEFT], "right": [JOY_BUTTON_DPAD_RIGHT], "jump": [JOY_BUTTON_A], "down": [JOY_BUTTON_DPAD_DOWN],
	"punch": [JOY_BUTTON_X], "kick": [JOY_BUTTON_B], "special": [JOY_BUTTON_Y],
	"grab": [JOY_BUTTON_LEFT_SHOULDER], "dash": [JOY_BUTTON_RIGHT_SHOULDER],
	"transform": [JOY_BUTTON_LEFT_STICK, JOY_BUTTON_RIGHT_STICK], # L3 ou R3
}
# Nome de cada comando para mostrar na tela.
const PAD_NAMES := {"punch": "X", "kick": "B", "special": "Y", "jump": "A", "grab": "LB", "dash": "RB", "transform": "L3/R3"}
const KEY_NAMES := {
	"main": {"punch": "J", "kick": "K", "special": "L", "jump": "W", "grab": "U", "dash": "I", "transform": "O"},
	"arrows": {"punch": ",", "kick": ".", "special": "/", "jump": "↑", "grab": ";", "dash": "'", "transform": "]"},
}
const CHOICES := ["auto", "keyboard", "pad"]
const CHOICE_NAMES := {"auto": "Automático", "keyboard": "Teclado", "pad": "Controle"}
const DEADZONE := 0.5
const SAVE_PATH := "user://controls.cfg"

static var choices := ["auto", "auto"]
static var devices := [{"layout": "main", "pad": -1}, {"layout": "arrows", "pad": -1}]

# Quem usa o quê. "pads" são os controles ligados; "solo" é a partida contra a CPU.
# No automático, o controle é do jogador 1 e o teclado, do jogador 2.
static func resolve(chosen: Array, pads: Array, solo: bool) -> Array:
	var free := pads.duplicate()
	var result := [{"layout": "", "pad": -1}, {"layout": "", "pad": -1}]
	for wanted in ["pad", "auto"]: # quem pediu controle escolhe primeiro
		for i in 2:
			if chosen[i] == wanted and result[i].pad < 0 and not free.is_empty():
				result[i].pad = free.pop_front()
	var on_keyboard: Array = [0, 1].filter(func(i): return result[i].pad < 0)
	for i in on_keyboard:
		result[i].layout = "arrows" if i == 1 and on_keyboard.size() == 2 else "main"
	# Sozinho contra a CPU, no automático, vale tanto o controle quanto o teclado.
	if solo and chosen[0] == "auto":
		result[0].layout = "main"
	return result

static func refresh(solo: bool) -> void:
	devices = resolve(choices, Input.get_connected_joypads(), solo)

static func read(player: int) -> Dictionary:
	var device: Dictionary = devices[player]
	var result := {}
	for action in BUTTONS:
		var down := false
		if device.layout != "":
			for key in LAYOUTS[device.layout][action]:
				down = down or Input.is_physical_key_pressed(key)
		if device.pad >= 0:
			for button in BUTTONS[action]:
				down = down or Input.is_joy_button_pressed(device.pad, button)
		result[action] = down
	if device.pad >= 0:
		var x := Input.get_joy_axis(device.pad, JOY_AXIS_LEFT_X)
		var y := Input.get_joy_axis(device.pad, JOY_AXIS_LEFT_Y)
		result.left = result.left or x < -DEADZONE
		result.right = result.right or x > DEADZONE
		result.down = result.down or y > DEADZONE
	return result

# Comandos da corrida: acelerar, frear, virar (analógico) e derrapar.
static func read_race() -> Dictionary:
	var device: Dictionary = devices[0]
	var result := {"accel": false, "brake": false, "drift": false, "steer": 0.0}
	if device.layout != "":
		result.accel = Input.is_physical_key_pressed(KEY_W)
		result.brake = Input.is_physical_key_pressed(KEY_S)
		result.drift = Input.is_physical_key_pressed(KEY_K) or Input.is_physical_key_pressed(KEY_SPACE)
		result.steer = float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A))
	var pad: int = device.pad
	if pad >= 0:
		result.accel = result.accel or Input.is_joy_button_pressed(pad, JOY_BUTTON_A) or Input.get_joy_axis(pad, JOY_AXIS_TRIGGER_RIGHT) > 0.25
		result.brake = result.brake or Input.is_joy_button_pressed(pad, JOY_BUTTON_B) or Input.get_joy_axis(pad, JOY_AXIS_TRIGGER_LEFT) > 0.25
		result.drift = result.drift or Input.is_joy_button_pressed(pad, JOY_BUTTON_RIGHT_SHOULDER)
		var x := Input.get_joy_axis(pad, JOY_AXIS_LEFT_X)
		if absf(x) > 0.15:
			result.steer = x
		if Input.is_joy_button_pressed(pad, JOY_BUTTON_DPAD_LEFT):
			result.steer = -1.0
		if Input.is_joy_button_pressed(pad, JOY_BUTTON_DPAD_RIGHT):
			result.steer = 1.0
	return result

static func uses_pad(player: int) -> bool:
	return devices[player].pad >= 0

static func name_of(action: String, player: int) -> String:
	if uses_pad(player):
		return PAD_NAMES[action]
	return KEY_NAMES[devices[player].layout][action]

# Texto curto do aparelho de um jogador.
static func describe(player: int) -> String:
	var device: Dictionary = devices[player]
	var keys: String = {"main": "teclado WASD + JKL", "arrows": "teclado nas setas", "": ""}[device.layout]
	if device.pad < 0:
		return keys
	var pad := "controle %d" % (Input.get_connected_joypads().find(device.pad) + 1)
	return pad if keys == "" else "%s ou %s" % [pad, keys]

static func cycle(player: int, step: int) -> void:
	choices[player] = CHOICES[wrapi(CHOICES.find(choices[player]) + step, 0, CHOICES.size())]

static func load_choices() -> void:
	var file := ConfigFile.new()
	if file.load(SAVE_PATH) != OK:
		return
	for i in 2:
		var value: String = file.get_value("players", "player%d" % (i + 1), "auto")
		choices[i] = value if value in CHOICES else "auto"

static func save_choices() -> void:
	var file := ConfigFile.new()
	for i in 2:
		file.set_value("players", "player%d" % (i + 1), choices[i])
	file.save(SAVE_PATH)
