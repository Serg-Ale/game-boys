# Elemental Fighters (nome provisório)

Jogo de luta 2D em Godot 4: o torneio dos seis clãs ninja, dois lutadores por clã. Contra a CPU ou em dupla.

| Clã | Ninjas |
|---|---|
| Chama (Fogo) | Brasa, Cinza |
| Maré (Água) | Maré, Geada |
| Raiz (Planta) | Cipó, Espinho |
| Trovão (Elétrico) | Faísca, Trovão |
| Montanha (Terra) | Rocha, Duna |
| Vento (Ar) | Brisa, Falcão |

Cada ninja tem passiva, três especiais, supremo, criatura, finalização e transformação próprios (`scripts/data.gd`, `scripts/supers.gd`).

## Rodar

    godot --headless --path . --import   # só na primeira vez ou após mudar a arte
    godot --path .

## Comandos

| Ação | Teclado | 2º no teclado | Controle (layout Xbox) |
|---|---|---|---|
| Andar / abaixar | A D / S | setas | direcional ou analógico |
| Pular | W ou Espaço | ↑ | A |
| Soco | J | , ou num. 1 | X |
| Chute | K | . ou num. 2 | B |
| Especial | L | / ou num. 3 | Y |
| Agarrão | U | ; ou num. 4 | LB |
| Dash | I | ' ou num. 5 | RB |
| Transformar | O | ] ou num. 6 | L3 ou R3 |

A opção **Controles** do menu define o aparelho de cada jogador (salvo em `user://controls.cfg`). No automático, o controle é do jogador 1 e o teclado do jogador 2; sem controle, o jogador 2 usa as setas; contra a CPU, controle e teclado funcionam.

No menu: direcional ou WASD escolhe; A, J ou Enter confirma; B, K ou Esc volta. Na luta: Start / Enter pausa e mostra os golpes; Select / Esc volta à seleção.

## Combate

| Comando | Efeito |
|---|---|
| soco, soco, soco | sequência |
| soco, depois chute | emenda |
| golpe + especial | cancela no especial, se o golpe tocou |
| especial / frente + especial / baixo + especial | os três especiais |
| ← ↓ → + especial | supremo (barra cheia), invoca a criatura |
| frente + chute | lançador; pule para seguir no ar |
| baixo + chute | rasteira |
| agarrão (ou soco + chute) | não se defende; aperte na hora para escapar |
| dois toques na direção | dash |
| segurar para trás (e baixo) | defesa |

**Transformação:** quem já venceu um round pode se transformar; dura até o fim do round.
**Finalização:** quando o golpe que decide a luta é um especial.

Atalhos de teste: F1 hitboxes e comando recebido, F2 enche o supremo, F3 libera a transformação, M música.

## Código

A lógica (`fight.gd`, `fighter.gd`) é separada do desenho e roda sem janela. Arte e som são originais e gerados por script:

    python3 tools/make_sprites.py && python3 tools/make_creatures.py && python3 tools/make_sounds.py && python3 tools/make_track.py && python3 tools/make_riders.py

Testes (um erro de sintaxe pode travar o processo, por isso o `timeout`):

    timeout 110 godot --headless --path . --script res://tests/test_combat.gd

Equilíbrio entre CPUs: `godot --headless --path . --script res://tools/balance.gd`.

## Corrida (protótipo de direção)

Opção **Corrida** do menu: o ninja corre montado na própria criatura, em pseudo-3D. Por enquanto, uma pista (Vulcão da Chama), 3 voltas, sozinho, sem poderes.

| Ação | Controle | Teclado |
|---|---|---|
| Virar | analógico ou direcional | A / D |
| Acelerar | A ou RT | W |
| Frear / ré | B ou LT | S |
| Derrapar | RB | K ou Espaço |

Segure a derrapagem virando para carregar o turbo (azul, laranja, roxo) e solte. Acelerar quando aparece o "1" dá arrancada. Lógica em `scripts/kart/race.gd`, desenho em `scripts/kart/race_view.gd`, pista em `tools/make_track.py`, montarias em `tools/make_riders.py`. Testes: `tests/test_race.gd`.

**Próximos passos combinados:** 12 corredores com CPU, poderes em orbes, supremo, transformação como turbo, e uma pista por clã.
