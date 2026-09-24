extends SceneTree

var checks := 0
var failures := 0

func verify(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + description)

func _initialize() -> void:
	test_generation()
	test_vision()
	test_greyman_directions()
	test_wall_collision()
	test_equipment_and_actions()
	test_autonomy()
	test_persistence()
	test_save_migration()
	print("Dungeon tests: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func test_greyman_directions() -> void:
	var actor := Adventurer.new()
	var directions := [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]
	for i in range(4):
		actor.facing = directions[i]
		actor.attack_clock = 0
		actor.moving = false
		verify(actor.sprite_region().position.y == i * 16, "Correct idle direction")
		actor.moving = true
		verify(actor.sprite_region().position.y == (i + 4) * 16, "Correct walking direction")
		actor.attack_clock = 0.3
		verify(actor.sprite_region().position.y == (i + 8) * 16, "Correct combat direction")

func test_wall_collision() -> void:
	var world := DungeonWorld.new(42)
	var actor := Adventurer.new()
	var actions := DungeonInteractions.new(world, actor)
	for direction in AutoExplorer.DIRECTIONS:
		actor.pos = Vector2i(16, 16)
		actor.visual = Vector2(actor.pos)
		actor.step_clock = 0
		world.set_tile(actor.pos + direction, DungeonWorld.WALL)
		verify(not actions.move(direction), "Wall blocks movement from " + str(direction))
		verify(actor.pos == Vector2i(16, 16), "Actor never enters solid tile")
		world.set_tile(actor.pos + direction, DungeonWorld.FLOOR)
	var canvas := Node2D.new()
	var painter := DungeonTerrainPainter.new(canvas)
	painter.world = world
	for y in range(8, 25):
		for x in range(8, 25):
			var tile := Vector2i(x, y)
			if not painter.solid(tile) or painter.solid(tile + Vector2i.DOWN):
				continue
			var footprint := painter.face_bounds(tile)
			for pixel_y in range(int(footprint.position.y), int(footprint.end.y)):
				var occupied := Vector2i(x, floori(float(pixel_y) / 16))
				verify(not world.walkable(occupied), "Visible wall never occupies traversable floor")
	canvas.free()

func test_generation() -> void:
	for seed_number in [1, 42, 83127, 999999]:
		var world := DungeonWorld.new(seed_number)
		for c in [Vector2i.ZERO, Vector2i(-1, -1), Vector2i(12, -7)]:
			world.generate(c)
			for entity in world.entities[c]:
				verify(world.walkable(entity.pos), "Every furnishing and enemy starts on floor")
			for y in range(1, DungeonWorld.SIZE - 1):
				for x in range(1, DungeonWorld.SIZE - 2):
					var p: Vector2i = c * DungeonWorld.SIZE + Vector2i(x, y)
					if world.tile(p) == DungeonWorld.DOOR and world.tile(p + Vector2i.LEFT) != DungeonWorld.DOOR:
						verify(world.tile(p + Vector2i.RIGHT) == DungeonWorld.DOOR, "Door spans full passage")
						verify(world.tile(p + Vector2i.LEFT) == DungeonWorld.WALL and world.tile(p + Vector2i(2, 0)) == DungeonWorld.WALL, "Door has two solid jambs")
						verify(world.walkable(p + Vector2i.UP) and world.walkable(p + Vector2i.DOWN), "Door connects two accessible spaces")
			var east_connection := false
			var south_connection := false
			for i in range(DungeonWorld.SIZE):
				var east: Vector2i = c * DungeonWorld.SIZE + Vector2i(DungeonWorld.SIZE - 1, i)
				if world.walkable(east):
					verify(world.walkable(east + Vector2i.RIGHT), "Shared east boundary")
					east_connection = true
				var south: Vector2i = c * DungeonWorld.SIZE + Vector2i(i, DungeonWorld.SIZE - 1)
				if world.walkable(south):
					verify(world.walkable(south + Vector2i.DOWN), "Shared south boundary")
					south_connection = true
			verify(east_connection and south_connection, "Sector has exits")
			var origin: Vector2i = c * DungeonWorld.SIZE
			var queue: Array[Vector2i] = [origin + world.layouts[c].rooms[0].get_center()]
			var seen := {queue[0]: true}
			var idx := 0
			while idx < queue.size():
				var p := queue[idx]
				idx += 1
				for dir in AutoExplorer.DIRECTIONS:
					var n: Vector2i = p + dir
					if world.sector(n) == c and not seen.has(n) and world.tile(n) in [DungeonWorld.FLOOR, DungeonWorld.DOOR]:
						seen[n] = true
						queue.append(n)
			for area: Rect2i in world.layouts[c].rooms:
				verify(seen.has(origin + area.get_center()), "All normal rooms connected")
			verify(not seen.has(origin + Vector2i(4, 23)), "Secret chamber starts sealed")
		var reference: PackedByteArray = world.chunks[Vector2i.ZERO].duplicate()
		world.maintain(Vector2i(6400, -6400))
		verify(world.chunks.size() <= 25, "Bounded resident terrain")
		world.generate(Vector2i.ZERO)
		verify(reference == world.chunks[Vector2i.ZERO], "Deterministic regeneration")

func test_vision() -> void:
	var world := DungeonWorld.new(1)
	var origin := Vector2i(16, 16)
	for y in range(8, 25):
		for x in range(8, 25):
			world.set_tile(Vector2i(x, y), DungeonWorld.FLOOR)
	var fov := world.field_of_view(origin)
	verify(fov.has(origin + Vector2i(6, 0)), "Vision reaches six tiles")
	verify(not fov.has(origin + Vector2i(7, 0)), "Vision never reaches seven tiles")
	verify(not fov.has(origin + Vector2i(5, 5)), "Circular vision radius")
	world.set_tile(origin + Vector2i.RIGHT, DungeonWorld.WALL)
	fov = world.field_of_view(origin)
	verify(fov.has(origin + Vector2i.RIGHT), "Occluder itself visible")
	verify(not fov.has(origin + Vector2i(2, 0)), "Wall blocks vision")
	world.set_tile(origin + Vector2i.DOWN, DungeonWorld.WALL)
	verify(not world.clear_line(origin, origin + Vector2i(1, 1)), "No diagonal corner leaks")
	verify(world.explored.has(origin + Vector2i(6, 0)), "Explored memory retained")

func test_equipment_and_actions() -> void:
	var actor := Adventurer.new()
	var world := DungeonWorld.new(42)
	world.generate(Vector2i.ZERO)
	var actions := DungeonInteractions.new(world, actor)
	var inv := actor.inventory
	for name in DungeonInventory.CATALOG:
		inv.add(name)
		inv.selected = inv.items.size() - 1
		for slot in range(4):
			inv.active_slot = slot
			inv.equip()
			verify(inv.equipped(DungeonInventory.SLOT_NAMES[slot]) == name, "Every item fits every slot")
	for name in ["soga", "pan", "ración", "casco", "piedra", "espada"]:
		inv.selected = inv.items.find(name)
		inv.active_slot = 0
		inv.equip()
		var victim := world.make_entity("mob", actor.pos + actor.facing, "prueba")
		victim.hp = 100
		world.entities[Vector2i.ZERO].append(victim)
		actor.attack_clock = 0
		actions.attack()
		verify(victim.hp == 100 - inv.damage(), "Damage matches object: " + name)
		if name in ["soga", "pan", "ración"]:
			verify(victim.hp == 100, "Soft objects deal absolutely zero damage")
		world.remove_entity(victim)
	inv.selected = inv.items.find("pico")
	inv.active_slot = 0
	inv.equip()
	actor.pos = Vector2i(8, 23)
	actor.facing = Vector2i.LEFT
	for i in range(3):
		actor.attack_clock = 0
		actions.attack()
	verify(world.walkable(Vector2i(7, 23)), "Pickaxe breaks secret wall")
	verify(world.walkable(Vector2i(6, 23)), "Excavation reaches secret room")
	world.set_tile(Vector2i(7, 23), DungeonWorld.SECRET)
	actions.search()
	verify(world.tile(Vector2i(7, 23)) == DungeonWorld.DOOR, "Search reveals hidden door")
	# First interaction collects the stone dropped while mining.
	actions.interact()
	actions.interact()
	verify(world.tile(Vector2i(7, 23)) == DungeonWorld.OPEN, "Revealed door can open")
	actions.interact()
	verify(world.tile(Vector2i(7, 23)) == DungeonWorld.DOOR, "Door closes after clearing threshold")

func test_autonomy() -> void:
	var actor := Adventurer.new()
	actor.tick(4.99)
	verify(not actor.autonomous, "Idle before five seconds")
	actor.tick(0.02)
	verify(actor.autonomous, "Autonomy after five seconds")
	actor.controlled()
	verify(not actor.autonomous and actor.idle_time == 0, "Input immediately cancels autonomy")
	var world := DungeonWorld.new(42)
	world.field_of_view(actor.pos)
	var explorer := AutoExplorer.new()
	explorer.find_route(actor, world)
	verify(not actor.auto_path.is_empty(), "Autonomy finds a route")
	for p in actor.auto_path:
		verify(world.explored.has(p) and world.walkable(p), "Auto route only uses explored walkable tiles")

func test_persistence() -> void:
	var store := DungeonSaveStore.new()
	# Use a dedicated save path; never touch the player's expedition.
	store.path = "user://test_expedition.save"
	var world := DungeonWorld.new(731)
	var actor := Adventurer.new()
	world.maintain(actor.pos)
	world.field_of_view(actor.pos)
	world.set_tile(Vector2i(7, 23), DungeonWorld.FLOOR)
	actor.inventory.add("soga")
	actor.inventory.equip()
	verify(store.save_game(world, actor), "Atomic save succeeds")
	var data := store.load_game()
	verify(data.get("seed") == 731, "Seed survives save")
	verify(data.changes[Vector2i(7, 23)] == DungeonWorld.FLOOR, "Excavation persists")
	verify(data.items[0] == "soga" and data.equipment.Mano == 0, "Equipment persists")
	var loaded := DungeonWorld.new(data.seed)
	loaded.changes = data.changes
	loaded.sleeping = data.entities
	loaded.generate(Vector2i.ZERO)
	verify(loaded.entities[Vector2i.ZERO].size() == world.entities[Vector2i.ZERO].size(), "Entities reload without duplication")
	DirAccess.remove_absolute(store.path)

func test_save_migration() -> void:
	var store := DungeonSaveStore.new()
	store.path = "user://test_layout_migration.save"
	var world := DungeonWorld.new(831)
	var actor := Adventurer.new()
	actor.inventory.add("casco")
	actor.inventory.equip()
	actor.pos = Vector2i(250, -80)
	world.set_tile(Vector2i(5, 5), DungeonWorld.FLOOR)
	store.save_game(world, actor)
	var old := store.load_game()
	old["terrain_revision"] = 1
	var file := FileAccess.open(store.path, FileAccess.WRITE)
	file.store_var(old)
	file.close()
	var migrated := store.load_game()
	verify(FileAccess.file_exists(store.path + ".before-layout-2"), "Previous layout backed up")
	verify(migrated.pos == Vector2i(16, 16) and migrated.changes.is_empty(), "Old coordinates never corrupt new geometry")
	verify(migrated.items == ["casco"] and migrated.equipment.Mano == 0, "Migration preserves items and equipment")
	var archive := FileAccess.open(store.path + ".before-layout-2", FileAccess.READ)
	var archived: Dictionary = archive.get_var(false)
	archive.close()
	verify(archived.pos == Vector2i(250, -80) and not archived.changes.is_empty(), "Backup retains original position and excavation")
	DirAccess.remove_absolute(store.path)
	DirAccess.remove_absolute(store.path + ".before-layout-2")
