class_name Adventurer
extends RefCounted

var pos := Vector2i(16, 16)
var visual := Vector2(16, 16)
var facing := Vector2i.DOWN
var hp: int = 40
var hunger: float = 100.0
var idle_time: float = 0.0
var step_clock: float = 0.0
var attack_clock: float = 0.0
var hurt_clock: float = 0.0
var anim_time: float = 0.0
var moving: bool = false
var autonomous: bool = false
var auto_path: Array[Vector2i] = []
var visits: Dictionary = {}
var inventory := DungeonInventory.new()
var progression := AdventurerProgression.new()
var animation := GreyManAnimation.new()
var walk_animation_time := 0.0

func direction_row() -> int:
	return GreyManAnimation.DIRECTION_ROW.get(facing, 2)

func sprite_region() -> Rect2:
	animation.advance(0, moving, attack_clock > 0)
	return animation.region(facing)

func max_hp() -> int:
	return progression.max_hp()

func damage() -> int:
	var base := inventory.damage()
	# Strength cannot turn flexible food or rope into a damaging weapon.
	return 0 if base == 0 else base + progression.strength - 1

func armor() -> int:
	return inventory.armor() + (progression.vitality - 1) / 3

func improve(attribute: String) -> bool:
	var old_max := max_hp()
	if not progression.improve(attribute):
		return false
	hp += max_hp() - old_max
	return true

func backpack_cost() -> int:
	return 20 + ((inventory.capacity - 16) / 4) * 10

func buy_backpack_upgrade() -> bool:
	if inventory.capacity >= DungeonInventory.MAX_CAPACITY or progression.coins < backpack_cost():
		return false
	progression.coins -= backpack_cost()
	inventory.expand()
	return true

func controlled() -> void:
	idle_time = 0.0
	autonomous = false
	auto_path.clear()

func tick(delta: float) -> void:
	idle_time += delta
	step_clock = maxf(0, step_clock - delta)
	attack_clock = maxf(0, attack_clock - delta)
	hurt_clock = maxf(0, hurt_clock - delta)
	anim_time += delta
	visual = visual.move_toward(Vector2(pos), delta * 1.15 / progression.step_interval())
	walk_animation_time = maxf(0, walk_animation_time - delta)
	moving = visual.distance_to(Vector2(pos)) > 0.02 or walk_animation_time > 0
	animation.advance(delta, moving, attack_clock > 0)
	hunger = maxf(0, hunger - delta * 0.035)
	if idle_time >= 5.0:
		autonomous = true
