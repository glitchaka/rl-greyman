class_name DungeonWorld
extends RefCounted

const SIZE := DungeonGenerator.SIZE
const WALL := 0
const FLOOR := 1
const DOOR := 2
const SECRET := 3
const OPEN := 4
const RESPAWN_TARGET_PER_SECTOR := 5
var seed_value: int = 0
var generator: DungeonGenerator
var layouts: Dictionary = {}
var chunks: Dictionary = {}
var changes: Dictionary = {}
var explored: Dictionary = {}
var sleeping: Dictionary = {}
var entities: Dictionary = {}
var revision := 0
var respawn_serial := 0

func _init(value: int = 0) -> void:
	seed_value = value
	generator = DungeonGenerator.new(value)

func sector(p: Vector2i) -> Vector2i:
	return Vector2i(floori(float(p.x) / SIZE), floori(float(p.y) / SIZE))

func theme(p: Vector2i) -> int:
	var c := sector(p)
	return posmod(c.x + c.y * 2, 3)

func noise(p: Vector2i, salt: int = 0) -> int:
	return absi(hash("%s:%s:%s:%s" % [seed_value, p.x, p.y, salt]))

func generate(c: Vector2i) -> void:
	if chunks.has(c):
		return
	var built := generator.build(c)
	chunks[c] = built.tiles
	layouts[c] = built
	if sleeping.has(c):
		entities[c] = sleeping[c]
		sleeping.erase(c)
	else:
		entities[c] = built.entities

func make_entity(kind: String, p: Vector2i, label: String) -> Dictionary:
	return DungeonGenerator.entity(kind, p, label)
func tile(p: Vector2i) -> int:
	if changes.has(p):
		return changes[p]
	var c := sector(p)
	generate(c)
	var local := p - c * SIZE
	return chunks[c][local.y * SIZE + local.x]

func set_tile(p: Vector2i, value: int) -> void:
	changes[p] = value
	revision += 1

func set_door(p: Vector2i, value: int) -> void:
	# A two-tile entrance is one door, both for interaction and collision.
	for cell in door_cells(p):
		set_tile(cell, value)

func door_cells(p: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = [p]
	for neighbour in [p + Vector2i.LEFT, p + Vector2i.RIGHT]:
		if tile(neighbour) in [DOOR, OPEN]:
			cells.append(neighbour)
	return cells

func walkable(p: Vector2i) -> bool:
	return tile(p) in [FLOOR, OPEN]

func opaque(p: Vector2i) -> bool:
	return tile(p) in [WALL, SECRET, DOOR]

func at(p: Vector2i) -> Array:
	generate(sector(p))
	var found: Array = []
	for list in entities.values():
		for e in list:
			if e.pos == p:
				found.append(e)
	return found

func remove_entity(e: Dictionary) -> void:
	for list in entities.values():
		if list.has(e):
			list.erase(e)
			return

func add_item(p: Vector2i, name: String) -> void:
	generate(sector(p))
	entities[sector(p)].append(make_entity("item", p, name))

func maintain(p: Vector2i) -> void:
	var c := sector(p)
	var transfers: Array = []
	for owner in entities:
		for entity in entities[owner]:
			var destination := sector(entity.pos)
			if destination != owner:
				transfers.append([owner, destination, entity])
	for transfer in transfers:
		generate(transfer[1])
		entities[transfer[0]].erase(transfer[2])
		entities[transfer[1]].append(transfer[2])
	for y in range(-1, 2):
		for x in range(-1, 2):
			generate(c + Vector2i(x, y))
	for key in chunks.keys():
		if absi(key.x - c.x) > 2 or absi(key.y - c.y) > 2:
			sleeping[key] = entities[key]
			entities.erase(key)
			chunks.erase(key)
			layouts.erase(key)

func respawn_enemy(player_pos: Vector2i, visible: Dictionary) -> bool:
	var loaded_sectors: Array = entities.keys()
	loaded_sectors.shuffle()
	for c in loaded_sectors:
		if not layouts.has(c):
			continue
		var mob_count := 0
		for e in entities[c]:
			if e.kind == "mob":
				mob_count += 1
		if mob_count >= RESPAWN_TARGET_PER_SECTOR:
			continue
		var candidates: Array[Vector2i] = []
		var rooms: Array = layouts[c].rooms
		for i in range(rooms.size()):
			if c == Vector2i.ZERO and i == 0:
				continue
			var room: Rect2i = rooms[i]
			var center := c * SIZE + room.get_center()
			candidates.append(center + Vector2i(-2, 1))
			candidates.append(center + Vector2i(2, -1))
			candidates.append(center + Vector2i(0, 2))
		candidates.shuffle()
		for p in candidates:
			if not explored.has(p) or visible.has(p):
				continue
			if (p - player_pos).length_squared() < 64 or not walkable(p):
				continue
			var blocked := false
			for e in at(p):
				if e.kind not in ["item", "trap"]:
					blocked = true
					break
			if blocked:
				continue
			respawn_serial += 1
			var names := ["rata", "slime", "esqueleto"]
			var name: String = names[noise(p, 700 + respawn_serial) % names.size()]
			var mob := make_entity("mob", p, name)
			mob.hp = 12 if name == "esqueleto" else 8
			mob.clock = 0.5 + float(noise(p, 800 + respawn_serial) % 70) / 100.0
			entities[c].append(mob)
			return true
	return false

func clear_line(a: Vector2i, b: Vector2i) -> bool:
	var delta := b - a
	var steps := maxi(absi(delta.x), absi(delta.y))
	for i in range(1, steps + 1):
		var p := Vector2i(roundi(a.x + float(delta.x) * i / steps), roundi(a.y + float(delta.y) * i / steps))
		if i < steps and opaque(p):
			return false
		# Block vision through the corner between two touching walls.
		var prev := Vector2i(roundi(a.x + float(delta.x) * (i - 1) / steps), roundi(a.y + float(delta.y) * (i - 1) / steps))
		if p.x != prev.x and p.y != prev.y and opaque(Vector2i(p.x, prev.y)) and opaque(Vector2i(prev.x, p.y)):
			return false
	return true

func field_of_view(p: Vector2i) -> Dictionary:
	var visible: Dictionary = {}
	for y in range(-6, 7):
		for x in range(-6, 7):
			var offset := Vector2i(x, y)
			if offset.length_squared() <= 36 and clear_line(p, p + offset):
				visible[p + offset] = true
				explored[p + offset] = true
	return visible
