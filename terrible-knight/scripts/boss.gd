extends Node2D
## All five bosses. `kind` picks the behaviour:
## hellbeast, nightmare, dragon, death, demon.
## The boss's origin sits on the ground (except the demon, whose origin is its body centre).

signal defeated

var kind := "hellbeast"
var level: Node
var hp := 10
var max_hp := 10
var active := false
var dead := false
var facing := -1
var native_facing := -1
var art_offset := Vector2.ZERO   # sprite offset when facing the art's native direction
var state := "idle"
var state_t := 0.0
var t := 0.0
var cycle := 0
var flash := 0.0
var invulnerable := false
var ground_y := 0.0
var arena := Vector2.ZERO        # x range the boss may use
var vel := Vector2.ZERO
var target := Vector2.ZERO
var shots_left := 0
var fired := false

var sprite: AnimatedSprite2D
var hurtbox: Area2D
var hazard: Area2D
var attack_box: Area2D           # extra hazard used by special attacks


func setup(k: String, lvl: Node, pos: Vector2, arena_range: Vector2) -> void:
	kind = k
	level = lvl
	position = pos
	ground_y = pos.y
	arena = arena_range


func _ready() -> void:
	match kind:
		"hellbeast":
			max_hp = 16
			native_facing = 1
			sprite = Game.make_sprite(["hellbeast_idle", "hellbeast_breath", "hellbeast_burn"])
			sprite.scale = Vector2(1.4, 1.4)
			art_offset = Vector2(-1, -80 * 1.4)
			_boxes(Vector2(52, 80), Vector2(0, -40), Vector2(40, 70), Vector2(0, -36))
			attack_box = _extra(Vector2(110, 100), Vector2(0, -50), 1)
		"nightmare":
			max_hp = 20
			sprite = Game.make_sprite(["nightmare_idle", "nightmare_run"])
			art_offset = Vector2(-4, -48)
			_boxes(Vector2(70, 50), Vector2(0, -30), Vector2(66, 40), Vector2(0, -28))
		"dragon":
			max_hp = 24
			sprite = Game.make_sprite(["dragon_idle", "dragon_breath", "dragon_tail"])
			sprite.scale = Vector2(1.6, 1.6)
			art_offset = Vector2(-23 * 1.6, -32 * 1.6)
			_boxes(Vector2(100, 56), Vector2(0, -30), Vector2(86, 46), Vector2(0, -26))
			attack_box = _extra(Vector2(200, 34), Vector2(0, -16), 2)
		"death":
			max_hp = 24
			native_facing = 1
			sprite = Game.make_sprite(["death_rise", "death_walk"])
			sprite.scale = Vector2(2, 2)
			art_offset = Vector2(-2, -48)
			sprite.stop()
			sprite.frame = 0
			_boxes(Vector2(40, 58), Vector2(0, -30), Vector2(28, 50), Vector2(0, -28))
		"demon":
			max_hp = 36
			sprite = Game.make_sprite(["demon_idle", "demon_attack", "demon_breath"])
			sprite.scale = Vector2(0.8, 0.8)
			art_offset = Vector2(-26 * 0.8, 2)
			_boxes(Vector2(72, 104), Vector2(0, 0), Vector2(52, 90), Vector2(0, 0))
			attack_box = _extra(Vector2(80, 46), Vector2(-80, 49), 2)
			sprite.frame_changed.connect(_demon_frame)
	hp = max_hp
	add_child(sprite)
	move_child(sprite, 0)
	_face(-1)


func _boxes(hurt_size: Vector2, hurt_pos: Vector2, haz_size: Vector2, haz_pos: Vector2) -> void:
	hurtbox = Game.area(hurt_size, hurt_pos, Game.L_ENEMY_HURT, 0)
	add_child(hurtbox)
	hazard = Game.area(haz_size, haz_pos, Game.L_HAZARD, 0)
	hazard.set_meta("damage", 1)
	add_child(hazard)


func _extra(size: Vector2, pos: Vector2, dmg: int) -> Area2D:
	var a := Game.area(size, pos, Game.L_HAZARD, 0)
	a.set_meta("damage", dmg)
	a.monitorable = false
	add_child(a)
	return a


