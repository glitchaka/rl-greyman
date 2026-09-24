class_name DungeonTerrainPainter
extends RefCounted

# Atlas coordinates are native pixels. A wall has a roof/coping and a 24 px
# vertical face; neither is a scaled floor tile. Logical collision stays 16 px.
const TILE := 16
const STONE := preload("res://assets/PNG/walls_floor.png")
const DOORS := preload("res://assets/PNG/doors_lever_chest_animation.png")
const FLAME := preload("res://assets/PNG/fire_animation.png")
const SANDSTONE := preload("res://assets/Dungen Tiles 2.png")
const CATACOMB := preload("res://assets/another tileset/1_MiniDungeon_Tileset1_A.png")
const CATACOMB_FLOOR := preload("res://assets/another tileset/1_MiniDungeon_Tileset_Background1.png")
var canvas: Node2D
var world: DungeonWorld
var visible_tiles: Dictionary
var center := Vector2.ZERO
var origin := Vector2(232, 136)
var time := 0.0

func _init(target: Node2D) -> void:
	canvas = target

func screen(p: Vector2i) -> Vector2:
	return ((Vector2(p) - center) * TILE + origin).floor()

func sprite(texture: Texture2D, p: Vector2, source: Rect2, tint := Color.WHITE) -> void:
	canvas.draw_texture_rect_region(texture, Rect2(p.floor(), source.size), source, tint)

func solid(p: Vector2i) -> bool:
	return world.tile(p) in [DungeonWorld.WALL, DungeonWorld.SECRET]

func shade(p: Vector2i) -> Color:
	if not visible_tiles.has(p):
		return Color(0.33, 0.35, 0.43)
	var strength := 1.0 - clampf(Vector2(p).distance_to(center) / 6.0, 0, 1) * 0.18
	return Color(strength, strength, strength)

func draw(game: Node2D) -> void:
	world = game.world
	visible_tiles = game.visible_tiles
	center = game.actor.visual
	time = game.actor.anim_time
	var walls: Array[Vector2i] = []
	var entrances: Array[Vector2i] = []
	for y in range(game.actor.pos.y - 11, game.actor.pos.y + 12):
		for x in range(game.actor.pos.x - 16, game.actor.pos.x + 17):
			var p := Vector2i(x, y)
			if not world.explored.has(p):
				continue
			if solid(p):
				walls.append(p)
			else:
				draw_floor(p)
				if world.tile(p) in [DungeonWorld.DOOR, DungeonWorld.OPEN]:
					entrances.append(p)
	for p in walls:
		draw_roof(p)
	for p in walls:
		if not solid(p + Vector2i.DOWN):
			draw_face(p)
	for p in entrances:
		draw_door(p)
	for p in walls:
		if has_torch(p) and visible_tiles.has(p):
			draw_torch(p)

func draw_floor(p: Vector2i) -> void:
	var north := solid(p + Vector2i.UP)
	var south := solid(p + Vector2i.DOWN)
	var west := solid(p + Vector2i.LEFT)
	var east := solid(p + Vector2i.RIGHT)
	var col := 0 if west else (32 if east else 16)
	var row := 80 if north else (112 if south else 96)
	var s := screen(p)
	var tint := shade(p)
	var theme := world.theme(p)
	var local := p - world.sector(p) * DungeonWorld.SIZE
	# A native stone threshold finishes a biome crossing inside a passage.
	# Room interiors can never be bisected by a palette boundary.
	if local.x in [0, DungeonWorld.SIZE - 1] or local.y in [0, DungeonWorld.SIZE - 1]:
		sprite(STONE, s, Rect2(160, 128, 16, 16), tint)
		return
	if theme == 1:
		var sx := 1 if west else (35 if east else 18)
		var sy := 18 if north else (52 if south else 35)
		sprite(SANDSTONE, s, Rect2(sx, sy, 16, 16), tint)
		return
	if theme == 2:
		sprite(CATACOMB_FLOOR, s, Rect2(24, 24, 16, 16), tint)
		return
	sprite(STONE, s, Rect2(col, row, 16, 16), tint)
	# Native alternate flagstones, in the same palette as the main floor.
	if not (north or south or west or east) and world.noise(p, 98) % 11 == 0:
		var variant := world.noise(p, 82) % 4
		sprite(STONE, s, Rect2(176 + variant % 2 * 16, 336 + variant / 2 * 16, 16, 16), tint)
	if north:
		canvas.draw_rect(Rect2(s, Vector2(16, 3)), Color(0.06, 0.055, 0.09, 0.24))
	if west:
		canvas.draw_rect(Rect2(s, Vector2(2, 16)), Color(0.06, 0.055, 0.09, 0.15))

func draw_face(p: Vector2i) -> void:
	var s := screen(p)
	var tint := shade(p)
	var left_edge := not solid(p + Vector2i.LEFT)
	var right_edge := not solid(p + Vector2i.RIGHT)
	var col := 0 if left_edge else (32 if right_edge else 16)
	# A raised face may extend upward ONLY into another solid tile. A thin
	# partition must fit its actual collision footprint, never neighbouring floor.
	var raised := solid(p + Vector2i.UP)
	var bounds := face_bounds(p)
	var top := s + bounds.position - Vector2(p * TILE) + Vector2(0, 6)
	var height := int(bounds.size.y) - 6
	match world.theme(p):
		0:
			sprite(STONE, top, Rect2(col, 72 - height, 16, height), tint)
			sprite(STONE, top - Vector2(0, 6), Rect2(col, 40, 16, 6), tint)
		1:
			sprite(SANDSTONE, top, Rect2(69, 1, 16, mini(height, 16)), tint)
			if raised:
				sprite(SANDSTONE, top + Vector2(0, 16), Rect2(69, 9, 16, 8), tint)
		2:
			sprite(CATACOMB, top, Rect2(16, 0, 16, mini(height, 16)), tint)
			if raised:
				sprite(CATACOMB, top + Vector2(0, 16), Rect2(16, 8, 16, 8), tint)
	canvas.draw_rect(Rect2(s + Vector2(0, 15), Vector2(16, 3)), Color(0.025, 0.02, 0.05, 0.3))

