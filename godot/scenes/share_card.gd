class_name ShareCard
extends RefCounted

# Renders the end-of-game result as a PNG, base64-encoded for FBInstant.
#
# shareAsync requires an image, and text can only be drawn by a CanvasItem —
# there is no way to compose this straight into an Image. So the card is built
# as a normal Control inside a SubViewport, rendered for one frame, and read
# back as pixels.
#
# Kept deliberately small (600x400): the blob travels inside the share payload,
# and Messenger scales it down anyway.

const WIDTH := 600
const HEIGHT := 400


# Awaits two frames, so callers must await it too.
static func render_base64(host: Node, nickname: String, score: int, lines: int) -> String:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(WIDTH, HEIGHT)
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	host.add_child(viewport)
	viewport.add_child(_build_card(nickname, score, lines))

	# One frame to lay the card out, one for the viewport to render it.
	await host.get_tree().process_frame
	await host.get_tree().process_frame

	var image := viewport.get_texture().get_image()
	viewport.queue_free()
	if image == null:
		return ""
	return "data:image/png;base64," + Marshalls.raw_to_base64(image.save_png_to_buffer())


static func _build_card(nickname: String, score: int, lines: int) -> Control:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var background := ColorRect.new()
	background.color = GameTheme.background_color()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(background)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	center.add_child(column)

	# Same wordmark the game shows, so a shared card is recognisably BrickRain.
	column.add_child(UiStyle.make_wordmark("BRICKRAIN", 64, false))
	column.add_child(UiStyle.make_label(nickname, 34, GameTheme.accent_color()))
	column.add_child(UiStyle.make_label(str(score), 96, GameTheme.text_color()))
	column.add_child(UiStyle.make_label(
		"%d line%s cleared" % [lines, "" if lines == 1 else "s"],
		26,
		GameTheme.text_color(),
		false
	))
	return root
