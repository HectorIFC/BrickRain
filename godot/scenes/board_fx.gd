class_name BoardFx
extends Control

# Celebration overlay for the well: particles, row flashes, the lock pulse,
# the level-up wave, the game-over sweep and confetti, plus the floating
# text popups. Sits as a child of BoardView (so it shares its rect) and uses
# the parent's well_metrics() for geometry.
#
# Same implementation style as piece_rain.gd: plain arrays advanced in
# _process and drawn in _draw. No nodes per particle, hard cap on the pool.
# Everything here is presentation; nothing reaches into game state.

const MAX_PARTICLES := 350
const GRAVITY := 900.0

var _particles: Array = []
var _rockets: Array = []      # {from, apex, t, rise, color}
var _flashes: Array = []      # {y_px, h_px, t}
var _pulses: Array = []       # {cells: Array, t}
var _wave_t := -1.0
var _sweep_t := -1.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rng.seed = 20260817


func _metrics() -> Dictionary:
	return get_parent().well_metrics()


# --- effect triggers -------------------------------------------------------


# Burst + flash over the cleared rows. `row_colors` carries one array of cell
# colors per row so the particles inherit the pieces they came from.
func line_clear(rows: Array, row_colors: Array, lines: int) -> void:
	var m := _metrics()
	var origin: Vector2 = m["origin"]
	var pitch: float = m["pitch"]
	var per_cell := 3 if lines >= 4 else 2
	for i in range(rows.size()):
		var row := int(rows[i])
		var y_px := origin.y + row * pitch
		_flashes.append({"y_px": y_px, "h_px": m["cell"], "t": 0.0})
		var colors: Array = row_colors[i] if i < row_colors.size() else []
		for col in range(BoardView.COLS):
			var color: Color = colors[col] if col < colors.size() else GameTheme.text_color()
			for _j in range(per_cell):
				_spawn_particle(
					origin + Vector2((col + 0.5) * pitch, y_px - origin.y + m["cell"] * 0.5),
					color
				)


# Dust where the piece landed on a hard drop.
func hard_drop(cells: Array) -> void:
	var m := _metrics()
	var origin: Vector2 = m["origin"]
	var pitch: float = m["pitch"]
	for cell in cells:
		var at := origin + Vector2((int(cell["x"]) + 0.5) * pitch, (int(cell["y"]) + 1.0) * pitch)
		for _j in range(2):
			var p := _make_particle(at, Color(1, 1, 1, 0.8))
			# Dust kicks out sideways and up, not skyward like a burst.
			p["vel"] = Vector2(_rng.randf_range(-140, 140), _rng.randf_range(-120, -30))
			p["size"] = _rng.randf_range(2.0, 4.0)
			_push_particle(p)


# Brief brightening of freshly locked cells: confirmation, not celebration.
func lock_pulse(cells: Array) -> void:
	_pulses.append({"cells": cells.duplicate(), "t": 0.0})


func level_up() -> void:
	_wave_t = 0.0


func game_over_sweep() -> void:
	_sweep_t = 0.0


# Confetti for a new record: falls from above the well, colours of the palette.
func confetti() -> void:
	var m := _metrics()
	var origin: Vector2 = m["origin"]
	var well: Vector2 = m["well"]
	var palette := GameTheme.cell_colors()
	for _i in range(120):
		var p := _make_particle(
			Vector2(origin.x + _rng.randf_range(0.0, well.x), origin.y - _rng.randf_range(0.0, well.y * 0.3)),
			palette[_rng.randi_range(1, 7)]
		)
		p["vel"] = Vector2(_rng.randf_range(-60, 60), _rng.randf_range(40, 160))
		p["life"] = _rng.randf_range(1.2, 2.2)
		p["size"] = _rng.randf_range(4.0, 8.0)
		p["gravity"] = 140.0
		_push_particle(p)


