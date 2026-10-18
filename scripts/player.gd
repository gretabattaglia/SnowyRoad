extends CharacterBody2D
## Personaggio top-down: si muove con WASD / frecce e anima la camminata nelle 4 direzioni.
## - su    -> animazione di schiena   (player_back.png)
## - giu   -> animazione frontale     (player_front.png)
## - lati  -> animazione di profilo   (player_walk.png, a sinistra si specchia con flip_h)

@export var speed: float = 90.0
## Limiti della mappa in pixel (il personaggio non esce da qui).
@export var bounds: Rect2 = Rect2(0, 0, 1280, 768)

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

## Direzione verso cui guarda: "down" (frontale), "up" (schiena) o "side".
var facing := "down"


func _ready() -> void:
	_setup_input()
	_play("idle")


func _physics_process(_delta: float) -> void:
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = dir * speed
	move_and_slide()

	global_position = global_position.clamp(bounds.position, bounds.end)

	if dir != Vector2.ZERO:
		# in diagonale vince l'asse verticale, cosi' si vede la schiena/il viso
		if absf(dir.y) >= absf(dir.x):
			facing = "down" if dir.y > 0.0 else "up"
			sprite.flip_h = false
		else:
			facing = "side"
			sprite.flip_h = dir.x < 0.0
		_play("walk")
	else:
		_play("idle")


func _play(state: String) -> void:
	var anim := state + "_" + facing
	if sprite.animation != anim:
		sprite.play(anim)


## Frecce E WASD (A/D, W/S) comandano gli stessi movimenti.
func _setup_input() -> void:
	var map := {
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"move_up": [KEY_W, KEY_UP],
		"move_down": [KEY_S, KEY_DOWN],
	}
	for action: String in map:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key: Key in map[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)
