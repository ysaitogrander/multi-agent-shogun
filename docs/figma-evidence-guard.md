# Figma 取得証跡ガード — 多層防御の責務と運用規律

**作成**: ashigaru3 / subtask_707_h5_responsibility_doc / 2026-06-04  
**参照アーキテクチャ**: queue/reports/cmd_707_arch_review.md  
**正典マップ**: context/figma-canonical-map.md

---

## 1. 多層防御の階層

Figma デザイン準拠の担保には、単一の関所では不十分である。  
エージェント種別（Claude / Copilot / Codex / 手動操作）や迂回経路に応じた  
4 層の防御を組み合わせ、最終的に CI が全経路を un-bypassable に検証する。

| 層 | 実装 | 設置先 | 対象 | bypass 耐性 | 権威 |
|----|------|--------|------|-------------|------|
| **Layer0** | `scripts/figma_fresh_fetch_guard.sh` (Claude Code PreToolUse フック) | 管理リポジトリ | Claude Code セッションのみ・`gh pr create/new` のみ傍受 | Claude 設定外では無効 | 補助（早期 UX ゲート） |
| **Layer1** | `.githooks/pre-push` (git フック) | **対象リポジトリ** | `git push` 実行時・全エージェント | `--no-verify` で迂回可 | 補助（ローカル preflight） |
| **Layer2** | `assign_to_copilot.sh::check_figma_gate` | 管理リポジトリ | Copilot 委譲経路のみ | 委譲を通らない経路は対象外 | 補助（委譲元担保） |
| **Layer3** | `.github/workflows/figma-evidence-guard.yml` (CI GitHub Actions) | **対象リポジトリ** | PR / push 時・全エージェント・全経路 | **un-bypassable（`--no-verify` 無効）** | **★最終権威★** |

> **最重要**: Layer3 CI が唯一の非依存・un-bypassable な関所。  
> Layer0/1/2 は早期警告・多重防御であり、CI が backstop として必ず捕捉する。

### Layer0 — Claude Code PreToolUse フック（早期 UX ゲート）

- ファイル: `scripts/figma_fresh_fetch_guard.sh`
- トリガー: `gh pr create` または `gh pr new` コマンドを Bash ツールで実行した瞬間
- 動作: `logs/figma_fetch_evidence.log` の 48 時間以内エントリを確認し、なければ PR 作成をブロックして取得手順を案内する
- 限界: Claude Code セッション外（Copilot --yolo / Codex / 手動の git push）は非経由のため素通り

### Layer1 — リポジトリ常駐 pre-push フック

- ファイル: 対象リポジトリの `.githooks/pre-push`
- 判定関数: `is_definitely_figma_ui`（positive-only 方式 — 後述）
- 動作: `git push` 直前にプッシュ差分を走査し、**UI ファイル**（blade テンプレート / CSS / SCSS / Tailwind / フロントエンド JS・TS・Vue / 公開 CSS・JS）が含まれる場合のみ、48 時間以内の証跡がなければ exit 1 でブロック。infra / backend / test / doc / config / ガード自身（.githooks / lib / .github / scripts 等）のみの push は EXEMPT（証跡不問・素通り）
- 有効化: `git config core.hooksPath .githooks` をクローン後に設定（bootstrap / セットアップスクリプトに組み込む）
- 限界: `git push --no-verify` で迂回可。Layer3 CI がこれを backstop として検知する

### Layer2 — Copilot 委譲元ゲート

- ファイル: 管理リポジトリの `scripts/assign_to_copilot.sh`（`check_figma_gate` 関数）
- 判定関数: `is_definitely_figma_ui`（positive-only 方式 — 後述）
- 動作: Copilot へのタスク委譲時に、対象パスが確実に Figma 管轄 UI である場合のみゲートを発火し、48 時間以内の証跡がなければ委譲をブロック。正典 node ID と URL をタスク YAML に埋め込む
- 限界: Copilot の委譲経路のみ。Claude 直接 / Codex / 手動は対象外

### Layer3 — CI GitHub Actions（最終権威）

