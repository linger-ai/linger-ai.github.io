# Hugo Configuration & Layout Guide

Tier 2 reference for modifying Hugo config, templates, and CI pipeline.
Only consult this file when working on `hugo.toml`, `layouts/`, or CI workflows.

## CI/CD Pipeline

Defined in `.github/workflows/hugo.yaml`:
- **Trigger**: push to `main` branch
- **Steps**: checkout with submodules -> install Hugo extended -> `hugo --minify` -> deploy to GitHub Pages
- Concurrency group `"pages"` with `cancel-in-progress: true`

Pushing to `main` triggers an automatic production deployment. There is no
staging environment or PR preview.

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
