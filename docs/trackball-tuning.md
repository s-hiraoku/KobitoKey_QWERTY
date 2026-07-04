# トラックボール チューニング記録

Magic Trackpad 風の操作感を目指した右トラックボール（ポインター）のチューニング記録。

**現在の対応状況: 右トラックボールは Phase 3 まで適用済み**

## 目標

右トラックボールを Magic Trackpad に近い操作感にする。特徴として:

1. 低速時に "張り付くような" 吸い付き感
2. 中速域で粘る（加速が急に立ち上がらない）
3. 高速で一気に伸びる（画面横断が一振りで完結）
4. 滑らかで粒状感のない動き

## 使用モジュール

- 加速度: [oleksandrmaslov/zmk-pointing-acceleration](https://github.com/oleksandrmaslov/zmk-pointing-acceleration)
- センサー: PMW3610（最大 3200 CPI / 200 CPI ステップ）

## 段階的プラン

### Phase 1: パラメータ微調整のみ ✅ 適用済み

加速度パラメータのみを調整。副作用なし、いつでも戻せる。

```dts
pointer_accel_right {
    min-factor = <950>;              /* ほぼ完全等倍 */
    max-factor = <3500>;             /* 高速を予測可能に */
    speed-threshold = <2000>;        /* 低速ゾーン拡大 */
    speed-max = <8500>;              /* 加速ピークを遠くへ */
    acceleration-exponent = <3>;
};
```

**効果**: 低速の張り付き感と中速の粘りが強まる。

### Phase 2: CPI 調整 ✅ 適用済み

ハード側の解像度を上げて低速の精度を向上。accel 側で相殺してベース速度は維持。

```dts
/* KobitoKey_right.overlay */
tb_right {
    cpi = <800>;                     /* 600→800 */
};

/* KobitoKey_left.overlay */
pointer_accel_right {
    min-factor = <750>;              /* CPI増分を相殺 */
    max-factor = <3200>;             /* 同上 */
    speed-threshold = <2000>;
    speed-max = <8500>;
    acceleration-exponent = <3>;
};
```

**効果**: 低速域の解像度が上がり、微小な動きがより素直にカーソルに伝わる。Magic Trackpad の "吸い付くような" 感触に近づく。

**リスク**: 小。PMW3610 の定格内（最大 3200 CPI）。

### Phase 3: ポーリングレート向上 + 低速域の微調整 ✅ 適用済み

`CONFIG_PMW3610_REPORT_INTERVAL_MIN` を下げて報告レートを上げる。カーソルの滑らかさに直結。

```conf
# KobitoKey_right.conf
CONFIG_PMW3610_REPORT_INTERVAL_MIN=8    # 12→8 (約83Hz→125Hz)
```

**効果**: カーソルの粒状感が減り、Magic Trackpad の "ぬるっとした" 動きに最も近づく。

**リスク**: 中。PMW3610 は低電力が売りなので、ポーリングレート増でバッテリー消費が増加。BLE 右手子機の電池持ちが1〜2日短くなる可能性。左右の充電タイミングがズレる副作用あり。

**実施内容**: 右側のみ `CONFIG_PMW3610_REPORT_INTERVAL_MIN=8` を適用し、accel も少しだけ減速方向へ微調整した。

**効果**: 粒状感を減らしつつ、移動距離を 5〜10% 程度短くして小さいターゲットで止めやすくする。

## 現在の右トラックボール最終値

`config/boards/shields/KobitoKey/KobitoKey_right.overlay`:
```dts
tb_right: trackball@0 {
    cpi = <800>;
};
```

`config/boards/shields/KobitoKey/KobitoKey_left.overlay`:
```dts
pointer_accel_right: pointer_accel_right {
    min-factor = <620>;
    max-factor = <2200>;
    speed-threshold = <2500>;
    speed-max = <10000>;
    acceleration-exponent = <3>;
    track-remainders;
};
```

`config/boards/shields/KobitoKey/KobitoKey_right.conf`:
```conf
CONFIG_PMW3610_REPORT_INTERVAL_MIN=8
```

**Phase 2 後の微調整** (2026-04-10): 当初値 (min=750, max=3200, threshold=2000, speed-max=8500) では
Magic Trackpad より速すぎたため、高速域を抑える方向で再調整した。さらに右側の粒状感を減らすため、
Phase 3 で報告間隔を 12 から 8 に上げ、accel を少しだけ減速方向へ振って低速の止めやすさを強めた。

## 左トラックボール（参考: スクロール用）

左は役割が異なるが、同じく Magic Trackpad 風（慣性スクロール風）にチューニング済み:

```dts
&pointer_accel {
    min-factor = <800>;
    max-factor = <2500>;             /* y_scaler×15 と掛け算で実効37.5倍 */
    speed-threshold = <1400>;
    speed-max = <6000>;
    acceleration-exponent = <3>;     /* 粘ってから急に伸びる=慣性風 */
};
```

ジェスチャー（Layer 5/6/7）は用途の重さに応じた段階設定:

| Layer | 用途 | threshold | tick | wait-ms |
|---|---|---|---|---|
| 5 | Spaces/Mission Control | 3 | 100 | 600 |
| 6 | ブラウザタブ | 3 | 100 | 600 |
| 7 | Launchpad/デスクトップ | 3 | 70 | 700 |

Layer 5 の二重入力対策は tick 増ではなく tap-ms=10 + max_threshold=70 の構造的対策に変更した（後述 2026-07-04）。Layer 6 はタブ送りの反応性を優先して少し軽く、Layer 7 は初回スワイプの取りこぼしを避けるため tick をさらに下げている。
Layer 7 の上下は `F4` / `F11`、左右は Launchpad 表示中の選択移動用に `LEFT` / `RIGHT` を送る。

### 左トラックボール初回操作の取りこぼし対策

Layer 7 の tick を下げても初回操作が無反応になることがあったため、PMW3610 の省電力復帰で最初の motion が落ちている可能性を見て、左センサーに `force-awake` を設定した。ZMK が ACTIVE の間はセンサーを起こしたままにするため、しばらく触らなかった後の初回スワイプを拾いやすくなる想定。

副作用として左手側の消費電力は増える可能性がある。改善しない場合はハード要因（ボール支持部、センサー窓、IRQ/SPI 配線）や keybind processor 側の取りこぼしを再確認する。

### Layer 5 の初動改善と 2 連発の構造的防止 (2026-07-04)

「初動が鈍い」「発火後に稀に仮想デスクトップが 2 枚送られる」の 2 症状を同時に修正。

zettaface/zmk-input-processor-keybind のソースを読んで確認した 2 連発の正体:

1. 発火時に累積 delta はゼロクリアされる（`track_remainders` false）
2. `tap-ms` 後に press_work が再実行され、その窓内に再び tick 分溜まっていると release → wait-ms スリープ → **2 発目の press** が走る
3. つまり 2 連発は「tap-ms 窓内の再蓄積」だけで起きる。フリックのピーク（1 パケット 60〜90 相当）が窓に落ちると tick=130 でも突破されていた

対策（`gesture_keybind`）:

```dts
tick = <100>;          /* 130 → 100: 初動の必要累積を減らす */
tap-ms = <10>;         /* 15 → 10: レポート間隔 12ms より短くし、窓内パケットを最大 1 個に */
max_threshold = <70>;  /* 新設: 1 パケットの寄与を hypot 込み最大 96 (< tick) に制限 */
```

- 窓に入るパケットは最大 1 個（10ms < CONFIG_PMW3610_REPORT_INTERVAL_MIN=12ms）
- その 1 パケットの最大寄与は 70 + (70×3>>3) = 96 < tick=100 → 窓内再発火が数学的に不成立
- tick を下げても 2 連発が復活しないため、初動と多重発火対策を両立できる
- 70 超のパケットは捨てられるが、CPI200/12ms で 70 ≒ 秒速 29 インチ相当。通常のスワイプでは到達しない
- キー押下時間が 10ms になるため、ショートカット取りこぼしが出たら tap-ms=15 に戻す（その場合窓に 2 パケット入り得るので完全防止は崩れる）

### オートマウスレイヤー滞留時間 3500ms (2026-07-04)

`&zip_temp_layer 4 1500` だと、ボールを止めてからマウスボタンやジェスチャーキーを押す前に
Layer 4 が抜けてしまうことがあったため、滞留時間を 2 秒延長して 3500ms にした。

### Layer 9（連続ズーム）は keybind を使わない

Layer 9 はジェスチャー系と異なり `input-processor-keybind` を使わない。理由は離散的なキー発火（`Cmd+`/`Cmd-` の連打）では Magic Trackpad ピンチのような滑らかな連続ズームが得られないため。

代わりに keymap 側で `zoom_hold` という macro behavior を定義している:

```dts
zoom_hold: zoom_hold {
    compatible = "zmk,behavior-macro-one-param";
    #binding-cells = <1>;
    bindings
        = <&macro_press &kp LCMD>
        , <&macro_press &mo MACRO_PLACEHOLDER>
        , <&macro_pause_for_release>
        , <&macro_release &mo MACRO_PLACEHOLDER>
        , <&macro_release &kp LCMD>
        ;
};
```

`&zoom_hold 9` を押している間 LCMD が保持され、Layer 9 でも左トラックボールはデフォルトのスクロール処理に流れる（overlay の Layer 9 分岐は空）。結果、OS には `Cmd+ホイール` として届き、macOS / Figma / ブラウザ / VSCode が連続ズームと解釈する。

`pointer_accel`（min 0.8 / max 2.5 / 三次カーブ）がそのまま効くため、操作感は通常スクロールと同等の滑らかさで、刻んでズームできる。

## オートマウスレイヤー（zip_temp_layer）チューニング

トラックボール操作時に Layer 4 (MOUSE) を自動発動させる `zip_temp_layer` の安定化記録。

### 症状

1. **マウスレイヤーから戻らない**: Layer 4 中に `&mo 5/6/7` などレイヤー切替を押した状態でトラックボールに触れると、タイマーがリセットされ続けて Layer 4 が10秒間ロックされる
2. **`-` を打つと `H` になる**: Layer 3 (SYMBOL) で `lt 3 RSHFT` 押下中、トラックボールに触れた直後に position 15 を押すと、`zip_temp_layer` が割り込んで Layer 4 へ遷移し、`MINUS` ではなく `&mo 5` → 透過で Layer 0 の `H` が出る

### 修正値 (2026-05-14)

```dts
&tb_left_listener {
    input-processors = <... &zip_temp_layer 4 2500>;  /* 10000 → 2500 */
};

&tb_right_listener {
    input-processors = <... &zip_temp_layer 4 2500>;  /* 10000 → 2500 */
};

zip_temp_layer {
    require-prior-idle-ms = <300>;  /* 150 → 300 */
};

&zip_temp_layer {
    excluded-positions = <
        5 6 7 8 9 15 16 18 19  /* 数字段右半分 */
        30 32 33 34 36 37 39   /* 親指列。34/36/37 を追加 */
    >;
};
```

### 効果

- **滞留時間 10000ms → 2500ms**: マウス層の自動復帰が4倍速くなり、入力詰まりが解消
- **prior-idle 150ms → 300ms**: タイピング中のトラボ誤反応を抑制。`-`→`H` の暴発を防ぐ
- **excluded-positions に 34/36/37 追加**: 当時は `LCTRL`, `lt 2 ENTER`, `lt 3 RSHFT` 押下時の安定化として追加したが、後に 36/37 は Layer 4 から低番レイヤーへ移動する際の阻害要因だと分かった（2026-06-20 修正）

副作用は限定的（クリック中にトラボから指を離してから2.5秒で Layer 0 へ戻るので、長時間のドラッグ操作中はトラボに軽く触れ続ける必要がある程度）。Layer 4 のキーマップ自体（`&trans` の扱い）は Cmd+クリック等の修飾用途を壊さないよう温存している。

### 追加修正 (2026-05-19) — 取りこぼし対策

de56e74 適用後も `-`→`H` 化けと、ローマ字入力中の小さいひらがな化け（`tsu`→`su`→「ぅ」相当）の取りこぼしが続いていたため、再強化:

```dts
zip_temp_layer {
    require-prior-idle-ms = <500>;  /* 300 → 500 */
};

&zip_temp_layer {
    excluded-positions = <
        5 6 7 8 9 15 16 17 18 19  /* 17 (K) を追加: 中段右の唯一の抜け */
        30 32 33 34 36 37 39
    >;
};
```

加えて Layer 4 (MOUSE) の左半分・3段目の `&to 0` を `&trans` に変更。これにより Layer 4 が誤発動した瞬間に左半分のキーを押しても、押下イベントが Layer 0 に透過して文字入力が成立する（従来は `to 0` で Layer 0 へ移行するだけで押下自体は消費されていた）。マウスボタン（position 15/16/18/19）と zoom_hold (19) は温存。

**効果**:
- prior-idle 300→500ms で、日本語ローマ字入力の自然なキー間隔（200〜400ms）でも Layer 4 に取られにくくなる
- K キー除外で、`ka/ki/ku/ke/ko` などの `k` を起点とした打鍵で Layer 4 が割り込んでも無視される
- Layer 4 誤発動時の文字欠落が `&trans` 化で救済される

**副作用**: マウス操作中に左半分の文字キーを押すと、その文字が入力される（従来は Layer 0 へ戻るだけだった）。マウス操作中に文字入力するケースは稀なので実害なし。

### 追加修正 (2026-06-20) — Layer 4 から Layer 1/2/3 へ入れない対策

`excluded-positions` は「キー押下時にオートマウス Layer 4 を解除しない位置」のリストなので、Layer 1/2/3 の lt 親指キー（position 33/36/37）を含めると、Layer 4 が残ったまま低番レイヤーを hold する形になる。ZMK は高番の active layer を優先するため、Layer 4 の `&trans` やマウス系キーにマスクされ、FUNCTION/NUMBER/SYMBOL へ移動したように見えないことがあった。

```dts
&zip_temp_layer {
    excluded-positions = <
        5 6 7 8 9 15 16 17 18 19
        30 32 34 39
    >;
};
```

**効果**:
- Layer 4 中に `lt 1 SPACE` / `lt 2 ENTER` / `lt 3 RSHFT` を押すと、先に Layer 4 が解除され、Layer 1/2/3 の hold が最上位になる
- Layer 4 上の `&mo 5/6/7`、マウスボタン、`zoom_hold 9`、明示的な `to0` は引き続き Layer 4 を保ったまま動く
- Layer 3 の `-` 入力対策は `require-prior-idle-ms = <500>` が担う。`excluded-positions` は Layer 4 がすでに active な時の解除制御であり、Layer 4 への新規突入抑制ではない

### 追加修正 (2026-06-20) — 左 force-awake と Layer 4 滞留の分離

Layer 5/6/7 の初回スワイプ改善として左 PMW3610 に `force-awake` を入れた後、左トラックボールの微小な motion が拾われやすくなり、左 default 経路の `&zip_temp_layer 4 1500` が Layer 4 の復帰タイマーを延長し続けることがあった。

ジェスチャー操作感は維持したいので、`force-awake` と Layer 5/6/7 の input processor はそのままにし、左 default 経路から auto mouse 発動だけを外した。右トラックボール側の `&zip_temp_layer 4 1500` は残すため、ポインター操作で Mouse Layer に入る運用は維持される。

```dts
&tb_left_listener {
    input-processors =
            <&sensor_rotation_left>,
            <&pointer_accel>,
            <&zip_x_scaler 0 1>,
            <&zip_y_scaler 1 15>,
            <&zip_xy_to_scroll_mapper>,
            <&zip_scroll_transform INPUT_TRANSFORM_Y_INVERT>,
            <&zip_scroll_transform INPUT_TRANSFORM_X_INVERT>;
};
```

**効果**:
- 左センサーの微小入力が Layer 4 のタイマーをリセットし続ける経路をなくす
- Layer 5/6/7 のジェスチャーと Layer 9 の Cmd+scroll は従来通り左トラックボールで動く
- Mouse Layer 4 の自動発動は右ポインター操作に集約する

## 参考資料

- [zmk-pointing-acceleration README](https://github.com/oleksandrmaslov/zmk-pointing-acceleration)
- [badjeff/zmk-pmw3610-driver](https://github.com/badjeff/zmk-pmw3610-driver)
- [ZMK Temporary Layer Input Processor](https://zmk.dev/docs/keymaps/input-processors/temp-layer)
- [PMW3610 データシート](https://www.epsglobal.com/Media-Library/EPSGlobal/Products/files/pixart/PMW3610DM-SUDU.pdf)
