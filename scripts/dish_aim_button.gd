class_name DishAimButton
extends Interactable
## A button on the dish control panel. Hold E to turn the dish.
## A tap moves one fine step; holding starts slow and speeds up, so one button
## covers both coarse swings and fine adjustment.

enum Axis { AZIMUTH, ELEVATION }

@export var axis: Axis = Axis.AZIMUTH
@export var direction := 1.0
## Degrees moved by a single tap.
@export var fine_step := 0.1
## Degrees per second once holding, ramping from min to max over ramp_time.
@export var min_speed := 1.0
@export var max_speed := 12.0
@export var ramp_time := 3.0

const HOLD_DELAY := 0.35
const PRESS_DEPTH := 0.012

var dish: SatelliteDish

var _player: Node = null
var _held := 0.0
var _cap_rest := 0.0

@onready var _cap: Node3D = $Cap


func _ready() -> void:
	_cap_rest = _cap.position.z
	set_process(false)


func get_prompt() -> String:
	return prompt_text + " (hold)"


func interact(player: Node) -> void:
	_player = player
	_held = 0.0
	_turn(fine_step)
	_cap.position.z = _cap_rest - PRESS_DEPTH
	set_process(true)
	super.interact(player)


func _process(delta: float) -> void:
	var still_held: bool = Input.is_action_pressed("interact") \
		and _player != null and _player.has_method("get_focused") \
		and _player.get_focused() == self
	if not still_held:
		_release()
		return
	_held += delta
	if _held < HOLD_DELAY:
		return
	var t := clampf((_held - HOLD_DELAY) / ramp_time, 0.0, 1.0)
	_turn(lerpf(min_speed, max_speed, t * t) * delta)


func _release() -> void:
	_cap.position.z = _cap_rest
	_player = null
	set_process(false)


func _turn(amount: float) -> void:
	if dish == null:
		return
	if axis == Axis.AZIMUTH:
		dish.nudge(amount * direction, 0.0)
	else:
		dish.nudge(0.0, amount * direction)
