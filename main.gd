extends Node2D

var current_level = 1
var rows = 4
var cols = 6
var tile_size = Vector2(56, 56)
var start_pos = Vector2.ZERO

var grid = []
var selected_tile = null
var tile_nodes = {}
var remaining_tiles = 0

var score = 0
var high_score = 0
var combo_count = 0
var combo_timer = 0.0
var max_combo_delay = 3.0

var hint_count = 3
var shuffle_count = 3

var time_left = 60.0
var max_time = 60.0
var is_playing = false
var is_paused = false

# Load gambar karakter
var tile_textures = {
	1: preload("res://naruto.png"),
	2: preload("res://sasuke.png"),
	3: preload("res://sakura.png"),
	4: preload("res://kakashi.png"),
	5: preload("res://itachi.png"),
	6: preload("res://gaara.png")
}

# Mapping file suara karakter
var character_sfx = {
	1: ["res://naruto_sfx.mp3", "res://naruto_sfx.wav", "res://naruto_sfx.ogg"],
	2: ["res://sasuke_sfx.mp3", "res://sasuke_sfx.wav", "res://sasuke_sfx.ogg"],
	3: ["res://sakura_sfx.mp3", "res://sakura_sfx.wav", "res://sakura_sfx.ogg"],
	4: ["res://kakashi_sfx.mp3", "res://kakashi_sfx.wav", "res://kakashi_sfx.ogg"],
	5: ["res://itachi_sfx.mp3", "res://itachi_sfx.wav", "res://itachi_sfx.ogg"],
	6: ["res://gaara_sfx.mp3", "res://gaara_sfx.wav", "res://gaara_sfx.ogg"]
}

@onready var line_2d = $Line2D
@onready var level_label = $LevelLabel

# Node UI Dynamic
var texture_rect: TextureRect
var menu_container: Control
var level_select_container: Control
var in_game_ui: Control
var game_over_container: Control
var pause_container: Control
var ui_layer: CanvasLayer # CanvasLayer khusus agar UI Pause selalu di atas
var bgm_player: AudioStreamPlayer
var sfx_player: AudioStreamPlayer

var score_label: Label
var high_score_label: Label
var combo_label: Label
var timer_bar: ProgressBar
var game_over_label: Label
var shuffle_btn: Button
var hint_btn: Button

const SAVE_PATH = "user://highscore.save"

func _ready():
	randomize()
	load_high_score()
	setup_line_visual()
	setup_background()
	setup_audio()
	create_ui_elements()
	
	if level_label:
		level_label.add_theme_color_override("font_color", Color(1, 0.9, 0.2))
		level_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		level_label.add_theme_constant_override("outline_size", 4)
		level_label.add_theme_font_size_override("font_size", 26)
		level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		level_label.position = Vector2(476, 5)
		level_label.custom_minimum_size = Vector2(200, 30)
		
	show_main_menu()

func setup_line_visual():
	if line_2d:
		line_2d.width = 6.0
		line_2d.default_color = Color(1.0, 0.5, 0.0, 0.9)

func _process(delta):
	if is_playing and not is_paused:
		time_left -= delta
		
		if combo_count > 0:
			combo_timer -= delta
			if combo_timer <= 0:
				combo_count = 0
				if combo_label:
					combo_label.text = ""

		if timer_bar:
			timer_bar.value = time_left
			
			var fill_style = StyleBoxFlat.new()
			fill_style.corner_radius_top_left = 4
			fill_style.corner_radius_top_right = 4
			fill_style.corner_radius_bottom_left = 4
			fill_style.corner_radius_bottom_right = 4
			
			if time_left <= 10.0:
				fill_style.bg_color = Color(1, 0.2, 0.2)
			elif time_left <= 25.0:
				fill_style.bg_color = Color(1, 0.8, 0.2)
			else:
				fill_style.bg_color = Color(0.2, 0.8, 0.3)
			timer_bar.add_theme_stylebox_override("fill", fill_style)
			
		if time_left <= 0:
			is_playing = false
			show_game_over(false)

