class_name DungeonInventory
extends RefCounted

const CATALOG := {
	"pico": {"weight": 4, "damage": 5, "armor": 0, "mining": 1, "icon": Vector2i(15, 21)},
	"casco": {"weight": 3, "damage": 3, "armor": 2, "protects": "Cabeza", "icon": Vector2i(13, 7)},
	"espada": {"weight": 3, "damage": 7, "armor": 0, "icon": Vector2i(14, 0)},
	"escudo": {"weight": 4, "damage": 4, "armor": 2, "protects": "Secundaria", "icon": Vector2i(13, 0)},
	"poción": {"weight": 1, "damage": 1, "armor": 0, "healing": 18, "icon": Vector2i(19, 3)},
	"pan": {"weight": 1, "damage": 0, "armor": 0, "nutrition": 35, "healing": 3, "icon": Vector2i(19, 6)},
	"ración": {"weight": 1, "damage": 0, "armor": 0, "nutrition": 35, "healing": 3, "icon": Vector2i(19, 6)},
	"soga": {"weight": 2, "damage": 0, "armor": 0, "icon": Vector2i(19, 6)},
	"piedra": {"weight": 2, "damage": 3, "armor": 0, "icon": Vector2i(19, 5)},
	"oro": {"weight": 1, "damage": 2, "armor": 0, "coins": 10, "icon": Vector2i(19, 4)},
	"manual": {"weight": 1, "damage": 2, "armor": 0, "xp": 20, "icon": Vector2i.ZERO},
	"bolsillo": {"weight": 1, "damage": 0, "armor": 0, "capacity": 4, "icon": Vector2i.ZERO}
}
const MAX_CAPACITY := 48
const SLOT_NAMES := ["Mano", "Cabeza", "Cuerpo", "Secundaria"]
var items: Array = []
var equipment: Dictionary = {"Mano": -1, "Cabeza": -1, "Cuerpo": -1, "Secundaria": -1}
var selected: int = 0
var active_slot: int = 0
var capacity := 16

func add(name: String) -> bool:
	if not CATALOG.has(name) or items.size() >= capacity:
		return false
	items.append(name)
	return true

func expand() -> bool:
	if capacity >= MAX_CAPACITY:
		return false
	capacity = mini(MAX_CAPACITY, capacity + 4)
	return true

func page() -> int:
	return selected / 16

func equipped(slot: String) -> String:
	var index: int = equipment[slot]
	return items[index] if index >= 0 and index < items.size() else ""

func equip() -> String:
	if items.is_empty():
		return "La mochila está vacía."
	var slot: String = SLOT_NAMES[active_slot]
	if equipment[slot] == selected:
		equipment[slot] = -1
		return "Retiras %s de %s." % [items[selected], slot.to_lower()]
	for key in equipment:
		if equipment[key] == selected:
			equipment[key] = -1
	equipment[slot] = selected
	return "%s en %s." % [items[selected].capitalize(), slot.to_lower()]

func erase(index: int) -> String:
	if index < 0 or index >= items.size():
		return ""
	var name: String = items[index]
	items.remove_at(index)
	for slot in equipment:
		if equipment[slot] == index:
			equipment[slot] = -1
		elif equipment[slot] > index:
			equipment[slot] -= 1
	selected = clampi(selected, 0, maxi(0, items.size() - 1))
	return name

func damage() -> int:
	var name := equipped("Mano")
	return CATALOG[name].damage if CATALOG.has(name) else 2

func armor() -> int:
	var value := 0
	for slot in equipment:
		var name := equipped(slot)
		if CATALOG.has(name) and CATALOG[name].get("protects", "") == slot:
			value += CATALOG[name].armor
	return value

func mining_power() -> int:
	return CATALOG.get(equipped("Mano"), {}).get("mining", 0)

func weight() -> int:
	var total := 0
	for name in items:
		total += CATALOG[name].weight
	return total
