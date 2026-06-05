# cmd_716 Phase1 差分台帳: 整理券管理（抽選状況）系 顔写真チェック画面群

**作成**: 2026-06-05 / 担当: ashigaru5  
**タスク**: subtask_716_facecheck_raffle_status_ledger  
**Figmaファイル**: `xDQ4U6O2LUfIrftJGzacqm`  
**証跡ファイル**: `docs/figma-evidence/cmd716_facecheck_raffle_status_node4560_47251_46982_48032.md`

---

## ★ cmd_713 vs cmd_716 区別（重要）

| 区分 | コンテキスト | Figma cluster | Controller | Route |
|------|------------|---------------|-----------|-------|
| **cmd_713** | LINEユーザー管理_顔写真チェック | `4560:57288` / `4560:55842` | `FaceSimilarityResultController` | `/face-check/` |
| **cmd_716** | 整理券管理（抽選状況）_顔写真チェック | `4560:47251` / `4560:46982` / `4560:48032` | `RaffleController@faceCheck` | `/raffles/{id}/face-check` |

**共通コンポーネント（重複回避対象）**:
- `resources/views/components/ui/face-thumbnail.blade.php` — 顔写真サムネイル（両context共通）
- `resources/views/partials/face-thumbnail-hover-js.blade.php` — ホバープレビューJS（共通）
- ステータスバッジ表示 (user.status: normal/caution/blacklist/withdrawn/unfollowed)
- 再撮影要否フラグ (users.face_rejected_flg)

**cmd_716固有（cmd_713には存在しない）**:
- 本番号 (raffle_result_entries.pre_number / number)
- 受付日時 (raffle_result_entries.created_at)
- 整理券コンテキスト (raffle_result特定のデータフィルタ)

---

## TVF確認（48h証跡）

| 項目 | 内容 |
|------|------|
| 取得日時 | 2026-06-05（REST API直接実取得・本日） |
| 取得方法 | Figma REST API `/v1/files/{key}/nodes?ids=...&depth=N` |
| 証跡ファイル | `docs/figma-evidence/cmd716_facecheck_raffle_status_node4560_47251_46982_48032.md` |
| Stage 1 | 全ノード `4560:` 系 ✅ |
| Stage 2 | 全ノードの機能実在確認（画面名・テキスト・フィールド抽出）✅ |

---

## Cluster 対象ノード一覧（3画面+周辺）差分台帳

### 主要3ノード

