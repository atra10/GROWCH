extends CharacterBody2D
## Regular enemies. `kind` picks the behaviour:
## hound (runs at you), ogre (heavy, swings a club), crow (swoops),
## eye (hovers and dives), ghost (drifts through walls), skull (bounces around).

const GRAVITY := 900.0

var kind := "hound"
var level: Node
var hp := 1
var native_facing := -1     # which way the art faces (-1 = left)
var facing := -1
var flying := false
var active := false
var t := 0.0
var home := Vector2.ZERO
var flash := 0.0
var state := ""
var state_t := 0.0
var dir := Vector2.ZERO

var sprite: AnimatedSprite2D
var hazard: Area2D
var hurtbox: Area2D
var club: Area2D
var floor_ray: RayCast2D


func setup(k: String, lvl: Node, pos: Vector2) -> void:
	kind = k
	level = lvl
	position = pos
	home = pos


func _ready() -> void:
	collision_layer = Game.L_ENEMY
	collision_mask = Game.L_WORLD
	t = randf() * 10.0
	match kind:
		"hound":
			hp = 2
			sprite = Game.make_sprite(["hound_idle", "hound_run"])
			sprite.position = Vector2(0, -24)
			_body(Vector2(30, 18), Vector2(0, -10))
			floor_ray = RayCast2D.new()
			floor_ray.target_position = Vector2(0, 24)
			floor_ray.position = Vector2(-16, -8)
			add_child(floor_ray)
		"ogre":
			hp = 5
			native_facing = 1
			sprite = Game.make_sprite(["ogre_walk", "ogre_attack"])
			sprite.position = Vector2(0, -40)
			sprite.animation_finished.connect(_on_ogre_anim_done)
			_body(Vector2(28, 44), Vector2(0, -22))
			club = Game.area(Vector2(42, 36), Vector2(30, -20), Game.L_HAZARD, 0)
			club.set_meta("damage", 2)
			club.monitorable = false
			add_child(club)
			floor_ray = RayCast2D.new()
			floor_ray.target_position = Vector2(0, 24)
			floor_ray.position = Vector2(-18, -8)
			add_child(floor_ray)
			state = "walk"
		"crow":
			hp = 1
			flying = true
			sprite = Game.make_sprite(["crow_fly"])
			_body(Vector2(20, 14), Vector2.ZERO)
		"eye":
			hp = 1
			flying = true
			native_facing = 1
			sprite = Game.make_sprite(["eye_fly"])
			_body(Vector2(18, 18), Vector2.ZERO)
			state = "hover"
		"ghost":
			hp = 2
			flying = true
			sprite = Game.make_sprite(["ghost_chase"])
			sprite.modulate.a = 0.85
			_body(Vector2(26, 28), Vector2(0, -2))
		"skull":
			hp = 2
			flying = true
			sprite = Game.make_sprite(["skull"])
			sprite.scale = Vector2(0.55, 0.55)
			_body(Vector2(24, 26), Vector2(0, 4))
			dir = Vector2(-1, 0.6).normalized()
	add_child(sprite)
	if flying:
		collision_mask = 0


func _body(size: Vector2, pos: Vector2) -> void:
	add_child(Game.rect_shape(size, pos))
	hazard = Game.area(size * 0.8, pos, Game.L_HAZARD, 0)
	hazard.set_meta("damage", 1)
	add_child(hazard)
	hurtbox = Game.area(size + Vector2(6, 6), pos, Game.L_ENEMY_HURT, 0)
	add_child(hurtbox)