func _face(dir: int) -> void:
	facing = dir
	sprite.flip_h = dir != native_facing
	sprite.position = Vector2(art_offset.x * (1 if dir == native_facing else -1), art_offset.y)


func _face_player() -> void:
	_face(-1 if level.player.global_position.x < global_position.x else 1)


func _set_attack(on: bool) -> void:
	if attack_box:
		attack_box.set_deferred("monitorable", on)


func _go(s: String) -> void:
	state = s
	state_t = 0.0
	fired = false


func activate() -> void:
	active = true
	level.hud.show_boss(Game.STAGES[Game.stage_index]["boss_name"], max_hp)
	if kind == "death":
		sprite.play("death_rise")
		_go("rise")


func rage() -> float:
	## 1.0 at full health, up to 1.6 when nearly dead: bosses get faster as they weaken.
	return 1.0 + 0.6 * (1.0 - float(hp) / max_hp)


func _physics_process(delta: float) -> void:
	t += delta
	if flash > 0.0:
		flash -= delta
		sprite.modulate = Color(4, 4, 4) if flash > 0.0 else Color.WHITE
	if not active or dead:
		if kind == "demon":
			position.y = ground_y + sin(t * 2.0) * 4.0
		return
	state_t += delta * rage()
	match kind:
		"hellbeast": _hellbeast(delta)
		"nightmare": _nightmare(delta)
		"dragon": _dragon(delta)
		"death": _death(delta)
		"demon": _demon(delta)


# ------------------------------------------------------------------ HELL BEAST

func _hellbeast(_delta: float) -> void:
	_face_player()
	match state:
		"idle":
			if sprite.animation != "hellbeast_idle":
				sprite.play("hellbeast_idle")
			if state_t > 1.3:
				cycle += 1
				if cycle % 4 == 0:
					_go("burn")
					sprite.play("hellbeast_burn")
					_set_attack(true)
				else:
					_go("breath")
					sprite.play("hellbeast_breath")
		"breath":
			if state_t > 0.45 and not fired:
				fired = true
				var mouth := global_position + Vector2(18 * facing, -96)
				if cycle % 2 == 1:
					# three arcing fireballs
					var dx: float = level.player.global_position.x - mouth.x
					for i in 3:
						var vx := dx / (1.1 + i * 0.25)
						_shoot("hellbeast_fireball", mouth, Vector2(vx, -260 + i * 30), 520.0, Vector2(12, 12), 1)
				else:
					# two low fireballs to jump over
					_low_fireball()
					get_tree().create_timer(0.45).timeout.connect(_low_fireball)
			if state_t > 1.2:
				_go("idle")
		"burn":
			if state_t > 2.2:
				_set_attack(false)
				_go("idle")


func _low_fireball() -> void:
	if not dead:
		_shoot("hellbeast_fireball", global_position + Vector2(20 * facing, -14), Vector2(150 * facing, 0), 0.0, Vector2(14, 12), 1)


# ------------------------------------------------------------------ NIGHTMARE

func _nightmare(delta: float) -> void:
	match state:
		"idle":
			sprite.play("nightmare_idle")
			_face_player()
			if state_t > 1.4:
				cycle += 1
				_go("windup" if cycle % 3 != 0 else "leap")
				if state == "leap":
					target = Vector2(clampf(level.player.global_position.x, arena.x, arena.y), ground_y)
					vel = Vector2((target.x - position.x) / 0.9, -380)
		"windup":
			sprite.play("nightmare_run")
			sprite.position.x = art_offset.x * (1 if facing == native_facing else -1) + sin(t * 60.0) * 2.0
			if state_t > 0.5:
				_go("charge")
				hazard.set_meta("damage", 2)
		"charge":
			position.x += facing * 270.0 * rage() * delta
			if position.x < arena.x or position.x > arena.y:
				position.x = clampf(position.x, arena.x, arena.y)
				hazard.set_meta("damage", 1)
				level.shake(4.0)
				_face(-facing)
				_go("idle")
		"leap":
			sprite.play("nightmare_run")
			vel.y += 850.0 * delta
			position += vel * delta
			position.x = clampf(position.x, arena.x, arena.y)
			if position.y >= ground_y and vel.y > 0:
				position.y = ground_y
				level.shake(5.0)
				for d in [-1, 1]:
					_shoot("fx_fireball", global_position + Vector2(d * 30, -10), Vector2(d * 140, 0), 0.0, Vector2(22, 12), 1)
				_go("idle")


