#!/usr/bin/env bash
# 공통 회귀 검사: import, 통합 검사 3종(기본·disabled·native), 초기화 실패 차단 2종.
# 사용법: tools/validate.sh            (PATH의 godot 사용)
#         GODOT=/path/to/Godot tools/validate.sh
# 로그는 build/validation_logs/에 남는다. Godot은 스크립트 오류 뒤에도 exit 0일 수 있어 로그도 검사한다.
set -u
cd "$(dirname "$0")/.."

GODOT="${GODOT:-godot}"
LOG_DIR="${LOG_DIR:-build/validation_logs}"
EXPECTED_VERSION="$(tr -d '[:space:]' < .godot-version)"
ERROR_PATTERN='SCRIPT ERROR|Parse Error|ERROR:|leaked|still in use'
failures=0
mkdir -p "$LOG_DIR"

version="$("$GODOT" --version 2>/dev/null | head -n 1)"
case "$version" in
	"$EXPECTED_VERSION".stable*) echo "Godot $version" ;;
	*) echo "FAIL: Godot $EXPECTED_VERSION is required (found: ${version:-none}). Set GODOT=/path/to/Godot."; exit 1 ;;
esac

# check <이름> <로그에 있어야 할 문구> <허용할 오류 패턴> <Godot 인수...>
check() {
	local name="$1" expected="$2" allowed="$3"
	shift 3
	local log="$LOG_DIR/$name.log"
	"$GODOT" --headless --path . "$@" > "$log" 2>&1
	local code=$?
	local problems=""
	[ "$code" -eq 0 ] || problems="$problems exit-code-$code;"
	if [ -n "$expected" ] && ! grep -qF -- "$expected" "$log"; then
		problems="$problems missing '$expected';"
	fi
	local unexpected
	unexpected="$(grep -E "$ERROR_PATTERN" "$log" | grep -vE "${allowed:-^$}")"
	[ -z "$unexpected" ] || problems="$problems unexpected errors;"
	if [ -z "$problems" ]; then
		echo "PASS $name $(grep -oE 'INTEGRATION: .*|BOOTSTRAP_FAILURE: .*' "$log" | head -n 1)"
	else
		failures=$((failures + 1))
		echo "FAIL $name:$problems (log: $log)"
		[ -z "$unexpected" ] || echo "$unexpected" | head -n 20
	fi
}

check import "" "" --editor --import --quit
check integration "checks, 0 failures" "" --scene res://tests/integration.tscn
check integration-disabled "checks, 0 failures" "" --scene res://tests/integration.tscn -- --disabled
check integration-native "checks, 0 failures" "" --scene res://tests/integration.tscn -- --native
# 실패 주입 검사는 의도한 init 실패 로그만 허용한다.
check bootstrap-failure "entry_blocked=true message_shown=true" "Game init script failed" \
	--scene res://tests/bootstrap_failure.tscn
check bootstrap-runtime-error "entry_blocked=true message_shown=true" "Game init script failed|deliberate_init_failure" \
	--scene res://tests/bootstrap_failure.tscn -- --runtime-error

if [ "$failures" -ne 0 ]; then
	echo "VALIDATION: $failures check(s) failed"
	exit 1
fi
echo "VALIDATION: all checks passed"
