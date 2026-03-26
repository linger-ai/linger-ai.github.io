#!/usr/bin/env bash
# ============================================================================
# Linger-AI Blog Linter — Harness Engineering P0
# 针对 Hugo + PaperMod 博客的自定义 Linter，每条错误都附带修复指令。
# 用法: ./scripts/lint.sh [file ...]
#   不传参数时检查 content/posts/*.md 全部文章
# ============================================================================
set -euo pipefail

RED='\033[0;31m'
YELLOW='\033[0;33m'
GREEN='\033[0;32m'
NC='\033[0m'

ERRORS=0
WARNINGS=0

error() {
  local file="$1" line="$2" msg="$3" fix="$4"
  echo -e "${RED}ERROR${NC} ${file}:${line}: ${msg}"
  echo -e "  ${YELLOW}FIX${NC}: ${fix}"
  ERRORS=$((ERRORS + 1))
}

warn() {
  local file="$1" line="$2" msg="$3" fix="$4"
  echo -e "${YELLOW}WARN${NC}  ${file}:${line}: ${msg}"
  echo -e "  ${YELLOW}FIX${NC}: ${fix}"
  WARNINGS=$((WARNINGS + 1))
}

# ---------- 确定要检查的文件 ----------
if [[ $# -gt 0 ]]; then
  FILES=("$@")
else
  FILES=()
  for f in content/posts/*.md content/bulletin/*.md; do
    [[ -f "$f" ]] && FILES+=("$f")
  done
fi

for file in "${FILES[@]}"; do
  [[ -f "$file" ]] || continue

  # 跳过 Hugo section 列表页 (_index.md)
  [[ "$(basename "$file")" == "_index.md" ]] && continue

  # ======== Front Matter 检查 ========

  # 1) 必须使用 YAML front matter (--- 而非 +++)
  first_line=$(head -1 "$file")
  if [[ "$first_line" == "+++" ]]; then
    error "$file" 1 \
      "Front matter 使用了 TOML 格式 (+++)" \
      "改为 YAML 格式 (---)。参考 AGENTS.md 的 Front Matter 章节"
    continue  # TOML front matter 无法继续做 YAML 解析
  fi

  if [[ "$first_line" != "---" ]]; then
    error "$file" 1 \
      "缺少 YAML front matter 开头 (---)" \
      "文件第一行必须是 --- 。参考现有文章的格式"
    continue
  fi

  # 提取 front matter 区域 (第一个 --- 和第二个 --- 之间)
  fm_end=$(awk 'NR>1 && /^---$/{print NR; exit}' "$file")
  if [[ -z "$fm_end" ]]; then
    error "$file" 1 \
      "YAML front matter 没有闭合 (缺少结尾 ---)" \
      "在 front matter 最后一行之后加上 ---"
    continue
  fi

  # 2) 必需字段检查: title
  if ! awk "NR>1 && NR<$fm_end" "$file" | grep -q '^title:'; then
    error "$file" 2 \
      "Front matter 缺少 title 字段" \
      "添加 title: 中文标题。标题应为描述性中文"
  fi

  # 3) 必需字段检查: date (ISO 8601 + 时区)
  date_line=$(awk "NR>1 && NR<$fm_end" "$file" | grep '^date:' || true)
  if [[ -z "$date_line" ]]; then
    error "$file" 2 \
      "Front matter 缺少 date 字段" \
      "添加 date: 2026-01-01T12:00:00+08:00 (ISO 8601 格式，+08:00 时区)"
  elif ! echo "$date_line" | grep -qE '\+[0-9]{2}:[0-9]{2}'; then
    line_num=$(grep -n '^date:' "$file" | head -1 | cut -d: -f1)
    warn "$file" "$line_num" \
      "date 字段缺少时区信息" \
      "date 应包含时区，如 +08:00。例: date: 2026-01-01T12:00:00+08:00"
  fi

  # 4) 必需字段检查: draft
  draft_line=$(awk "NR>1 && NR<$fm_end" "$file" | grep '^draft:' || true)
  if [[ -z "$draft_line" ]]; then
    warn "$file" 2 \
      "Front matter 缺少 draft 字段" \
      "添加 draft: false (发布) 或 draft: true (草稿)"
  elif echo "$draft_line" | grep -q 'true'; then
    line_num=$(grep -n '^draft:' "$file" | head -1 | cut -d: -f1)
    warn "$file" "$line_num" \
      "文章标记为 draft: true，不会出现在生产站点" \
      "如果要发布，改为 draft: false"
  fi

  # 5) 必需字段检查: tags
  if ! awk "NR>1 && NR<$fm_end" "$file" | grep -q '^tags:'; then
    warn "$file" 2 \
      "Front matter 缺少 tags 字段" \
      "添加 tags 列表。例:\ntags:\n  - AI\n  - 技术"
  fi

  # 5b) Bulletin 专属: searchHidden: true 必须存在
  if [[ "$file" == content/bulletin/* ]]; then
    if ! awk "NR>1 && NR<$fm_end" "$file" | grep -q '^searchHidden: true'; then
      error "$file" 2 \
        "Bulletin 文章缺少 searchHidden: true" \
        "Bulletin 文章必须在 front matter 中添加 searchHidden: true 以排除搜索索引"
    fi
  fi

  # ======== 文件名检查 ========

  basename=$(basename "$file")
  # 6) 文件名必须 kebab-case
  if echo "$basename" | grep -qE '[A-Z_]'; then
    error "$file" 0 \
      "文件名不是 kebab-case: ${basename}" \
      "文件名应使用小写英文 + 连字符。例: my-new-post.md"
  fi

  # ======== 正文内容检查 ========

  body_start=$((fm_end + 1))

  # 7) 正文中不应出现 H1 (# 标题)
  h1_line=$(awk "NR>=$body_start && /^# [^#]/{print NR; exit}" "$file")
  if [[ -n "$h1_line" ]]; then
    warn "$file" "$h1_line" \
      "正文中使用了 H1 标题 (# ...)，标题应来自 front matter 的 title" \
      "将 # 改为 ## (H2)。正文中最高使用 ## 作为顶级标题。参考 AGENTS.md"
  fi

  # 8) 代码块应有语言标识 (只检查开启标记，跳过闭合的 ```)
  in_code_block=0
  while IFS= read -r line_info; do
    line_num="${line_info%%:*}"
    line_content="${line_info#*:}"
    if [[ $in_code_block -eq 0 ]]; then
      # 开启标记：纯 ``` 没有语言标识
      if [[ "$line_content" == '```' ]]; then
        warn "$file" "$line_num" \
          "代码块缺少语言标识符" \
          "在 \`\`\` 后添加语言标识。例: \`\`\`go, \`\`\`python, \`\`\`mermaid"
      fi
      in_code_block=1
    else
      # 闭合标记
      in_code_block=0
    fi
  done < <(awk "NR>=$body_start && /^\`\`\`/{print NR\":\"\$0}" "$file")

  # 9) 检查 themes/PaperMod/ 下的文件是否被修改 (git tracked)
  # 这个检查由 CI 层面的 lint-theme.sh 处理

done

# ======== 项目级检查 ========

# 10) hugo.toml 关键配置完整性
if [[ -f hugo.toml ]]; then
  if ! grep -q 'unsafe = true' hugo.toml; then
    error "hugo.toml" 0 \
      "缺少 markup.goldmark.renderer.unsafe = true" \
      "此配置允许 Markdown 中嵌入原始 HTML，是项目必需的。参考 AGENTS.md"
  fi
  if ! grep -q '"JSON"' hugo.toml; then
    error "hugo.toml" 0 \
      "outputs.home 缺少 JSON 格式" \
      "搜索功能依赖 JSON 输出。确保 home = [\"HTML\", \"RSS\", \"JSON\"]"
  fi
  if ! grep -q 'mermaid = true' hugo.toml; then
    error "hugo.toml" 0 \
      "缺少 params.mermaid = true" \
      "Mermaid 图表渲染依赖此配置。参考 AGENTS.md"
  fi
  if ! grep -q 'mainSections' hugo.toml; then
    error "hugo.toml" 0 \
      "缺少 mainSections 配置" \
      "需要 mainSections = [\"posts\"] 以隔离 bulletin 内容。参考 AGENTS.md"
  fi
fi

# 11) 主题子模块完整性
if [[ ! -d themes/PaperMod/layouts ]]; then
  error "themes/PaperMod" 0 \
    "PaperMod 主题子模块不完整" \
    "运行: git submodule update --init --recursive"
fi

# 12) 检查 themes/PaperMod/ 下是否有未提交的修改
if git diff --quiet themes/PaperMod 2>/dev/null; then
  : # 没有修改，ok
else
  error "themes/PaperMod" 0 \
    "主题子模块有未提交的修改 — 禁止直接编辑主题文件" \
    "撤销修改: git checkout themes/PaperMod 。如需自定义，在 layouts/ 下创建覆盖文件"
fi

# ======== 汇总 ========
echo ""
if [[ $ERRORS -eq 0 && $WARNINGS -eq 0 ]]; then
  echo -e "${GREEN}All checks passed.${NC}"
  exit 0
elif [[ $ERRORS -eq 0 ]]; then
  echo -e "${YELLOW}${WARNINGS} warning(s), 0 error(s).${NC}"
  exit 0
else
  echo -e "${RED}${ERRORS} error(s), ${WARNINGS} warning(s).${NC}"
  exit 1
fi
