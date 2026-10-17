extends SceneTree
## Rigenera tileset, scena del player e scena main.
## Uso (dalla cartella del progetto):
##   Godot --headless --import
##   Godot --headless --script res://tools/build_scenes.gd

const TILE := 32
const MAP_W := 40
const MAP_H := 24

# indici tile nell'atlas (vedi tools/make_tiles.py)
const SNOW_A := 0
const SNOW_B := 1
const SNOW_C := 2
const ROAD := 3
const EDGE_TOP := 4
const EDGE_BOTTOM := 5
const SNOW_ROCKS := 6
const ICE := 7


func _init() -> void:
	var tileset := _make_tileset()
	var err := ResourceSaver.save(tileset, "res://assets/tiles/terrain_tileset.tres")
	assert(err == OK)
	tileset = load("res://assets/tiles/terrain_tileset.tres")

	_save_scene(_make_player(), "res://scenes/player.tscn")
	_save_scene(_make_main(tileset), "res://scenes/main.tscn")
	print("Scene generate.")
	quit()


func _save_scene(root: Node, path: String) -> void:
	var packed := PackedScene.new()
	assert(packed.pack(root) == OK)
	assert(ResourceSaver.save(packed, path) == OK)
	root.free()


func _make_tileset() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE, TILE)
	var src := TileSetAtlasSource.new()
	src.texture = load("res://assets/tiles/terrain.png")
	src.texture_region_size = Vector2i(TILE, TILE)
	for i in 8:
		src.create_tile(Vector2i(i, 0))
	ts.add_source(src, 0)
	return ts


func _make_player() -> CharacterBody2D:
	var tex: Texture2D = load("res://assets/characters/player_walk.png")
	var frames: Array[AtlasTexture] = []
	for i in 3:
		var a := AtlasTexture.new()
		a.atlas = tex
		a.region = Rect2(i * 64, 0, 64, 64)
		frames.append(a)

	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	sf.add_animation("walk")
	sf.set_animation_speed("walk", 7.0)
	sf.set_animation_loop("walk", true)
	for i in [0, 1, 2, 1]:  # ciclo: passo - centro - passo - centro
		sf.add_frame("walk", frames[i])
	sf.add_animation("idle")
	sf.set_animation_speed("idle", 1.0)
	sf.set_animation_loop("idle", true)
	sf.add_frame("idle", frames[1])

	var player := CharacterBody2D.new()
	player.name = "Player"
	player.set_script(load("res://scripts/player.gd"))

	var sprite := AnimatedSprite2D.new()
	sprite.name = "AnimatedSprite2D"
	sprite.sprite_frames = sf
	sprite.animation = "idle"
	# i piedi nello spritesheet stanno a y~48 su 64: sposto lo sprite cosi' l'origine del nodo = piedi
	sprite.offset = Vector2(0, -16)
	player.add_child(sprite)
	sprite.owner = player

	var shape := CollisionShape2D.new()
	shape.name = "CollisionShape2D"
	var rect := RectangleShape2D.new()
	rect.size = Vector2(12, 6)
	shape.shape = rect
	shape.position = Vector2(0, -3)
	player.add_child(shape)
	shape.owner = player

	var cam := Camera2D.new()
	cam.name = "Camera2D"
	cam.position = Vector2(0, -18)
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 8.0
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = MAP_W * TILE
	cam.limit_bottom = MAP_H * TILE
	player.add_child(cam)
	cam.owner = player
	return player


func _road_center(x: int) -> int:
	return 12 + int(round(1.2 * sin(x * 0.13)))


func _make_main(tileset: TileSet) -> Node2D:
	var root := Node2D.new()
	root.name = "Main"

	var ground := TileMapLayer.new()
	ground.name = "Ground"
	ground.tile_set = tileset
	root.add_child(ground)
	ground.owner = root

	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for x in MAP_W:
		var c := _road_center(x)
		for y in MAP_H:
			var t := SNOW_A
			if y == c - 2:
				t = EDGE_TOP
			elif y >= c - 1 and y <= c + 1:
				t = ROAD
			elif y == c + 2:
				t = EDGE_BOTTOM
			else:
				var r := rng.randf()
				if r < 0.55: t = SNOW_A
				elif r < 0.80: t = SNOW_B
				elif r < 0.92: t = SNOW_C
				elif r < 0.96: t = SNOW_ROCKS
				else: t = ICE
			ground.set_cell(Vector2i(x, y), 0, Vector2i(t, 0))

	var player_scene: PackedScene = load("res://scenes/player.tscn")
	var player: CharacterBody2D = player_scene.instantiate()
	player.name = "Player"
	player.position = Vector2((4 + 0.5) * TILE, (_road_center(4) + 0.5) * TILE)
	root.add_child(player)
	player.owner = root

	var hud := CanvasLayer.new()
	hud.name = "HUD"
	root.add_child(hud)
	hud.owner = root
	var label := Label.new()
	label.name = "Help"
	label.text = "WASD / frecce: muovi il personaggio"
	label.position = Vector2(6, 4)
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(1, 1, 1))
	label.add_theme_color_override("font_outline_color", Color(0.15, 0.2, 0.3))
	label.add_theme_constant_override("outline_size", 4)
	hud.add_child(label)
	label.owner = root
	return root
