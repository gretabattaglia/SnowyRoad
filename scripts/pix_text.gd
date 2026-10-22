extends Control
## Testo con il font pixel 5x7 di pixfont.gd (solo maiuscolo: il testo viene convertito).
## - px: ingrandimento di ogni pixel del font (intero, cosi' i pixel restano quadrati)
## - wrap: va a capo da solo in base alla larghezza (size.x) del controllo
## - visible_chars: effetto macchina da scrivere (-1 = tutto il testo)

const PixFont := preload("res://scripts/pixfont.gd")

const GLYPH_W := 5
const GLYPH_H := 7

static var _glyphs: Dictionary = {}

@export var text := "":
	set(v):
		text = v
		_relayout()
@export var color := Color.WHITE:
	set(v):
		color = v
		queue_redraw()
@export var shadow_color := Color(0, 0, 0, 0)
@export var px := 2:
	set(v):
		px = v
		_relayout()
@export var letter_gap := 1       # spazio tra le lettere, in pixel del font
@export var line_gap := 4         # spazio tra le righe, in pixel dello schermo
@export var wrap := false
@export_enum("Left", "Center") var align := 0:
	set(v):
		align = v
		queue_redraw()

var visible_chars := -1:
	set(v):
		visible_chars = v
		queue_redraw()

var _lines := PackedStringArray()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_relayout)
	_relayout()


func advance() -> int:
	return (GLYPH_W + letter_gap) * px


## Numero di caratteri da mostrare per scrivere tutto il testo.
func total_chars() -> int:
	var n := 0
	for line in _lines:
		n += line.length()
	return n


## Larghezza in pixel di una riga di testo (senza a capo).
func text_width() -> int:
	var longest := 0
	for line in _lines:
		longest = maxi(longest, line.length())
	return maxi(longest * advance() - letter_gap * px, 0)


func _relayout() -> void:
	_lines = PackedStringArray()
	var max_chars := 100000
	if wrap and size.x > 0.0:
		max_chars = maxi(int(size.x) / advance(), 1)
	for para in text.to_upper().split("\n"):
		var cur := ""
		for word in para.split(" "):
			var candidate := word if cur == "" else cur + " " + word
			if cur == "" or candidate.length() <= max_chars:
				cur = candidate
			else:
				_lines.append(cur)
				cur = word
		_lines.append(cur)
	queue_redraw()


func _draw() -> void:
	var shown := 0
	var y := 0
	var adv := advance()
	for line in _lines:
		var x := 0
		if align == 1:
			x = int((size.x - (line.length() * adv - letter_gap * px)) * 0.5)
		for ch in line:
			if visible_chars >= 0 and shown >= visible_chars:
				return
			shown += 1
			var tex := _glyph(ch)
			if tex != null:
				var rect := Rect2(x, y, GLYPH_W * px, GLYPH_H * px)
				if shadow_color.a > 0.0:
					draw_texture_rect(tex, Rect2(rect.position + Vector2(px, px), rect.size), false, shadow_color)
				draw_texture_rect(tex, rect, false, color)
			x += adv
		y += GLYPH_H * px + line_gap


static func _glyph(ch: String) -> Texture2D:
	if _glyphs.has(ch):
		return _glyphs[ch]
	var tex: ImageTexture = null
	if PixFont.GLYPHS.has(ch) and ch != " ":
		var rows: Array = PixFont.GLYPHS[ch]
		var img := Image.create(GLYPH_W, GLYPH_H, false, Image.FORMAT_RGBA8)
		for gy in GLYPH_H:
			for gx in GLYPH_W:
				if (rows[gy] as String)[gx] == "#":
					img.set_pixel(gx, gy, Color.WHITE)
		tex = ImageTexture.create_from_image(img)
	_glyphs[ch] = tex
	return tex
