# Figma Canonical Map

This document is the authoritative reference for Figma canonical sources by system type.
Before implementing any UI or creating a new ticket, look up this map to identify the correct
Figma file key and representative node. If this map conflicts with task instructions or cached
information from prior sessions, this map takes precedence.

**Rule**: The canonical Figma file varies by system type. Do not hardcode a single file key
as the universal canonical source. Always look up this map for the target system.

---

## Canonical Sources by System

### Admin Management System / Reservation Management

| Field | Value |
|-------|-------|
| Figma File Key | `xDQ4U6O2LUfIrftJGzacqm` |
| Representative Nodes | `209:23439` (Ticket Management / Calendar), `1051:22288` (Raffle Status Detail) |
| Status | **Active — current canonical source** |
| Figma URL pattern | `https://www.figma.com/design/xDQ4U6O2LUfIrftJGzacqm/?node-id=<node>&m=dev` |

Use this file for all admin panel screens, including reservation management, hall settings,
user management, and related admin UI.

---

### Tablet System

| Field | Value |
|-------|-------|
| Figma File Key | `xDQ4U6O2LUfIrftJGzacqm` |
| Representative Node Series | `4560:89033` series |
| Status | **Active — switched from previous file per 2026-06-03 ruling** |
| Previous File | `z7UqrdIxvZU2aH0ahYiEXo` (deprecated — history reference only) |

The previous file (`z7Uq...`) is no longer the canonical source for tablet screens.
Do not use `z7Uq...` for new implementations. Any implementation based on `z7Uq...` is
considered outdated and subject to correction.

**Operational model (confirmed by client 2026-06-04)**:
- Tablet is for in-store guests who cannot use LINE; device is set up and managed by store staff
- Guest takes photo → entry username is uniformly **「タブレット受付」** (no LINE user matching of any kind)
- No consent flow required; (a)(b)(c) identification method is **not applicable**
- Face photo duplication check is optional — records to `face_similarity_results`; same retention policy as LINE guests (no new retention/encryption/access-control design needed)
- Temp number ticket issued at entry; staff verbally matches at raffle results and hands over actual number ticket (analog operation — no system automation)
- ✕ Rekognition-based identity verification is **not used** here; face comparison is for duplication detection only (optional)

---

### Admin User Management — User Detail / Edit Screen

| Field | Value |
|-------|-------|
| Figma File Key | `xDQ4U6O2LUfIrftJGzacqm` |
| Representative Node | `4560:55306` |
| Status | **Active — exists under admin user management menu** |
| Figma URL | `https://www.figma.com/design/xDQ4U6O2LUfIrftJGzacqm/?node-id=4560:55306&m=dev` |

This screen exists as part of the admin user management menu hierarchy (利用者管理 → 利用者詳細・編集).
⚠️ **Do NOT confuse** with the deprecated standalone `/users/{id}` page (USER-10) below — they are distinct screens.

---

### Standalone User Detail Page `/users/{id}` — DEPRECATED

⚠️ **Confusion risk**: This is NOT the same as the active **Admin User Management → User Detail/Edit Screen** (node `4560:55306`) listed above.

| Field | Value |
|-------|-------|
| Figma File Key | — |
| Status | **Does not exist — deprecated (Backlog: USER-10)** |

This standalone page was removed from scope entirely.
Any pull request that implements a standalone `/users/{id}` page is based on a deprecated design and should
be closed without merging. The admin user management detail/edit screen (`4560:55306`) remains active and valid.

---

## Key Rules

### canonical_figma_base is system-variable, not a fixed value

Different systems use different Figma files. Never write a single file key in task
instructions, self-check items, or code as the universal "canonical" source.
Always reference this map and look up the correct file key for the specific system.

### When a system has no entry in this map

If the target screen or system is not listed here, do not assume a file key.
Stop and report the gap before implementing. Add a "要特定" (to be identified) note
to the ticket and request confirmation.

### How to add a new system

When a new system needs a canonical Figma source:

