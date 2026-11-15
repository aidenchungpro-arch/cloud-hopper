extends Node2D
# CLOUD HOPPER - an endless vertical jumper.
# Steer with A/D, arrow keys, or by holding the left/right side of the screen.
# Everything (art + sound) is generated in code, so there are no asset files.

const W := 400.0
const H := 640.0
const G := 1500.0
const JUMP := 640.0
const MAXVX := 270.0
const SAVE_PATH := "user://cloud_hopper.cfg"


enum St { MENU, PLAY, PAUSE, OVER }

var SKINS := [
	{"name": "Pip", "body": Color("86e06c"), "dark": Color("4fae4a"), "acc": "none", "acc_col": Color("ffffff"), "cost": 0},
	{"name": "Bubbles", "body": Color("ff93c9"), "dark": Color("d9509a"), "acc": "bow", "acc_col": Color("ffe27a"), "cost": 25},
	{"name": "Sunny", "body": Color("ffd84d"), "dark": Color("e0a21c"), "acc": "halo", "acc_col": Color("fff6b0"), "cost": 50},
	{"name": "Blueberry", "body": Color("7aa8ff"), "dark": Color("4468d8"), "acc": "cap", "acc_col": Color("ff6b6b"), "cost": 75},
	{"name": "Foxy", "body": Color("ff9a4d"), "dark": Color("d9631c"), "acc": "ears", "acc_col": Color("fff0dc"), "cost": 120},
	{"name": "Robo", "body": Color("b4bfd0"), "dark": Color("7584a0"), "acc": "antenna", "acc_col": Color("ff5a5a"), "cost": 180},
]

var SKY := [
	{"a": 0.0, "top": Color8(126, 200, 255), "bot": Color8(222, 244, 255)},
	{"a": 1500.0, "top": Color8(255, 140, 110), "bot": Color8(255, 214, 160)},
	{"a": 3500.0, "top": Color8(22, 28, 80), "bot": Color8(92, 64, 140)},
	{"a": 6500.0, "top": Color8(3, 4, 14), "bot": Color8(16, 20, 52)},
]

var state = St.MENU
var t := 0.0
var cam_y := 0.0
var top_y := 0.0
var start_y := 0.0
var max_h := 0.0
var bonus := 0
var run_coins := 0
var chain_x := W / 2.0
var p := {}
var plats := []
var coins_arr := []
var items := []
var enemies := []
var parts := []
var pops := []
var rocket_t := 0.0
var shield := false
var dying := false
var dying_t := 0.0
var hint_t := 0.0
var new_best := false
var shake := 0.0
var sel := 0
var menu_t := 0.0
var menu_phase := 0.0
var menu_msg := ""
var menu_msg_t := 0.0
var final_score := 0
var muted := false
var touch_dir := 0
var ptrs := {}
var ui := []
var save := {"best": 0, "coins": 0, "skin": 0, "unlocked": [0]}
var last_lvl := 1
var stars := []
var clouds := []
var sfx := {}
var players := []


# ================================================================ setup
func _ready() -> void:
	randomize()
	load_save()
	sel = save.skin
	for i in range(80):
		stars.append({"x": randf_range(0, W), "y": randf_range(0, H), "r": randf_range(0.6, 1.9), "tw": randf_range(0, 6)})
	for i in range(8):
		clouds.append({"x": randf_range(0, W + 200), "y": randf_range(0, H + 160), "s": randf_range(0.6, 1.5), "f": randf_range(0.25, 0.6), "sp": randf_range(4, 14)})
	build_sfx()
	for i in range(8):
		var pl := AudioStreamPlayer.new()
		pl.volume_db = -3.0
		add_child(pl)
		players.append(pl)


func load_save() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		save.best = int(cfg.get_value("s", "best", 0))
		save.coins = int(cfg.get_value("s", "coins", 0))
		save.skin = int(cfg.get_value("s", "skin", 0))
		save.unlocked = Array(cfg.get_value("s", "unlocked", [0]))
		muted = bool(cfg.get_value("s", "muted", false))


func persist() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("s", "best", save.best)
	cfg.set_value("s", "coins", save.coins)
	cfg.set_value("s", "skin", save.skin)
	cfg.set_value("s", "unlocked", save.unlocked)
	cfg.set_value("s", "muted", muted)
	cfg.save(SAVE_PATH)


# ================================================================ audio (synthesized)
func build_sfx() -> void:
	sfx["jump"] = make_sfx([[380, 0.14, "sine", 0.13, 340, 0.0]])
	sfx["spring"] = make_sfx([[260, 0.28, "square", 0.06, 760, 0.0]])
	sfx["coin"] = make_sfx([[880, 0.08, "tri", 0.13, 0, 0.0], [1320, 0.12, "tri", 0.13, 0, 0.07]])
	sfx["stomp"] = make_sfx([[240, 0.16, "square", 0.08, -140, 0.0]])
	sfx["crack"] = make_sfx([[130, 0.2, "saw", 0.08, -70, 0.0]])
	sfx["power"] = make_sfx([[523, 0.12, "tri", 0.12, 0, 0.0], [659, 0.12, "tri", 0.12, 0, 0.07], [784, 0.12, "tri", 0.12, 0, 0.14], [1047, 0.12, "tri", 0.12, 0, 0.21]])
	sfx["shield"] = make_sfx([[600, 0.25, "sine", 0.12, 400, 0.0]])
	sfx["hit"] = make_sfx([[210, 0.4, "saw", 0.13, -150, 0.0]])
	sfx["over"] = make_sfx([[392, 0.22, "tri", 0.12, 0, 0.0], [330, 0.22, "tri", 0.12, 0, 0.14], [262, 0.22, "tri", 0.12, 0, 0.28], [196, 0.22, "tri", 0.12, 0, 0.42]])
	sfx["click"] = make_sfx([[520, 0.06, "tri", 0.1, 0, 0.0]])


