class_name DungeonSaveStore
extends RefCounted

var path := "user://expedition.save"

func save_game(world: DungeonWorld, actor: Adventurer) -> bool:
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return false
	var entity_state := world.sleeping.duplicate(true)
	for c in world.entities:
		entity_state[c] = world.entities[c]
	file.store_var({"version": 2, "terrain_revision": DungeonGenerator.REVISION, "seed": world.seed_value, "changes": world.changes,
		"explored": world.explored, "entities": entity_state, "pos": actor.pos,
		"hp": actor.hp, "hunger": actor.hunger, "items": actor.inventory.items,
		"gold_count": actor.inventory.gold_count, "equipment": actor.inventory.equipment, "visits": actor.visits,
		"progression": actor.progression.serialize(), "capacity": actor.inventory.capacity})
	file.close()
	return DirAccess.rename_absolute(path + ".tmp", path) == OK

func load_game() -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var data = file.get_var(false)
	file.close()
	if not data is Dictionary:
		return {}
	var save_version := int(data.get("version", 1))
	if save_version not in [1, 2]:
		return {}
	if save_version == 1:
		# Version 1 stored satiety: 100 meant fully fed. Version 2 stores
		# actual hunger: 0 means fed and 100 means starving.
		data["hunger"] = 100.0 - clampf(float(data.get("hunger", 100.0)), 0.0, 100.0)
		data["version"] = 2
	if data.get("terrain_revision", 1) != DungeonGenerator.REVISION:
		# Preserve the entire previous expedition before moving its character to
		# the revised layout. Old coordinates cannot be applied to new geometry.
		var backup := path + ".before-layout-2"
		if not FileAccess.file_exists(backup):
			if DirAccess.copy_absolute(path, backup) != OK:
				push_error("Could not preserve the previous dungeon save.")
				return {}
		data.changes = {}
		data.explored = {}
		data.entities = {}
		data.visits = {}
		data.pos = Vector2i(16, 16)
		data["layout_migrated"] = true
	return data