# --- SAVE & LOAD HIGH SCORE ---

func load_high_score():
	if FileAccess.file_exists(SAVE_PATH):
		var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file:
			high_score = file.get_32()

func save_high_score():
	if score > high_score:
		high_score = score
		var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		if file:
			file.store_32(high_score)

# --- SETUP BACKGROUND AUTOMATIS ---

func setup_background():
	texture_rect = get_node_or_null("TextureRect") as TextureRect
	if not texture_rect:
		texture_rect = TextureRect.new()
		texture_rect.name = "TextureRect"
		add_child(texture_rect)
		move_child(texture_rect, 0)

	if ResourceLoader.exists("res://background.png"):
		texture_rect.texture = load("res://background.png")
	
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_rect.stretch_mode = TextureRect.STRETCH_SCALE
	texture_rect.size = get_viewport_rect().size

# --- SETUP AUDIO AUTOMATIS ---

func setup_audio():
	bgm_player = AudioStreamPlayer.new()
	add_child(bgm_player)
	
	sfx_player = AudioStreamPlayer.new()
	add_child(sfx_player)
	
	if ResourceLoader.exists("res://bgm.ogg"):
		bgm_player.stream = load("res://bgm.ogg")
		bgm_player.play()
	elif ResourceLoader.exists("res://bgm.mp3"):
		bgm_player.stream = load("res://bgm.mp3")
		bgm_player.play()

func play_character_voice(type_id: int):
	if character_sfx.has(type_id):
		for file_path in character_sfx[type_id]:
			if ResourceLoader.exists(file_path):
				sfx_player.stream = load(file_path)
				sfx_player.play()
				break

# --- SISTEM UI & MENU UTAMA ---

