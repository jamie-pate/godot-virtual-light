extends EditorNode3DGizmoPlugin
# cribbed from godot's editor/spatial_editor_gizmos.cpp

const VirtualLight = preload('./VirtualLight.gd')

var _editor_plugin: EditorPlugin
var _settings

func _ed_intf() -> EditorInterface:
	return _editor_plugin.get_editor_interface()

func get_name():
	return "Virtual Light3D"

func _init(editor_plugin: EditorPlugin):
	_editor_plugin = editor_plugin

	create_material("lines_primary", Color(1, 1, 1), false, false, true);
	create_material("lines_secondary", Color(1, 1, 1, 0.35), false, false, true);
	create_material("lines_billboard", Color(1, 1, 1), true, false, true);

	var ed = _ed_intf()
	create_icon_material("light_omni_icon", preload('./VirtualLightOmni.svg'))
	create_icon_material("light_spot_icon", preload('./VirtualLightSpot.svg'))

	create_handle_material("handles");
	create_handle_material("handles_billboard", true);

func has_gizmo(spatial):
	return spatial is VirtualLight

func _get_handle_name(gizmo, index):
	match index:
		0: return 'Radius'
		1: return 'Aperture'
		_: return 'Unknown'

func _get_handle_value(gizmo: EditorNode3DGizmo, index):
	var virtual_light: VirtualLight = gizmo.get_node_3d()
	var light: Light3D = virtual_light.target

	if !light:
		print('get_handle_values: no light on %s' % [virtual_light])
		return null
	match index:
		0: return light.get_param(Light3D.PARAM_RANGE)
		1: return light.get_param(Light3D.PARAM_SPOT_ANGLE)
		_:
			print('unknown handle %s' % index)
			return null

func _find_closest_angle_to_half_pi_arc(from: Vector3, to: Vector3, arc_radius: float, arc_xform: Transform3D) -> float:

	#bleh, discrete is simpler
	var arc_test_points: int = 64
	var min_d: float = 1e20
	var min_p: Vector3

	for i in range(arc_test_points):

		var a: float = i * PI * 0.5 / arc_test_points
		var an: float = (i + 1) * PI * 0.5 / arc_test_points
		var p := Vector3(cos(a), 0, -sin(a)) * arc_radius
		var n := Vector3(cos(an), 0, -sin(an)) * arc_radius

		var ra: Vector3
		var rb: Vector3
		var r := Geometry.get_closest_points_between_segments(p, n, from, to)
		ra = r[0]
		rb = r[1]
		var d: float = ra.distance_to(rb)
		if d < min_d:
			min_d = d
			min_p = ra

	var a: float = (PI * 0.5) - Vector2(min_p.x, -min_p.z).angle()
	return a * 180.0 / PI;

func _snap_enabled():
	Input.is_key_pressed(KEY_CTRL)

func _translate_snap():
	# TODO: find a way to load this from the SpatialEditor
	# https://github.com/godotengine/godot/issues/11180
	return 0.1 if Input.is_key_pressed(KEY_SHIFT) else 1.0

func set_handle(gizmo: EditorNode3DGizmo, index: int, camera: Camera3D, point: Vector2):
	var virtual_light: VirtualLight = gizmo.get_node_3d()
	var light: Light3D = virtual_light.target
	if !light:
		print('set_handle: no light on %s' % [virtual_light])
		return
	var gt := light.global_transform
	var gi := gt.affine_inverse()

	var ray_from := camera.project_ray_origin(point)
	var ray_dir := camera.project_ray_normal(point)

	var s := PackedVector3Array([gi * (ray_from), gi.xform(ray_from + ray_dir * 4096)])
	if index == 0:
		if light is SpotLight3D:
			var r := Geometry.get_closest_points_between_segments(Vector3(), Vector3(0, 0, -4096), s[0], s[1])
			var d := -r[0].z
			if _snap_enabled():
				d = snapped(d, _translate_snap())
			if d <= 0:
				d = 0

			light.set_param(Light3D.PARAM_RANGE, d)
			virtual_light.update_gizmos()
		elif light is OmniLight3D:
			var b = camera.transform.basis
			# get_axis in c++
			var axis = b.z #Vector3(b.x.z, b.y.z, b.z.z)
			var dot = axis.dot(gt.origin)
			var gto = gt.origin
			var cp := Plane(gto, gto + b.x, gto + b.y)
			# maybe null
			var inters = cp.intersects_ray(ray_from, ray_dir)
			if inters:
				var r:float = inters.distance_to(gt.origin)
				if _snap_enabled():
					r = snapped(r, _translate_snap())

				light.set_param(Light3D.PARAM_RANGE, r)
				virtual_light.update_gizmos()
	elif index == 1:
		var a := _find_closest_angle_to_half_pi_arc(s[0], s[1], light.get_param(Light3D.PARAM_RANGE), gt)
		light.set_param(Light3D.PARAM_SPOT_ANGLE, clamp(a, 0.01, 89.99))
		virtual_light.update_gizmos()

