# 親指レイヤーキー (lt_l / lt_r)

左親指 Space と右親指 Enter / RSHFT は、タップで文字・長押しでレイヤーという
hold-tap。このキーボードで一番事故が起きている場所。

Space は「文字」であると同時に「修飾キーと組み合わせる対象」でもあるため
(⌘Space, ⌃⌘Space)、レイヤーを載せた瞬間に構造的な不安定さを抱える。

## Sub-features

- **lt_l (pos 33, Space / Layer 1 FUNCTION)** — `retro-tap` 付き。
  他のキーを押さずに離した場合だけ tap にロールバックする
- **lt_r (pos 36/37, Enter / RSHFT → Layer 2 NUMBER / Layer 3 SYMBOL)** —
  `retro-tap` なし。付けると「Layer に入ろうとして思い直しただけで Enter が飛ぶ」
- **共通パラメータ** — `hold-preferred` / 180ms / quick-tap 125ms /
  require-prior-idle 90ms

## How to get to it (user POV)

- Space を叩く → スペースが入る
- Space を押しながら右手の矢印位置 → Layer 1 の矢印
- ⌘ を押したまま Space を長押しして、**Space から先に離す** → Spotlight / 絵文字
- Space を長押しして何も押さずに離す → スペースが 1 つ入る (retro-tap の副作用)

## Driving it with native_posix_64

`tests/lt-left-thumb-retro-tap/` と `tests/lt-right-thumb-no-retro-tap/`。

position は `row * 2 + col`。左親指テストの割り当て:

```
0 = lt_l 1 SPACE    1 = LCMD
2 = A (Layer 1 で LEFT)
3 = LCTRL
```

長押しは第 3 引数で作る。`tapping-term-ms = 180` なので 400ms 待てば確実に
hold 側へ倒れる:

```dts
ZMK_MOCK_PRESS(0,0,400)    /* Space を押して 400ms 保持 */
ZMK_MOCK_RELEASE(0,0,400)  /* 離す -> retro-tap で SPACE が出る */
```

判定経路まで見たいので `events.patterns` で `ht_decide` と `decide_retro_tap`
も拾う。`kp_pressed` だけ見ていると、同じ出力でも判定が変わったことに気づけない。

## Gotchas

- **`require-prior-idle-ms` は修飾キーでは効かない。** ZMK の
  `keycode_state_changed_listener` は `!is_mod()` のキーでしか `last_tapped` を
  更新しないので、⌘ を押した直後に Space を打っても quick-tap にはならない。
  テストのシナリオ間は 400ms 空けて、直前の tap が次に漏れないようにする
- **シナリオを詰めすぎると `quick-tap-ms = 125` が誤発火する。** 同じ position を
  125ms 以内に再度押すと tap 確定になり、意図した長押しにならない
- **retro-tap は「他のキーを押さなかった場合」だけ。** 修飾キーの**離上**も
  position イベントなので、Space より先に ⌘ を離すと
  `update_hold_status_for_retro_tap` が hold へ昇格させ、Space は出ない。
  これは仕様であり、`tests/lt-left-thumb-retro-tap` のシナリオ E で固定してある。
  ここが赤くなったら「直った」のではなく「retro-tap の意味が変わった」を疑う
- **positional hold-tap (`hold-trigger-key-positions` +
  `hold-trigger-on-release`) を復活させない。** `hold-preferred` が他キーの
  『押下』で hold を確定するのに対し、位置が記録されるのは『離した』時なので
  `decide_positional_hold` が常に空振りする。過去に入っていたが一度も
  機能していなかった
- テストの behavior は実機キーマップの**写し**でしかない。数値を変えるときは
  両方直す。`scripts/doctor.sh` が乖離を検出する
