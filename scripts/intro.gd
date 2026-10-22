extends Node
## Sequenza iniziale di "New Game".
##  1. schermata nera di 4 secondi (segnaposto: qui andra' il disegno della cutscene)
##  2. si vede il giocatore con un piccolo barlume di luce, tutto il resto e' buio pesto
##  3. dopo 2 secondi parlano i dialoghi: il bastone, "Accendere la fiaccola?" con scelta Si'/No
##     - No: il bastone torna a terra, la neve ti ricopre e si torna al menu
##     - Si': animazione di accensione + fiamma che si muove per 4 secondi, poi il mondo si illumina un po'
## Dopo la sequenza si puo' camminare; Esc torna al menu.

const WORLD := preload("res://scenes/main.tscn")
const DialogBox := preload("res://scripts/dialog_box.gd")
const STICK_TEX := preload("res://assets/items/Fiaccola.png")
const IGNITE_SHEET := preload("res://assets/ui/Animation fiamma.png")
const BURN_SHEET := preload("res://assets/ui/Fiaccola access.png")
const MENU_SCENE := "res://scenes/menu.tscn"

# ---- tempi (secondi)
const CUTSCENE_TIME := 4.0      # schermata nera iniziale
const FADE_IN_TIME := 1.5       # dal nero al mondo buio
const DIALOGUE_DELAY := 2.0     # dopo che il mondo si illumina, prima del primo dialogo
const LINE_GAP := 0.3           # tra una frase e l'altra la finestra sparisce
const NIGHT_FADE_TIME := 1.0
const BURN_TIME := 4.0          # la fiamma accesa si muove per 4 secondi
const LIGHT_UP_TIME := 2.5
const DARKEN_TIME := 3.0

# ---- luce
const AMBIENT_DARK := Color(0.004, 0.005, 0.011)    # buio pesto
const AMBIENT_LIT := Color(0.085, 0.11, 0.185)        # notte un po' piu' chiara
const LIGHT_COLOR := Color(1.0, 0.8, 0.52)
const LIGHT_DIM := {"energy": 0.55, "scale": 0.38}  # barlume iniziale: illumina appena il giocatore
const LIGHT_LIT := {"energy": 0.8, "scale": 0.95}  # dopo l'accensione
const LIGHT_OFFSET := Vector2(0, -18)               # centro del corpo del giocatore

# ---- fiaccola (spritesheet a celle 256x256, 8 colonne)
const CELL := 256
const COLUMNS := 8
const IGNITE_FRAMES := 17
const BURN_FRAMES := 9
const NIGHT_COLOR := Color(0.012, 0.018, 0.045)
const TORCH_SCALE := 1.5
# la base del bastone e' l'ultima riga della cella: la appoggio al bordo inferiore dello schermo (480)
const TORCH_POS := Vector2(320, 480.0 - CELL * TORCH_SCALE * 0.5)
const FLAME_POS := TORCH_POS + Vector2(0, -28 * TORCH_SCALE)   # la fiamma sta circa 28 px sopra il centro della cella

var light_energy: float = LIGHT_DIM.energy
var light_scale: float = LIGHT_DIM.scale

var world: Node2D
var player: CharacterBody2D
var stick: Sprite2D
var darkness: CanvasModulate
var light: PointLight2D
var dialog: Node
var cover: ColorRect
var roaming := false

var _overlay: Control
var _torch: AnimatedSprite2D
var _glow: Sprite2D
var _glow_level := 0.0
var _time := 0.0


func _ready() -> void:
	world = WORLD.instantiate()
	add_child(world)
	world.get_node("HUD").queue_free()   # la scritta di aiuto non serve qui
	player = world.get_node("Player")
	player.position.x = 12.5 * 32.0      # lontano dal bordo sinistro: la camera segue il giocatore al centro
	player.get_node("Camera2D").reset_smoothing()
	player.set_physics_process(false)

	stick = Sprite2D.new()
	stick.texture = STICK_TEX
	stick.scale = Vector2(2, 2)
	stick.position = player.position + Vector2(16, 6)
	world.add_child(stick)

	darkness = CanvasModulate.new()
	darkness.color = AMBIENT_DARK
	add_child(darkness)

	light = PointLight2D.new()
	light.texture = _radial_texture(256, [1.0, 0.35, 0.0])
	light.color = LIGHT_COLOR
	light.position = LIGHT_OFFSET
	player.add_child(light)

	var cover_layer := CanvasLayer.new()
	cover_layer.layer = 100
	add_child(cover_layer)
	cover = ColorRect.new()
	cover.color = Color.BLACK
	cover.size = Vector2(640, 480)
	cover_layer.add_child(cover)

	dialog = DialogBox.new()
	add_child(dialog)

	_run()


func _process(delta: float) -> void:
	_time += delta
	# la fiamma ondeggia leggermente
	var flicker := 1.0 + 0.06 * sin(_time * 9.0) + 0.04 * sin(_time * 23.0 + 1.3)
	light.energy = light_energy * flicker
	light.texture_scale = light_scale * (1.0 + 0.015 * sin(_time * 7.0))
	if _glow != null:
		_glow.modulate.a = _glow_level * flicker