func face_bounds(p: Vector2i) -> Rect2:
	var raised := solid(p + Vector2i.UP)
	return Rect2(Vector2(p * TILE) + Vector2(0, -14 if raised else 0), Vector2(16, 30 if raised else 16))

func draw_roof(p: Vector2i) -> void:
	var n := not solid(p + Vector2i.UP)
	var s := not solid(p + Vector2i.DOWN)
	var w := not solid(p + Vector2i.LEFT)
	var e := not solid(p + Vector2i.RIGHT)
	var dest := screen(p)
	var tint := shade(p)
	# Dark wall core bounded by the actual coping sprites from the atlas.
	canvas.draw_rect(Rect2(dest, Vector2(16, 16)), Color("1c1c29") * tint)
	var col := 0 if w else (32 if e else 16)
	var row := 0 if n else (32 if s else 16)
	if world.theme(p) == 1:
		canvas.draw_rect(Rect2(dest, Vector2(16, 16)), Color("574c3d") * tint)
		var sx := 52 + (col / 16) * 17
		var sy := 1 + (row / 16) * 17
		sprite(SANDSTONE, dest, Rect2(sx, sy, 16, 16), tint)
		return
	if world.theme(p) == 2:
		sprite(CATACOMB, dest, Rect2(col, row + 16, 16, 16), tint)
		return
	sprite(STONE, dest, Rect2(col, row, 16, 16), tint)
	if w and e:
		sprite(STONE, dest + Vector2(8, 0), Rect2(40, row, 8, 16), tint)
	if n and s:
		sprite(STONE, dest + Vector2(0, 8), Rect2(col, 40, 16, 8), tint)
	# Inner turns use the actual corner quadrants, never a full isolated wall
	# tile that would create a stone spur outside the connected outline.
	if not (n or s or w or e):
		for offset in [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]:
			if not solid(p + offset):
				var target := Vector2(8 if offset.x > 0 else 0, 8 if offset.y > 0 else 0)
				var source := Vector2(40 if offset.x > 0 else 0, 40 if offset.y > 0 else 0)
				sprite(STONE, dest + target, Rect2(source, Vector2(8, 8)), tint)

func draw_door(p: Vector2i) -> void:
	var open := world.tile(p) == DungeonWorld.OPEN
	if solid(p + Vector2i.UP) and solid(p + Vector2i.DOWN):
		# A side-facing secret entrance is a narrow leaf across a horizontal
		# passage, not a front-facing arch floating over floor.
		if not open:
			sprite(DOORS, screen(p) + Vector2(6, 0), Rect2(14, 40, 4, 16), shade(p))
		return
	if world.tile(p + Vector2i.LEFT) in [DungeonWorld.DOOR, DungeonWorld.OPEN]:
		return
	var paired := world.tile(p + Vector2i.RIGHT) in [DungeonWorld.DOOR, DungeonWorld.OPEN]
	var position := screen(p) - Vector2(0 if paired else 8, 16)
	if world.theme(p) == 1:
		sprite(SANDSTONE, position, Rect2(154, 273 if open else 137, 32, 32), shade(p))
		return
	if world.theme(p) == 2:
		var tint := shade(p)
		var width := 32 if paired else 16
		var base := screen(p) - Vector2(0, 16)
		if not open:
			sprite(CATACOMB, base, Rect2(48, 16, 16, 32), tint)
			if paired:
				sprite(CATACOMB, base + Vector2(16, 0), Rect2(48, 16, 16, 32), tint)
		else:
			sprite(CATACOMB, base, Rect2(0, 16, 4, 32), tint)
			sprite(CATACOMB, base + Vector2(width - 4, 0), Rect2(44, 16, 4, 32), tint)
		return
	# Full 32x32 animation frame, including both jambs and the arch.
	sprite(DOORS, position, Rect2(128 if open else 0, 32, 32, 32), shade(p))

func has_torch(p: Vector2i) -> bool:
	return solid(p) and not solid(p + Vector2i.DOWN) and (world.noise(p, 51) % 5 == 0 or p in [Vector2i(13, 11), Vector2i(19, 11)])

func draw_torch(p: Vector2i) -> void:
	if not solid(p + Vector2i.UP):
		return
	var s := screen(p)
	# Native animated flame and brazier, with a small pixel-stepped light halo.
	for i in range(3, 0, -1):
		var radius := 7 + i * 3
		canvas.draw_rect(Rect2(s + Vector2(8 - radius, -4 - radius), Vector2(radius * 2, radius * 2)), Color(0.95, 0.60, 0.23, 0.016))
	var frame := int(time * 7 + p.x) % 6
	sprite(FLAME, s + Vector2(0, -14), Rect2(8, frame * 48 + 8, 16, 32))