1. Confirm the Figma file key and representative node from the product owner
2. Add a new section following the format above, including:
   - File key
   - Representative node(s)
   - Status
   - URL pattern
   - Any notes about previous files or transitions
3. If there was a file switch from a previous canonical, record the ruling date and
   mark the previous file as deprecated

---

*This map is the single source of truth for Figma canonical references.
All instructions, self-check items, and ticket templates must reference this map
rather than hardcoding specific file keys.*

---

## 画面別 Node マップ（xDQ4U6O2LUfIrftJGzacqm）

**取得証跡**: 2026-06-05 — Figma REST API (`/v1/files/{file_key}?depth=1`, `/v1/files/{file_key}/nodes?ids=<id>&depth=N`)  
**正典セクション**: MCP用_管理者向け画面ページ section `4560:41601`（管理者向け管理画面 20260527）  
**正典タブレットセクション**: MCP用_タブレット画面ページ section `4560:89033`（20260527_タブレット画面）

---

### Wave2 優先: G-05〜08/G-11 参照画面（blocked_by 解除）

#### G-05: 予約 RSRV — 整理券管理（抽選予約）

整理券 section (`4560:43044`) 内・抽選予約部分。

| # | 画面名 | Node ID | Figma URL |
|---|--------|---------|-----------|
| 51 | 整理券管理（抽選予約）一覧 **★RSRV main★** | `4560:46699` | [dev](https://www.figma.com/design/xDQ4U6O2LUfIrftJGzacqm/?node-id=4560:46699&m=dev) |
| 52 | 整理券管理（抽選予約）編集 | `4560:46414` | [dev](https://www.figma.com/design/xDQ4U6O2LUfIrftJGzacqm/?node-id=4560:46414&m=dev) |
| 53 | 整理券管理（抽選予約）編集_日時入力イメージ | `4560:46115` | [dev](https://www.figma.com/design/xDQ4U6O2LUfIrftJGzacqm/?node-id=4560:46115&m=dev) |
| 54 | 整理券管理（抽選予約）編集_予約枠削除 | `4560:45820` | [dev](https://www.figma.com/design/xDQ4U6O2LUfIrftJGzacqm/?node-id=4560:45820&m=dev) |

#### G-06: 設定 SET — 整理券管理（基本設定・固定文言）

整理券 section (`4560:43044`) 内・基本設定部分。

| # | 画面名 | Node ID | Figma URL |
|---|--------|---------|-----------|
| 55 | 整理券管理（基本設定・固定文言）一覧 **★SET main★** | `4560:45626` | [dev](https://www.figma.com/design/xDQ4U6O2LUfIrftJGzacqm/?node-id=4560:45626&m=dev) |
| 56 | 整理券管理（基本設定・固定文言）編集 | `4560:45419` | [dev](https://www.figma.com/design/xDQ4U6O2LUfIrftJGzacqm/?node-id=4560:45419&m=dev) |
| 57 | 整理券管理（基本設定・固定文言）編集_ツールチップ | `4560:45209` | [dev](https://www.figma.com/design/xDQ4U6O2LUfIrftJGzacqm/?node-id=4560:45209&m=dev) |
| 58 | 整理券管理（基本設定・固定文言）編集_エラー | `4560:45001` | [dev](https://www.figma.com/design/xDQ4U6O2LUfIrftJGzacqm/?node-id=4560:45001&m=dev) |
| 59 | 整理券管理（基本設定・固定文言）編集_文字数オーバー | `4560:44793` | [dev](https://www.figma.com/design/xDQ4U6O2LUfIrftJGzacqm/?node-id=4560:44793&m=dev) |
| 60 | 整理券管理（基本設定・固定文言）編集_未保存確認モーダル | `4560:44576` | [dev](https://www.figma.com/design/xDQ4U6O2LUfIrftJGzacqm/?node-id=4560:44576&m=dev) |
| 61 | 整理券管理（基本設定・固定文言）編集_文字数オーバーで更新 | `4560:44359` | [dev](https://www.figma.com/design/xDQ4U6O2LUfIrftJGzacqm/?node-id=4560:44359&m=dev) |

#### G-07: 利用者 USER — LINEユーザー管理

ユーザー管理 section (`4560:55305`)。

| # | 画面名 | Node ID | Figma URL |
|---|--------|---------|-----------|
| 26 | LINEユーザー管理（一覧）**★USER main★** | `4560:59439` | [dev](https://www.figma.com/design/xDQ4U6O2LUfIrftJGzacqm/?node-id=4560:59439&m=dev) |
| 27 | LINEユーザー管理（検索フォーム絞り込み） | `4560:59185` | [dev](https://www.figma.com/design/xDQ4U6O2LUfIrftJGzacqm/?node-id=4560:59185&m=dev) |
| 28 | LINEユーザー管理（ステータス変更） | `4560:58925` | [dev](https://www.figma.com/design/xDQ4U6O2LUfIrftJGzacqm/?node-id=4560:58925&m=dev) |
| 29 | LINEユーザー管理_ステータス変更確認モーダル | `4560:58654` | [dev](https://www.figma.com/design/xDQ4U6O2LUfIrftJGzacqm/?node-id=4560:58654&m=dev) |
| 30 | LINEユーザー管理（一括操作） | `4560:58394` | [dev](https://www.figma.com/design/xDQ4U6O2LUfIrftJGzacqm/?node-id=4560:58394&m=dev) |
| 31 | LINEユーザー管理_一括操作確認モーダル | `4560:58124` | [dev](https://www.figma.com/design/xDQ4U6O2LUfIrftJGzacqm/?node-id=4560:58124&m=dev) |
| 32 | LINEユーザー管理（絞り込み） | `4560:57827` | [dev](https://www.figma.com/design/xDQ4U6O2LUfIrftJGzacqm/?node-id=4560:57827&m=dev) |
| 33 | LINEユーザー管理_登録画像確認 | `4560:57570` | [dev](https://www.figma.com/design/xDQ4U6O2LUfIrftJGzacqm/?node-id=4560:57570&m=dev) |
| 34 | LINEユーザー管理_顔写真チェック **★face-check main★** | `4560:57288` | [dev](https://www.figma.com/design/xDQ4U6O2LUfIrftJGzacqm/?node-id=4560:57288&m=dev) |
| 35 | LINEユーザー管理_顔写真チェック（顔写真マウスオーバー） | `4560:57004` | [dev](https://www.figma.com/design/xDQ4U6O2LUfIrftJGzacqm/?node-id=4560:57004&m=dev) |
| 36 | LINEユーザー管理_顔写真チェック（タグ押下後） | `4560:56715` | [dev](https://www.figma.com/design/xDQ4U6O2LUfIrftJGzacqm/?node-id=4560:56715&m=dev) |
| 37 | LINEユーザー管理_顔写真チェック（店舗選択） | `4560:56417` | [dev](https://www.figma.com/design/xDQ4U6O2LUfIrftJGzacqm/?node-id=4560:56417&m=dev) |
| 38 | LINEユーザー管理_顔写真チェック（絞り込み） | `4560:56104` | [dev](https://www.figma.com/design/xDQ4U6O2LUfIrftJGzacqm/?node-id=4560:56104&m=dev) |
| 39 | LINEユーザー管理_顔写真チェック_ユーザー詳細_編集 | `4560:55842` | [dev](https://www.figma.com/design/xDQ4U6O2LUfIrftJGzacqm/?node-id=4560:55842&m=dev) |
| 40 | LINEユーザー管理_顔写真チェック_ユーザー詳細_編集（不要チェック時） | `4560:55569` | [dev](https://www.figma.com/design/xDQ4U6O2LUfIrftJGzacqm/?node-id=4560:55569&m=dev) |
| 41 | LINEユーザー管理_顔写真チェック_ユーザー詳細_編集（トースト） | `4560:55306` | [dev](https://www.figma.com/design/xDQ4U6O2LUfIrftJGzacqm/?node-id=4560:55306&m=dev) ※既canonical-map掲載 |

#### G-08: カード / フレーム CARD — 整理券管理（抽選番号デザインフレーム）

整理券 section (`4560:43044`) 内・デザインフレーム部分。

| # | 画面名 | Node ID | Figma URL |
|---|--------|---------|-----------|
| 62 | 整理券管理（抽選番号デザインフレーム）一覧 **★CARD main★** | `4560:44204` | [dev](https://www.figma.com/design/xDQ4U6O2LUfIrftJGzacqm/?node-id=4560:44204&m=dev) |
| 63 | 整理券管理（抽選番号デザインフレーム）編集_ハズレ券を含めない場合 | `4560:44041` | [dev](https://www.figma.com/design/xDQ4U6O2LUfIrftJGzacqm/?node-id=4560:44041&m=dev) |
| 64 | 整理券管理（抽選番号デザインフレーム）編集_ハズレ券ヘルプアイコン押下時 | `4560:43867` | [dev](https://www.figma.com/design/xDQ4U6O2LUfIrftJGzacqm/?node-id=4560:43867&m=dev) |
| 65 | 整理券管理（抽選番号デザインフレーム）編集_ハズレ券（数字つき） | `4560:43701` | [dev](https://www.figma.com/design/xDQ4U6O2LUfIrftJGzacqm/?node-id=4560:43701&m=dev) |
| 66 | 整理券管理（抽選番号デザインフレーム）編集_ハズレ券（数字なし） | `4560:43534` | [dev](https://www.figma.com/design/xDQ4U6O2LUfIrftJGzacqm/?node-id=4560:43534&m=dev) |
| 67 | 整理券管理（抽選番号デザインフレーム）編集_オリジナルフレーム追加 | `4560:43480` | [dev](https://www.figma.com/design/xDQ4U6O2LUfIrftJGzacqm/?node-id=4560:43480&m=dev) |
| 68 | 整理券管理（抽選番号デザインフレーム）編集_オリジナルフレーム追加（3セット） | `4560:43342` | [dev](https://www.figma.com/design/xDQ4U6O2LUfIrftJGzacqm/?node-id=4560:43342&m=dev) |
| 69 | 整理券管理（抽選番号デザインフレーム）編集_オリジナルフレーム追加_エラー1 | `4560:43193` | [dev](https://www.figma.com/design/xDQ4U6O2LUfIrftJGzacqm/?node-id=4560:43193&m=dev) |
| 70 | 整理券管理（抽選番号デザインフレーム）編集_オリジナルフレーム追加_エラー2 | `4560:43045` | [dev](https://www.figma.com/design/xDQ4U6O2LUfIrftJGzacqm/?node-id=4560:43045&m=dev) |

#### G-11: タブレット残画面（TB-09〜24 / SP系）

MCP用_タブレット画面ページ section `4560:89033`（20260527）。TB-01〜08は実装済（cmd_682）。TB-15はin-flight #276。

| TB# | 画面名 | Node ID | 備考 |
|-----|--------|---------|------|
| TB-01 | ログイン | `4560:89034` | 実装済 |
| TB-02 | ログイン（入力イメージ） | `4560:89070` | 実装済 |
| TB-03 | ログイン（入力エラー） | `4560:89052` | 実装済 |
| TB-04 | トップ | `4560:89089` | 実装済 |
| TB-05 | 撮影 | `4560:89757` | 実装済 |
| TB-06 | 撮影後 | `4560:89768` | 実装済 |
| TB-07 | 写真登録中 | `4560:89661` | 実装済 |
| TB-08 | 抽選参加完了 | `4560:89632` | 実装済 |
| **TB-09** | **抽選受付時間外** | `4560:89732` | **G-11残・要実装確認** |
| **TB-10** | **本番号確認** | `4560:89125` | **G-11残・要実装確認** |
| **TB-11** | **本番号確認_本番号表示** | `4560:89594` | **G-11残** |
| **TB-12** | **本番号確認_本番号表示（再読み込み）** | `4560:89580` | **G-11残** |
| **TB-13** | **本番号確認_本番号表示（抽選時間前）** | `4560:89682` | **G-11残** |
| **TB-14** | **セッションの有効期限切れ** | `4560:89707` | **G-11残** |
| TB-15 | 緊急QR | in-flight #276 | cmd_682対応中・node未記録 |
| **TB-16** | **抽選受付状況** | `4560:92427` | **G-11残** |
| **TB-17** | **抽選受付状況（日付変更）** | `4560:93137` | **G-11残** |
| **TB-18** | **抽選受付状況（受付ツール絞り込み）** | `4560:92026` | **G-11残** |
| **TB-19** | **抽選受付状況（ステータス絞り込み）** | `4560:92211` | **G-11残** |
| **TB-20** | **抽選受付状況（顔写真拡大）** | `4560:89154` | **G-11残** |
| **TB-21** | **抽選受付状況（本番号表示）** | `4560:89366` | **G-11残** |
| **TB-22** | **抽選受付状況_顔写真チェック** | `4560:92612` | **G-11残** |
| **TB-23** | **抽選受付状況_顔写真チェック_ユーザー詳細_編集** | `4560:92874` | **G-11残** |
| **TB-24** | **ログアウト** | `4560:89102` | **G-11残** |

**SP系（スマートフォン向け — 同セクション 4560:89033内）**:

| SP# | 画面名 | Node ID |
|-----|--------|---------|
| SP-01 | ログイン | `4560:90193` |
| SP-02 | ログイン（入力イメージ） | `4560:90231` |
| SP-03 | ログイン（入力エラー） | `4560:90288` |
| SP-04 | トップ | `4560:89794` |
| SP-05 | 撮影 | `4560:90174` |
| SP-06 | 撮影後 | `4560:90185` |
| SP-07 | 写真登録中 | `4560:89912` |
| SP-08 | 抽選参加完了 | `4560:89952` |
| SP-09 | 抽選受付時間外 | `4560:90000` |
| SP-10 | 本番号確認 | `4560:89826` |
| SP-11 | 本番号確認_本番号表示 | `4560:89872` |
| SP-12 | 本番号確認_本番号表示（再読み込み） | `4560:89858` |
| SP-13 | 本番号確認_本番号表示（抽選時間前） | `4560:90044` |
| SP-14 | セッションの有効期限切れ | `4560:90130` |
| SP-16 | 抽選受付状況 | `4560:90326` |
| SP-17 | 抽選受付状況（日付変更） | `4560:91741` |
| SP-18 | 抽選受付状況（受付ツール絞り込み） | `4560:91340` |
| SP-19 | 抽選受付状況（受付ツール絞り込み / ドロップダウン） | `4560:91530` |
| SP-20 | 抽選受付状況（オーバーレイ） | `4560:90944` |
| SP-21 | 抽選受付状況（本番号表示） | `4560:91141` |
| SP-22 | 抽選受付状況_顔写真チェック | `4560:90516` |
| SP-23 | 抽選受付状況_顔写真チェック_ユーザー詳細_編集 | `4560:90682` |
| TB-24-SP | ログアウト（スマホ） | `4560:90088` |

---

### Admin 全画面マップ（MCP正典 4560:41601 / 20260527）

#### 整理券管理一覧・抽選状況・監視 MON

整理券 section (`4560:43044`) 内・抽選状況部分。B-MON-001/002/004 (#278 in-flight) が参照する画面群。

| # | 画面名 | Node ID | Figma URL |
|---|--------|---------|-----------|
| 42 | 整理券管理（一覧）**★整理券管理main・カレンダービュー含む★** | `4560:50444` | [dev](https://www.figma.com/design/xDQ4U6O2LUfIrftJGzacqm/?node-id=4560:50444&m=dev) |
| 43 | 整理券管理詳細（抽選状況）**★MON main★** | `4560:49983` | [dev](https://www.figma.com/design/xDQ4U6O2LUfIrftJGzacqm/?node-id=4560:49983&m=dev) |
| 44 | 整理券管理詳細（抽選状況）_実施済みの特定予約 | `4560:49375` | [dev](https://www.figma.com/design/xDQ4U6O2LUfIrftJGzacqm/?node-id=4560:49375&m=dev) |
| 45 | 整理券管理詳細（抽選状況）_未実施の特定予約 | `4560:48993` | [dev](https://www.figma.com/design/xDQ4U6O2LUfIrftJGzacqm/?node-id=4560:48993&m=dev) |
| 46 | 整理券管理詳細（抽選状況）_顔写真ホバー時 | `4560:48530` | [dev](https://www.figma.com/design/xDQ4U6O2LUfIrftJGzacqm/?node-id=4560:48530&m=dev) |
| 47 | 整理券管理（抽選状況）_ユーザー詳細モーダル | `4560:48032` | [dev](https://www.figma.com/design/xDQ4U6O2LUfIrftJGzacqm/?node-id=4560:48032&m=dev) |
| 48 | 整理券管理詳細（抽選状況）_本番号画像 | `4560:47543` | [dev](https://www.figma.com/design/xDQ4U6O2LUfIrftJGzacqm/?node-id=4560:47543&m=dev) |
| 49 | 整理券管理詳細（抽選状況）_顔写真チェック | `4560:47251` | [dev](https://www.figma.com/design/xDQ4U6O2LUfIrftJGzacqm/?node-id=4560:47251&m=dev) |
| 50 | 整理券管理詳細（抽選状況）_顔写真チェック_ユーザー詳細_編集 | `4560:46982` | [dev](https://www.figma.com/design/xDQ4U6O2LUfIrftJGzacqm/?node-id=4560:46982&m=dev) |

#### ホール管理 HALL（section `4560:61351`）

| # | 画面名 | Node ID | Figma URL |
|---|--------|---------|-----------|
| 09 | ホール管理（一覧）**★HALL main★** | `4560:64206` | [dev](https://www.figma.com/design/xDQ4U6O2LUfIrftJGzacqm/?node-id=4560:64206&m=dev) |
| 10 | ホール管理_ホール詳細 | `4560:63939` | [dev](https://www.figma.com/design/xDQ4U6O2LUfIrftJGzacqm/?node-id=4560:63939&m=dev) |
| 11 | ホール管理_ホール詳細-編集 | `4560:63938` | [dev](https://www.figma.com/design/xDQ4U6O2LUfIrftJGzacqm/?node-id=4560:63938&m=dev) |
| 12 | ホール管理_ホール詳細-編集_ツールチップ | `4560:63677` | [dev](https://www.figma.com/design/xDQ4U6O2LUfIrftJGzacqm/?node-id=4560:63677&m=dev) |
| 13 | ホール管理_ホール詳細-編集（整理券機能を無効にした場合） | `4560:63417` | [dev](https://www.figma.com/design/xDQ4U6O2LUfIrftJGzacqm/?node-id=4560:63417&m=dev) |
| 14 | ホール管理_ホール詳細-編集（カラー変更） | `4560:63125` | [dev](https://www.figma.com/design/xDQ4U6O2LUfIrftJGzacqm/?node-id=4560:63125&m=dev) |
| 15 | ホール管理_ホール詳細-編集_エラー | `4560:62857` | [dev](https://www.figma.com/design/xDQ4U6O2LUfIrftJGzacqm/?node-id=4560:62857&m=dev) |
| 16 | ホール管理_ホール詳細-編集_未保存確認モーダル | `4560:62845` | [dev](https://www.figma.com/design/xDQ4U6O2LUfIrftJGzacqm/?node-id=4560:62845&m=dev) |
| 17 | ホール管理_ホール詳細-編集_メールアドレス変更確認 | `4560:62833` | [dev](https://www.figma.com/design/xDQ4U6O2LUfIrftJGzacqm/?node-id=4560:62833&m=dev) |
| 18 | ホール管理_ホール詳細-編集_メールアドレス変更（認証メール送信） | `4560:62822` | [dev](https://www.figma.com/design/xDQ4U6O2LUfIrftJGzacqm/?node-id=4560:62822&m=dev) |
| 19 | ホール管理_ホール詳細-編集_パスワードリセット確認 | `4560:62810` | [dev](https://www.figma.com/design/xDQ4U6O2LUfIrftJGzacqm/?node-id=4560:62810&m=dev) |
| 20 | ホール管理_ホール詳細-編集_メールアドレス変更（メール未認証） | `4560:62536` | [dev](https://www.figma.com/design/xDQ4U6O2LUfIrftJGzacqm/?node-id=4560:62536&m=dev) |
| 21 | ホール管理_ホール詳細（メール未認証） | `4560:62266` | [dev](https://www.figma.com/design/xDQ4U6O2LUfIrftJGzacqm/?node-id=4560:62266&m=dev) |
| 22 | ホール管理_アカウント追加 | `4560:62047` | [dev](https://www.figma.com/design/xDQ4U6O2LUfIrftJGzacqm/?node-id=4560:62047&m=dev) |
| 23 | ホール管理_アカウント追加（入力エラー） | `4560:61828` | [dev](https://www.figma.com/design/xDQ4U6O2LUfIrftJGzacqm/?node-id=4560:61828&m=dev) |
| 24 | ホール管理_アカウント追加_認証メール送信 | `4560:61616` | [dev](https://www.figma.com/design/xDQ4U6O2LUfIrftJGzacqm/?node-id=4560:61616&m=dev) |
| 25 | ホール管理_アカウント追加完了 | `4560:61412` | [dev](https://www.figma.com/design/xDQ4U6O2LUfIrftJGzacqm/?node-id=4560:61412&m=dev) |

#### ログイン（section `4560:67509`）

| # | 画面名 | Node ID | Figma URL |
|---|--------|---------|-----------|
| 01 | ログイン | `4560:67631` | [dev](https://www.figma.com/design/xDQ4U6O2LUfIrftJGzacqm/?node-id=4560:67631&m=dev) |
| 02 | ログイン（入力中） | `4560:67608` | [dev](https://www.figma.com/design/xDQ4U6O2LUfIrftJGzacqm/?node-id=4560:67608&m=dev) |
| 03 | ログイン（入力エラー） | `4560:67585` | [dev](https://www.figma.com/design/xDQ4U6O2LUfIrftJGzacqm/?node-id=4560:67585&m=dev) |
| 04 | 初回ログイン | `4560:67567` | [dev](https://www.figma.com/design/xDQ4U6O2LUfIrftJGzacqm/?node-id=4560:67567&m=dev) |
| 05 | ログイン_パスワードリセット | `4560:67547` | [dev](https://www.figma.com/design/xDQ4U6O2LUfIrftJGzacqm/?node-id=4560:67547&m=dev) |
| 06 | ログイン_パスワードリセット（メール送信） | `4560:67537` | [dev](https://www.figma.com/design/xDQ4U6O2LUfIrftJGzacqm/?node-id=4560:67537&m=dev) |
| 07 | ログイン_パスワード再設定 | `4560:67519` | [dev](https://www.figma.com/design/xDQ4U6O2LUfIrftJGzacqm/?node-id=4560:67519&m=dev) |
| 08 | ログイン（パスワード再設定完了） | `4560:67510` | [dev](https://www.figma.com/design/xDQ4U6O2LUfIrftJGzacqm/?node-id=4560:67510&m=dev) |

#### 管理者アカウント管理（section `4560:41602`）

| # | 画面名 | Node ID | Figma URL |
|---|--------|---------|-----------|
| 71 | 管理者アカウント管理（一覧） | `4560:42862` | [dev](https://www.figma.com/design/xDQ4U6O2LUfIrftJGzacqm/?node-id=4560:42862&m=dev) |
| 72 | 管理者アカウント詳細 | `4560:42819` | [dev](https://www.figma.com/design/xDQ4U6O2LUfIrftJGzacqm/?node-id=4560:42819&m=dev) |
| 73 | 管理者アカウント詳細-編集 | `4560:42758` | [dev](https://www.figma.com/design/xDQ4U6O2LUfIrftJGzacqm/?node-id=4560:42758&m=dev) |
| 74 | 管理者アカウント詳細-編集_削除確認 | `4560:42686` | [dev](https://www.figma.com/design/xDQ4U6O2LUfIrftJGzacqm/?node-id=4560:42686&m=dev) |
| 75 | 管理者アカウント詳細-編集_未保存確認 | `4560:42614` | [dev](https://www.figma.com/design/xDQ4U6O2LUfIrftJGzacqm/?node-id=4560:42614&m=dev) |
| 76 | 管理者アカウント詳細-編集_メールアドレス変更確認 | `4560:42542` | [dev](https://www.figma.com/design/xDQ4U6O2LUfIrftJGzacqm/?node-id=4560:42542&m=dev) |
| 77 | 管理者アカウント詳細-編集_メールアドレス変更（認証メール送信） | `4560:42471` | [dev](https://www.figma.com/design/xDQ4U6O2LUfIrftJGzacqm/?node-id=4560:42471&m=dev) |
| 78 | 管理者アカウント詳細-編集（メール未認証） | `4560:42403` | [dev](https://www.figma.com/design/xDQ4U6O2LUfIrftJGzacqm/?node-id=4560:42403&m=dev) |
| 79 | 管理者アカウント詳細（メール未認証） | `4560:42355` | [dev](https://www.figma.com/design/xDQ4U6O2LUfIrftJGzacqm/?node-id=4560:42355&m=dev) |
| 80 | 管理者アカウント追加 | `4560:42162` | [dev](https://www.figma.com/design/xDQ4U6O2LUfIrftJGzacqm/?node-id=4560:42162&m=dev) |
| 81 | 管理者アカウント追加（入力エラー） | `4560:41968` | [dev](https://www.figma.com/design/xDQ4U6O2LUfIrftJGzacqm/?node-id=4560:41968&m=dev) |
| 82 | 管理者アカウント追加_認証メール送信 | `4560:41781` | [dev](https://www.figma.com/design/xDQ4U6O2LUfIrftJGzacqm/?node-id=4560:41781&m=dev) |
| 83 | 管理者アカウント追加_アカウント追加完了 | `4560:41603` | [dev](https://www.figma.com/design/xDQ4U6O2LUfIrftJGzacqm/?node-id=4560:41603&m=dev) |

---

### 要特定（20260527 MCP正典セクションに画面未確認）

| 画面名 | 状況 | 備考 |
|--------|------|------|
| **休日 / 特定日設定機能** | ⚠️ 要特定 | 旧admin section (62:6259, 1063:26512) には「整理券_特定日設定機能_未設定」(`62:8509`)等が実在するが、**正典セクション 4560:41601（20260527）に相当画面なし**。廃止か未移行か要確認。旧node参照: `62:8509` / `62:7393` 等（旧版・非正典）。 |
| **分析ダッシュボード** | ⚠️ 要特定 | G-04 / F-ANLT-001: 本格集計UIのFigmaデザインなし。`analytics/index.blade`は実在するがPhase1 XS相当のみ。**発注者scope/優先裁定が先行**（🚨dashboard掲載済）。 |
| **カレンダービュー** | ⚠️ 要確認 | 旧canonical-map `209:23439` は旧section（187:20481）の「33_整理券管理」frame（旧版・非正典）。現正典セクションでは `4560:50444`（42_整理券管理）がカレンダー表示を含む可能性あり。目視確認推奨。 |