func make_sfx(specs: Array) -> AudioStreamWAV:
	var rate := 22050
	var total := 0.0
	for s in specs:
		total = max(total, float(s[5]) + float(s[1]))
	var n := int((total + 0.03) * rate)
	var buf := PackedFloat32Array()
	buf.resize(n)
	for s in specs:
		var freq: float = s[0]
		var dur: float = s[1]
		var wave: String = s[2]
		var vol: float = s[3]
		var slide: float = s[4]
		var start := int(float(s[5]) * rate)
		var cnt := int(dur * rate)
		var phase := 0.0
		var end_f: float = max(30.0, freq + slide)
		for i in range(cnt):
			var k := float(i) / float(cnt)
			var f: float = freq * pow(end_f / freq, k)
			phase += f / rate
			var ph := fmod(phase, 1.0)
			var osc := 0.0
			match wave:
				"sine": osc = sin(TAU * phase)
				"square": osc = 1.0 if ph < 0.5 else -1.0
				"saw": osc = 2.0 * ph - 1.0
				_: osc = 4.0 * abs(ph - 0.5) - 1.0
			var env: float = vol * pow(0.0001 / vol, k)
			if start + i < n:
				buf[start + i] += osc * env * 1.6
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in range(n):
		data.encode_s16(i * 2, int(clamp(buf[i], -1.0, 1.0) * 32000.0))
	var st := AudioStreamWAV.new()
	st.format = AudioStreamWAV.FORMAT_16_BITS
	st.mix_rate = rate
	st.stereo = false
	st.data = data
	return st


func play_sfx(n: String) -> void:
	if muted or not sfx.has(n):
		return
	for pl in players:
		if not pl.playing:
			pl.stream = sfx[n]
			pl.play()
			return
	players[0].stream = sfx[n]
	players[0].play()


# ================================================================ helpers
func A(c: Color, a: float) -> Color:
	return Color(c.r, c.g, c.b, c.a * a)


func score() -> int:
	return int(max_h / 10.0) + bonus


func diff() -> float:
	# 0 -> 1 over the first 2500 points: tighter gaps, narrower platforms, more hazards
	return clamp(float(score()) / 2500.0, 0.0, 1.0)


func extra() -> float:
	# keeps getting harder after diff() maxes out (2500 -> 7500 points)
	return clamp((float(score()) - 2500.0) / 5000.0, 0.0, 1.0)


func lvl() -> int:
	return int(float(score()) / 400.0) + 1


func rr_pts(x: float, y: float, w: float, h: float, r: float) -> PackedVector2Array:
	r = min(r, min(w, h) / 2.0)
	var pts := PackedVector2Array()
	var centers := [Vector2(x + w - r, y + r), Vector2(x + w - r, y + h - r), Vector2(x + r, y + h - r), Vector2(x + r, y + r)]
	for ci in range(4):
		for i in range(7):
			var a: float = -PI / 2.0 + ci * PI / 2.0 + (i / 6.0) * PI / 2.0
			pts.append(centers[ci] + Vector2.from_angle(a) * r)
	return pts


func rr(x: float, y: float, w: float, h: float, r: float, col: Color) -> void:
	if w < 1.0 or h < 1.0:
		return
	draw_colored_polygon(rr_pts(x, y, w, h, r), col)


func rr_grad(x: float, y: float, w: float, h: float, r: float, c1: Color, c2: Color) -> void:
	if w < 1.0 or h < 1.0:
		return
	var pts := rr_pts(x, y, w, h, r)
	var cols := PackedColorArray()
	for pt in pts:
		cols.append(c1.lerp(c2, clamp((pt.y - y) / h, 0.0, 1.0)))
	draw_polygon(pts, cols)


func el_pts(x: float, y: float, rx: float, ry: float, n := 22) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(n):
		var a := TAU * i / n
		pts.append(Vector2(x + cos(a) * rx, y + sin(a) * ry))
	return pts


func el(x: float, y: float, rx: float, ry: float, col: Color) -> void:
	if rx < 0.3 or ry < 0.3:
		return
	draw_colored_polygon(el_pts(x, y, rx, ry), col)


func circ(x: float, y: float, r: float, col: Color) -> void:
	draw_circle(Vector2(x, y), r, col)


func tri(a: Vector2, b: Vector2, c: Vector2, col: Color) -> void:
	draw_colored_polygon(PackedVector2Array([a, b, c]), col)


func txt(s: String, x: float, y: float, size: int, col: Color, align := 1, outline := Color(0, 0, 0, 0)) -> void:
	var f := ThemeDB.fallback_font
	var pos := Vector2(x, y)
	var a := HORIZONTAL_ALIGNMENT_CENTER
	var w := 800.0
	if align == 1:
		pos.x = x - 400.0
	elif align == 0:
		a = HORIZONTAL_ALIGNMENT_LEFT
		w = -1.0
	else:
		pos.x = x - 800.0
		a = HORIZONTAL_ALIGNMENT_RIGHT
	if outline.a > 0.0:
		draw_string_outline(f, pos, s, a, w, size, max(3, int(size / 7.0)), outline)
	draw_string(f, pos, s, a, w, size, col)


func text_w(s: String, size: int) -> float:
	return ThemeDB.fallback_font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


func reset_xf() -> void:
	draw_set_transform_matrix(Transform2D.IDENTITY)


# ================================================================ particles / popups
func burst(x: float, y: float, n: int, color: Color, speed: float, life: float, grav := 500.0, size := -1.0) -> void:
	for i in range(n):
		var a := randf() * TAU
		var s := randf_range(0.3, 1.0) * speed
		parts.append({"x": x, "y": y, "vx": cos(a) * s, "vy": sin(a) * s, "life": randf_range(0.6, 1.0) * life,
			"max": life, "size": size if size > 0.0 else randf_range(2, 4), "color": color, "grav": grav})


func pop(text: String, x: float, y: float, color: Color) -> void:
	pops.append({"text": text, "x": x, "y": y, "life": 1.0, "color": color})


func update_fx(dt: float) -> void:
	for q in parts:
		q.life -= dt
		q.vy += q.grav * dt
		q.x += q.vx * dt
		q.y += q.vy * dt
	parts = parts.filter(func(q): return q.life > 0.0)
	for q in pops:
		q.life -= dt * 0.9
		q.y -= 40.0 * dt
	pops = pops.filter(func(q): return q.life > 0.0)


