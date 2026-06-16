extends CharacterBody2D

const SPEED = 300.0
const JUMP_VELOCITY = -400.0
const ROLL_SPEED = 500.0

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity", 980)

@export var is_topdown: bool = false

# 구르기 상태 변수
var is_rolling = false
var roll_timer = 0.0
var roll_duration = 0.3
var roll_direction = Vector2.ZERO

@onready var sprite = $Sprite2D
@onready var interact_area = $InteractArea
var overlapping_interactables = []

func _ready():
	# 충돌 레이어 설정 (플레이어는 1번 레이어)
	collision_layer = 1
	collision_mask = 2 # 장애물이나 바닥 등은 2번 레이어
	
	# 그룹 등록
	add_to_group("player")
	
	# 상호작용 영역 시그널 연결

	interact_area.area_entered.connect(_on_interact_area_area_entered)
	interact_area.area_exited.connect(_on_interact_area_area_exited)
	
	# 현재 활성화된 씬 이름을 감지하여 탑다운 모드 자동 스위칭
	if get_tree().current_scene:
		var scene_name = get_tree().current_scene.name
		if "Scene2" in scene_name:
			is_topdown = true

func _physics_process(delta):
	if is_topdown:
		_physics_process_topdown(delta)
	else:
		_physics_process_platformer(delta)

func _physics_process_platformer(delta):
	# 기존 횡스크롤 물리 (중력 적용)
	if not is_on_floor():
		velocity.y += gravity * delta

	var direction = Input.get_axis("ui_left", "ui_right")
	if direction:
		velocity.x = direction * SPEED
		sprite.flip_h = direction < 0
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()

func _physics_process_topdown(delta):
	if is_rolling:
		roll_timer -= delta
		velocity = roll_direction * ROLL_SPEED
		
		# 데굴데굴 구르는 360도 휠 스핀 연출
		sprite.rotation_degrees += 1080.0 * delta * (-1 if sprite.flip_h else 1)
		
		if roll_timer <= 0.0:
			is_rolling = false
			sprite.rotation_degrees = 0.0
			collision_layer = 1 # 무적 해제 (플레이어 레이어 복구)
			
		move_and_slide()
		return

	# 8방향 걷기 입력 감지
	var input_dir = Vector2.ZERO
	input_dir.x = Input.get_axis("ui_left", "ui_right")
	input_dir.y = Input.get_axis("ui_up", "ui_down")
	input_dir = input_dir.normalized()

	if input_dir != Vector2.ZERO:
		velocity = input_dir * SPEED
		sprite.flip_h = input_dir.x < 0
	else:
		velocity = velocity.move_toward(Vector2.ZERO, SPEED)

	# Space 키로 구르기 발사
	if Input.is_action_just_pressed("ui_select"):
		start_roll(input_dir)
		return

	move_and_slide()

func start_roll(dir: Vector2):
	if is_rolling:
		return
	is_rolling = true
	roll_timer = roll_duration
	
	# 입력 방향이 없는 경우 소년이 보는 방향으로 구름
	if dir == Vector2.ZERO:
		roll_direction = Vector2(-1 if sprite.flip_h else 1, 0)
	else:
		roll_direction = dir
		
	# 구르는 동안 장애물(가시 등)과의 접촉 판정을 피하기 위해 임시로 무적 레이어로 설정
	collision_layer = 0

func get_target_interactable():
	# 유효하지 않은 노드 정리
	var valid_interactables = []
	for area in overlapping_interactables:
		if is_instance_valid(area) and area.is_inside_tree():
			valid_interactables.append(area)
	overlapping_interactables = valid_interactables

	if overlapping_interactables.is_empty():
		return null

	# 다른 상호작용 가능한 물체(집터, 저장소 등)를 앵무새보다 우선시하여 빌드/수집을 편하게 함
	for area in overlapping_interactables:
		if area.name != "Parrot":
			return area

	# 남은 게 앵무새뿐이면 앵무새 리턴
	return overlapping_interactables[0]

func _input(event):
	# E키 또는 Enter, 그리고 가상패드의 interact 액션(E버튼) 감지
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		var target = get_target_interactable()
		if target and target.has_method("interact"):
			target.interact(self)

func _on_interact_area_area_entered(area):
	if area.is_in_group("interactable"):
		if not overlapping_interactables.has(area):
			overlapping_interactables.append(area)

func _on_interact_area_area_exited(area):
	if overlapping_interactables.has(area):
		overlapping_interactables.erase(area)
