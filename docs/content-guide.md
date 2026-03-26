# Content Authoring Guide

Tier 2 reference for writing blog posts and bulletin content.
Only consult this file when creating or editing content in `content/`.

## Post Filenames

Use **kebab-case English** names: `adk-multi-agent-collab.md`,
`eino-technical-deep-dive.md`. Keep names descriptive but concise.

## Front Matter

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

## Content Language

- **Body text**: Chinese
- **Technical terms**: keep in English (e.g., Agent, Session, ReAct, Transfer)
- **Code examples**: English identifiers, standard language conventions

## Heading Hierarchy

- **H2 (`##`)** for top-level sections — never use H1 in body (title from front matter)
- **H3 (`###`)** for subsections
- Number sections with Chinese numerals (`一、二、三`) or Arabic (`1. 2. 3.`)
  at the H2 level, and dotted Arabic (`2.1, 2.2`) at H3

## Rich Content

- **Mermaid diagrams**: use fenced code blocks with ` ```mermaid `. Supported
  types: flowchart, sequence, class, state diagrams. Mermaid is loaded via CDN
  in the footer partial.
- **Code blocks**: always include a language identifier (` ```go `, ` ```python `)
- **Tables**: standard Markdown pipe tables for structured comparisons
- **Section separators**: use `---` horizontal rules between major sections
- **Blockquotes**: use for key takeaways (e.g., `> **一句话总结**：...`)
- **Bold (`**...**`)**: for emphasis on key terms within paragraphs

---

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
