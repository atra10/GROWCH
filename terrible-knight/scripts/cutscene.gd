extends Node2D
## Intro (wolf -> Terrible Knight under the full moon) and the ending.

const DialogueScript := preload("res://scripts/dialogue.gd")

var kind := "intro"
var dialogue: CanvasLayer
var bg_layer: CanvasLayer
var stage: Node2D
var moon: Control
var fade: ColorRect
var moon_glow := 0.0
var dawn := 0.0
var ground_y := 170.0
var show_end := false
var end_t := 0.0


func _ready() -> void:
	var view := get_viewport().get_visible_rect().size
	ground_y = view.y - 40.0
	bg_layer = CanvasLayer.new()
	bg_layer.layer = -10
	add_child(bg_layer)
	var sky := ColorRect.new()
	sky.color = Color(0.06, 0.05, 0.12)
	sky.size = view
	bg_layer.add_child(sky)
	moon = Control.new()
	moon.size = view
	moon.draw.connect(_draw_moon)
	bg_layer.add_child(moon)
	for n in ["dusk_far_mountains", "dusk_mountains", "dusk_trees"]:
		var tex: Texture2D = load("res://assets/bg/%s.png" % n)
		var s := Sprite2D.new()
		s.texture = tex
		s.centered = false
		s.region_enabled = true
		s.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		var sc := view.y / tex.get_height()
		s.scale = Vector2(sc, sc)
		s.region_rect = Rect2(0, 0, view.x / sc + 2, tex.get_height())
		s.modulate = Color(0.55, 0.55, 0.8)
		bg_layer.add_child(s)

	stage = Node2D.new()
	add_child(stage)
	var ground_tex: Texture2D = load("res://assets/tiles/forest.png")
	var g := Sprite2D.new()
	g.texture = ground_tex
	g.centered = false
	g.region_enabled = true
	g.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	g.region_rect = Rect2(0, 0, view.x, ground_tex.get_height())
	g.position = Vector2(0, ground_y - 14)
	stage.add_child(g)
	var fill := ColorRect.new()
	fill.color = Color(0.17, 0.09, 0.05)
	fill.position = Vector2(0, ground_y - 14 + ground_tex.get_height())
	fill.size = Vector2(view.x, 100)
	stage.add_child(fill)

	dialogue = DialogueScript.new()
	add_child(dialogue)
	var fl := CanvasLayer.new()
	fl.layer = 30
	add_child(fl)
	fade = ColorRect.new()
	fade.color = Color.BLACK
	fade.size = Vector2(4000, 4000)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fl.add_child(fade)

	if kind == "intro":
		_intro()
	else:
		_ending()


func _process(delta: float) -> void:
	moon.queue_redraw()
	if show_end:
		end_t += delta


func _draw_moon() -> void:
	var view := moon.size
	var m := Vector2(view.x * 0.7, view.y * 0.28)
	var sky_col := Color(0.06, 0.05, 0.12).lerp(Color(0.85, 0.45, 0.3), dawn)
	moon.draw_rect(Rect2(Vector2.ZERO, view), sky_col)
	var glow := 0.03 + moon_glow * 0.08
	for i in 8:
		moon.draw_circle(m, 26.0 + i * 6.0 * (1.0 + moon_glow), Color(1, 0.95, 0.8, glow))
	moon.draw_circle(m, 24.0, Color(0.98, 0.95, 0.85, 1.0 - dawn * 0.8))
	moon.draw_circle(m + Vector2(-7, -5), 5.0, Color(0.88, 0.85, 0.75, 1.0 - dawn * 0.8))
	moon.draw_circle(m + Vector2(8, 7), 3.0, Color(0.88, 0.85, 0.75, 1.0 - dawn * 0.8))
	if show_end:
		var font := ThemeDB.fallback_font
		var a := clampf(end_t, 0.0, 1.0)
		moon.draw_string(font, Vector2(0, view.y * 0.45), "THE END", HORIZONTAL_ALIGNMENT_CENTER, view.x, 24, Color(1, 0.9, 0.8, a))
		var mins := int(Game.play_time) / 60
		var secs := int(Game.play_time) % 60
		moon.draw_string(font, Vector2(0, view.y * 0.58), "Time %d:%02d   Falls %d" % [mins, secs, Game.deaths], HORIZONTAL_ALIGNMENT_CENTER, view.x, 10, Color(1, 1, 1, a * 0.8))
		moon.draw_string(font, Vector2(0, view.y * 0.68), "Thank you for playing", HORIZONTAL_ALIGNMENT_CENTER, view.x, 10, Color(1, 1, 1, a * 0.8))


