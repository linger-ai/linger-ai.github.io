# AGENTS.md

Guidelines for AI coding agents operating in this repository.

## Project Overview

Hugo static blog ("Linger-AI Space") using the **PaperMod** theme, deployed to
GitHub Pages. Content is Chinese-language technical articles about AI agent
architectures. The theme is a git submodule at `themes/PaperMod`.

## Prerequisites

- **Hugo extended** (latest version) — required for PaperMod's SCSS support
- Git with submodule support

## Build & Dev Commands

```bash
# Local dev server with live reload
hugo server

# Production build (same as CI)
hugo --minify

# Create a new post
hugo new posts/my-new-post.md

# Run content linter (checks front matter, headings, code blocks, config)
bash scripts/lint.sh

# Record an Agent failure case into AGENTS.md
bash scripts/harness-feedback.sh "错误描述" "修复方式"
```

## Directory Structure

```
content/posts/          Blog post Markdown files (the primary content)
content/bulletin/       灵儿情报站 — AI daily/weekly reports (isolated section)
layouts/                Custom Hugo partial overrides & render hooks
static/images/          Static assets (avatar, etc.)
themes/PaperMod/        Theme submodule — do NOT edit directly
hugo.toml               Site configuration
public/                 Built output (committed to repo)
docs/                   Tier 2 detailed guides (see below)
```

## Tier 2 Detailed Guides

Consult these **only when working on the relevant area**:

- `docs/content-guide.md` — Post & bulletin authoring: filenames, front matter,
  heading hierarchy, rich content, bulletin isolation rules
- `docs/hugo-config-guide.md` — Hugo config details, layout/template conventions,
  CI/CD pipeline

## Git Conventions

Use **gitmoji** prefix + brief description:
- `:sparkles:` new feature or content
- `:art:` improve structure/format
- `:bug:` fix a bug
- `:fire:` remove code/files
- `:memo:` documentation

Example: `:sparkles: support mermaid image`

Single branch: `main`. All changes go directly to `main` and auto-deploy.

## Important Gotchas

- **`public/` is committed** — run `hugo --minify` before committing if you
  want `public/` to reflect changes.
- **Theme is a submodule** — always clone/pull with `--recurse-submodules`.
  Never edit files in `themes/PaperMod/` directly.
- **Unsafe HTML rendering is enabled** — raw HTML in Markdown will be rendered.
- **No Node.js or npm** — pure Hugo project, no JavaScript build pipeline.

## Historical Failure Cases

Below are rules derived from actual Agent mistakes. Each entry exists because
an Agent made this exact error in the past. **Do not repeat them.**

- **2026-03-26**: Agent 在正文中使用了 H1 标题
  - Fix: 正文中最高使用 ## (H2)，标题来自 front matter 的 title

- **2026-03-26**: lint.sh 使用 `((WARNINGS++))` 在 `set -e` 模式下，当变量从 0 自增时返回值为 0（false），导致脚本提前退出
  - Fix: 使用 `VAR=$((VAR + 1))` 替代 `((VAR++))`，避免 `set -e` 误杀

- **2026-03-26**: lint.sh 将 `_index.md`（Hugo section 列表页）当作普通文章检查，报出缺少 date、searchHidden 等字段的误报错误
  - Fix: 在 lint 循环开头跳过 `_index.md` 文件：`[[ "$(basename "$file")" == "_index.md" ]] && continue`