func create_ui_elements():
	# CanvasLayer khusus agar seluruh UI Pop-up berada paling atas
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 100
	add_child(ui_layer)

	# 1. Main Menu Container
	menu_container = Control.new()
	menu_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_layer.add_child(menu_container)

	var title = Label.new()
	title.text = "ONET NARUTO GAME"
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color(1, 0.8, 0))
	title.position = Vector2(400, 140)
	menu_container.add_child(title)

	high_score_label = Label.new()
	high_score_label.text = "HIGH SCORE: " + str(high_score)
	high_score_label.add_theme_font_size_override("font_size", 20)
	high_score_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	high_score_label.position = Vector2(470, 190)
	menu_container.add_child(high_score_label)

	var play_btn = Button.new()
	play_btn.text = "PLAY GAME"
	play_btn.custom_minimum_size = Vector2(200, 50)
	play_btn.position = Vector2(475, 250)
	play_btn.pressed.connect(func(): start_level(1))
	menu_container.add_child(play_btn)

	var level_btn = Button.new()
	level_btn.text = "PILIH LEVEL"
	level_btn.custom_minimum_size = Vector2(200, 50)
	level_btn.position = Vector2(475, 320)
	level_btn.pressed.connect(show_level_select)
	menu_container.add_child(level_btn)

	# 2. Level Select Container
	level_select_container = Control.new()
	level_select_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_layer.add_child(level_select_container)

	var select_title = Label.new()
	select_title.text = "PILIH LEVEL"
	select_title.add_theme_font_size_override("font_size", 28)
	select_title.add_theme_color_override("font_color", Color(1, 0.8, 0))
	select_title.position = Vector2(490, 150)
	level_select_container.add_child(select_title)

	for i in range(1, 4):
		var lvl_btn = Button.new()
		lvl_btn.text = "LEVEL " + str(i)
		lvl_btn.custom_minimum_size = Vector2(150, 45)
		lvl_btn.position = Vector2(320 + (i - 1) * 170, 260)
		lvl_btn.pressed.connect(func(): start_level(i))
		level_select_container.add_child(lvl_btn)

	var back_btn = Button.new()
	back_btn.text = "KEMBALI"
	back_btn.custom_minimum_size = Vector2(150, 40)
	back_btn.position = Vector2(490, 360)
	back_btn.pressed.connect(show_main_menu)
	level_select_container.add_child(back_btn)

	# 3. In Game UI
	in_game_ui = Control.new()
	ui_layer.add_child(in_game_ui)

	var top_panel = ColorRect.new()
	top_panel.color = Color(0, 0, 0, 0.55)
	top_panel.size = Vector2(1152, 60)
	in_game_ui.add_child(top_panel)

	var main_menu_btn = Button.new()
	main_menu_btn.text = "PAUSE"
	main_menu_btn.custom_minimum_size = Vector2(80, 35)
	main_menu_btn.position = Vector2(20, 12)
	main_menu_btn.pressed.connect(toggle_pause)
	in_game_ui.add_child(main_menu_btn)

	shuffle_btn = Button.new()
	shuffle_btn.text = "SHUFFLE (3)"
	shuffle_btn.custom_minimum_size = Vector2(100, 35)
	shuffle_btn.position = Vector2(110, 12)
	shuffle_btn.pressed.connect(use_shuffle)
	in_game_ui.add_child(shuffle_btn)

	hint_btn = Button.new()
	hint_btn.text = "HINT (3)"
	hint_btn.custom_minimum_size = Vector2(90, 35)
	hint_btn.position = Vector2(220, 12)
	hint_btn.pressed.connect(use_hint)
	in_game_ui.add_child(hint_btn)

	score_label = Label.new()
	score_label.text = "SKOR: 0"
	score_label.add_theme_font_size_override("font_size", 18)
	score_label.add_theme_color_override("font_color", Color(1, 1, 1))
	score_label.position = Vector2(980, 10)
	in_game_ui.add_child(score_label)

	combo_label = Label.new()
	combo_label.text = ""
	combo_label.add_theme_font_size_override("font_size", 16)
	combo_label.add_theme_color_override("font_color", Color(1, 0.9, 0.2))
	combo_label.position = Vector2(980, 32)
	in_game_ui.add_child(combo_label)

	timer_bar = ProgressBar.new()
	timer_bar.custom_minimum_size = Vector2(380, 14)
	timer_bar.position = Vector2(386, 38)
	timer_bar.show_percentage = false
	in_game_ui.add_child(timer_bar)

	# 4. Pause Container
	pause_container = Control.new()
	pause_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_container.mouse_filter = Control.MOUSE_FILTER_STOP
	ui_layer.add_child(pause_container)

	var pause_bg = ColorRect.new()
	pause_bg.color = Color(0, 0, 0, 0.7)
	pause_bg.size = get_viewport_rect().size
	pause_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	pause_container.add_child(pause_bg)

	var pause_label = Label.new()
	pause_label.text = "PAUSED"
	pause_label.add_theme_font_size_override("font_size", 38)
	pause_label.add_theme_color_override("font_color", Color(1, 0.8, 0))
	pause_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_label.position = Vector2(376, 200)
	pause_label.custom_minimum_size = Vector2(400, 50)
	pause_container.add_child(pause_label)

	var resume_btn = Button.new()
	resume_btn.text = "LANJUTKAN"
	resume_btn.custom_minimum_size = Vector2(160, 45)
	resume_btn.position = Vector2(400, 300)
	resume_btn.pressed.connect(toggle_pause)
	pause_container.add_child(resume_btn)

	var pause_menu_btn = Button.new()
	pause_menu_btn.text = "MENU UTAMA"
	pause_menu_btn.custom_minimum_size = Vector2(160, 45)
	pause_menu_btn.position = Vector2(590, 300)
	pause_menu_btn.pressed.connect(show_main_menu)
	pause_container.add_child(pause_menu_btn)

	# 5. Game Over Pop-up
	game_over_container = Control.new()
	game_over_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	game_over_container.mouse_filter = Control.MOUSE_FILTER_STOP
	ui_layer.add_child(game_over_container)

	var bg_overlay = ColorRect.new()
	bg_overlay.color = Color(0, 0, 0, 0.75)
	bg_overlay.size = get_viewport_rect().size
	bg_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	game_over_container.add_child(bg_overlay)

	game_over_label = Label.new()
	game_over_label.text = "WAKTU HABIS!"
	game_over_label.add_theme_font_size_override("font_size", 40)
	game_over_label.add_theme_color_override("font_color", Color(1, 0.2, 0.2))
	game_over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_over_label.position = Vector2(376, 220)
	game_over_label.custom_minimum_size = Vector2(400, 50)
	game_over_container.add_child(game_over_label)

	var retry_btn = Button.new()
	retry_btn.text = "COBA LAGI"
	retry_btn.custom_minimum_size = Vector2(160, 50)
	retry_btn.position = Vector2(400, 320)
	retry_btn.pressed.connect(func(): start_level(current_level))
	game_over_container.add_child(retry_btn)

	var go_menu_btn = Button.new()
	go_menu_btn.text = "MENU UTAMA"
	go_menu_btn.custom_minimum_size = Vector2(160, 50)
	go_menu_btn.position = Vector2(590, 320)
	go_menu_btn.pressed.connect(show_main_menu)
	game_over_container.add_child(go_menu_btn)

