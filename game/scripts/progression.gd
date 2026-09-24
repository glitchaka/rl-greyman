class_name AdventurerProgression
extends RefCounted

const ATTRIBUTES := ["Fuerza", "Vitalidad", "Agilidad"]
var level := 1
var xp := 0
var points := 0
var strength := 1
var vitality := 1
var agility := 1
var coins := 0
var kills := 0

func xp_required() -> int:
	return 20 + (level - 1) * 15

func gain_xp(amount: int) -> int:
	xp += maxi(0, amount)
	var gained := 0
	while xp >= xp_required():
		xp -= xp_required()
		level += 1
		points += 2
		gained += 1
	return gained

func improve(attribute: String) -> bool:
	if points <= 0 or attribute not in ATTRIBUTES:
		return false
	points -= 1
	match attribute:
		"Fuerza": strength += 1
		"Vitalidad": vitality += 1
		"Agilidad": agility += 1
	return true

func max_hp() -> int:
	return 40 + (vitality - 1) * 8

func attack_interval() -> float:
	return maxf(0.20, 0.45 - (agility - 1) * 0.025)

func step_interval() -> float:
	return maxf(0.09, 0.14 - (agility - 1) * 0.005)

func serialize() -> Dictionary:
	return {"level": level, "xp": xp, "points": points, "strength": strength,
		"vitality": vitality, "agility": agility, "coins": coins, "kills": kills}

func restore(data: Dictionary) -> void:
	level = maxi(1, int(data.get("level", 1)))
	xp = maxi(0, int(data.get("xp", 0)))
	points = maxi(0, int(data.get("points", 0)))
	strength = maxi(1, int(data.get("strength", 1)))
	vitality = maxi(1, int(data.get("vitality", 1)))
	agility = maxi(1, int(data.get("agility", 1)))
	coins = maxi(0, int(data.get("coins", 0)))
	kills = maxi(0, int(data.get("kills", 0)))
