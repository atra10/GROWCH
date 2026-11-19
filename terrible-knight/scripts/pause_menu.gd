extends CanvasLayer
## Pause button (top-right) and pause menu: Resume, Restart from checkpoint, Quit to title.
## Also pauses on the Android back button and when the app goes to the background.

var level: Node
var open := false
var button: Button
var overlay: Control
var menu: VBoxContainer
var save_button: Button


func _ready() -> void:
	layer = 25
	process_mode = Node.PROCESS_MODE_ALWAYS

	button = Button.new()
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(26, 26)
	button.size = Vector2(26, 26)
	button.draw.connect(_draw_pause_icon)
	button.pressed.connect(toggle)
	add_child(button)

	overlay = ColorRect.new()
	(overlay as ColorRect).color = Color(0.02, 0.01, 0.05, 0.75)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.visible = false
	add_child(overlay)

	menu = VBoxContainer.new()
	menu.add_theme_constant_override("separation", 6)
	overlay.add_child(menu)
	var title := Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.95, 0.75, 0.5))
	menu.add_child(title)
	_menu_button("Resume", resume)
	save_button = _menu_button("Save game", _save)
	_menu_button("Restart from checkpoint", _restart)
	_menu_button("Quit to title", _quit)

	get_viewport().size_changed.connect(_layout)
	_layout()


func _menu_button(text: String, cb: Callable) -> Button:
	var b := Game.menu_button(text, cb)
	menu.add_child(b)
	return b


func _save() -> void:
	var ok := Game.save_game()
	save_button.text = "Saved!" if ok else "Could not save"
	await get_tree().create_timer(1.2, true).timeout
	if is_instance_valid(save_button):
		save_button.text = "Save game"


func _layout() -> void:
	var size := get_viewport().get_visible_rect().size
	button.position = Vector2(size.x - 30, 4)
	menu.reset_size()
	menu.position = (size - menu.size) / 2.0


func _draw_pause_icon() -> void:
	var a := 0.95 if open else 0.75
	button.draw_circle(Vector2(13, 13), 12.0, Color(0, 0, 0, 0.35))
	button.draw_arc(Vector2(13, 13), 12.0, 0, TAU, 32, Color(1, 1, 1, 0.5), 1.0)
	button.draw_rect(Rect2(8, 7, 3.5, 12), Color(1, 1, 1, a))
	button.draw_rect(Rect2(14.5, 7, 3.5, 12), Color(1, 1, 1, a))


func _can_pause() -> bool:
	return level != null and not level.finished and not level.dialogue.open \
		and level.player != null and not level.player.dead


func toggle() -> void:
	if open:
		resume()
	elif _can_pause():
		open = true
		overlay.visible = true
		get_tree().paused = true
		_layout()
		button.queue_redraw()


func resume() -> void:
	if not open:
		return
	open = false
	overlay.visible = false
	get_tree().paused = false
	button.queue_redraw()


func _restart() -> void:
	open = false
	Game.goto("level")


func _quit() -> void:
	open = false
	Game.goto("title")


func _process(_delta: float) -> void:
	# hide the button while dialogue covers the screen
	button.visible = level != null and not level.dialogue.open


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		toggle()
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		toggle()
	elif what == NOTIFICATION_APPLICATION_PAUSED or (what == NOTIFICATION_APPLICATION_FOCUS_OUT and OS.has_feature("mobile")):
		if not open:
			toggle()
