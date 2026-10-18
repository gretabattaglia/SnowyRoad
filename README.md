# SnowyRoad

Progetto Godot 4.5 (pixel art). Due scene da provare:

## 1. Mondo (`scenes/main.tscn`: aprila e premi **F6**)
Terreno pixelart (neve + strada) e personaggio top-down.
- Muovi il personaggio con **WASD** o con le **frecce**.
- Tre animazioni di camminata (3 frame 64x64, ciclo 0-1-2-1, 7 fps):
  - `assets/characters/player_front.png`: di fronte (verso il basso)
  - `assets/characters/player_back.png`: di schiena (verso l'alto)
  - `assets/characters/player_walk.png`: di profilo (a sinistra viene specchiato)

## 2. Combattimento (`scenes/battle.tscn`, scena principale: **F5**)
Prova grafica del combattimento: nemico grande in alto, bullet hell nel resto dello schermo (senza riquadro),
luci e ombre sui nemici. Il personaggio con la torcia non c'e' ancora: la fiamma e' sola.
- Frecce / WASD: menu e movimento della fiamma. Invio / Z: conferma. Esc / X: indietro.
- **1** boss (`assets/bosses/boss_ombra.png`), **2** nemico normale (`assets/enemies/bush.png`), **R** ricomincia.
- Piu' la fiamma e' vicina all'occhio grande del nemico, piu' i proiettili sono fitti e piu' forte e' la fiamma rossa.
- `shaders/enemy_lit.gdshader`: luce della fiamma sul bordo dei nemici, controluce freddo, occhi che brillano.
- I parametri (durata del turno, danni, densita') sono in cima a `scripts/battle.gd`.
- Lo sfondo (`assets/battle/`) e il font pixel (`scripts/pixfont.gd`) sono provvisori.

## Cartelle
`assets/` (characters, tiles, bosses, enemies, battle, ui, audio) - `scenes/` - `scripts/` - `shaders/` - `tools/` - `docs/`

`tools/build_scenes.gd` rigenera tileset e scene del mondo (`Godot --headless --script res://tools/build_scenes.gd`).
