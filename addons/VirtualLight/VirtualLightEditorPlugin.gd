tool
extends EditorPlugin
const VirtualLightGizmoPlugin = preload('./VirtualLightGizmoPlugin.gd')
const VirtualLight = preload('./VirtualLight.gd')
var gizmo_plugin

func _enter_tree():
	gizmo_plugin = VirtualLightGizmoPlugin.new(self)
	add_spatial_gizmo_plugin(gizmo_plugin)
	add_custom_type('VirtualLight', 'Spatial', preload('./VirtualLight.gd'), preload('./VirtualLight.svg'))

	# add_control_to_container?
	add_tool_menu_item('Convert All Lights to VirtualLights', self, 'convert_all_lights')
	add_tool_menu_item('Convert Selected Lights to VirtualLights', self, 'convert_selected_lights')

func _exit_tree():
	remove_spatial_gizmo_plugin(gizmo_plugin)
	remove_custom_type('VirtualLight')
	remove_tool_menu_item('Convert All Lights to VirtualLights')
	remove_tool_menu_item('Convert Selected Lights to VirtualLights')

func convert_selected_lights(arg):
	var selection := get_editor_interface().get_selection()

	var lights = []
	for l in selection.get_selected_nodes():
		if l is OmniLight || l is SpotLight:
			lights.append(l)
	# clear selection before modifying the tree to prevent a crash!
	selection.clear()
	var vl_selection = convert_lights(lights)
	for vl in vl_selection:
		selection.add_node(vl)

func convert_all_lights(arg):
	var lights := []
	_find_all_lights(null, lights)
	convert_lights(lights)

func _find_all_lights(node, lights):
	var edited_scene = get_editor_interface().get_edited_scene_root()
	if node == null:
		node = edited_scene
		print('scene root = ',node.get_path())
	if node is OmniLight || node is SpotLight:
		if node.owner == edited_scene:
			lights.append(node)
	for c in node.get_children():
		_find_all_lights(c, lights)

func _replace_node(node: Node, by_node: Node) -> void:
	# from editor/scene_tree_dock.cpp
	get_editor_interface().inspect_object(null)
	for s in node.get_signal_list():
		for c in node.get_signal_connection_list(s.name):
			if c.flags & CONNECT_PERSIST:
				by_node.connect(c.signal, c.target, c.method, c.binds, CONNECT_PERSIST)

	var gt = node.global_transform
	node.replace_by(by_node, true)
	by_node.name = node.name
	if by_node is VirtualLight:
		by_node.copy_from(node)
	for c in by_node.get_child_count():
		c.transform = c.transform
	by_node.global_transform = gt

func convert_lights(lights):
	if len(lights) == 0:
		print('No lights to convert')
	print('there are %s lights!' % [len(lights)])
	var virtual_lights = []
	var ur := get_undo_redo()
	ur.create_action('Replace Lights with VirtualLights')
	for l in lights:
		var parent: Node = l.get_parent()
		if parent:
			var vl = VirtualLight.new()
			ur.add_do_method(self, '_replace_node', l, vl)
			ur.add_undo_reference(vl)
			ur.add_undo_method(self, '_replace_node', vl, l)
			virtual_lights.append(vl)
	ur.commit_action()
	return virtual_lights