func draw_fx() -> void:
	for q in parts:
		circ(q.x, q.y - cam_y, q.size, A(q.color, clamp(q.life / q.max, 0.0, 1.0)))
	for q in pops:
		txt(q.text, q.x, q.y - cam_y, 22, A(q.color, clamp(q.life * 1.6, 0.0, 1.0)), 1, Color(0, 0, 0, 0.4 * clamp(q.life * 1.6, 0.0, 1.0)))


# ================================================================ world generation
func mk_plat(x: float, y: float, w: float, type: String) -> Dictionary:
	return {"x": x, "y": y, "w": w, "type": type, "t": randf_range(0, 6), "base_x": x, "amp": 0.0, "spd": 1.3,
		"broken": false, "bvy": 0.0, "rot": 0.0, "dead": false, "fade": 1.0, "spring": false, "spring_t": 0.0}


func mk_enemy(x: float, y: float, d: float) -> Dictionary:
	var amp := randf_range(40, 80)
	return {"x": x, "y": y, "base_x": clamp(x, amp + 20, W - amp - 20), "amp": amp,
		"sp": randf_range(0.8, 1.4) + d * 0.9, "amp_extra": 0.0, "ph": randf_range(0, 6), "dead": false, "rot": 0.0}


func gen_platforms() -> void:
	while top_y > cam_y - 320.0:
		var d := diff()
		var x := extra()
		var sc := score()
		var gap := randf_range(50.0 + 25.0 * d, 82.0 + 40.0 * d)
		top_y -= gap
		var w := roundf(76.0 - 22.0 * d - 10.0 * x + randf_range(-4, 4))
		var cx: float = clamp(chain_x + randf_range(-170, 170), w / 2.0 + 6.0, W - w / 2.0 - 6.0)
		chain_x = cx
		var type := "normal"
		var r := randf()
		if sc > 100 and r < 0.08 + 0.30 * d + 0.12 * x:
			type = "moving"
		elif sc > 40 and r > 0.88 - 0.04 * d:
			type = "cloud"
		var pl := mk_plat(cx - w / 2.0, top_y, w, type)
		if type == "moving":
			pl.amp = min(70.0 + 20.0 * d, (W - w) / 2.0 - 6.0)
			pl.base_x = clamp(pl.x, pl.amp + 6.0, W - w - pl.amp - 6.0)
			pl.spd = 1.3 + 1.2 * d + 0.8 * x
		elif randf() < 0.09 * (1.0 - 0.6 * d):
			pl.spring = true
		plats.append(pl)
		if sc > 60 and randf() < 0.10 + 0.18 * d + 0.08 * x:
			plats.append(mk_plat(randf_range(8, W - 72), top_y + gap * 0.5, 64.0, "breakable"))
		var rc := randf()
		if rc < 0.28:
			coins_arr.append({"x": cx, "y": top_y - 40.0, "t": randf_range(0, 6), "got": false})
		elif rc < 0.34:
			for i in range(3):
				coins_arr.append({"x": cx, "y": top_y - 40.0 - i * 30.0, "t": randf_range(0, 6), "got": false})
		if sc > 120 and randf() < 0.012:
			items.append({"type": "rocket", "x": cx, "y": top_y - 52.0, "got": false})
		elif sc > 50 and randf() < 0.016:
			items.append({"type": "shield", "x": cx, "y": top_y - 52.0, "got": false})
		if sc > 150 and randf() < 0.05 + 0.10 * d + 0.08 * x:
			enemies.append(mk_enemy(randf_range(70, W - 70), top_y - randf_range(60, 90), d + x))


func new_game() -> void:
	state = St.PLAY
	cam_y = 0.0
	plats = []
	coins_arr = []
	items = []
	enemies = []
	parts = []
	pops = []
	p = {"x": W / 2.0, "y": H - 70.0 - 18.0, "vx": 0.0, "vy": -JUMP, "sq": 0.0, "blink": 2.0, "look": 1.0, "spin": 0.0}
	start_y = p.y
	max_h = 0.0
	bonus = 0
	run_coins = 0
	rocket_t = 0.0
	shield = false
	dying = false
	dying_t = 0.0
	hint_t = 4.5
	new_best = false
	shake = 0.0
	t = 0.0
	chain_x = W / 2.0
	last_lvl = 1
	plats.append(mk_plat(W / 2.0 - 70.0, H - 70.0, 140.0, "normal"))
	top_y = H - 70.0
	gen_platforms()
	play_sfx("jump")


# ================================================================ game logic
func land(pl: Dictionary) -> void:
	p.y = pl.y - 18.0
	if pl.type == "breakable":
		pl.broken = true
		pl.bvy = 0.0
		play_sfx("crack")
		burst(pl.x + pl.w / 2.0, pl.y, 10, Color("b98557"), 180, 0.6, 700)
		return
	var v := JUMP
	if pl.spring:
		v = JUMP * 1.65
		pl.spring_t = 0.3
		play_sfx("spring")
		p.sq = -0.3
		burst(p.x, pl.y, 10, Color("ffe27a"), 220, 0.5, 400)
	else:
		play_sfx("jump")
		p.sq = 0.28
	p.vy = -v
	burst(p.x, pl.y, 5, Color(1, 1, 1, 0.9), 90, 0.45, 200, 2.5)
	if pl.type == "cloud":
		pl.dead = true


func die(spin: bool) -> void:
	if dying:
		return
	dying = true
	dying_t = 0.0
	rocket_t = 0.0
	p.vy = -420.0 if spin else 0.0
	p.vx = randf_range(-90, 90) if spin else 0.0
	if spin:
		play_sfx("hit")
		shake = 12.0


func game_over() -> void:
	state = St.OVER
	final_score = score()
	new_best = final_score > save.best
	if new_best:
		save.best = final_score
	save.coins += run_coins
	persist()
	play_sfx("over")
	if new_best:
		var cols := [Color("ffd84d"), Color("ff7a59"), Color("6ea8ff"), Color("86e06c"), Color("ff93c9")]
		for i in range(70):
			burst(randf_range(60, 340), cam_y + randf_range(120, 300), 1, cols[i % cols.size()], 220, 1.6, 260, randf_range(2.5, 4.5))


