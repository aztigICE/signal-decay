class_name SatelliteDish
extends StaticBody3D
## Aimable satellite dish. Drives two bones of the imported rig:
## the mast (azimuth, turns around the vertical axis) and the head (elevation, tilts).
##
## Azimuth is a compass bearing in degrees: 0 = north (-Z), 90 = east (+X).
## Elevation is degrees above the horizon: 0 = horizon, 90 = straight up.
## Setting `target_*` makes the motors slew there at `slew_speed`; setting
## `azimuth` / `elevation` directly snaps.

signal aim_changed(azimuth: float, elevation: float)
signal slew_finished

const AZIMUTH_BONE := "Bone.001"
const ELEVATION_BONE := "Bone.003"
const MIN_ELEVATION := 5.0
const MAX_ELEVATION := 90.0

@export_range(0.0, 360.0, 0.1) var azimuth := 135.0:
	set(value):
		azimuth = fposmod(value, 360.0)
		if not is_slewing:
			target_azimuth = azimuth
		_apply_pose()
@export_range(MIN_ELEVATION, MAX_ELEVATION, 0.1) var elevation := 35.0:
	set(value):
		elevation = clampf(value, MIN_ELEVATION, MAX_ELEVATION)
		if not is_slewing:
			target_elevation = elevation
		_apply_pose()
## Motor speed in degrees per second.
@export var slew_speed := 12.0
## Applied to every mesh in the model, so a re-import of the FBX can't undo it.
@export var surface_material: Material

var target_azimuth := 135.0
var target_elevation := 35.0
var is_slewing := false

var _skeleton: Skeleton3D
var _az_bone := -1
var _el_bone := -1


func _ready() -> void:
	if surface_material:
		for mesh in find_children("*", "MeshInstance3D", true, false):
			(mesh as MeshInstance3D).material_override = surface_material
	_skeleton = find_child("Skeleton3D", true, false) as Skeleton3D
	if _skeleton == null:
		push_error("SatelliteDish: no Skeleton3D in model")
		return
	_az_bone = _skeleton.find_bone(AZIMUTH_BONE)
	_el_bone = _skeleton.find_bone(ELEVATION_BONE)
	_apply_pose()


func _process(delta: float) -> void:
	if not is_slewing:
		return
	var step := slew_speed * delta
	var az_diff := wrapf(target_azimuth - azimuth, -180.0, 180.0)
	azimuth += clampf(az_diff, -step, step)
	elevation = move_toward(elevation, target_elevation, step)
	if absf(az_diff) <= step and is_equal_approx(elevation, target_elevation):
		is_slewing = false
		azimuth = target_azimuth
		slew_finished.emit()
	aim_changed.emit(azimuth, elevation)


## Start slewing the motors toward a bearing and elevation.
func slew_to(new_azimuth: float, new_elevation: float) -> void:
	target_azimuth = fposmod(new_azimuth, 360.0)
	target_elevation = clampf(new_elevation, MIN_ELEVATION, MAX_ELEVATION)
	is_slewing = true


## World-space unit vector the dish is pointing along.
func get_aim_direction() -> Vector3:
	var az := deg_to_rad(azimuth)
	var el := deg_to_rad(elevation)
	var local := Vector3(sin(az) * cos(el), sin(el), -cos(az) * cos(el))
	return (global_transform.basis * local).normalized()


func _apply_pose() -> void:
	if _skeleton == null or _az_bone < 0 or _el_bone < 0:
		return
	# Rest pose points straight up. Compass bearing is clockwise from above,
	# Godot's +Y rotation is counter-clockwise, hence the minus sign.
	var az_rest := _skeleton.get_bone_rest(_az_bone).basis.get_rotation_quaternion()
	_skeleton.set_bone_pose_rotation(_az_bone, az_rest * Quaternion(Vector3.UP, deg_to_rad(-azimuth)))
	# Tilt from vertical down toward the bearing (north = -Z at azimuth 0).
	# The rig's head bone is mirrored, so a positive X rotation tilts toward -Z.
	var el_rest := _skeleton.get_bone_rest(_el_bone).basis.get_rotation_quaternion()
	_skeleton.set_bone_pose_rotation(_el_bone, el_rest * Quaternion(Vector3.RIGHT, deg_to_rad(90.0 - elevation)))
