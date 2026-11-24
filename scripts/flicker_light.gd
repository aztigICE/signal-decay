extends Light3D
## Makes a light flicker now and then, like a failing sodium lamp.

@export var flicker_chance: float = 0.08    # chance per second to start a flicker burst
@export var min_energy_scale: float = 0.05

var _base_energy: float
var _burst_left: float = 0.0


func _ready() -> void:
	_base_energy = light_energy


func _process(delta: float) -> void:
	if _burst_left > 0.0:
		_burst_left -= delta
		light_energy = _base_energy * (randf_range(min_energy_scale, 1.0) if randf() < 0.6 else 1.0)
		if _burst_left <= 0.0:
			light_energy = _base_energy
	elif randf() < flicker_chance * delta:
		_burst_left = randf_range(0.15, 0.9)
