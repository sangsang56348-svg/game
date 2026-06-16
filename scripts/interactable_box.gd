extends Area2D

# 상자 타입 정의
@export var is_evil: bool = false
var is_opened: bool = false

# UI 및 씬을 위한 시그널
signal box_opened(box_node)

@onready var sprite = $Sprite2D
@onready var label = $InteractPrompt

func _ready():
	collision_layer = 4 # 상호작용 레이어
	collision_mask = 1  # 플레이어의 InteractArea는 collision_layer 0, mask 4이지만 Area2D의 감지를 위해 mask/layer 짝을 맞춰줍니다.
	add_to_group("interactable")
	
	# 상자 크기 조정
	sprite.scale = Vector2(0.12, 0.12)
	label.visible = false
	
	# 시그널 연결
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)
	
	# 악령 상자는 검붉은 오라를 덧씌워서 힌트를 줌
	if is_evil:
		sprite.modulate = Color(0.9, 0.75, 1.0, 1.0)


func interact(player):
	if is_opened:
		return
	
	is_opened = true
	label.visible = false
	box_opened.emit(self)

func _on_area_entered(area):
	if not is_opened:
		label.visible = true

func _on_area_exited(area):
	label.visible = false
