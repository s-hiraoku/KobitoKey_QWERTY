# 英数/かな コンボ (combo_eisu / combo_kana)

日本語入力の切り替え。macOS の JIS キーボードの英数/かなキーに相当する
`LANG2` / `LANG1` を、ホームポジションの 2 キー同時押しで送る。

**検証済み** — `tests/ime-combos/`

## Sub-features

- **combo_eisu** — `key-positions = <12 13>` (D+F) → `&kp LANG2` (英数)
- **combo_kana** — `key-positions = <16 17>` (J+K) → `&kp LANG1` (かな)
- どちらも `timeout-ms = 80`、`layers` 指定なし = **全レイヤーで有効**
- 他のコンボ (`combo_esc` Q+W / `combo_tab` A+S / `combo_bt` BSPC+RSHFT) は
  `layers = <0>` に限定されている

## How to get to it (user POV)

- D と F を同時に叩く → IME が英数になる
- J と K を同時に叩く → IME がかなになる
- ローマ字入力中に `df` / `jk` と続けて打っても、80ms 以上ずれていれば
  文字として入る

## Driving it with native_posix_64

未作成。作るなら 2x2 の mock kscan では足りない
(コンボには隣接する 2 キー + 干渉確認用のキーが要る)。テスト側で
`&kscan { rows = <N>; columns = <N>; }` を上書きして広げる。

検証したいシナリオ:

1. 2 キーをほぼ同時 (10ms 差) に押す → `LANG2` が 1 回出る
2. 80ms を超えてずらす → コンボが成立せず、`D` と `F` が個別に出る
3. 高レイヤー滞在中に同時押し → `layers` 未指定なのでコンボが成立する
   (オートマウスレイヤー滞在中でも IME 切替を優先する、という設計意図の確認)

`events.patterns` は `hid_listener_keycode` を拾えば足りる。
`LANG1 = 0x90` / `LANG2 = 0x91`。

## Gotchas

- **`timeout-ms` の値がそのまま「取りこぼし」と「誤爆」のトレードオフ。**
  50ms → 80ms に上げた経緯がキーマップのコメントに残っている。値を触るなら
  シナリオ 2 の境界 (79ms と 81ms) を両方テストに入れないと意味がない
- **全レイヤーで有効なのは意図的。** `layers` を足して Layer 0 限定にすると
  オートマウスレイヤー滞在中に IME が切り替わらなくなる。テストで
  シナリオ 3 を固定しておけば、この意図が消えたときに気づける
- コンボは押下イベントを遅延させる。コンボ候補に含まれる position は
  `timeout-ms` の間ホストへの送出が保留されるので、hold-tap と重なる位置に
  コンボを足すと判定が絡む (`combo_bt` は pos 35/37 で、37 は `lt_r 3 RSHFT`)
