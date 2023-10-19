@tool
extends Control

@export var text: String = '': set = _set_text

func _set_text(value):
	text = value
	call_deferred('_set_text_deferred', value)

func _set_text_deferred(value):
	$Label.text = value
