extends CanvasLayer
## Hearts, boss bar, stage title and the on-screen touch buttons.

var hp := Game.MAX_HP
var boss_max := 1
var boss_hp := 1
var boss_name := ""
var boss_visible := false
var title_text := ""
var title_alpha := 0.0

var canvas: Control
var buttons := {}


func _ready() -> void:
	layer = 10
	canvas = Control.new()
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.draw.connect(_draw_hud)
	add_child(canvas)
	_make_buttons()
	get_viewport().size_changed.connect(_layout)
	_layout()


func _process(delta: float) -> void:
	if title_alpha > 0.0:
		title_alpha -= delta * 0.4
	canvas.queue_redraw()


func set_hp(v: int) -> void:
	hp = maxi(v, 0)


func show_title(text: String) -> void:
	title_text = text
	title_alpha = 1.6


func show_boss(n: String, m: int) -> void:
	boss_name = n
	boss_max = m
	boss_hp = m
	boss_visible = true


func set_boss(v: int) -> void:
	boss_hp = maxi(v, 0)


func hide_boss() -> void:
	boss_visible = false


func _draw_hud() -> void:
	var size := canvas.size
	var font := ThemeDB.fallback_font
	# hearts
	for i in Game.MAX_HP / 2:
		var full := hp - i * 2
		var c := Vector2(14 + i * 15, 13)
		_heart(c, Color(0.25, 0.05, 0.08))
		if full >= 2:
			_heart(c, Color(0.9, 0.12, 0.2))
		elif full == 1:
			_heart(c, Color(0.9, 0.12, 0.2), true)
	# boss bar
	if boss_visible:
		var w := minf(size.x * 0.6, 260.0)
		var r := Rect2((size.x - w) / 2.0, 20, w, 6)
		canvas.draw_rect(r.grow(1), Color(0, 0, 0, 0.8))
		canvas.draw_rect(Rect2(r.position, Vector2(w * boss_hp / boss_max, 6)), Color(0.75, 0.1, 0.15))
		canvas.draw_string(font, Vector2(r.position.x, r.position.y - 3), boss_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1, 0.85, 0.8))
	# stage title
	if title_alpha > 0.0:
		var a := clampf(title_alpha, 0.0, 1.0)
		canvas.draw_string(font, Vector2(0, size.y * 0.33), title_text, HORIZONTAL_ALIGNMENT_CENTER, size.x, 16, Color(1, 0.9, 0.75, a))


func _heart(c: Vector2, col: Color, half := false) -> void:
	var pts := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		var p := Vector2(16.0 * pow(sin(a), 3), -(13.0 * cos(a) - 5.0 * cos(2 * a) - 2.0 * cos(3 * a) - cos(4 * a))) * 0.36
		if half:
			p.x = minf(p.x, 0.0)
		pts.append(c + p)
	canvas.draw_colored_polygon(pts, col)


# --------------------------------------------------------------- touch buttons
# Icons are drawn into textures at 4x resolution and the buttons are scaled down,
# so they stay sharp on high-resolution phone screens.

const SS := 4.0

const ARROW := [Vector2(-0.62, -0.18), Vector2(0.02, -0.18), Vector2(0.02, -0.55), Vector2(0.66, 0.0),
	Vector2(0.02, 0.55), Vector2(0.02, 0.18), Vector2(-0.62, 0.18)]
const CHEVRON := [Vector2(-0.5, 0.22), Vector2(0.0, -0.28), Vector2(0.5, 0.22), Vector2(0.34, 0.38),
	Vector2(0.0, 0.04), Vector2(-0.34, 0.38)]
const BLADE := [Vector2(-0.09, -0.62), Vector2(0.0, -0.78), Vector2(0.09, -0.62), Vector2(0.09, 0.28), Vector2(-0.09, 0.28)]
const GUARD := [Vector2(-0.34, 0.28), Vector2(0.34, 0.28), Vector2(0.34, 0.4), Vector2(-0.34, 0.4)]
const GRIP := [Vector2(-0.06, 0.4), Vector2(0.06, 0.4), Vector2(0.06, 0.64), Vector2(-0.06, 0.64)]
const POMMEL := [Vector2(-0.11, 0.64), Vector2(0.11, 0.64), Vector2(0.11, 0.76), Vector2(-0.11, 0.76)]