func update_play(dt: float) -> void:
	t += dt
	hint_t = max(0.0, hint_t - dt)
	p.blink -= dt
	if p.blink < -0.12:
		p.blink = randf_range(1.8, 4.0)
	p.sq *= pow(0.0005, dt)

	if not dying:
		var dir := 0
		if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A): dir -= 1
		if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D): dir += 1
		if touch_dir != 0:
			dir = touch_dir
		p.vx += (dir * MAXVX - p.vx) * min(1.0, 10.0 * dt)
		if dir != 0:
			p.look = float(dir)
		var prev_y: float = p.y
		if rocket_t > 0.0:
			rocket_t -= dt
			p.vy = -560.0
			burst(p.x - 10.0 * p.look, p.y + 20.0, 1, Color("ffb347") if randf() < 0.5 else Color("ff6a3d"), 120, 0.3, 0.0, 4.0)
		else:
			p.vy += G * dt
		p.y += p.vy * dt
		p.x += p.vx * dt
		if p.x < -10.0:
			p.x = W + 10.0
		elif p.x > W + 10.0:
			p.x = -10.0

		if p.vy > 0.0 and rocket_t <= 0.0:
			var pb := prev_y + 18.0
			var b: float = p.y + 18.0
			for pl in plats:
				if pl.broken or pl.dead:
					continue
				if b >= pl.y and pb <= pl.y + 6.0 and p.x + 12.0 > pl.x and p.x - 12.0 < pl.x + pl.w:
					land(pl)
					break
		if p.y < cam_y + H * 0.4:
			cam_y = p.y - H * 0.4
		max_h = max(max_h, start_y - p.y)
		var l := lvl()
		if l > last_lvl:
			last_lvl = l
			pop("LEVEL %d" % l, p.x, p.y - 70.0, Color.WHITE)
			play_sfx("shield")

		for c in coins_arr:
			if not c.got and Vector2(c.x, c.y).distance_to(Vector2(p.x, p.y)) < 26.0:
				c.got = true
				run_coins += 1
				bonus += 5
				play_sfx("coin")
				burst(c.x, c.y, 8, Color("ffd84d"), 170, 0.5, 300)
				pop("+5", c.x, c.y - 10.0, Color("ffd84d"))
		for it in items:
			if not it.got and Vector2(it.x, it.y).distance_to(Vector2(p.x, p.y)) < 30.0:
				it.got = true
				play_sfx("power")
				if it.type == "rocket":
					rocket_t = 3.2
					pop("ROCKET!", p.x, p.y - 30.0, Color("ff9a4d"))
				else:
					shield = true
					pop("SHIELD!", p.x, p.y - 30.0, Color("7ad0ff"))
				burst(it.x, it.y, 14, Color.WHITE, 200, 0.6, 100)
				shake = 5.0
		for e in enemies:
			if e.dead:
				continue
			if abs(p.x - e.x) < 26.0 and abs(p.y - e.y) < 26.0:
				if p.vy > 80.0 and p.y < e.y - 4.0 and rocket_t <= 0.0:
					e.dead = true
					p.vy = -JUMP * 1.2
					p.sq = 0.3
					bonus += 20
					play_sfx("stomp")
					burst(e.x, e.y, 14, Color("d6334a"), 220, 0.6, 500)
					pop("+20", e.x, e.y - 14.0, Color("ffd84d"))
				elif rocket_t > 0.0:
					e.dead = true
					bonus += 20
					play_sfx("stomp")
					burst(e.x, e.y, 14, Color("d6334a"), 240, 0.6, 400)
					pop("+20", e.x, e.y - 14.0, Color("ffd84d"))
				elif shield:
					shield = false
					e.dead = true
					play_sfx("hit")
					burst(p.x, p.y, 16, Color("7ad0ff"), 240, 0.6, 200)
					shake = 8.0
				else:
					die(true)
		if p.y - cam_y > H + 40.0:
			if shield:
				shield = false
				p.y = cam_y + H - 40.0
				p.vy = -JUMP * 1.45
				play_sfx("shield")
				pop("SAVED!", p.x, p.y - 20.0, Color("7ad0ff"))
				burst(p.x, p.y, 16, Color("7ad0ff"), 240, 0.6, 200)
			else:
				die(false)
	else:
		dying_t += dt
		p.vy += G * dt
		p.y += p.vy * dt
		p.x += p.vx * dt
		p.spin += dt * 9.0
		if p.y - cam_y > H + 120.0 or dying_t > 2.0:
			game_over()

	for pl in plats:
		if pl.type == "moving":
			pl.x = pl.base_x + sin(t * pl.spd + pl.t) * pl.amp
		if pl.broken:
			pl.bvy += G * dt
			pl.y += pl.bvy * dt
			pl.rot += dt * 3.0
		if pl.dead:
			pl.fade -= dt * 4.0
		pl.spring_t = max(0.0, pl.spring_t - dt)
	for e in enemies:
		e.x = e.base_x + sin(t * e.sp + e.ph) * e.amp
		e.rot += dt * 2.5
	gen_platforms()
	var cut := cam_y + H + 100.0
	plats = plats.filter(func(pl): return pl.y < cut and pl.fade > 0.0)
	coins_arr = coins_arr.filter(func(c): return c.y < cut and not c.got)
	items = items.filter(func(i): return i.y < cut and not i.got)
	enemies = enemies.filter(func(e): return e.y < cut and not e.dead)
	update_fx(dt)


func update_menu(dt: float) -> void:
	t += dt
	menu_t += dt
	menu_msg_t = max(0.0, menu_msg_t - dt)
	var ph := fmod(menu_t * 1.2, 1.0)
	if ph < menu_phase:
		burst(W / 2.0, 450.0, 5, Color(1, 1, 1, 0.9), 90, 0.45, 200, 2.5)
	menu_phase = ph
	cam_y = 0.0
	update_fx(dt)


func _process(delta: float) -> void:
	var dt: float = min(delta, 0.033)
	shake = max(0.0, shake - dt * 30.0)
	match state:
		St.PLAY: update_play(dt)
		St.MENU: update_menu(dt)
		_:
			t += dt
			update_fx(dt)
	position = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake * 0.5 if shake > 0.0 else Vector2.ZERO
	queue_redraw()


