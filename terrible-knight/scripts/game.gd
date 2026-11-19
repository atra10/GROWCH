extends Node
## Global game state, shared helpers and all story data.
## Autoloaded as "Game".

# Physics layers (bit values)
const L_WORLD := 1
const L_PLAYER := 2
const L_ENEMY := 4
const L_HAZARD := 8
const L_ENEMY_HURT := 16
const L_PICKUP := 32

const TILE := 16
const MAX_HP := 8
const MOON_MAX := 100.0
const MOON_PER_KILL := 20.0
const MOON_PER_BOSS_HIT := 5.0
const KNIGHT_TIME := 30.0

# name: [file, frame width, fps, loop]
const ANIMS := {
	"knight_idle": ["knight_idle", 128, 8, true],
	"knight_run": ["knight_run", 128, 18, true],
	"knight_jump": ["knight_jump", 128, 10, false],
	"knight_slash": ["knight_slash", 128, 20, false],
	"knight_airslash": ["knight_airslash", 128, 20, false],
	"knight_hurt": ["knight_hurt", 128, 12, false],
	"wolf_idle": ["wolf_idle", 96, 8, true],
	"wolf_run": ["wolf_run", 96, 12, true],
	"wolf_jump": ["wolf_jump", 96, 8, true],
	"wolf_fall": ["wolf_fall", 96, 8, true],
	"dagger": ["dagger", 32, 1, true],
	"fx_claw": ["fx_claw", 65, 24, false],
	"fx_transform": ["fx_transform", 52, 14, false],
	"heroine_idle": ["heroine_idle", 128, 6, true],
	"heroine_run": ["heroine_run", 128, 12, true],
	"hellbeast_idle": ["hellbeast_idle", 80, 8, true],
	"hellbeast_breath": ["hellbeast_breath", 80, 8, false],
	"hellbeast_burn": ["hellbeast_burn", 80, 10, true],
	"hellbeast_fireball": ["hellbeast_fireball", 19, 12, true],
	"nightmare_idle": ["nightmare_idle", 160, 8, true],
	"nightmare_run": ["nightmare_run", 160, 12, true],
	"dragon_idle": ["dragon_idle", 144, 8, true],
	"dragon_breath": ["dragon_breath", 144, 10, false],
	"dragon_tail": ["dragon_tail", 144, 14, false],
	"death_walk": ["death_walk", 32, 8, true],
	"death_rise": ["death_rise", 32, 12, false],
	"demon_idle": ["demon_idle", 312, 8, true],
	"demon_attack": ["demon_attack", 312, 14, false],
	"demon_breath": ["demon_breath", 312, 12, false],
	"hound_run": ["hound_run", 64, 12, true],
	"hound_idle": ["hound_idle", 64, 8, true],
	"ghost_chase": ["ghost_chase", 64, 8, true],
	"ghost_appear": ["ghost_appear", 64, 10, false],
	"spirit": ["spirit", 64, 10, true],
	"skull": ["skull", 96, 10, true],
	"crow_fly": ["crow_fly", 48, 8, true],
	"eye_fly": ["eye_fly", 48, 12, true],
	"ogre_walk": ["ogre_walk", 144, 8, true],
	"ogre_attack": ["ogre_attack", 144, 10, false],
	"fx_death": ["fx_death", 48, 16, false],
	"fx_hit": ["fx_hit", 31, 16, false],
	"fx_fireball": ["fx_fireball", 52, 12, true],
}

