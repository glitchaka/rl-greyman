class_name DungeonInteractions
extends RefCounted

signal message(text: String)
signal effect(pos: Vector2i, text: String, color: Color)
var world: DungeonWorld
var actor: Adventurer
var mining: Dictionary = {}

func _init(dungeon: DungeonWorld, player: Adventurer) -> void:
	world = dungeon
	actor = player

func move(dir: Vector2i, automatic: bool = false) -> bool:
	if actor.step_clock > 0 or absi(dir.x) + absi(dir.y) != 1:
		return false
	actor.facing = dir
	actor.step_clock = 0.20 if automatic else actor.progression.step_interval()
	var target := actor.pos + dir
	if world.tile(target) == DungeonWorld.DOOR and not automatic:
		world.set_door(target, DungeonWorld.OPEN)
		message.emit("Abres la puerta.")
		return false
	if not world.walkable(target):
		return false
	for e in world.at(target):
		if e.kind == "mob":
			if not automatic:
				attack()
			return false
		if e.kind in ["barrel", "urn", "crate", "chest", "fountain"]:
			return false
	actor.pos = target
	actor.spend_energy(Adventurer.MOVE_HUNGER_COST)
	actor.moving = true
	actor.walk_animation_time = actor.step_clock + 0.025
	actor.visits[target] = actor.visits.get(target, 0) + 1
	for e in world.at(target):
		if e.kind == "trap" and not e.used:
			e.used = true
			hurt(5)
			message.emit("¡Una placa de presión! -5 vida.")
	return true

func interact() -> void:
	for p in [actor.pos, actor.pos + actor.facing]:
		for e in world.at(p):
			match e.kind:
				"item":
					if actor.inventory.add(e.name):
						message.emit("Recoges %s." % e.name)
						world.remove_entity(e)
					else:
						message.emit("Mochila llena. Suelta algo con G.")
					return
				"chest":
					if not e.used:
						e.used = true
						actor.progression.coins += 10
						reward_xp(8)
						if e.name == "cofre de provisiones":
							for item in ["casco", "soga", "ración", "poción", "manual", "bolsillo"]:
								world.add_item(actor.pos, item)
						var loot := ["espada", "escudo", "poción", "ración", "manual", "bolsillo", "oro"]
						world.add_item(actor.pos, loot[world.noise(e.pos, 90) % loot.size()])
						world.add_item(actor.pos, "oro")
						message.emit("Cofre abierto: +10 monedas, +8 XP. [E] Recoger.")
					else:
						message.emit("El cofre está vacío; puedes romperlo.")
					return
				"fountain":
					if not e.used:
						e.used = true
						actor.hp = mini(actor.max_hp(), actor.hp + 12)
						message.emit("Bebes de la fuente. +12 vida.")
					else:
						message.emit("La fuente se ha secado.")
					return
				"trap":
					if not e.used:
						reward_xp(5)
					e.used = true
					message.emit("Desactivas la placa de presión.")
					return
				"barrel", "urn", "crate":
					var dest: Vector2i = e.pos + actor.facing
					if p != actor.pos and world.walkable(dest) and world.at(dest).is_empty():
						e.pos = dest
						message.emit("Empujas %s." % e.name)
					else:
						message.emit("No hay espacio para empujar.")
					return
	var front := actor.pos + actor.facing
	if world.tile(front) == DungeonWorld.DOOR:
		world.set_door(front, DungeonWorld.OPEN)
		message.emit("Abres la puerta.")
	elif world.tile(front) == DungeonWorld.OPEN:
		var clear := true
		for cell in world.door_cells(front):
			if cell == actor.pos or not world.at(cell).is_empty():
				clear = false
		if clear:
			world.set_door(front, DungeonWorld.DOOR)
			message.emit("Cierras la puerta.")
	else:
		message.emit("Nada que recoger aquí. [X] Examinar.")

func attack() -> void:
	if actor.attack_clock > 0:
		return
	actor.attack_clock = actor.progression.attack_interval()
	actor.spend_energy(Adventurer.ATTACK_HUNGER_COST)
	var p := actor.pos + actor.facing
	var held := actor.inventory.equipped("Mano")
	for e in world.at(p):
		if e.kind in ["mob", "barrel", "urn", "crate", "chest", "fountain"]:
			var damage := actor.damage()
			if damage == 0:
				message.emit("%s es flexible o blando: no hace daño." % held.capitalize())
				effect.emit(p, "0", Color("a0b0b9"))
				return
			e.hp -= damage
			effect.emit(p, "-%s" % damage, Color("e8b66e"))
			if not held.is_empty():
				message.emit("Golpeas con %s: %d de daño." % [held, damage])
			if e.hp <= 0:
				message.emit("%s %s." % ["Derrotas a" if e.kind == "mob" else "Rompes", e.name])
				if e.kind == "mob":
					actor.progression.kills += 1
					actor.progression.coins += 3
					reward_xp(15 if e.name == "esqueleto" else 10)
				if e.kind != "mob" or world.noise(p, 34) % 3 == 0:
					world.add_item(p, "pan" if e.kind in ["barrel", "mob"] else "piedra")
				world.remove_entity(e)
			return
	if world.tile(p) in [DungeonWorld.WALL, DungeonWorld.SECRET, DungeonWorld.DOOR]:
		if actor.inventory.mining_power() > 0:
			mining[p] = mining.get(p, 0) + actor.inventory.mining_power()
			effect.emit(p, "%s/3" % mining[p], Color("d8bd89"))
			if mining[p] >= 3:
				if world.tile(p) == DungeonWorld.DOOR:
					world.set_door(p, DungeonWorld.FLOOR)
				else:
					world.set_tile(p, DungeonWorld.FLOOR)
				world.add_item(p, "piedra")
				mining.erase(p)
				message.emit("El muro cede. Se abre un nuevo paso.")
		else:
			message.emit("Necesitas un pico en la mano para excavar.")

