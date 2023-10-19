@tool
extends Node3D

@export var text: String = '': set = _set_text

var bodies = []

var _updating: bool = false

func _ready():
	visible = len(bodies)

func _set_text(value):
	text = str(value)
	call_deferred('_set_text_deferred', text)

func _set_text_deferred(value):
	$SubViewport/DebugLabelText.text = value
	call_deferred('_update_once')

func _set_small_font_deferred(value):
	$SubViewport/DebugLabelText.small_font = value
	call_deferred('_update_once')

func _update_once():
	if _updating:
		return
	_updating = true;
	var tree = get_tree()
	if tree:
		await tree.idle_frame
	$SubViewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	_updating = false


func _on_Area_body_entered(body):
	if body == world_mgr.player:
		bodies.append(body)
		visible = len(bodies)

func _on_Area_body_exited(body):
	bodies.erase(body)
	visible = len(bodies)
