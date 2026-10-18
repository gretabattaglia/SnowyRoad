extends Node2D
## Combattimento di SnowyRoad (prova grafica, NON definitiva).
## Nemico grande in alto, bullet hell nel resto dello schermo (senza riquadro),
## luci e ombre sui nemici. Il personaggio con la torcia non c'e' ancora: la fiamma e' sola.
##
## Come provarlo: apri scenes/battle.tscn in Godot e premi F6.
## Comandi: frecce / WASD = menu e movimento della fiamma, Invio / Z = conferma,
##          Esc / X = indietro, 1 / 2 = cambia nemico (boss / cespuglio), R = ricomincia.

const PixFont := preload("res://scripts/pixfont.gd")

enum Phase { MENU, DODGE, RESOLVE, WIN, LOSE }

# ------------------------------------------------------------------ parametri (cambiali qui)
const FLAME_MAX := 100.0
const TURN_TIME := 8.0          # durata del turno del nemico (secondi)
const FLAME_SPEED := 120.0
const HIT_DAMAGE := 8.0         # danno alla fiamma per ogni proiettile
const HIT_COOLDOWN := 0.8       # invulnerabilita' dopo un colpo
const GRACE := 0.8              # secondi senza proiettili a inizio turno
const CHARGE_RATE := 0.07       # carica al secondo quando sei vicinissimo al nemico
const ITEM_HEAL := 30.0
const DENSITY_FAR := 0.55       # fittezza dei proiettili: lontano dal nemico...
const DENSITY_NEAR := 1.7       # ...e attaccati al nemico
const MAX_DIST := 250.0         # distanza (px) oltre la quale la vicinanza e' zero
const FIELD := Rect2(14, 38, 612, 310)      # dove puo' muoversi la fiamma (quasi tutto lo schermo)
const REST_FLAME := Vector2(322, 304)       # dove sta la fiamma durante il menu

# Nemici. "eyes" = [x, y, area] in pixel della texture, dal piu' grande al piu' piccolo.
var enemies: Dictionary = {
	"boss": {
		"name": "L'OMBRA DEGLI OCCHI", "tex": "res://assets/bosses/boss_ombra.png",
		"hp": 500.0, "height": 168.0, "base": Vector2(320, 176), "shadow": Vector2(110, 14),
		"eyes": [[442.4, 250.7, 13228], [383.6, 504.7, 5995], [539.0, 673.4, 4324], [504.6, 832.8, 2875],
				[359.1, 674.3, 2280], [503.3, 114.5, 1800], [347.3, 389.8, 1789], [432.7, 1082.2, 1635],
				[347.7, 172.5, 1369]],
		"glow": Color(0.55, 0.80, 1.0), "bullet": Color(0.47, 0.77, 1.0),
	},
	"bush": {
		"name": "CESPUGLIO CON GLI OCCHI", "tex": "res://assets/enemies/bush.png",
		"hp": 220.0, "height": 123.0, "base": Vector2(320, 182), "shadow": Vector2(120, 12),
		"eyes": [[252.2, 242.9, 2294], [427.6, 243.4, 2246]],
		"glow": Color(1.0, 0.55, 0.2), "bullet": Color(1.0, 0.62, 0.25),
	},
}
var enemy_id := "boss"

# zona: "vicino" | "lontano" | "media" | "fissa" ; min = efficacia minima (0..1)
var moves: Array[Dictionary] = [
	{"name": "FIAMMA ROSSA", "kind": "attacco", "base": 100.0, "zone": "vicino", "min": 0.2, "color": Color("ff4a2e")},
	{"name": "FIAMMA BLU", "kind": "cura", "base": 50.0, "zone": "lontano", "min": 0.3, "color": Color("3d8bff")},
]
var legendary: Dictionary = {"name": "FIAMMA LEGGENDARIA", "kind": "attacco", "base": 250.0,
		"zone": "fissa", "min": 1.0, "color": Color("fff2a8"), "legendary": true}

const FLAME_COLS := [Color("b02814"), Color("ff4a1c"), Color("ff8a1f"), Color("ffc233"), Color("fff2a8")]
const INK := Color("18171f")
const ICE := Color("cfe3f2")
const GREY := Color("8c9cb0")
const WHITE := Color("e6f0f7")
const BAYER := [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]

# ------------------------------------------------------------------ stato
var phase: Phase = Phase.MENU
var t := 0.0
var enemy_hp := 500.0
var enemy_max := 500.0
var flame_hp := FLAME_MAX
var charge := 0.0
var brace := 2
var turn_index := 0

var menu_level := 0
var cursor := 0
var cur_move: Dictionary = {}

