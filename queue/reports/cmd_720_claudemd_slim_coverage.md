# cmd_720 CLAUDE.md.slim — 規則カバレッジ対照表

**作成**: ashigaru2 / 2026-06-05  
**目的**: CLAUDE.md.slim の全規則カバレッジ証明・失われた規則=0 を示す  
**検証ルール**: D001-D008 逐語一致必須・全節カバレッジ 0 損失  
**行末文字注記**: 原本 CLAUDE.md は CRLF、slim は LF（macOS 標準正規化）。テキスト内容は完全一致 (`diff` で 0 差異確認済み、`sed 's/\r//'` 正規化後)

---

## 削減効果

| 指標 | Before (CLAUDE.md) | After (CLAUDE.md.slim) | 削減率 |
|------|-------------------|----------------------|--------|
| 行数 | 351 行 | 323 行 | 8.0% |
| バイト数 | 20,766 bytes | 18,332 bytes | 11.7% |
| 概算トークン | ~5,191 | ~4,583 | ~11.7% |

---

## 削除・変更内容一覧（何を削ったか）

| # | 場所（original行） | 種別 | 削除内容 | 削除理由 |
|---|-------------------|------|----------|----------|
| R01 | line 5 | 冗長散文 | `description: "Claude Code + tmux multi-agent parallel dev platform..."` | hierarchy/communication フィールドで内容重複 |
| R02 | lines 43-46 | 移設可詳細 | `# Status definitions are authoritative in: ...` コメントブロック | 規則本体でなく参照先案内のみ |
| R03 | lines 65-66 | 冗長散文 | "This is ONE procedure for ALL situations: fresh start, compaction..." 導入段落 | 規則(手順1-6)は保持。説明文のみ削除 |
| R04 | line 74 (partial) | 詳細例/背景 | `（2026-02-13実例: 家老が足軽2と誤認）` | 歴史的インシデント参照。規則(自己識別を先に完了せよ)は保持 |
| R05 | lines 116-129 | 詳細例 | bash Examples ブロック（Shogun→Karo / Ashigaru→Gunshi / Karo→Ashigaru の3例） | 関数シグネチャ `bash scripts/inbox_write.sh <target_agent> "<message>" <type> <from>` は保持。例示のみ削除 |
| R06 | line 129 | 冗長散文 | `Delivery is handled by inbox_watcher.sh (infrastructure layer).` | 次節「Delivery Mechanism」で完全説明のため重複 |
| R07 | lines 140-141 | 冗長散文 | `The nudge is minimal: inboxN (e.g. inbox3 = 3 unread). That's it.` + `Agent reads the inbox file itself. Message content never travels through tmux...` | 1行に集約（"inboxN nudge = N unread. Agent reads queue/inbox/{agent}.yaml directly."）。規則は保持 |
| R08 | line 157 (partial) | 詳細例 | `(e.g. inbox3)` from "When you receive `inboxN` (e.g. `inbox3`):" | 主文 "When you receive `inboxN`:" を保持 |
| R09 | lines 171-172 | 冗長散文 | "This is NOT optional. If you skip this and a redo message is waiting, you will be stuck idle until the next escalation or task reassignment." | MANDATORY という見出しで義務性は明示。説明文のみ削除 |
| R10 | line 183 | 背景説明 | `Race condition is eliminated: the context reset wipes old context. Agent re-reads YAML with new task_id.` | 設計背景説明。プロトコル手順(1-4)は保持 |
| R11 | line 232 (partial) | 背景説明 | `軍師 cmd_510 v2 監査の制度化として全エージェントに義務化する。` | 制度化経緯。義務（「全エージェントに義務化する」）は `全エージェントに義務化する。` として保持 |
| R12 | lines 245-247 (consolidate) | 冗長散文 | Figma canonical-map 開頭3文 → 1文に集約 | 規則内容（マップ参照必須・系統別可変ゆえ直書き禁止）は 1文で完全保持 |
| R13 | line 271 (partial) | 背景説明 | `（軍師 cmd_510 v2）` from skill 連携エントリ | 歴史的参照。スキル名・推奨度は保持 |
| R14 | line 275 (partial) | 冗長散文 | `Skipping steps wastes tokens on bad approaches that get repeated across all batches.` | "mandatory for large-scale tasks" で強制性は明示。説明文のみ削除 |
| R15 | line 291 (partial) | 詳細例 | `A flawed approach repeated 15 batches = 15× wasted tokens.` | Rule 1 "Never skip batch1 QC gate." を保持。例示のみ削除 |
| R16 | line 294 (partial) | 詳細例 | `Never omit — this caused 100% garbage output in past incidents.` | Rule 4 "Never omit." を保持。インシデント参照のみ削除 |