- ファイル: 対象リポジトリの `.github/workflows/figma-evidence-guard.yml`
- 判定関数: `is_definitely_figma_ui`（positive-only 方式）
- 動作: PR ごとに差分を走査し、**UI ファイル**（blade / CSS / Tailwind / フロントエンド JS・TS・Vue 等）が含まれる場合のみ、リポジトリにコミット済みの証跡ファイルで 48 時間以内の取得を確認する。証跡なし / 期限切れの場合は CI を fail させマージをブロック。infra / backend / test / doc / config / ガード自身（.github / .githooks / lib / scripts / *.md / *.yml 等）のみの PR は EXEMPT（スキップ・pass）
- bypass 耐性: `--no-verify` は git フックをスキップするが CI には無効。`.figma-guard-bypass` ファイルも CI は参照しない（常に検証）

---

## 2. 判定基準の一元化

判定ロジックは `lib/figma_guard_common.sh` に集約し、各層が source して共用する。  
対象リポジトリでは `vendor` コピーとして配置する（同一ロジックを保証し矛盾を排除）。

### 2-1. 関数と使用層

| 関数 | 不明パスの扱い | 使用層 | 理由 |
|------|--------------|--------|------|
| `is_definitely_figma_ui` | **1（pass）** — positive-only | Layer1（pre-push）、Layer2（assigner ゲート）、Layer3（CI） | UI allowlist 一致のみ発火（positive-only）。非 UI（infra / backend / test / doc / config / ガード自身）は EXEMPT。H7 校正で L1・L3 も positive-only へ切替済（自己ブロック防止・精密化） |
| `is_figma_relevant_path` | **0（証跡要求）** — false-negative-safe | **現在 L1・L3 未使用**（H7 以降）— lib に定義は残置 | H7 校正前まで L1・L3 担当。不明パスも証跡要求（false-negative-safe）のため、UI以外のPRも引っ掛かる副作用があった |

> **H7 校正トレードオフ（A707h7-1）**: L1・L3 の positive-only 化により、allowlist に未登録のノベル UI（例: 将来の新フロントエンドフレームワーク）は EXEMPT となる（false-negative リスク）。UI 技術が進化した際は allowlist（`is_definitely_figma_ui` 内）の保守が必要。

### 2-2. Figma 管轄ファイル — allowlist と denylist

**証跡が必要（allowlist）**:

| パターン | 説明 |
|---------|------|
| `resources/views/**/*.blade.php` / `*.blade.php` | Blade テンプレート（UI） |
| `*.css` / `*.scss` / `*.sass` | スタイルシート |
| `tailwind.config.*` | Tailwind 設定 |
| `resources/js/**` / `resources/ts/**` / `resources/vue/**` | フロントエンド JS/TS/Vue |
| `public/**/*.css` / `public/**/*.js` | 公開済み静的ファイル |

**対象外（denylist、証跡不要）**:

| パターン | 説明 |
|---------|------|
| `app/**` | バックエンドロジック |
| `database/migrations/**` | DB マイグレーション |
| `tests/**` | テストコード |
| `routes/**` | ルーティング定義 |
| `config/**` | アプリ設定 |

> **不明パス**: `is_figma_relevant_path` では証跡要求側（0）に倒す（false-negative-safe）。  
> `is_definitely_figma_ui` では pass（1）に倒す（positive-only）。

---

## 3. bypass 運用規律

### git push --no-verify

Layer1（pre-push フック）をスキップするが、Layer3（CI）は必ず発火する。  
`--no-verify` を使用しても PR のマージは CI に阻まれる。  
緊急時に使用した場合は、その旨をダッシュボードの記録欄に残すこと。

### .figma-guard-bypass ファイル（緊急 skip）

- 対象: Layer0（Claude Code PreToolUse フック）のみ有効
- 用途: 殿（プロジェクト責任者）が承認した緊急 skip
- 使用時の義務:
  1. `stderr` およびログに bypass 理由を記録する（`figma_fresh_fetch_guard.sh` が自動出力）
  2. ダッシュボードへ bypass 使用を記録する
- **Layer3 CI は `.figma-guard-bypass` を参照しない。CI は常に証跡を検証する。**

