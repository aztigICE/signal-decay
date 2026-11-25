extends Node
## Autoload "Station": shared game state for the signal loop.
## The terminal asks it for targets and lock checks; the dish registers itself here.
##
## Loop: scan() picks a target bearing -> player walks out and aims the dish by hand
## -> lock() compares the dish's aim to the target and pays points.

signal target_found(target: SignalTarget)
signal target_lost(target: SignalTarget)
signal target_locked(target: SignalTarget, points: int)
signal points_changed(total: int)

## A lock needs this quality (0..1) or better.
const LOCK_THRESHOLD := 0.9
## Aim error (degrees) at which lock quality reaches 0. Quality falls off linearly,
## so with 6 deg and a 0.9 threshold the dish must be within 0.6 deg.
const LOCK_TOLERANCE_DEG := 6.0
## How long a fresh signal lasts before it fades out completely (seconds).
const SIGNAL_LIFETIME := 300.0

const BANDS := [
	["L", 1.0, 2.0],
	["S", 2.0, 4.0],
	["C", 4.0, 8.0],
]


var points := 0
var signals_locked := 0
var dish: SatelliteDish = null
var target: SignalTarget = null

var _rng := RandomNumberGenerator.new()
var _serial := 400


func _ready() -> void:
	_rng.randomize()
	_serial = _rng.randi_range(300, 700)


func _process(_delta: float) -> void:
	if target != null and target.strength(now()) <= 0.0:
		var lost := target
		target = null
		target_lost.emit(lost)


func now() -> float:
	return Time.get_ticks_msec() / 1000.0


func register_dish(d: SatelliteDish) -> void:
	dish = d


func has_dish() -> bool:
	return dish != null and is_instance_valid(dish)


## Find a new signal. Returns null if one is already being tracked.
func scan() -> SignalTarget:
	if target != null:
		return null
	var t := SignalTarget.new()
	_serial += _rng.randi_range(1, 37)
	t.designation = "SIG-%04d" % _serial
	var band: Array = BANDS[_rng.randi() % BANDS.size()]
	t.band = band[0]
	t.frequency_ghz = snappedf(_rng.randf_range(band[1], band[2]), 0.001)
	t.azimuth = snappedf(_rng.randf_range(0.0, 360.0), 0.1)
	t.elevation = snappedf(_rng.randf_range(15.0, 75.0), 0.1)
	t.found_at = now()
	t.lifetime = SIGNAL_LIFETIME
	target = t
	target_found.emit(t)
	return t


func drop_target() -> void:
	target = null


## Degrees between where the dish points and where the target is. -1 if no dish/target.
func aim_error() -> float:
	if target == null or not has_dish():
		return -1.0
	var aim := dish.get_aim_direction()
	return rad_to_deg(aim.angle_to(target.direction()))


## 0..1, how well the dish is aimed at the current target.
func lock_quality() -> float:
	var err := aim_error()
	if err < 0.0:
		return 0.0
	return clampf(1.0 - err / LOCK_TOLERANCE_DEG, 0.0, 1.0)


## Try to lock the current target. Returns points earned (0 if the lock failed).
func try_lock() -> int:
	if target == null:
		return 0
	var q := lock_quality()
	if q < LOCK_THRESHOLD:
		return 0
	var reward := roundi(10.0 + 40.0 * target.strength(now()) * q)
	var locked := target
	target = null
	points += reward
	signals_locked += 1
	target_locked.emit(locked, reward)
	points_changed.emit(points)
	return reward