var turn_t := 0.0
var prox_acc := 0.0
var flame_pos := REST_FLAME
var hit_cd := 0.0
var spawn_a := 0.0
var spawn_b := 0.0
var b_pos := PackedVector2Array()
var b_vel := PackedVector2Array()
var b_big := PackedByteArray()
var spin := 0.0

var resolve_t := 0.0
var flash := 0.0
var shake := 0.0
var texts: Array[Dictionary] = []
var toast := ""
var toast_t := 0.0
var snow: PackedVector2Array = PackedVector2Array()

# nodi / risorse
var world: Node2D
var bg: Sprite2D
var shadow: Sprite2D
var enemy: Sprite2D
var glow_node: Node2D
var fog: Sprite2D
var fx: Node2D
var vignette: Sprite2D
var ui: Node2D
var mat: ShaderMaterial
var glyphs: Dictionary = {}
var tex_halo_flame: ImageTexture
var tex_halo_bullet: ImageTexture
var tex_glow: GradientTexture2D
var tex_shadow: GradientTexture2D
var tex_bullet_small: ImageTexture
var tex_bullet_big: ImageTexture

var emit_pos: Array[Vector2] = []    # occhi del nemico = da qui partono i proiettili
var emit_area: Array[float] = []
var anchor := Vector2(320, 40)
var bob := Vector2.ZERO
var en_scale := 0.1


func _ready() -> void:
	_setup_input()
	_build_nodes()
	_build_glyphs()
	_build_textures()
	for i in 70:
		snow.append(Vector2(randf() * 640.0, randf() * 360.0))
	_set_enemy("boss")


# ------------------------------------------------------------------ costruzione della scena
func _build_nodes() -> void:
	world = Node2D.new()
	add_child(world)

	bg = Sprite2D.new()
	bg.texture = load("res://assets/battle/bg_battle.png")
	bg.centered = false
	world.add_child(bg)

	shadow = Sprite2D.new()
	world.add_child(shadow)

	enemy = Sprite2D.new()
	enemy.centered = false
	enemy.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS   # illustrazione: liscia, non pixelata
	mat = ShaderMaterial.new()
	mat.shader = load("res://shaders/enemy_lit.gdshader")
	enemy.material = mat
	world.add_child(enemy)

	glow_node = Node2D.new()
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow_node.material = add
	world.add_child(glow_node)
	glow_node.draw.connect(_draw_glow)

	fog = Sprite2D.new()
	fog.texture = load("res://assets/battle/fog_battle.png")
	fog.centered = false
	world.add_child(fog)

	fx = Node2D.new()
	world.add_child(fx)
	fx.draw.connect(_draw_fx)

	vignette = Sprite2D.new()
	vignette.texture = load("res://assets/battle/vignette_battle.png")
	vignette.centered = false
	add_child(vignette)

	ui = Node2D.new()
	add_child(ui)
	ui.draw.connect(_draw_ui)


func _build_glyphs() -> void:
	for ch: String in PixFont.GLYPHS:
		var rows: Array = PixFont.GLYPHS[ch]
		var img := Image.create(5, 7, false, Image.FORMAT_RGBA8)
		for y in 7:
			for x in 5:
				if (rows[y] as String)[x] == "#":
					img.set_pixel(x, y, Color.WHITE)
		glyphs[ch] = ImageTexture.create_from_image(img)


func _build_textures() -> void:
	tex_halo_flame = _make_halo(78, Color(1.0, 0.58, 0.22), 6, 0.55)
	tex_halo_bullet = _make_halo(8, Color(0.5, 0.8, 1.0), 3, 0.3)
	tex_bullet_small = _make_bullet(5, Color("78c4ff"))
	tex_bullet_big = _make_bullet(7, Color("78c4ff"))

	var gr := Gradient.new()
	gr.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	gr.offsets = PackedFloat32Array([0.0, 1.0])
	tex_glow = GradientTexture2D.new()
	tex_glow.gradient = gr
	tex_glow.width = 64
	tex_glow.height = 64
	tex_glow.fill = GradientTexture2D.FILL_RADIAL
	tex_glow.fill_from = Vector2(0.5, 0.5)
	tex_glow.fill_to = Vector2(1.0, 0.5)

	var gs := Gradient.new()
	gs.colors = PackedColorArray([Color(0, 0, 0, 0.62), Color(0, 0, 0, 0.0)])
	gs.offsets = PackedFloat32Array([0.0, 1.0])
	tex_shadow = GradientTexture2D.new()
	tex_shadow.gradient = gs
	tex_shadow.width = 128
	tex_shadow.height = 128
	tex_shadow.fill = GradientTexture2D.FILL_RADIAL
	tex_shadow.fill_from = Vector2(0.5, 0.5)
	tex_shadow.fill_to = Vector2(1.0, 0.5)
	shadow.texture = tex_shadow


