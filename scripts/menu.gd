extends Node2D
## Menu principale: New Game, Load Game, Options.
## Comandi: frecce / W S = scegli, Invio / Spazio / Z = conferma, Esc / X = indietro.

const PixText := preload("res://scripts/pix_text.gd")

const INTRO_SCENE := "res://scenes/intro.tscn"
const SIZE := Vector2(640, 480)
const BG_COLOR := Color(0.02, 0.03, 0.07)
const TITLE_COLOR := Color(0.85, 0.93, 1.0)
const ACTIVE_COLOR := Color(0.95, 0.97, 1.0)
const IDLE_COLOR := Color(0.42, 0.5, 0.65)
const DISABLED_COLOR := Color(0.24, 0.28, 0.36)
const MESSAGE_COLOR := Color(1.0, 0.78, 0.45)
const ITEM_PX := 3
const ITEM_Y := 250
const ITEM_STEP := 46
const FLAKES := 70

enum Page { MAIN, OPTIONS }

var page := Page.MAIN
var cursor := 0
var busy := true      # fino a fine dissolvenza iniziale il menu non risponde

var _title: Control
var _hint: Control
var _message: Control
var _cursor_mark: Control
var _items: Array[Control] = []
var _cover: ColorRect
var _flakes := PackedVector2Array()
var _flake_speed := PackedFloat32Array()
var _message_timer := 0.0


func _ready() -> void:
	randomize()
	for i in FLAKES:
		_flakes.append(Vector2(randf() * SIZE.x, randf() * SIZE.y))
		_flake_speed.append(randf_range(10.0, 28.0))

	_title = _text("SNOWY ROAD", 7, 92, TITLE_COLOR)
	_title.shadow_color = Color(0.1, 0.18, 0.35)
	for i in 3:
		_items.append(_text("", ITEM_PX, ITEM_Y + i * ITEM_STEP, IDLE_COLOR))
	_cursor_mark = _text(">", ITEM_PX, 0, ACTIVE_COLOR)
	_cursor_mark.align = 0
	_cursor_mark.size = Vector2(40, 30)
	_hint = _text("", 2, 446, DISABLED_COLOR)
	_message = _text("", 2, 410, MESSAGE_COLOR)

	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	_cover = ColorRect.new()
	_cover.color = Color.BLACK
	_cover.size = SIZE
	_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_cover)

	_refresh()
	var tw := create_tween()
	tw.tween_property(_cover, "modulate:a", 0.0, 1.0)
	tw.tween_callback(func() -> void: busy = false)


func _text(t: String, px: int, y: int, color: Color) -> Control:
	var node: Control = PixText.new()
	node.text = t
	node.px = px
	node.color = color
	node.align = 1
	node.position = Vector2(0, y)
	node.size = Vector2(SIZE.x, 8 * px)
	add_child(node)
	return node


func _process(delta: float) -> void:
	for i in _flakes.size():
		var f := _flakes[i]
		f.y += _flake_speed[i] * delta
		f.x += sin(f.y * 0.04 + i) * 6.0 * delta
		if f.y > SIZE.y:
			f = Vector2(randf() * SIZE.x, -2.0)
		_flakes[i] = f
	queue_redraw()
	if _message_timer > 0.0:
		_message_timer -= delta
		if _message_timer <= 0.0:
			_message.text = ""


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, SIZE), BG_COLOR)
	for i in _flakes.size():
		var size := 2.0 if _flake_speed[i] > 19.0 else 1.0
		var alpha := 0.55 if size > 1.0 else 0.3
		draw_rect(Rect2(_flakes[i].floor(), Vector2(size, size)), Color(0.85, 0.93, 1.0, alpha))


## Voci della pagina corrente: {text, enabled}
func _entries() -> Array:
	if page == Page.OPTIONS:
		return [
			{"text": "Fullscreen: " + ("On" if GameSettings.fullscreen else "Off"), "enabled": true},
			{"text": "Pixel perfect: " + ("On" if GameSettings.pixel_perfect else "Off"), "enabled": true},
			{"text": "Back", "enabled": true},
		]
	return [
		{"text": "New Game", "enabled": true},
		{"text": "Load Game", "enabled": GameSettings.has_save()},
		{"text": "Options", "enabled": true},
	]


func _refresh() -> void:
	var entries := _entries()
	for i in _items.size():
		var item := _items[i]
		var entry: Dictionary = entries[i]
		item.text = entry.text
		if not entry.enabled:
			item.color = DISABLED_COLOR
		else:
			item.color = ACTIVE_COLOR if i == cursor else IDLE_COLOR
	var active := _items[cursor]
	_cursor_mark.position = Vector2(
		(SIZE.x - active.text_width()) * 0.5 - 40, ITEM_Y + cursor * ITEM_STEP)
	_cursor_mark.align = 0
	if page == Page.OPTIONS:
		_hint.text = ["F11 or Alt+Enter toggles fullscreen", "Whole-number scaling: sharper, wider black bars", ""][cursor]
	else:
		_hint.text = "F11 - fullscreen"


func _unhandled_input(event: InputEvent) -> void:
	if busy:
		return
	_message.text = ""
	if event.is_action_pressed("menu_up"):
		cursor = posmod(cursor - 1, 3)
	elif event.is_action_pressed("menu_down"):
		cursor = posmod(cursor + 1, 3)
	elif page == Page.OPTIONS and (event.is_action_pressed("menu_left") or event.is_action_pressed("menu_right")):
		_activate()
	elif event.is_action_pressed("confirm") and not event.is_echo():
		_activate()
	elif event.is_action_pressed("cancel") and page == Page.OPTIONS:
		page = Page.MAIN
		cursor = 2
	else:
		return
	get_viewport().set_input_as_handled()
	_refresh()


func _activate() -> void:
	if page == Page.OPTIONS:
		match cursor:
			0: GameSettings.toggle_fullscreen()
			1: GameSettings.set_pixel_perfect(not GameSettings.pixel_perfect)
			2:
				page = Page.MAIN
				cursor = 2
		return
	match cursor:
		0: _new_game()
		1:
			if not GameSettings.has_save():
				_message.text = "No save data found"
				_message_timer = 2.0
		2:
			page = Page.OPTIONS
			cursor = 0


func _new_game() -> void:
	busy = true
	var tw := create_tween()
	tw.tween_property(_cover, "modulate:a", 1.0, 0.8)
	tw.tween_callback(func() -> void: get_tree().change_scene_to_file(INTRO_SCENE))
