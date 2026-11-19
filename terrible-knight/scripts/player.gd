extends CharacterBody2D
## The hero. Normally a werewolf; when the moon meter is full the player can call the
## moon and become the Terrible Knight for Game.KNIGHT_TIME seconds.
##
## Werewolf: faster, jumps higher, short lunge + claw slash (1 damage), takes full damage.
## Knight:   sword slash (2 damage, longer reach), throws daggers with the moon button,
##           armour: every hit only costs 1 (half a heart).

const ACCEL := 1000.0
const GRAVITY := 900.0
const MAX_FALL := 420.0
const COYOTE := 0.1
const JUMP_BUFFER := 0.12
const FORMS := {
	"wolf": {"speed": 135.0, "jump": -345.0, "body": Vector2(24, 26), "art": Vector2(8, -38)},
	"knight": {"speed": 115.0, "jump": -320.0, "body": Vector2(14, 36), "art": Vector2(0, -48)},
}
const DaggerScript := preload("res://scripts/dagger.gd")

var level: Node
var hp := Game.MAX_HP
var form := "wolf"
var knight_time := 0.0
var facing := 1
var invuln := 0.0
var hurt_time := 0.0
var attacking := false
var attack_time := 0.0        # wolf lunge timer
var attack_cooldown := 0.0
var dagger_cooldown := 0.0
var transform_time := 0.0     # short freeze while changing form
var hit_targets := []
var coyote := 0.0
var jump_buffer := 0.0
var safe_pos := Vector2.ZERO
var safe_time := 0.0
var dead := false
var controllable := true

var sprite: AnimatedSprite2D
var body_shape: CollisionShape2D
var hurtbox: Area2D
var hurt_shape: CollisionShape2D
var attack_area: Area2D
var attack_shape: CollisionShape2D


func _ready() -> void:
	collision_layer = Game.L_PLAYER
	collision_mask = Game.L_WORLD
	floor_snap_length = 4.0
	body_shape = Game.rect_shape(Vector2(14, 36), Vector2(0, -18))
	add_child(body_shape)

	sprite = Game.make_sprite(["wolf_idle", "wolf_run", "wolf_jump", "wolf_fall",
		"knight_idle", "knight_run", "knight_jump", "knight_slash", "knight_airslash", "knight_hurt"])
	sprite.animation_finished.connect(_on_anim_finished)
	sprite.frame_changed.connect(_on_frame_changed)
	add_child(sprite)

	hurtbox = Game.area(Vector2(12, 32), Vector2(0, -17), 0, Game.L_HAZARD)
	hurt_shape = hurtbox.get_child(0)
	add_child(hurtbox)

	attack_area = Game.area(Vector2(44, 40), Vector2(26, -22), 0, Game.L_ENEMY_HURT)
	attack_shape = attack_area.get_child(0)
	attack_area.monitoring = false
	add_child(attack_area)
	safe_pos = position
	_apply_form("wolf")


func _apply_form(f: String) -> void:
	form = f
	var spec: Dictionary = FORMS[f]
	var body: Vector2 = spec["body"]
	(body_shape.shape as RectangleShape2D).size = body
	body_shape.position = Vector2(0, -body.y / 2.0)
	(hurt_shape.shape as RectangleShape2D).size = body - Vector2(2, 4)
	hurt_shape.position = Vector2(0, -body.y / 2.0)
	var ra := attack_shape.shape as RectangleShape2D
	ra.size = Vector2(36, 26) if f == "wolf" else Vector2(48, 42)
	attacking = false
	attack_area.monitoring = false
	sprite.play(f + "_idle")


# ------------------------------------------------------------------ moon / form changes

func can_transform() -> bool:
	return form == "wolf" and Game.moon >= Game.MOON_MAX and not dead


func become_knight() -> void:
	Game.moon = 0.0
	knight_time = Game.KNIGHT_TIME
	_transform_fx()
	_apply_form("knight")


func become_wolf() -> void:
	knight_time = 0.0
	_transform_fx()
	_apply_form("wolf")


func _transform_fx() -> void:
	transform_time = 0.45
	invuln = maxf(invuln, 0.8)
	velocity = Vector2(0, minf(velocity.y, 0.0))
	level.shake(4.0)
	level.flash(Color(0.85, 0.9, 1.0), 0.35)
	level.spawn_fx("fx_transform", global_position + Vector2(0, -20))


# ------------------------------------------------------------------ main loop