# One firework of the record celebration: a rocket streaks up from the well
# floor and pops into a radial burst at a random apex. The caller fixes rise_s
# so it can schedule the burst sound for the same instant - sound and visual
# stay in sync by construction, no signal needed.
func firework(color: Color, rise_s: float) -> void:
	var m := _metrics()
	var origin: Vector2 = m["origin"]
	var well: Vector2 = m["well"]
	_rockets.append({
		"from": Vector2(origin.x + _rng.randf_range(well.x * 0.15, well.x * 0.85), origin.y + well.y),
		"apex": Vector2(
			origin.x + _rng.randf_range(well.x * 0.2, well.x * 0.8),
			origin.y + _rng.randf_range(well.y * 0.08, well.y * 0.35)
		),
		"t": 0.0,
		"rise": rise_s,
		"color": color,
	})


func _explode(at: Vector2, color: Color) -> void:
	# Sizes and speeds live in the 1080x1920 design space, so the burst has to
	# be sized against the well (~900 wide), not against a cell - the first cut
	# used cell-scale numbers and read as a barely-visible speck.
	# A brief white core so the pop reads as a flash, then the colored ring.
	for _i in range(8):
		var core := _make_particle(at, Color(1, 1, 1, 0.95))
		core["vel"] = Vector2(_rng.randf_range(-80, 80), _rng.randf_range(-80, 80))
		core["life"] = _rng.randf_range(0.2, 0.35)
		core["size"] = _rng.randf_range(10.0, 16.0)
		core["gravity"] = 0.0
		_push_particle(core)
	for i in range(48):
		var angle := TAU * i / 48.0 + _rng.randf_range(-0.05, 0.05)
		var p := _make_particle(at, color.lightened(_rng.randf_range(0.0, 0.35)))
		p["vel"] = Vector2.from_angle(angle) * _rng.randf_range(260.0, 620.0)
		p["life"] = _rng.randf_range(0.8, 1.4)
		p["size"] = _rng.randf_range(5.0, 9.0)
		p["gravity"] = 260.0
		_push_particle(p)


# Floating text popup rising from the well centre. `tint` may be a single
# colour; pass Color.TRANSPARENT to use the wordmark palette per letter.
func popup(text: String, font_size: int, tint: Color = Color.TRANSPARENT) -> void:
	var node: Control
	if tint == Color.TRANSPARENT:
		node = UiStyle.make_wordmark(text, font_size, false)
	else:
		node = UiStyle.make_label(text, font_size, tint)
	add_child(node)
	node.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	node.modulate.a = 0.0
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(node, "modulate:a", 1.0, 0.12)
	tween.tween_property(node, "position:y", node.position.y - 90.0, 0.85) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.chain().tween_property(node, "modulate:a", 0.0, 0.3).set_delay(0.25)
	tween.chain().tween_callback(node.queue_free)


# --- simulation ------------------------------------------------------------


func _make_particle(at: Vector2, color: Color) -> Dictionary:
	return {
		"pos": at,
		"vel": Vector2(_rng.randf_range(-220, 220), _rng.randf_range(-320, -80)),
		"color": color,
		"life": _rng.randf_range(0.4, 0.8),
		"age": 0.0,
		"size": _rng.randf_range(3.0, 6.0),
		"gravity": GRAVITY,
	}


func _spawn_particle(at: Vector2, color: Color) -> void:
	_push_particle(_make_particle(at, color))


func _push_particle(p: Dictionary) -> void:
	# Hard cap: recycle the oldest slot rather than growing without bound.
	if _particles.size() >= MAX_PARTICLES:
		_particles.pop_front()
	_particles.append(p)


