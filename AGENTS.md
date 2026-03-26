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
# First-time setup: clone with submodules
git clone --recurse-submodules <repo-url>
# Or if already cloned without submodules:
git submodule update --init --recursive

# Local dev server with live reload
hugo server

# Production build (same as CI)
hugo --minify

# Create a new post
hugo new posts/my-new-post.md

# Run content linter (checks front matter, headings, code blocks, config)
bash scripts/lint.sh

# Lint a single file
bash scripts/lint.sh content/posts/my-post.md

# Record an Agent failure case into AGENTS.md
bash scripts/harness-feedback.sh "错误描述" "修复方式"
```

**Custom linter** (`scripts/lint.sh`) checks content and config conventions.
Errors block CI; warnings are informational. The linter runs automatically in
CI before the Hugo build — if lint fails, the site won't deploy.

## CI/CD Pipeline

Defined in `.github/workflows/hugo.yaml`:
- **Trigger**: push to `main` branch
- **Steps**: checkout with submodules → install Hugo extended → `hugo --minify` → deploy to GitHub Pages
- Concurrency group `"pages"` with `cancel-in-progress: true`

Pushing to `main` triggers an automatic production deployment. There is no
staging environment or PR preview.

## Directory Structure

```
content/posts/          Blog post Markdown files (the primary content)
content/bulletin/       灵儿情报站 — AI daily/weekly reports (isolated section)
content/archives.md     Archive listing page
content/search.md       Search page
layouts/partials/       Custom Hugo partial overrides
layouts/_default/       Markup render hooks (e.g., Mermaid), RSS override
static/images/          Static assets (avatar, etc.)
themes/PaperMod/        Theme submodule — do NOT edit directly
hugo.toml               Site configuration
public/                 Built output (committed to repo)
```

## Content Authoring Conventions

### Post Filenames

Use **kebab-case English** names: `adk-multi-agent-collab.md`,
`eino-technical-deep-dive.md`. Keep names descriptive but concise.

### Front Matter

Use **YAML** format (not TOML), with these required fields:

```yaml
---
title: 中文标题
date: 2026-02-13T15:03:33+08:00
draft: false
tags:
  - AI
  - 技术
---
```

- `title`: Chinese, descriptive
- `date`: ISO 8601 with `+08:00` timezone
- `draft`: set to `false` for published posts
- `tags`: YAML list, short category-style labels (mix of Chinese and English)

Note: the archetype (`archetypes/default.md`) uses TOML front matter (`+++`),
but all existing posts use YAML (`---`). **Follow YAML for consistency.**

### Content Language

- **Body text**: Chinese
- **Technical terms**: keep in English (e.g., Agent, Session, ReAct, Transfer)
- **Code examples**: English identifiers, standard language conventions

### Heading Hierarchy

- **H2 (`##`)** for top-level sections — never use H1 in body (title from front matter)
- **H3 (`###`)** for subsections
- Number sections with Chinese numerals (`一、二、三`) or Arabic (`1. 2. 3.`)
  at the H2 level, and dotted Arabic (`2.1, 2.2`) at H3

### Rich Content

- **Mermaid diagrams**: use fenced code blocks with ` ```mermaid `. Supported
  types: flowchart, sequence, class, state diagrams. Mermaid is loaded via CDN
  in the footer partial.
- **Code blocks**: always include a language identifier (` ```go `, ` ```python `)
- **Tables**: standard Markdown pipe tables for structured comparisons
- **Section separators**: use `---` horizontal rules between major sections
- **Blockquotes**: use for key takeaways (e.g., `> **一句话总结**：...`)
- **Bold (`**...**`)**: for emphasis on key terms within paragraphs

## Bulletin Section (灵儿情报站)

The `content/bulletin/` directory is an **isolated section** for AI daily and
weekly reports. It has its own list page and menu entry but is deliberately
excluded from the main content areas.

### Isolation Rules

- **Homepage / Posts list**: excluded via `mainSections = ["posts"]` in
  `hugo.toml` — only the `posts` section appears on the homepage and "文章" list.
- **Archives**: PaperMod's `archives.html` also filters by `mainSections`,
  so bulletin content does not appear.
- **RSS feed**: `layouts/_default/rss.xml` overrides the theme template to
  filter by `mainSections` at the homepage level.
- **Search index**: each bulletin post sets `searchHidden: true` in its front
  matter, which excludes it from `index.json`.

### Bulletin Filenames

Use the pattern `{type}-{date}.md`:
- Daily reports: `daily-2026-03-26.md`
- Weekly reports: `weekly-2026-03-20.md`

### Bulletin Front Matter

```yaml
---
title: "灵儿情报站 | AI 日报 (2026-03-26)"
date: 2026-03-26T08:00:00+08:00
draft: false
searchHidden: true
tags:
  - 灵儿情报站
  - AI日报