# ================================================================ drawing: background
func sky_colors(a: float) -> Array:
	var i := 0
	while i < SKY.size() - 2 and a > SKY[i + 1].a:
		i += 1
	var f: float = clamp((a - SKY[i].a) / (SKY[i + 1].a - SKY[i].a), 0.0, 1.0)
	return [SKY[i].top.lerp(SKY[i + 1].top, f), SKY[i].bot.lerp(SKY[i + 1].bot, f)]


func draw_background(a: float) -> void:
	var c := sky_colors(a)
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(W, 0), Vector2(W, H), Vector2(0, H)]),
		PackedColorArray([c[0], c[0], c[1], c[1]]))
	var star_a: float = clamp((a - 2600.0) / 1800.0, 0.0, 1.0)
	if star_a > 0.0:
		for s in stars:
			var sy := fposmod(s.y - cam_y * 0.05, H)
			circ(s.x, sy, s.r, Color(1, 1, 1, star_a * (0.55 + 0.45 * sin(t * 2.0 + s.tw))))
	var sun_a: float = 1.0 - clamp(a / 2600.0, 0.0, 1.0)
	if sun_a > 0.0:
		for i in range(6):
			circ(318, 118, 70.0 - i * 8.0, Color(1, 0.93, 0.55, sun_a * (0.04 + i * 0.03)))
		circ(318, 118, 26, Color(1, 0.95, 0.69, sun_a))
	var moon_a: float = clamp((a - 3000.0) / 1500.0, 0.0, 1.0)
	if moon_a > 0.0:
		circ(76, 120, 28, Color(0.96, 0.95, 0.89, moon_a))
		var cr := Color(0.7, 0.69, 0.63, 0.5 * moon_a)
		circ(68, 112, 6, cr)
		circ(86, 128, 8, cr)
		circ(80, 106, 4, cr)
	var cloud_a: float = 0.92 - clamp((a - 2500.0) / 4000.0, 0.0, 1.0) * 0.78
	var tint := Color(1, 1, 1)
	if a >= 3500.0:
		tint = Color8(170, 160, 220)
	elif a >= 1500.0:
		tint = Color8(255, 226, 214)
	tint.a = cloud_a
	for c2 in clouds:
		var span := H + 200.0
		var sy := fposmod(c2.y - cam_y * c2.f, span) - 100.0
		var sx := fposmod(c2.x + t * c2.sp, W + 200.0) - 100.0
		var s: float = c2.s
		el(sx, sy, 34 * s, 14 * s, tint)
		el(sx - 22 * s, sy + 4 * s, 22 * s, 11 * s, tint)
		el(sx + 24 * s, sy + 5 * s, 24 * s, 11 * s, tint)
		el(sx + 2 * s, sy - 9 * s, 20 * s, 12 * s, tint)


# ================================================================ drawing: entities
func draw_plat(pl: Dictionary) -> void:
	var x: float = pl.x
	var y: float = pl.y - cam_y
	var w: float = pl.w
	if y < -40.0 or y > H + 60.0:
		return
	if pl.broken:
		draw_set_transform_matrix(Transform2D(0.0, Vector2(x + w / 2.0, y + 7.0)) * Transform2D(pl.rot, Vector2.ZERO) * Transform2D(0.0, Vector2(-w / 2.0, -7.0)))
	else:
		draw_set_transform_matrix(Transform2D(0.0, Vector2(x, y)))
	var al: float = max(0.0, pl.fade) if pl.dead else 1.0
	if pl.type == "cloud":
		el(w / 2.0, 12, w * 0.5, 6, Color(0.47, 0.59, 0.78, 0.35 * al))
		var wc := Color(1, 1, 1, al)
		el(w * 0.2, 7, 12, 9, wc)
		el(w * 0.45, 4, 15, 11, wc)
		el(w * 0.72, 7, 13, 9, wc)
		el(w * 0.5, 9, w * 0.42, 8, wc)
	else:
		var c1 := Color("8be06f")
		var c2 := Color("4fae4a")
		if pl.type == "moving":
			c1 = Color("7cc4ff")
			c2 = Color("3f8fd8")
		elif pl.type == "breakable":
			c1 = Color("d4a373")
			c2 = Color("a47148")
		rr(0, 3, w, 12, 6, A(c2, al))
		rr(0, 0, w, 11, 6, A(c1, al))
		rr(6, 2, w - 12, 3, 1.5, Color(1, 1, 1, 0.38 * al))
		if pl.type == "breakable":
			var cc := Color("7a4f2d")
			draw_polyline(PackedVector2Array([Vector2(w * 0.3, 0), Vector2(w * 0.4, 6), Vector2(w * 0.33, 12)]), cc, 2.0)
			draw_polyline(PackedVector2Array([Vector2(w * 0.7, 0), Vector2(w * 0.62, 7), Vector2(w * 0.7, 12)]), cc, 2.0)
		elif pl.type == "moving":
			circ(10, 6, 2, Color(1, 1, 1, 0.8))
			circ(w - 10, 6, 2, Color(1, 1, 1, 0.8))
	if pl.spring:
		var h: float = lerp(9.0, 22.0, pl.spring_t / 0.3)
		var sx := w / 2.0
		var pts := PackedVector2Array([Vector2(sx - 7.0, 0.0)])
		for i in range(1, 5):
			pts.append(Vector2(sx + (7.0 if i % 2 == 1 else -7.0), -h * i / 4.0))
		draw_polyline(pts, Color("e8443a"), 3.0)
		rr(sx - 10.0, -h - 5.0, 20.0, 6.0, 3.0, Color("ffd84d"))
	reset_xf()


func draw_coin(x: float, y: float, r: float, spin_t: float) -> void:
	var sx: float = max(0.25, abs(cos(spin_t)))
	el(x, y, r * sx, r, Color("e0a21c"))
	el(x, y, (r - 2.0) * sx, r - 2.0, Color("ffd84d"))
	rr(x - r * 0.2 * sx, y - r * 0.5, r * 0.4 * sx, r, 2, Color("fff1a8"))


