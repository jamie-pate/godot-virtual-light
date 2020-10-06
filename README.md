# Godot-Virtual-Light

<img src="icon.png" style="float:right">
An Plugin to work around performance limitations of the visual server when adding/removing complex geometry from a scene. See [this issue](https://github.com/godotengine/godot/issues/42563)
For Godot verision 3.x


## How-To
Download the Plugin and copy the addons directory into your projects folder

Enable the plugin in the project settings.

You should now be able to create `VirtualLight` nodes. When you run the project, all `VirtualLight` nodes will create `Light` instances at the root of the containing viewport, instead of inside the tree. By setting the `detail` value you can improve engine performance.

## Properties

* `light_type = VirtualLight.LightType.Omni`: create an OmniLight at the root of the viewport
* `light_type = VirtualLight.LightType.Spot`: create a SpotLight at the root of the viewport

* `detail = VirtualLight.Detail.NORMAL_DETAIL`: Create a light at the root of the viewport. When your geometry is removed from the scene the light will not be removed.
* `detail = VirtualLight.Detail.LOW_DETAIL`: Virtually disable shadows. The fact that the shadows are disabled will be hidden from scripts accessing the `VirtualLight` properties
* `detail = VirtualLight.Detail.LOWEST_DETAIL`: Remove the light from the scene completely for that wolfenstein 3d look. (also get double FPS!)

## Methods

* `copy_from(light: Light) -> void` Copy an existing light's properties so you can replace it dynamically.


## Debugging
Enable `show_debug_meshes` to show a labelled representation of a light and it's virtual light container in case they aren't actually matching up as expected
