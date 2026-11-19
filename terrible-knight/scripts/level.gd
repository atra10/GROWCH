extends Node2D
## Builds and runs one stage from its map (see maps.gd) and its entry in Game.STAGES.

const Maps := preload("res://scripts/maps.gd")
const PlayerScript := preload("res://scripts/player.gd")
const EnemyScript := preload("res://scripts/enemy.gd")
const BossScript := preload("res://scripts/boss.gd")
const HeartScript := preload("res://scripts/heart.gd")
const HudScript := preload("res://scripts/hud.gd")
const DialogueScript := preload("res://scripts/dialogue.gd")

var data: Dictionary
var rows: Array
var map_size := Vector2.ZERO
var world: Node2D
var player: CharacterBody2D
var camera: Camera2D
var hud: CanvasLayer
var dialogue: CanvasLayer
var bg_layer: CanvasLayer
var bg_sprites := []           # [sprite, factor, scale]
var visions := []              # [x, index, done]
var checkpoints := []
var arena_x := 0.0
var boss_pos := Vector2.ZERO
var boss: Node2D
var heroine: AnimatedSprite2D
var arena_started := false
var finished := false
var shake_amount := 0.0
var fade: ColorRect


func _ready() -> void:
	add_to_group("level")
	data = Game.STAGES[Game.stage_index]
	rows = Maps.ALL[data["map"]]
	map_size = Vector2(rows[0].length() * Game.TILE, rows.size() * Game.TILE)

	_build_background()
	world = Node2D.new()
	add_child(world)
	_build_ground()

	hud = HudScript.new()
	add_child(hud)
	dialogue = DialogueScript.new()
	add_child(dialogue)

	_spawn_entities()

	camera = Camera2D.new()
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(map_size.x)
	camera.limit_bottom = int(map_size.y)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 7.0
	world.add_child(camera)
	camera.global_position = player.global_position + Vector2(0, -30)
	camera.reset_smoothing.call_deferred()

	fade = ColorRect.new()
	fade.color = Color.BLACK
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fl := CanvasLayer.new()
	fl.layer = 30
	fl.process_mode = Node.PROCESS_MODE_ALWAYS
	fl.add_child(fade)
	add_child(fl)
	fade.size = Vector2(2000, 2000)
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 0.0, 0.6)
	hud.show_title(data["title"])


# ------------------------------------------------------------------ building

func _build_background() -> void:
	bg_layer = CanvasLayer.new()
	bg_layer.layer = -10
	add_child(bg_layer)
	var ref_h := 0.0
	for entry in data["bg"]:
		var tex: Texture2D = load("res://assets/bg/%s.png" % entry[0])
		ref_h = maxf(ref_h, tex.get_height())
	for entry in data["bg"]:
		var tex: Texture2D = load("res://assets/bg/%s.png" % entry[0])
		var s := Sprite2D.new()
		s.texture = tex
		s.centered = false
		s.region_enabled = true
		s.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		s.modulate = data.get("bg_tint", Color.WHITE)
		bg_layer.add_child(s)
		bg_sprites.append([s, entry[1], ref_h])


func _update_background() -> void:
	var view := get_viewport().get_visible_rect().size
	var cam_x := camera.get_screen_center_position().x - view.x / 2.0
	for b in bg_sprites:
		var s: Sprite2D = b[0]
		var sc: float = view.y / b[2]
		s.scale = Vector2(sc, sc)
		var h := s.texture.get_height()
		s.region_rect = Rect2(cam_x * b[1] / sc, 0, view.x / sc + 2, h)
		s.position = Vector2(0, view.y - h * sc)


func _solid(c: int, r: int) -> bool:
	if r < 0 or r >= rows.size() or c < 0 or c >= rows[0].length():
		return false
	return rows[r][c] == "#"