func draw_item(it: Dictionary) -> void:
	var y: float = it.y - cam_y + sin(t * 3.0 + it.x) * 4.0
	draw_set_transform_matrix(Transform2D(0.0, Vector2(it.x, y)))
	if it.type == "rocket":
		var fin := Color("ff6a3d")
		tri(Vector2(-9, 6), Vector2(-17, 16), Vector2(-9, 14), fin)
		tri(Vector2(9, 6), Vector2(17, 16), Vector2(9, 14), fin)
		rr(-9, -16, 18, 32, 9, Color("f2f4fa"))
		draw_colored_polygon(PackedVector2Array([Vector2(-9, -8), Vector2(-6, -20), Vector2(0, -27), Vector2(6, -20), Vector2(9, -8)]), Color("ff4a5a"))
		circ(0, 0, 5, Color("6ea8ff"))
	else:
		circ(0, 0, 17, Color(0.48, 0.82, 1.0, 0.35))
		draw_arc(Vector2.ZERO, 16.0, 0.0, TAU, 32, Color("7ad0ff"), 3.0)
		el(-6, -7, 4, 2.5, Color(1, 1, 1, 0.8))
	reset_xf()


func draw_enemy(e: Dictionary) -> void:
	var pos := Vector2(e.x, e.y - cam_y)
	for i in range(10):
		draw_set_transform(pos, e.rot + (i + 1) * PI / 5.0, Vector2.ONE)
		tri(Vector2(-5, -13), Vector2(0, -25), Vector2(5, -13), Color("8f1d33"))
	draw_set_transform(pos, 0.0, Vector2.ONE)
	circ(0, 0, 16, Color("e03a55"))
	circ(-6, -3, 5, Color.WHITE)
	circ(6, -3, 5, Color.WHITE)
	var ink := Color("25141c")
	circ(-5, -2, 2.4, ink)
	circ(5, -2, 2.4, ink)
	draw_line(Vector2(-11, -9), Vector2(-3, -6), ink, 2.5)
	draw_line(Vector2(11, -9), Vector2(3, -6), ink, 2.5)
	draw_arc(Vector2(0, 9), 5.0, PI * 1.1, PI * 1.9, 8, ink, 2.5)
	reset_xf()


func draw_player(x: float, y: float, sk: Dictionary, sq := 0.0, locked := false, look := 0.0, blink_v := 1.0, spin := 0.0, jet := false, dead := false) -> void:
	draw_set_transform_matrix(Transform2D(spin, Vector2(x, y)).scaled_local(Vector2(1.0 - sq * 0.7, 1.0 + sq)))
	var body: Color = Color("5b6475") if locked else sk.body
	var dark: Color = Color("3d4452") if locked else sk.dark
	var ink := Color("1d2433")
	if jet:
		rr(-24, -6, 11, 24, 5, Color("d9dde5"))
		rr(-24, 14, 11, 5, 2, Color("ff6a3d"))
	el(-9, 17, 7, 4, dark)
	el(9, 17, 7, 4, dark)
	if sk.acc == "ears" and not locked:
		tri(Vector2(-16, -12), Vector2(-13, -29), Vector2(-3, -17), dark)
		tri(Vector2(16, -12), Vector2(13, -29), Vector2(3, -17), dark)
		tri(Vector2(-13, -15), Vector2(-12, -24), Vector2(-7, -17), sk.acc_col)
		tri(Vector2(13, -15), Vector2(12, -24), Vector2(7, -17), sk.acc_col)
	rr_grad(-18, -18, 36, 34, 15, body, dark)
	el(0, 7, 10, 7, Color(1, 1, 1, 0.28))
	var lk := look * 2.0
	var bl := 0.15 if blink_v < 0.0 else 1.0
	el(-7, -5, 6, 6.5 * bl, Color.WHITE)
	el(7, -5, 6, 6.5 * bl, Color.WHITE)
	if bl > 0.5:
		circ(-7 + lk, -4, 3, ink)
		circ(7 + lk, -4, 3, ink)
	el(-13, 3, 3.5, 2.2, Color(1, 0.47, 0.59, 0.45))
	el(13, 3, 3.5, 2.2, Color(1, 0.47, 0.59, 0.45))
	if dead:
		draw_arc(Vector2(0, 7), 3.0, PI, TAU, 8, ink, 2.0)
	else:
		draw_arc(Vector2(0, 3.5), 4.0, 0.15 * PI, 0.85 * PI, 10, ink, 2.0)
	if not locked:
		var ac: Color = sk.acc_col
		match sk.acc:
			"bow":
				tri(Vector2(8, -17), Vector2(19, -25), Vector2(19, -11), ac)
				tri(Vector2(8, -17), Vector2(-3, -25), Vector2(-3, -11), ac)
				circ(8, -17, 3, ac)
			"halo":
				var hp := el_pts(0, -25, 11, 4)
				hp.append(hp[0])
				draw_polyline(hp, ac, 3.5)
			"cap":
				var cp := PackedVector2Array()
				for i in range(13):
					cp.append(Vector2(0, -14) + Vector2.from_angle(PI + PI * i / 12.0) * 16.0)
				draw_colored_polygon(cp, ac)
				rr(-17, -16, 34, 5, 2.5, Color.WHITE)
				circ(0, -31, 4, Color.WHITE)
			"antenna":
				draw_line(Vector2(0, -18), Vector2(0, -29), dark, 2.5)
				circ(0, -31, 4, ac)
	reset_xf()


func draw_shield_bubble(x: float, y: float) -> void:
	var a := 0.55 + 0.15 * sin(t * 6.0)
	circ(x, y, 27, Color(0.48, 0.82, 1.0, a * 0.35))
	draw_arc(Vector2(x, y), 26.0, 0.0, TAU, 32, Color(0.63, 0.88, 1.0, a), 3.0)
	el(x - 10, y - 14, 5, 3, Color(1, 1, 1, 0.6))


