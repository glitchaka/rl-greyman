class_name AutoExplorer
extends RefCounted

const DIRECTIONS := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]

func next_step(actor: Adventurer, world: DungeonWorld) -> Vector2i:
	if actor.auto_path.is_empty():
		find_route(actor, world)
	if actor.auto_path.is_empty():
		return Vector2i.ZERO
	var target: Vector2i = actor.auto_path.pop_front()
	var offset := target - actor.pos
	if absi(offset.x) + absi(offset.y) != 1 or not world.explored.has(target) or not world.walkable(target):
		actor.auto_path.clear()
		return Vector2i.ZERO
	return target - actor.pos

func find_route(actor: Adventurer, world: DungeonWorld) -> void:
	var queue: Array[Vector2i] = [actor.pos]
	var parent: Dictionary = {actor.pos: actor.pos}
	var depth: Dictionary = {actor.pos: 0}
	var best := actor.pos
	var best_score := -INF
	var index := 0
	while index < queue.size() and index < 250:
		var p := queue[index]
		index += 1
		if p != actor.pos:
			var score: float = depth[p] * 0.4 - actor.visits.get(p, 0) * 4.0
			if score > best_score:
				best_score = score
				best = p
		for dir in DIRECTIONS:
			var n: Vector2i = p + dir
			if parent.has(n) or not world.explored.has(n) or not world.walkable(n):
				continue
			var safe := true
			for e in world.at(n):
				if e.kind in ["mob", "trap", "barrel", "urn", "crate", "chest", "fountain"]:
					safe = false
			if safe:
				parent[n] = p
				depth[n] = depth[p] + 1
				queue.append(n)
	while best != actor.pos:
		actor.auto_path.push_front(best)
		best = parent[best]