func _build_ground() -> void:
	var tiles: Texture2D = load("res://assets/tiles/%s.png" % data["tiles"])
	var body := StaticBody2D.new()
	body.collision_layer = Game.L_WORLD
	world.add_child(body)
	var fill_layer := Node2D.new()
	world.add_child(fill_layer)
	var top_layer := Node2D.new()
	world.add_child(top_layer)
	var T := Game.TILE
	var w: int = rows[0].length()
	for r in rows.size():
		var c := 0
		while c < w:
			var ch: String = rows[r][c]
			if ch != "#" and ch != "-":
				c += 1
				continue
			var start := c
			while c < w and rows[r][c] == ch:
				c += 1
			var run_w := (c - start) * T
			var pos := Vector2(start * T, r * T)
			if ch == "#":
				body.add_child(Game.rect_shape(Vector2(run_w, T), pos + Vector2(run_w, T) / 2.0))
				var fill := ColorRect.new()
				fill.color = data["fill"]
				fill.position = pos
				fill.size = Vector2(run_w, T)
				fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
				fill_layer.add_child(fill)
				# draw the textured top edge wherever the cell above is open
				var cc := start
				while cc < c:
					if _solid(cc, r - 1):
						cc += 1
						continue
					var s0 := cc
					while cc < c and not _solid(cc, r - 1):
						cc += 1
					_top_strip(top_layer, tiles, s0, cc, r)
			else:
				var cs := Game.rect_shape(Vector2(run_w, 6), pos + Vector2(run_w / 2.0, 3))
				cs.one_way_collision = true
				body.add_child(cs)
				var plank := Sprite2D.new()
				plank.texture = tiles
				plank.centered = false
				plank.region_enabled = true
				plank.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
				plank.region_rect = Rect2(0, 0, run_w, 10)
				plank.position = pos
				top_layer.add_child(plank)


func _top_strip(parent: Node, tex: Texture2D, c0: int, c1: int, r: int) -> void:
	var T := Game.TILE
	# how deep the solid ground goes below this row, so the strip doesn't hang under a thin ledge
	var depth := 0
	while _solid(c0, r + depth):
		depth += 1
	var th := tex.get_height()
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.region_enabled = true
	s.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	# grass tufts in the strip may poke up above the ground line
	var lift := 0
	if data["tiles"] == "forest":
		lift = 14
	elif data["tiles"] == "mist":
		lift = 6
	s.region_rect = Rect2(0, 0, (c1 - c0) * T, mini(th, depth * T + lift))
	s.position = Vector2(c0 * T, r * T - lift)
	parent.add_child(s)


func _spawn_entities() -> void:
	var T := Game.TILE
	var start := Vector2(48, 176)
	var vision_i := 0
	for r in rows.size():
		var line: String = rows[r]
		for c in line.length():
			var ch := line[c]
			var feet := Vector2(c * T + T / 2.0, (r + 1) * T)
			var center := Vector2(c * T + T / 2.0, r * T + T / 2.0)
			match ch:
				"P": start = feet
				"h", "o": spawn_enemy("hound" if ch == "h" else "ogre", feet)
				"c": spawn_enemy("crow", center)
				"e": spawn_enemy("eye", center)
				"g": spawn_enemy("ghost", center)
				"s": spawn_enemy("skull", center)
				"+": spawn_heart(center, true)
				"k": checkpoints.append(feet)
				"A": arena_x = c * T
				"X": boss_pos = feet
	# visions are numbered left to right
	var vx := []
	for r in rows.size():
		for c in rows[r].length():
			if rows[r][c] == "v":
				vx.append(c * T)
	vx.sort()
	for x in vx:
		visions.append([x, vision_i, false])
		vision_i += 1

	player = PlayerScript.new()
	player.level = self
	if Game.checkpoint >= 0.0:
		start = _safe_ground(Game.checkpoint)
	player.position = start
	world.add_child(player)
	if Game.main and Game.main.args.has("hp"):   # debug: --hp=N
		player.hp = int(Game.main.args["hp"])
	hud.set_hp(player.hp)
	hud.player = player

	if data["boss"] == "demon":
		heroine = Game.make_sprite(["heroine_idle"])
		heroine.flip_h = true
		heroine.position = boss_pos + Vector2(0, -32)
		world.add_child(heroine)
	else:
		_create_boss(boss_pos)