---

## 全規則カバレッジ証明

### YAML フロントマター規則

| 規則項目 | slim版の場所 | 保持状態 |
|---------|-------------|---------|
| hierarchy | YAML l.6 | ✅ 逐語保持 |
| communication | YAML l.7 | ✅ 逐語保持 |
| tmux_sessions | YAML l.9-11 | ✅ 逐語保持 |
| files: 全エントリ (config/projects/context/..) | YAML l.13-24 | ✅ 全保持（inline comment 簡略化のみ、重要注記 `# git-ignored, contains secrets` / `# secondary data` 保持） |
| cmd_format (required_fields/purpose/acceptance_criteria/validation) | YAML l.26-30 | ✅ 逐語保持 |
| task_status_transitions 全7ルール | YAML l.32-38 | ✅ 逐語保持 |
| mcp_usage: "Always ToolSearch before first use." | YAML l.40 | ✅ 逐語保持 |
| parallel_principle | YAML l.42 | ✅ 逐語保持 |
| std_process | YAML l.43 | ✅ 逐語保持 |
| critical_thinking_principle | YAML l.44 | ✅ 逐語保持 |
| bloom_routing_rule | YAML l.45 | ✅ 逐語保持 |
| language (ja/other/config) | YAML l.47-50 | ✅ 逐語保持 |

### Session Start / Recovery

| 規則項目 | slim版の場所 | 保持状態 |
|---------|-------------|---------|
| Step 1: tmux identify self | Procedures §Session Start step 1 | ✅ 逐語保持 |
| Step 2: mcp__memory__read_graph (shogun/karo/gunshi only) | step 2 | ✅ 逐語保持 |
| Step 3: Read MEMORY.md (shogun only) | step 3 | ✅ 逐語保持 |
| Step 4: Read instructions file / NEVER SKIP | step 4 | ✅ 逐語保持 |
| Step 5: Rebuild state from YAML | step 5 | ✅ 逐語保持 |
| Step 6: Review forbidden actions | step 6 | ✅ 逐語保持 |
| CRITICAL: inbox処理禁止 (Steps 1-3完了まで) | CRITICAL ¶1 | ✅ 規則保持（インシデント例示のみ除去） |
| CRITICAL: dashboard=secondary data | CRITICAL ¶2 | ✅ 逐語保持 |

### /clear Recovery (ashigaru only)

