# Figma取得証跡 — cmd_716 整理券管理（抽選状況）系 顔写真チェック画面群

**取得日時**: 2026-06-05  
**取得担当**: ashigaru5  
**タスク**: subtask_716_facecheck_raffle_status_ledger  
**取得方法**: Figma REST API `/v1/files/{file_key}/nodes?ids=...&depth=N`  
**APIキー環境変数**: `FIGMA_API_KEY`  
**Figmaファイルキー**: `xDQ4U6O2LUfIrftJGzacqm`  
**正典セクション**: MCP用_管理者向け画面ページ section `4560:41601`（管理者向け管理画面 20260527）

---

## TVF 2段判定 結果

### Stage 1: Node系列確認

| Node ID | 系列 | 判定 |
|---------|------|------|
| `4560:47251` | `4560:` 系 | ✅ 現行正典 |
| `4560:46982` | `4560:` 系 | ✅ 現行正典 |
| `4560:48032` | `4560:` 系 | ✅ 現行正典 |

全ノード `4560:` 系 — 廃止系列 (`209:`, `1051:`, `62:`, `1063:`) ではない。**Stage 1 PASS**

### Stage 2: Node内容実在確認

#### Node 4560:47251 — `49_整理券管理_整理券管理詳細（抽選状況）_顔写真チェック`

- **タイプ**: FRAME
- **子要素数**: 3（PC Navbar, PC Sidebar, Container）
- **画面名確認**: "49_整理券管理_整理券管理詳細（抽選状況）_顔写真チェック" ✅
- **PageTitle テキスト**: "顔写真チェック（2026/04/20抽選分）" + Badge LotteryState ✅
- **Table columns** (text extracted):
  - 名前, ステータス, チェック結果, 再撮影要否, （詳細ボタン列）, （操作列）
- **Filter UI**: 名前入力フォーム, ホール選択フォーム, 絞り込みボタン
- **TabFilter**: すべて / 正常 / 要注意 / 警告（Buttonコンポーネント×4）
- **Pagination**: 実在確認
- **判定**: 当該機能（整理券コンテキスト_顔写真チェック一覧）が実在 ✅ **Stage 2 PASS**

#### Node 4560:46982 — `50_整理券管理_整理券管理詳細（抽選状況）_顔写真チェック_ユーザー詳細_編集`

- **タイプ**: FRAME
- **子要素数**: 3（PC Navbar, PC Sidebar, Container）
- **画面名確認**: "50_整理券管理_整理券管理詳細（抽選状況）_顔写真チェック_ユーザー詳細_編集" ✅
- **PageTitle テキスト**: "ユーザー詳細" + 戻るボタン ✅
- **ユーザー詳細フィールド** (text extracted):
  - 名前（鈴木 未来）, 店舗名（メガシティ小田原店）, 本番号（1）
  - チェック結果（警告）, 詳細（類似ユーザー2件検出/最大類似度：92.3%）
  - ステータス（通常ユーザー/タブレット受付）
  - 友達登録日（2026/01/20）, 最終抽選参加日（2026/05/20）
  - 再撮影要否（チェックボックス + 説明テキスト）
- **類似ユーザーリスト**: 「類似ユーザー（3件検出）」テーブル実在
  - 類似度 92.3% / 87.1% 等のサンプルデータ確認
- **判定**: 当該機能（整理券コンテキスト_ユーザー詳細_編集）が実在 ✅ **Stage 2 PASS**

#### Node 4560:48032 — `47_整理券管理（抽選状況）_ユーザー詳細モーダル`

- **タイプ**: FRAME
- **子要素数**: 2（背景Frame + Modal）
- **画面名確認**: "47_整理券管理（抽選状況）_ユーザー詳細モーダル" ✅
- **Modal構成**:
  - Modal header: "鈴木 未来" + 閉じるボタン
  - Modal body フィールド（text extracted）:
    - 本番号（1）, 受付日時（2026/04/20 11:40）
    - ステータス（通常ユーザー/タブレット受付）
    - ユーザーID（abcde12345）, LINE ID（abcde12345）
    - 友達登録日（2026/01/20）, 最終抽選参加日（2026/05/20）
    - 画像（登録済み）
  - Modal footer: 閉じるボタン
- **判定**: 当該機能（整理券_ユーザー詳細モーダル）が実在 ✅ **Stage 2 PASS**

---

## 周辺 cluster ノード確認

| Node ID | 画面名 | 確認状況 |
|---------|--------|---------|
| `4560:48530` | 46_整理券管理詳細（抽選状況）_顔写真ホバー時 | REST実取得 ✅ / PR #287 MERGED で被覆済 |
| `4560:49983` | 43_整理券管理詳細（抽選状況） MON main | REST実取得 ✅ / PR #278 in-flight |
| `4560:49375` | 44_実施済みの特定予約 | canonical-map記録済 / PR #278 対象 |
| `4560:48993` | 45_未実施の特定予約 | canonical-map記録済 / PR #278 対象 |
| `4560:47543` | 48_本番号画像 | canonical-map記録済 |

---

## raw API呼び出し記録

```
GET https://api.figma.com/v1/files/xDQ4U6O2LUfIrftJGzacqm/nodes?ids=4560:47251,4560:46982,4560:48032&depth=3
GET https://api.figma.com/v1/files/xDQ4U6O2LUfIrftJGzacqm/nodes?ids=4560:47251&depth=5
GET https://api.figma.com/v1/files/xDQ4U6O2LUfIrftJGzacqm/nodes?ids=4560:46982&depth=5
GET https://api.figma.com/v1/files/xDQ4U6O2LUfIrftJGzacqm/nodes?ids=4560:48032&depth=5
GET https://api.figma.com/v1/files/xDQ4U6O2LUfIrftJGzacqm/nodes?ids=4560:47251&depth=8 (text抽出用)
GET https://api.figma.com/v1/files/xDQ4U6O2LUfIrftJGzacqm/nodes?ids=4560:46982&depth=10 (text抽出用)
GET https://api.figma.com/v1/files/xDQ4U6O2LUfIrftJGzacqm/nodes?ids=4560:48032&depth=10 (text抽出用)
GET https://api.figma.com/v1/files/xDQ4U6O2LUfIrftJGzacqm/nodes?ids=4560:48530,4560:49983&depth=4
```

全レスポンス: HTTP 200, nodes オブジェクトに全対象ノード実在を確認。

---

*48h以内REST実取得証跡 — F005相当捏造禁止遵守*
