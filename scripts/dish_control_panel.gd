extends Node3D
## Control panel at the foot of the dish: a mechanical AZ/EL readout and the
## aim buttons. Reading the angles means walking out here.

## Leave empty when the panel is a child of the dish scene.
@export var dish: SatelliteDish

@onready var _display: Label3D = $Face/Display


func _ready() -> void:
	if dish == null:
		dish = get_parent() as SatelliteDish
	for button in find_children("*", "DishAimButton", true, false):
		(button as DishAimButton).dish = dish
	if dish != null:
		dish.aim_changed.connect(_on_aim_changed)
		_on_aim_changed(dish.azimuth, dish.elevation)


func _on_aim_changed(azimuth: float, elevation: float) -> void:
	# Show 0.1 deg steps; 360.0 reads as 000.0 like a real dial.
	var az := fposmod(snappedf(azimuth, 0.1), 360.0)
	_display.text = "AZ %05.1f°\nEL %05.1f°" % [az, snappedf(elevation, 0.1)]
