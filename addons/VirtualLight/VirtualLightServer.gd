extends RefCounted


static var _instance: Server = null

static func get_instance() -> Server:
	if !_instance:
		_instance = Server.new()
	return _instance

class Server:
	signal light_toggled(msec)

	# Type is actually VirtualLight but that would be a dependency cycle
	var _visibility_queue: Array[Node3D] = []

	func remove(light: Node3D):
		_visibility_queue.erase(light)

	func sync_visible(light: Node3D):
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
					await light.get_tree().process_frame
				_visibility_queue.erase(light)

				if !light || !is_instance_valid(light):
					continue
				if light && is_instance_valid(light) && light.is_inside_tree() && \
					'target' in light && light.target && light.target.is_inside_tree():
					var start = Time.get_ticks_msec()
					var target = light.target
					var visible = light.is_visible_in_tree()
					target.visible = visible
					assert(target.is_visible_in_tree() == visible)
					emit_signal('light_toggled', Time.get_ticks_msec() - start)
