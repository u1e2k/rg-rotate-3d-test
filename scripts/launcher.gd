class_name LauncherHub
extends Node3D

## Launcher and Benchmark Mode Selector for ANBERNIC RG Rotate (720x720)
## Pure Node3D scene with its own dedicated WorldEnvironment and Camera3D to guarantee clean buffer clearing.

const SoundManagerScript = preload("res://scripts/sound_manager.gd")
const SettingsScript = preload("res://scripts/settings_manager.gd")

@onready var sound_manager: Node = $SoundManager

# UI References
@onready var mode_title_label: Label = $UI/Margin/VBox/CenterCard/Margin/VBox/Header/TitleLabel
@onready var mode_badge_label: Label = $UI/Margin/VBox/CenterCard/Margin/VBox/Header/BadgePanel/BadgeLabel
@onready var mode_badge_panel: PanelContainer = $UI/Margin/VBox/CenterCard/Margin/VBox/Header/BadgePanel
@onready var mode_subtitle_label: Label = $UI/Margin/VBox/CenterCard/Margin/VBox/SubtitleLabel
@onready var mode_desc_label: Label = $UI/Margin/VBox/CenterCard/Margin/VBox/DescLabel
@onready var tech_specs_label: Label = $UI/Margin/VBox/CenterCard/Margin/VBox/TechSpecsPanel/Margin/TechSpecsLabel
@onready var mode_icon_rect: ColorRect = $UI/Margin/VBox/CenterCard/Margin/VBox/IconBox/ColorRect
@onready var mode_counter_label: Label = $UI/Margin/VBox/NavBar/CounterLabel
@onready var action_button_label: Label = $UI/Margin/VBox/ActionPrompt/PromptLabel
@onready var fps_label: Label = $UI/Margin/VBox/TopBar/FpsLabel

# Key Visualizer Indicators
@onready var key_up: Label = $UI/InputOverlay/Grid/Up
@onready var key_down: Label = $UI/InputOverlay/Grid/Down
@onready var key_left: Label = $UI/InputOverlay/Grid/Left
@onready var key_right: Label = $UI/InputOverlay/Grid/Right
@onready var key_a: Label = $UI/InputOverlay/Grid/A
@onready var key_b: Label = $UI/InputOverlay/Grid/B
@onready var key_x: Label = $UI/InputOverlay/Grid/X
@onready var key_y: Label = $UI/InputOverlay/Grid/Y
@onready var key_lb: Label = $UI/InputOverlay/Grid/LB
@onready var key_rb: Label = $UI/InputOverlay/Grid/RB