# ------------------------------------------------------------------ DRAGON

func _dragon(delta: float) -> void:
	match state:
		"idle":
			sprite.play("dragon_idle")
			_face_player()
			# drift slowly toward the player but keep some distance
			var dx: float = level.player.global_position.x - position.x
			if absf(dx) > 140.0:
				position.x += signf(dx) * 25.0 * delta
			if state_t > 1.2:
				cycle += 1
				if absf(dx) < 90.0:
					_go("tail")
					sprite.play("dragon_tail")
				elif cycle % 4 == 0:
					_go("hop")
					var to_x := arena.x + 40.0 if position.x > (arena.x + arena.y) / 2.0 else arena.y - 40.0
					vel = Vector2((to_x - position.x) / 1.0, -420)
				else:
					shots_left = 3
					_go("breath")
					sprite.play("dragon_breath")
		"breath":
			if sprite.frame >= 3 and not fired:
				fired = true
				var high := randf() < 0.45
				var y := -54.0 if high else -14.0
				_shoot("fx_fireball", global_position + Vector2(facing * 70, y), Vector2(facing * 170, 0), 0.0, Vector2(24, 12), 1)
			if not sprite.is_playing():
				shots_left -= 1
				if shots_left > 0:
					_face_player()
					_go("breath")
					sprite.play("dragon_breath")
					sprite.frame = 0
				else:
					_go("idle")
		"tail":
			var f := sprite.frame
			_set_attack(f >= 2 and f <= 6)
			if not sprite.is_playing():
				_set_attack(false)
				_go("idle")
		"hop":
			sprite.play("dragon_idle")
			vel.y += 840.0 * delta
			position += vel * delta
			if position.y >= ground_y and vel.y > 0:
				position.y = ground_y
				position.x = clampf(position.x, arena.x, arena.y)
				level.shake(6.0)
				_go("idle")


# ------------------------------------------------------------------ DEATH

func _death(delta: float) -> void:
	var bob := sin(t * 3.0) * 3.0
	sprite.position.y = art_offset.y + bob
	match state:
		"rise":
			if not sprite.is_playing():
				sprite.play("death_walk")
				_go("walk")
		"walk":
			_face_player()
			position.x += facing * 38.0 * delta
			position.x = clampf(position.x, arena.x, arena.y)
			if state_t > 2.6:
				cycle += 1
				_go("vanish" if cycle % 2 == 1 else "summon")
		"vanish":
			invulnerable = true
			hazard.set_deferred("monitorable", false)
			sprite.modulate.a = clampf(1.0 - state_t / 0.5, 0.0, 1.0)
			if state_t > 0.7:
				var px: float = level.player.global_position.x
				var side := -1.0 if randf() < 0.5 else 1.0
				var nx := px + side * 80.0
				if nx < arena.x or nx > arena.y:
					nx = px - side * 80.0
				position.x = clampf(nx, arena.x, arena.y)
				_face_player()
				_go("appear")
		"appear":
			sprite.modulate.a = clampf(state_t / 0.5, 0.0, 1.0)
			if state_t > 0.6:
				invulnerable = false
				hazard.set_deferred("monitorable", true)
				sprite.modulate.a = 1.0
				_go("summon")
		"summon":
			if state_t > 0.3 and not fired:
				fired = true
				var n := 2 if hp > max_hp / 2 else 3
				for i in n:
					var p := _shoot("spirit", global_position + Vector2(facing * 20, -70 - i * 14), Vector2(facing * 40, -60 + i * 40), 0.0, Vector2(14, 14), 1)
					p.homing = 1.4
					p.speed = 70.0
					p.life = 5.0
					p.breaks_on_world = false
					p.collision_mask = 0
					p.sprite.scale = Vector2(0.5, 0.5)
				if hp <= max_hp / 2:
					for i in 3:
						var x := randf_range(arena.x, arena.y)
						_shoot("hellbeast_fireball", Vector2(x, ground_y - 200 - i * 40), Vector2(0, 60), 300.0, Vector2(12, 12), 1).spin = true
			if state_t > 1.4:
				_go("walk")


