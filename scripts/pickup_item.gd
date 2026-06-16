extends Area2D

@export_enum("wood", "stone", "fruit", "fish", "bottle") var item_type: String = "wood"

@onready var sprite = $Sprite2D
@onready var label = $InteractPrompt

signal item_picked_up(type)

func _ready():
	collision_layer = 4
	collision_mask = 1
	add_to_group("interactable")
	
	label.visible = false
	
	# 시그널 연결
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)
	
	# 아이템에 따른 라벨 및 텍스처 변경
	match item_type:
		"wood":
			label.text = "[E] 나뭇가지 줍기"
			setup_atlas(Rect2(30, 370, 230, 250), Vector2(0.3, 0.3))
		"stone":
			label.text = "[E] 돌멩이 줍기"
			setup_atlas(Rect2(280, 420, 180, 150), Vector2(0.3, 0.3))
		"fruit":
			label.text = "[E] 과일 먹기"
			setup_atlas(Rect2(510, 360, 170, 260), Vector2(0.3, 0.3))
		"fish":
			label.text = "[E] 물고기 먹기"
			setup_atlas(Rect2(720, 410, 250, 160), Vector2(0.3, 0.3))
		"bottle":
			label.text = "[E] 유리병 줍기"
			sprite.texture = load("res://assets/bottle.png")
			sprite.scale = Vector2(0.08, 0.08)

func setup_atlas(region: Rect2, custom_scale: Vector2):
	var atlas = AtlasTexture.new()
	atlas.atlas = load("res://assets/survival_items.png")
	atlas.region = region
	sprite.texture = atlas
	sprite.scale = custom_scale


func interact(player):
	GameManager.play_sfx("pickup")
	item_picked_up.emit(item_type)
	queue_free()

func _on_area_entered(area):
	label.visible = true

func _on_area_exited(area):
	label.visible = false