func _commit_handle(gizmo: EditorNode3DGizmo, index: int, restore, cancel: bool=false) -> void:
	var virtual_light: VirtualLight = gizmo.get_node_3d()
	var light: Light3D = virtual_light.target
	if !light:
		print('_commit_handle: no light on %s' % [virtual_light])
		return
	if cancel:
		light.set_param(Light3D.PARAM_RANGE if index == 0 else Light3D.PARAM_SPOT_ANGLE, restore)
	elif index == 0:
		var ur := _editor_plugin.get_undo_redo()
		ur.create_action('Change Light3D Radius')
		ur.add_do_method(light, 'set_param', Light3D.PARAM_RANGE, light.get_param(Light3D.PARAM_RANGE))
		ur.add_undo_method(light, 'set_param', Light3D.PARAM_RANGE, restore)
		ur.commit_action()
	elif index == 1:
		var ur := _editor_plugin.get_undo_redo()
		ur.create_action('Change Light3D Radius')
		ur.add_do_method(light, 'set_param', Light3D.PARAM_SPOT_ANGLE, light.get_param(Light3D.PARAM_SPOT_ANGLE))
		ur.add_undo_method(light, 'set_param', Light3D.PARAM_SPOT_ANGLE, restore)
		ur.commit_action()

func _color_get_s(color: Color):

	var min_ := min(color.r, color.g)
	min_ = min(min_, color.b)
	var max_ := max(color.r, color.g)
	max_ = max(max_, color.b)

	var delta := max_ - min_

	return (delta / max_) if max_ != 0 else 0

func _color_get_h(color: Color):

	var min_ := min(color.r, color.g)
	min_ = min(min_, color.b)
	var max_ := max(color.r, color.g)
	max_ = max(max_, color.b)

	var delta := max_ - min_

	if delta == 0:
		return 0

	var h: float
	if color.r == max_:
		h = (color.g - color.b) / delta # between yellow & magenta
	elif color.g == max_:
		h = 2 + (color.b - color.r) / delta # between cyan & yellow
	else:
		h = 4 + (color.r - color.g) / delta # between magenta & cyan

	h /= 6.0
	if h < 0:
		h += 1.0

	return h

func redraw(gizmo):
	var virtual_light: VirtualLight = gizmo.get_node_3d()
	var light: Light3D = virtual_light.target
	gizmo.clear()
	if !light:
		print('redraw: no light on %s' % [virtual_light])
		return
	var color: Color = light.light_color
	color = Color.from_hsv(_color_get_h(color), _color_get_s(color), 1)

	if light is OmniLight3D:
		var lines_material := get_material('lines_secondary', gizmo)
		var lines_billboard_material := get_material('lines_billboard', gizmo)
		var icon := get_material('light_omni_icon', gizmo)

		var on := light as OmniLight3D
		var r: float = on.get_param(Light3D.PARAM_RANGE)
		var points := PackedVector3Array()
		var points_billboard := PackedVector3Array()

		for i in range(120):
			var ra: float = deg_to_rad(float(i * 3))
			var rb: float = deg_to_rad(float((i + 1) * 3))
			var a := Vector2(sin(ra), cos(ra)) * r
			var b := Vector2(sin(rb), cos(rb)) * r

			points.push_back(Vector3(a.x, 0, a.y))
			points.push_back(Vector3(b.x, 0, b.y))
			points.push_back(Vector3(0, a.x, a.y))
			points.push_back(Vector3(0, b.x, b.y))
			points.push_back(Vector3(a.x, a.y, 0))
			points.push_back(Vector3(b.x, b.y, 0))

			points_billboard.push_back(Vector3(a.x, a.y, 0))
			points_billboard.push_back(Vector3(b.x, b.y, 0))

		gizmo.add_lines(points, lines_material, true, color)
		gizmo.add_lines(points_billboard, lines_billboard_material, true, color)
		gizmo.add_unscaled_billboard(icon, 0.05, color)

		var handles := PackedVector3Array()
		handles.push_back(Vector3(r, 0, 0))
		# don't pass gizmo because it's actually for handles?
		gizmo.add_handles(handles, get_material('handles_billboard', null), true)

	if light is SpotLight3D:
		var material_primary := get_material('lines_primary', gizmo)
		var material_secondary := get_material('lines_secondary', gizmo)
		var icon := get_material('light_spot_icon', gizmo)

		var points_primary := PackedVector3Array()
		var points_secondary := PackedVector3Array()
		var sl := light as SpotLight3D
		var r: float =  sl.get_param(Light3D.PARAM_RANGE)
		var angle = deg_to_rad(sl.get_param(Light3D.PARAM_SPOT_ANGLE))
		var w := r * sin(angle)
		var d := r * cos(angle)

		for i in range(120):
			var ra := deg_to_rad(float(i * 3))
			var rb := deg_to_rad(float((i + 1) * 3))
			var a := Vector2(sin(ra), cos(ra)) * w
			var b := Vector2(sin(rb), cos(rb)) * w

			points_primary.push_back(Vector3(a.x, a.y, -d))
			points_primary.push_back(Vector3(b.x, b.y, -d))

			if i % 15 == 0:
				points_secondary.push_back(Vector3(a.x, a.y, -d))
				points_secondary.push_back(Vector3())

		points_primary.push_back(Vector3(0, 0, -r))
		points_primary.push_back(Vector3())

		gizmo.add_lines(points_primary, material_primary, false, color)
		gizmo.add_lines(points_secondary, material_secondary, false, color)

		var ra: float = 16.0 * PI * 2.0 / 64.0
		var a := Vector2(sin(ra), cos(ra)) * w

		var handles = PackedVector3Array([
			Vector3(0, 0, -r),
			Vector3(a.x, a.y, -d)
		])

		gizmo.add_handles(handles, get_material('handles', null))
		gizmo.add_unscaled_billboard(icon, 0.05, color)