func toggle_pause():
	if not is_playing:
		return
	is_paused = not is_paused
	pause_container.visible = is_paused
	
	# Nonaktifkan klik kartu saat game sedang di-pause
	for pos in tile_nodes:
		if is_instance_valid(tile_nodes[pos]):
			tile_nodes[pos].disabled = is_paused

func show_main_menu():
	is_playing = false
	is_paused = false
	clear_board()
	high_score_label.text = "HIGH SCORE: " + str(high_score)
	menu_container.visible = true
	level_select_container.visible = false
	in_game_ui.visible = false
	pause_container.visible = false
	game_over_container.visible = false
	if level_label:
		level_label.visible = false

func show_level_select():
	menu_container.visible = false
	level_select_container.visible = true
	in_game_ui.visible = false
	pause_container.visible = false
	game_over_container.visible = false
	if level_label:
		level_label.visible = false

func show_game_over(win: bool):
	is_playing = false
	is_paused = false
	save_high_score()
	clear_board()
	game_over_container.visible = true
	in_game_ui.visible = false
	pause_container.visible = false
	if level_label:
		level_label.visible = false

	if win:
		game_over_label.text = "LEVEL COMPLETED!"
		game_over_label.add_theme_color_override("font_color", Color(0.2, 1, 0.2))
	else:
		game_over_label.text = "WAKTU HABIS!"
		game_over_label.add_theme_color_override("font_color", Color(1, 0.2, 0.2))

# --- LOGIKA GAMEPLAY ---

func start_level(level: int):
	current_level = level
	if level == 1:
		score = 0
	combo_count = 0
	hint_count = 3
	shuffle_count = 3
	is_paused = false
	
	score_label.text = "SKOR: " + str(score)
	combo_label.text = ""
	shuffle_btn.text = "SHUFFLE (" + str(shuffle_count) + ")"
	hint_btn.text = "HINT (" + str(hint_count) + ")"
	
	menu_container.visible = false
	level_select_container.visible = false
	in_game_ui.visible = true
	pause_container.visible = false
	game_over_container.visible = false
	
	if level_label:
		level_label.visible = true
		level_label.text = "LEVEL " + str(current_level)

	clear_board()
	
	match level:
		1:
			rows = 4
			cols = 6
			max_time = 60.0
		2:
			rows = 6
			cols = 8
			max_time = 90.0
		_:
			rows = 6
			cols = 10
			max_time = 120.0

	time_left = max_time
	timer_bar.max_value = max_time
	timer_bar.value = max_time

	var viewport_size = get_viewport_rect().size
	var total_grid_size = Vector2(float(cols + 2) * tile_size.x, float(rows + 2) * tile_size.y)
	start_pos = (viewport_size - total_grid_size) / 2.0

	init_grid()
	create_tiles()
	is_playing = true

func clear_board():
	for pos in tile_nodes:
		if is_instance_valid(tile_nodes[pos]):
			tile_nodes[pos].queue_free()
	tile_nodes.clear()
	grid.clear()
	selected_tile = null

