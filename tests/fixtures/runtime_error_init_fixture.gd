## 별도 프로세스에서 의도적인 hook 런타임 오류의 진입 차단을 확인한다.
extends RefCounted

func before_app_initialize() -> Dictionary:
	var target: Variant = null
	# 반환식에 오류를 주입하여 Release의 미사용 연산 제거를 피한다.
	return target.deliberate_init_failure()