func _unhandled_input(event: InputEvent) -> void:
	if roaming and event.is_action_pressed("cancel"):
		roaming = false
		get_tree().change_scene_to_file(MENU_SCENE)


func _run() -> void:
	# 1. cutscene (per ora solo nero)
	await _wait(CUTSCENE_TIME)
	# 2. si vede il giocatore con il barlume
	await _fade(cover, 0.0, FADE_IN_TIME)
	await _wait(DIALOGUE_DELAY)
	# 3. dialoghi
	await _line("Ai tuoi piedi noti un bastone ricoperto di neve e terra...")
	stick.hide()
	await _line("Afferri il bastone")
	var answer: int = await dialog.ask("Accendere la fiaccola?", ["Sì", "No"])
	dialog.close()
	if answer == 0:
		await _light_torch()
	else:
		await _give_up()


func _line(text: String) -> void:
	await dialog.say(text)
	dialog.close()
	await _wait(LINE_GAP)


func _give_up() -> void:
	await _wait(LINE_GAP)
	stick.show()
	await _line("Hai rimesso il bastone a terra")
	await _line("E fosti pian piano ricoperto dalla neve")
	await _wait(0.6)
	# il buio si riprende tutto
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "light_energy", 0.0, DARKEN_TIME)
	tw.tween_property(darkness, "color", Color.BLACK, DARKEN_TIME)
	await tw.finished
	await _fade(cover, 1.0, 0.5)
	await _wait(0.8)
	get_tree().change_scene_to_file(MENU_SCENE)


func _light_torch() -> void:
	await _wait(LINE_GAP)
	_build_overlay()
	await _fade(_overlay, 1.0, NIGHT_FADE_TIME)

	# accensione, poi la fiamma si muove per 4 secondi (BURN_TIME)
	_torch.play("ignite")
	var ignite := create_tween()
	ignite.tween_property(self, "_glow_level", 0.3, 1.4)
	await _torch.animation_finished
	_torch.play("burn")
	await _wait(BURN_TIME)

	# il mondo si illumina un po' di piu'
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(_overlay, "modulate:a", 0.0, NIGHT_FADE_TIME + 0.4)
	tw.tween_property(darkness, "color", AMBIENT_LIT, LIGHT_UP_TIME)
	tw.tween_property(self, "light_energy", LIGHT_LIT.energy, LIGHT_UP_TIME)
	tw.tween_property(self, "light_scale", LIGHT_LIT.scale, LIGHT_UP_TIME)
	await tw.finished

	_overlay.get_parent().queue_free()
	_glow = null
	player.set_physics_process(true)
	roaming = true


## Sfondo notturno con la fiaccola al centro dello schermo.
func _build_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 30
	add_child(layer)
	_overlay = Control.new()
	_overlay.modulate.a = 0.0
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_overlay)

	var night := ColorRect.new()
	night.color = NIGHT_COLOR
	night.size = Vector2(640, 480)
	_overlay.add_child(night)

	_glow = Sprite2D.new()
	_glow.texture = _radial_texture(256, [1.0, 0.3, 0.0])
	_glow.position = FLAME_POS
	_glow.scale = Vector2(2.2, 2.2)
	_glow.self_modulate = Color(1.0, 0.62, 0.28)
	_glow.modulate.a = 0.0
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = additive
	_overlay.add_child(_glow)

	_torch = AnimatedSprite2D.new()
	_torch.sprite_frames = _torch_frames()
	_torch.position = TORCH_POS
	_torch.scale = Vector2(TORCH_SCALE, TORCH_SCALE)
	_overlay.add_child(_torch)


func _torch_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	_add_animation(frames, "ignite", IGNITE_SHEET, IGNITE_FRAMES, 12.0, false)
	_add_animation(frames, "burn", BURN_SHEET, BURN_FRAMES, 10.0, true)
	return frames


func _add_animation(frames: SpriteFrames, anim: String, sheet: Texture2D, count: int,
		fps: float, loop: bool) -> void:
	frames.add_animation(anim)
	frames.set_animation_speed(anim, fps)
	frames.set_animation_loop(anim, loop)
	for i in count:
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2((i % COLUMNS) * CELL, floori(i / float(COLUMNS)) * CELL, CELL, CELL)
		frames.add_frame(anim, atlas)


## Macchia di luce circolare: stops = luminosita' al centro, a meta' e al bordo.
func _radial_texture(size: int, stops: Array) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	gradient.colors = PackedColorArray([
		Color(stops[0], stops[0], stops[0], 1.0),
		Color(stops[1], stops[1], stops[1], 1.0),
		Color(stops[2], stops[2], stops[2], 1.0)])
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.width = size
	tex.height = size
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	return tex


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _fade(node: CanvasItem, alpha: float, seconds: float) -> void:
	var tw := create_tween()
	tw.tween_property(node, "modulate:a", alpha, seconds)
	await tw.finished
