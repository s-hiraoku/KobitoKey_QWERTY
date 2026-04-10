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
| 5 | Spaces/Mission Control | 6 | 160 | 650 |
| 6 | ブラウザタブ | 10 | 140 | 400 |
| 7 | Launchpad/デスクトップ | 15 | 220 | 800 |

Layer 5 は初動を拾いやすくしつつ二重入力を避けるため、threshold は軽く、tick と wait-ms は重めに設定している。

## 参考資料

- [zmk-pointing-acceleration README](https://github.com/oleksandrmaslov/zmk-pointing-acceleration)
- [badjeff/zmk-pmw3610-driver](https://github.com/badjeff/zmk-pmw3610-driver)
- [PMW3610 データシート](https://www.epsglobal.com/Media-Library/EPSGlobal/Products/files/pixart/PMW3610DM-SUDU.pdf)