# Driven by GameScreen's clock, same as BoardView.tick.
func tick(delta: float) -> void:
	var busy := false

	for i in range(_rockets.size() - 1, -1, -1):
		var r: Dictionary = _rockets[i]
		r["t"] += delta
		if r["t"] >= r["rise"]:
			_explode(r["apex"], r["color"])
			_rockets.remove_at(i)
		busy = true

	for i in range(_particles.size() - 1, -1, -1):
		var p: Dictionary = _particles[i]
		p["age"] += delta
		if p["age"] >= p["life"]:
			_particles.remove_at(i)
			continue
		p["vel"] += Vector2(0, p["gravity"]) * delta
		p["pos"] += p["vel"] * delta
		busy = true

	for i in range(_flashes.size() - 1, -1, -1):
		_flashes[i]["t"] += delta
		if _flashes[i]["t"] > 0.14:
			_flashes.remove_at(i)
		else:
			busy = true

	for i in range(_pulses.size() - 1, -1, -1):
		_pulses[i]["t"] += delta
		if _pulses[i]["t"] > 0.18:
			_pulses.remove_at(i)
		else:
			busy = true

	if _wave_t >= 0.0:
		_wave_t += delta
		if _wave_t > 0.5:
			_wave_t = -1.0
		busy = true

	if _sweep_t >= 0.0:
		_sweep_t += delta
		if _sweep_t > 0.75:
			_sweep_t = 0.75  # holds until the overlay covers it
		busy = true

	if busy:
		queue_redraw()


func clear_all() -> void:
	_particles.clear()
	_rockets.clear()
	_flashes.clear()
	_pulses.clear()
	_wave_t = -1.0
	_sweep_t = -1.0
	queue_redraw()


# --- drawing ---------------------------------------------------------------


func _draw() -> void:
	var m := _metrics()
	var origin: Vector2 = m["origin"]
	var well: Vector2 = m["well"]
	var pitch: float = m["pitch"]
	var cell: float = m["cell"]

	for flash in _flashes:
		var a: float = 0.85 * (1.0 - float(flash["t"]) / 0.14)
		draw_rect(
			Rect2(Vector2(origin.x, flash["y_px"]), Vector2(well.x, flash["h_px"])),
			Color(1, 1, 1, a)
		)

	for pulse in _pulses:
		var a: float = 0.35 * (1.0 - float(pulse["t"]) / 0.18)
		for c in pulse["cells"]:
			draw_rect(
				Rect2(origin + Vector2(int(c["x"]) * pitch, int(c["y"]) * pitch), Vector2(cell, cell)),
				Color(1, 1, 1, a)
			)

	if _wave_t >= 0.0:
		var band_y := origin.y + well.y * (_wave_t / 0.5)
		var band := Color(GameTheme.accent_color(), 0.35 * (1.0 - _wave_t / 0.5))
		draw_rect(Rect2(Vector2(origin.x, band_y - 14.0), Vector2(well.x, 28.0)), band)

	if _sweep_t >= 0.0:
		var covered := well.y * minf(_sweep_t / 0.6, 1.0)
		draw_rect(Rect2(origin, Vector2(well.x, covered)), Color(0.03, 0.04, 0.13, 0.72))

	for r in _rockets:
		var f: float = clampf(float(r["t"]) / float(r["rise"]), 0.0, 1.0)
		# Ease-out: the rocket decelerates as it nears the apex, like the real thing.
		var eased := 1.0 - (1.0 - f) * (1.0 - f)
		var pos: Vector2 = Vector2(r["from"]).lerp(r["apex"], eased)
		var color: Color = r["color"]
		draw_line(pos, pos + Vector2(0, 44.0 * (1.0 - f)), Color(color, 0.5), 5.0)
		draw_rect(Rect2(pos - Vector2(4, 4), Vector2(8, 8)), Color(1, 1, 1, 0.95))

	for p in _particles:
		var fade: float = 1.0 - p["age"] / p["life"]
		var color: Color = p["color"]
		color.a *= fade
		var size: float = p["size"]
		draw_rect(Rect2(p["pos"] - Vector2(size, size) * 0.5, Vector2(size, size)), color)
