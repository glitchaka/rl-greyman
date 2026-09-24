extends SceneTree

class Sheet extends Node2D:
	var texture: Texture2D
	func _draw() -> void:
		var extent := texture.get_size() * 3
		draw_rect(Rect2(Vector2.ZERO, extent + Vector2(80, 80)), Color("20202c"))
		draw_texture_rect(texture, Rect2(Vector2(40, 40), extent), false)
		for x in range(int(texture.get_width() / 16) + 1):
			draw_line(Vector2(40 + x * 48, 40), Vector2(40 + x * 48, extent.y + 40), Color(0.9, 0.7, 0.3, 0.3))
			draw_string(ThemeDB.fallback_font, Vector2(40 + x * 48, 25), str(x * 16), HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
		for y in range(int(texture.get_height() / 16) + 1):
			draw_line(Vector2(40, 40 + y * 48), Vector2(extent.x + 40, 40 + y * 48), Color(0.9, 0.7, 0.3, 0.3))
			draw_string(ThemeDB.fallback_font, Vector2(2, 50 + y * 48), str(y * 16), HORIZONTAL_ALIGNMENT_LEFT, -1, 14)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var viewport := SubViewport.new()
	var filename := "walls_floor"
	if not OS.get_cmdline_user_args().is_empty():
		filename = OS.get_cmdline_user_args()[0]
	var texture: Texture2D = load("res://assets/" + filename) if filename.ends_with(".png") else load("res://assets/PNG/" + filename + ".png")
	viewport.size = Vector2i(texture.get_size() * 3 + Vector2(80, 80))
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var sheet := Sheet.new()
	sheet.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sheet.texture = texture
	viewport.add_child(sheet)
	await process_frame
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png("res://tests/screenshots/atlas_" + filename.get_file().get_basename() + ".png")
	quit()
