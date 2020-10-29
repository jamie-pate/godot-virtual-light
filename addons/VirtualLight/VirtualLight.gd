extends Spatial
tool

const _DEBUG := false
const VirtualLightServer = preload('./VirtualLightServer.gd');

enum LightType { Omni, Spot }
enum Detail { Normal=0, Low=1, Lower=2 }

export(LightType) var light_type:= LightType.Omni setget _set_light_type
export(Detail) var detail: int = Detail.Normal setget _set_detail

var target: Light setget _set_target
var show_debug_meshes: bool setget _set_show_debug_meshes

var _r: RandomNumberGenerator

# shadow properties to conditionally override based on detail
var _props := {}
var _reparenting_target := false
var _skip_sync := false
var _debug_meshes: Array = []

func _init():
	var err:int = connect('visibility_changed', self, '_on_visibility_changed')
	assert(err == OK)

func _on_visibility_changed():
	_sync_visible()

func get_param(param: int):
	_ensure_target()
	return target.get_param(param)

func set_param(param: int, value: float):
	_ensure_target()
	target.set_param(param, value)

func _set_detail(value: int):
	detail = value
	_ensure_target()
	if target && is_inside_tree():
		# remove lights completely if we set max_low_detail
		_reparent_target_later()
		# Just disable shadows for LOWER_DETAIL
		target.shadow_enabled = false if detail == Detail.Low else _props.shadow_enabled

func _reparent_target_later():
	if !_reparenting_target:
		_reparenting_target = true
		call_deferred('_reparent_target')

func _reparent_target():
	_reparenting_target = false
	if is_inside_tree() && target:

		if detail == Detail.Lower:
			if target.get_parent():
				target.get_parent().remove_child(target)
		else:
			var parent: Node = get_viewport()
			if Engine.editor_hint:
				parent = self
			while target && is_inside_tree() && target.get_parent() != parent:
				if target.get_parent():
					target.get_parent().remove_child(target)
				if _DEBUG:
					target.name = str(get_path()).replace('/' , '_')
				parent.add_child(target)
				if target.is_inside_tree():
					target.global_transform = global_transform
			var tp = target.get_parent()
			if !tp:
				print('no parent!')
		if target.visible != is_visible_in_tree():
			_sync_visible()

func _ensure_target():
	if !target:
		_set_light_type(light_type)

func _process(delta):
	# NOTIFICATION_TRANSFORM_CHANGED doesn't seem to work :(
	_update_transform()

func _notification(what):
	if what == NOTIFICATION_PREDELETE:
		if target:
			var p := target.get_parent()
			if p:
				p.remove_child(target)
			if !target.is_queued_for_deletion():
				target.queue_free()

func _sync_visible():
	if !_skip_sync && is_inside_tree():
		VirtualLightServer.instance().sync_visible(self)

func _enter_tree():
	_ensure_target()
	_set_detail(detail)

	_reparent_target_later()

func _exit_tree():
	if target:
		var p = target.get_parent()
		if p:
			p.remove_child(target)
	VirtualLightServer.instance().remove(self)

func copy_from(light: Light):
	if light is OmniLight:
		_set_light_type(LightType.Omni)
	elif light is SpotLight:
		_set_light_type(LightType.Spot)
	_copy_props(light, self, ['script'])

func _copy_props(src: Light, dest, banned_props = []):
	var pl = src.get_property_list()

	var banned = ['multiplayer', 'global_transform']
	for p in banned_props:
		banned.append(p)
	for p in pl:
		if !p.name in banned && p.name in dest && p.name in dest && p.usage != PROPERTY_USAGE_STORAGE:
			dest[p.name] = src[p.name]

func _set_light_type(value):
	var changed = light_type != value
	light_type = value
	if target && !changed:
		return
	if !target:
		assert(get_child_count() == 0)
	if target:
		target.queue_free()
		target = null
	if value == LightType.Omni && (!target || !target is OmniLight):
		var _new_target := OmniLight.new()
		if target:
			_copy_props(target, _new_target)
		_set_target(_new_target)
	if value == LightType.Spot && (!target || !target is SpotLight):
		var _new_target := SpotLight.new()
		if target:
			_copy_props(target, _new_target)
		_set_target(_new_target)
	target.visible = false

	_set_show_debug_meshes(show_debug_meshes)
	_reparent_target_later()
	# ensure that the correct gizmo gets drawn
	if visible && Engine.editor_hint:
		_skip_sync = true
		visible = false
		visible = true
		_skip_sync = false

