extends Interactable
## Desk terminal. Press E to sit: the camera moves to the screen and keyboard
## input goes to the on-screen command line. Esc (or 'exit') stands you up.

@onready var sub_viewport: SubViewport = $SubViewport
@onready var ui: TerminalUI = $SubViewport/TerminalUI
@onready var screen: MeshInstance3D = $Monitor/Screen
@onready var camera_anchor: Marker3D = $CameraAnchor

var _player: Node = null


func _ready() -> void:
	prompt_text = "Use terminal"
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/lcd_screen.gdshader")
	mat.set_shader_parameter("screen_tex", sub_viewport.get_texture())
	screen.material_override = mat
	ui.exit_requested.connect(_stand_up)
	set_process_input(false)


func interact(player: Node) -> void:
	if _player != null or not player.has_method("enter_seat"):
		return
	_player = player
	player.enter_seat(camera_anchor)
	set_process_input(true)
	ui.activate()
	super.interact(player)


func _input(event: InputEvent) -> void:
	if _player == null:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_stand_up()
	elif event is InputEventKey:
		sub_viewport.push_input(event)
		get_viewport().set_input_as_handled()


func _stand_up() -> void:
	if _player == null:
		return
	ui.deactivate()
	_player.exit_seat()
	_player = null
	set_process_input(false)