const STAGES := [
	{
		"title": "Stage 1 - The Haunted Forest",
		"map": "STAGE1",
		"tiles": "forest", "fill": Color(0.17, 0.09, 0.05),
		"bg": [["forest_back", 0.1], ["forest_middle", 0.35]],
		"boss": "hellbeast", "boss_name": "HELL BEAST",
		"visions": [
			[["Princess", "This forest is cursed. Hounds of hell roam between the dead trees."],
			 ["Princess", "Strike with your claws. Jump over the pits!"],
			 ["Princess", "Every creature you slay gathers moonlight. When the moon is full, touch it..."],
			 ["Princess", "...and for thirty heartbeats you will be the Terrible Knight again."]],
			[["Princess", "The crows are the demon's eyes. Cut them down."],
			 ["Princess", "If you are wounded, red hearts will heal you."]],
			[["Princess", "The Hell Beast guards the forest gate."],
			 ["Princess", "Jump over its fireballs, then strike! When it bursts into flame, stay back."]],
		],
		"outro": [["Princess", "The first guardian has fallen..."],
				  ["Princess", "Hurry, Knight. The full moon will not last forever."]],
	},
	{
		"title": "Stage 2 - The Night Town",
		"map": "STAGE2",
		"tiles": "town", "fill": Color(0.13, 0.11, 0.07),
		"bg": [["town_sky", 0.0], ["town_mountains", 0.05], ["town_clouds", 0.1], ["town_far_buildings", 0.2], ["town_town", 0.4]],
		"boss": "nightmare", "boss_name": "NIGHTMARE",
		"visions": [
			[["Princess", "The town beneath the castle. Its people fled long ago."],
			 ["Princess", "Ghosts drift through these streets. They pass through walls... but not through steel."]],
			[["Princess", "Do you feel the ground shaking? Something wild gallops in the dark."]],
			[["Princess", "The Nightmare! When it charges, leap over it."],
			 ["Princess", "Strike when it stops to breathe."]],
		],
		"outro": [["Princess", "Two guardians gone. I can feel the chains... loosening."]],
	},
	{
		"title": "Stage 3 - The Burning Caverns",
		"map": "STAGE3",
		"tiles": "cave", "fill": Color(0.1, 0.07, 0.12),
		"bg": [["lava_back", 0.1], ["lava_rocks", 0.3]],
		"boss": "dragon", "boss_name": "DRAGON",
		"visions": [
			[["Princess", "The caverns burn beneath the mountain. Fire skulls hunt in the dark."]],
			[["Princess", "Ogres guard these tunnels. Strike, then step back before their club falls."]],
			[["Princess", "The Dragon! Its fire flies high and low."],
			 ["Princess", "Jump the low flames. Stay on the ground under the high ones."]],
		],
		"outro": [["Princess", "Only one guardian remains..."],
				  ["Princess", "Death itself."]],
	},
	{
		"title": "Stage 4 - The Graveyard Mist",
		"map": "STAGE4",
		"tiles": "mist", "fill": Color(0.03, 0.12, 0.12),
		"bg": [["horror_clouds", 0.08], ["horror_town", 0.3]], "bg_tint": Color(0.42, 0.5, 0.78),
		"boss": "death", "boss_name": "DEATH",
		"visions": [
			[["Princess", "The graveyard at the castle gate. Death walks here with his lamp."]],
			[["Princess", "Knight... whatever happens next, don't stop. Please."]],
			[["Princess", "Death does not chase. He appears."],
			 ["Princess", "Watch for his lamp, and for the spirits he sends."]],
		],
		"outro": [["Death", "Fool... you have unlocked her cage."],
				  ["Princess", "Come to me, my knight. The castle door is open."]],
	},
	{
		"title": "Final - The Black Castle",
		"map": "FINAL",
		"tiles": "town", "fill": Color(0.07, 0.06, 0.08),
		"bg": [["castle_back", 0.25]],
		"boss": "demon", "boss_name": "THE DEMON",
		"visions": [
			[["Princess", "You're here... Just a little further. I'm waiting for you."]],
			[],
			[["Princess", "My knight. You came, just as I knew you would."],
			 ["Princess", "The Hell Beast. The Nightmare. The Dragon. Death."],
			 ["Princess", "They were never my captors..."],
			 ["Princess", "They were my JAILERS."],
			 ["Princess", "And you, poor cursed wolf... you set me free."]],
		],
		"outro": [],
	},
]

const INTRO_LINES_1 := [
	["", "Long ago, a cursed wolf roamed the old kingdom of Valdren."],
	["", "Most nights it was only a beast. But under the full moon..."],
]
const INTRO_LINES_2 := [
	["", "...it became the Terrible Knight."],
	["Princess", "Knight... can you hear me? It is me, the Princess."],
	["Princess", "A demon dragged me into the Black Castle. Four guardians stand in your way."],
	["Princess", "But hear me: the moon's gift is brief. Its light fades fast."],
	["Princess", "Follow my voice. I will guide you."],
]
const ENDING_LINES := [
	["", "The demon's scream shook the Black Castle until its towers fell."],
	["", "There was no princess. There never had been. Only the demon, and the voice it used."],
	["", "When dawn came, the Terrible Knight was gone."],
	["", "Only a wounded wolf limped out of the ruins, into the forest."],
	["", "The moon will be full again."],
]

