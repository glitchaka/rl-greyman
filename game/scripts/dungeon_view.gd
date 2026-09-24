class_name DungeonView
extends Node2D

const INK := Color("1b1b27")
const PANEL := Color("131923")
const EDGE := Color("303947")
const TEXT := Color("ced1cc")
const MUTED := Color("77838a")
const GOLD := Color("d1ab6b")
const TEAL := Color("72b6a2")
var game: Node2D
var tiles := preload("res://assets/PNG/walls_floor.png")
var objects := preload("res://assets/PNG/Objects.png")
var doors := preload("res://assets/PNG/doors_lever_chest_animation.png")
var greyman := preload("res://assets/GreyMan-Idle-Run-Action.png")
var mini := preload("res://assets/Dungen Tiles 2.png")
var terrain := DungeonTerrainPainter.new(self)
var font: SystemFont

func _init() -> void:
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Consolas", "DejaVu Sans Mono", "monospace"])
	font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	font.hinting = TextServer.HINTING_NORMAL
	font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED

func label_at(p: Vector2, text: String, color: Color = TEXT, size: int = 10) -> void:
	draw_string(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func box(rect: Rect2, fill: Color = PANEL, border: Color = EDGE) -> void:
	draw_rect(rect, fill)
	draw_rect(rect, border, false, 1)

func screen(p: Vector2) -> Vector2:
	return (p - game.actor.visual) * 16 + Vector2(232, 136)

func tile_sprite(texture: Texture2D, p: Vector2, region: Rect2, tint: Color = Color.WHITE) -> void:
	draw_texture_rect_region(texture, Rect2(p.floor(), region.size), region, tint)

func _draw() -> void:
	if game == null:
		return
	draw_rect(Rect2(0, 0, 480, 300), INK)
	draw_world()
	draw_hud()
	if game.inventory_open:
		draw_inventory()
	if game.help_open:
		draw_help()
	if game.paused and not game.help_open and not game.inventory_open:
		box(Rect2(85, 100, 184, 58))
		label_at(Vector2(142, 121), "EN PAUSA", GOLD, 12)
		label_at(Vector2(105, 144), "Esc para continuar", MUTED)
	if game.actor.hp <= 0:
		box(Rect2(64, 95, 228, 76))
		label_at(Vector2(90, 117), "LA PIEDRA TE RECLAMA", GOLD, 13)
		label_at(Vector2(83, 138), "Tu expedición ha terminado.", MUTED)
		label_at(Vector2(83, 158), "[R] Nueva semilla y aventura", TEXT)

func draw_world() -> void:
	terrain.draw(game)
	var actor: Adventurer = game.actor
	var render_entities: Array = []
	for list in game.world.entities.values():
		for entity in list:
			if game.visible_tiles.has(entity.pos):
				render_entities.append(entity)
	render_entities.append({"kind": "player", "pos": actor.pos})
	render_entities.sort_custom(func(a, b): return a.pos.y < b.pos.y)
	for entity in render_entities:
		if entity.kind == "player":
			var s := Vector2(232, 136)
			draw_ellipse_shadow(s)
			tile_sprite(greyman, s, actor.sprite_region(), Color("ef8888") if actor.hurt_clock > 0 else Color.WHITE)
			if actor.attack_clock > 0.20:
				var point := s + Vector2(8, 8) + Vector2(actor.facing) * 12
				draw_arc(point, 7, actor.anim_time * 5, actor.anim_time * 5 + 2.4, 6, Color("edce8b"), 1)
		else:
			draw_entity(entity)
	for fx in game.particles:
		label_at(screen(Vector2(fx.pos)) + Vector2(1, -4 - (0.8 - fx.time) * 12), fx.text, fx.color)
func draw_ellipse_shadow(s: Vector2) -> void:
	draw_rect(Rect2(s + Vector2(3, 13), Vector2(10, 3)), Color(0.02, 0.025, 0.04, 0.5))

func draw_torch(s: Vector2) -> void:
	draw_rect(Rect2(s + Vector2(7, 7), Vector2(2, 7)), Color("71513b"))
	var flicker := int(game.actor.anim_time * 8) % 2
	draw_rect(Rect2(s + Vector2(6, 4 - flicker), Vector2(4, 5)), Color("c47e3b"))
	draw_rect(Rect2(s + Vector2(7, 4), Vector2(2, 3)), Color("f4d590"))

func draw_entity(e: Dictionary) -> void:
	var s := screen(Vector2(e.pos))
	draw_ellipse_shadow(s)
	if game.world.theme(e.pos) == 1 and e.kind in ["barrel", "chest", "crate"]:
		var source := Rect2(102, 170, 16, 17) if e.kind == "barrel" else Rect2(255 if not e.used else 289, 187, 16, 17)
		tile_sprite(mini, s - Vector2(0, 1), source)
		return
	match e.kind:
		"item":
			draw_item(e.name, s)
			if int(game.actor.anim_time * 2) % 3 == 0:
				draw_rect(Rect2(s + Vector2(12, 2), Vector2(1, 3)), GOLD)
		"chest":
			tile_sprite(objects, s - Vector2(8, 12), Rect2(128 if e.used else 160, 0, 32, 32))
		"barrel":
			tile_sprite(objects, s - Vector2(0, 8), Rect2(96, 64, 16, 24))
		"urn":
			tile_sprite(objects, s - Vector2(0, 4), Rect2(192, 64, 16, 24))
		"crate":
			tile_sprite(objects, s - Vector2(0, 14), Rect2(48, 64, 16, 32))
		"fountain":
			draw_rect(Rect2(s + Vector2(2, 4), Vector2(12, 11)), Color("79828b"))
			draw_rect(Rect2(s + Vector2(4, 6), Vector2(8, 6)), Color("344653") if e.used else Color("5da5bc"))
			draw_rect(Rect2(s + Vector2(6, 1), Vector2(4, 8)), Color("929da5"))
		"trap":
			if e.used or e.get("revealed", false):
				draw_rect(Rect2(s + Vector2(3, 9), Vector2(10, 5)), MUTED if e.used else Color("c78363"), false)
			else:
				draw_rect(Rect2(s + Vector2(5, 12), Vector2(5, 1)), Color("59616b"))
		"mob":
			draw_monster(s, e)

func draw_monster(s: Vector2, e: Dictionary) -> void:
	var bob := int(game.actor.anim_time * 4) % 2
	if e.name == "slime":
		draw_rect(Rect2(s + Vector2(3, 7 + bob), Vector2(10, 7 - bob)), Color("608f7b"))
		draw_rect(Rect2(s + Vector2(5, 5 + bob), Vector2(6, 3)), Color("7db18e"))
		draw_rect(Rect2(s + Vector2(5, 9), Vector2(1, 2)), INK)
		draw_rect(Rect2(s + Vector2(10, 9), Vector2(1, 2)), INK)
	elif e.name == "rata":
		draw_rect(Rect2(s + Vector2(3, 8 + bob), Vector2(10, 5)), Color("998786"))
		draw_rect(Rect2(s + Vector2(3, 6 + bob), Vector2(3, 3)), Color("b8a39b"))
		draw_line(s + Vector2(13, 12), s + Vector2(16, 9), Color("b8a39b"), 1)
		draw_rect(Rect2(s + Vector2(4, 9), Vector2(1, 1)), Color("efbd8f"))
	else:
		draw_rect(Rect2(s + Vector2(5, 2 + bob), Vector2(7, 6)), Color("cbc7ae"))
		draw_rect(Rect2(s + Vector2(6, 4 + bob), Vector2(1, 2)), INK)
		draw_rect(Rect2(s + Vector2(10, 4 + bob), Vector2(1, 2)), INK)
		draw_line(s + Vector2(8, 8), s + Vector2(8, 12), Color("cbc7ae"), 2)
		draw_line(s + Vector2(4, 9), s + Vector2(12, 9), Color("cbc7ae"), 1)
		draw_line(s + Vector2(8, 12), s + Vector2(5, 15), Color("cbc7ae"), 1)
		draw_line(s + Vector2(8, 12), s + Vector2(11, 15), Color("cbc7ae"), 1)

func draw_item(name: String, s: Vector2) -> void:
	match name:
		"pico":
			draw_line(s + Vector2(4, 14), s + Vector2(11, 4), Color("ae875b"), 2)
			draw_line(s + Vector2(6, 3), s + Vector2(14, 7), Color("b8c8ce"), 2)
		"casco":
			draw_rect(Rect2(s + Vector2(4, 5), Vector2(9, 7)), Color("a5b4c0"))
			draw_rect(Rect2(s + Vector2(6, 3), Vector2(5, 4)), Color("c2cbd0"))
			draw_rect(Rect2(s + Vector2(7, 9), Vector2(3, 3)), Color("596675"))
		"poción":
			draw_rect(Rect2(s + Vector2(6, 3), Vector2(4, 4)), Color("b7ada0"))
			draw_rect(Rect2(s + Vector2(4, 7), Vector2(8, 7)), Color("b96776"))
			draw_rect(Rect2(s + Vector2(5, 8), Vector2(2, 3)), Color("ebacb0"))
		"soga":
			draw_arc(s + Vector2(8, 9), 4, 0, 5.8, 10, Color("bba17a"), 2)
			draw_line(s + Vector2(11, 11), s + Vector2(14, 14), Color("bba17a"), 1)
		"pan", "ración":
			draw_rect(Rect2(s + Vector2(3, 7), Vector2(11, 6)), Color("be925c"))
			draw_line(s + Vector2(6, 7), s + Vector2(7, 10), Color("ead4a1"), 1)
		"piedra":
			draw_rect(Rect2(s + Vector2(4, 8), Vector2(9, 6)), Color("8f939c"))
			draw_rect(Rect2(s + Vector2(6, 6), Vector2(5, 3)), Color("a9b0b6"))
		"oro":
			tile_sprite(objects, s, Rect2(240, 32, 16, 16))
		_:
			var icon: Vector2i = DungeonInventory.CATALOG[name].icon
			tile_sprite(mini, s, Rect2(Vector2(icon * 17), Vector2(16, 16)))

func draw_hud() -> void:
	var actor: Adventurer = game.actor
	# One bottom strip. All remaining pixels belong to the dungeon.
	draw_rect(Rect2(0, 263, 480, 37), Color("181720"))
	draw_line(Vector2(0, 263), Vector2(480, 263), Color("514752"))
	draw_line(Vector2(0, 264), Vector2(480, 264), Color("292631"))
	label_at(Vector2(8, 276), "VIDA %02d/40" % actor.hp, Color("ce9390"), 9)
	draw_rect(Rect2(68, 269, 40, 5), Color("342630"))
	draw_rect(Rect2(68, 269, actor.hp, 5), Color("9f626d"))
	label_at(Vector2(119, 276), "COMIDA %d" % actor.hunger, Color("b6b29a"), 9)
	var held := actor.inventory.equipped("Mano")
	label_at(Vector2(194, 276), "Mano: " + ("libre" if held.is_empty() else held), TEXT, 9)
	label_at(Vector2(292, 276), "ATQ %d  DEF %d" % [actor.inventory.damage(), actor.inventory.armor()], MUTED, 9)
	label_at(Vector2(388, 276), "I Equipo  F1 Ayuda", GOLD, 8)
	if not game.messages.is_empty():
		label_at(Vector2(8, 290), game.messages.back(), Color("a8a3a1"), 9)
	var state := "AUTO" if actor.autonomous and game.auto_enabled else "MANUAL"
	label_at(Vector2(442, 290), state, Color("958975"), 8)
func draw_inventory() -> void:
	draw_rect(Rect2(0, 28, 480, 228), Color(0.02, 0.03, 0.05, 0.85))
	box(Rect2(32, 34, 416, 222))
	label_at(Vector2(44, 52), "MOCHILA / EQUIPAMIENTO LIBRE", GOLD, 12)
	var inv: DungeonInventory = game.actor.inventory
	label_at(Vector2(44, 66), "%d/%d espacios · peso %d  |  Simulación pausada" % [inv.items.size(), inv.capacity, inv.weight()], MUTED, 9)
	for i in range(inv.items.size()):
		var col := i / 8
		var row := i % 8
		var p := Vector2(44 + col * 112, 73 + row * 17)
		if inv.selected == i:
			draw_rect(Rect2(p, Vector2(108, 17)), Color("303a44"))
		draw_item(inv.items[i], p)
		var marker := "*" if inv.equipment.values().has(i) else ""
		var stack := " x%d" % inv.stack_count(i) if inv.stack_count(i) > 1 else ""
		label_at(p + Vector2(19, 12), inv.items[i].capitalize() + stack + marker, TEXT, 9)
	if inv.items.is_empty():
		label_at(Vector2(48, 95), "Vacía. [E] recoge objetos.", MUTED, 9)
	for i in range(4):
		var p := Vector2(280, 77 + i * 29)
		box(Rect2(p, Vector2(155, 26)), Color("1a222e"), GOLD if i == inv.active_slot else EDGE)
		var slot: String = DungeonInventory.SLOT_NAMES[i]
		var name := inv.equipped(slot)
		label_at(p + Vector2(5, 10), slot.to_upper(), MUTED, 8)
		label_at(p + Vector2(5, 21), "—" if name.is_empty() else name.capitalize(), TEXT, 9)
	if not inv.items.is_empty():
		var properties: Dictionary = DungeonInventory.CATALOG[inv.items[inv.selected]]
		label_at(Vector2(280, 206), "Daño en mano: %d" % properties.damage, GOLD, 9)
		label_at(Vector2(280, 219), "Blando/flexible: no causa daño." if properties.damage == 0 else "Todo cabe en cualquier ranura.", MUTED, 8)
	label_at(Vector2(44, 237), "↑↓ Objeto  TAB Ranura  ENTER Equipar  U Consumir  G Soltar", GOLD, 9)
	label_at(Vector2(44, 249), "Clic: elegir objeto o ranura                              I Cerrar", MUTED, 8)

func inventory_click(p: Vector2) -> void:
	var inv: DungeonInventory = game.actor.inventory
	if p.x >= 44 and p.x < 268 and p.y >= 73 and p.y < 209:
		var index := int((p.x - 44) / 112) * 8 + int((p.y - 73) / 17)
		if index < inv.items.size():
			inv.selected = index
	if p.x >= 280 and p.x < 435 and p.y >= 77 and p.y < 193:
		inv.active_slot = int((p.y - 77) / 29)

func draw_help() -> void:
	draw_rect(Rect2(0, 28, 480, 228), Color(0.02, 0.03, 0.05, 0.9))
	box(Rect2(28, 36, 424, 216))
	label_at(Vector2(42, 55), "MANUAL DEL ERRANTE", GOLD, 12)
	var lines := [
		"WASD / Flechas   Caminar; chocar con un enemigo lo ataca.",
		"E                Recoger, abrir/cerrar, empujar, beber, desarmar.",
		"ESPACIO          Atacar de frente. Con pico: excavar (3 golpes).",
		"X                Examinar alrededor: puertas secretas y trampas.",
		"I                Mochila. ↑↓ objeto, Tab ranura, Enter equipar.",
		"U / G            Consumir / soltar el objeto elegido (en mochila).",
		"Q                Activar o desactivar autonomía tras 5 s sin jugar.",
		"F5 / Esc         Guardar / pausar. También se guarda al salir.",
		"",
		"Un casco en la mano golpea. En la cabeza protege.",
		"El pico rompe cualquier muro y conecta salas y pasillos.",
		"Tu visión llega 6 tiles. Lo visto queda en la memoria del mapa.",
		"La autonomía recorre lo conocido y se detiene si ve enemigos.",
		"Los sectores continúan en todas direcciones. Cada partida es única."
	]
	for i in range(lines.size()):
		label_at(Vector2(42, 73 + i * 11), lines[i], MUTED if i >= 9 else TEXT, 9)
	label_at(Vector2(42, 242), "[F1 / Esc] Volver a la expedición", GOLD, 9)

