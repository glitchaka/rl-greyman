class_name GreyManAnimation
extends RefCounted

# Verified against the actual 64x192 atlas, not an assumed sprite convention.
# Side profiles occupy rows 0/1, front/back rows 2/3 in EVERY state block.
const DIRECTION_ROW := {Vector2i.RIGHT: 0, Vector2i.LEFT: 1, Vector2i.DOWN: 2, Vector2i.UP: 3}
const FRAME_SIZE := 16
var elapsed := 0.0
var state := "idle"

func advance(delta: float, walking: bool, attacking: bool) -> void:
	var next := "attack" if attacking else ("walk" if walking else "idle")
	if next != state:
		elapsed = 0.0
		state = next
	elapsed += delta

func region(facing: Vector2i) -> Rect2:
	var row: int = DIRECTION_ROW.get(facing, 2)
	var speed := 5.0
	if state == "walk":
		row += 4
		speed = 10.0
	elif state == "attack":
		row += 8
		speed = 12.0
	var frame := mini(3, int(elapsed * speed)) if state == "attack" else int(elapsed * speed) % 4
	return Rect2(frame * FRAME_SIZE, row * FRAME_SIZE, FRAME_SIZE, FRAME_SIZE)