var main: Node
var stage_index := 0
var checkpoint := -1.0        # x position of the last checkpoint in the current stage (-1 = start)
var seen := {}                # dialogue keys already shown (skip on retry)
var deaths := 0
var moon := 60.0               # moon meter, carried between stages
var god := false              # debug: player takes no damage
var play_time := 0.0

var _frames_cache := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()


func _process(delta: float) -> void:
	if not get_tree().paused:
		play_time += delta


func _setup_input() -> void:
	var map := {
		"left": [KEY_A, KEY_LEFT],
		"right": [KEY_D, KEY_RIGHT],
		"jump": [KEY_SPACE, KEY_W, KEY_UP, KEY_K],
		"attack": [KEY_J, KEY_X, KEY_Z, KEY_ENTER],
		"special": [KEY_L, KEY_C, KEY_SHIFT],
		"pause": [KEY_ESCAPE, KEY_P],
	}
	for action in map:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key in map[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)
	# gamepad support
	var pad := {"left": JOY_BUTTON_DPAD_LEFT, "right": JOY_BUTTON_DPAD_RIGHT, "jump": JOY_BUTTON_A, "attack": JOY_BUTTON_X, "special": JOY_BUTTON_Y, "pause": JOY_BUTTON_START}
	for action in pad:
		var jb := InputEventJoypadButton.new()
		jb.button_index = pad[action]
		InputMap.action_add_event(action, jb)


## Builds (and caches) a SpriteFrames resource holding the given animations.
func frames(names: Array) -> SpriteFrames:
	var key := ",".join(names)
	if _frames_cache.has(key):
		return _frames_cache[key]
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	for n in names:
		var spec: Array = ANIMS[n]
		var tex: Texture2D = load("res://assets/sprites/%s.png" % spec[0])
		var fw: int = spec[1]
		var fh: int = tex.get_height()
		var count: int = tex.get_width() / fw
		sf.add_animation(n)
		sf.set_animation_speed(n, spec[2])
		sf.set_animation_loop(n, spec[3])
		for i in count:
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2(i * fw, 0, fw, fh)
			sf.add_frame(n, at)
	_frames_cache[key] = sf
	return sf


func make_sprite(names: Array, start: String = "") -> AnimatedSprite2D:
	var s := AnimatedSprite2D.new()
	s.sprite_frames = frames(names)
	s.animation = start if start != "" else names[0]
	s.play()
	return s


func rect_shape(size: Vector2, pos: Vector2 = Vector2.ZERO) -> CollisionShape2D:
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = size
	cs.shape = r
	cs.position = pos
	return cs


## Creates an Area2D with a rectangle shape.
func area(size: Vector2, pos: Vector2, layer: int, mask: int) -> Area2D:
	var a := Area2D.new()
	a.collision_layer = layer
	a.collision_mask = mask
	a.monitorable = layer != 0
	a.add_child(rect_shape(size, pos))
	return a


# ---------------------------------------------------------------- flow

func goto(screen: String) -> void:
	get_tree().paused = false
	for c in main.get_children():
		c.queue_free()
	var node: Node
	match screen:
		"title":
			node = load("res://scripts/title.gd").new()
		"intro":
			node = load("res://scripts/cutscene.gd").new()
			node.kind = "intro"
		"ending":
			node = load("res://scripts/cutscene.gd").new()
			node.kind = "ending"
		"level":
			node = load("res://scripts/level.gd").new()
	# main runs while paused (for debug tools); screens must still pause for dialogue
	node.process_mode = Node.PROCESS_MODE_PAUSABLE
	main.add_child(node)


func new_game() -> void:
	stage_index = 0
	checkpoint = -1.0
	seen.clear()
	deaths = 0
	play_time = 0.0
	moon = 60.0
	goto("intro")


func start_stage(i: int) -> void:
	stage_index = i
	checkpoint = -1.0
	goto("level")


func next_stage() -> void:
	if stage_index + 1 < STAGES.size():
		start_stage(stage_index + 1)
	else:
		goto("ending")


func retry_stage() -> void:
	deaths += 1
	goto("level")
