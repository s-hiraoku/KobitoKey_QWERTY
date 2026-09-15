---
name: verify-kobitokey
description: KobitoKey (ZMK 自作キーボードファームウェア) のキーマップ挙動を、ZMK の native_posix_64 テストハーネスで実証する。押下シーケンスに対して実際にどの HID イベントが出るかをスナップショット比較する。hold-tap / retro-tap / combo / レイヤー遷移を変更したとき、「ビルドが通った」ではなく「意図した挙動になっている」を証明したいときに使う。実機に書き込む前の唯一の機械的な検証手段。
---

# verify-kobitokey

このリポジトリには「起動して操作できるアプリ」が無い。成果物は `.uf2` で、
ユーザーが触る面は物理キーボードそのもの。エージェントが指で押すことはできない。

代わりに ZMK は **native_posix_64 上でキーマップを実行し、HID イベント列を
スナップショットと突き合わせる**テストハーネスを持っている。これがこのリポジトリで
唯一、機械的に「挙動」を検証できる面であり、このスキルが駆動するのはそこ。

**このスキルが証明できること**: 押下シーケンス → HID 出力の対応。
**証明できないこと**: トラックボールのセンサー挙動、BLE 接続、消費電力、
実際の macOS 側の解釈。これらは実機でしか確認できない。

## なぜこれが要るのか

絵文字ショートカット (⌃⌘Space) が効かない調査では、`hold-preferred` +
`hold-trigger-on-release` の組み合わせが「一度も機能していない」ことを、
ZMK の `behavior_hold_tap.c` を読んで初めて確定できた。キーマップを眺めても、
ビルドを通しても分からない種類のバグだった。

結論をテストに落としておけば、次に同じ場所を触る人間やエージェントは
ソースを読み直さずに済む。`tests/` はそのための資産。

## Launch

**ローカル実行はこのマシンでは不可** (後述)。CI が実行環境。

テストを走らせる = ブランチに push する。`.github/workflows/keymap-test.yml` が
`tests/**` と `config/KobitoKey.keymap` の変更で発火する。

```bash
git push origin HEAD:<branch>
gh run list --workflow keymap-test.yml --limit 1 --json databaseId,status,conclusion
```

準備完了の判定は `status=completed`。所要はキャッシュが効いて 3-6 分、
コールドで 10 分前後。

### ローカル実行が塞がっている理由 (2026-09-15 時点)

`native_posix_64` は Linux バイナリを吐くので macOS では直接ビルドできず、
コンテナが要る。しかし社内ネットワークの **Cato Networks による TLS
インスペクション**で、colima / podman の VM から Docker Hub に到達できない:

```
x509: certificate signed by unknown authority
issuer=CN = Cato-Networks-Server-tok3catod2a
```

ホスト側の macOS は Cato の CA を信頼しているが VM は信頼していない。
VM の信頼ストアに企業 CA を入れれば解決するが、**会社のセキュリティ設定に
手を入れる話なのでエージェントの判断で行わないこと。** 必要ならユーザーに
判断を仰ぐ。解決した場合のローカル手順は下の「参考」に置いてある。

## Doctor

テストを回す前に必ず実行する。read-only。

```bash
.claude/skills/verify-kobitokey/scripts/doctor.sh
```

見るのは 3 つ:

1. `tests/*/` に 3 点セット (`native_posix_64.keymap` / `keycode_events.snapshot` /
   `events.patterns`) が揃っているか
2. テスト同士の構成が壊れていないか
3. **drift** — テストが宣言している behavior のパラメータが
   `config/KobitoKey.keymap` の実物と一致しているか

3 が一番重要。テストの keymap は mock kscan 用に behavior を再宣言しているので、
**実機側の数値だけ変えるとテストは通り続けるのに挙動だけ変わる**という最悪の嘘が
成立する。doctor はそれを検出する。

drift が出たら、どちらが正かは実機の意図で決める。**テスト側だけ書き換えて
通すのは禁止** — 「実機と違うものを検証し続ける」状態になる。

## Drive

1 テスト = 1 ディレクトリ。`tests/<name>/` に 3 ファイル:

- `native_posix_64.keymap` — behavior 定義 + 2x2 のキーマップ + 押下シーケンス
- `events.patterns` — ログから何を拾うかの sed スクリプト
- `keycode_events.snapshot` — 期待される出力

キー位置は 2 行 2 列の mock kscan (`app/boards/native_posix_64.overlay`) で、
**position = row * 2 + col**。つまり `(0,0)=0 (0,1)=1 (1,0)=2 (1,1)=3`。

押下シーケンスの書式 (第 3 引数は**そのイベントの後に待つ ms**):

```dts
&kscan {
    events = <
        ZMK_MOCK_PRESS(0,0,400)    /* position 0 を押して 400ms 待つ = 長押し */
        ZMK_MOCK_RELEASE(0,0,10)
    >;
};
```

### 新しいテストの作り方

1. `tests/<name>/` を作り、既存テストの 3 ファイルをコピーして書き換える
2. behavior は `config/KobitoKey.keymap` から**パラメータをそのまま写す**
   (doctor の drift チェック対象に入れるなら node 名も合わせる)