func _physics_process(delta: float) -> void:
	var player: Node2D = level.player
	if not active:
		if absf(player.global_position.x - global_position.x) < 260.0:
			active = true
		else:
			return
	t += delta
	state_t += delta
	if flash > 0.0:
		flash -= delta
		sprite.modulate = Color(3, 3, 3, sprite.modulate.a) if flash > 0.0 else Color(1, 1, 1, sprite.modulate.a)
	var to_p: Vector2 = player.global_position + Vector2(0, -18) - global_position
	match kind:
		"hound":
			_hound(delta, to_p)
		"ogre":
			_ogre(delta, to_p)
		"crow":
			facing = -1 if to_p.x < 0 else 1
			var target := Vector2(signf(to_p.x) * 70.0, to_p.y * 0.8 + sin(t * 3.0) * 40.0)
			velocity = velocity.lerp(target, delta * 2.0)
			position += velocity * delta
		"eye":
			_eye(delta, to_p)
		"ghost":
			facing = -1 if to_p.x < 0 else 1
			velocity = velocity.lerp(to_p.normalized() * 38.0, delta * 1.5)
			position += velocity * delta + Vector2(0, sin(t * 2.0) * 0.3)
			sprite.modulate.a = 0.55 + 0.35 * sin(t * 2.5)
		"skull":
			position += dir * 55.0 * delta
			if position.y < home.y - 50.0 or position.y > home.y + 30.0:
				dir.y = -dir.y
			if absf(position.x - home.x) > 90.0:
				dir.x = -dir.x
				position.x = clampf(position.x, home.x - 90.0, home.x + 90.0)
			facing = 1 if dir.x > 0 else -1
	sprite.flip_h = facing != native_facing
	if position.y > level.map_size.y + 100:
		queue_free()


func _hound(delta: float, to_p: Vector2) -> void:
	velocity.y = minf(velocity.y + GRAVITY * delta, 400.0)
	if state == "stun":
		if state_t > 0.3:
			state = ""
	elif absf(to_p.x) < 200.0:
		facing = -1 if to_p.x < 0 else 1
		velocity.x = move_toward(velocity.x, facing * 105.0, 400.0 * delta)
		sprite.play("hound_run")
	else:
		velocity.x = move_toward(velocity.x, 0, 400.0 * delta)
		sprite.play("hound_idle")
	floor_ray.position.x = 16.0 * facing
	floor_ray.force_raycast_update()
	if is_on_floor() and not floor_ray.is_colliding() and state != "stun":
		velocity.x = 0.0
		sprite.play("hound_idle")
	move_and_slide()


func _ogre(delta: float, to_p: Vector2) -> void:
	velocity.y = minf(velocity.y + GRAVITY * delta, 400.0)
	club.position.x = 0.0
	club.get_child(0).position.x = 30.0 * facing
	if state == "attack":
		velocity.x = 0.0
		var f := sprite.frame
		club.set_deferred("monitorable", f >= 3 and f <= 5)
	else:
		club.set_deferred("monitorable", false)
		if state == "stun":
			if state_t > 0.25:
				state = "walk"
		if absf(to_p.x) < 200.0:
			facing = -1 if to_p.x < 0 else 1
		velocity.x = facing * 32.0 if absf(to_p.x) > 30.0 else 0.0
		floor_ray.position.x = 18.0 * facing
		floor_ray.force_raycast_update()
		if is_on_floor() and not floor_ray.is_colliding():
			velocity.x = 0.0
		sprite.play("ogre_walk")
		if absf(to_p.x) < 56.0 and absf(to_p.y) < 40.0 and state_t > 1.0:
			state = "attack"
			state_t = 0.0
			sprite.play("ogre_attack")
	move_and_slide()


func _on_ogre_anim_done() -> void:
	state = "walk"
	state_t = 0.0


func _eye(delta: float, to_p: Vector2) -> void:
	facing = -1 if to_p.x < 0 else 1
	if state == "hover":
		var target := home + Vector2(sin(t) * 30.0, sin(t * 2.0) * 10.0)
		position = position.lerp(target, delta * 2.0)
		if state_t > 2.0 and to_p.length() < 150.0:
			state = "dive"
			state_t = 0.0
			dir = to_p.normalized()
	elif state == "dive":
		position += dir * 150.0 * delta
		if state_t > 1.0:
			state = "return"
			state_t = 0.0
	else:
		position = position.move_toward(home, 80.0 * delta)
		if position.distance_to(home) < 4.0:
			state = "hover"
			state_t = 0.0


func take_hit(dmg: int, from: Vector2) -> void:
	hp -= dmg
	flash = 0.1
	var away := 1.0 if global_position.x > from.x else -1.0
	if flying:
		position.x += away * 10.0
		if kind == "eye":
			state = "return"
			state_t = 0.0
	elif kind == "hound":
		velocity = Vector2(away * 140.0, -100.0)
		state = "stun"
		state_t = 0.0
	if hp <= 0:
		level.add_moon(Game.MOON_PER_KILL)
		level.spawn_fx("fx_death", global_position + Vector2(0, -12 if not flying else 0))
		if randf() < 0.25:
			level.spawn_heart(global_position + Vector2(0, -10))
		queue_free()
