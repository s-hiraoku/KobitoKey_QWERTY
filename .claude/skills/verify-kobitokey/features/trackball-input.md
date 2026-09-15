# トラックボール操作

左右 2 つの PMW3610。右はポインター、左はスクロールとジェスチャー。

**実機のみ** — native_posix_64 のハーネスでは原理的に検証できない。
ここを「検証した」と言わないための線引きとして置いてある。

## Sub-features

- **右トラボ** — ポインター移動。動かすと `zip_temp_layer 4 5000` で
  Layer 4 (MOUSE) が 5 秒発動
- **左トラボ** — 2 次元スクロール。動かすと `zip_fixed_temp_layer 13 2500` で
  Layer 13 (SCROLL MENU) が 2.5 秒発動
- **ジェスチャー** — Layer 5/6/7 で `input-processor-keybind` が移動量を
  キー入力に変換 (Ctrl+矢印 / Cmd+T / F4 等)
- **ズーム** — Layer 9。`zoom_hold` で LCMD を保持したままスクロールを送る
- **ドラッグロック / 精密モード / 横スクロール** — Layer 10/11/12

## How to get to it (user POV)

- 右トラボを転がす → カーソルが動く。直後は Layer 4 なので U/I/O 等が
  マウスボタンに化ける
- 左トラボを転がす → スクロール。直後 2.5 秒は Layer 13
- Y/H/P を長押ししながら左トラボ → ジェスチャー

## Driving it with native_posix_64

**できない。** 駆動には Zephyr の input subsystem に `INPUT_EV_REL` イベントを
流す必要があり、mock kscan (キーマトリクス) からは発生させられない。
`zip_temp_layer` / `zip_fixed_temp_layer` / `input-processor-keybind` は
いずれも input processor チェーンの中で動くので、このハーネスの外側にある。

したがって以下は**実機でしか確認できない**:

- オートマウスレイヤーの発動と滞留時間
- `excluded-positions` の効き方
- ジェスチャーの発火回数 (Mission Control の 2 連発のような不具合)
- センサーの感度・加速カーブ・ノイズ

## Gotchas

- **レイヤーが絡む不具合を「キーマップの問題」と決めつけない。**
  日付が入らない (⌘;) / 絵文字が出ない (⌃⌘Space) の調査では、原因が
  トラボ由来の一時レイヤーだったケースと hold-tap だったケースの両方があった。
  切り分けは「トラボに触らず 3 秒待ってから再現するか」が速い
- **Layer 13 は `&to 0` と状態がズレる。** `zmk_keymap_layer_to(0)` は
  レイヤーを落とすがドライバの `data->active` は 1 のまま残るので、
  残り時間は再発動しない。症状が出たり出なかったりする原因になる
- 実機確認の結果は `docs/trackball-tuning.md` に記録する慣例。
  このスキルの守備範囲外だが、証拠の置き場所としてはそこ
