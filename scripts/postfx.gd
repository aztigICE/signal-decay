extends CanvasLayer
## Retro post-processing: Bayer dither + 16-level posterize over the 3D view.
## Also turns on TAA for the soft motion ghosting. F1 toggles the filter.

@export var enable_taa: bool = true

@onready var dither: ColorRect = $Dither


func _ready() -> void:
	GameInput.ensure()
	get_viewport().use_taa = enable_taa


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_postfx"):
		dither.visible = not dither.visible
