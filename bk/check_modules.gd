extends SceneTree
# Smoke test run by CI: fails if the engine was built without the modules we depend on.

const REQUIRED_CLASSES := [
	"VoxelTerrain",      # Voxel Tools: smooth/blocky terrain node
	"VoxelLodTerrain",   # Voxel Tools: large terrain with LOD
	"VoxelTool",         # Voxel Tools: runtime edit API (craters, trenches)
	"VoxelMesherTransvoxel",
	"HeightMapShape3D",  # rut layer collision
	"MultiplayerSynchronizer",
]

func _init() -> void:
	var missing := []
	for c in REQUIRED_CLASSES:
		if not ClassDB.class_exists(c):
			missing.append(c)
	if not ProjectSettings.has_setting("physics/3d/physics_engine"):
		missing.append("physics/3d/physics_engine setting")
	print("Engine: ", Engine.get_version_info().string)
	if missing.is_empty():
		print("OK: all required classes present")
		quit(0)
	else:
		printerr("MISSING: ", ", ".join(missing))
		quit(1)