func _poly(points: Array, offset := Vector2.ZERO, scale := 1.0, angle := 0.0, mirror := false) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in points:
		var q: Vector2 = p
		if mirror:
			q.x = -q.x
		out.append(q.rotated(angle) * scale + offset)
	if mirror:
		out.reverse()
	return out


func _edge_dist(p: Vector2, poly: PackedVector2Array) -> float:
	var best := INF
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		best = minf(best, p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b)))
	return best


## Rasterises an icon. `shapes` is a list of polygons in -1..1 space.
func _icon(size: float, shapes: Array, fill: Color, outline: Color, disc: Color, ring: Color, thick := 1.0) -> ImageTexture:
	var n := int(size * SS)
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var line := 2.2 * thick / size  # outline width (in -1..1 space)
	for y in n:
		for x in n:
			var p := Vector2((x + 0.5) / n * 2.0 - 1.0, (y + 0.5) / n * 2.0 - 1.0)
			var c := Color(0, 0, 0, 0)
			var r := p.length()
			if disc.a > 0.0 and r <= 1.0:
				c = ring if r > 1.0 - 2.2 * 1.4 / size else disc
			var inside := false
			var near := false
			for poly in shapes:
				if Geometry2D.is_point_in_polygon(p, poly):
					inside = true
					break
				if _edge_dist(p, poly) < line:
					near = true
			if inside:
				c = fill
			elif near:
				c = outline
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


func _make_buttons() -> void:
	var white := Color(1, 1, 1, 0.82)
	var white_on := Color(1, 1, 1, 1.0)
	var dark := Color(0.05, 0.03, 0.08, 0.7)
	var none := Color(0, 0, 0, 0)
	var arrow_r := [_poly(ARROW)]
	var arrow_l := [_poly(ARROW, Vector2.ZERO, 1.0, 0.0, true)]
	var jump_icon := [_poly(CHEVRON, Vector2(0, -0.14), 0.95), _poly(CHEVRON, Vector2(0, 0.26), 0.7)]
	var sword_icon := []
	for part in [BLADE, GUARD, GRIP, POMMEL]:
		sword_icon.append(_poly(part, Vector2.ZERO, 0.95, PI / 4.0))
	var blue := Color(0.3, 0.5, 0.9, 0.3)
	var blue_ring := Color(0.7, 0.85, 1.0, 0.65)
	var red := Color(0.9, 0.35, 0.25, 0.3)
	var red_ring := Color(1.0, 0.75, 0.65, 0.65)
	var spec := {
		"left": [44.0, arrow_l, none, none],
		"right": [44.0, arrow_r, none, none],
		"jump": [46.0, jump_icon, blue, blue_ring],
		"attack": [46.0, sword_icon, red, red_ring],
	}
	for action in spec:
		var s: Array = spec[action]
		var b := TouchScreenButton.new()
		var disc: Color = s[2]
		var ring: Color = s[3]
		var thick := 2.2 if disc.a == 0.0 else 1.6
		b.texture_normal = _icon(s[0], s[1], white, dark, disc, ring, thick)
		b.texture_pressed = _icon(s[0], s[1], white_on, dark,
			Color(disc.r, disc.g, disc.b, disc.a * 2.0), Color(ring.r, ring.g, ring.b, minf(ring.a * 1.4, 1.0)), thick)
		b.scale = Vector2(1.0 / SS, 1.0 / SS)
		b.action = action
		b.passby_press = action in ["left", "right"]
		add_child(b)
		buttons[action] = b


func _layout() -> void:
	var size := get_viewport().get_visible_rect().size
	buttons["left"].position = Vector2(6, size.y - 50)
	buttons["right"].position = Vector2(54, size.y - 50)
	buttons["attack"].position = Vector2(size.x - 104, size.y - 50)
	buttons["jump"].position = Vector2(size.x - 54, size.y - 72)
