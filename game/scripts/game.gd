extends Node2D

const ProgressionScript = preload("res://scripts/progression.gd")

var world: DungeonWorld
var actor: Adventurer
var interactions: DungeonInteractions
var explorer := AutoExplorer.new()
var saves := DungeonSaveStore.new()
var view: DungeonView
var visible_tiles: Dictionary = {}
var messages: Array[String] = []
var particles: Array = []
var inventory_open := false
var help_open := false
var character_open := false
var character_selection := 0
var paused := false
var save_clock := 0.0
var survival_clock := 0.0
var auto_enabled := true
var last_fov_pos := Vector2i(2147483647, 2147483647)
var last_fov_revision := -1

func _ready() -> void:
	get_tree().auto_accept_quit = false
	DisplayServer.window_set_title("Dungeon Living — revisión 3")
	start(false)
	view = DungeonView.new()
	view.game = self
	add_child(view)

func start(fresh: bool, seed_override: int = -1) -> void:
	var data := {} if fresh else saves.load_game()
	world = DungeonWorld.new(seed_override if seed_override >= 0 else int(data.get("seed", randi())))
	actor = Adventurer.new()
	if not data.is_empty():
		world.changes = data.changes
		world.explored = data.explored
		world.sleeping = data.entities
		actor.pos = data.pos
		actor.visual = Vector2(actor.pos)
		actor.hp = data.hp
		actor.hunger = data.hunger
		actor.inventory.items = data.items
		actor.inventory.equipment = data.equipment
		actor.inventory.capacity = clampi(int(data.get("capacity", 16)), 16, DungeonInventory.MAX_CAPACITY)
		actor.progression.restore(data.get("progression", {}))
		actor.hp = clampi(actor.hp, 0, actor.max_hp())
		actor.visits = data.visits
	interactions = DungeonInteractions.new(world, actor)
	interactions.message.connect(log_message)
	interactions.effect.connect(add_effect)
	world.maintain(actor.pos)
	visible_tiles = world.field_of_view(actor.pos)
	messages.clear()
	particles.clear()
	inventory_open = false
	help_open = false
	character_open = false
	paused = false
	log_message("La expedición continúa." if not data.is_empty() else "Despiertas bajo la piedra. No estás solo.")
	log_message("[E] Recoger · [I] Equipo · [C] Atributos y mochila")
	if data.get("layout_migrated", false):
		log_message("Nueva mazmorra; equipo conservado y partida anterior respaldada.")

func log_message(text: String) -> void:
	messages.append(text)
	if messages.size() > 30:
		messages.pop_front()

func add_effect(p: Vector2i, text: String, color: Color) -> void:
	particles.append({"pos": p, "text": text, "color": color, "time": 0.8})

func _process(delta: float) -> void:
	if not paused and not inventory_open and not help_open and not character_open and actor.hp > 0:
		actor.tick(delta)
		var dir := input_direction()
		if dir != Vector2i.ZERO:
			actor.controlled()
			interactions.move(dir)
		elif auto_enabled and actor.autonomous and actor.step_clock <= 0:
			var danger := false
			for list in world.entities.values():
				for e in list:
					if e.kind == "mob" and visible_tiles.has(e.pos):
						danger = true
			if not danger:
				if not interactions.move(explorer.next_step(actor, world), true):
					actor.auto_path.clear()
			else:
				actor.auto_path.clear()
		if Input.is_physical_key_pressed(KEY_SPACE):
			actor.controlled()
			interactions.attack()
		world.maintain(actor.pos)
		if actor.pos != last_fov_pos or world.revision != last_fov_revision:
			visible_tiles = world.field_of_view(actor.pos)
			last_fov_pos = actor.pos
			last_fov_revision = world.revision
		interactions.tick_enemies(delta, visible_tiles)
		survival_clock += delta
		if survival_clock > 8:
			survival_clock = 0
			if actor.hunger <= 0:
				interactions.hurt(1)
			elif actor.hunger > 65:
				actor.hp = mini(actor.max_hp(), actor.hp + 1)
		save_clock += delta
		if save_clock > 20:
			save_clock = 0
			saves.save_game(world, actor)
	for i in range(particles.size() - 1, -1, -1):
		particles[i].time -= delta
		if particles[i].time <= 0:
			particles.remove_at(i)
	if view:
		view.queue_redraw()

func input_direction() -> Vector2i:
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		return Vector2i.UP
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		return Vector2i.DOWN
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		return Vector2i.LEFT
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		return Vector2i.RIGHT
	return Vector2i.ZERO

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		actor.controlled()
		if inventory_open:
			view.inventory_click(get_global_mouse_position())
		elif character_open:
			view.character_click(get_global_mouse_position())
		return
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	actor.controlled()
	var key: int = event.physical_keycode
	if key == KEY_F1:
		help_open = not help_open
		inventory_open = false
		character_open = false
		return
	if key == KEY_ESCAPE:
		if help_open or inventory_open or character_open:
			help_open = false
			inventory_open = false
			character_open = false
		else:
			paused = not paused
		return
	if key == KEY_F5:
		log_message("Expedición guardada." if saves.save_game(world, actor) else "No se pudo guardar la expedición.")
		return
	if actor.hp <= 0:
		if key == KEY_R:
			start(true)
		return
	if key == KEY_I:
		inventory_open = not inventory_open
		help_open = false
		character_open = false
		return
	if key == KEY_C:
		character_open = not character_open
		inventory_open = false
		help_open = false
		return
	if paused or help_open:
		return
	if character_open:
		match key:
			KEY_UP, KEY_W: character_selection = maxi(0, character_selection - 1)
			KEY_DOWN, KEY_S: character_selection = mini(3, character_selection + 1)
			KEY_ENTER: upgrade_selected()
			KEY_1, KEY_2, KEY_3:
				character_selection = key - KEY_1
				upgrade_selected()
			KEY_B:
				character_selection = 3
				upgrade_selected()
		return
	if inventory_open:
		var inv := actor.inventory
		match key:
			KEY_UP, KEY_W:
				inv.selected = maxi(0, inv.selected - 1)
			KEY_DOWN, KEY_S:
				inv.selected = mini(maxi(0, inv.items.size() - 1), inv.selected + 1)
			KEY_RIGHT, KEY_PAGEDOWN:
				inv.selected = mini(maxi(0, inv.items.size() - 1), inv.selected + 16)
			KEY_LEFT, KEY_PAGEUP:
				inv.selected = maxi(0, inv.selected - 16)
			KEY_TAB:
				inv.active_slot = (inv.active_slot + 1) % 4
			KEY_ENTER:
				log_message(inv.equip())
			KEY_U:
				interactions.use_item()
			KEY_G:
				interactions.drop()
		return
	match key:
		KEY_E:
			interactions.interact()
		KEY_X:
			interactions.search()
		KEY_Q:
			auto_enabled = not auto_enabled
			log_message("Autonomía " + ("activada: tras 5 s sin control." if auto_enabled else "desactivada."))
		KEY_U:
			interactions.use_item()
	visible_tiles = world.field_of_view(actor.pos)

func upgrade_selected() -> void:
	if character_selection < 3:
		var attribute: String = ProgressionScript.ATTRIBUTES[character_selection]
		log_message(attribute + " +1." if actor.improve(attribute) else "Necesitas puntos de nivel. Lee manuales o gana XP.")
	else:
		log_message("Mochila ampliada a %d espacios." % actor.inventory.capacity if actor.buy_backpack_upgrade() else "No tienes monedas suficientes o la mochila está al máximo.")

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if world != null and actor != null:
			saves.save_game(world, actor)
		get_tree().quit()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		paused = true

