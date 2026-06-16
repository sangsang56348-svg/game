extends Node2D

@onready var player = $Player
@onready var ui_dialogue = $CanvasLayer/DialoguePanel
@onready var dialogue_label = $CanvasLayer/DialoguePanel/Label
@onready var transition_rect = $CanvasLayer/TransitionRect

@onready var shelter_sprite = $ShelterArea/ShelterSprite
@onready var shelter_prompt = $ShelterArea/InteractPrompt
@onready var storage_prompt = $StorageArea/InteractPrompt

@onready var inventory_label = $CanvasLayer/HUD/InventoryLabel

# 앵무새 미니게임 UI
@onready var qte_panel = $CanvasLayer/QTEPanel
@onready var qte_prompt_label = $CanvasLayer/QTEPanel/PromptLabel
@onready var qte_timer_progress = $CanvasLayer/QTEPanel/TimerProgress

var wood_count = 0
var stone_count = 0
var shelter_progress = 0 # 0 ~ 3 단계
var food_stored = false
var bottle_spawned = false

# 앵무새 시스템 관련 변수
var player_has_fruit = false
var is_parrot_captured = false
var parrot_words_learned = 0 # 0 ~ 3 단계
var is_training_parrot = false
var parrot_speech_timer = 5.0 # 앵무새 혼잣말 쿨다운 타이머

var qte_keys = []
var qte_index = 0
var qte_timer = 0.0
var qte_limit = 4.0

var learned_words_list = ["안녕!", "살려줘!", "배고파!"]
var key_symbols = {
	KEY_UP: "↑",
	KEY_DOWN: "↓",
	KEY_LEFT: "←",
	KEY_RIGHT: "→"
}

# 앵무새 말풍선
@onready var parrot_node = $Parrot
@onready var parrot_speech_bubble = $Parrot/SpeechBubble
@onready var parrot_speech_label = $Parrot/SpeechBubble/Label

var pickup_scene = preload("res://scenes/pickup_item.tscn")

func _ready():
	# 1024x1024 탑다운 숲 카메라 리미트 설정
	var cam = player.get_node("Camera2D")
	cam.limit_right = 1024
	cam.limit_bottom = 1024
	cam.limit_left = 0
	cam.limit_top = 0
	
	# 초기화
	qte_panel.visible = false
	parrot_speech_bubble.visible = false
	ui_dialogue.visible = true
	dialogue_label.text = "울창한 숲속이다! 상/하/좌/우(W,A,S,D 또는 방향키)로 이동하고 [Space] 키로 굴러 회피할 수 있어.\n나뭇가지와 돌을 모아 기지를 지어보자. 앗, 숲에 날아다니는 아름다운 앵무새도 길들여 말을 가르쳐볼까? (과일 필요)"
	update_inventory_ui()
	
	# 페이드 인
	var tween = create_tween()
	tween.tween_property(transition_rect, "color", Color(0, 0, 0, 0), 1.0)
	
	# 맵의 아이템 신호 연결
	for child in $Items.get_children():
		if child.has_signal("item_picked_up"):
			child.item_picked_up.connect(_on_item_picked_up)
			
	# 쉘터와 저장소 초기화
	shelter_sprite.modulate.a = 0.1
	
	# 쉘터와 저장소 Area2D 충돌 연결
	$ShelterArea.area_entered.connect(func(area): shelter_prompt.visible = true)
	$ShelterArea.area_exited.connect(func(area): shelter_prompt.visible = false)
	$StorageArea.area_entered.connect(func(area): storage_prompt.visible = true)
	$StorageArea.area_exited.connect(func(area): storage_prompt.visible = false)
	
	# 앵무새 훈련 신호 연결
	parrot_node.parrot_interacted.connect(start_parrot_training)
	
	# 출구 감지
	$ExitArea.body_entered.connect(_on_exit_area_body_entered)

func _process(delta):
	# 가시 덩굴 데미지 처리
	_process_thorn_damage(delta)
	
	# 앵무새 훈련 QTE 타이머 처리
	if is_training_parrot:
		qte_timer -= delta
		qte_timer_progress.value = (qte_timer / qte_limit) * 100.0
		if qte_timer <= 0.0:
			fail_training()

	# 앵무새 혼잣말 연출
	if is_parrot_captured and parrot_words_learned > 0 and not is_training_parrot and not parrot_speech_bubble.visible:
		parrot_speech_timer -= delta
		if parrot_speech_timer <= 0.0:
			# 배운 단어 중 무작위로 외치기
			var random_word = learned_words_list[randi() % parrot_words_learned]
			show_parrot_bubble(random_word)
			# 다음 말할 때까지 6~12초 간격 무작위 대기
			parrot_speech_timer = randf_range(6.0, 12.0)