### bypass サマリー

| 手段 | Layer0 | Layer1 | Layer2 | Layer3 |
|------|--------|--------|--------|--------|
| `--no-verify` | 無関係 | スキップ可 | 無関係 | **無効（CI は常に検証）** |
| `.figma-guard-bypass` | スキップ可 | 無関係 | 無関係 | **無効（CI は常に検証）** |
| Layer2 外経路（直接 push 等） | — | Layer1 で検知 | 素通り | **Layer3 で捕捉** |

---

## 4. 証跡フォーマットと取得手順

### 4-1. 証跡ソース（2 系統・OR 判定）

`has_fresh_evidence` は以下の 2 ソースを OR 評価する。どちらかに新鮮な証跡があれば通過。

| ソース | パス | 用途 | gitignore |
|--------|------|------|-----------|
| **ログファイル** | `logs/figma_fetch_evidence.log` | ローカル / pre-push | ✅ gitignore 対象（CI では不可用） |
| **per-PR ファイル（.md）** | `docs/figma-evidence/*.md` | PR ブランチにコミット | ❌ gitignore 対象外（★CI で可用★） |
| **per-PR ファイル（.json）** | `docs/figma-evidence/*.json` | cmd_715 figma_node_verification 連携 | ❌ gitignore 対象外（★CI で可用★） |

> **CI（Layer3）では `logs/` は gitignore により不在**のため、per-PR ファイルが必須。  
> pre-push（Layer1）やローカル（Layer0）はログのみでも動作する（後方互換）。

### 4-2. フォーマット

#### ログファイル形式（後方互換）

```
<ISO8601>  node:<node_id>  by:<agent_id>  [説明]
```

#### ログファイル形式（拡張）

```
<ISO8601>  node:<node_id>  url:<figma_url>  scope:<file_paths>  by:<agent_id>  [説明]
```

#### per-PR ファイル — 機械解析可能ブロック（★CI 走査対象★）

`docs/figma-evidence/*.md` に以下ブロックを含める。1 ファイルに複数ブロック可（cluster 複数 node）。

```markdown
<!-- figma-evidence-block (machine-parseable・guard走査対象) -->
node: 4560:47251
file: src/resources/views/admin/facecheck/index.blade.php
fetched: 2026-06-05T11:33:13+09:00
url: https://www.figma.com/design/xDQ4U6O2LUfIrftJGzacqm/?node-id=4560-47251&m=dev
<!-- /figma-evidence-block -->
```

必須フィールド: `node` / `fetched`（ISO8601）。`file` / `url` は省略可だが記載を推奨。

#### per-PR ファイル — JSON 形式（cmd_715 figma_node_verification 連携）

`docs/figma-evidence/*.json` に以下形式で記録（配列または単一オブジェクト）。

```json
[
  {
    "node": "4560:47251",
    "file": "resources/views/admin/facecheck/index.blade.php",
    "fetched": "2026-06-05T11:33:13+09:00",
    "url": "https://www.figma.com/design/xDQ4U6O2LUfIrftJGzacqm/?node-id=4560-47251&m=dev"
  }
]
```

`node` / `fetched` 必須。`node_id` / `fetched_at` も代替キーとして受理。

### 4-3. 証跡記録手順

Figma ノードを取得した直後に以下を実行する:

```bash
# 基本（後方互換 — ローカル/pre-push のみ有効、CI では機能しない）
bash scripts/figma_fetch_record.sh "<node_id>" "<説明>"

# 推奨 .md（per-PR Markdown ブロック — CI で有効）
bash scripts/figma_fetch_record.sh "<node_id>" "<説明>" \
  --url "https://www.figma.com/design/xDQ4U6O2LUfIrftJGzacqm/?node-id=<node>&m=dev" \
  --file "resources/views/admin/index.blade.php" \
  --pr-file

# 推奨 .json（per-PR JSON 形式 — cmd_715 figma_node_verification 連携）
bash scripts/figma_fetch_record.sh "<node_id>" "<説明>" \
  --url "https://www.figma.com/design/xDQ4U6O2LUfIrftJGzacqm/?node-id=<node>&m=dev" \
  --file "resources/views/admin/index.blade.php" \
  --pr-file-json

# --pr-file / --pr-file-json はログへの追記も行う（両建て・後方互換維持）
# 生成ファイルをコミット
git add docs/figma-evidence/<生成file>.{md,json} && git commit -m "chore(figma-evidence): add fetch evidence"
```