---
```

Required extra field compared to regular posts:
- `searchHidden: true` — **mandatory** for all bulletin posts to prevent them
  from appearing in the search index.

### Content Format

Bulletin posts use the same Markdown conventions as regular posts (H2 for
top-level sections, Chinese body text, etc.) but typically follow a structured
template with news items, each containing a title, source link, and summary.

## Hugo Configuration (`hugo.toml`)

- Format: **TOML**
- Comments: **Chinese**, both inline and as section headers
- Section delimiters: `# ------ Description ------`
- Key settings to preserve:
  - `markup.goldmark.renderer.unsafe = true` (allows raw HTML in Markdown)
  - `outputs.home` includes `JSON` (required for search functionality)
  - `params.mermaid = true` (enables Mermaid diagram rendering)
  - Google Analytics ID: `G-M0R8M4JVEY`

## Layout & Template Conventions

Custom layout overrides — keep overrides minimal:

- `layouts/partials/extend_footer.html`: Mermaid JS loader + Busuanzi visitor
  counter. Uses Go template conditionals, inline styles, PaperMod CSS variables
  (e.g., `var(--secondary)`).
- `layouts/partials/post_meta.html`: Overrides PaperMod post meta to add
  per-page busuanzi page view counter.
- `layouts/_default/_markup/render-codeblock-mermaid.html`: Renders Mermaid
  blocks as `<div class="mermaid">`. Three lines total.
- `layouts/_default/rss.xml`: Overrides PaperMod RSS template to filter
  homepage feed by `mainSections`, excluding bulletin content.

When adding templates:
- Use **Go template** syntax (Hugo standard)
- Write **HTML comments in Chinese** (e.g., `<!-- 引入脚本 -->`)
- Reference PaperMod CSS variables for consistent styling
- Do NOT modify files inside `themes/PaperMod/` — use layout overrides instead

## Git Conventions

### Commit Messages

Use **gitmoji** prefix + brief description:
- `:sparkles:` new feature or content
- `:art:` improve structure/format
- `:bug:` fix a bug
- `:fire:` remove code/files
- `:memo:` documentation

Example: `:sparkles: support mermaid image`

### Branch Model

Single branch: `main`. All changes go directly to `main` and auto-deploy.

## Important Gotchas

- **`public/` is committed** — the built output directory is tracked in git.
  Run `hugo --minify` before committing if you want `public/` to reflect changes.
- **Theme is a submodule** — always clone/pull with `--recurse-submodules`.
  Never edit files in `themes/PaperMod/` directly.
- **Unsafe HTML rendering is enabled** — raw HTML in Markdown will be rendered.
  This is intentional for embedding custom elements.
- **No Node.js or npm** — this is a pure Hugo project with no JavaScript build
  pipeline. Do not add `package.json` unless there is a specific need.

## Historical Failure Cases

Below are rules derived from actual Agent mistakes. Each entry exists because
an Agent made this exact error in the past. **Do not repeat them.**

- **2026-03-26**: Agent 在正文中使用了 H1 标题
  - Fix: 正文中最高使用 ## (H2)，标题来自 front matter 的 title

- **2026-03-26**: lint.sh 使用 `((WARNINGS++))` 在 `set -e` 模式下，当变量从 0 自增时返回值为 0（false），导致脚本提前退出
  - Fix: 使用 `VAR=$((VAR + 1))` 替代 `((VAR++))`，避免 `set -e` 误杀

- **2026-03-26**: lint.sh 将 `_index.md`（Hugo section 列表页）当作普通文章检查，报出缺少 date、searchHidden 等字段的误报错误
  - Fix: 在 lint 循环开头跳过 `_index.md` 文件：`[[ "$(basename "$file")" == "_index.md" ]] && continue`