func _create_boss(pos: Vector2) -> void:
	boss = BossScript.new()
	var arena_range := Vector2(arena_x + 40.0, map_size.x - 56.0)
	if data["boss"] == "demon":
		boss.setup("demon", self, pos + Vector2(0, -72), Vector2(arena_x + 60.0, map_size.x - 70.0))
	else:
		boss.setup(data["boss"], self, pos, arena_range)
	boss.defeated.connect(_on_boss_defeated)
	world.add_child(boss)


func _ground_at(x: float) -> Vector2:
	var c := int(x / Game.TILE)
	for r in rows.size():
		if _solid(c, r):
			return Vector2(c * Game.TILE + Game.TILE / 2.0, r * Game.TILE)
	return Vector2(x, 160)


# ------------------------------------------------------------------ spawning helpers

func spawn_enemy(kind: String, pos: Vector2) -> Node2D:
	var e := EnemyScript.new()
	e.setup(kind, self, pos)
	world.add_child(e)
	return e


func spawn_heart(pos: Vector2, fixed := false) -> void:
	var h := HeartScript.new()
	h.position = pos
	if fixed:
		h.vy = 0.0
	world.add_child.call_deferred(h)


func spawn_fx(anim: String, pos: Vector2) -> void:
	var s := Game.make_sprite([anim])
	s.position = pos
	s.animation_finished.connect(s.queue_free)
	world.add_child(s)


func add_moon(amount: float) -> void:
	if player and player.form == "wolf":
		Game.moon = minf(Game.moon + amount, Game.MOON_MAX)


func flash(col: Color, t: float) -> void:
	fade.color = Color(col.r, col.g, col.b, 0.85)
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 0.0, t)


func shake(amount: float) -> void:
	shake_amount = maxf(shake_amount, amount)


# ------------------------------------------------------------------ main loop

func _process(delta: float) -> void:
	if player == null:
		return
	var ahead: float = 24.0 * player.facing
	camera.global_position = player.global_position + Vector2(ahead, -30)
	if shake_amount > 0.0:
		camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake_amount
		shake_amount = maxf(shake_amount - delta * 20.0, 0.0)
	else:
		camera.offset = Vector2.ZERO
	_update_background()


func _physics_process(_delta: float) -> void:
	if player == null or player.dead or finished:
		return
	var px := player.global_position.x
	for cp in checkpoints:
		if px > cp.x and Game.checkpoint < cp.x:
			Game.checkpoint = cp.x
	for v in visions:
		if not v[2] and px > v[0] - 40.0:
			v[2] = true
			_vision(v[1], Vector2(v[0] + 60.0, player.global_position.y - 30))
	if not arena_started and px > arena_x + 48.0:
		_start_arena()
	if player.global_position.y > map_size.y + 40.0:
		player_fell()


func _vision_key(i: int) -> String:
	return "%d-%d" % [Game.stage_index, i]


func _vision(i: int, pos: Vector2) -> void:
	var lines: Array = data["visions"][i]
	if lines.is_empty():
		return
	var key := _vision_key(i)
	if Game.seen.has(key):
		return
	Game.seen[key] = true
	var ghost := Game.make_sprite(["heroine_idle"])
	ghost.flip_h = true
	ghost.position = pos
	ghost.modulate = Color(0.6, 0.85, 1.4, 0.0)
	world.add_child(ghost)
	var tw := create_tween()
	tw.tween_property(ghost, "modulate:a", 0.7, 0.4)
	await tw.finished
	await dialogue.run(lines)
	var tw2 := create_tween()
	tw2.tween_property(ghost, "modulate:a", 0.0, 0.6)
	tw2.tween_callback(ghost.queue_free)


