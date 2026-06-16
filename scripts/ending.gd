extends Node2D

@onready var result_label = $CanvasLayer/ResultLabel
@onready var transition_rect = $CanvasLayer/TransitionRect

func _ready():
	# 최종 점수 표시
	result_label.text = "최종 생존 방어력 점수: " + str(GameManager.defense_score) + " 점\n\n소년의 무인도 생존과 구조에 성공하셨습니다! \n플레이해주셔서 감사합니다."
	
	# 페이드 인
	var tween = create_tween()
	tween.tween_property(transition_rect, "color", Color(1, 1, 1, 0), 2.0)

func _on_restart_button_pressed():
	# 페이드 아웃 후 씬 1으로 재시작
	var tween = create_tween()
	tween.tween_property(transition_rect, "color", Color(0, 0, 0, 1), 1.0)
	await tween.finished
	GameManager.reset_to_scene_1("게임 재시작")
