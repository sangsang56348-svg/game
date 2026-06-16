extends Node2D

@onready var player = $Player
@onready var bottle_projectile = $BottleProjectile
@onready var throw_prompt = $ThrowArea/InteractPrompt
@onready var ui_dialogue = $CanvasLayer/DialoguePanel
@onready var dialogue_label = $CanvasLayer/DialoguePanel/Label
@onready var transition_rect = $CanvasLayer/TransitionRect

# 미니게임 UI
@onready var minigame_ui = $CanvasLayer/MinigameUI
@onready var gauge_bar = $CanvasLayer/MinigameUI/GaugeContainer/ProgressBar
@onready var wind_label = $CanvasLayer/MinigameUI/WindLabel

# 파밍 구역
@onready var spawn_timer = $SpawnTimer

var is_in_throw_area = false
var is_playing_minigame = false
var gauge_direction = 1
var gauge_speed = 250.0
var current_power = 0.0
var current_wind = 0.0

var fruit_prefab = preload("res://scenes/pickup_item.tscn")
var minigame_start_time = 0.0

# 스폰 위치
var fruit_pos = Vector2(100, 560)
var fish_pos = Vector2(300, 560)
var has_fruit = true
var has_fish = true

var is_near_ladder = false
var is_at_ladder_bottom = false

func _ready():
	# 씬 3 카메라 고정 혹은 리미트 설정
	player.get_node("Camera2D").limit_right = 1152 # 1화면 크기로 고정하여 멀리 날아가는 병 연출 극대화
	
	# 손에 든 유리병 연출 활성화
	player.get_node("Sprite2D/HeldBottle").visible = true
	
	# 초기화
	minigame_ui.visible = false
	throw_prompt.visible = false
	bottle_projectile.splash_down.connect(_on_bottle_splash_down)
	
	# 상호작용 영역 연결
	$ThrowArea.area_entered.connect(func(area): is_in_throw_area = true; throw_prompt.visible = true)
	$ThrowArea.area_exited.connect(func(area): is_in_throw_area = false; throw_prompt.visible = false)
	
	# 사다리 영역 충돌 연결
	$LadderTopArea.body_entered.connect(func(body): if body.name == "Player": is_near_ladder = true)
	$LadderTopArea.body_exited.connect(func(body): if body.name == "Player": is_near_ladder = false)
	$LadderBottomArea.body_entered.connect(func(body): if body.name == "Player": is_at_ladder_bottom = true)
	$LadderBottomArea.body_exited.connect(func(body): if body.name == "Player": is_at_ladder_bottom = false)
	
	# 스폰 타이머 연결
	spawn_timer.timeout.connect(respawn_items)
	
	# 페이드 인
	var tween = create_tween()
	tween.tween_property(transition_rect, "color", Color(0, 0, 0, 0), 1.0)
	
	# 초기 식량 스폰
	spawn_item("fruit", fruit_pos)
	spawn_item("fish", fish_pos)
	
	ui_dialogue.visible = true
	dialogue_label.text = "높은 절벽에 도착했다. 바람이 알맞을 때 유리병을 강하게 던져 수평선 너머 육지에 보내야 한다! \n체력이 바닥나면 절벽 밑(사다리 아래)에서 과일이나 고기를 얻어 체력을 보충하자. \n(화면을 마우스로 클릭하거나 Space/E 키를 누르면 설명창이 닫힙니다.)"

func _process(delta):
	if is_playing_minigame:
		# 게이지 채우기 루프 (0 ~ 100 왕복)
		current_power += gauge_direction * gauge_speed * delta
		if current_power >= 100.0:
			current_power = 100.0
			gauge_direction = -1
		elif current_power <= 0.0:
			current_power = 0.0
			gauge_direction = 1
		
		gauge_bar.value = current_power