`--pr-file` は `docs/figma-evidence/<branch>_<node>.md`、`--pr-file-json` は `<branch>_<node>.json` を生成。  
ブランチ固有のファイルとなるため**並行ブランチ間の証跡衝突が解消**される。  
`.md` / `.json` どちらも `has_fresh_evidence` で受理される（OR 判定）。

### 4-4. 48 時間ウィンドウ

証跡の有効期限は `fetched` フィールドの時刻から 48 時間。期限切れの場合は Figma を再取得して証跡を更新する。

### 4-5. 現在の限界（honest）

プッシュ差分にはノードメタデータが含まれない。  
「48 時間以内の取得証跡の存在」が現時点での現実的な近似であり、  
**ファイル単位 × ノード単位の完全相関は将来課題**として扱う（過剰な約束はしない）。

---

## 5. 正典 Figma マップ（canonical-map）への参照

実装着手前・証跡記録時は必ず `context/figma-canonical-map.md` を参照し、  
正典ファイルキーと代表ノード ID を確認すること。

- **管理画面 / 予約管理系**: ファイルキー `xDQ4U6O2LUfIrftJGzacqm`、代表ノード `209:23439`
- **タブレット系**: ファイルキー `xDQ4U6O2LUfIrftJGzacqm`、代表ノードシリーズ `4560:89033`（2026-06-03 裁定で旧ファイルから切替済）

指示文や実装コード内にファイルキーを直書きせず、常にこのマップを経由すること（系統別に可変のため）。

---

## 6. 既存 figma-fresh-fetch-guard との関係

`scripts/figma_fresh_fetch_guard.sh` は **Layer0 として引き続き残置**する（撤去しない）。

- 役割: Claude Code セッション内での `gh pr create` 時の早期 UX ゲート。  
  PR 作成前に証跡不足を即時指摘し、開発者が手戻りなく対処できるよう補助する
- 権威: 補助（早期警告）。**最終権威は Layer3 CI**
- 二重発火について: Layer0 と Layer3 の両方が発火しても矛盾でなく多層防御の設計通り。  
  各層は「自層で検知した」旨を明示し、CI が最終権威である旨をメッセージに含める

---

## 7. 設置先リポジトリと責任範囲

| 層 | 設置先 | 設置責任 |
|----|--------|---------|
| Layer0 | 管理リポジトリ（本リポジトリ） | 管理リポジトリ担当者 |
| Layer1 | **対象リポジトリ**（Figma 管轄 UI を含む全リポジトリ） | 対象リポジトリ担当者・bootstrap 設定含む |
| Layer2 | 管理リポジトリ（本リポジトリ） | 管理リポジトリ担当者 |
| Layer3 | **対象リポジトリ**（Figma 管轄 UI を含む全リポジトリ） | 対象リポジトリ担当者 |

> Layer1（pre-push）は `git config core.hooksPath .githooks` をクローン後に設定する bootstrap が必要。  
> セットアップスクリプト / 出陣手順に組み込むこと。bootstrap なしのクローンでは Layer1 が無効になるが、  
> Layer3 CI が最終 backstop として機能する。

---

*実装との整合確認: Layer0 = `scripts/figma_fresh_fetch_guard.sh`、Layer2 = `scripts/assign_to_copilot.sh`、共有 lib = `lib/figma_guard_common.sh` の実コードを読んで記述。Layer1・Layer3 は対象リポジトリ常駐（本リポジトリ外）の PR#258 branch = feature/20260604_figma_evidence_guard に実装済（H7 校正 subtask_707_h7_guard_calibration 完了・2026-06-04）。判定関数は H7 以降 `is_definitely_figma_ui`（positive-only）。内部用語なし。捏造なし。*
