extends CharacterBody2D
## The Terrible Knight.

const SPEED := 115.0
const ACCEL := 1000.0
const GRAVITY := 900.0
const JUMP_VELOCITY := -320.0
const MAX_FALL := 420.0
const COYOTE := 0.1
const JUMP_BUFFER := 0.12

var level: Node
var hp := Game.MAX_HP
var facing := 1
var invuln := 0.0
var hurt_time := 0.0
var attacking := false
var hit_targets := []
var coyote := 0.0
var jump_buffer := 0.0
var safe_pos := Vector2.ZERO
var safe_time := 0.0
var dead := false
var controllable := true

var sprite: AnimatedSprite2D
var hurtbox: Area2D
var attack_area: Area2D
var attack_shape: CollisionShape2D


func _ready() -> void:
	collision_layer = Game.L_PLAYER
	collision_mask = Game.L_WORLD
	floor_snap_length = 4.0
	add_child(Game.rect_shape(Vector2(14, 36), Vector2(0, -18)))

	sprite = Game.make_sprite(["knight_idle", "knight_run", "knight_jump", "knight_slash", "knight_airslash", "knight_hurt"])
	sprite.position = Vector2(0, -48)
	sprite.animation_finished.connect(_on_anim_finished)
	sprite.frame_changed.connect(_on_frame_changed)
	add_child(sprite)

	hurtbox = Game.area(Vector2(12, 32), Vector2(0, -17), 0, Game.L_HAZARD)
	add_child(hurtbox)

	attack_area = Game.area(Vector2(44, 40), Vector2(26, -22), 0, Game.L_ENEMY_HURT)
	attack_shape = attack_area.get_child(0)
	attack_area.monitoring = false
	add_child(attack_area)
	safe_pos = position


func _physics_process(delta: float) -> void:
	if dead:
		return
	invuln = maxf(invuln - delta, 0.0)
	hurt_time = maxf(hurt_time - delta, 0.0)
	sprite.visible = invuln <= 0.0 or int(invuln * 20.0) % 2 == 0

	var dir := 0.0
	if controllable and hurt_time <= 0.0:
		dir = Input.get_axis("left", "right")

	# horizontal
	var target := dir * SPEED
	if attacking and is_on_floor():
		target *= 0.15
	if hurt_time <= 0.0:
		velocity.x = move_toward(velocity.x, target, ACCEL * delta)
	if dir != 0.0 and not attacking:
		facing = 1 if dir > 0.0 else -1

	# vertical
	velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL)
	if is_on_floor():
		coyote = COYOTE
	else:
		coyote -= delta
	jump_buffer -= delta
	if controllable and Input.is_action_just_pressed("jump"):
		jump_buffer = JUMP_BUFFER
	if jump_buffer > 0.0 and coyote > 0.0 and hurt_time <= 0.0:
		velocity.y = JUMP_VELOCITY
		jump_buffer = 0.0
		coyote = 0.0
	if not Input.is_action_pressed("jump") and velocity.y < -120.0:
		velocity.y = -120.0

	if controllable and Input.is_action_just_pressed("attack") and not attacking and hurt_time <= 0.0:
		_start_attack()

	move_and_slide()

	# remember last safe ground for pit respawns
	if is_on_floor():
		safe_time += delta
		if safe_time > 0.25:
			safe_pos = position
	else:
		safe_time = 0.0

	_check_attack()
	_check_hurt()
	_update_anim()


func _start_attack() -> void:
	attacking = true
	hit_targets.clear()
	sprite.play("knight_airslash" if not is_on_floor() else "knight_slash")


func _on_frame_changed() -> void:
	if not attacking:
		return
	var f := sprite.frame
	if sprite.animation == "knight_slash":
		attack_area.monitoring = f >= 1 and f <= 4
	elif sprite.animation == "knight_airslash":
		attack_area.monitoring = f >= 1 and f <= 5
	else:
		attack_area.monitoring = false


func _on_anim_finished() -> void:
	if sprite.animation in ["knight_slash", "knight_airslash"]:
		attacking = false
		attack_area.monitoring = false


func _check_attack() -> void:
	attack_shape.position.x = 26.0 * facing
	if not attack_area.monitoring:
		return
	for a in attack_area.get_overlapping_areas():
		var target: Node = a.get_parent()
		if target in hit_targets or not target.has_method("take_hit"):
			continue
		hit_targets.append(target)
		target.take_hit(1, global_position)
		level.spawn_fx("fx_hit", a.global_position.lerp(global_position + Vector2(20 * facing, -20), 0.5))


func _check_hurt() -> void:
	if invuln > 0.0:
		return
	for a in hurtbox.get_overlapping_areas():
		if a.has_meta("damage"):
			take_damage(a.get_meta("damage"), a.global_position)
			return


func take_damage(amount: int, from: Vector2) -> void:
	if dead or invuln > 0.0 or Game.god:
		return
	hp -= amount
	level.hud.set_hp(hp)
	level.shake(3.0)
	invuln = 1.2
	hurt_time = 0.3
	attacking = false
	attack_area.monitoring = false
	var away := 1.0 if global_position.x >= from.x else -1.0
	velocity = Vector2(away * 160.0, -170.0)
	sprite.play("knight_hurt")
	if hp <= 0:
		die()


func heal(amount: int) -> void:
	hp = mini(hp + amount, Game.MAX_HP)
	level.hud.set_hp(hp)


func die() -> void:
	dead = true
	sprite.visible = true
	sprite.play("knight_hurt")
	velocity = Vector2.ZERO
	level.player_died()


func _update_anim() -> void:
	sprite.flip_h = facing < 0
	if attacking or dead:
		return
	if hurt_time > 0.0:
		return
	var anim := "knight_idle"
	if not is_on_floor():
		anim = "knight_jump"
	elif absf(velocity.x) > 10.0:
		anim = "knight_run"
	if sprite.animation != anim:
		sprite.play(anim)