var modes: Array[Dictionary] = [
	{
		"id": "sandbox",
		"title": "1. 3D Sandbox & Flight",
		"badge": "PLAYABLE (60 FPS)",
		"badge_color": Color(0.15, 0.75, 0.35),
		"subtitle": "基本3Dアクション & 飛行機フライト",
		"desc": "十字キー旋回＋自動カメラ追従、階段昇降、リフト、物理ブロックタワー、クリスタル収集、射撃、シームレス搭乗型飛行機テスト。",
		"tech": "・解像度: 720×720 (1:1)\n・描画: gl_compatibility (GLES3)\n・物理: Jolt/Godot Physics 3D\n・音響: Procedural WAV",
		"scene": "res://scenes/main.tscn",
		"playable": true,
		"theme_color": Color(0.2, 0.55, 0.95)
	},
	{
		"id": "musou",
		"title": "2. Musou Horde Benchmark",
		"badge": "PLAYABLE (60 FPS)",
		"badge_color": Color(0.95, 0.45, 0.15),
		"subtitle": "三國無双ライク 大群ワラワラ検証",
		"desc": "画面内に50〜100体以上のローポリ敵兵士を同時描画。MultiMeshInstance3Dによる超低負荷レンダリングと薙ぎ払い吹っ飛ばしアクション。",
		"tech": "・描画: MultiMesh (1 Draw Call)\n・アニメ: コード駆動軽量変形\n・群集AI: 2D平面距離・円形押し合い\n・負荷切替: 30 / 60 / 100 / 150体",
		"scene": "res://scenes/musou_mode.tscn",
		"playable": true,
		"theme_color": Color(0.95, 0.30, 0.20)
	},
	{
		"id": "space",
		"title": "3. Star Flight & Space",
		"badge": "PLAYABLE (60 FPS)",
		"badge_color": Color(0.65, 0.35, 0.95),
		"subtitle": "スターフォックス / Elite風 ドッグファイト",
		"desc": "3D無重力フライト（ピッチ・ロール・ブースト）、アステロイド小惑星群、ロックオンホーミングミサイル、敵戦闘機編隊AIの検証。",
		"tech": "・背景: プロシージャル・スターフィールド\n・小惑星: MultiMesh アステロイド群\n・カメラ: 三人称追従 / コックピット\n・戦闘: ロックオンHUD & レティクル",
		"scene": "res://scenes/space_flight_mode.tscn",
		"playable": true,
		"theme_color": Color(0.65, 0.35, 0.95)
	},
	{
		"id": "openworld",
		"title": "4. Open World & Terrain",
		"badge": "PLAYABLE (60 FPS)",
		"badge_color": Color(0.20, 0.80, 0.45),
		"subtitle": "広大マップ・LOD & バギー走破",
		"desc": "1 - 2km四方の起伏のある広域ハイトマップ、距離フォグ、木々・岩の動的インスタンシング、4輪バギーでの高速走破ストレステスト。",
		"tech": "・地形: グリッドチャンク & LODメッシュ\n・フォグ: 低負荷距離フォグ\n・ストリーミング: チャンク単位動的生成\n・ビークル: 4輪サスペンションバギー",
		"scene": "res://scenes/openworld_mode.tscn",
		"playable": true,
		"theme_color": Color(0.20, 0.80, 0.45)
	},
	{
		"id": "dungeon",
		"title": "5. Dungeon & Boss Battle",
		"badge": "PLAYABLE (60 FPS)",
		"badge_color": Color(0.95, 0.25, 0.25),
		"subtitle": "閉鎖空間・動的光源 & 巨大ゴーレム",
		"desc": "石造りダンジョン回廊での動的光源ストレステスト、Z注目ロックオン、緊急ステップ回避、予兆衝撃波を放つ巨大ボスAI。",
		"tech": "・視点: Z注目ロックオン & 自動追従\n・回避: 無敵フレーム付きステップダッシュ\n・光源: 2灯(最適化) / 6灯(ストレステスト)\n・ボス: 予兆モーション & 衝撃波リング",
		"scene": "res://scenes/dungeon_mode.tscn",
		"playable": true,
		"theme_color": Color(0.95, 0.25, 0.25)
	}
]

var current_mode_index: int = 0
var input_cooldown: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = false # Ensure pause state is cleanly cleared
	SettingsScript.load_settings()
	_update_ui()
	_update_indicators()

func _process(delta: float) -> void:
	if input_cooldown > 0.0:
		input_cooldown -= delta
		
	# Update FPS
	fps_label.text = "%d FPS" % Engine.get_frames_per_second()
	
	_update_indicators()

func _input(event: InputEvent) -> void:
	if input_cooldown > 0.0:
		return
		
	# D-pad navigation (Supports Action, Key, and explicit Joypad button index)
	var is_prev = false
	var is_next = false
	var is_select = false
	
	if event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_DPAD_LEFT or event.button_index == JOY_BUTTON_DPAD_UP:
			is_prev = true
		elif event.button_index == JOY_BUTTON_DPAD_RIGHT or event.button_index == JOY_BUTTON_DPAD_DOWN:
			is_next = true
		elif event.button_index == JOY_BUTTON_A:
			is_select = true
			
	if not (is_prev or is_next or is_select):
		if event.is_action_pressed("turn_left") or event.is_action_pressed("ui_left") or event.is_action_pressed("move_backward") or event.is_action_pressed("ui_up"):
			is_prev = true
		elif event.is_action_pressed("turn_right") or event.is_action_pressed("ui_right") or event.is_action_pressed("move_forward") or event.is_action_pressed("ui_down"):
			is_next = true
		elif event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
			is_select = true
			
	if is_prev:
		_change_mode(-1)
		var vp = get_viewport()
		if vp: vp.set_input_as_handled()
	elif is_next:
		_change_mode(1)
		var vp = get_viewport()
		if vp: vp.set_input_as_handled()
	elif is_select:
		_launch_current_mode()
		var vp = get_viewport()
		if vp: vp.set_input_as_handled()