# ================================================================ UI
func button(label: String, x: float, y: float, w: float, h: float, fn: Callable, kind := "secondary") -> void:
	ui.append({"r": Rect2(x, y, w, h), "fn": fn})
	if kind == "primary":
		rr(x, y + 4, w, h, h / 2.0, Color("d9502a"))
		rr_grad(x, y, w, h, h / 2.0, Color("ff9a5c"), Color("ff6a3d"))
		txt(label, x + w / 2.0, y + h / 2.0 + h * 0.18, int(h * 0.45), Color.WHITE)
	else:
		rr(x, y, w, h, h / 2.0, Color(1, 1, 1, 0.82))
		txt(label, x + w / 2.0, y + h / 2.0 + h * 0.18, int(h * 0.42), Color("1f3a5c"))


func arrow_button(x: float, y: float, dirn: float, fn: Callable) -> void:
	ui.append({"r": Rect2(x - 24, y - 24, 48, 48), "fn": fn})
	circ(x, y, 22, Color(1, 1, 1, 0.82))
	tri(Vector2(x + dirn * 7, y), Vector2(x - dirn * 5, y - 9), Vector2(x - dirn * 5, y + 9), Color("1f3a5c"))


func icon_button(x: float, y: float, kind: String, fn: Callable) -> void:
	ui.append({"r": Rect2(x - 4, y - 4, 44, 44), "fn": fn})
	rr(x, y, 36, 36, 12, Color(0, 0, 0, 0.28))
	if kind == "pause":
		rr(x + 11, y + 9, 5, 18, 2, Color.WHITE)
		rr(x + 20, y + 9, 5, 18, 2, Color.WHITE)
	else:
		draw_colored_polygon(PackedVector2Array([Vector2(x + 9, y + 14), Vector2(x + 15, y + 14), Vector2(x + 22, y + 8), Vector2(x + 22, y + 28), Vector2(x + 15, y + 22), Vector2(x + 9, y + 22)]), Color.WHITE)
		if muted:
			draw_line(Vector2(x + 26, y + 13), Vector2(x + 33, y + 23), Color.WHITE, 2.5)
			draw_line(Vector2(x + 33, y + 13), Vector2(x + 26, y + 23), Color.WHITE, 2.5)
		else:
			draw_arc(Vector2(x + 22, y + 18), 6.0, -0.9, 0.9, 8, Color.WHITE, 2.5)


func pause_game() -> void:
	state = St.PAUSE
	play_sfx("click")


func resume_game() -> void:
	state = St.PLAY


func skin_prev() -> void:
	change_skin(-1)


func skin_next() -> void:
	change_skin(1)


func toggle_mute() -> void:
	muted = not muted
	persist()
	if not muted:
		play_sfx("click")


func to_menu() -> void:
	state = St.MENU
	sel = save.skin
	parts = []
	pops = []
	cam_y = 0.0
	play_sfx("click")


func unlock_or_select() -> void:
	var s: Dictionary = SKINS[sel]
	if save.unlocked.has(sel):
		save.skin = sel
		persist()
		play_sfx("click")
		return
	if save.coins >= s.cost:
		save.coins -= s.cost
		save.unlocked.append(sel)
		save.skin = sel
		persist()
		play_sfx("power")
		burst(W / 2.0, 400.0, 22, Color("ffd84d"), 240, 0.9, 300)
	else:
		menu_msg = "Need %d more coins" % (s.cost - save.coins)
		menu_msg_t = 1.8
		play_sfx("hit")


func change_skin(d: int) -> void:
	sel = (sel + d + SKINS.size()) % SKINS.size()
	if save.unlocked.has(sel):
		save.skin = sel
		persist()
	play_sfx("click")


func start_from_menu() -> void:
	if not save.unlocked.has(save.skin):
		save.skin = 0
	play_sfx("click")
	new_game()


func draw_hud() -> void:
	var sc := str(score())
	txt(sc, 16, 50, 44, Color.WHITE, 0, Color(0, 0, 0, 0.35))
	txt("pts", 16 + text_w(sc, 44) + 6, 50, 16, Color(1, 1, 1, 0.9), 0, Color(0, 0, 0, 0.3))
	draw_coin(26, 74, 9, t * 3.0)
	txt(str(run_coins), 42, 80, 20, Color.WHITE, 0, Color(0, 0, 0, 0.35))
	var yy := 96.0
	if rocket_t > 0.0:
		rr(16, yy, 110, 10, 5, Color(0, 0, 0, 0.3))
		rr(16, yy, 110.0 * (rocket_t / 3.2), 10, 5, Color("ff9a4d"))
		yy += 18.0
	if shield:
		circ(26, yy + 6, 8, Color(0.48, 0.82, 1.0, 0.85))
		txt("Shield", 42, yy + 12, 16, Color.WHITE, 0, Color(0, 0, 0, 0.35))
	icon_button(W - 52, 14, "pause", pause_game)
	txt("LV %d" % lvl(), W - 16, 80, 18, Color.WHITE, 2, Color(0, 0, 0, 0.35))
	icon_button(W - 94, 14, "mute", toggle_mute)
	if hint_t > 0.0:
		var a: float = clamp(hint_t, 0.0, 1.0)
		txt("Hold left / right side or use arrow keys", W / 2.0, H - 26.0, 16, Color(1, 1, 1, a), 1, Color(0, 0, 0, 0.4 * a))


func overlay_card(x: float, y: float, w: float, h: float) -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0.03, 0.055, 0.125, 0.5))
	rr(x, y + 6, w, h, 28, Color(0, 0, 0, 0.2))
	rr(x, y, w, h, 28, Color.WHITE)


func draw_over() -> void:
	overlay_card(45, 120, 310, 390)
	txt("Game over", W / 2.0, 175, 32, Color("1f3a5c"))
	txt(str(final_score), W / 2.0, 258, 72, Color("ff6a3d"))
	txt("points", W / 2.0, 282, 17, Color("6a7c93"))
	if new_best:
		txt("New best!", W / 2.0, 318, 24, Color("e0a21c"))
	else:
		txt("Best %d" % save.best, W / 2.0, 318, 20, Color("6a7c93"))
	draw_coin(W / 2.0 - 46.0, 349, 10, t * 3.0)
	txt("+%d coins" % run_coins, W / 2.0 - 28.0, 356, 22, Color("1f3a5c"), 0)
	txt("Reached level %d" % lvl(), W / 2.0, 380, 15, Color("6a7c93"))
	button("Play again", 90, 394, 220, 54, new_game, "primary")
	button("Menu", 130, 458, 140, 42, to_menu)


