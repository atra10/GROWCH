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
var labels := {}


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

func _circle_tex(r: int, col: Color) -> ImageTexture:
	var img := Image.create(r * 2, r * 2, false, Image.FORMAT_RGBA8)
	for y in r * 2:
		for x in r * 2:
			var d := Vector2(x - r + 0.5, y - r + 0.5).length()
			if d < r - 0.5:
				var edge := d > r - 3.0
				img.set_pixel(x, y, Color(col.r, col.g, col.b, 0.55 if edge else col.a))
	return ImageTexture.create_from_image(img)


func _make_buttons() -> void:
	var spec := {
		"left": ["<", 22, Color(1, 1, 1, 0.18)],
		"right": [">", 22, Color(1, 1, 1, 0.18)],
		"jump": ["JUMP", 24, Color(0.6, 0.8, 1, 0.22)],
		"attack": ["SWORD", 24, Color(1, 0.6, 0.5, 0.22)],
	}
	var pressed_tex := {}
	for action in spec:
		var s: Array = spec[action]
		var b := TouchScreenButton.new()
		b.texture_normal = _circle_tex(s[1], s[2])
		b.texture_pressed = _circle_tex(s[1], Color(s[2].r, s[2].g, s[2].b, 0.45))
		b.action = action
		b.passby_press = action in ["left", "right"]
		var l := Label.new()
		l.text = s[0]
		l.add_theme_font_size_override("font_size", 14 if s[0].length() == 1 else 8)
		l.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.size = Vector2(s[1] * 2, s[1] * 2)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(l)
		add_child(b)
		buttons[action] = b


func _layout() -> void:
	var size := get_viewport().get_visible_rect().size
	buttons["left"].position = Vector2(8, size.y - 52)
	buttons["right"].position = Vector2(58, size.y - 52)
	buttons["attack"].position = Vector2(size.x - 108, size.y - 50)
	buttons["jump"].position = Vector2(size.x - 56, size.y - 74)
