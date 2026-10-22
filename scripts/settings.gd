extends Node
## Impostazioni globali (autoload "GameSettings"): schermo intero, scala dei pixel e tasti dei menu.
##
## Il gioco ha una risoluzione interna 4:3 di 640x480 (come Omori). Su uno schermo 16:9 l'immagine
## viene scalata fino a riempire l'altezza e ai lati restano due bande nere.
## - F11 oppure Alt+Invio: schermo intero / finestra
## - Pixel perfect (opzioni): scala solo a multipli interi, pixel nitidissimi ma bande nere piu' grandi
## Le scelte vengono salvate in user://settings.cfg.

const SAVE_PATH := "user://settings.cfg"
const BASE_SIZE := Vector2i(640, 480)
const MAX_WINDOW_HEIGHT := 720
const SCREEN_MARGIN := 80   # spazio lasciato a barra del titolo e della barra delle applicazioni

var fullscreen := false
var pixel_perfect := false

var _windowed_size := Vector2i(960, 720)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	RenderingServer.set_default_clear_color(Color.BLACK)   # le bande ai lati sono nere
	_setup_input()
	_load()

	var win := get_window()
	win.min_size = BASE_SIZE / 2
	win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	_windowed_size = _default_window_size()
	if not fullscreen and win.mode == Window.MODE_WINDOWED and win.size != _windowed_size:
		win.size = _windowed_size
		win.move_to_center()
	_apply()


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key := event as InputEventKey
	var alt_enter := key.alt_pressed and (key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER)
	if key.keycode == KEY_F11 or alt_enter:
		toggle_fullscreen()
		get_viewport().set_input_as_handled()


func toggle_fullscreen() -> void:
	set_fullscreen(not fullscreen)


func set_fullscreen(value: bool) -> void:
	if value == fullscreen:
		return
	var win := get_window()
	if value and win.mode == Window.MODE_WINDOWED:
		_windowed_size = win.size   # ricordo la dimensione scelta dal giocatore
	fullscreen = value
	_apply()
	_save()


func set_pixel_perfect(value: bool) -> void:
	pixel_perfect = value
	_apply()
	_save()


func has_save() -> bool:
	return FileAccess.file_exists("user://save.json")


func _apply() -> void:
	var win := get_window()
	win.content_scale_stretch = Window.CONTENT_SCALE_STRETCH_INTEGER if pixel_perfect \
			else Window.CONTENT_SCALE_STRETCH_FRACTIONAL
	if fullscreen:
		win.mode = Window.MODE_FULLSCREEN
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	else:
		var was_fullscreen := win.mode != Window.MODE_WINDOWED
		win.mode = Window.MODE_WINDOWED
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		if was_fullscreen:
			_restore_window.call_deferred()


## Uscendo dallo schermo intero la finestra torna alla dimensione di prima, centrata.
func _restore_window() -> void:
	await get_tree().process_frame
	var win := get_window()
	win.size = _windowed_size
	win.move_to_center()


func _default_window_size() -> Vector2i:
	var usable := DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
	var h := mini(MAX_WINDOW_HEIGHT, usable.size.y - SCREEN_MARGIN)
	h = maxi(h - h % 3, BASE_SIZE.y / 2)
	return Vector2i(h * 4 / 3, h)


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	fullscreen = cfg.get_value("display", "fullscreen", false)
	pixel_perfect = cfg.get_value("display", "pixel_perfect", false)


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("display", "fullscreen", fullscreen)
	cfg.set_value("display", "pixel_perfect", pixel_perfect)
	cfg.save(SAVE_PATH)


## Azioni dei menu e dei dialoghi (il movimento del personaggio le definisce da se' in player.gd).
func _setup_input() -> void:
	var map := {
		"menu_up": [KEY_UP, KEY_W],
		"menu_down": [KEY_DOWN, KEY_S],
		"menu_left": [KEY_LEFT, KEY_A],
		"menu_right": [KEY_RIGHT, KEY_D],
		"confirm": [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_Z],
		"cancel": [KEY_ESCAPE, KEY_X],
	}
	for action: String in map:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key: Key in map[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)
