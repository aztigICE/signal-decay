extends CharacterBody3D
## First-person player: WASD movement, mouse look, sprint, jump, head bob,
## and a center-screen raycast for interacting with objects (E).

@export var walk_speed: float = 3.5
@export var sprint_speed: float = 6.0
@export var jump_velocity: float = 4.2
@export var mouse_sensitivity: float = 0.002
@export var interact_distance: float = 2.5
@export var ground_accel: float = 12.0
@export var air_accel: float = 3.0

const BOB_FREQ: float = 2.0
const BOB_AMP: float = 0.04

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var ray: RayCast3D = $Head/Camera3D/InteractRay
@onready var prompt: Label = $HUD/Prompt

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _focused: Node = null
var _bob_t: float = 0.0


func _ready() -> void:
	_setup_input()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	ray.target_position = Vector3(0, 0, -interact_distance)
	ray.add_exception(self)
	prompt.text = ""


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		head.rotate_x(-event.relative.y * mouse_sensitivity)
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-89.0), deg_to_rad(89.0))
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed("interact") and _focused != null:
		_focused.interact(self)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif Input.is_action_just_pressed("jump"):
		velocity.y = jump_velocity

	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir: Vector3 = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	var speed: float = sprint_speed if Input.is_action_pressed("sprint") else walk_speed
	var accel: float = ground_accel if is_on_floor() else air_accel

	velocity.x = lerp(velocity.x, dir.x * speed, accel * delta)
	velocity.z = lerp(velocity.z, dir.z * speed, accel * delta)
	move_and_slide()

	_head_bob(delta)
	_update_focus()


func _head_bob(delta: float) -> void:
	var horiz_speed: float = Vector2(velocity.x, velocity.z).length()
	if is_on_floor() and horiz_speed > 0.5:
		_bob_t += delta * horiz_speed * BOB_FREQ
	else:
		_bob_t = lerp(_bob_t, round(_bob_t / PI) * PI, 10.0 * delta)
	camera.position.y = sin(_bob_t) * BOB_AMP
	camera.position.x = cos(_bob_t * 0.5) * BOB_AMP * 0.5


func _update_focus() -> void:
	var target: Node = null
	if ray.is_colliding():
		var hit: Object = ray.get_collider()
		if hit != null and hit.has_method("interact"):
			target = hit
	_focused = target
	prompt.text = "[E] " + _focused.get_prompt() if _focused != null else ""


func _setup_input() -> void:
	# Default key bindings. Kept in code for now; can move to Project Settings > Input Map later.
	var binds: Dictionary = {
		"move_forward": KEY_W,
		"move_back": KEY_S,
		"move_left": KEY_A,
		"move_right": KEY_D,
		"jump": KEY_SPACE,
		"sprint": KEY_SHIFT,
		"interact": KEY_E,
	}
	for action: String in binds:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		var ev := InputEventKey.new()
		ev.physical_keycode = binds[action]
		InputMap.action_add_event(action, ev)
