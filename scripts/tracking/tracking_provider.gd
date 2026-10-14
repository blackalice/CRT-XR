class_name TrackingProvider
extends RefCounted
## Provider output is a normalized Godot-space local-to-world orientation.
## +X right, +Y up, forward -Z. No translation in the 3DoF contract.
## Native providers must reject stale/nonfinite samples before returning valid=true.

var orientation := Quaternion.IDENTITY
var valid := true
var status := "Ready"
var sample_time_usec: int = 0
var enabled := true
var invert_yaw := false
var invert_pitch := false
var invert_roll := false

func close() -> void:
	pass

func update(_delta: float) -> void:
	pass

func handle_input(_event: InputEvent) -> void:
	pass