func draw_pause() -> void:
	overlay_card(60, 190, 280, 260)
	txt("Paused", W / 2.0, 250, 36, Color("1f3a5c"))
	button("Resume", 90, 280, 220, 54, resume_game, "primary")
	button("Menu", 130, 350, 140, 42, to_menu)


func draw_menu() -> void:
	draw_background(3500.0 * (1.0 - cos(t * 0.12)) / 2.0)
	var bob := sin(t * 2.0) * 4.0
	var so := Color(0.137, 0.275, 0.55, 0.55)
	txt("Cloud", W / 2.0, 118.0 + bob, 68, Color.WHITE, 1, so)
	txt("Hopper", W / 2.0, 190.0 - bob, 76, Color("ffe27a"), 1, so)
	var ph := fmod(menu_t * 1.2, 1.0)
	var h := 4.0 * ph * (1.0 - ph) * 120.0
	var sq := 0.25 * (1.0 - ph / 0.1) if ph < 0.1 else 0.0
	var sk: Dictionary = SKINS[sel]
	var locked: bool = not save.unlocked.has(sel)
	draw_plat(mk_plat(W / 2.0 - 55.0, 450.0, 110.0, "normal"))
	draw_player(W / 2.0, 450.0 - 18.0 - h, sk, sq, locked, sin(t * 1.5), -1.0 if sin(t * 0.9) < -0.97 else 1.0)
	draw_fx()
	arrow_button(70, 392, -1.0, skin_prev)
	arrow_button(330, 392, 1.0, skin_next)
	txt(sk.name, W / 2.0, 500, 28, Color.WHITE, 1, Color(0, 0, 0, 0.35))
	if locked:
		button("Unlock    %d" % sk.cost, 120, 512, 160, 40, unlock_or_select)
	else:
		txt("Your hopper" if save.skin == sel else "Tap to pick", W / 2.0, 530, 16, Color(1, 1, 1, 0.9), 1, Color(0, 0, 0, 0.3))
	button("PLAY", 90, 566, 220, 56, start_from_menu, "primary")
	draw_coin(24, 28, 9, t * 3.0)
	txt(str(save.coins), 40, 35, 22, Color.WHITE, 0, Color(0, 0, 0, 0.35))
	txt("Best %d" % save.best, W / 2.0, 35, 20, Color.WHITE, 1, Color(0, 0, 0, 0.35))
	icon_button(W - 52, 14, "mute", toggle_mute)
	if menu_msg_t > 0.0:
		var a: float = clamp(menu_msg_t, 0.0, 1.0)
		txt(menu_msg, W / 2.0, 560, 16, Color(1, 0.89, 0.48, a), 1, Color(0, 0, 0, 0.5 * a))


func draw_world() -> void:
	draw_background(floor(max_h / 10.0))
	for pl in plats:
		draw_plat(pl)
	for c in coins_arr:
		draw_coin(c.x, c.y - cam_y, 9.0, t * 3.0 + c.t)
	for it in items:
		draw_item(it)
	for e in enemies:
		draw_enemy(e)
	if not p.is_empty():
		var sk: Dictionary = SKINS[save.skin if save.unlocked.has(save.skin) else 0]
		var spin: float = p.spin if dying else 0.0
		draw_player(p.x, p.y - cam_y, sk, p.sq, false, p.look, p.blink, spin, rocket_t > 0.0, dying)
		if p.x < 18.0:
			draw_player(p.x + W, p.y - cam_y, sk, p.sq, false, p.look)
		if p.x > W - 18.0:
			draw_player(p.x - W, p.y - cam_y, sk, p.sq, false, p.look)
		if shield and not dying:
			draw_shield_bubble(p.x, p.y - cam_y)
	draw_fx()


func _draw() -> void:
	ui = []
	match state:
		St.MENU:
			draw_menu()
		St.PLAY:
			draw_world()
			draw_hud()
		St.PAUSE:
			draw_world()
			draw_hud()
			ui = []
			draw_pause()
		St.OVER:
			draw_world()
			draw_over()


# ================================================================ input
func handle_key(code: int) -> void:
	if code == KEY_M:
		toggle_mute()
		return
	match state:
		St.MENU:
			if code == KEY_LEFT or code == KEY_A: change_skin(-1)
			elif code == KEY_RIGHT or code == KEY_D: change_skin(1)
			elif code == KEY_SPACE or code == KEY_ENTER:
				if not save.unlocked.has(sel):
					unlock_or_select()
				else:
					save.skin = sel
					persist()
					start_from_menu()
		St.PLAY:
			if code == KEY_ESCAPE or code == KEY_P: state = St.PAUSE
		St.PAUSE:
			if code == KEY_ESCAPE or code == KEY_P or code == KEY_SPACE or code == KEY_ENTER: state = St.PLAY
		St.OVER:
			if code == KEY_SPACE or code == KEY_ENTER: new_game()
			elif code == KEY_ESCAPE: to_menu()


func pointer_down(id: int, pos: Vector2) -> void:
	for i in range(ui.size() - 1, -1, -1):
		if ui[i].r.has_point(pos):
			ui[i].fn.call()
			return
	if state == St.PLAY:
		ptrs[id] = pos.x
		calc_touch()


func pointer_up(id: int) -> void:
	ptrs.erase(id)
	calc_touch()


func calc_touch() -> void:
	var d := 0
	for x in ptrs.values():
		d += -1 if x < W / 2.0 else 1
	touch_dir = signi(d)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		handle_key(event.keycode)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.device != InputEvent.DEVICE_ID_EMULATION:
		if event.pressed: pointer_down(-1, event.position)
		else: pointer_up(-1)
	elif event is InputEventMouseMotion and ptrs.has(-1):
		ptrs[-1] = event.position.x
		calc_touch()
	elif event is InputEventScreenTouch:
		if event.pressed: pointer_down(event.index, event.position)
		else: pointer_up(event.index)
	elif event is InputEventScreenDrag and ptrs.has(event.index):
		ptrs[event.index] = event.position.x
		calc_touch()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		ptrs.clear()
		touch_dir = 0
		if state == St.PLAY:
			state = St.PAUSE