func _start_arena() -> void:
	arena_started = true
	Game.checkpoint = maxf(Game.checkpoint, arena_x - 32.0)
	camera.limit_left = int(arena_x)
	# a wall closes the arena behind the knight
	var wall := StaticBody2D.new()
	wall.collision_layer = Game.L_WORLD
	wall.add_child(Game.rect_shape(Vector2(16, map_size.y), Vector2(arena_x - 8.0, map_size.y / 2.0)))
	world.add_child(wall)

	var lines: Array = data["visions"][2]
	var key := _vision_key(2)
	if data["boss"] == "demon":
		player.controllable = false
		if not Game.seen.has(key):
			Game.seen[key] = true
			await dialogue.run(lines)
		await _transform_heroine()
		player.controllable = true
	elif not Game.seen.has(key):
		Game.seen[key] = true
		await dialogue.run(lines)
	boss.activate()


func _transform_heroine() -> void:
	shake(4.0)
	var tw := create_tween()
	tw.tween_property(heroine, "modulate", Color(3, 0.3, 0.3), 0.8)
	tw.tween_property(heroine, "scale", Vector2(1.6, 1.6), 0.4)
	await tw.finished
	fade.color = Color(1, 1, 1, 1)
	shake(8.0)
	heroine.queue_free()
	_create_boss(boss_pos)
	var tw2 := create_tween()
	tw2.tween_property(fade, "color:a", 0.0, 0.8)
	await tw2.finished
	var key := "%d-demon" % Game.stage_index
	if not Game.seen.has(key):
		Game.seen[key] = true
		await dialogue.run([["Demon", "FREE! After a thousand years... FREE!"], ["Demon", "Now kneel, little wolf. Your moon is setting."]])


func _on_boss_defeated() -> void:
	finished = true
	player.controllable = false
	player.invuln = 999.0
	await get_tree().create_timer(0.6).timeout
	if data["boss"] == "demon":
		await _fade_out(1.5)
		Game.next_stage()
		return
	await dialogue.run(data["outro"])
	hud.show_title("STAGE CLEAR")
	await get_tree().create_timer(2.0).timeout
	await _fade_out(0.8)
	Game.next_stage()


func _fade_out(t: float) -> void:
	fade.color = Color(0, 0, 0, 0)
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 1.0, t)
	await tw.finished


func player_fell() -> void:
	## Put the player back on solid ground and always charge for the fall,
	## even while invincible (otherwise falling could loop forever).
	var spot := _safe_ground(player.safe_pos.x)
	player.position = spot
	player.safe_pos = spot
	player.velocity = Vector2.ZERO
	player.take_damage(2, spot, true)
	if not player.dead:
		player.velocity = Vector2.ZERO
		player.hurt_time = 0.0
		player.invuln = 1.2


## Nearest flat, solid ground (3 tiles wide) at or behind x, so a respawn never lands over a pit.
func _safe_ground(x: float) -> Vector2:
	var T := Game.TILE
	var min_col := int(arena_x / T) + 2 if arena_started else 1
	var col := clampi(int(x / T), min_col, rows[0].length() - 2)
	for c in range(col, min_col - 1, -1):
		var top := _top_row(c)
		if top >= 0 and _top_row(c - 1) == top and _top_row(c + 1) == top:
			return Vector2(c * T + T / 2.0, top * T)
	for c in range(col, rows[0].length() - 1):
		var top := _top_row(c)
		if top >= 0 and _top_row(c - 1) == top and _top_row(c + 1) == top:
			return Vector2(c * T + T / 2.0, top * T)
	return Vector2(48, 176)


## First solid row in a column, or -1 if the column is a pit.
func _top_row(c: int) -> int:
	for r in rows.size():
		if _solid(c, r):
			return r
	return -1


func player_died() -> void:
	finished = true
	await get_tree().create_timer(1.0).timeout
	await _fade_out(0.8)
	Game.retry_stage()
