# トラボ機能への入口 (Y/H/P の menu_lt)

右手上段の Y / P と中段の H は、タップすると文字、長押しすると
ジェスチャー系レイヤー (5 GESTURE / 6 TAB / 7 DESKTOP) へ入る hold-tap。

**未検証** — 優先度が高い。この位置は過去 2 回、実機で文字が出ない/リピートする
不具合を起こしている (`e1577a6`, `b6209b8`)。

## Sub-features

- **`menu_lt`** — `tap-preferred` / `tapping-term-ms = 180` / `bindings = <&mo>, <&kp>`
- Layer 0: `&menu_lt 5 Y` (pos 5) / `&menu_lt 6 P` (pos 9) / `&menu_lt 7 H` (pos 15)
- Layer 4 (MOUSE) と Layer 13 (SCROLL MENU) にも同じ位置に同じ `menu_lt` がある
- `menu_zoom` は同型だが hold 側が `zoom_hold` (LCMD 保持 + レイヤー)

## How to get to it (user POV)

- `y` / `h` / `p` を普通に叩く → 文字が入る
- 長押ししながら左トラックボールを回す → ジェスチャー (Spaces 切替、タブ操作、
  Mission Control 等)
- トラックボールを動かした直後 (Layer 4 / 13 滞在中) に叩いても文字が入る

## Driving it with native_posix_64

未作成。**レイヤーが重なった状態のタップ**を再現するのが本質なので、
テスト側で複数レイヤーを定義し、`&mo` で上位レイヤーに入った状態から
`menu_lt` の position を叩く。

検証したいシナリオ:

1. 素の状態でタップ → `Y` が出る
2. 180ms 以上長押し → レイヤー 5 に入り、文字は出ない
3. **上位レイヤー (4 相当) に入った状態でタップ → `Y` が出る**
   ← `&mo 5` を直に置いていた頃はここが無反応だった。回帰の本命
4. 上位レイヤー滞在中に長押し → レイヤー 5 に入る

`tap-preferred` なので、他キーを押しても `tapping-term-ms` を超えなければ
tap に倒れる。`hold-preferred` の lt_l/lt_r とは判定が違う点に注意。

## Gotchas

- **実機の Layer 4 / 13 はトラックボール入力で発動する。**
  mock kscan からは駆動できないので、テストでは `&mo` で「同じレイヤー状態」を
  作って代用する。**これは近似**であり、`zip_temp_layer` の
  `excluded-positions` や滞留タイマーの挙動は再現できない。
  過去の不具合はまさにその `excluded-positions` が絡んでいたので、
  このテストが通っても実機で同じ症状が出ないとは言い切れない
- `&mo` を直接置くと「タップしても何も出ない」。`menu_lt` 化はそれが理由。
  シナリオ 1 と 3 がそれを固定する
- Layer 5/6/7 の同じ position に置かれている `&mo 5` 等の自己参照は、
  既に押されているキーなので発火しない死に設定。テストで拾おうとしないこと
