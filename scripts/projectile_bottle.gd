extends Sprite2D

var velocity = Vector2.ZERO
var gravity = 500.0
var active = false
var wind_effect = 0.0

signal splash_down(success, landing_pos)

func _ready():
	visible = false
	scale = Vector2(0.08, 0.08)

func launch(start_pos: Vector2, power: float, angle_deg: float, wind: float):
	global_position = start_pos
	wind_effect = wind
	
	# 발사 속도 계산
	var angle_rad = deg_to_rad(angle_deg)
	var speed = 150.0 + (power * 6.0) # 힘에 비례
	
	velocity = Vector2(cos(angle_rad) * speed, sin(angle_rad) * speed)
	active = true
	visible = true

func _physics_process(delta):
	if not active:
		return
	
	# 중력 및 바람 저항/영향 적용
	velocity.y += gravity * delta
	velocity.x += wind_effect * delta * 5.0
	
	global_position += velocity * delta
	
	# 수면(Y=520 근처)이나 바닥에 닿으면 판정
	if global_position.y >= 520:
		active = false
		
		# 성공 조건: X 좌표가 1100 이상으로 멀리 날아간 경우 (성공적으로 수평선을 넘음)
		var is_success = global_position.x >= 1050
		splash_down.emit(is_success, global_position)