## Alone a gradini con dither di Bayer (stile pixel art). Bianco/colore + alpha.
func _make_halo(radius: int, col: Color, levels: int, max_alpha: float) -> ImageTexture:
	var size := radius * 2 + 1
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var d := Vector2(x - radius, y - radius).length() / float(radius)
			if d >= 1.0:
				continue
			var k := pow(1.0 - d, 2.0)
			var q := k * levels
			var lv := int(q) + (1 if (q - int(q)) > float(BAYER[(y % 4) * 4 + (x % 4)]) / 16.0 else 0)
			if lv > 0:
				img.set_pixel(x, y, Color(col.r, col.g, col.b, max_alpha * float(lv) / float(levels)))
	return ImageTexture.create_from_image(img)


func _make_bullet(size: int, mid: Color) -> ImageTexture:
	var pat: Array = []
	if size == 5:
		pat = ["..#..", ".#o#.", "#oWo#", ".#o#.", "..#.."]
	else:
		pat = ["...#...", "..#o#..", ".#oWo#.", "#oWWWo#", ".#oWo#.", "..#o#..", "...#..."]
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			match (pat[y] as String)[x]:
				"#":
					img.set_pixel(x, y, INK)
				"o":
					img.set_pixel(x, y, mid)
				"W":
					img.set_pixel(x, y, Color("f0faff"))
	return ImageTexture.create_from_image(img)


# ------------------------------------------------------------------ nemico
func _set_enemy(id: String) -> void:
	enemy_id = id
	var e: Dictionary = enemies[id]
	var tex: Texture2D = load(e["tex"])
	enemy.texture = tex
	en_scale = float(e["height"]) / float(tex.get_height())
	enemy.scale = Vector2(en_scale, en_scale)
	enemy_max = e["hp"]
	shadow.scale = Vector2(e["shadow"].x / 128.0 * 2.0, e["shadow"].y / 128.0 * 2.0)
	var col: Color = e["bullet"]
	tex_bullet_small = _make_bullet(5, col)
	tex_bullet_big = _make_bullet(7, col)
	tex_halo_bullet = _make_halo(8, e["glow"], 3, 0.3)
	_reset()


func _reset() -> void:
	phase = Phase.MENU
	enemy_hp = enemy_max
	flame_hp = FLAME_MAX
	charge = 0.0
	brace = 2
	turn_index = 0
	menu_level = 0
	cursor = 0
	texts.clear()
	flame_pos = REST_FLAME
	hit_cd = 0.0
	turn_t = 0.0
	_clear_bullets()
	_update_enemy_pose(0.0)


func _clear_bullets() -> void:
	b_pos = PackedVector2Array()
	b_vel = PackedVector2Array()
	b_big = PackedByteArray()


## Posizione, ondeggiamento, occhi e uniform dello shader.
func _update_enemy_pose(_delta: float) -> void:
	var e: Dictionary = enemies[enemy_id]
	bob = Vector2(sin(t * 0.7) * 1.2, sin(t * 1.1) * 2.0) if enemy_id == "boss" else Vector2(0.0, sin(t * 1.6) * 0.8)
	var tex: Texture2D = enemy.texture
	var size := Vector2(tex.get_width(), tex.get_height()) * en_scale
	var base: Vector2 = e["base"]
	enemy.position = base - Vector2(size.x * 0.5, size.y) + bob

	emit_pos.clear()
	emit_area.clear()
	for eye: Array in e["eyes"]:
		emit_pos.append(enemy.position + Vector2(eye[0], eye[1]) * en_scale)
		emit_area.append(float(eye[2]))
	anchor = emit_pos[0] if enemy_id == "boss" else (emit_pos[0] + emit_pos[1]) * 0.5

	# luce della fiamma (in pixel della texture)
	mat.set_shader_parameter("light_px", (flame_pos - enemy.position) / en_scale)
	mat.set_shader_parameter("light_radius", 340.0 / en_scale)
	var flick := 1.0 + 0.12 * sin(t * 17.0) + 0.07 * sin(t * 29.0)
	mat.set_shader_parameter("light_energy", flick * (1.15 if phase == Phase.DODGE else 0.8))
	mat.set_shader_parameter("band", 18.0 if enemy_id == "boss" else 14.0)
	mat.set_shader_parameter("eye_col", Vector3(e["glow"].r, e["glow"].g, e["glow"].b))
	mat.set_shader_parameter("eye_glow", 0.35 + (0.65 if phase == Phase.DODGE and turn_t > GRACE else 0.0))
	mat.set_shader_parameter("flash", flash)
	mat.set_shader_parameter("fade_bottom", 0.35 if enemy_id == "boss" else 0.0)

	# ombra a terra: si sposta e si allunga lontano dalla fiamma
	var away := base.x - flame_pos.x
	shadow.position = Vector2(base.x + clampf(away * 0.22, -40.0, 40.0), base.y + 8.0)
	var stretch := 1.0 + clampf(absf(away) / 260.0, 0.0, 0.5)
	shadow.scale = Vector2(e["shadow"].x / 128.0 * 2.0 * stretch, e["shadow"].y / 128.0 * 2.0)
	var lit := clampf(1.0 - flame_pos.distance_to(base) / 400.0, 0.0, 1.0)
	shadow.modulate.a = 0.75 + 0.25 * lit


