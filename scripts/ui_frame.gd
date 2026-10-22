extends RefCounted
## Costruisce le cornici dei dialoghi a qualsiasi dimensione partendo da assets/ui/Dialog Box.png (400x64).
## Gli angoli e l'ornamento centrale restano a grandezza originale (pixel nitidi, niente stiramenti):
## le parti lisce del bordo vengono ripetute per allungare la cornice.

const SRC := preload("res://assets/ui/Dialog Box.png")
const SRC_W := 400
const SRC_H := 64

const CAP_PLAIN := 30     # colonne dell'angolo (senza ornamento centrale)
const CAP_ORNAMENT := 190 # colonne a sinistra/destra dell'ornamento centrale
const ORNAMENT_HALF := 10 # l'ornamento centrale e' largo 20 colonne
const TILE_X := 60        # colonne lisce del bordo (da ripetere in orizzontale)
const TILE_W := 90
const TOP_CAP := 18       # righe dell'angolo in alto
const BOTTOM_CAP := 23    # righe dell'angolo in basso
const TILE_Y := 18        # righe lisce (da ripetere in verticale)
const TILE_H := 23

static var _cache: Dictionary = {}


## size: dimensione finale (almeno 64 di larghezza e 41 di altezza).
## ornaments: con l'ornamento centrale in alto e in basso (solo per cornici larghe almeno 400).
static func make(size: Vector2i, ornaments := false) -> ImageTexture:
	var key := "%dx%d_%s" % [size.x, size.y, ornaments]
	if _cache.has(key):
		return _cache[key]

	var src := SRC.get_image()
	if src.is_compressed():
		src.decompress()
	var cap := CAP_ORNAMENT if ornaments else CAP_PLAIN
	var mid := size.x / 2

	var xs := PackedInt32Array()
	xs.resize(size.x)
	for x in size.x:
		if x < cap:
			xs[x] = x
		elif x >= size.x - cap:
			xs[x] = SRC_W - (size.x - x)
		elif ornaments and x >= mid - ORNAMENT_HALF and x < mid + ORNAMENT_HALF:
			xs[x] = SRC_W / 2 + (x - mid)
		else:
			xs[x] = TILE_X + posmod(x - cap, TILE_W)

	var out := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	for y in size.y:
		var sy: int
		if y < TOP_CAP:
			sy = y
		elif y >= size.y - BOTTOM_CAP:
			sy = SRC_H - (size.y - y)
		else:
			sy = TILE_Y + posmod(y - TOP_CAP, TILE_H)
		for x in size.x:
			out.set_pixel(x, y, src.get_pixel(xs[x], sy))

	var tex := ImageTexture.create_from_image(out)
	_cache[key] = tex
	return tex
