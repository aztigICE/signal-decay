class_name Interactable
extends StaticBody3D
## Base for anything the player can press E on.
## Extend this and override get_prompt() / interact().

signal interacted(player: Node)

@export var prompt_text: String = "Interact"


func get_prompt() -> String:
	return prompt_text


func interact(player: Node) -> void:
	interacted.emit(player)
