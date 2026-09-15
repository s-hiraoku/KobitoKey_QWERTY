#!/usr/bin/env bash
# 読み取り専用。テストを回す前に「回す価値がある状態か」を判定する。
#
# 一番効くのは最後の drift チェック。テストの keymap は mock kscan 用に
# behavior を再宣言しているので、config/KobitoKey.keymap 側だけ数値を変えると
# テストは通り続けるのに実機の挙動だけ変わる、という最悪の嘘が成立する。
# それを検出する。
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
KEYMAP="$REPO_ROOT/config/KobitoKey.keymap"
TESTS_DIR="$REPO_ROOT/tests"
rc=0

say()  { printf '%-52s %s\n' "$1" "$2"; }
ok()   { say "$1" "OK"; }
bad()  { say "$1" "NG  $2"; rc=1; }

echo "== 前提 =="
[ -f "$KEYMAP" ] && ok "config/KobitoKey.keymap" || bad "config/KobitoKey.keymap" "見つからない"
[ -d "$TESTS_DIR" ] && ok "tests/" || bad "tests/" "見つからない"

echo
echo "== テストディレクトリの構成 =="
for d in "$TESTS_DIR"/*/; do
  [ -d "$d" ] || continue
  name="$(basename "$d")"
  missing=""
  for f in native_posix_64.keymap keycode_events.snapshot events.patterns; do
    [ -f "$d/$f" ] || missing="$missing $f"
  done
  [ -z "$missing" ] && ok "$name" || bad "$name" "欠落:$missing"
done

# behavior ブロックから 1 プロパティの値を取り出す。
# ブロックは `<node> {` から最初の `};` まで。
# `= <180>;` -> 180 / `= "hold-preferred";` -> hold-preferred
# 真偽プロパティ (`retro-tap;`) -> present / 無ければ absent
prop_of() {
  awk -v node="$2" -v prop="$3" '
    $0 ~ node "[[:space:]]*\\{" { inblk = 1 }
    inblk && $0 ~ "^[[:space:]]*};" { inblk = 0 }
    inblk && $0 ~ "^[[:space:]]*" prop "[[:space:]]*(=|;)" {
      line = $0
      if (line !~ /=/)      { print "present" }
      else if (line ~ /"/)  { sub(/[^"]*"/, "", line); sub(/".*/, "", line); print line }
      else                  { sub(/.*=[[:space:]]*</, "", line); sub(/>.*/, "", line); print line }
      found = 1; exit
    }
    END { if (!found) print "absent" }
  ' "$1"
}

echo
echo "== 実機キーマップとテストの behavior 乖離 =="
check_drift() {
  local node="$1" test_file="$2"; shift 2
  [ -f "$test_file" ] || { bad "$node" "テストが無い: ${test_file#$REPO_ROOT/}"; return; }
  for prop in "$@"; do
    local a b
    a="$(prop_of "$KEYMAP" "$node" "$prop")"
    b="$(prop_of "$test_file" "$node" "$prop")"
    if [ "$a" = "$b" ]; then
      ok "$node $prop = $a"
    else
      bad "$node $prop" "keymap='$a' test='$b'"
    fi
  done
}

HT_PROPS="flavor tapping-term-ms quick-tap-ms require-prior-idle-ms retro-tap"
CB_PROPS="timeout-ms key-positions bindings layers"

check_drift lt_left_thumb  "$TESTS_DIR/lt-left-thumb-retro-tap/native_posix_64.keymap"        $HT_PROPS
check_drift lt_right_thumb "$TESTS_DIR/lt-right-thumb-no-retro-tap/native_posix_64.keymap"    $HT_PROPS
check_drift scroll_menu_layer_tap "$TESTS_DIR/menu-lt-tap-on-higher-layer/native_posix_64.keymap" $HT_PROPS
check_drift combo_eisu     "$TESTS_DIR/ime-combos/native_posix_64.keymap"                     $CB_PROPS
check_drift combo_kana     "$TESTS_DIR/ime-combos/native_posix_64.keymap"                     $CB_PROPS

echo
if [ $rc -eq 0 ]; then
  echo "doctor: 問題なし。テストを回してよい。"
else
  echo "doctor: 上の NG を直してから回すこと。"
  echo "  drift が出た場合、正はどちらか実機の意図で決める。"
  echo "  テスト側だけ直すと『実機と違うものを検証し続ける』ことになるので注意。"
fi
exit $rc
