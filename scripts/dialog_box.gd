extends CanvasLayer
## Finestra di dialogo (grafica: assets/ui/Dialog Box.png) con testo a macchina da scrivere.
## Si usa con await:
##   await dialog.say("Testo...")                       # aspetta che il giocatore confermi
##   var scelta: int = await dialog.ask("Domanda?", ["Si'", "No"])   # box delle scelte in basso a destra
##   dialog.close()
## Conferma: Invio / Spazio / Z.  Scelte: frecce o W/S.

const PixText := preload("res://scripts/pix_text.gd")
const UiFrame := preload("res://scripts/ui_frame.gd")

signal _line_finished
signal _choice_made(index: int)

const BOX_POS := Vector2(16, 370)
const BOX_SIZE := Vector2i(608, 96)
const CHOICE_SIZE := Vector2i(120, 76)
const TEXT_PX := 2
const CHARS_PER_SEC := 38.0
const TEXT_COLOR := Color(0.93, 0.96, 1.0)
const DIM_COLOR := Color(0.5, 0.57, 0.7)

enum State { IDLE, TYPING, WAITING, CHOOSING }

var state := State.IDLE

var _box: TextureRect
var _text: Control
var _arrow: Control
var _choice_box: TextureRect
var _choice_cursor: Control
var _choice_labels: Array[Control] = []
var _choices: Array = []
var _cursor := 0
var _shown := 0.0
var _blink := 0.0


func _ready() -> void:
	layer = 40

	_box = TextureRect.new()
	_box.texture = UiFrame.make(BOX_SIZE, true)
	_box.position = BOX_POS
	_box.visible = false
	add_child(_box)

	_text = PixText.new()
	_text.px = TEXT_PX
	_text.wrap = true
	_text.color = TEXT_COLOR
	_text.position = Vector2(28, 24)
	_text.size = Vector2(BOX_SIZE.x - 56, BOX_SIZE.y - 40)
	_box.add_child(_text)

	_arrow = Control.new()
	_arrow.position = Vector2(BOX_SIZE.x - 40, BOX_SIZE.y - 26)
	_arrow.draw.connect(_draw_arrow)
	_arrow.visible = false
	_box.add_child(_arrow)

	_choice_box = TextureRect.new()
	_choice_box.texture = UiFrame.make(CHOICE_SIZE, false)
	_choice_box.position = Vector2(BOX_POS.x + BOX_SIZE.x - CHOICE_SIZE.x, BOX_POS.y - CHOICE_SIZE.y + 4)
	_choice_box.visible = false
	add_child(_choice_box)

	_choice_cursor = PixText.new()
	_choice_cursor.px = TEXT_PX
	_choice_cursor.text = ">"
	_choice_cursor.color = TEXT_COLOR
	_choice_box.add_child(_choice_cursor)


func say(line: String) -> void:
	_choices = []
	_open(line)
	await _line_finished


func ask(line: String, options: Array) -> int:
	_choices = options
	_cursor = 0
	_open(line)
	return await _choice_made


func close() -> void:
	state = State.IDLE
	_box.visible = false
	_choice_box.visible = false


func _open(line: String) -> void:
	_text.text = line
	_text.visible_chars = 0
	_shown = 0.0
	_arrow.visible = false
	_choice_box.visible = false
	_box.visible = true
	state = State.TYPING


func _process(delta: float) -> void:
	match state:
		State.TYPING:
			_shown += delta * CHARS_PER_SEC
			_text.visible_chars = int(_shown)
			if _shown >= _text.total_chars():
				_finish_typing()
		State.WAITING:
			_blink += delta
			_arrow.visible = fmod(_blink, 0.8) < 0.5


func _finish_typing() -> void:
	_text.visible_chars = -1
	_blink = 0.0
	if _choices.is_empty():
		state = State.WAITING
	else:
		_show_choices()
		state = State.CHOOSING


func _show_choices() -> void:
	for lbl in _choice_labels:
		lbl.queue_free()
	_choice_labels.clear()
	for i in _choices.size():
		var lbl: Control = PixText.new()
		lbl.px = TEXT_PX
		lbl.text = str(_choices[i])
		lbl.position = Vector2(46, 22 + i * 28)
		_choice_box.add_child(lbl)
		_choice_labels.append(lbl)
	_update_choice_cursor()
	_choice_box.visible = true


func _update_choice_cursor() -> void:
	_choice_cursor.position = Vector2(26, 22 + _cursor * 28)
	for i in _choice_labels.size():
		_choice_labels[i].color = TEXT_COLOR if i == _cursor else DIM_COLOR


func _unhandled_input(event: InputEvent) -> void:
	if state == State.IDLE:
		return
	var confirm := event.is_action_pressed("confirm") and not event.is_echo()
	match state:
		State.TYPING:
			if confirm:
				_shown = _text.total_chars()
				_finish_typing()
				get_viewport().set_input_as_handled()
		State.WAITING:
			if confirm:
				state = State.IDLE
				_arrow.visible = false
				get_viewport().set_input_as_handled()
				_line_finished.emit()
		State.CHOOSING:
			var step := 0
			if event.is_action_pressed("menu_up"):
				step = -1
			elif event.is_action_pressed("menu_down"):
				step = 1
			if step != 0:
				_cursor = posmod(_cursor + step, _choices.size())
				_update_choice_cursor()
				get_viewport().set_input_as_handled()
			elif confirm:
				state = State.IDLE
				_choice_box.visible = false
				get_viewport().set_input_as_handled()
				_choice_made.emit(_cursor)


func _draw_arrow() -> void:
	_arrow.draw_colored_polygon(
		PackedVector2Array([Vector2(0, 0), Vector2(12, 0), Vector2(6, 7)]), TEXT_COLOR)