func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _fade_to(a: float, t: float, col := Color.BLACK) -> void:
	fade.color = Color(col.r, col.g, col.b, fade.color.a)
	var tw := create_tween()
	tw.tween_property(fade, "color:a", a, t)
	await tw.finished


func _intro() -> void:
	var view := get_viewport().get_visible_rect().size
	await _fade_to(0.0, 1.0)
	await dialogue.run(Game.INTRO_LINES_1)
	var wolf := Game.make_sprite(["wolf_idle", "wolf_run"], "wolf_run")
	wolf.position = Vector2(-50, ground_y - 38)
	stage.add_child(wolf)
	var tw := create_tween()
	tw.tween_property(wolf, "position:x", view.x * 0.4, 2.2)
	await tw.finished
	wolf.play("wolf_idle")
	await _wait(0.6)
	# the moon calls
	var tw2 := create_tween()
	tw2.tween_property(self, "moon_glow", 1.0, 1.5)
	await tw2.finished
	for i in 3:
		wolf.modulate = Color(3, 3, 3)
		await _wait(0.12)
		wolf.modulate = Color.WHITE
		await _wait(0.2)
	fade.color = Color(1, 1, 1, 1)
	var knight := Game.make_sprite(["knight_idle"])
	knight.position = Vector2(wolf.position.x, ground_y - 48)
	stage.add_child(knight)
	wolf.queue_free()
	moon_glow = 0.3
	await _fade_to(0.0, 1.2, Color.WHITE)
	await dialogue.run([Game.INTRO_LINES_2[0]])
	var vision := Game.make_sprite(["heroine_idle"])
	vision.flip_h = true
	vision.position = Vector2(view.x * 0.62, ground_y - 50)
	vision.modulate = Color(0.6, 0.85, 1.4, 0.0)
	stage.add_child(vision)
	var tw3 := create_tween()
	tw3.tween_property(vision, "modulate:a", 0.75, 0.8)
	await tw3.finished
	await dialogue.run(Game.INTRO_LINES_2.slice(1))
	var tw4 := create_tween()
	tw4.tween_property(vision, "modulate:a", 0.0, 0.8)
	await tw4.finished
	knight.sprite_frames = Game.frames(["knight_run"])
	knight.play("knight_run")
	var tw5 := create_tween()
	tw5.tween_property(knight, "position:x", view.x + 60, 1.6)
	await _wait(0.8)
	await _fade_to(1.0, 0.8)
	Game.start_stage(0)


func _ending() -> void:
	var view := get_viewport().get_visible_rect().size
	var knight := Game.make_sprite(["knight_idle"])
	knight.position = Vector2(view.x * 0.45, ground_y - 48)
	stage.add_child(knight)
	await _fade_to(0.0, 1.5)
	await dialogue.run(Game.ENDING_LINES.slice(0, 2))
	var tw := create_tween()
	tw.tween_property(self, "dawn", 1.0, 3.0)
	await tw.finished
	await dialogue.run([Game.ENDING_LINES[2]])
	for i in 3:
		knight.modulate = Color(3, 3, 3)
		await _wait(0.12)
		knight.modulate = Color.WHITE
		await _wait(0.2)
	fade.color = Color(1, 1, 1, 1)
	var wolf := Game.make_sprite(["wolf_idle", "wolf_run"], "wolf_idle")
	wolf.position = Vector2(knight.position.x, ground_y - 38)
	stage.add_child(wolf)
	knight.queue_free()
	await _fade_to(0.0, 1.2, Color.WHITE)
	await dialogue.run([Game.ENDING_LINES[3]])
	wolf.play("wolf_run")
	var tw2 := create_tween()
	tw2.tween_property(wolf, "position:x", view.x + 60, 3.0)
	await tw2.finished
	await dialogue.run([Game.ENDING_LINES[4]])
	show_end = true
	await _wait(2.5)
	set_process_input(true)
	var done := false
	while not done:
		await get_tree().process_frame
		if Input.is_action_just_pressed("attack") or Input.is_action_just_pressed("jump") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or _touched:
			done = true
	Game.goto("title")


var _touched := false


func _input(event: InputEvent) -> void:
	if show_end and event is InputEventScreenTouch and event.pressed:
		_touched = true