func init_grid():
	var total_cards = rows * cols
	remaining_tiles = total_cards
	var pairs_count = int(total_cards / 2.0)
	var values = []
	
	var max_types = min(3 + current_level, tile_textures.size())
	
	for i in range(pairs_count):
		var type_id = (i % max_types) + 1
		values.append(type_id)
		values.append(type_id)
	values.shuffle()

	var index = 0
	for r in range(rows + 2):
		var row = []
		for c in range(cols + 2):
			if r == 0 or r == rows + 1 or c == 0 or c == cols + 1:
				row.append(0)
			else:
				row.append(values[index])
				index += 1
		grid.append(row)

func create_tiles():
	var card_style = StyleBoxFlat.new()
	card_style.bg_color = Color(0.18, 0.20, 0.26, 1.0)
	card_style.set_border_width_all(2)
	card_style.border_color = Color(0.4, 0.5, 0.7, 0.9)
	card_style.set_corner_radius_all(6)

	for r in range(1, rows + 1):
		for c in range(1, cols + 1):
			var val = grid[r][c]
			if val == 0:
				continue
				
			var btn = Button.new()
			btn.text = ""
			btn.icon = tile_textures[val]
			btn.expand_icon = true
			btn.mouse_filter = Control.MOUSE_FILTER_STOP
			
			btn.add_theme_stylebox_override("normal", card_style)
			
			btn.custom_minimum_size = tile_size
			btn.size = tile_size
			btn.position = start_pos + Vector2(c * tile_size.x, r * tile_size.y)
			btn.pressed.connect(_on_tile_pressed.bind(r, c))
			add_child(btn)
			tile_nodes[Vector2i(c, r)] = btn

func _on_tile_pressed(r, c):
	if not is_playing or is_paused or grid[r][c] == 0:
		return

	var pos = Vector2i(c, r)

	if selected_tile == null:
		selected_tile = pos
		highlight_tile(pos, true)
	elif selected_tile == pos:
		highlight_tile(pos, false)
		selected_tile = null
	else:
		var p1 = selected_tile
		var p2 = pos
		var tile_val = grid[p1.y][p1.x]
		
		if tile_val == grid[p2.y][p2.x]:
			var path = find_path(p1, p2)
			if path.size() > 0:
				draw_line_path(path)
				
				combo_count += 1
				combo_timer = max_combo_delay
				combo_label.text = "COMBO x" + str(combo_count) + "!"
				time_left = min(time_left + 2.0, max_time)
				
				var gained_score = 100 * combo_count
				score += gained_score
				score_label.text = "SKOR: " + str(score)
				
				spawn_floating_text("+" + str(gained_score), p2)
				
				if remaining_tiles == 2:
					play_character_voice(tile_val)
				
				remove_tile(p1)
				remove_tile(p2)
				selected_tile = null
				
				await get_tree().create_timer(0.2).timeout
				apply_board_gravity()
				check_level_complete()
				return
		
		flash_wrong_tiles(p1, p2)
		highlight_tile(p1, false)
		selected_tile = pos
		highlight_tile(pos, true)

func apply_board_gravity():
	if current_level == 2:
		for c in range(1, cols + 1):
			for r in range(rows, 0, -1):
				if grid[r][c] == 0:
					for kr in range(r - 1, 0, -1):
						if grid[kr][c] != 0:
							move_tile_data(Vector2i(c, kr), Vector2i(c, r))
							break
	elif current_level >= 3:
		for r in range(1, rows + 1):
			for c in range(1, cols + 1):
				if grid[r][c] == 0:
					for kc in range(c + 1, cols + 1):
						if grid[r][kc] != 0:
							move_tile_data(Vector2i(kc, r), Vector2i(c, r))
							break