| # | 画面名 | Node ID | Figma URL | 実装状況 | 実装先（develop） | in-flight PR | GAP |
|---|--------|---------|-----------|---------|-----------------|-------------|-----|
| 49 | 顔写真チェック一覧（整理券context） | `4560:47251` | [dev](https://www.figma.com/design/xDQ4U6O2LUfIrftJGzacqm/?node-id=4560:47251&m=dev) | ⚠️ **部分実装** | `RaffleController@faceCheck` → `face-similarity-results.raffle-context` | — | **GAP-1: カラム構造・データソース乖離（要再設計）** |
| 50 | 顔写真チェック_ユーザー詳細_編集（整理券context） | `4560:46982` | [dev](https://www.figma.com/design/xDQ4U6O2LUfIrftJGzacqm/?node-id=4560:46982&m=dev) | ❌ **未実装** | ルートなし（`face-check.show`はLINEユーザー管理context） | — | **GAP-2: 整理券context専用ルート・ビュー未作成** |
| 47 | ユーザー詳細モーダル（抽選状況内） | `4560:48032` | [dev](https://www.figma.com/design/xDQ4U6O2LUfIrftJGzacqm/?node-id=4560:48032&m=dev) | ⚠️ **部分実装** | `raffles/show.blade.php` L511 `#user-detail-modal` | PR #278 in-flight | **GAP-3: 本番号・受付日時・最終抽選参加日 フィールド欠如** |

### 周辺clusterノード

| # | 画面名 | Node ID | 状況 |
|---|--------|---------|------|
| 46 | 顔写真ホバー時（抽選状況画面） | `4560:48530` | ✅ PR #287 MERGED（face-thumbnail hover実装済み） |
| 43 | 整理券管理詳細（抽選状況） MON main | `4560:49983` | ⏳ PR #278 in-flight |
| 44 | 実施済みの特定予約 | `4560:49375` | ⏳ PR #278 in-flight |
| 45 | 未実施の特定予約 | `4560:48993` | ⏳ PR #278 in-flight |
| 48 | 本番号画像 | `4560:47543` | canonical-map記録済（要実装確認） |

---

## GAP詳細分析

### GAP-1: 顔写真チェック一覧（4560:47251）— カラム構造・データソース乖離

**現在の実装**（`face-similarity-results/raffle-context.blade.php`）:
- データソース: `face_similarity_results` テーブル（Raffle参加者でフィルタ）
- カラム: ID, 対象ユーザー, 類似ユーザー, 類似度, 管理者判断, チェック日時, 操作
- ページタイトル: "顔写真チェック" + "整理券 #ID（YYYY/MM/DD）の参加者に関連するチェック結果"

**Figma正典**（4560:47251）:
- データソース: `raffle_result_entries` × `users`（参加者ごとのステータス集計）
- カラム: 名前, ステータス, チェック結果, 再撮影要否, 詳細, 操作
- ページタイトル: "顔写真チェック（2026/04/20抽選分）" + Badge LotteryState
- フィルター: 名前検索フォーム + ホール選択フォーム + 絞り込みボタン
- タブフィルター: すべて / 正常 / 要注意 / 警告（Buttonバッジ×4）
- Pagination

**根本的な設計差異**:
- 現行: face_similarity_results（類似ペア単位） → 1ユーザーが複数行になりえる
- Figma: raffle_result_entries（参加者単位）× face_check集計 → 1ユーザー1行
- `users.face_check_status`: 'unchecked'/'processing'/'checked'/'invalid'
- `users.face_rejected_flg`: boolean（再撮影要否）
- Figmaの「チェック結果 (正常/要注意/警告)」= face_check_statusまたはface_similarity_resultsの最大類似度ベース判定と推定

### GAP-2: ユーザー詳細_編集（4560:46982）— 専用ルート・ビュー未作成

**現在の実装**: なし
- `raffle-context.blade.php`の「詳細」リンクは `route('face-check.show', $result)` → LINEユーザー管理contextの`show.blade.php`へ遷移
- LINEユーザー管理contextの`show.blade.php`は**整理券固有フィールドを持たない**

**Figma正典**（4560:46982）必須フィールド:
- 基本情報: 名前, 店舗名, 本番号, チェック結果, 詳細（類似検出数/最大類似度）, ステータス
- ユーザー属性: 友達登録日, 最終抽選参加日
- アクション: 再撮影要否チェックボックス + 説明テキスト（LIFF上の再撮影導線制御）
- 類似ユーザーリスト（3件例）: 類似度, 名前, チェック結果, ステータス, 友達登録日, 最終抽選参加日, 再撮影要否

**cmd_713との共通部分**（重複排除候補）:
- 再撮影要否チェックボックス → `users.face-rejected` route (`PATCH /users/{user}/face-rejected`)（cmd_713実装済み）
- ステータスバッジ表示 → 共通コンポーネント化推奨
- 顔写真表示 → `x-ui.face-thumbnail`（共通）

### GAP-3: ユーザー詳細モーダル（4560:48032）— フィールド欠如

**現在の実装**（`raffles/show.blade.php` L511 `#user-detail-modal`）:
- 実装フィールド: user_id, LINE ID, 友達登録日, LINE status, user status, thumbnail画像

**Figma正典**（4560:48032）フィールド:
- ✅ 実装済: ユーザーID, LINE ID, 友達登録日, ステータス, 画像
- ❌ **欠如**: **本番号** (`raffle_result_entries.pre_number`)
- ❌ **欠如**: **受付日時** (`raffle_result_entries.created_at`)
- ❌ **欠如**: **最終抽選参加日** (`users.last_raffle_participated_at` または集計値)
- **注**: PR #278 in-flight（B-MON-001/002/004）がモーダルに関連する可能性あり — 被覆状況はPR #278 merge後に再確認要

---

## Backlogチケット化（担当=斎藤・要発注者起票）

> **Backlog API不可のため、起票用チケット内容を記載（要発注者起票）**

---

### B-FACE-RAFFLE-001: 整理券管理_顔写真チェック一覧 Figma正典準拠再設計

| 項目 | 内容 |
|------|------|
| タイトル | 整理券管理（抽選状況）_顔写真チェック一覧をFigma正典に合わせて再設計 |
| 担当 | 斎藤 |
| Figma Node | `4560:47251` |
| Figma URL | https://www.figma.com/design/xDQ4U6O2LUfIrftJGzacqm/?node-id=4560:47251&m=dev |
| 概要 | `face-similarity-results/raffle-context.blade.php` をFigma正典に合わせて再設計。データソースを `face_similarity_results` 絞り込みから `raffle_result_entries × users` 参加者ビューに変更。カラム構成（名前/ステータス/チェック結果/再撮影要否/詳細/操作）・フィルターUI（名前検索/ホール選択）・タブバッジフィルター（すべて/正常/要注意/警告）・Paginationを実装 |
| 関連 | cmd_716 GAP-1 / 既存ルート `GET /raffles/{raffle}/face-check` 維持 |

---

### B-FACE-RAFFLE-002: 整理券管理_顔写真チェック_ユーザー詳細_編集 新規実装

| 項目 | 内容 |
|------|------|
| タイトル | 整理券管理（抽選状況）_顔写真チェック_ユーザー詳細_編集 専用画面の新規実装 |
| 担当 | 斎藤 |
| Figma Node | `4560:46982` |
| Figma URL | https://www.figma.com/design/xDQ4U6O2LUfIrftJGzacqm/?node-id=4560:46982&m=dev |
| 概要 | 整理券コンテキスト専用のユーザー詳細_編集ビューを新規作成。新ルート `GET /raffles/{raffle}/face-check/{entry}` 追加。表示フィールド: 名前/店舗名/本番号/チェック結果/詳細/ステータス/友達登録日/最終抽選参加日/再撮影要否チェックボックス+説明テキスト。類似ユーザーリスト（類似度/名前/チェック結果/ステータス等）。再撮影要否更新は既存 `PATCH /users/{user}/face-rejected` ルートを再利用（cmd_713実装済みとの共通化）。顔写真表示は `x-ui.face-thumbnail` コンポーネント共通使用 |
| 関連 | cmd_716 GAP-2 / cmd_713との重複排除（再撮影要否action・thumbnailコンポーネント共有） |

---

### B-FACE-RAFFLE-003: 整理券管理_ユーザー詳細モーダル フィールド追加

| 項目 | 内容 |
|------|------|
| タイトル | 整理券管理（抽選状況）_ユーザー詳細モーダルに本番号・受付日時・最終抽選参加日を追加 |
| 担当 | 斎藤 |
| Figma Node | `4560:48032` |
| Figma URL | https://www.figma.com/design/xDQ4U6O2LUfIrftJGzacqm/?node-id=4560:48032&m=dev |
| 概要 | `raffles/show.blade.php` L511 `#user-detail-modal` に不足フィールドを追加。追加: 本番号（`raffle_result_entries.pre_number`）/ 受付日時（`raffle_result_entries.created_at`）/ 最終抽選参加日。テーブル行に `data-pre-number`・`data-entry-at` 属性を追加しJSでモーダルへ渡す。PR #278 merge状況次第で被覆可能性を再確認のこと |
| 関連 | cmd_716 GAP-3 / PR #278 B-MON-001/002/004 との重複確認要 |

---

## 実装振り分け案

| チケット | 振り分け | 理由 |
|---------|--------|------|
| B-FACE-RAFFLE-001 | **Claude必須（Figma忠実性核）** | データモデル変更（face_similarity_results→entries×users集計）+フィルターUI再設計を伴う。Copilot不可 |
| B-FACE-RAFFLE-002 | **Claude必須（Figma忠実性核）** | 新規ルート・新規ビュー作成＋cmd_713コンポーネント再利用設計要。Copilot不可 |
| B-FACE-RAFFLE-003 | **Copilot可（48h証跡ガード+Claude照合）** | 既存モーダルへのフィールド追加のみ。PR #278 merge後CI実測・Claude忠実性照合必須 |

---

## in-flight重複確認（排除済み）

| PR | タイトル | 重複対象 | 判定 |
|----|---------|---------|------|
| PR #287 | face-thumbnail hover (MERGED) | 4560:48530 cluster | ✅ 被覆済（重複なし） |
| PR #289 | ユーザー詳細UI改善（OPEN） | users/show.blade.php, face-similarity-results/show.blade.php | ⚠️ cmd_713 context（4560:55842系）→ cmd_716 GAP-2とは別 |
| PR #278 | B-MON-001/002/004 monitoring (OPEN) | 4560:49983/49375 cluster | ⚠️ モーダル関連更新あり可能性→merge後GAP-3再確認要 |
| cmd_713 | LINEユーザー管理_顔写真チェック | 4560:57288/55842 cluster | ✅ 別context（共通コンポーネントのみ重複回避） |

---

## purpose_gap

```yaml
purpose_gap:
  detected: false
  description: ""
  action_taken: "該当なし"
```

差分台帳作成の目的（整理券管理系_顔写真チェック画面群のTVF確認+チケット化）と実態（REST実取得+2段判定+gap分析+チケット化）に乖離なし。なお、既存 `raffle-context.blade.php` がFigmaと根本的にデータソース・カラム構成が異なる点を発見（GAP-1）したが、これは実装の課題であり指示の前提崩れではないため purpose_gap=false とする。

---

*Phase1=read-only台帳+チケット化のみ実施。実装本体は次wave。*
