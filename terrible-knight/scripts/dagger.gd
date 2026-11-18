extends Area2D
## The Terrible Knight's thrown dagger: flies straight, hits one enemy for 1 damage.

var level: Node
var velocity := Vector2.ZERO
var life := 0.9
var sprite: Sprite2D


func _ready() -> void:
	collision_layer = 0
	collision_mask = Game.L_ENEMY_HURT | Game.L_WORLD
	add_child(Game.rect_shape(Vector2(18, 6)))
	sprite = Sprite2D.new()
	sprite.texture = load("res://assets/sprites/dagger.png")
	sprite.flip_h = velocity.x < 0
	add_child(sprite)
	area_entered.connect(_on_area)
	body_entered.connect(func(_b): _end())


func _on_area(a: Area2D) -> void:
	var target := a.get_parent()
	if target.has_method("take_hit"):
		target.take_hit(1, global_position - velocity.normalized() * 20.0)
		_end()


func _end() -> void:
	level.spawn_fx("fx_hit", global_position)
	queue_free()


func _physics_process(delta: float) -> void:
	position += velocity * delta
	life -= delta
	if life <= 0.0:
		queue_free()