3. `keycode_events.snapshot` は**まず期待値を手で書く**。これが仮説になる
4. push して CI を見る。差分が出たら、それは仮説が違ったか実装が違うかのどちらか
   — **差分を見てから、どちらを直すか決める**
5. 通ったらコミット

**スナップショットを CI の出力で機械的に上書きするのは最後の手段。**
それをやると「今の実装がこう動く」を記録するだけで、「こう動くべき」の
検証にならない。どうしても必要なときは `workflow_dispatch` の `auto_accept`
入力で再生成し、**中身を読んで意図と合っているか確認してから**コミットする。

```bash
gh workflow run keymap-test.yml --ref <branch> -f auto_accept=true
gh run download <run-id> -n snapshot-<test-name>
```

### 使えるログ行

`events.patterns` で拾えるもの (`app/src/` の `LOG_DBG` 由来):

| パターン | 出る行 |
| --- | --- |
| `hid_listener_keycode` | `kp_pressed: usage_page 0x07 keycode 0x2C implicit_mods 0x00 explicit_mods 0x00` |
| `mo_keymap_binding` | `mo_pressed: position 0 layer 1` |
| `on_hold_tap_binding` | `ht_binding_pressed: 0 new undecided hold_tap` |
| `decide_hold_tap` | `ht_decide: 0 decided tap (hold-preferred decision moment key-up)` |
| `decide_retro_tap` | `decide_retro_tap: 0 retro tap` |
| `update_hold_status_for_retro_tap` | `update_hold_status_for_retro_tap: Update hold tap 0 status to hold-interrupt` |

キーコードは `0x%02X` (大文字)。`SPACE=0x2C` `RET=0x28` `A=0x04` `LEFT=0x50`
`N1=0x1E` `LGUI=0xE3` `LCTRL=0xE0` `LSHFT=0xE1`。

## Evidence

証拠として残すもの:

- **CI の run URL と conclusion** — これが一次証拠
- **`keycode_events.snapshot` の diff** — 挙動が変わったなら必ずここに出る。
  「テストが通った」より「スナップショットがこう変わった」の方が情報量が多い
- 失敗時は `log-<test>` artifact に `keycode_events_full.log` (フィルタ前の全ログ)
  が上がる。`events.patterns` で拾い損ねている行を探すときに使う

証明の基準:

- **ユーザーが実際に通る経路を再現する。** 「長押しして離す」を検証したいなら
  press/release のシーケンスで書く。behavior を直接叩くような近道はしない
- **結果だけでなく過程も captureする。** `kp_pressed` だけでなく
  `ht_decide` も拾っておくと、同じ出力でも判定経路が変わったことに気づける
- **直らなかったことも固定する。** retro-tap には「修飾キーを先に離すと救済
  されない」限界がある。これをテストに書いておかないと、後から「直ってない」と
  再調査が始まる
- 実機でしか分からないこと (センサー、BLE、OS 側の解釈) をこのハーネスで
  「検証した」と言わない

## Cleanup

CI 実行なので落とすプロセスは無い。片付けるのはブランチだけ:

```bash
git push origin --delete <branch>   # マージ後、不要になったら
```

ローカルに `~/.cache/kobitokey-verify/` (zmk のクローン) がある場合、消しても
構わないが、`app/src/` を読むのに便利なので残しておくとよい。**証拠 (CI の run
と snapshot の diff) は GitHub 側に残るので、ローカルの片付けで消えることはない。**

## Helpers

| スクリプト | 用途 |
| --- | --- |
| `scripts/doctor.sh` | 上記 Doctor。引数なし。exit 0 なら回してよい |

## features/

検証対象の一覧は [`features/README.md`](features/README.md)。
**1 つのテストが通ったことをもって「キーマップを検証した」と言わないこと。**
feature map に挙がっている他の項目は未検証のまま残っている。

## 参考: ローカル実行 (TLS の問題が解決した場合のみ)

このマシンでは未検証。**動いたことを確認せずに「ローカルで検証した」と報告しない。**

```bash
colima start
docker pull docker.io/zmkfirmware/zmk-build-arm:3.5
WS=~/.cache/kobitokey-verify
git clone --depth 1 -b v0.3 https://github.com/zmkfirmware/zmk "$WS/zmk"
docker run --rm -v "$WS:/ws" -w /ws/zmk docker.io/zmkfirmware/zmk-build-arm:3.5 \
  bash -lc 'west init -l app && west update --fetch-opt=--filter=tree:0 && west zephyr-export'

# テスト実行 (リポジトリを /repo にマウント)
docker run --rm -v "$WS:/ws" -v "$PWD:/repo" -w /ws/zmk \
  docker.io/zmkfirmware/zmk-build-arm:3.5 \
  bash -lc 'ZMK_SRC_DIR=/ws/zmk/app ZMK_BUILD_DIR=/ws/build \
            ./app/run-test.sh /repo/tests/lt-left-thumb-retro-tap'
```

`run-test.sh` は `-DZMK_CONFIG` にテストディレクトリを渡す作りなので、zmk ツリーの
外にあるテストをそのまま実行できる (パスに `/tests/` が含まれていることが条件)。
