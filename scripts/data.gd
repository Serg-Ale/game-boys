# Clãs e lutadores como dados: ajuste os valores aqui.
extends RefCounted

const ADVANTAGE := 0.15 # vale só para especiais

const ELEMENTS := ["fire", "water", "plant", "electric", "earth", "air"]
const ELEMENT_NAMES := {"fire": "Fogo", "water": "Água", "plant": "Planta", "electric": "Elétrico", "earth": "Terra", "air": "Ar"}
# Cada ninja invoca a sua própria criatura no supremo.
const CREATURES := {"fire": "Ignar", "water": "Marulho", "plant": "Brotal", "electric": "Voltaro", "earth": "Terrão",
	"ash": "Fuligem", "frost": "Nevasco", "thorn": "Rosnara", "thunder": "Estrondo", "sand": "Ferrão", "air": "Zéfiro", "gale": "Altair"}
const CLAN_NAMES := {"fire": "Clã da Chama", "water": "Clã da Maré", "plant": "Clã da Raiz", "electric": "Clã do Trovão", "earth": "Clã da Montanha", "air": "Clã do Vento"}

# Cada elemento tem vantagem sobre dois e desvantagem contra dois.
const BEATS := {
	"fire": ["plant", "electric"],
	"water": ["fire", "earth"],
	"plant": ["water", "earth"],
	"electric": ["water", "air"],
	"earth": ["electric", "air"],
	"air": ["fire", "plant"],
}

# Os seis primeiros são um por clã; os seis seguintes, o segundo de cada clã, na mesma ordem.
const ROSTER := ["fire", "water", "plant", "electric", "earth", "air", "ash", "frost", "thorn", "thunder", "sand", "gale"]
# Nome da transformação de cada um.
const FORMS := {"fire": "Brasa Solar", "water": "Maré Abissal", "plant": "Cipó Ancião", "electric": "Faísca Supercarregada",
	"earth": "Rocha Titã", "air": "Brisa Celeste", "ash": "Cinza Fantasma", "frost": "Geada Absoluta",
	"thorn": "Espinho Escarlate", "thunder": "Trovão Furioso", "sand": "Duna Faraônica", "gale": "Falcão Real"}

