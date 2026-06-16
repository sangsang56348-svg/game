extends Node2D

@onready var player = $Player
@onready var ui_dialogue = $CanvasLayer/DialoguePanel
@onready var dialogue_label = $CanvasLayer/DialoguePanel/Label
@onready var score_label = $CanvasLayer/HUD/FoodScore
@onready var transition_rect = $CanvasLayer/TransitionRect
@onready var evil_effect_sprite = $EvilEffectSprite

var food_boxes_total = 3
var food_boxes_opened = 0
var input_disabled = true

func _ready():
	# 초기 연출: 플레이어 이동 제한 및 쓰러진 모습
	player.set_physics_process(false)
	player.get_node("Sprite2D").rotation_degrees = -90
	player.get_node("Sprite2D").offset = Vector2(-150, -100) # 누워있는 위치 보정
	
	# 카메라 스크롤 한계 설정
	player.get_node("Camera2D").limit_right = 2000
	
	# 대화창 및 화면 연출

	ui_dialogue.visible = true
	dialogue_label.text = "으으윽... 머리가 아프다... 여긴 어디지? (화면을 클릭하거나 Space키를 누르면 일어납니다)"
	score_label.text = "음식 찾기: 0 / " + str(food_boxes_total)
	transition_rect.color = Color(0, 0, 0, 1) # 검은색 시작
	
	# 페이드 인
	var tween = create_tween()
	tween.tween_property(transition_rect, "color", Color(0, 0, 0, 0), 1.5)
	
	# 상자 시그널 연결
	for child in $Boxes.get_children():
		if child.has_signal("box_opened"):
			child.box_opened.connect(_on_box_opened)
			
	evil_effect_sprite.visible = false
	evil_effect_sprite.scale = Vector2(0.1, 0.1)

func _input(event):
	if input_disabled:
		if event.is_action_pressed("ui_accept") or (event is InputEventMouseButton and event.pressed):
			wake_up_player()

func wake_up_player():
	input_disabled = false
	dialogue_label.text = "관광선이 난파된 모양이다... 나 혼자 살아남은 건가? \n해변에 흩어진 나무 상자에서 음식을 찾아야겠어. 하지만 불길한 오라가 흐르는 상자는 절대 열면 안 돼!"
	
	var tween = create_tween().set_parallel(true)
	# 소년이 서서히 일어남
	tween.tween_property(player.get_node("Sprite2D"), "rotation_degrees", 0.0, 1.0)
	tween.tween_property(player.get_node("Sprite2D"), "offset", Vector2(0, -350), 1.0)
	
	await tween.finished
	player.set_physics_process(true)
	
	# 대화창 3초 후 닫기
	await get_tree().create_timer(4.0).timeout
	if not input_disabled: # 중간에 리셋되지 않은 경우
		ui_dialogue.visible = false

func _on_box_opened(box_node):
	if box_node.is_evil:
		trigger_evil_reset(box_node.global_position)
	else:
		collect_food(box_node)

func collect_food(box_node):
	food_boxes_opened += 1
	score_label.text = "음식 찾기: " + str(food_boxes_opened) + " / " + str(food_boxes_total)
	GameManager.play_sfx("pickup")
	
	# 상자 삭제 및 획득 사운드 대신 연출
	box_node.queue_free()
	
	ui_dialogue.visible = true
	dialogue_label.text = "음식 상자를 열어 식량을 획득했습니다! (에너지 보충)"
	GameManager.add_energy(25.0) # 음식 줍기 보너스 에너지
	
	if food_boxes_opened >= food_boxes_total:
		# 모든 음식을 수집함 -> 씬 2로
		dialogue_label.text = "좋아, 당분간 먹을 음식은 구했다. \n슬슬 밤이 되면 추워질 테니 숲으로 들어가 집을 짓고 기지를 만들어야겠어!"
		player.set_physics_process(false)
		
		var tween = create_tween()
		tween.tween_interval(3.0)
		tween.tween_property(transition_rect, "color", Color(0, 0, 0, 1), 1.5)
		await tween.finished
		GameManager.change_scene("res://scenes/scene_2.tscn")
	else:
		await get_tree().create_timer(1.8).timeout
		if ui_dialogue.visible and dialogue_label.text.begins_with("음식 상자"):
			ui_dialogue.visible = false

func trigger_evil_reset(spawn_pos):
	player.set_physics_process(false)
	input_disabled = true
	
	# 악령 이펙트 띄우기
	evil_effect_sprite.global_position = spawn_pos + Vector2(0, -50)
	evil_effect_sprite.visible = true
	evil_effect_sprite.modulate = Color(1, 1, 1, 0)
	
	# 대화창 텍스트 변경
	ui_dialogue.visible = true
	dialogue_label.text = "크아아악! 상자에서 검은 연기와 함께 강력한 악령이 튀어나왔습니다! 눈앞이 어두워집니다..."
	
	var tween = create_tween()
	# 악령이 커지며 나타남
	tween.parallel().tween_property(evil_effect_sprite, "scale", Vector2(0.5, 0.5), 1.5)
	tween.parallel().tween_property(evil_effect_sprite, "modulate", Color(1, 1, 1, 1), 1.0)
	# 화면 암전
	tween.tween_property(transition_rect, "color", Color(0, 0, 0, 1), 1.0)
	
	await tween.finished
	evil_effect_sprite.visible = false
	
	# 게임 리셋
	GameManager.reset_to_scene_1("악령 상자를 열었습니다.")
