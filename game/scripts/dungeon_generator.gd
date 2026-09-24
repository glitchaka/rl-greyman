class_name DungeonGenerator
extends RefCounted

const SIZE := 48
const REVISION := 2
const WALL := 0
const FLOOR := 1
const DOOR := 2
const SECRET := 3
var seed_value: int

func _init(value: int) -> void:
	seed_value = value

func noise(p: Vector2i, salt: int = 0) -> int:
	return absi(hash("%s:%s:%s:%s" % [seed_value, p.x, p.y, salt]))

func floor_at(data: PackedByteArray, p: Vector2i) -> void:
	if p.x >= 0 and p.y >= 0 and p.x < SIZE and p.y < SIZE:
		data[p.y * SIZE + p.x] = FLOOR

func room(data: PackedByteArray, area: Rect2i) -> void:
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			floor_at(data, Vector2i(x, y))

func hall(data: PackedByteArray, a: Vector2i, b: Vector2i) -> void:
	# Two-tile passages have room for both floor rims. Turns are full 2x2
	# landings; corridor edges never collapse into a one-pixel strip.
	var p := a
	while true:
		room(data, Rect2i(p, Vector2i(2, 2)))
		if p == b:
			break
		if p.x != b.x:
			p.x += signi(b.x - p.x)
		else:
			p.y += signi(b.y - p.y)

func connect_rooms(data: PackedByteArray, a: Rect2i, b: Rect2i) -> void:
	var ac := a.get_center()
	var bc := b.get_center()
	if absi(ac.y - bc.y) > absi(ac.x - bc.x):
		var midway := (ac.y + bc.y) / 2
		hall(data, ac, Vector2i(ac.x, midway))
		hall(data, Vector2i(ac.x, midway), Vector2i(bc.x, midway))
		hall(data, Vector2i(bc.x, midway), bc)
		var bottom: Rect2i = b if bc.y > ac.y else a
		var door := Vector2i(bottom.get_center().x, bottom.position.y - 1)
		data[door.y * SIZE + door.x] = DOOR
		data[door.y * SIZE + door.x + 1] = DOOR
	else:
		var midway := (ac.x + bc.x) / 2
		hall(data, ac, Vector2i(midway, ac.y))
		hall(data, Vector2i(midway, ac.y), Vector2i(midway, bc.y))
		hall(data, Vector2i(midway, bc.y), bc)

