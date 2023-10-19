extends Node3D

var test_normal = false

const VirtualLight := preload("res://addons/VirtualLight/VirtualLight.gd")
var INITIAL_MAX_LIGHTS := 500
var max_lights := INITIAL_MAX_LIGHTS

var count := 0.0
var start := 0
var rng := RandomNumberGenerator.new()
var max_60fps := {}

func _ready():
	rng.randomize()
	_setup()

func _setup():
	max_lights = INITIAL_MAX_LIGHTS
	count = 0
	while %Container.get_child_count() > 0:
		%Container.remove_child(%Container.get_child(0))
	for i in range(max_lights):
		_add_light()

func _add_light():
	count += 1
	var i := %Container.get_child_count()
	if i > max_lights:
		return
	var l
	if test_normal:
		l = SpotLight3D.new() if i % 2 == 0 else OmniLight3D.new()
	else:
		l = VirtualLight.new()
		l.light_type = VirtualLight.LightType.Spot if i % 2 == 0 else VirtualLight.LightType.Omni
	l.rotate_x(PI * -0.5)
	l.transform.origin = Vector3(rng.randf_range(-15, 15), rng.randf_range(0, 5), rng.randf_range(-15, 15))
	l.shadow_enabled = true
	%Container.add_child(l)

func _process(delta: float):
	var light_count := %Container.get_child_count()
	var toggle_count = 10 * count * delta
	
	if toggle_count > max_lights && Engine.get_frames_per_second() >= 60:
		max_lights *= 1.5
	var end := int(round(toggle_count)) + start
	for i in range(start, end):
		if i < light_count:
			%Container.get_child(i).visible = !%Container.get_child(i).visible
	if end > light_count:
		start = 0
	else:
		start = end
	var test_type = "normal" if test_normal else "virtual"
	if Engine.get_frames_per_second() >= 60:
		if !test_type in max_60fps || toggle_count > max_60fps[test_type] * 0.75:
			max_60fps[test_type] = round(toggle_count)
		$Timer.stop()
	elif $Timer.is_stopped():
		$Timer.start()
	$Label.text = "%sfps %s %s lights: hideshow: %s max @60fps: %s  (%s frame time)" % [
		 Engine.get_frames_per_second(), light_count, test_type, round(toggle_count), max_60fps, delta
	]
	
	for i in range(10):
		_add_light()


func _on_timer_timeout():
	test_normal = !test_normal
	_setup()