func search() -> void:
	var found := false
	for y in range(-1, 2):
		for x in range(-1, 2):
			var p := actor.pos + Vector2i(x, y)
			if world.tile(p) == DungeonWorld.SECRET:
				world.set_tile(p, DungeonWorld.DOOR)
				reward_xp(15)
				message.emit("¡Una corriente de aire! Puerta oculta.")
				found = true
			for e in world.at(p):
				if e.kind == "trap" and not e.used:
					e["revealed"] = true
					message.emit("Detectas una trampa. [E] Desactivar.")
					found = true
	if not found:
		var list := world.at(actor.pos + actor.facing)
		if not list.is_empty():
			message.emit("Ves %s. [E] Usar / [Espacio] Golpear." % list[0].name)
		else:
			message.emit("Examinas juntas y grietas. Nada oculto cerca.")

func use_item() -> void:
	var inv := actor.inventory
	if inv.items.is_empty():
		return
	var name: String = inv.items[inv.selected]
	var properties: Dictionary = DungeonInventory.CATALOG[name]
	var nutrition: int = properties.get("nutrition", 0)
	var healing: int = properties.get("healing", 0)
	if properties.has("xp"):
		inv.erase(inv.selected)
		reward_xp(properties.xp)
		return
	if properties.has("coins"):
		actor.progression.coins += properties.coins
		inv.erase(inv.selected)
		message.emit("Guardas 10 monedas. [C] Mejoras y mochila.")
		return
	if properties.has("capacity"):
		if inv.expand():
			inv.erase(inv.selected)
			message.emit("Coses un bolsillo: mochila de %d espacios." % inv.capacity)
		else:
			message.emit("Tu mochila ya tiene la capacidad máxima.")
		return
	if nutrition > 0 or healing > 0:
		var old_hp: int = actor.hp
		var old_hunger: float = actor.hunger
		actor.hp = mini(actor.max_hp(), actor.hp + healing)
		actor.hunger = maxf(0.0, actor.hunger - float(nutrition))
		inv.erase(inv.selected)
		var healed := actor.hp - old_hp
		var hunger_reduced := roundi(old_hunger - actor.hunger)
		message.emit("Consumes %s: hambre -%d, vida +%d." % [name, hunger_reduced, healed])
	else:
		message.emit("Equípalo con Enter; elige ranura con Tab.")

func drop() -> void:
	var name := actor.inventory.erase(actor.inventory.selected)
	if not name.is_empty():
		world.add_item(actor.pos, name)
		message.emit("Dejas %s en el suelo." % name)

func hurt(amount: int) -> void:
	if actor.hp <= 0:
		return
	var damage := maxi(1, amount - actor.armor())
	actor.hp = maxi(0, actor.hp - damage)
	actor.hurt_clock = 0.25
	effect.emit(actor.pos, "-%s" % damage, Color("e47777"))

func reward_xp(amount: int) -> void:
	var levels := actor.progression.gain_xp(amount)
	if levels > 0:
		message.emit("¡Nivel %d! +%d puntos. [C] Aumentar atributos." % [actor.progression.level, levels * 2])
		effect.emit(actor.pos, "NIVEL +%d" % levels, Color("dfc77e"))
	else:
		message.emit("+%d XP. [C] Ver progreso." % amount)

func tick_enemies(delta: float, visible: Dictionary) -> void:
	for list in world.entities.values():
		for e in list:
			if e.kind != "mob" or not visible.has(e.pos):
				continue
			e.clock -= delta
			if e.clock > 0:
				continue
			match e.name:
				"rata": e.clock = 0.65
				"slime": e.clock = 0.90
				_: e.clock = 0.80
			var diff: Vector2i = actor.pos - e.pos
			if absi(diff.x) + absi(diff.y) == 1:
				var attack_damage := 4
				if e.name == "slime":
					attack_damage = 5
				elif e.name == "esqueleto":
					attack_damage = 7
				hurt(attack_damage)
				continue
			if not world.clear_line(e.pos, actor.pos):
				continue
			var dirs: Array[Vector2i] = []
			if absi(diff.x) > absi(diff.y):
				dirs = [Vector2i(signi(diff.x), 0), Vector2i(0, signi(diff.y))]
			else:
				dirs = [Vector2i(0, signi(diff.y)), Vector2i(signi(diff.x), 0)]
			for dir in dirs:
				var dest: Vector2i = e.pos + dir
				if dir == Vector2i.ZERO or not world.walkable(dest) or dest == actor.pos:
					continue
				var blocked := false
				for other in world.at(dest):
					if other.kind != "item" and other.kind != "trap":
						blocked = true
				if not blocked:
					e.pos = dest
					break