func build(c: Vector2i) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = noise(c)
	var data := PackedByteArray()
	data.resize(SIZE * SIZE)
	var rooms: Array[Rect2i] = []
	for offset in [Vector2i(4, 5), Vector2i(29, 5), Vector2i(4, 29), Vector2i(29, 29)]:
		rooms.append(Rect2i(offset + Vector2i(rng.randi_range(0, 2), rng.randi_range(0, 2)), Vector2i(rng.randi_range(10, 13), rng.randi_range(8, 11))))
	if c == Vector2i.ZERO:
		rooms[0] = Rect2i(11, 12, 11, 9)
	for i in range(rooms.size()):
		var area := rooms[i]
		room(data, area)
		# Stepped room silhouettes leave structural returns, like the atlas
		# examples, while keeping the middle of each wall available for portals.
		if i == 0 or rng.randi_range(0, 1) == 1:
			for y in range(area.position.y, area.position.y + 2):
				for x in range(area.end.x - 2, area.end.x):
					data[y * SIZE + x] = WALL
	# A room graph, not five spokes cut across the same central chamber.
	# Remove at most one edge from a cycle: every room is always connected.
	var links := [Vector2i(0, 1), Vector2i(1, 3), Vector2i(3, 2), Vector2i(2, 0)]
	var skip := rng.randi_range(0, 4)
	for i in range(links.size()):
		if i != skip:
			connect_rooms(data, rooms[links[i].x], rooms[links[i].y])
	# Shared edge keys guarantee matching portals even when generated in a
	# different order. All portals enter a room through a corridor vestibule.
	var west := 11 + noise(c, 11) % 5
	var east := 11 + noise(c + Vector2i.RIGHT, 11) % 5
	var north := 11 + noise(c, 23) % 5
	var south := 11 + noise(c + Vector2i.DOWN, 23) % 5
	hall(data, Vector2i(0, west), Vector2i(rooms[0].get_center().x, west))
	hall(data, Vector2i(rooms[0].get_center().x, west), rooms[0].get_center())
	hall(data, rooms[1].get_center(), Vector2i(rooms[1].get_center().x, east))
	hall(data, Vector2i(rooms[1].get_center().x, east), Vector2i(SIZE - 1, east))
	hall(data, Vector2i(north, 0), Vector2i(north, rooms[0].get_center().y))
	hall(data, Vector2i(north, rooms[0].get_center().y), rooms[0].get_center())
	hall(data, rooms[2].get_center(), Vector2i(south, rooms[2].get_center().y))
	hall(data, Vector2i(south, rooms[2].get_center().y), Vector2i(south, SIZE - 1))
	# Sealed side chamber in the unused middle strip, with a searchable door.
	var secret := Rect2i(2, 22, 5, 4)
	room(data, secret)
	var secret_door := Vector2i(7, 23)
	data[secret_door.y * SIZE + secret_door.x] = SECRET
	hall(data, Vector2i(8, 23), Vector2i(8, rooms[2].get_center().y))
	hall(data, Vector2i(8, rooms[2].get_center().y), rooms[2].get_center())
	validate_doors(data)
	var entities: Array = []
	var origin := c * SIZE
	entities.append(entity("chest", origin + secret.position + Vector2i(1, 1), "cofre antiguo"))
	for i in range(rooms.size()):
		var area := rooms[i]
		var nw := origin + area.position
		var se := origin + area.end - Vector2i.ONE
		entities.append(entity("chest", nw + Vector2i(2, 0), "cofre de provisiones" if c == Vector2i.ZERO and i == 0 else "cofre"))
		entities.append(entity("barrel", se - Vector2i(0, 1), "barril"))
		entities.append(entity("barrel", se - Vector2i(1, 0), "barril"))
		entities.append(entity("urn", nw + Vector2i(0, area.size.y - 2), "urna"))
		entities.append(entity("crate", nw + Vector2i(1, 2), "cajón"))
		entities.append(entity("item", nw + Vector2i(3, 1), "oro"))
		if c != Vector2i.ZERO or i != 0:
			var mob := entity("mob", origin + area.get_center() + Vector2i(2, 2), ["rata", "slime", "esqueleto"][rng.randi_range(0, 2)])
			mob.hp = 12 if mob.name == "esqueleto" else 8
			mob.clock = rng.randf_range(0.3, 1.2)
			entities.append(mob)
			entities.append(entity("item", origin + area.get_center(), ["espada", "pan", "poción", "escudo", "casco"][rng.randi_range(0, 4)]))
	entities.append(entity("fountain", origin + rooms[3].position + Vector2i(5, 1), "fuente"))
	entities.append(entity("trap", origin + rooms[2].get_center() + Vector2i(0, 2), "trampa"))
	if c == Vector2i.ZERO:
		entities.append(entity("item", Vector2i(15, 17), "pico"))
	return {"tiles": data, "rooms": rooms, "secret_door": origin + secret_door, "entities": entities}

func validate_doors(data: PackedByteArray) -> void:
	for y in range(1, SIZE - 1):
		for x in range(1, SIZE - 2):
			var i := y * SIZE + x
			if data[i] != DOOR or data[i - 1] == DOOR:
				continue
			var valid := data[i + 1] == DOOR and data[i - 1] == WALL and data[i + 2] == WALL
			valid = valid and data[i - SIZE] == FLOOR and data[i + SIZE] == FLOOR
			valid = valid and data[i + 1 - SIZE] == FLOOR and data[i + 1 + SIZE] == FLOOR
			if not valid:
				data[i] = FLOOR
				if data[i + 1] == DOOR:
					data[i + 1] = FLOOR

static func entity(kind: String, p: Vector2i, label: String) -> Dictionary:
	return {"kind": kind, "pos": p, "name": label, "hp": 6, "used": false, "clock": 0.0}