# ------------------------------------------------------------------ DEMON

func _demon(delta: float) -> void:
	var hover_y := ground_y + sin(t * 2.0) * 5.0
	match state:
		"idle":
			sprite.play("demon_idle")
			_face_player()
			position.y = lerpf(position.y, hover_y, delta * 3.0)
			position.x = move_toward(position.x, target.x, 60.0 * delta)
			if state_t > 1.6:
				cycle += 1
				_face_player()
				if cycle % 3 == 0:
					_go("breath")
					sprite.play("demon_breath")
				else:
					_go("claw")
					target.x = clampf(level.player.global_position.x - facing * 30.0, arena.x, arena.y)
					sprite.play("demon_attack")
				if hp <= max_hp / 2 and cycle % 2 == 0:
					_summon_skull()
		"claw":
			# swoop towards the player while winding up, then slam
			if sprite.frame < 6:
				position.x = move_toward(position.x, target.x, 160.0 * delta)
			position.y = lerpf(position.y, hover_y + (14.0 if sprite.frame >= 3 and sprite.frame <= 6 else 0.0), delta * 6.0)
			if not sprite.is_playing():
				_new_drift()
		"breath":
			position.y = lerpf(position.y, hover_y, delta * 3.0)
			if not sprite.is_playing():
				_set_attack(false)
				_new_drift()


func _new_drift() -> void:
	_go("idle")
	target.x = randf_range(arena.x + 30.0, arena.y - 30.0)


func _demon_frame() -> void:
	if not active or dead:
		return
	var f := sprite.frame
	if sprite.animation == "demon_breath":
		attack_box.get_child(0).position = Vector2(82.0 * facing, 49)
		_set_attack(f >= 7 and f <= 16)
	elif sprite.animation == "demon_attack":
		if f == 6:
			level.shake(6.0)
			for d in [-1, 1]:
				_shoot("fx_fireball", Vector2(global_position.x + d * 30, ground_y + 60), Vector2(d * 150, 0), 0.0, Vector2(22, 12), 1)


func _summon_skull() -> void:
	if get_tree().get_nodes_in_group("summoned").size() >= 2:
		return
	var e: Node2D = level.spawn_enemy("skull", Vector2(randf_range(arena.x, arena.y), ground_y - 20))
	e.add_to_group("summoned")


# ------------------------------------------------------------------ shared

func _shoot(anim: String, pos: Vector2, v: Vector2, grav: float, box_size: Vector2, dmg: int) -> Area2D:
	var p := preload("res://scripts/projectile.gd").new()
	p.anim = anim
	p.velocity = v
	p.grav = grav
	p.damage = dmg
	p.native_facing = -1 if anim == "spirit" else 1
	p.box(box_size)
	p.position = pos
	level.world.add_child(p)
	return p


func take_hit(dmg: int, _from: Vector2) -> void:
	if not active or dead or invulnerable:
		return
	hp -= dmg
	flash = 0.08
	level.hud.set_boss(hp)
	if hp <= 0:
		_die()


func _die() -> void:
	dead = true
	_set_attack(false)
	hazard.set_deferred("monitorable", false)
	hurtbox.set_deferred("monitorable", false)
	sprite.pause()
	level.hud.hide_boss()
	for p in get_tree().get_nodes_in_group("summoned"):
		p.queue_free()
	for i in 10:
		await get_tree().create_timer(0.15).timeout
		var r := Vector2(randf_range(-40, 40), randf_range(-70, 0) if kind != "demon" else randf_range(-50, 50))
		level.spawn_fx("fx_death", global_position + r)
		level.shake(3.0)
	var tw := create_tween()
	tw.tween_property(sprite, "modulate", Color(1, 1, 1, 0), 0.8)
	await tw.finished
	defeated.emit()