func _process_thorn_damage(delta):
	# 가시 덩굴에 닿아 있는 플레이어 감지
	for area in $Thorns.get_children():
		if area.overlaps_body(player):
			# 플레이어가 굴러 회피 중인 상태(collision_layer가 0인 상태)라면 데미지를 받지 않음
			if player.is_rolling:
				continue
			# 지속적인 에너지 감점 (초당 25)
			var is_dead = GameManager.consume_energy(25.0 * delta)
			if is_dead:
				break

func _input(event):
	if is_training_parrot:
		var qte_actions = {
			KEY_UP: "ui_up",
			KEY_DOWN: "ui_down",
			KEY_LEFT: "ui_left",
			KEY_RIGHT: "ui_right"
		}
		for keycode in qte_actions.keys():
			var action_name = qte_actions[keycode]
			if event.is_action_pressed(action_name):
				get_viewport().set_input_as_handled() # 이벤트 차단
				
				if keycode == qte_keys[qte_index]:
					# 올바른 키 입력 성공
					qte_index += 1
					update_qte_display()
					
					if qte_index >= qte_keys.size():
						success_training()
				else:
					# 틀린 키 입력
					fail_training()
				return

func get_player_has_fruit() -> bool:
	return player_has_fruit

func update_inventory_ui():
	var fruit_str = "보유" if player_has_fruit else "없음"
	inventory_label.text = "나뭇가지: %d/3 | 돌멩이: %d/1 | 과일: %s" % [wood_count, stone_count, fruit_str]

func _on_item_picked_up(type):
	match type:
		"wood":
			wood_count += 1
			GameManager.add_defense(10)
			show_message("나뭇가지를 주웠습니다! 방어력 점수 상승 (+10)")
		"stone":
			stone_count += 1
			GameManager.add_defense(10)
			show_message("돌멩이를 주웠습니다! 방어력 점수 상승 (+10)")
		"fruit":
			player_has_fruit = true
			show_message("맛있는 코코넛 과일을 주웠습니다! (앵무새를 꼬실 수 있습니다)")
		"bottle":
			GameManager.has_letter_bottle = true
			transition_to_scene_3()
			
	update_inventory_ui()

func show_message(msg: String, duration: float = 2.0):
	ui_dialogue.visible = true
	dialogue_label.text = msg
	
	var timer = get_tree().create_timer(duration)
	await timer.timeout
	if ui_dialogue.visible and dialogue_label.text == msg:
		ui_dialogue.visible = false

# 앵무새 포획 성공 시 콜백 (parrot.gd에서 호출됨)
func on_parrot_captured():
	is_parrot_captured = true
	player_has_fruit = false # 과일 소모
	update_inventory_ui()
	GameManager.add_defense(30)
	show_message("앵무새 포획 완료! 이제 어깨 위 앵무새를 향해 E키를 눌러 말을 가르쳐보세요! (+30)", 4.0)

# QTE 말 가르치기 게임 시작
func start_parrot_training():
	if parrot_words_learned >= 3:
		show_message("앵무새가 이미 모든 말을 완벽하게 배웠습니다! (삐약삐약!)")
		return
		
	if is_training_parrot:
		return
		
	is_training_parrot = true
	player.set_physics_process(false)
	player.velocity = Vector2.ZERO
	
	# QTE 단어 패턴 정의 (배운 갯수가 많아질수록 콤보 증가: 3 -> 4 -> 5 키)
	var keys_count = 3 + parrot_words_learned
	qte_keys = []
	var directions = [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]
	for i in range(keys_count):
		qte_keys.append(directions[randi() % directions.size()])
		
	qte_index = 0
	qte_timer = qte_limit
	
	qte_panel.visible = true
	update_qte_display()

func update_qte_display():
	var full_text = ""
	for i in range(qte_keys.size()):
		var sym = key_symbols[qte_keys[i]]
		if i < qte_index:
			# 이미 입력 성공한 키는 초록색
			full_text += "[color=#55ff55]" + sym + "[/color] "
		elif i == qte_index:
			# 입력해야 할 키는 흰색 굵게 강조
			full_text += "[b]" + sym + "[/b] "
		else:
			# 대기 중인 키는 회색
			full_text += "[color=#888888]" + sym + "[/color] "
			
	# 풍부한 서식 지원을 위해 RichTextLabel처럼 세팅하거나 기본 텍스트 포맷팅
	qte_prompt_label.text = "순서대로 누르세요:\n" + clean_bbcode(full_text)

