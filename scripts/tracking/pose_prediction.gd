extends RefCounted
## Estimates body-frame angular velocity (rad/s) from a stream of timestamped
## orientations. The provider never mutates the orientation it reports; the
## consumer extrapolates with extrapolate(). That keeps recentering and
## reconnect rebasing exact, and lets the estimate be tested on its own.

const VELOCITY_LIMIT := 8.0 # rad/s; sustained faster motion is under-predicted
const FILTER_SECONDS := 0.06 # low-pass time constant for the velocity estimate
const MAX_SAMPLE_GAP := 0.25 # seconds; a longer gap resets the estimate

var angular_velocity := Vector3.ZERO
var _previous := Quaternion.IDENTITY
var _previous_stamp_usec := -1

## orientation must be the final provider output (axis mapping and inversion
## applied); the velocity is then consistent with that same frame.
## stamp_usec is the pose's own clock (driver timestamp), microseconds.
func sample(orientation: Quaternion, stamp_usec: int) -> void:
	if _previous_stamp_usec < 0:
		_previous = orientation
		_previous_stamp_usec = stamp_usec
		return
	if stamp_usec <= _previous_stamp_usec:
		_previous = orientation # same-millisecond quantization: keep the newer pose
		return
	var dt := float(stamp_usec - _previous_stamp_usec) / 1000000.0
	if dt > MAX_SAMPLE_GAP:
		angular_velocity = Vector3.ZERO
	else:
		var delta := _previous.inverse() * orientation
		if delta.w < 0.0:
			delta = Quaternion(-delta.x, -delta.y, -delta.z, -delta.w) # shortest path
		# Godot's Quaternion.log() returns axis * full rotation angle (verified
		# against the engine), so dividing by the sample gap gives rad/s.
		var measured := Vector3(delta.log().x, delta.log().y, delta.log().z) / dt
		var rate := measured.length()
		if rate > VELOCITY_LIMIT:
			measured *= VELOCITY_LIMIT / rate
		angular_velocity = angular_velocity.lerp(measured, 1.0 - exp(-dt / FILTER_SECONDS))
	_previous = orientation
	_previous_stamp_usec = stamp_usec

## No new pose this frame: the head may have stopped; bleed the estimate off.
func decay(seconds: float) -> void:
	angular_velocity *= exp(-seconds / FILTER_SECONDS)

func reset() -> void:
	angular_velocity = Vector3.ZERO
	_previous = Quaternion.IDENTITY
	_previous_stamp_usec = -1

static func extrapolate(orientation: Quaternion, velocity: Vector3, seconds: float) -> Quaternion:
	var rotation := velocity * seconds
	var angle := rotation.length()
	if angle < 0.0001:
		return orientation
	return orientation * Quaternion(rotation / angle, angle)
