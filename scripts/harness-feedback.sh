#!/usr/bin/env bash
# ============================================================================
# Harness Feedback Loop — 将 Agent 犯错记录追加到 AGENTS.md
#
# 用法:
#   ./scripts/harness-feedback.sh "错误描述" "修复方式"
#
# 示例:
#   ./scripts/harness-feedback.sh \
#     "Agent 直接编辑了 themes/PaperMod/ 下的文件" \
#     "永远不要修改主题子模块，使用 layouts/ 下的覆盖文件"
#
# 原理: AGENTS.md 中的每条规则都对应一个历史失败案例。
# 每当 Agent 犯错，运行此脚本更新文档，形成"错误疫苗库"。
# ============================================================================
set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "用法: $0 \"错误描述\" \"修复方式\""
  echo "示例: $0 \"Agent 在正文中使用了 H1 标题\" \"正文中最高使用 ## (H2)，标题来自 front matter\""
  exit 1
fi

ERROR_DESC="$1"
FIX_DESC="$2"
AGENTS_FILE="AGENTS.md"
SECTION_HEADER="## Historical Failure Cases"

if [[ ! -f "$AGENTS_FILE" ]]; then
  echo "ERROR: $AGENTS_FILE 不存在。请先创建。"
  exit 1
fi

# 如果 AGENTS.md 里还没有 failure cases 章节，追加一个
if ! grep -q "$SECTION_HEADER" "$AGENTS_FILE"; then
  cat >> "$AGENTS_FILE" << 'HEADER'

## Historical Failure Cases

Below are rules derived from actual Agent mistakes. Each entry exists because
an Agent made this exact error in the past. **Do not repeat them.**

HEADER
fi

# 追加新的失败案例
DATE=$(date '+%Y-%m-%d')
cat >> "$AGENTS_FILE" << ENTRY
- **${DATE}**: ${ERROR_DESC}
  - Fix: ${FIX_DESC}
ENTRY

echo "已追加到 ${AGENTS_FILE}:"
echo "  [${DATE}] ${ERROR_DESC}"
echo "  Fix: ${FIX_DESC}"
echo ""
echo "记得提交: git add ${AGENTS_FILE} && git commit -m ':memo: update AGENTS.md failure case'"
