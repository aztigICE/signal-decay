class_name GameInput
extends RefCounted
## Default key bindings, registered at startup.
## Kept in code for now; can move to Project Settings > Input Map later.

const BINDS: Dictionary = {
	"move_forward": KEY_W,
	"move_back": KEY_S,
	"move_left": KEY_A,
	"move_right": KEY_D,
	"jump": KEY_SPACE,
	"sprint": KEY_SHIFT,
	"interact": KEY_E,
	"flashlight": KEY_F,
	"toggle_postfx": KEY_F1,
}


static func ensure() -> void:
	for action: String in BINDS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		var ev := InputEventKey.new()
		ev.physical_keycode = BINDS[action]
		InputMap.action_add_event(action, ev)