func _set_show_debug_meshes(value):
	show_debug_meshes = value
	if _DEBUG || show_debug_meshes:
		var script_path: String = get_script().resource_path.get_base_dir()
		var DebugLabel = load('%s/debug/DebugLabel.tscn' % [script_path])
		var dl
		if target:
			for c in target.get_children():
				c.queue_free()
			var lm = _debug_light_mesh(Color.red)
			if !_r:
				_r = RandomNumberGenerator.new()
				_r.randomize()
			lm.transform = lm.transform.scaled(Vector3(_r.randf() + 0.1, _r.randf() + 0.1, _r.randf() + 0.1))
			target.add_child(lm)
			if DebugLabel:
				dl = DebugLabel.instance()
				dl.text = '%s %s target: %s' % [Engine.get_frames_drawn(), target, get_path()]
				dl.transform.origin = Vector3(0, 0.5 * _r.randf(), 0)
				target.add_child(dl)
		if !_debug_meshes:
			_debug_meshes.append(_debug_light_mesh(Color.green))
			if DebugLabel:
				dl = DebugLabel.instance()
				dl.text = get_path()
				_debug_meshes.append(dl)
			for m in _debug_meshes:
				add_child(m)
	else:
		if target:
			for c in target.get_children():
				c.queue_free()
		for m in _debug_meshes:
			m.queue_free()
		_debug_meshes = []

func _debug_light_mesh(color: Color):
	var mi := MeshInstance.new()
	var s := SphereMesh.new()
	s.radial_segments = 12
	s.rings = 8
	var radius = 0.15 + (color.r * 0.05)
	s.radius = radius
	s.height = radius * 2
	mi.mesh = s
	mi.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_OFF
	var mat := SpatialMaterial.new()
	mat.flags_no_depth_test = true
	mat.flags_unshaded = true
	mat.flags_transparent = true
	mat.params_blend_mode = SpatialMaterial.BLEND_MODE_ADD
	mat.albedo_color = Color(color.r, color.g, color.b, color.a if color.a < 1.0 else 0.25)
	mi.set_surface_material(0, mat)
	return mi

func _set_target(value: Light):
	if value:
		target = value
		_props.shadow_enabled = target.shadow_enabled
		_set_detail(detail)

func _get_property_list():
	_ensure_target()
	assert(target)
	if target:
		var light_pl = target.get_property_list()
		var pl = []
		for p in light_pl:
			# editor errors/complains if name is empty
			if p.name:
				pl.append(p)
		return pl
	assert(false)
	return []

# https://docs.godotengine.org/en/stable/classes/class_object.html?highlight=Object#class-object-method-get
func _get(property: String):
	if property == 'target':
		return target
	elif property == 'visible':
		return visible
	elif property == 'detail':
		return detail
	elif property == 'global_transform':
		return global_transform
	elif property == 'transform':
		return transform
	elif property == 'translation':
		return translation
	elif property == 'rotation':
		return rotation
	elif property == 'rotation_degrees':
		return rotation_degrees
	elif property == 'scale':
		return scale
	elif property == 'script':
		return get_script()
	elif property == 'name':
		return name
	elif property == 'show_debug_meshes':
		return show_debug_meshes
	elif target:
		# grab from shadow _props
		if property in _props:
			return _props[property]
		else:
			# pass the rest on the the target
			return target.get(property)
	# worrying that the return value for 'property doesn't exist' is null
	return null

func _set(property: String, value):
	_ensure_target()
	var result = true
	if Engine.editor_hint:
		update_gizmo()

	if property == 'visible':
		visible = !!value
		call_deferred('_sync_visible')
	if property == 'target':
		_set_target(value)
	elif property == 'detail':
		_set_detail(value)
	elif property == 'global_transform':
		global_transform = value
		_update_transform()
	elif property == 'transform':
		transform = value
		_update_transform()
	elif property == 'translation':
		translation = value
		_update_transform()
	elif property == 'rotation':
		rotation = value
		_update_transform()
	elif property == 'scale':
		scale = value
	elif property == 'rotation_degrees':
		rotation_degrees = value
		_update_transform()
	elif property == 'name':
		name = value
	elif property == 'show_debug_meshes':
		show_debug_meshes = value
	elif property == 'script':
		set_script(value)
	elif target:
		# get from shadow props
		if property in _props:
			_props[property] = value
		else:
			target.set(property, value)
		# ensure shadow props are applied at the correct detail levels
		_set_detail(detail)
	else:
		result = false
	return result

func _update_transform():
	if target && target.is_inside_tree():
		target.global_transform = global_transform