func clean_bbcode(bbcode_text: String) -> String:
	# Label 노드 호환을 위해 BBCode 태그를 심플한 문양으로 정리
	return bbcode_text.replace("[color=#55ff55]", "★").replace("[/color]", "").replace("[b]", "▷").replace("[/b]", "").replace("[color=#888888]", "").replace(" ", "  ")

func success_training():
	is_training_parrot = false
	qte_panel.visible = false
	player.set_physics_process(true)
	
	parrot_words_learned += 1
	GameManager.add_defense(30)
	
	# 앵무새 말풍선 외치기 연출
	var word = learned_words_list[parrot_words_learned - 1]
	show_parrot_bubble(word)
	
	show_message("훈련 성공! 앵무새가 '%s' 말을 배웠습니다. 방어력 대폭 상승 (+30)" % word, 3.0)
	check_completion()

func fail_training():
	is_training_parrot = false
	qte_panel.visible = false
	player.set_physics_process(true)
	show_message("훈련 실패... 앵무새가 머리를 갸우뚱거립니다. 다시 E를 눌러 가르쳐주세요.", 2.5)

func show_parrot_bubble(text: String):
	parrot_speech_label.text = text
	parrot_speech_bubble.visible = true
	var timer = get_tree().create_timer(2.0)
	await timer.timeout
	parrot_speech_bubble.visible = false

# 쉘터 짓기 상호작용
func _on_shelter_area_interact(player_node):
	if shelter_progress >= 3:
		show_message("이미 튼튼한 집을 완성했습니다!")
		return
		
	if wood_count >= 1:
		wood_count -= 1
		shelter_progress += 1
		shelter_sprite.modulate.a = 0.3 + (0.23 * shelter_progress)
		if shelter_progress == 3:
			shelter_sprite.modulate.a = 1.0
			GameManager.add_defense(50)
			show_message("집을 완공했습니다! 방어력 대폭 상승 (+50)")
		else:
			GameManager.add_defense(20)
			show_message("집을 짓는 중입니다... (%d/3) 방어력 상승 (+20)" % shelter_progress)
			
		update_inventory_ui()
		check_completion()
	else:
		show_message("집을 지을 나뭇가지가 부족합니다. 주변에서 나뭇가지를 주워 오세요.")

# 음식 땅 파고 저장 상호작용
func _on_storage_area_interact(player_node):
	if food_stored:
		show_message("이미 식량을 보존고에 묻어 저장해두었습니다.")
		return
		
	if stone_count >= 1:
		stone_count -= 1
		food_stored = true
		GameManager.add_defense(50)
		$StorageArea/StorageSprite.modulate = Color(0.6, 0.9, 0.6)
		show_message("돌멩이를 이용해 땅을 파고 식량을 보관했습니다! 방어력 대폭 상승 (+50)")
		update_inventory_ui()
		check_completion()
	else:
		show_message("단단한 돌멩이가 있어야 땅을 파고 식량을 묻을 수 있습니다.")

func check_completion():
	if shelter_progress >= 3 and food_stored and parrot_words_learned >= 3 and not bottle_spawned:
		bottle_spawned = true
		
		# 소년 바로 옆에 유리병 스폰
		var bottle = pickup_scene.instantiate()
		bottle.item_type = "bottle"
		bottle.position = player.position + Vector2(70, 20)
		bottle.z_index = 3
		bottle.item_picked_up.connect(_on_item_picked_up)
		add_child(bottle)
		
		ui_dialogue.visible = true
		dialogue_label.text = "기지도 짓고, 음식 저장도 하고, 앵무새에게 말 가르치기까지 끝냈어! 완벽한 방비야.\n어? 내 바로 옆에 반짝이는 '유리병'이 보인다. 저걸 주워서 메시지를 써보자!"

# ExitArea 진입 시 씬 3 조건부 전환
func _on_exit_area_body_entered(body):
	if body.name == "Player":
		if GameManager.has_letter_bottle:
			transition_to_scene_3()
		else:
			show_message("아직 유리병을 줍지 못해 절벽으로 나갈 수 없습니다! \n쉘터 근처를 조사하여 유리병을 획득하세요.", 3.0)
			body.global_position = player.global_position - Vector2(50, 0) # 경계 밖으로 밀어냄

func transition_to_scene_3():
	player.set_physics_process(false)
	ui_dialogue.visible = true
	dialogue_label.text = "유리병을 주워 구조 편지를 넣었습니다. \n이제 바다가 내려다보이는 높은 절벽으로 가서 병을 바다에 던져야 합니다!"
	
	var tween = create_tween()
	tween.tween_interval(3.0)
	tween.tween_property(transition_rect, "color", Color(0, 0, 0, 1), 1.0)
	await tween.finished
	GameManager.change_scene("res://scenes/scene_3.tscn")
