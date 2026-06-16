extends CanvasLayer

func _ready():
	# 모바일 환경(Android, iOS)이거나 개발용 디버그 빌드일 때만 터치 패드를 활성화합니다.
	# (PC에서도 마우스 클릭으로 터치 패드 테스트를 할 수 있도록 디버그 모드에서는 항상 표시합니다.)
	if OS.has_feature("mobile") or OS.is_debug_build():
		visible = true
	else:
		visible = false