# Tempos em frames (60 = 1 segundo). "neutral" = Y, "forward" = → + Y, "down" = ↓ + Y.
# "clan" é o elemento; "power" multiplica o dano de socos e chutes; "passive" é a habilidade fixa.
const FIGHTERS := {
	"fire": {
		"name": "Brasa", "clan": "fire", "title": "O Punho Indomável", "color": Color(0.93, 0.36, 0.18),
		"health": 950, "walk": 4.5, "power": 1.0,
		"style": "Pressão: avança e não para.",
		"passive": "fury", "passive_text": "Fúria: +15% de dano com pouca vida",
		"intro": "Meu fogo não pede licença.", "win": "Levante. Ainda tenho chama de sobra.",
		"specials": {
			"neutral": {"type": "projectile", "name": "Chama Viva", "cooldown": 180, "startup": 14, "active": 0, "recovery": 24,
				"speed": 8.0, "damage": 80, "push": 6.0, "burn": 120, "look": "fireball"},
			"forward": {"type": "rush", "name": "Investida Flamejante", "cooldown": 240, "startup": 12, "active": 16, "recovery": 20,
				"speed": 11.0, "damage": 75, "height": "mid", "push": 12.0, "hitstun": 24, "blockstun": 12, "burn": 60},
			"down": {"type": "pillar", "name": "Erupção", "cooldown": 300, "startup": 7, "active": 18, "recovery": 26,
				"damage": 95, "height": "mid", "push": 8.0, "hitstun": 30, "blockstun": 16},
		},
	},
	"water": {
		"name": "Maré", "clan": "water", "title": "A Guardiã das Correntes", "color": Color(0.2, 0.55, 0.95),
		"health": 1000, "walk": 4.0, "power": 1.0,
		"style": "Controle: dita a distância da luta.",
		"passive": "flow", "passive_text": "Fluidez: especiais recarregam 20% mais rápido",
		"intro": "Água calma também afoga.", "win": "A corrente sempre encontra o caminho.",
		"specials": {
			"neutral": {"type": "projectile", "name": "Onda de Choque", "cooldown": 180, "startup": 14, "active": 0, "recovery": 24,
				"speed": 6.0, "damage": 90, "push": 14.0, "look": "wave", "size": 1.7},
			"forward": {"type": "slide", "name": "Deslize", "cooldown": 240, "startup": 8, "active": 20, "recovery": 18,
				"speed": 9.5, "damage": 80, "height": "low", "push": 9.0, "hitstun": 24, "blockstun": 12},
			"down": {"type": "mirror", "name": "Espelho d'Água", "cooldown": 300, "startup": 4, "active": 30, "recovery": 14,
				"damage": 50, "height": "mid", "push": 14.0, "hitstun": 18, "blockstun": 10},
		},
	},
	"plant": {
		"name": "Cipó", "clan": "plant", "title": "O Jardineiro Paciente", "color": Color(0.32, 0.7, 0.3),
		"health": 1050, "walk": 3.8, "power": 1.05,
		"weight": 1, "reach": 1.08,
		"style": "Armadilhas: prende, puxa e espera.",
		"passive": "sap", "passive_text": "Seiva: recupera vida aos poucos",
		"intro": "Toda raiz começa em silêncio.", "win": "Descanse. A terra cuida do resto.",
		"specials": {
			"neutral": {"type": "projectile", "name": "Semente Presa", "cooldown": 300, "startup": 14, "active": 0, "recovery": 24,
				"speed": 5.0, "damage": 70, "push": 2.0, "root": 75, "look": "seed"},
			"forward": {"type": "whip", "name": "Chicote de Cipó", "cooldown": 240, "startup": 14, "active": 6, "recovery": 22,
				"damage": 70, "height": "mid", "push": -13.0, "hitstun": 26, "blockstun": 12},
			"down": {"type": "trap", "name": "Raiz Oculta", "cooldown": 360, "startup": 12, "active": 0, "recovery": 18,
				"distance": 220.0, "damage": 80, "push": 0.0, "root": 80},
		},
	},
	"electric": {
		"name": "Faísca", "clan": "electric", "title": "O Mensageiro Veloz", "color": Color(0.95, 0.82, 0.15),
		"health": 1000, "walk": 5.6, "power": 1.12, "jump": 19.0,
		"weight": -2, "reach": 0.92,
		"style": "Velocidade: some e reaparece.",
		"passive": "light", "passive_text": "Pés Ligeiros: pula mais alto",
		"intro": "Piscou, perdeu.", "win": "Já acabou? Eu nem aqueci!",
		"specials": {
			"neutral": {"type": "projectile", "name": "Raio Curto", "cooldown": 130, "startup": 14, "active": 0, "recovery": 24,
				"speed": 12.0, "damage": 90, "push": 5.0, "look": "bolt"},
			"forward": {"type": "teleport", "name": "Piscar", "cooldown": 240, "startup": 10, "active": 1, "recovery": 10},
			"down": {"type": "burst", "name": "Descarga", "cooldown": 270, "startup": 8, "active": 10, "recovery": 22,
				"damage": 125, "height": "mid", "push": 13.0, "hitstun": 28, "blockstun": 14},
		},
	},
	"earth": {
		"name": "Rocha", "clan": "earth", "title": "A Muralha Serena", "color": Color(0.66, 0.45, 0.27),
		"health": 1080, "walk": 3.0, "power": 1.06,
		"weight": 3, "reach": 1.14,
		"style": "Resistência: aguenta e esmaga.",
		"passive": "shell", "passive_text": "Couraça: recebe 10% menos dano",
		"intro": "Pode bater. Eu espero.", "win": "A montanha continua de pé.",
		"specials": {
			"neutral": {"type": "projectile", "name": "Pedregulho", "cooldown": 270, "startup": 14, "active": 0, "recovery": 24,
				"speed": 4.0, "damage": 120, "push": 10.0, "look": "boulder", "roll": true},
			"forward": {"type": "armor", "name": "Ombrada", "cooldown": 270, "startup": 14, "active": 18, "recovery": 24,
				"speed": 8.0, "damage": 95, "height": "mid", "push": 16.0, "hitstun": 28, "blockstun": 16},
			"down": {"type": "quake", "name": "Tremor", "cooldown": 330, "startup": 22, "active": 6, "recovery": 26,
				"damage": 90, "height": "low", "push": 5.0, "hitstun": 32, "blockstun": 14},
		},
	},
	"ash": {
		"name": "Cinza", "clan": "fire", "title": "A Sombra do Incêndio", "color": Color(1.0, 0.5, 0.45),
		"health": 1000, "walk": 5.2, "power": 1.1,
		"weight": -3, "reach": 0.9,
		"style": "Assassina: pula duas vezes e ataca pelas costas.",
		"passive": "double", "passive_text": "Salto Duplo: pula de novo no ar",
		"intro": "Brasa faz barulho. Eu faço silêncio.", "win": "Você só viu a fumaça.",
		"specials": {
			"neutral": {"type": "projectile", "name": "Leque de Brasas", "cooldown": 200, "startup": 10, "active": 0, "recovery": 20,
				"speed": 9.0, "damage": 52, "push": 3.0, "fan": [-1.4, 0.0, 1.4], "look": "ember"},
			"forward": {"type": "phase", "name": "Corte Fantasma", "cooldown": 270, "startup": 9, "active": 14, "recovery": 20,
				"speed": 17.0, "damage": 80, "height": "mid", "push": 4.0, "hitstun": 28, "blockstun": 12},
			"down": {"type": "projectile", "name": "Bomba de Pólvora", "cooldown": 300, "startup": 16, "active": 0, "recovery": 22,
				"speed": 5.5, "damage": 130, "push": 12.0, "burn": 90, "lift": -11.0, "gravity": 0.55, "look": "bomb"},
		},
	},
	"frost": {
		"name": "Geada", "clan": "water", "title": "O Monge do Inverno", "color": Color(0.7, 0.92, 1.0),
		"health": 1100, "walk": 4.0, "power": 1.1,
		"weight": 2, "reach": 1.08,
		"style": "Contragolpe: espera o erro e congela.",
		"passive": "chill", "passive_text": "Toque Gélido: seus golpes deixam o rival lento",
		"intro": "Respire fundo. Vai esfriar.", "win": "A pressa foi o seu inverno.",
		"specials": {
			"neutral": {"type": "projectile", "name": "Lança de Gelo", "cooldown": 210, "startup": 18, "active": 0, "recovery": 24,
				"speed": 7.0, "damage": 100, "push": 5.0, "look": "lance", "pierce": true},
			"forward": {"type": "wall", "name": "Muralha de Gelo", "cooldown": 330, "startup": 14, "active": 0, "recovery": 18,
				"distance": 105.0, "damage": 60, "push": 12.0, "life": 150},
			"down": {"type": "counter", "name": "Contra-Gelo", "cooldown": 300, "startup": 3, "active": 26, "recovery": 18,
				"damage": 120, "height": "mid", "push": 8.0, "hitstun": 36, "blockstun": 16, "root": 60},
		},
	},
	"thorn": {
		"name": "Espinho", "clan": "plant", "title": "A Rosa Carmesim", "color": Color(0.75, 0.85, 0.3),
		"health": 950, "walk": 4.4, "power": 1.0,
		"weight": 0, "reach": 1.12,
		"style": "Veneno: fere à distância e rouba vida.",
		"passive": "drain", "passive_text": "Sorver: especiais devolvem 25% do dano em vida",
		"intro": "Bonita, não é? Não toque.", "win": "Cada espinho lembra o seu nome.",
		"specials": {
			"neutral": {"type": "projectile", "name": "Dardo Venenoso", "cooldown": 180, "startup": 12, "active": 0, "recovery": 22,
				"speed": 11.0, "damage": 32, "push": 1.0, "burn": 120, "look": "dart", "volley": 3},
			"forward": {"type": "pounce", "name": "Salto Espinhoso", "cooldown": 240, "startup": 10, "active": 30, "recovery": 12,
				"speed": 8.0, "damage": 95, "height": "high", "push": 9.0, "hitstun": 26, "blockstun": 14},
			"down": {"type": "rain", "name": "Chuva de Espinhos", "cooldown": 300, "startup": 14, "active": 0, "recovery": 22,
				"damage": 40, "push": 2.0, "burn": 60},
		},
	},
	"thunder": {
		"name": "Trovão", "clan": "electric", "title": "O Boxeador da Tempestade", "color": Color(0.72, 0.6, 1.0),
		"health": 900, "walk": 4.5, "power": 0.9,
		"weight": -2, "reach": 0.92,
		"style": "Combos: socos e chutes sem respiro.",
		"passive": "flurry", "passive_text": "Rajada: socos e chutes se recuperam mais rápido",
		"intro": "Faísca corre. Eu bato.", "win": "Ouviu? Esse foi o trovão chegando depois.",
		"specials": {
			"neutral": {"type": "projectile", "name": "Esfera Trovejante", "cooldown": 270, "startup": 22, "active": 0, "recovery": 24,
				"speed": 4.5, "damage": 90, "push": 9.0, "look": "orb", "stall": 62, "life": 130},
			"forward": {"type": "barrage", "name": "Metralhadora Elétrica", "cooldown": 240, "startup": 7, "active": 24, "recovery": 18,
				"damage": 24, "height": "mid", "push": 1.5, "hitstun": 16, "blockstun": 9},
			"down": {"type": "uppercut", "name": "Gancho Voltaico", "cooldown": 270, "startup": 5, "active": 14, "recovery": 28,
				"damage": 80, "height": "mid", "push": 7.0, "hitstun": 32, "blockstun": 14},
		},
	},
	"sand": {
		"name": "Duna", "clan": "earth", "title": "A Miragem do Deserto", "color": Color(0.95, 0.8, 0.5),
		"health": 1100, "walk": 4.5, "power": 1.18,
		"weight": -1, "reach": 1.0,
		"style": "Truques: some na areia e domina a energia.",
		"passive": "focus", "passive_text": "Foco: o supremo carrega 50% mais rápido",
		"intro": "O que você vê nem sempre está lá.", "win": "O deserto engole os apressados.",
		"specials": {
			"neutral": {"type": "projectile", "name": "Rajada de Areia", "cooldown": 100, "startup": 10, "active": 0, "recovery": 18,
				"speed": 9.0, "damage": 95, "push": 11.0, "life": 42, "look": "gust"},
			"forward": {"type": "dig", "name": "Mergulho na Areia", "cooldown": 300, "startup": 10, "active": 34, "recovery": 16,
				"speed": 11.0, "damage": 95, "height": "low", "push": 4.0, "hitstun": 30, "blockstun": 14, "launch": -13.0},
			"down": {"type": "quicksand", "name": "Areia Movediça", "cooldown": 360, "startup": 14, "active": 0, "recovery": 18,
				"distance": 190.0, "damage": 0, "push": 0.0, "life": 260},
		},
	},
	"air": {
		"name": "Brisa", "clan": "air", "title": "A Dançarina dos Ventos", "color": Color(0.7, 1.0, 0.88),
		"health": 960, "walk": 5.0, "power": 1.0,
		"weight": -2, "reach": 1.0,
		"style": "Acrobata: plana e domina o céu.",
		"passive": "glide", "passive_text": "Leveza: segure o pulo para planar",
		"intro": "Tente segurar o vento.", "win": "Leve como sempre.",
		"specials": {
			"neutral": {"type": "projectile", "name": "Lâmina de Vento", "cooldown": 190, "startup": 11, "active": 0, "recovery": 20,
				"speed": 11.0, "damage": 80, "push": 6.0, "look": "crescent", "boomerang": true, "life": 90},
			"forward": {"type": "push", "name": "Rajada Violenta", "cooldown": 230, "startup": 10, "active": 10, "recovery": 18,
				"damage": 55, "height": "mid", "push": 22.0, "hitstun": 22, "blockstun": 14},
			"down": {"type": "cyclone", "name": "Ciclone Ascendente", "cooldown": 300, "startup": 8, "active": 14, "recovery": 24,
				"damage": 75, "height": "mid", "push": 2.0, "hitstun": 40, "blockstun": 14, "launch": -17.0},
		},
	},
	"gale": {
		"name": "Falcão", "clan": "air", "title": "O Caçador das Alturas", "color": Color(0.85, 0.9, 0.55),
		"health": 1000, "walk": 4.7, "power": 1.05,
		"weight": 0, "reach": 1.06,
		"style": "Caçador: mergulha e pune quem sai do chão.",
		"passive": "hunter", "passive_text": "Caçador: +20% de dano em quem está no ar",
		"intro": "Do alto, vejo todos os seus erros.", "win": "A presa nunca olha para cima.",
		"specials": {
			"neutral": {"type": "projectile", "name": "Pena Cortante", "cooldown": 170, "startup": 12, "active": 0, "recovery": 20,
				"speed": 8.0, "damage": 80, "push": 5.0, "look": "feather", "wavy": 48.0},
			"forward": {"type": "dive", "name": "Mergulho do Falcão", "cooldown": 260, "startup": 7, "active": 32, "recovery": 12,
				"damage": 105, "height": "high", "push": 10.0, "hitstun": 28, "blockstun": 14},
			"down": {"type": "vortex", "name": "Vácuo", "cooldown": 360, "startup": 14, "active": 0, "recovery": 18,
				"distance": 170.0, "damage": 0, "push": 0.0, "life": 130},
		},
	},
}

static func multiplier(attacker: String, defender: String) -> float:
	if defender in BEATS[attacker]:
		return 1.0 + ADVANTAGE
	if attacker in BEATS[defender]:
		return 1.0 - ADVANTAGE
	return 1.0
