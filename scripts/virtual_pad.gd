extends CanvasLayer

func _ready():
	# 모바일 환경, 모바일 웹(Android/iOS), 터치 사용 가능 기기, 또는 디버그 빌드인 경우 터치 패드를 활성화합니다.
	if OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios") or DisplayServer.is_touchscreen_available() or OS.is_debug_build():
		visible = true
	else:
		visible = false
