extends Node

## Hitstop and time dilation.
##
## This is a rule, not a decoration: it scales `Engine.time_scale`, so it moves
## the simulation itself — a dilated fight really is slower for everything in
## it, which is the whole point of the TIME DILATION part. Screen shake and
## sparks, which change nothing, live in `graphics/fx.gd` instead.

var _hitstop_until: float = 0.0
var _dilation_until: float = 0.0
var _dilation_scale: float = 1.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(_delta: float) -> void:
	var now := _now()
	var target := 1.0
	if now < _hitstop_until:
		target = 0.02
	elif now < _dilation_until:
		target = _dilation_scale
	Engine.time_scale = lerpf(Engine.time_scale, target, 0.35) if absf(Engine.time_scale - target) > 0.01 else target

func _now() -> float:
	return float(Time.get_ticks_msec()) / 1000.0

func hitstop(seconds: float) -> void:
	_hitstop_until = maxf(_hitstop_until, _now() + seconds)

func dilate(seconds: float, scale: float = 0.45) -> void:
	_dilation_until = maxf(_dilation_until, _now() + seconds)
	_dilation_scale = scale

func is_dilated() -> bool:
	return _now() < _dilation_until

func clear() -> void:
	_hitstop_until = 0.0
	_dilation_until = 0.0
	Engine.time_scale = 1.0
