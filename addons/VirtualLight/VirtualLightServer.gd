extends Reference


const _instance = {}

static func instance() -> Server:
	if !'instance' in _instance:
		_instance.instance = Server.new()
	return _instance.instance

class Server:
	signal light_toggled(msec)

	var _visibility_queue := []

	func remove(light):
		_visibility_queue.erase(light)

	func sync_visible(light):
		var running = len(_visibility_queue) > 0
		_visibility_queue.erase(light)
		_visibility_queue.append(light)

		if running:
			return
		if !running:
			while len(_visibility_queue) > 0:
				light = _visibility_queue[0]
				if !light || !is_instance_valid(light):
					_visibility_queue.erase(light)
					continue
				if light.get_tree():
					yield(light.get_tree(), 'idle_frame')
				_visibility_queue.erase(light)

				if !light || !is_instance_valid(light):
					continue
				if light.is_inside_tree() && 'target' in light && light.target && light.target.is_inside_tree():
					var start = OS.get_ticks_msec()
					var target = light.target
					var visible = light.is_visible_in_tree()
					target.visible = visible
					assert(target.is_visible_in_tree() == visible)
					emit_signal('light_toggled', OS.get_ticks_msec() - start)
