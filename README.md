# SnowyRoad

Scena di prova in Godot 4.5: terreno pixelart (neve + strada) e personaggio top-down con animazione di camminata.

- Apri la cartella con Godot 4.5 e premi **F5** (scena principale: `scenes/main.tscn`).
- Muovi il personaggio con **WASD** o le **frecce**. Lo spritesheet ha una sola direzione (destra): a sinistra viene specchiato.
- `assets/characters/player_walk.png`: spritesheet 3 frame 64x64 (ciclo 0-1-2-1, 7 fps).
- `assets/tiles/terrain.png`: tileset 32x32, rigenerabile con `python tools/make_tiles.py`.
- `tools/build_scenes.gd`: rigenera tileset e scene (`Godot --headless --script res://tools/build_scenes.gd`).
