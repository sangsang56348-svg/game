extends Control

@onready var energy_bar = $MarginContainer/VBoxContainer/EnergyHBox/EnergyBar
@onready var energy_text = $MarginContainer/VBoxContainer/EnergyHBox/EnergyText
@onready var defense_text = $MarginContainer/VBoxContainer/DefenseHBox/DefenseText

func _ready():
	# 초기화 및 시그널 연결
	update_energy(GameManager.energy)
	update_defense(GameManager.defense_score)
	
	GameManager.energy_changed.connect(update_energy)
	GameManager.defense_changed.connect(update_defense)

func update_energy(new_energy: float):
	energy_bar.value = new_energy
	energy_text.text = str(round(new_energy)) + " / 100"
	
	# 에너지 수준에 따른 색상 변경 (기본 녹색 -> 고갈 위기 시 적색)
	if new_energy > 50:
		energy_bar.modulate = Color(0.2, 0.9, 0.2) # 초록색
	elif new_energy > 20:
		energy_bar.modulate = Color(0.9, 0.6, 0.1) # 주황색
	else:
		energy_bar.modulate = Color(0.9, 0.2, 0.2) # 빨간색

func update_defense(new_defense: int):
	defense_text.text = "방어력 점수: " + str(new_defense)