func _input(event):
	# 설명창 닫기 처리 (키보드 또는 마우스 클릭)
	if ui_dialogue.visible:
		if (event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_select") or event.is_action_pressed("interact")) or (event is InputEventMouseButton and event.pressed):
			ui_dialogue.visible = false
			get_viewport().set_input_as_handled() # 이벤트 전파 차단
			return
			
	# 사다리 오르내리기 처리 (위/아래 방향키 및 가상패드 감지)
	if event.is_action_pressed("ui_down") and is_near_ladder:
		player.global_position = Vector2(200, 520) # 아래 안전지대
		show_hud_message_simple("밧줄 사다리를 타고 절벽 아래로 내려왔습니다.")
		get_viewport().set_input_as_handled()
		return
	elif event.is_action_pressed("ui_up") and is_at_ladder_bottom:
		player.global_position = Vector2(300, 270) # 위 안전지대
		show_hud_message_simple("밧줄 사다리를 타고 절벽 위로 올라왔습니다.")
		get_viewport().set_input_as_handled()
		return

	# 미니게임 작동 중의 발사/취소 분리 처리 (E키 충돌 방지 및 모바일 가상버튼 대응)
	if is_playing_minigame:
		if event.is_action_pressed("ui_cancel") or (event.is_action_pressed("interact") and Time.get_ticks_msec() - minigame_start_time > 200):
			# ESC 키, ui_cancel, 혹은 충분한 시간(200ms)이 지난 후 E키로 미니게임 취소
			is_playing_minigame = false
			minigame_ui.visible = false
			player.set_physics_process(true)
			show_hud_message_simple("유리병 던지기를 취소했습니다.")
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("ui_select") or event.is_action_pressed("ui_accept"):
			# Space/Enter 혹은 가상 버튼으로 발사
			launch_bottle()
			get_viewport().set_input_as_handled()



func show_hud_message_simple(msg: String):
	ui_dialogue.visible = true
	dialogue_label.text = msg
	await get_tree().create_timer(1.5).timeout
	if ui_dialogue.visible and dialogue_label.text == msg:
		ui_dialogue.visible = false

func _on_throw_area_interact(player_node):
	if not is_playing_minigame and not ui_dialogue.visible:
		start_minigame()

func start_minigame():
	is_playing_minigame = true
	player.set_physics_process(false)
	minigame_start_time = Time.get_ticks_msec()
	
	# 바람 세기 새로 정의
	current_wind = randf_range(-40.0, 60.0)
	var wind_dir_text = "역풍" if current_wind < 0 else "순풍"
	var wind_status = "풍향: %s | 풍속: %d km/h" % [wind_dir_text, abs(round(current_wind))]
	
	if current_wind > 20:
		wind_label.modulate = Color(0.2, 0.9, 0.2) # 초록색 (성공 추천)
		wind_label.text = wind_status + "\n[ ★ 던지기 아주 좋은 타이밍! ★ ]"
	else:
		wind_label.modulate = Color(0.9, 0.4, 0.4) # 적색/황색
		wind_label.text = wind_status + "\n[ ⚠️ 역풍/약풍 상태! 취소(ESC) 후 재시도 권장 ]"
		
	minigame_ui.visible = true

	current_power = 0.0
	gauge_direction = 1

func launch_bottle():
	is_playing_minigame = false
	minigame_ui.visible = false
	GameManager.play_sfx("throw")
	
	# 손에 쥐었던 병 숨기기 (발사 연출)
	player.get_node("Sprite2D/HeldBottle").visible = false
	
	# 플레이어 위치에서 약간 오른쪽 위에서 발사
	var start_pos = player.global_position + Vector2(30, -50)
	bottle_projectile.launch(start_pos, current_power, -45.0, current_wind)
	
	ui_dialogue.visible = true
	dialogue_label.text = "유리병을 바다를 향해 힘껏 던졌습니다! 날아가는 궤적을 확인하세요..."

func _on_bottle_splash_down(success, landing_pos):
	GameManager.play_sfx("splash")
	if success:
		trigger_ending()
	else:
		# 물속으로 가라앉는 이펙트 연출
		var tween = create_tween()
		tween.tween_property(bottle_projectile, "modulate:a", 0.0, 1.5)
		
		ui_dialogue.visible = true
		dialogue_label.text = "실패! 병이 강한 파도와 역풍을 이기지 못하고 바다에 가라앉았습니다... \n투척에 많은 에너지를 소모하여 지칩니다. (체력 -25, Space/E 키를 눌러 닫기)"
		
		# 에너지 소모
		var is_dead = GameManager.consume_energy(25.0)
		
		await tween.finished
		bottle_projectile.visible = false
		bottle_projectile.modulate.a = 1.0 # 리셋
		
		if not is_dead:
			# 실패 후 다시 소년 손에 유리병 쥐여주기
			player.get_node("Sprite2D/HeldBottle").visible = true
			player.set_physics_process(true)


func trigger_ending():
	ui_dialogue.visible = true
	dialogue_label.text = "대성공!! 던진 유리병이 거센 바람을 타고 수평선 끝 육지에 도달했습니다!\n메시지를 확인한 구조대가 소년을 찾기 위해 출발했습니다."
	
	var tween = create_tween()
	# 화면을 천천히 밝게 페이드아웃
	tween.tween_interval(3.5)
	tween.tween_property(transition_rect, "color", Color(1, 1, 1, 1), 2.0)
	await tween.finished
	
	GameManager.change_scene("res://scenes/ending.tscn")

# 파밍 시스템
func spawn_item(type: String, pos: Vector2):
	var item = fruit_prefab.instantiate()
	item.item_type = type
	item.position = pos
	item.item_picked_up.connect(func(picked_type):
		if picked_type == "fruit": has_fruit = false
		if picked_type == "fish": has_fish = false
		
		# 아이템이 주워지면 쿨다운 타이머 시작
		if spawn_timer.is_stopped():
			spawn_timer.start(15.0)
		
		# UI 메세지 띄우기
		show_hud_message(picked_type)
	)
	$Items.add_child(item)

func show_hud_message(type: String):
	ui_dialogue.visible = true
	if type == "fruit":
		dialogue_label.text = "신선한 무인도 과일을 먹었습니다! 체력이 완전히 보충됩니다 (+100)"
	else:
		dialogue_label.text = "바다에서 잡은 물고기를 구워 먹었습니다! 체력이 완전히 보충됩니다 (+100)"
	GameManager.add_energy(100.0)
	await get_tree().create_timer(2.0).timeout
	if ui_dialogue.visible and dialogue_label.text.contains("먹었습니다"):
		ui_dialogue.visible = false

func respawn_items():
	if not has_fruit:
		has_fruit = true
		spawn_item("fruit", fruit_pos)
	if not has_fish:
		has_fish = true
		spawn_item("fish", fish_pos)
