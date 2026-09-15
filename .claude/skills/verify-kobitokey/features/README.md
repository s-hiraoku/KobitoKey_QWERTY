# KobitoKey 検証フィーチャーマップ

ユーザーから見た「機能」の一覧と、それぞれをどう検証するか。
このリポジトリの検証対象の正はここ。**1 つ通したことをもって
「キーマップを検証した」と言わないため**に置いてある。

`検証` 欄の意味:

- **自動** — `tests/` にテストがあり CI で回っている
- **未** — このハーネスで検証可能だがテストが無い (書くべき候補)
- **実機のみ** — native_posix_64 では原理的に検証できない

| 機能 | 検証 | テスト |
| --- | --- | --- |
| [親指レイヤーキー](thumb-layer-keys.md) | 自動 | `lt-left-thumb-retro-tap` / `lt-right-thumb-no-retro-tap` |
| [英数/かな コンボ](ime-combos.md) | 自動 | `ime-combos` |
| [トラボ機能への入口 (Y/H/P 長押し)](trackball-menu-keys.md) | 自動 | `menu-lt-tap-on-higher-layer` |
| [トラックボール操作](trackball-input.md) | 実機のみ | — |

## 次に書く候補

1. **Layer 4 (MOUSE) のマウスボタン位置** — U/I/O が MB1/MB3/MB2、J/L が
   MB4/MB5 に化ける。滞留 5 秒の窓で誤爆する位置なので、レイヤーが乗った
   状態での挙動を固定する価値がある
2. **`mt RSHFT SLASH` (右親指 /)** — `require-prior-idle-ms` でタイピング中の
   Shift 化けを防いでいる。境界値のテストが無い
3. **`combo_bt` (BSPC+RSHFT -> Layer 8)** — `timeout-ms = 50` で飛び先が
   BT 設定レイヤー。踏むと復帰が面倒なわりに誤爆条件が検証されていない

## 検証できないことの線引き

トラックボール入力 (`zip_temp_layer` / `zip_fixed_temp_layer` /
`input-processor-keybind`) は input subsystem のイベントが必要で、mock kscan
からは駆動できない。Mission Control の 2 連発のようなバグはこのハーネスでは
捕まらないので、**実機で確認するしかない**。ここを混同しないこと。
