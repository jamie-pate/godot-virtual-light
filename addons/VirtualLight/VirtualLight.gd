extends Spatial
tool

enum LightType { Omni, Spot }
enum Detail { Normal=0, Low=1, Lower=2 }

export(LightType) var light_type:= LightType.Omni setget _set_light_type

var target: Light setget _set_target
export(Detail) var detail: int = Detail.Normal setget _set_detail

# properties to override based on detail
var _props := {}

# warning-ignore:unused_argument
func _process(delta):
	if target && target.is_inside_tree():
		target.global_transform = global_transform

func _set_detail(value: int):
	detail = value
	if target && is_inside_tree():
		if Engine.editor_hint:
			if target.get_parent() != self:
				add_child(target)
			return
		# remove lights completely if we set max_low_detail
		call_deferred('_reparent_target')
		# Just disable shadows for LOWER_DETAIL
		target.shadow_enabled = false if detail == Detail.Low else _props.shadow_enabled

func _reparent_target():
	if is_inside_tree() && target:
		if detail == Detail.Lower:
			if target.get_parent():
				target.get_parent().remove_child(target)
		else:
			var tree = get_tree()
			while target && is_inside_tree() && target.get_parent() != tree.root:
				if target.get_parent():
					target.get_parent().remove_child(target)
				tree.root.add_child(target)
				target.global_transform = global_transform
				if !target.get_parent() == tree.root:
					# i don't think this is actually needed
					print('yield->target.parent= %s' % [target.get_parent()])
					yield(tree, 'idle_frame')
					print('yield->target= %s parent=%s' % [ target, target.get_parent() if target else null])

func _ensure_target():
	if !target:
		_set_light_type(light_type)

func _enter_tree():
	_set_detail(detail)
	_ensure_target()

func _exit_tree():
	if target && target.get_parent():
		target.get_parent().remove_child(target)

func _copy_props(src: Light, dest: Light):
	var pl = src.get_property_list()

	for p in pl:
		var banned = ['multiplayer', 'global_transform']
		if !p.name in banned && p.name in dest && p.name in dest:
			dest[p.name] = src[p.name]

func _set_light_type(value):
	var changed = light_type != value
	light_type = value
	if target && !changed:
		return
	if target:
		target.queue_free()
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
	# ensure that the correct gizmo gets drawn
	if visible:
		visible = false
		visible = true

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
	elif property == 'detail':
		return detail
	elif property == 'transform':
		return transform
	elif property == 'translation':
		return translation
	elif property == 'rotation':
		return rotation
	elif property == 'rotation_degrees':
		return rotation_degrees
	elif property == 'script':
		return get_script()
	elif property == 'name':
		return name
	elif target:
		if property in _props:
			return _props[property]
		else:
			return target.get(property)
	# worrying that the return value for 'property doesn't exist' is null
	return null

func _set(property: String, value):
	var result = true
	if Engine.editor_hint:
		update_gizmo()
	if property == 'target':
		_set_target(value)
	elif property == 'detail':
		_set_detail(value)
	elif property == 'transform' && Engine.editor_hint:
		transform = value
		if target && target.is_inside_tree():
			target.global_transform = global_transform
	elif property == 'translation':
		translation = value
	elif property == 'rotation':
		rotation = value
	elif property == 'rotation_degrees':
		rotation_degrees = value
	elif property == 'name':
		name = value
	elif property == 'script':
		set_script(value)
	elif target:
		if property in _props:
			_props[property] = value
		target.set(property, value)
		_set_detail(detail)
	else:
		result = false
	return result
