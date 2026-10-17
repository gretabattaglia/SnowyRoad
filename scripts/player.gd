extends CharacterBody2D
## Personaggio top-down: si muove con WASD / frecce e anima la camminata.
## Lo spritesheet ha un solo orientamento (verso destra): per andare a sinistra si specchia (flip_h).

@export var speed: float = 90.0
## Limiti della mappa in pixel (il personaggio non esce da qui).
@export var bounds: Rect2 = Rect2(0, 0, 1280, 768)

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	_setup_input()
	sprite.play("idle")


func _physics_process(_delta: float) -> void:
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = dir * speed
	move_and_slide()

	global_position = global_position.clamp(bounds.position, bounds.end)

	if dir.x != 0.0:
		sprite.flip_h = dir.x < 0.0

	if dir != Vector2.ZERO:
		if sprite.animation != "walk":
			sprite.play("walk")
	elif sprite.animation != "idle":
		sprite.play("idle")


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
