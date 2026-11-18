extends Area2D
## Heart pickup: heals 2.

var t := 0.0
var vy := -120.0
var base_y := 0.0
var landed := false


func _ready() -> void:
	collision_layer = Game.L_PICKUP
	collision_mask = Game.L_PLAYER
	add_child(Game.rect_shape(Vector2(14, 14)))
	body_entered.connect(_on_body)


func _on_body(b: Node) -> void:
	if b.has_method("heal"):
		b.heal(2)
		queue_free()


func _physics_process(delta: float) -> void:
	t += delta
	if not landed:
		vy += 600.0 * delta
		var space := get_world_2d().direct_space_state
		var q := PhysicsRayQueryParameters2D.create(global_position, global_position + Vector2(0, maxf(vy * delta, 0.0) + 8.0), Game.L_WORLD)
		var hit := space.intersect_ray(q)
		if hit and vy > 0.0:
			global_position.y = hit.position.y - 8.0
			landed = true
		else:
			position.y += vy * delta
		if position.y > 400:
			queue_free()
	queue_redraw()


func _draw() -> void:
	var s := 1.0 + 0.1 * sin(t * 6.0)
	var pts := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		# classic heart curve
		var x := 16.0 * pow(sin(a), 3)
		var y := -(13.0 * cos(a) - 5.0 * cos(2 * a) - 2.0 * cos(3 * a) - cos(4 * a))
		pts.append(Vector2(x, y) * 0.38 * s)
	draw_colored_polygon(pts, Color(0.9, 0.1, 0.2))
	draw_polyline(pts + PackedVector2Array([pts[0]]), Color(1, 0.8, 0.8), 1.0)
