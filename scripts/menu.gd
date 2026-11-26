# Navegação do título e da seleção. Só estado: o desenho fica no main.gd.
extends RefCounted

const Data = preload("res://scripts/data.gd")
const Controls = preload("res://scripts/controls.gd")
const OPTIONS := ["Jogar contra a CPU", "Dois jogadores", "Corrida", "Controles", "Sair"]

var screen := "title" # "title", "controls" ou "select"
var row := 0 # jogador em ajuste na tela de controles
var option := 0
var versus_cpu := true
var racing := false # escolhendo o corredor
var picks := ["fire", "water"]
var cursor := 0
var side := 0 # 0 = escolhendo o jogador 1, 1 = escolhendo o adversário

# Devolve "fight" ou "quit" quando o menu termina; senão, "".
func handle(action: String, player: int) -> String:
	if screen == "title":
		if action == "up" or action == "down":
			option = wrapi(option + (1 if action == "down" else -1), 0, OPTIONS.size())
		elif action == "confirm":
			if option == 4:
				return "quit"
			if option == 3:
				screen = "controls"
				row = 0
				return ""
			versus_cpu = option != 1
			racing = option == 2
			open_select()
		return ""
	if screen == "controls":
		match action:
			"up", "down":
				row = 1 - row
			"left", "right":
				Controls.cycle(row, 1 if action == "right" else -1)
			"confirm", "back":
				screen = "title"
				return "saved"
		return ""
	# Contra a CPU, o jogador 1 escolhe os dois. Em dupla, o jogador 2 também pode mexer na sua vez.
	if player == 1 and side == 0:
		return ""
	if action in ["left", "right", "up", "down"]:
		# Colunas são os clãs; as duas fileiras, os dois ninjas de cada um.
		var columns := Data.ELEMENTS.size()
		var column := cursor % columns
		var row := cursor / columns
		if action == "left" or action == "right":
			column = wrapi(column + (1 if action == "right" else -1), 0, columns)
		else:
			row = 1 - row
		cursor = row * columns + column
		picks[side] = Data.ROSTER[cursor]
	elif action == "confirm":
		picks[side] = Data.ROSTER[cursor]
		if racing:
			return "race"
		if side == 1:
			return "fight"
		side = 1
		cursor = Data.ROSTER.find(picks[1])
	elif action == "back":
		if side == 1:
			side = 0
			cursor = Data.ROSTER.find(picks[0])
		else:
			screen = "title"
	return ""

func open_select() -> void:
	screen = "select"
	side = 0
	cursor = Data.ROSTER.find(picks[0])
