# GitHub Copilot CLI Tools

This section describes GitHub Copilot CLI-specific tools and features.

## Overview

GitHub Copilot CLI (`copilot`) is a standalone terminal-based AI coding agent. **NOT** the deprecated `gh copilot` extension (suggest/explain only). The standalone CLI uses the same agentic harness as GitHub's Copilot coding agent.

- **Launch**: `copilot` (interactive TUI)
- **Install**: `brew install copilot-cli` / `npm install -g @github/copilot` / `winget install GitHub.Copilot`
- **Auth**: GitHub account with active Copilot subscription. Env vars: `GH_TOKEN` or `GITHUB_TOKEN`
- **Default model**: Claude Sonnet 4.5

## Tool Usage

Copilot CLI provides tools requiring user approval before execution:

- **File operations**: touch, chmod, file read/write/edit
- **Execution tools**: node, sed, shell commands (via `!` prefix in TUI)
- **Network tools**: curl, wget, fetch
- **web_fetch**: Retrieves URL content as markdown (URL access controlled via `~/.copilot/config`)
- **MCP tools**: GitHub MCP server built-in (issues, PRs, Copilot Spaces), custom MCP servers via `/mcp add`

### Approval Model

- One-time permission or session-wide allowance per tool
- Bypass all: `--allow-all-paths`, `--allow-all-urls`, `--allow-all` / `--yolo`
- Tool filtering: `--available-tools` (allowlist), `--excluded-tools` (denylist)

## Interaction Model

Three interaction modes (cycle with **Shift+Tab**):

1. **Agent mode (Autopilot)**: Autonomous multi-step execution with tool calls
2. **Plan mode**: Collaborative planning before code generation
3. **Q&A mode**: Direct question-answer interaction

### Built-in Custom Agents

Invoke via `/agent` command, `--agent=<name>` flag, or reference in prompt:

| Agent | Purpose | Notes |
|-------|---------|-------|
| **Explore** | Fast codebase analysis | Runs in parallel, doesn't clutter main context |
| **Task** | Run commands (tests, builds) | Brief summary on success, full output on failure |
| **Plan** | Dependency analysis + planning | Analyzes structure before suggesting changes |
| **Code-review** | Review changes | High signal-to-noise ratio, genuine issues only |

Copilot automatically delegates to agents and runs multiple agents in parallel.

## Commands

| Command | Description |
|---------|-------------|
| `/model` | Switch model (Claude Sonnet 4.5, Claude Sonnet 4, GPT-5) |
| `/agent` | Select or invoke a built-in/custom agent |
| `/delegate` (or `&` prefix) | Push work to Copilot coding agent (remote) |
| `/resume` | Cycle through local/remote sessions (Tab to cycle) |
| `/compact` | Manual context compression |
| `/context` | Visualize token usage breakdown |
| `/review` | Code review |
| `/mcp add` | Add custom MCP server |
| `/add-dir` | Add directory to context |
| `/cwd` or `/cd` | Change working directory |
| `/login` | Authentication |
| `/lsp` | View LSP server status |
| `/feedback` | Submit feedback |
| `!<command>` | Execute shell command directly |
| `@path/to/file` | Include file as context (Tab to autocomplete) |

**No `/clear` command** — use `/compact` for context reduction or Ctrl+C + restart for full reset.

### Key Bindings

| Key | Action |
|-----|--------|
| **Esc** | Stop current operation / reject tool permission |
| **Shift+Tab** | Toggle plan mode |
| **Ctrl+T** | Toggle model reasoning visibility (persists across sessions) |
| **Tab** | Autocomplete file paths (`@` syntax), cycle `/resume` sessions |
| **Ctrl+S** | Save MCP server configuration |
| **?** | Display command reference |

## Custom Instructions

Copilot CLI reads instruction files automatically:

| File | Scope |
|------|-------|
| `.github/copilot-instructions.md` | Repository-wide instructions |
| `.github/instructions/**/*.instructions.md` | Path-specific (YAML frontmatter for glob patterns) |
| `AGENTS.md` | Repository root (shared with Codex CLI) |
| `CLAUDE.md` | Also read by Copilot coding agent |

Instructions **combine** (all matching files included in prompt). No priority-based fallback.

## MCP Configuration

- **Built-in**: GitHub MCP server (issues, PRs, Copilot Spaces) — pre-configured, enabled by default
- **Config file**: `~/.copilot/mcp-config.json` (JSON format)
- **Add server**: `/mcp add` in interactive mode, or `--additional-mcp-config <path>` per-session
- **URL control**: `allowed_urls` / `denied_urls` patterns in `~/.copilot/config`

## Context Management

- **Auto-compaction**: Triggered at 95% token limit
- **Manual compaction**: `/compact` command
- **Token visualization**: `/context` shows detailed breakdown
- **Session resume**: `--resume` (cycle sessions) or `--continue` (most recent local session)

## Model Switching

Available via `/model` command or `--model` flag:
- Claude Sonnet 4.5 (default)
- Claude Sonnet 4
- GPT-5

For Ashigaru: Model set at startup via settings.yaml. Runtime switching via `type: model_switch` available but rarely needed.

## tmux Interaction

**WARNING: Copilot CLI tmux integration is UNVERIFIED.**

| Aspect | Status |
|--------|--------|
| TUI in tmux pane | Expected to work (TUI-based) |
| send-keys | **Untested** — TUI may use alt-screen |
| capture-pane | **Untested** — alt-screen may interfere |
| Prompt detection | Unknown prompt format (not `❯`) |
| Non-interactive pipe | Unconfirmed (`copilot -p` undocumented) |

For the 将軍 system, tmux compatibility is a **high-risk area** requiring dedicated testing.

