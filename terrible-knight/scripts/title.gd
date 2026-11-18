extends Node2D
## Title screen.

var t := 0.0
var wolf: AnimatedSprite2D
var knight: AnimatedSprite2D
var ui: CanvasLayer
var started := false


func _ready() -> void:
	ui = CanvasLayer.new()
	add_child(ui)
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.03, 0.08)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(bg)
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func(): _draw_ui(c))
	ui.add_child(c)
	set_process(true)
	wolf = Game.make_sprite(["wolf_idle"])
	knight = Game.make_sprite(["knight_idle"])
	ui.add_child(wolf)
	ui.add_child(knight)


func _process(delta: float) -> void:
	t += delta
	var size := get_viewport().get_visible_rect().size
	wolf.position = Vector2(size.x / 2.0 - 50, size.y * 0.55)
	knight.position = Vector2(size.x / 2.0 + 50, size.y * 0.55 - 10)
	knight.flip_h = true
	for n in ui.get_children():
		if n is Control:
			n.queue_redraw()


func _draw_ui(c: Control) -> void:
	var size := c.size
	var font := ThemeDB.fallback_font
	# full moon
	var m := Vector2(size.x / 2.0, size.y * 0.3)
	for i in 6:
		c.draw_circle(m, 34.0 + i * 5.0, Color(1, 0.95, 0.8, 0.03))
	c.draw_circle(m, 30.0, Color(0.98, 0.95, 0.85))
	c.draw_circle(m + Vector2(-9, -6), 6.0, Color(0.88, 0.85, 0.75))
	c.draw_circle(m + Vector2(10, 8), 4.0, Color(0.88, 0.85, 0.75))
	c.draw_string(font, Vector2(0, size.y * 0.14), "THE TERRIBLE KNIGHT", HORIZONTAL_ALIGNMENT_CENTER, size.x, 22, Color(0.95, 0.3, 0.25))
	var a := 0.5 + 0.5 * sin(t * 4.0)
	c.draw_string(font, Vector2(0, size.y * 0.86), "Tap to begin", HORIZONTAL_ALIGNMENT_CENTER, size.x, 11, Color(1, 1, 1, a))
	c.draw_string(font, Vector2(0, size.y * 0.95), "Keyboard: arrows/A-D move, Space jump, J/X attack, L/C moon", HORIZONTAL_ALIGNMENT_CENTER, size.x, 7, Color(1, 1, 1, 0.4))


func _input(event: InputEvent) -> void:
	if started or t < 0.4:
		return
	if (event is InputEventScreenTouch and event.pressed) or event.is_action_pressed("attack") or event.is_action_pressed("jump"):
		started = true
		Game.new_game()
