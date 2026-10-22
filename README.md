# SnowyRoad

Progetto Godot 4.7 (pixel art). **F5** avvia il menu principale; le altre scene si provano con **F6**.

## 0. Menu e inizio partita (`scenes/menu.tscn`, scena principale)
- **New Game**: 4 secondi di schermo nero (segnaposto per la cutscene), poi il giocatore con un barlume di luce nel buio.
  Dopo 2 secondi arrivano i dialoghi (`scripts/intro.gd`): afferri il bastone, "Accendere la fiaccola?" Si'/No.
  *No*: rimetti il bastone a terra, la neve ti ricopre e torni al menu. *Si'*: animazione di accensione
  (`assets/ui/Animation fiamma.png`), fiamma che si muove per 4 secondi (`assets/ui/Fiaccola access.png`), il mondo si illumina un po'.
  Dopo la sequenza si puo' camminare; **Esc** torna al menu.
- **Load Game**: per ora non c'e' nessun salvataggio. **Options**: schermo intero e pixel perfect.
- Dialoghi: `scripts/dialog_box.gd` (`await dialog.say("...")`, `await dialog.ask("...?", ["Si'", "No"])`),
  cornice costruita da `assets/ui/Dialog Box.png` con `scripts/ui_frame.gd`, testo con `scripts/pix_text.gd` (font pixel di `pixfont.gd`).
- Tempi e luci della sequenza sono le costanti in cima a `scripts/intro.gd`.

## Schermo
Risoluzione interna **640x480 (4:3, come Omori)**: su schermi 16:9 ai lati restano due bande nere.
**F11** o **Alt+Invio** = schermo intero (anche dalle opzioni). "Pixel perfect" scala solo a multipli interi (pixel nitidissimi, bande piu' grandi).
Le scelte sono salvate in `user://settings.cfg`; `scripts/settings.gd` (autoload `GameSettings`) gestisce tutto.

## 1. Mondo (`scenes/main.tscn`)
Terreno pixelart (neve + strada) e personaggio top-down.
- Muovi il personaggio con **WASD** o con le **frecce**.
- Tre animazioni di camminata (3 frame 64x64, ciclo 0-1-2-1, 7 fps):
  - `assets/characters/player_front.png`: di fronte (verso il basso)
  - `assets/characters/player_back.png`: di schiena (verso l'alto)
  - `assets/characters/player_walk.png`: di profilo (a sinistra viene specchiato)

## 2. Combattimento (`scenes/battle.tscn`: aprila e premi **F6**)
Prova grafica (disegnata per 640x360: nel nuovo schermo 4:3 sta al centro con due fasce nere sopra e sotto) del combattimento: nemico grande in alto, bullet hell nel resto dello schermo (senza riquadro),
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
