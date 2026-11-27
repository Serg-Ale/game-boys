# Game Boys (nome provisório; o projeto Godot ainda se chama "Elemental Fighters")

Responder em português. Comandos, controles e estrutura do código estão no README.md.

## Tarefa atual: portar para Windows

O jogo foi desenvolvido no Linux com Godot 4.7.2 (versão padrão, sem .NET). Nunca foi testado no Windows.

1. Instalar o Godot 4.7.2 e os export templates da mesma versão (Editor > Manage Export Templates).
2. No PowerShell, usar o executável `*_console.exe` do Godot para ver a saída:

       godot --headless --path . --import
       godot --path .
       New-Item -ItemType Directory -Force build
       godot --headless --path . --export-release "Windows Desktop" build/GameBoys.exe

3. Testar o `build/GameBoys.exe`: teclado, controle, som e a opção Controles.

O preset `export_presets.cfg` foi escrito à mão e ainda não foi usado em um export; ajustar se o Godot reclamar.

## Cuidados

- Erro de sintaxe em um script faz o teste headless travar sem sair: conferir antes com `--quit-after 60` e limitar o tempo de execução.
- O comando `timeout 110` do README é do Linux; no PowerShell o `timeout` é outra coisa.
- Controle usado: 8BitDo Ultimate 2C (usar no modo XInput). Teclado principal: WASD + JKL.
- O usuário gosta de ver o jogo aberto após cada mudança e de receber notícia do andamento em esperas longas.

## Estado

Luta com 12 ninjas em 6 clãs e Modo Corrida (uma pista). Equilíbrio entre lutadores ainda não ajustado.
