tool
extends EditorPlugin
const VirtualLightGizmoPlugin = preload('./VirtualLightGizmoPlugin.gd')
var gizmo_plugin

func _enter_tree():
	gizmo_plugin = VirtualLightGizmoPlugin.new(self)
	add_spatial_gizmo_plugin(gizmo_plugin)
	add_custom_type('VirtualLight', 'Spatial', preload('./VirtualLight.gd'), preload('./VirtualLight.svg'))

func _exit_tree():
	remove_spatial_gizmo_plugin(gizmo_plugin)
	remove_custom_type('VirtualLight')