func move_tile_data(from_pos: Vector2i, to_pos: Vector2i):
	grid[to_pos.y][to_pos.x] = grid[from_pos.y][from_pos.x]
	grid[from_pos.y][from_pos.x] = 0
	
	if tile_nodes.has(from_pos):
		var btn = tile_nodes[from_pos]
		tile_nodes.erase(from_pos)
		tile_nodes[to_pos] = btn
		
		btn.disconnect("pressed", _on_tile_pressed)
		btn.pressed.connect(_on_tile_pressed.bind(to_pos.y, to_pos.x))
		
		var target_world_pos = start_pos + Vector2(to_pos.x * tile_size.x, to_pos.y * tile_size.y)
		var tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(btn, "position", target_world_pos, 0.2)

func spawn_floating_text(txt: String, grid_pos: Vector2i):
	var float_label = Label.new()
	float_label.text = txt
	float_label.add_theme_font_size_override("font_size", 18)
	float_label.add_theme_color_override("font_color", Color(1, 0.9, 0.2))
	
	var world_pos = start_pos + Vector2(grid_pos.x * tile_size.x, grid_pos.y * tile_size.y)
	float_label.position = world_pos
	add_child(float_label)
	
	var tween = create_tween()
	tween.tween_property(float_label, "position:y", world_pos.y - 30.0, 0.5)
	tween.parallel().tween_property(float_label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(float_label.queue_free)

func highlight_tile(pos: Vector2i, enable: bool):
	if tile_nodes.has(pos) and is_instance_valid(tile_nodes[pos]):
		if enable:
			var active_style = StyleBoxFlat.new()
			active_style.bg_color = Color(0.3, 0.6, 1.0, 1.0)
			active_style.set_border_width_all(3)
			active_style.border_color = Color(1.0, 0.9, 0.2)
			active_style.set_corner_radius_all(6)
			tile_nodes[pos].add_theme_stylebox_override("normal", active_style)
		else:
			var normal_style = StyleBoxFlat.new()
			normal_style.bg_color = Color(0.18, 0.20, 0.26, 1.0)
			normal_style.set_border_width_all(2)
			normal_style.border_color = Color(0.4, 0.5, 0.7, 0.9)
			normal_style.set_corner_radius_all(6)
			tile_nodes[pos].add_theme_stylebox_override("normal", normal_style)

func flash_wrong_tiles(p1: Vector2i, p2: Vector2i):
	if tile_nodes.has(p1):
		tile_nodes[p1].modulate = Color(1, 0.3, 0.3)
	if tile_nodes.has(p2):
		tile_nodes[p2].modulate = Color(1, 0.3, 0.3)
		
	var tween = create_tween()
	tween.tween_property(tile_nodes[p1], "modulate", Color(1, 1, 1), 0.2)
	tween.parallel().tween_property(tile_nodes[p2], "modulate", Color(1, 1, 1), 0.2)

func remove_tile(pos: Vector2i):
	grid[pos.y][pos.x] = 0
	if tile_nodes.has(pos):
		var btn = tile_nodes[pos]
		tile_nodes.erase(pos)
		
		var tween = create_tween()
		tween.tween_property(btn, "scale", Vector2.ZERO, 0.15)
		tween.tween_callback(btn.queue_free)
		remaining_tiles -= 1

func use_hint():
	if not is_playing or is_paused or hint_count <= 0:
		return
		
	var pair = find_pair_move()
	if pair.size() == 2:
		hint_count -= 1
		hint_btn.text = "HINT (" + str(hint_count) + ")"
		
		var p1 = pair[0]
		var p2 = pair[1]
		
		var tween1 = create_tween().set_loops(3)
		tween1.tween_property(tile_nodes[p1], "modulate", Color(0.2, 1, 0.2), 0.15)
		tween1.tween_property(tile_nodes[p1], "modulate", Color(1, 1, 1), 0.15)
		
		var tween2 = create_tween().set_loops(3)
		tween2.tween_property(tile_nodes[p2], "modulate", Color(0.2, 1, 0.2), 0.15)
		tween2.tween_property(tile_nodes[p2], "modulate", Color(1, 1, 1), 0.15)

func use_shuffle():
	if not is_playing or is_paused or shuffle_count <= 0:
		return
		
	shuffle_count -= 1
	shuffle_btn.text = "SHUFFLE (" + str(shuffle_count) + ")"
	shuffle_board()

func check_level_complete():
	if remaining_tiles <= 0:
		is_playing = false
		await get_tree().create_timer(0.5).timeout
		current_level += 1
		
		if current_level > 3:
			show_game_over(true)
		else:
			start_level(current_level)
	else:
		if not has_valid_moves():
			shuffle_board()

func shuffle_board():
	if not is_playing:
		return
		
	var current_values = []
	var positions = []

	for r in range(1, rows + 1):
		for c in range(1, cols + 1):
			if grid[r][c] != 0:
				current_values.append(grid[r][c])
				positions.append(Vector2i(c, r))

	current_values.shuffle()

	for i in range(positions.size()):
		var pos = positions[i]
		var val = current_values[i]
		grid[pos.y][pos.x] = val
		if tile_nodes.has(pos):
			tile_nodes[pos].icon = tile_textures[val]
			highlight_tile(pos, false)

	selected_tile = null

func find_pair_move() -> Array:
	var active_tiles = []
	for r in range(1, rows + 1):
		for c in range(1, cols + 1):
			if grid[r][c] != 0:
				active_tiles.append(Vector2i(c, r))

	for i in range(active_tiles.size()):
		for j in range(i + 1, active_tiles.size()):
			var p1 = active_tiles[i]
			var p2 = active_tiles[j]
			if grid[p1.y][p1.x] == grid[p2.y][p2.x]:
				if find_path(p1, p2).size() > 0:
					return [p1, p2]
	return []

func has_valid_moves() -> bool:
	return find_pair_move().size() > 0

func draw_line_path(path: Array):
	line_2d.clear_points()
	line_2d.modulate = Color(1, 1, 1, 1)
	
	for p in path:
		var world_pos = start_pos + Vector2(p.x * tile_size.x, p.y * tile_size.y) + tile_size / 2.0
		line_2d.add_point(world_pos)
	
	var tween = create_tween()
	tween.tween_property(line_2d, "modulate:a", 0.0, 0.25)
	tween.tween_callback(line_2d.clear_points)

# Algoritma Pathfinding Onet (Max 2 Belokan)
func find_path(p1: Vector2i, p2: Vector2i) -> Array:
	if check_line(p1, p2):
		return [p1, p2]

	var c1 = Vector2i(p1.x, p2.y)
	if is_empty(c1) and check_line(p1, c1) and check_line(c1, p2):
		return [p1, c1, p2]

	var c2 = Vector2i(p2.x, p1.y)
	if is_empty(c2) and check_line(p1, c2) and check_line(c2, p2):
		return [p1, c2, p2]

	for r in range(rows + 2):
		var k1 = Vector2i(p1.x, r)
		var k2 = Vector2i(p2.x, r)
		if (k1 == p1 or is_empty(k1)) and (k2 == p2 or is_empty(k2)):
			if check_line(p1, k1) and check_line(k1, k2) and check_line(k2, p2):
				return [p1, k1, k2, p2]

	for c in range(cols + 2):
		var k1 = Vector2i(c, p1.y)
		var k2 = Vector2i(c, p2.y)
		if (k1 == p1 or is_empty(k1)) and (k2 == p2 or is_empty(k2)):
			if check_line(p1, k1) and check_line(k1, k2) and check_line(k2, p2):
				return [p1, k1, k2, p2]

	return []

func check_line(p1: Vector2i, p2: Vector2i) -> bool:
	if p1.x != p2.x and p1.y != p2.y:
		return false
	var min_x = min(p1.x, p2.x)
	var max_x = max(p1.x, p2.x)
	var min_y = min(p1.y, p2.y)
	var max_y = max(p1.y, p2.y)

	if p1.x == p2.x:
		for y in range(min_y + 1, max_y):
			if grid[y][p1.x] != 0:
				return false
	else:
		for x in range(min_x + 1, max_x):
			if grid[p1.y][x] != 0:
				return false
	return true

func is_empty(p: Vector2i) -> bool:
	return grid[p.y][p.x] == 0
