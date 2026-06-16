extends Area2D

# 앵무새 상태 정의
enum State { WANDERING, SITTING, APPROACHING, TAMED }
var current_state = State.WANDERING

var speed = 120.0
var wander_timer = 0.0
var wander_dir = Vector2.ZERO
var velocity = Vector2.ZERO

var target_player = null
var follow_offset = Vector2(-25, -95) # 소년의 어깨/머리 부근
var tame_distance = 80.0
var attract_distance = 250.0

@onready var sprite = $Sprite2D
@onready var label = $InteractPrompt

signal parrot_interacted

func _ready():
	collision_layer = 4 # 상호작용 레이어
	collision_mask = 1  # 플레이어 감지용 마스크
	add_to_group("interactable")
	
	label.visible = false
	choose_new_wander_dir()
	
	# 시그널 동적 연결
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)
	
	# 앉아있는 앵무새(왼쪽) Atlas
	setup_atlas(Rect2(50, 150, 400, 700), Vector2(0.08, 0.08))

func _physics_process(delta):
	match current_state:
		State.WANDERING:
			_process_wandering(delta)
		State.SITTING:
			_process_sitting(delta)
		State.APPROACHING:
			_process_approaching(delta)
		State.TAMED:
			_process_tamed(delta)

func _process_wandering(delta):
	wander_timer -= delta
	velocity = wander_dir * speed
	global_position += velocity * delta
	
	# 맵의 범위 내에서만 움직이도록 클램핑 (1024x1024 맵 기준)
	global_position.x = clamp(global_position.x, 50, 970)
	global_position.y = clamp(global_position.y, 50, 970)
	
	# 비행 애니메이션 연출 (날아가는 모습 Atlas)
	setup_atlas(Rect2(460, 150, 500, 700), Vector2(0.08, 0.08))
	sprite.flip_h = wander_dir.x < 0
	
	if wander_timer <= 0.0:
		if randf() < 0.4:
			current_state = State.SITTING
			wander_timer = randf_range(1.5, 3.0)
		else:
			choose_new_wander_dir()
			
	check_player_proximity()

func _process_sitting(delta):
	wander_timer -= delta
	
	# 앉아있는 앵무새 연출
	setup_atlas(Rect2(50, 150, 400, 700), Vector2(0.08, 0.08))
	
	if wander_timer <= 0.0:
		choose_new_wander_dir()
		current_state = State.WANDERING
		
	check_player_proximity()

func _process_approaching(delta):
	if not is_instance_valid(target_player):
		current_state = State.WANDERING
		return
		
	# 플레이어가 과일을 가지고 있어야만 다가옴
	var scene_manager = get_tree().current_scene
	if scene_manager.has_method("get_player_has_fruit") and not scene_manager.get_player_has_fruit():
		current_state = State.WANDERING
		return
		
	var dir = (target_player.global_position - global_position).normalized()
	velocity = dir * speed
	sprite.flip_h = dir.x < 0
	setup_atlas(Rect2(460, 150, 500, 700), Vector2(0.08, 0.08))
	
	global_position += velocity * delta
	
	# 플레이어와 아주 가까워지면 상호작용 프롬프트 노출
	var dist = global_position.distance_to(target_player.global_position)
	if dist <= tame_distance:
		label.visible = true
	else:
		label.visible = false
		
	if dist > attract_distance:
		current_state = State.WANDERING

func _process_tamed(delta):
	label.visible = false
	# 플레이어 어깨 부근을 스무스하게 따라다님
	var target_pos = target_player.global_position + follow_offset
	global_position = global_position.lerp(target_pos, 0.15)
	
	# 플레이어의 방향에 맞춰서 반전
	sprite.flip_h = target_player.get_node("Sprite2D").flip_h
	
	# 소년 어깨에 앉아있는 연출
	setup_atlas(Rect2(50, 150, 400, 700), Vector2(0.06, 0.06))

func choose_new_wander_dir():
	wander_dir = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
	wander_timer = randf_range(2.0, 4.0)

func check_player_proximity():
	if current_state == State.TAMED:
		return
		
	# 플레이어 노드 탐색
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var p = players[0]
		var dist = global_position.distance_to(p.global_position)
		
		# 플레이어가 과일(바나나)을 가지고 있으면 유인됨
		var scene_manager = get_tree().current_scene
		if dist < attract_distance and scene_manager.has_method("get_player_has_fruit") and scene_manager.get_player_has_fruit():
			target_player = p
			current_state = State.APPROACHING

func setup_atlas(region: Rect2, custom_scale: Vector2):
	var atlas = AtlasTexture.new()
	atlas.atlas = load("res://assets/parrot.png")
	atlas.region = region
	sprite.texture = atlas
	sprite.scale = custom_scale

func interact(player):
	if current_state == State.APPROACHING or current_state == State.WANDERING or current_state == State.SITTING:
		# 포획 액션
		target_player = player
		current_state = State.TAMED
		label.visible = false
		var scene_manager = get_tree().current_scene
		if scene_manager.has_method("on_parrot_captured"):
			scene_manager.on_parrot_captured()
	elif current_state == State.TAMED:
		# 포획 완료된 상태에서 상호작용하면 말 가르치기(QTE) 미니게임 시작
		parrot_interacted.emit()

func _on_area_entered(area):
	if current_state != State.TAMED:
		var scene_manager = get_tree().current_scene
		if scene_manager.has_method("get_player_has_fruit") and scene_manager.get_player_has_fruit():
			label.text = "[E] 앵무새 포획하기"
		else:
			label.text = "앵무새가 경계합니다 (과일이 필요함)"
		label.visible = true

func _on_area_exited(area):
	label.visible = false
