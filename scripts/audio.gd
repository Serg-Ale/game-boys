# Toca os efeitos e as músicas, e deduz os sons da luta a partir das mudanças de estado.
extends Node

const Data = preload("res://scripts/data.gd")
const Fighter = preload("res://scripts/fighter.gd")
const Finisher = preload("res://scripts/finisher.gd")

const EFFECTS := ["move", "confirm", "back", "versus", "punch_swing", "kick_swing", "hit", "hit_heavy", "block",
	"jump", "land", "ko", "special_fire", "special_water", "special_plant", "special_electric", "special_earth",
	"finish_call", "finish_blow", "finish_title", "victory", "roar_fire", "roar_water", "roar_plant", "roar_electric", "roar_earth", "roar_air", "special_air", "transform", "kart_boost", "kart_charge", "kart_bump", "count", "go", "lap"]
const VOICES := 10
const MUSIC_DB := -12.0

var sounds := {}
var players: Array = []
var music := AudioStreamPlayer.new()
var engine := AudioStreamPlayer.new()
var skid := AudioStreamPlayer.new()
var track := ""
var muted := false
var next_voice := 0
var last_states := [Fighter.State.IDLE, Fighter.State.IDLE]
var round_over := false
var match_done := false

func _ready() -> void:
	for name in EFFECTS:
		sounds[name] = load("res://assets/sounds/%s.wav" % name)
	for i in VOICES:
		var player := AudioStreamPlayer.new()
		add_child(player)
		players.append(player)
	music.volume_db = MUSIC_DB
	add_child(music)
	for pair in [[engine, "kart_engine"], [skid, "kart_drift"]]:
		var stream: AudioStreamWAV = load("res://assets/sounds/%s.wav" % pair[1])
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = roundi(stream.get_length() * stream.mix_rate)
		pair[0].stream = stream
		add_child(pair[0])

func play(name: String, volume_db := 0.0, pitch := 1.0) -> void:
	var player: AudioStreamPlayer = players[next_voice]
	next_voice = (next_voice + 1) % players.size()
	player.stream = sounds[name]
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.play()

# "menu" ou o nome de um elemento. Chamar de novo com a mesma faixa não reinicia.
func play_music(name: String) -> void:
	if name == track:
		return
	track = name
	if name == "":
		music.stop()
		return
	var stream: AudioStreamWAV = load("res://assets/sounds/music_%s.wav" % name)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = roundi(stream.get_length() * stream.mix_rate)
	music.stream = stream
	if not muted:
		music.play()

func toggle_music() -> void:
	muted = not muted
	if muted:
		music.stop()
	elif track != "":
		music.play()

# Galope contínuo, mais agudo quanto mais rápido, e o chiado da derrapagem.
func race_sounds(race) -> void:
	var running: bool = absf(race.speed) > 0.4 and not race.finished
	if running != engine.playing:
		if running:
			engine.play()
		else:
			engine.stop()
	engine.pitch_scale = 0.6 + clampf(absf(race.speed) / race.max_speed, 0.0, 1.5)
	engine.volume_db = -16.0
	var sliding: bool = race.drift != 0 and not race.finished
	if sliding != skid.playing:
		if sliding:
			skid.play()
		else:
			skid.stop()
	skid.volume_db = -12.0

func stop_race() -> void:
	engine.stop()
	skid.stop()

func reset_fight() -> void:
	last_states = [Fighter.State.IDLE, Fighter.State.IDLE]
	round_over = false
	match_done = false

# Chamar depois de cada step da luta.
func watch(fight) -> void:
	for i in 2:
		var f = fight.fighters[i]
		var before: int = last_states[i]
		if f.state != before:
			match f.state:
				Fighter.State.ATTACK:
					play(f.move + "_swing", -6.0)
				Fighter.State.SPECIAL:
					play("special_" + f.element, -2.0, {"neutral": 1.0, "forward": 1.18, "down": 0.85}[f.slot])
				Fighter.State.SUPER:
					play("finish_call", 2.0)
					play("roar_" + f.element, 3.0)
				Fighter.State.JUMP:
					if before != Fighter.State.ATTACK:
						play("jump", -8.0)
			if before == Fighter.State.JUMP and f.on_ground():
				play("land", -6.0)
		last_states[i] = f.state

	if not fight.transforming.is_empty() and fight.transforming.age == 0:
		play("transform", 2.0)

	# O estrondo vem quando o supremo dispara.
	if not fight.cast.is_empty() and fight.freeze == 0 and fight.cast.age == fight.Supers.SUPERS[fight.cast.id].startup + 1 and fight.hitstop == 0:
		play("finish_blow")
		play("special_" + fight.cast.element, 2.0, 0.65)

	var over: bool = fight.pause > 0 or fight.match_over
	if over and not round_over and (fight.fighters[0].health == 0 or fight.fighters[1].health == 0):
		play("ko")
	round_over = over
	if fight.match_over and not match_done:
		match_done = true
		play_music("")
		if fight.finisher.is_empty():
			play("victory")

func impact(hit: Dictionary) -> void:
	if hit.blocked:
		play("block", -3.0)
	else:
		play("hit_heavy" if hit.strong else "hit", 0.0, randf_range(0.92, 1.08))

# Chamar a cada frame da finalização.
func finisher(element: String, age: int) -> void:
	if age == 1:
		play("finish_call")
	elif age == Finisher.START:
		play("special_" + element, 0.0, 0.7)
	elif age == Finisher.CLIMAX:
		play("finish_blow", 2.0)
	elif age == Finisher.CLIMAX + 20:
		play("finish_title")
	elif element == "electric" and age > Finisher.START and age < Finisher.CLIMAX and age % 24 == 0:
		play("special_electric", -2.0)
