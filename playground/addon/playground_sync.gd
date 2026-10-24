@tool
extends EditorPlugin
## Opening the playground straight from the Godot editor skips
## run_playground.bat, so the copy of the game goes stale. This runs sync.py
## before every Play, then rescans so the editor sees what changed.


func _build() -> bool:
	var script := ProjectSettings.globalize_path("res://").path_join("../sync.py").simplify_path()
	var output: Array = []
	var code := OS.execute("python", [script], output, true)
	print("".join(output).strip_edges())
	if code != 0:
		push_warning("Playground sync failed (is Python on PATH?). Running the last synced copy.")
	EditorInterface.get_resource_filesystem().scan()
	return true