func _physics_process(delta: float) -> void:
	if dead:
		return
	invuln = maxf(invuln - delta, 0.0)
	hurt_time = maxf(hurt_time - delta, 0.0)
	attack_cooldown -= delta
	dagger_cooldown -= delta
	sprite.visible = invuln <= 0.0 or transform_time > 0.0 or int(invuln * 20.0) % 2 == 0

	if form == "knight":
		knight_time -= delta
		if knight_time <= 0.0:
			become_wolf()

	if transform_time > 0.0:
		transform_time -= delta
		sprite.modulate = Color(2.5, 2.5, 3.0) if int(transform_time * 16.0) % 2 == 0 else Color.WHITE
		if transform_time <= 0.0:
			sprite.modulate = Color.WHITE
		velocity.x = 0.0
		velocity.y = minf(velocity.y + GRAVITY * delta * 0.3, MAX_FALL)
		move_and_slide()
		_update_anim()
		return

	var spec: Dictionary = FORMS[form]
	var dir := 0.0
	if controllable and hurt_time <= 0.0:
		dir = Input.get_axis("left", "right")

	# horizontal
	if attack_time > 0.0:
		# wolf lunge keeps its own speed
		attack_time -= delta
		velocity.x = facing * 290.0
		if attack_time <= 0.0:
			attacking = false
			attack_area.monitoring = false
			velocity.x = facing * 80.0
	elif hurt_time <= 0.0:
		var target: float = dir * spec["speed"]
		if attacking and is_on_floor():
			target *= 0.15
		velocity.x = move_toward(velocity.x, target, ACCEL * delta)
	if dir != 0.0 and not attacking:
		facing = 1 if dir > 0.0 else -1

	# vertical
	velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL)
	if attack_time > 0.0 and not is_on_floor():
		velocity.y = minf(velocity.y, 60.0)   # lunges float a little in the air
	if is_on_floor():
		coyote = COYOTE
	else:
		coyote -= delta
	jump_buffer -= delta
	if controllable and Input.is_action_just_pressed("jump"):
		jump_buffer = JUMP_BUFFER
	if jump_buffer > 0.0 and coyote > 0.0 and hurt_time <= 0.0:
		velocity.y = spec["jump"]
		jump_buffer = 0.0
		coyote = 0.0
	if not Input.is_action_pressed("jump") and velocity.y < -120.0:
		velocity.y = -120.0

	if controllable and hurt_time <= 0.0:
		if Input.is_action_just_pressed("attack") and not attacking and attack_cooldown <= 0.0:
			_start_attack()
		if Input.is_action_just_pressed("special"):
			_special()

	move_and_slide()

	# remember last safe ground for pit respawns
	if is_on_floor():
		safe_time += delta
		if safe_time > 0.1:
			safe_pos = position
	else:
		safe_time = 0.0

	_check_attack()
	_check_hurt()
	_update_anim()


func _special() -> void:
	if can_transform():
		become_knight()
	elif form == "knight" and dagger_cooldown <= 0.0:
		dagger_cooldown = 0.45
		var d := DaggerScript.new()
		d.level = level
		d.velocity = Vector2(facing * 300.0, 0)
		d.position = global_position + Vector2(facing * 14, -24)
		level.world.add_child(d)


func _start_attack() -> void:
	attacking = true
	hit_targets.clear()
	if form == "wolf":
		attack_time = 0.2
		attack_cooldown = 0.38
		attack_area.monitoring = true
		var claw := Game.make_sprite(["fx_claw"])
		claw.flip_h = facing < 0
		claw.position = Vector2(facing * 26, -18)
		claw.animation_finished.connect(claw.queue_free)
		add_child(claw)
		sprite.play("wolf_run")
	else:
		sprite.play("knight_airslash" if not is_on_floor() else "knight_slash")


func _on_frame_changed() -> void:
	if not attacking or form != "knight":
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
	if form == "wolf":
		attack_shape.position = Vector2(22.0 * facing, -14)
	else:
		attack_shape.position = Vector2(26.0 * facing, -22)
	if not attack_area.monitoring:
		return
	var dmg := 1 if form == "wolf" else 2
	for a in attack_area.get_overlapping_areas():
		var target: Node = a.get_parent()
		if target in hit_targets or not target.has_method("take_hit"):
			continue
		hit_targets.append(target)
		target.take_hit(dmg, global_position)
		level.spawn_fx("fx_hit", a.global_position.lerp(global_position + Vector2(20 * facing, -16), 0.5))


func _check_hurt() -> void:
	if invuln > 0.0:
		return
	for a in hurtbox.get_overlapping_areas():
		if a.has_meta("damage"):
			take_damage(a.get_meta("damage"), a.global_position)
			return


func take_damage(amount: int, from: Vector2, force := false) -> void:
	## force: ignore invincibility and armour (used for falling into pits).
	if dead or Game.god:
		return
	if invuln > 0.0 and not force:
		return
	if form == "knight" and not force:
		amount = 1   # armour
	hp -= amount
	level.hud.set_hp(hp)
	level.shake(3.0)
	invuln = 1.2
	hurt_time = 0.3
	attacking = false
	attack_time = 0.0
	attack_area.monitoring = false
	var away := 1.0 if global_position.x >= from.x else -1.0
	velocity = Vector2(away * 160.0, -170.0)
	if form == "knight":
		sprite.play("knight_hurt")
	else:
		sprite.play("wolf_jump")
	if hp <= 0:
		die()


func heal(amount: int) -> void:
	hp = mini(hp + amount, Game.MAX_HP)
	level.hud.set_hp(hp)


func die() -> void:
	dead = true
	sprite.visible = true
	velocity = Vector2.ZERO
	sprite.modulate = Color(1, 0.4, 0.4)
	sprite.pause()
	level.player_died()


func _update_anim() -> void:
	sprite.flip_h = facing < 0
	var art: Vector2 = FORMS[form]["art"]
	sprite.position = Vector2(art.x * facing, art.y)
	if dead or hurt_time > 0.0:
		return
	if form == "wolf":
		var anim := "wolf_idle"
		if attack_time > 0.0:
			anim = "wolf_run"
		elif not is_on_floor():
			anim = "wolf_jump" if velocity.y < 0.0 else "wolf_fall"
		elif absf(velocity.x) > 10.0:
			anim = "wolf_run"
		if sprite.animation != anim:
			sprite.play(anim)
		return
	if attacking:
		return
	var kanim := "knight_idle"
	if not is_on_floor():
		kanim = "knight_jump"
	elif absf(velocity.x) > 10.0:
		kanim = "knight_run"
	if sprite.animation != kanim:
		sprite.play(kanim)
