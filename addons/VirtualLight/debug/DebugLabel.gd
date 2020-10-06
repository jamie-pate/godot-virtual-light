tool
extends Spatial

export(String) var text = '' setget _set_text

var bodies = []

var _updating: bool = false

func _ready():
	visible = len(bodies)

func _set_text(value):
	text = str(value)
	call_deferred('_set_text_deferred', text)

func _set_text_deferred(value):
	$Viewport/DebugLabelText.text = value
	call_deferred('_update_once')

func _set_small_font_deferred(value):
	$Viewport/DebugLabelText.small_font = value
	call_deferred('_update_once')

func _update_once():
	if _updating:
		return
	_updating = true;
	var tree = get_tree()
	if tree:
		yield(tree, 'idle_frame')
	$Viewport.render_target_update_mode = Viewport.UPDATE_ONCE
	_updating = false


func _on_Area_body_entered(body):
	if body == world_mgr.player:
		bodies.append(body)
		visible = len(bodies)

func _on_Area_body_exited(body):
	bodies.erase(body)
	visible = len(bodies)