func _change_mode(direction: int) -> void:
	current_mode_index = posmod(current_mode_index + direction, modes.size())
	input_cooldown = 0.18
	if sound_manager and sound_manager.has_method("play_cursor"):
		sound_manager.play_cursor()
	_update_ui()

func _update_ui() -> void:
	var mode = modes[current_mode_index]
	
	mode_title_label.text = mode["title"]
	mode_subtitle_label.text = mode["subtitle"]
	mode_desc_label.text = mode["desc"]
	tech_specs_label.text = mode["tech"]
	mode_badge_label.text = mode["badge"]
	
	mode_counter_label.text = "MODE %d / %d" % [current_mode_index + 1, modes.size()]
	
	# Badge & Accent Color
	var theme_color: Color = mode.get("theme_color", Color.WHITE)
	mode_icon_rect.color = theme_color
	
	if mode["playable"]:
		action_button_label.text = "▶ [ A ボタン ] でモード開始"
		action_button_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4))
	else:
		action_button_label.text = "🔒 [ 近日実装予定 ]"
		action_button_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))

func _launch_current_mode() -> void:
	var mode = modes[current_mode_index]
	if not mode["playable"] or mode["scene"].is_empty():
		if sound_manager and sound_manager.has_method("play_cancel"):
			sound_manager.play_cancel()
		return
		
	if not ResourceLoader.exists(mode["scene"]):
		push_warning("Scene does not exist: %s" % mode["scene"])
		if sound_manager and sound_manager.has_method("play_cancel"):
			sound_manager.play_cancel()
		return
		
	if sound_manager and sound_manager.has_method("play_confirm"):
		sound_manager.play_confirm()
		
	input_cooldown = 1.0
	get_tree().change_scene_to_file(mode["scene"])

func _update_indicators() -> void:
	var c_active = Color(0.2, 1.0, 0.4, 1.0)
	var c_dim = Color(1.0, 1.0, 1.0, 0.25)
	
	_set_key_state(key_up, Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_UP) or Input.is_action_pressed("move_forward") or Input.is_action_pressed("ui_up"), c_active, c_dim)
	_set_key_state(key_down, Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_DOWN) or Input.is_action_pressed("move_backward") or Input.is_action_pressed("ui_down"), c_active, c_dim)
	_set_key_state(key_left, Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_LEFT) or Input.is_action_pressed("turn_left") or Input.is_action_pressed("ui_left"), c_active, c_dim)
	_set_key_state(key_right, Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_RIGHT) or Input.is_action_pressed("turn_right") or Input.is_action_pressed("ui_right"), c_active, c_dim)
	
	# Dedicated Joypad Button Query to prevent crosstalk
	var joy_a = Input.is_joy_button_pressed(0, JOY_BUTTON_A) or Input.is_key_pressed(KEY_E) or Input.is_key_pressed(KEY_ENTER)
	var joy_b = Input.is_joy_button_pressed(0, JOY_BUTTON_B) or Input.is_key_pressed(KEY_SPACE)
	var joy_x = Input.is_joy_button_pressed(0, JOY_BUTTON_X)
	var joy_y = Input.is_joy_button_pressed(0, JOY_BUTTON_Y) or Input.is_key_pressed(KEY_SHIFT)
	var joy_lb = Input.is_joy_button_pressed(0, JOY_BUTTON_LEFT_SHOULDER) or Input.is_key_pressed(KEY_Q)
	var joy_rb = Input.is_joy_button_pressed(0, JOY_BUTTON_RIGHT_SHOULDER) or Input.is_key_pressed(KEY_F)
	
	_set_key_state(key_a, joy_a, c_active, c_dim)
	_set_key_state(key_b, joy_b, c_active, c_dim)
	_set_key_state(key_x, joy_x, c_active, c_dim)
	_set_key_state(key_y, joy_y, c_active, c_dim)
	_set_key_state(key_lb, joy_lb, c_active, c_dim)
	_set_key_state(key_rb, joy_rb, c_active, c_dim)

func _set_key_state(label: Label, pressed: bool, active_col: Color, dim_col: Color) -> void:
	if not label:
		return
	if pressed:
		label.add_theme_color_override("font_color", active_col)
	else:
		label.add_theme_color_override("font_color", dim_col)