# ------------------------------------------------------------------ input
func _setup_input() -> void:
	var map := {
		"b_left": [KEY_A, KEY_LEFT], "b_right": [KEY_D, KEY_RIGHT],
		"b_up": [KEY_W, KEY_UP], "b_down": [KEY_S, KEY_DOWN],
		"b_ok": [KEY_ENTER, KEY_KP_ENTER, KEY_Z, KEY_SPACE],
		"b_back": [KEY_ESCAPE, KEY_X, KEY_BACKSPACE],
		"b_restart": [KEY_R], "b_enemy1": [KEY_1], "b_enemy2": [KEY_2],
	}
	for action: String in map:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key: Key in map[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("b_restart"):
		_reset()
		return
	if event.is_action_pressed("b_enemy1"):
		_set_enemy("boss")
		return
	if event.is_action_pressed("b_enemy2"):
		_set_enemy("bush")
		return
	if phase == Phase.MENU:
		_menu_input(event)


func _menu_entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	match menu_level:
		0:
			out.append({"label": "MOSSE", "id": "moves"})
			out.append({"label": "OGGETTI", "id": "items"})
		1:
			if charge >= 1.0:
				out.append({"label": "* LEGGENDARIA", "color": legendary["color"], "move": legendary})
			for m in moves:
				out.append({"label": m["name"], "color": m["color"], "move": m})
		2:
			out.append({"label": "BRACE X%d" % brace, "id": "brace", "color": Color("ffa726")})
	return out


func _menu_input(event: InputEvent) -> void:
	var entries := _menu_entries()
	if event.is_action_pressed("b_up"):
		cursor = (cursor - 1 + entries.size()) % entries.size()
	elif event.is_action_pressed("b_down"):
		cursor = (cursor + 1) % entries.size()
	elif event.is_action_pressed("b_back"):
		if menu_level > 0:
			menu_level = 0
			cursor = 0
	elif event.is_action_pressed("b_ok"):
		var e := entries[cursor]
		if menu_level == 0:
			menu_level = 1 if e["id"] == "moves" else 2
			cursor = 0
		elif menu_level == 1:
			_start_turn(e["move"])
		elif menu_level == 2 and brace > 0:
			brace -= 1
			flame_hp = minf(FLAME_MAX, flame_hp + ITEM_HEAL)
			_float("+%d" % int(ITEM_HEAL), REST_FLAME + Vector2(26, -24), Color("7dff9a"))
			_start_turn({"name": "OGGETTO", "kind": "oggetto", "zone": "fissa", "base": 0.0,
					"min": 1.0, "color": Color("ffa726")})


# ------------------------------------------------------------------ logica del turno
func _start_turn(m: Dictionary) -> void:
	cur_move = m
	if m.get("legendary", false):
		charge = 0.0
	phase = Phase.DODGE
	turn_t = 0.0
	prox_acc = 0.0
	hit_cd = 0.0
	spawn_a = 0.0
	spawn_b = 0.5
	flame_pos = Vector2(320, 262)
	_clear_bullets()


## 1.0 = sopra l'occhio del nemico, 0.0 = lontano (MAX_DIST pixel o piu').
func proximity() -> float:
	return 1.0 - clampf(flame_pos.distance_to(anchor) / MAX_DIST, 0.0, 1.0)


func effect_mult(m: Dictionary, p: float) -> float:
	var lo: float = m.get("min", 0.2)
	match m["zone"]:
		"vicino":
			return lerpf(lo, 1.0, p)
		"lontano":
			return lerpf(lo, 1.0, 1.0 - p)
		"media":
			return lerpf(lo, 1.0, 1.0 - absf(p - 0.5) * 2.0)
	return 1.0


func _add_bullet(pos: Vector2, vel: Vector2, big: bool = false) -> void:
	b_pos.append(pos)
	b_vel.append(vel)
	b_big.append(1 if big else 0)


func _pick_emitters(n: int) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for i in n:
		out.append(emit_pos[randi() % emit_pos.size()])
	return out


func _spawn(delta: float) -> void:
	if turn_t < GRACE:
		return
	# piu' sei vicino al nemico, piu' i proiettili sono fitti
	var dens := lerpf(DENSITY_FAR, DENSITY_NEAR, proximity())
	spawn_a -= delta * dens
	spawn_b -= delta * dens
	spin += delta
	var big_eye := emit_pos[0]
	match turn_index % 3:
		0:  # ventagli da alcuni occhi a caso
			if spawn_a <= 0.0:
				spawn_a = 0.75
				var off := sin(turn_t * 1.7) * 9.0
				for o in _pick_emitters(3):
					for i in 9:
						_add_bullet(o, Vector2.from_angle(deg_to_rad(38.0 + i * 13.0 + off)) * 66.0)
		1:  # onda: getti che spazzano avanti e indietro
			if spawn_a <= 0.0:
				spawn_a = 0.09
				_add_bullet(big_eye, Vector2.from_angle(deg_to_rad(90.0 + 62.0 * sin(turn_t * 2.3))) * 92.0, true)
				var o2 := emit_pos[(1 + int(turn_t * 3.0)) % emit_pos.size()]
				_add_bullet(o2, Vector2.from_angle(deg_to_rad(90.0 - 55.0 * sin(turn_t * 2.0))) * 80.0)
		2:  # mirato + anello
			if spawn_a <= 0.0:
				spawn_a = 1.15
				for o in _pick_emitters(3):
					var base := (flame_pos - o).angle()
					for i in 3:
						_add_bullet(o, Vector2.from_angle(base + deg_to_rad((i - 1) * 9.0)) * 105.0)
			if spawn_b <= 0.0:
				spawn_b = 1.7
				for i in 14:
					_add_bullet(big_eye, Vector2.from_angle(TAU * i / 14.0 + spin) * 52.0, true)


func _update_dodge(delta: float) -> void:
	turn_t += delta
	hit_cd = maxf(0.0, hit_cd - delta)

	var dir := Input.get_vector("b_left", "b_right", "b_up", "b_down")
	flame_pos += dir * FLAME_SPEED * delta
	flame_pos = flame_pos.clamp(FIELD.position, FIELD.end)

	var p := proximity()
	prox_acc += p * delta
	charge = minf(1.0, charge + CHARGE_RATE * p * delta)

	_spawn(delta)

	var np := PackedVector2Array()
	var nv := PackedVector2Array()
	var nb := PackedByteArray()
	var lim := Rect2(-16, -16, 672, 392)
	for i in b_pos.size():
		var q := b_pos[i] + b_vel[i] * delta
		if not lim.has_point(q):
			continue
		if hit_cd <= 0.0 and q.distance_to(flame_pos) < 5.5:
			flame_hp -= HIT_DAMAGE
			hit_cd = HIT_COOLDOWN
			shake = 4.0
			_float("-%d" % int(HIT_DAMAGE), flame_pos + Vector2(0, -16), Color("ff6b6b"))
			continue
		np.append(q)
		nv.append(b_vel[i])
		nb.append(b_big[i])
	b_pos = np
	b_vel = nv
	b_big = nb

	if flame_hp <= 0.0:
		flame_hp = 0.0
		phase = Phase.LOSE
		return
	if turn_t >= TURN_TIME:
		_resolve()


func _resolve() -> void:
	var p_avg := prox_acc / TURN_TIME
	var mult := effect_mult(cur_move, p_avg)
	var amount: float = cur_move.get("base", 0.0) * mult
	match cur_move["kind"]:
		"attacco":
			enemy_hp = maxf(0.0, enemy_hp - amount)
			flash = 0.5
			shake = 5.0
			_float("-%d" % roundi(amount), anchor, (cur_move["color"] as Color).lightened(0.3))
		"cura":
			flame_hp = minf(FLAME_MAX, flame_hp + amount)
			_float("+%d" % roundi(amount), flame_pos + Vector2(0, -16), Color("7dff9a"))
	phase = Phase.RESOLVE
	resolve_t = 1.6
	_clear_bullets()


func _float(s: String, pos: Vector2, col: Color) -> void:
	texts.append({"s": s, "pos": pos, "col": col, "age": 0.0})


func _process(delta: float) -> void:
	t += delta
	flash = maxf(0.0, flash - delta * 1.6)
	toast_t = maxf(0.0, toast_t - delta)
	shake = maxf(0.0, shake - delta * 30.0)
	world.position = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake
	for tx in texts:
		tx["age"] += delta
	texts = texts.filter(func(x: Dictionary) -> bool: return x["age"] < 1.4)
	for i in snow.size():
		var s := snow[i]
		s.y += (14.0 + float(i % 5) * 4.0) * delta
		s.x += sin(t * 0.8 + float(i)) * 6.0 * delta
		if s.y > 362.0:
			s = Vector2(randf() * 640.0, -2.0)
		snow[i] = s

	match phase:
		Phase.MENU:
			# la fiamma riposa in basso, al centro, e ondeggia appena
			flame_pos = REST_FLAME + Vector2(0.0, sin(t * 2.0) * 1.2)
		Phase.DODGE:
			_update_dodge(delta)
		Phase.RESOLVE:
			resolve_t -= delta
			flame_pos = flame_pos.lerp(REST_FLAME, minf(1.0, delta * 3.0))
			if resolve_t <= 0.0:
				if enemy_hp <= 0.0:
					phase = Phase.WIN
				else:
					phase = Phase.MENU
					menu_level = 0
					cursor = 0
					turn_index += 1
	_update_enemy_pose(delta)
	glow_node.queue_redraw()
	fx.queue_redraw()
	ui.queue_redraw()


# ------------------------------------------------------------------ disegno: bagliori (additivi)
func _draw_glow() -> void:
	var e: Dictionary = enemies[enemy_id]
	var gcol: Color = e["glow"]
	var firing := phase == Phase.DODGE and turn_t > GRACE
	# occhi che brillano: gli attivi pulsano quando il nemico spara
	for i in emit_pos.size():
		var r := sqrt(emit_area[i] / PI) * en_scale
		var a := 0.22 + 0.06 * sin(t * 2.0 + float(i))
		var scl := 2.3
		if firing:
			a = 0.5 + 0.25 * sin(t * 9.0 + float(i) * 1.7)
			scl = 3.0
		var rr := r * scl + 3.0
		glow_node.draw_texture_rect(tex_glow, Rect2(emit_pos[i] - Vector2(rr, rr), Vector2(rr * 2.0, rr * 2.0)),
				false, Color(gcol.r, gcol.g, gcol.b, a))
	# alone della fiamma (a gradini, pixel art)
	var fp := Vector2(roundf(flame_pos.x), roundf(flame_pos.y))
	var flick := 0.85 + 0.15 * sin(t * 17.0)
	glow_node.draw_texture(tex_halo_flame, fp - Vector2(78, 78 + 8), Color(1, 1, 1, flick))
	# aloni dei proiettili
	for i in b_pos.size():
		var q := Vector2(roundf(b_pos[i].x), roundf(b_pos[i].y))
		glow_node.draw_texture(tex_halo_bullet, q - Vector2(8, 8), Color(1, 1, 1, 1))


# ------------------------------------------------------------------ disegno: proiettili, neve, fiamma
func _draw_fx() -> void:
	# neve
	for s in snow:
		fx.draw_rect(Rect2(floorf(s.x), floorf(s.y), 1, 1), Color(0.86, 0.92, 0.97, 0.85))
	# proiettili
	for i in b_pos.size():
		var tex := tex_bullet_big if b_big[i] == 1 else tex_bullet_small
		var q := Vector2(roundf(b_pos[i].x), roundf(b_pos[i].y)) - tex.get_size() * 0.5
		fx.draw_texture(tex, Vector2(floorf(q.x), floorf(q.y)))
	# fiamma del giocatore
	var small := phase == Phase.DODGE or phase == Phase.RESOLVE
	var invuln := phase == Phase.DODGE and hit_cd > 0.0 and int(t * 20.0) % 2 == 0
	if not (phase == Phase.LOSE) and not invuln:
		_draw_flame(fx, Vector2(roundf(flame_pos.x), roundf(flame_pos.y) + 8.0), 22.0 if small else 34.0, 13.0 if small else 20.0)


func _draw_flame(ci: CanvasItem, base: Vector2, h: float, w: float) -> void:
	var layers := [[1.0, 1.0], [0.92, 0.84], [0.78, 0.66], [0.58, 0.46], [0.34, 0.26]]
	for li in 5:
		var sw: float = layers[li][0]
		var sh: float = layers[li][1]
		var hh := h * sh
		var ww := w * sw
		for i in int(hh):
			var u := float(i) / hh
			var r := 0.3
			var width := 0.0
			if u < r:
				var k := (r - u) / r
				width = ww * sqrt(maxf(0.0, 1.0 - k * k))
			else:
				width = ww * pow(1.0 - (u - r) / (1.0 - r), 1.15)
			var sway := (sin(u * 3.2 + t * 7.0) * 2.0) * pow(u, 1.4)
			var x0 := roundf(base.x + sway - width * 0.5)
			ci.draw_rect(Rect2(x0, base.y - i, maxf(1.0, roundf(width)), 1), FLAME_COLS[li])
	# scintille
	for k in 4:
		var ph := fmod(t * 1.3 + float(k) * 0.37, 1.0)
		var sx := base.x + sin(float(k) * 2.1 + t) * w * 0.4
		ci.draw_rect(Rect2(roundf(sx), roundf(base.y - h - ph * 14.0), 1, 1), FLAME_COLS[3 if k % 2 == 0 else 2])


# ------------------------------------------------------------------ disegno: interfaccia
func _text(s: String, pos: Vector2, col: Color, scale: int = 1, shadow_col: Color = Color(0, 0, 0, 0)) -> float:
	var x := pos.x
	for ch in s.to_upper():
		var tex: Texture2D = glyphs.get(ch, glyphs["?"])
		var sz := Vector2(5 * scale, 7 * scale)
		if shadow_col.a > 0.0:
			ui.draw_texture_rect(tex, Rect2(Vector2(x + 1, pos.y + 1), sz), false, shadow_col)
		ui.draw_texture_rect(tex, Rect2(Vector2(x, pos.y), sz), false, col)
		x += 6 * scale
	return x


func _panel(r: Rect2) -> void:
	ui.draw_rect(r, Color(0.03, 0.045, 0.07, 0.92))
	ui.draw_rect(r, ICE, false)
	ui.draw_rect(r.grow(-2), Color("4a607e"), false)


func _segbar(pos: Vector2, n: int, filled: int, col: Color) -> void:
	for i in n:
		var c := col if i < filled else Color("1e2636")
		ui.draw_rect(Rect2(pos.x + i * 7, pos.y, 6, 7), c)
		if i < filled:
			ui.draw_rect(Rect2(pos.x + i * 7, pos.y, 6, 2), col.lightened(0.25))


func _describe(m: Dictionary) -> Array:
	var z := ""
	match m["zone"]:
		"vicino":
			z = "PIU FORTE DA VICINO"
		"lontano":
			z = "PIU FORTE DA LONTANO"
		"media":
			z = "PIU FORTE A META"
		_:
			z = "SEMPRE AL MASSIMO"
	var l1: String = "CURA %d" % int(m["base"])
	if m["kind"] == "attacco":
		l1 = "ATTACCO %d-%d" % [int(m["base"] * m["min"]), int(m["base"])]
	return [l1, z, "MA I PROIETTILI", "SONO PIU FITTI"]


func _draw_ui() -> void:
	var e: Dictionary = enemies[enemy_id]
	# --- testata
	_text(e["name"], Vector2(12, 10), WHITE, 1, Color.BLACK)
	_segbar(Vector2(12, 22), 20, int(ceil(20.0 * enemy_hp / enemy_max)), Color("b0b8c8"))
	_text("FIAMMA", Vector2(470, 10), ICE)
	_segbar(Vector2(470, 22), 10, int(ceil(10.0 * flame_hp / FLAME_MAX)), FLAME_COLS[2])
	_text("CARICA", Vector2(470, 36), ICE)
	_segbar(Vector2(470, 48), 10, int(10.0 * charge), Color("e6c85a"))

	match phase:
		Phase.MENU:
			_draw_menu()
		Phase.DODGE:
			_draw_dodge_hud()
		Phase.RESOLVE:
			pass
		Phase.WIN:
			_text("VITTORIA", Vector2(250, 150), Color("ffe08a"), 3, Color.BLACK)
			_text("R = RICOMINCIA", Vector2(262, 184), WHITE)
		Phase.LOSE:
			_text("LA FIAMMA SI E SPENTA", Vector2(206, 150), Color("ff6b6b"), 2, Color.BLACK)
			_text("R = RICOMINCIA", Vector2(262, 178), WHITE)

	for tx in texts:
		var a := 1.0 - float(tx["age"]) / 1.4
		var c: Color = tx["col"]
		var p: Vector2 = tx["pos"] + Vector2(0, -float(tx["age"]) * 22.0)
		_text(tx["s"], p - Vector2(float(tx["s"].length()) * 6.0, 0.0), Color(c.r, c.g, c.b, a), 2, Color(0, 0, 0, a))

	_text("1 BOSS   2 CESPUGLIO   R RICOMINCIA", Vector2(180, 352), Color(0.55, 0.62, 0.72, 0.6))


func _draw_menu() -> void:
	var py := 279.0
	var ph := 70.0
	var entries := _menu_entries()
	_panel(Rect2(12, py, 124, ph))
	_text("COSA FAI?", Vector2(24, py + 9), GREY)
	var main_labels := ["MOSSE", "OGGETTI"]
	for i in main_labels.size():
		var sel := menu_level == 0 and cursor == i
		if sel:
			_text(">", Vector2(24, py + 22 + i * 12), Color("ff4a2e"))
		_text(main_labels[i], Vector2(34, py + 22 + i * 12), WHITE if sel else GREY)

	_panel(Rect2(140, py, 140, ph))
	var sub_title := "MOSSE" if menu_level <= 1 else "OGGETTI"
	_text(sub_title, Vector2(152, py + 9), GREY)
	var sub_entries: Array[Dictionary] = []
	if menu_level == 2:
		sub_entries = entries
	else:
		var save := menu_level
		menu_level = 1
		sub_entries = _menu_entries()
		menu_level = save
	for i in sub_entries.size():
		var c: Color = sub_entries[i].get("color", WHITE)
		var sel := menu_level >= 1 and cursor == i
		if sel:
			_text(">", Vector2(152, py + 21 + i * 11), Color("ff4a2e"))
		_text(sub_entries[i]["label"], Vector2(162, py + 21 + i * 11), c if sel or menu_level == 0 else c.darkened(0.2))

	_panel(Rect2(364, py, 264, ph))
	var m: Dictionary = {}
	if menu_level == 1 and cursor < sub_entries.size():
		m = sub_entries[cursor]["move"]
	elif menu_level == 0 and cursor == 0:
		m = moves[0]
	if not m.is_empty():
		_text(m["name"], Vector2(376, py + 9), m["color"])
		var lines := _describe(m)
		for i in lines.size():
			_text(lines[i], Vector2(376, py + 21 + i * 11), WHITE if i == 0 else GREY)
	elif menu_level == 2:
		_text("BRACE", Vector2(376, py + 9), Color("ffa726"))
		_text("RECUPERA %d DI FIAMMA" % int(ITEM_HEAL), Vector2(376, py + 21), WHITE)
		_text("COSTA IL TURNO", Vector2(376, py + 32), GREY)
	else:
		_text("OGGETTI", Vector2(376, py + 9), GREY)
		_text("USA UN OGGETTO", Vector2(376, py + 21), WHITE)
		_text("COSTA IL TURNO", Vector2(376, py + 32), GREY)


func _draw_dodge_hud() -> void:
	# cerchi di vicinanza tratteggiati, centrati sull'occhio del nemico (niente riquadro)
	var radii := [MAX_DIST * 0.34, MAX_DIST * 0.67, MAX_DIST]
	var names := ["VICINO", "MEDIO", "LONTANO"]
	for ri in 3:
		var r: float = radii[ri]
		var n := int(TAU * r / 2.0)
		for i in n:
			if i % 9 >= 5:
				continue
			var a := TAU * float(i) / float(n)
			var q := anchor + Vector2(cos(a), sin(a)) * r
			if q.x < 0 or q.x >= 640 or q.y < 0 or q.y >= 300:
				continue
			ui.draw_rect(Rect2(floorf(q.x), floorf(q.y), 1, 1), Color(0.5, 0.63, 0.78, 0.55))
		var lp := anchor + Vector2(cos(deg_to_rad(33.0)), sin(deg_to_rad(33.0))) * r
		if lp.x < 600 and lp.y < 290:
			ui.draw_rect(Rect2(lp.x - 3, lp.y - 3, names[ri].length() * 6 + 5, 11), Color(0.03, 0.045, 0.07, 0.8))
			_text(names[ri], lp, Color("aac0da"))

	var p := proximity()
	var mult := effect_mult(cur_move, p)
	_text("MOSSA", Vector2(14, 256), GREY)
	_text(cur_move.get("name", ""), Vector2(14, 267), cur_move.get("color", WHITE))
	_text("VICINANZA", Vector2(14, 284), GREY)
	_segbar(Vector2(14, 295), 10, int(round(p * 10.0)), Color("ff4a2e"))
	_text("EFFETTO", Vector2(14, 312), GREY)
	_text("%d%%" % roundi(mult * 100.0), Vector2(14, 323), WHITE, 2, Color.BLACK)
	_text("TURNO DEL NEMICO", Vector2(470, 64), GREY)
	_segbar(Vector2(470, 76), 10, int(10.0 * turn_t / TURN_TIME), Color("c8d2e0"))