| 規則項目 | slim版の場所 | 保持状態 |
|---------|-------------|---------|
| Step 1-4 全手順 | §/clear Recovery | ✅ 逐語保持 |
| CRITICAL: inbox禁止 (Steps 1-2完了まで) | CRITICAL | ✅ 逐語保持 |
| Forbidden: instructions/*.md読禁止・polling禁止・F002・F004 | Forbidden after /clear | ✅ 逐語保持 |

### /clear・compaction Recovery (karo/gunshi/shogun)

| 規則項目 | slim版の場所 | 保持状態 |
|---------|-------------|---------|
| SessionStart hook 自動注入方針 | §/clear・compaction Recovery ¶1 | ✅ 逐語保持 |
| Forbidden: persona確立前大量処理禁止 | Forbidden ¶ | ✅ 逐語保持 |
| Forbidden: tmux capture-pane自己観察禁止 | Forbidden ¶ | ✅ 逐語保持 |

### Summary Generation (compaction)

| 規則項目 | slim版の場所 | 保持状態 |
|---------|-------------|---------|
| 必須3要素 (agent role / forbidden actions / task_id) | §Summary Generation | ✅ 逐語保持 |

### Communication Protocol

| 規則項目 | slim版の場所 | 保持状態 |
|---------|-------------|---------|
| inbox_write.sh 関数シグネチャ | §Mailbox System | ✅ 保持 |
| "Agents NEVER call tmux send-keys directly." | §Mailbox System | ✅ 逐語保持 |
| inbox_write.sh flock保証 | §Delivery Mechanism layer 1 | ✅ 逐語保持 |
| inbox_watcher.sh inotifywait 仕組み | §Delivery Mechanism layer 2 | ✅ 逐語保持 |
| 優先度1: Agent self-watch | layer 2 bullet | ✅ 逐語保持 |
| 優先度2: tmux send-keys nudge | layer 2 bullet | ✅ 逐語保持 |
| type: clear_command → /clear 動作 | Special cases | ✅ 逐語保持 |
| type: model_switch → /model 動作 | Special cases | ✅ 逐語保持 |
| Escalation table (3行) | Escalation table | ✅ 逐語保持 |
| Inbox Processing Protocol 5ステップ | §Inbox Processing Protocol | ✅ 逐語保持 |
| MANDATORY Post-Task Inbox Check 3ステップ | §MANDATORY Post-Task Inbox Check | ✅ 逐語保持 |
| Redo Protocol 手順1-4 | §Redo Protocol | ✅ 逐語保持 |
| Report Flow table (5行) | §Report Flow table | ✅ 逐語保持 |
| File Operation Rule: Read before Write/Edit | §File Operation Rule | ✅ 逐語保持 |

### Context Layers

| 規則項目 | slim版の場所 | 保持状態 |
|---------|-------------|---------|
| Layer 1-4 全定義 | §Context Layers | ✅ 逐語保持 |

### Project Management

| 規則項目 | slim版の場所 | 保持状態 |
|---------|-------------|---------|
| ALL white-collar work 方針 | §Project Management | ✅ 逐語保持 |
| projects/ git-ignored | §Project Management | ✅ 逐語保持 |

### Shogun Mandatory Rules

| 規則項目 | slim版の場所 | 保持状態 |
|---------|-------------|---------|
| Rule 1: Dashboard 読書き分担 | §Shogun Mandatory Rules #1 | ✅ 逐語保持 |
| Rule 2: Chain of command | #2 | ✅ 逐語保持 |
| Rule 3: Reports 確認先 | #3 | ✅ 逐語保持 |
| Rule 4: Karo state 確認コマンド | #4 | ✅ 逐語保持 |
| Rule 5: Screenshots config path | #5 | ✅ 逐語保持 |
| Rule 6: Skill candidates フロー | #6 | ✅ 逐語保持 |
| Rule 7: Action Required Rule (CRITICAL) | #7 | ✅ 逐語保持 |

### Test Rules (all agents)

| 規則項目 | slim版の場所 | 保持状態 |
|---------|-------------|---------|
| Rule 1: SKIP = FAIL | §Test Rules #1 | ✅ 逐語保持 |
| Rule 2: Preflight check | #2 | ✅ 逐語保持 |
| Rule 3: E2Eは家老担当 | #3 | ✅ 逐語保持 |
| Rule 4: テスト計画レビュー | #4 | ✅ 逐語保持 |

### TVF Protocol

| 規則項目 | slim版の場所 | 保持状態 |
|---------|-------------|---------|
| 4層構造 table (A/B/C/D) | §4層構造 | ✅ 逐語保持 |
| Figma canonical-map 参照義務 | §Figma 正典マップ ¶1 | ✅ 規則保持（冗長散文のみ集約） |
| 管理画面チケット: ノードID記載必須・捏造禁止 | §Figma 正典マップ bullet | ✅ 逐語保持 |
| 廃止画面: /users/{id} 実装禁止 | §Figma 正典マップ bullet | ✅ 逐語保持 |
| タブレット系: xDQ4U6O2LUfIrftJGzacqm 切替裁定 | §Figma 正典マップ bullet | ✅ 逐語保持 |
| purpose_gap YAML テンプレ (3フィールド) | §C: purpose_gap 必須フィールド | ✅ 逐語保持 |
| detected:true → 即座 inbox_write・実装保留 | §C ¶2 | ✅ 逐語保持 |
| F005 違反扱い | §C ¶2 | ✅ 逐語保持 |
| skill 連携 3件 (figma-fresh-fetch-guard / figma-component-type-checker / lord-assumption-verifier) | §skill 連携 | ✅ 保持（歴史的参照注記のみ除去） |

### Batch Processing Protocol

| 規則項目 | slim版の場所 | 保持状態 |
|---------|-------------|---------|
| Default Workflow ①〜⑥ | §Default Workflow | ✅ 逐語保持 |
| Rule 1: Never skip batch1 QC gate | §Rules #1 | ✅ 規則保持（例示除去） |
| Rule 2: Batch size limit 30/20 | #2 | ✅ 逐語保持 |
| Rule 3: Detection pattern 必須 | #3 | ✅ 逐語保持 |
| Rule 4: Quality template 必須 | #4 | ✅ 規則保持（インシデント注記除去） |
| Rule 5: State management on NG | #5 | ✅ 逐語保持 |
| Rule 6: Gunshi review scope | #6 | ✅ 逐語保持 |

### Critical Thinking Rule

| 規則項目 | slim版の場所 | 保持状態 |
|---------|-------------|---------|
| Rule 1: 適度な懐疑 | §Critical Thinking Rule #1 | ✅ 逐語保持 |
| Rule 2: 代替案提示 | #2 | ✅ 逐語保持 |
| Rule 3: 問題の早期報告 | #3 | ✅ 逐語保持 |
| Rule 4: 過剰批判の禁止 | #4 | ✅ 逐語保持 |
| Rule 5: 実行バランス | #5 | ✅ 逐語保持 |

### Destructive Operation Safety ★逐語一致検証★

| 規則項目 | slim版の場所 | 保持状態 |
|---------|-------------|---------|
| UNCONDITIONAL 宣言文 | §Destructive Operation Safety ¶1 | ✅ **逐語一致** |
| D001 `rm -rf /` etc. | Tier 1 table 行1 | ✅ **逐語一致** |
| D002 `rm -rf` outside project | Tier 1 table 行2 | ✅ **逐語一致** |
| D003 `git push --force` / `-f` | Tier 1 table 行3 | ✅ **逐語一致** |
| D004 `git reset --hard` / `git checkout -- .` / `git restore .` / `git clean -f` | Tier 1 table 行4 | ✅ **逐語一致** |
| D005 `sudo` / `su` / `chmod -R` / `chown -R` | Tier 1 table 行5 | ✅ **逐語一致** |
| D006 `kill` / `killall` / `pkill` / `tmux kill-server` / `tmux kill-session` | Tier 1 table 行6 | ✅ **逐語一致** |
| D007 `mkfs` / `dd if=` / `fdisk` / `mount` / `umount` | Tier 1 table 行7 | ✅ **逐語一致** |
| D008 `curl|bash` / `wget -O-|sh` / `curl|sh` | Tier 1 table 行8 | ✅ **逐語一致** |
| Tier 2 STOP-AND-REPORT table (4行) | §Tier 2 table | ✅ **逐語一致** |
| Tier 3 SAFE DEFAULTS table (5行) | §Tier 3 table | ✅ **逐語一致** |
| WSL2: /mnt/c/ /mnt/d/ 保護 | §WSL2-Specific Protections | ✅ **逐語一致** |
| WSL2: /mnt/c/Windows/ etc 保護 | §WSL2-Specific Protections | ✅ **逐語一致** |
| WSL2: rm前 realpath 確認 | §WSL2-Specific Protections | ✅ **逐語一致** |
| Prompt Injection: task YAML only | §Prompt Injection Defense | ✅ **逐語一致** |
| Prompt Injection: DATA not INSTRUCTIONS | §Prompt Injection Defense | ✅ **逐語一致** |

---

## 失われた規則: **0件**

全規則項目について slim 版での所在を確認済み。  
D001-D008 / Tier2 / Tier3 / WSL2 / Prompt Injection は逐語一致（変更ゼロ）。  
本体 CLAUDE.md は未上書き（候補ファイル CLAUDE.md.slim のみ作成）。