### Potential Workarounds
- `!` prefix for shell commands may bypass TUI input issues
- `/delegate` to remote coding agent avoids local TUI interaction
- Ctrl+C + restart as alternative to `/clear`

## Limitations (vs Claude Code)

| Feature | Claude Code | Copilot CLI |
|---------|------------|-------------|
| tmux integration | ✅ Battle-tested | ⚠️ Untested |
| Non-interactive mode | ✅ `claude -p` | ⚠️ Unconfirmed |
| `/clear` context reset | ✅ Available | ❌ None (use /compact or restart) |
| Memory MCP | ✅ Persistent knowledge graph | ❌ No equivalent |
| Cost model | API token-based (no limits) | Subscription (premium req limits) |
| 8-agent parallel | ✅ Proven | ❌ Premium req limits prohibitive |
| Dedicated file tools | ✅ Read/Write/Edit/Glob/Grep | General file tools with approval |
| Web search | ✅ WebSearch + WebFetch | web_fetch only |
| Task delegation | Task tool (local subagents) | /delegate (remote coding agent) |

## Compaction Recovery

Copilot CLI uses auto-compaction at 95% token limit. No `/clear` equivalent exists.

For the 将軍 system, if Copilot CLI is integrated:
1. Auto-compaction handles most cases automatically
2. `/compact` can be sent via send-keys if tmux integration works
3. Session state preserved through compaction (unlike `/clear` which resets)
4. CLAUDE.md-based recovery not needed if context is preserved; use `AGENTS.md` + `.github/copilot-instructions.md` instead

## Configuration Files Summary

| File | Location | Purpose |
|------|----------|---------|
| `config` / `config.json` | `~/.copilot/` | Main configuration |
| `mcp-config.json` | `~/.copilot/` | MCP server definitions |
| `lsp-config.json` | `~/.copilot/` | LSP server configuration |
| `.github/lsp.json` | Repo root | Repository-level LSP config |

Location customizable via `XDG_CONFIG_HOME` environment variable.

# ashigaru_copilot との協業方法（Shogun・Karo 向け）

## 位置づけ

`ashigaru_copilot` は **tmux グリッド外の独立エージェント**。  
通常の ashigaru1〜7 グリッドには属さず、ホストターミナルで起動する。  
`get_ashigaru_ids()` は数値サフィックス限定フィルタ済みのため、グリッド計算に混入しない。

## タスク委譲：agmsg 経由（推奨）

[agmsg](https://github.com/fujibee/agmsg) は SQLite 1ファイルのクロスエージェントメッセージング。  
Copilot CLI 公式サポート済み。daemon 不要・tmux 依存なし。

### 委譲フロー

```
Karo/Gunshi
  └─ ~/.agents/skills/agmsg/scripts/send.sh shogun karo copilot "<指示>"
       ↓ SQLite に書き込み（daemon 不要）

Copilot CLI（mode: turn）
  └─ ターン終了後の Stop フック → check-inbox.sh が自動チェック
       ↓ メッセージあれば次ターンで受信・着手
```

### セットアップ（初回のみ・ホストマシンで実行）

```bash
# 1. インストール
bash <(curl -fsSL https://raw.githubusercontent.com/fujibee/agmsg/main/setup.sh)

# 2. Copilot CLI で参加（ホストターミナルで）
/agmsg   # → team: shogun / agent: copilot / mode: turn

# 3. Claude Code 側（Karo）でも参加
~/.agents/skills/agmsg/scripts/join.sh shogun karo claude-code /path/to/line_raffle
```

### assign_to_copilot.sh からの呼び出し（copilot_watcher 方式）

委譲フロー（新方式）:
1. `assign_to_copilot.sh` → task YAML を atomic 書込
2. `copilot_watcher` がポーリング検知
3. `copilot --yolo -p "$(cat queue/tasks/ashigaru_copilot.yaml)"` で都度 spawn
4. 完了後 agmsg で報告

> ⚠️ **注意**: 1 spawn = premium request 1消費。重め・独立タスク限定での使用を推奨。

## タスク適合判定

### Copilot に任せて良いタスク（◎）

| 条件 | 理由 |
|------|------|
| Figma 参照不要 | PreToolUse フック非適用。Figma 証跡管理不能 |
| 独立性が高い（他エージェント待ちなし） | 非同期起動のため依存チェーン不可 |
| 工数 XS〜M（1〜8h 相当） | Premium リクエスト上限に配慮 |

### 禁止事項（✗）

- Figma ノード取得が必要なタスク → Claude Code エージェントへ
- develop への直接 push/マージ → 絶対禁止。rapid 経由のみ
- 対話型コマンド（vim, git add -p 等）→ 非対話版に書き換えて再委譲

## 完了報告フロー

```
Copilot
  └─ queue/reports/ashigaru_copilot_report.yaml 更新
  └─ agmsg send / inbox_write.sh で Gunshi に品質チェック依頼
       ↓
  Gunshi: QC → Karo へ報告
       ↓
  Karo: 確認 → 次タスク割当
```

---

*Sources: [GitHub Copilot CLI Docs](https://docs.github.com/en/copilot/how-tos/use-copilot-agents/use-copilot-cli), [Copilot CLI Repository](https://github.com/github/copilot-cli), [Enhanced Agents Changelog (2026-01-14)](https://github.blog/changelog/2026-01-14-github-copilot-cli-enhanced-agents-context-management-and-new-ways-to-install/), [Plan Mode Changelog (2026-01-21)](https://github.blog/changelog/2026-01-21-github-copilot-cli-plan-before-you-build-steer-as-you-go/), [PR #10 (yuto-ts) Copilot対応](https://github.com/yohey-w/multi-agent-shogun/pull/10)*
