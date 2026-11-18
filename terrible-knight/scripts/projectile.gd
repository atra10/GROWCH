extends Area2D
## A hazard that flies in a straight line (optionally with gravity).

var velocity := Vector2.ZERO
var grav := 0.0
var life := 4.0
var native_facing := 1
var anim := "fx_fireball"
var spin := false
var breaks_on_world := true
var damage := 1
var homing := 0.0          # turn rate towards the player (0 = straight)
var speed := 0.0
var sprite: AnimatedSprite2D


func _ready() -> void:
	collision_layer = Game.L_HAZARD
	collision_mask = Game.L_WORLD if breaks_on_world else 0
	set_meta("damage", damage)
	sprite = Game.make_sprite([anim])
	add_child(sprite)
	body_entered.connect(func(_b): _pop())


func box(s: Vector2) -> void:
	add_child(Game.rect_shape(s))


func _physics_process(delta: float) -> void:
	if homing > 0.0:
		var lvl := get_tree().get_first_node_in_group("level")
		if lvl and lvl.player:
			var want: Vector2 = (lvl.player.global_position + Vector2(0, -18) - global_position).normalized() * speed
			velocity = velocity.lerp(want, homing * delta)
	velocity.y += grav * delta
	position += velocity * delta
	if spin:
		sprite.rotation = velocity.angle() if native_facing == 1 else velocity.angle() + PI
	else:
		sprite.flip_h = (velocity.x < 0) == (native_facing == 1)
	life -= delta
	if life <= 0.0:
		queue_free()


func _pop() -> void:
	var lvl := get_tree().get_first_node_in_group("level")
	if lvl:
		lvl.spawn_fx("fx_hit", global_position)
	queue_free()
