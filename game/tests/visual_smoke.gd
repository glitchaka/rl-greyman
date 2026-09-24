extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func capture(game: Node, filename: String) -> void:
	game.view.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png("res://tests/screenshots/" + filename + ".png")
	assert(result == OK, "Screenshot must actually save: " + filename)

func run() -> void:
	var scene := load("res://main.tscn") as PackedScene
	var game = scene.instantiate()
	root.add_child(game)
	game.start(true, 42)
	game.set_process(false)
	game.auto_enabled = false
	await capture(game, "expedition_v2")
	for item in ["pico", "casco", "soga", "ración"]:
		game.actor.inventory.add(item)
	game.inventory_open = true
	await capture(game, "inventory")
	game.inventory_open = false
	game.help_open = true
	await capture(game, "guide")
	game.help_open = false
	for theme in range(3):
		var c := Vector2i(theme, 0)
		game.world.generate(c)
		game.actor.pos = c * DungeonWorld.SIZE + game.world.layouts[c].rooms[0].get_center()
		game.actor.visual = Vector2(game.actor.pos)
		game.world.maintain(game.actor.pos)
		game.visible_tiles = game.world.field_of_view(game.actor.pos)
		await capture(game, "zone_%d" % theme)
		var door := Vector2i(-1, -1)
		for y in range(DungeonWorld.SIZE):
			for x in range(DungeonWorld.SIZE):
				var p := c * DungeonWorld.SIZE + Vector2i(x, y)
				if game.world.tile(p) == DungeonWorld.DOOR and game.world.tile(p + Vector2i.LEFT) != DungeonWorld.DOOR:
					door = p
		if door != Vector2i(-1, -1):
			game.actor.pos = door + Vector2i(0, 2)
			game.actor.visual = Vector2(game.actor.pos)
			game.actor.facing = Vector2i.UP
			game.visible_tiles = game.world.field_of_view(game.actor.pos)
			await capture(game, "door_%d" % theme)
		for y in range(-1, DungeonWorld.SIZE + 1):
			for x in range(-1, DungeonWorld.SIZE + 1):
				var p := c * DungeonWorld.SIZE + Vector2i(x, y)
				game.world.explored[p] = true
				game.visible_tiles[p] = true
		game.actor.pos = c * DungeonWorld.SIZE + game.world.layouts[c].rooms[0].get_center()
		game.actor.visual = Vector2(game.actor.pos)
		await capture(game, "layout_%d" % theme)
	print("Visual smoke completed: initial FOV, inventory, guide, three biomes and their doors")
	quit()