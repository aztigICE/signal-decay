class_name SignalTarget
extends RefCounted
## One signal found by a scan. Created by the Station autoload.

var designation: String
var band: String
var frequency_ghz: float
var azimuth: float
var elevation: float
var found_at: float
var lifetime: float

## 1.0 when found, falling to 0.0 when the signal is gone.
func strength(now: float) -> float:
	return clampf(1.0 - (now - found_at) / lifetime, 0.0, 1.0)

func seconds_left(now: float) -> float:
	return maxf(lifetime - (now - found_at), 0.0)

func direction() -> Vector3:
	var az := deg_to_rad(azimuth)
	var el := deg_to_rad(elevation)
	return Vector3(sin(az) * cos(el), sin(el), -cos(az) * cos(el))
