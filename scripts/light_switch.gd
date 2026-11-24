extends Interactable
## Test interactable: toggles a light on and off.

@export var light: Light3D


func get_prompt() -> String:
	if light == null:
		return "Switch (no light linked)"
	return "Turn off light" if light.visible else "Turn on light"


func interact(player: Node) -> void:
	if light != null:
		light.visible = not light.visible
	super.interact(player)
