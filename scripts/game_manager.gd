extends Node

# 플레이어 능력치 및 게임 상태 전역 관리
var energy: float = 100.0
var max_energy: float = 100.0
var defense_score: int = 0
var has_letter_bottle: bool = false

# UI 및 씬 제어를 위한 신호
signal energy_changed(new_energy)
signal defense_changed(new_defense)
signal game_reset

var bgm_player: AudioStreamPlayer = null

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# 글로벌 BGM 재생기 설정
	bgm_player = AudioStreamPlayer.new()
	bgm_player.stream = load("res://assets/bgm_forest.ogg")
	bgm_player.volume_db = -10.0 # 대화 상자와 어울리도록 볼륨 조절 (-10dB)
	bgm_player.process_mode = Node.PROCESS_MODE_ALWAYS # 씬 전환 시에도 안 끊기게 설정
	add_child(bgm_player)
	bgm_player.play()

func add_energy(amount: float):
	energy = min(energy + amount, max_energy)
	energy_changed.emit(energy)

func consume_energy(amount: float) -> bool:
	energy = max(energy - amount, 0.0)
	energy_changed.emit(energy)
	if energy <= 0.0:
		reset_to_scene_1("에너지가 모두 고갈되어 쓰러졌습니다...")
		return true
	return false

func add_defense(amount: int):
	defense_score += amount
	defense_changed.emit(defense_score)

# 씬 1의 처음으로 리셋
func reset_to_scene_1(reason: String = ""):
	energy = 100.0
	defense_score = 0
	has_letter_bottle = false
	energy_changed.emit(energy)
	defense_changed.emit(defense_score)
	
	print("Game Reset: ", reason)
	game_reset.emit()
	
	# 씬 1으로 전환
	get_tree().change_scene_to_file("res://scenes/scene_1.tscn")

func change_scene(scene_path: String):
	get_tree().change_scene_to_file(scene_path)

func play_sfx(sfx_name: String):
	var sfx_player = AudioStreamPlayer.new()
	sfx_player.volume_db = -5.0 # 효과음 크기 조절
	add_child(sfx_player)
	
	match sfx_name:
		"pickup":
			sfx_player.stream = load("res://assets/sfx_pickup.wav")
		"throw":
			sfx_player.stream = load("res://assets/sfx_throw.wav")
		"splash":
			sfx_player.stream = load("res://assets/sfx_splash.wav")
			
	sfx_player.play()
	sfx_player.finished.connect(func(): sfx_player.queue_free())
