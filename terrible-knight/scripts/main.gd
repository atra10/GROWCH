extends Node
## Entry point: hands control to the Game autoload.
## Debug options (desktop only, ignored normally), passed after "--":
##   --stage=N        start directly at stage N (0-4; 5 = ending, -1 = intro)
##   --autoplay       a simple bot holds right, jumps and swings
##   --shots=DIR      save a screenshot every 2 seconds into DIR
##   --quit=SECONDS   quit after that many seconds

var args := {}
var shot_t := 0.0
var shot_n := 0
var bot_t := 0.0


func _ready() -> void:
	Game.main = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.trim_prefix("--").split("=")
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	Game.god = args.has("god")
	if args.has("stage"):
		var s := int(args["stage"])
		if s < 0:
			Game.new_game()
		elif s >= Game.STAGES.size():
			Game.goto("ending")
		else:
			Game.start_stage(s)
			if args.has("cp"):
				Game.checkpoint = float(args["cp"])
				Game.goto("level")
	else:
		Game.goto("title")


func _process(delta: float) -> void:
	if args.is_empty():
		set_process(false)
		return
	if args.has("shots"):
		shot_t += delta
		if shot_t >= 2.0:
			shot_t = 0.0
			shot_n += 1
			var img := get_viewport().get_texture().get_image()
			img.save_png("%s/shot_%03d.png" % [args["shots"], shot_n])
	if args.has("quit") and Time.get_ticks_msec() / 1000.0 > float(args["quit"]):
		get_tree().quit()
	if args.has("autoplay"):
		_bot(delta)


func _bot(delta: float) -> void:
	bot_t += delta
	if get_tree().paused:
		# advance dialogue
		if int(bot_t * 10) % 5 == 0:
			var ev := InputEventAction.new()
			ev.action = "attack"
			ev.pressed = true
			Input.parse_input_event(ev)
			var ev2 := InputEventAction.new()
			ev2.action = "attack"
			ev2.pressed = false
			Input.parse_input_event(ev2)
		return
	var lvl := get_tree().get_first_node_in_group("level")
	var go_left := false
	if lvl and lvl.boss and lvl.boss.active and lvl.player:
		go_left = lvl.boss.global_position.x < lvl.player.global_position.x
	Input.action_press("left" if go_left else "right")
	Input.action_release("right" if go_left else "left")
	if fmod(bot_t, 0.7) < 0.35:
		Input.action_press("jump")
	else:
		Input.action_release("jump")
	if fmod(bot_t, 0.4) < 0.05:
		Input.action_press("attack")
	else:
		Input.action_release("attack")
