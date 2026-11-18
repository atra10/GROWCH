extends CanvasLayer
## Dialogue box with a speaker portrait. Pauses the game while open.
## Usage:  await dialogue.run([["Princess", "Hello"], ["", "Narration"]])
## Tap the screen (or press attack / jump) to advance.

signal finished

var lines: Array = []
var index := 0
var typing := 0.0
var cooldown := 0.0
var open := false

var panel: ColorRect
var name_label: Label
var text_label: Label
var hint: Label
var portrait: AnimatedSprite2D
var portrait_box: Control


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel = ColorRect.new()
	panel.color = Color(0.05, 0.03, 0.08, 0.88)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	var border := ReferenceRect.new()
	border.border_color = Color(0.8, 0.6, 0.4, 0.8)
	border.editor_only = false
	border.set_anchors_preset(Control.PRESET_FULL_RECT)
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(border)

	portrait_box = Control.new()
	portrait_box.clip_contents = true
	portrait_box.size = Vector2(48, 56)
	portrait_box.position = Vector2(6, 6)
	portrait_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(portrait_box)
	portrait = AnimatedSprite2D.new()
	portrait_box.add_child(portrait)

	name_label = Label.new()
	name_label.add_theme_font_size_override("font_size", 9)
	name_label.add_theme_color_override("font_color", Color(0.95, 0.75, 0.5))
	panel.add_child(name_label)
	text_label = Label.new()
	text_label.add_theme_font_size_override("font_size", 10)
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(text_label)
	hint = Label.new()
	hint.text = "tap >"
	hint.add_theme_font_size_override("font_size", 7)
	hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	panel.add_child(hint)
	visible = false


func run(new_lines: Array) -> void:
	if new_lines.is_empty():
		return
	lines = new_lines
	index = 0
	open = true
	visible = true
	get_tree().paused = true
	_layout()
	_show_line()
	await finished


func _layout() -> void:
	var size := get_viewport().get_visible_rect().size
	var w := minf(size.x - 16, 420.0)
	panel.size = Vector2(w, 68)
	panel.position = Vector2((size.x - w) / 2.0, 6)


func _show_line() -> void:
	var line: Array = lines[index]
	var who: String = line[0]
	name_label.text = who
	text_label.text = line[1]
	text_label.visible_ratio = 0.0
	typing = 0.0
	cooldown = 0.2
	var has_portrait := who != ""
	portrait_box.visible = has_portrait
	var x0 := 60.0 if has_portrait else 10.0
	name_label.position = Vector2(x0, 4)
	text_label.position = Vector2(x0, 16 if has_portrait else 10)
	text_label.size = Vector2(panel.size.x - x0 - 10, 46)
	hint.position = Vector2(panel.size.x - 30, 56)
	match who:
		"Princess":
			portrait.sprite_frames = Game.frames(["heroine_idle"])
			portrait.play("heroine_idle")
			portrait.scale = Vector2(2, 2)
			portrait.position = Vector2(24, 14)
			portrait.modulate = Color(0.75, 0.9, 1.3, 0.9)
		"Death":
			portrait.sprite_frames = Game.frames(["death_walk"])
			portrait.play("death_walk")
			portrait.scale = Vector2(1.6, 1.6)
			portrait.position = Vector2(24, 30)
			portrait.modulate = Color.WHITE
		"Demon":
			portrait.sprite_frames = Game.frames(["demon_idle"])
			portrait.play("demon_idle")
			portrait.scale = Vector2(0.5, 0.5)
			portrait.position = Vector2(14, 30)
			portrait.modulate = Color.WHITE
		_:
			portrait.sprite_frames = Game.frames(["knight_idle"])
			portrait.play("knight_idle")
			portrait.scale = Vector2(1.6, 1.6)
			portrait.position = Vector2(24, 8)
			portrait.modulate = Color.WHITE


func _process(delta: float) -> void:
	if not open:
		return
	cooldown -= delta
	var n := maxi(text_label.text.length(), 1)
	typing += delta * 45.0
	text_label.visible_ratio = minf(typing / n, 1.0)
	hint.visible = text_label.visible_ratio >= 1.0 and int(Time.get_ticks_msec() / 400) % 2 == 0


func _input(event: InputEvent) -> void:
	if not open:
		return
	var tapped: bool = (event is InputEventScreenTouch and event.pressed) \
		or event.is_action_pressed("attack") or event.is_action_pressed("jump")
	if not tapped or cooldown > 0.0:
		return
	get_viewport().set_input_as_handled()
	cooldown = 0.15
	if text_label.visible_ratio < 1.0:
		typing = 9999.0
		return
	index += 1
	if index < lines.size():
		_show_line()
	else:
		open = false
		visible = false
		get_tree().paused = false
		finished.emit()
