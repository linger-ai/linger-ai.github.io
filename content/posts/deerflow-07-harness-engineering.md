---
title: "DeerFlow 源码解析（七）：Harness Engineering 工程实践"
date: 2026-03-28T16:00:00+08:00
draft: false
tags:
  - AI
  - 技术
  - DeerFlow
---

> **DeerFlow 源码解析系列目录**
>
> - [导读：AI Agent 框架的选择与 DeerFlow 的定位](/posts/deerflow-00-introduction)
> - [第一篇：一个 Chat 请求的完整生命周期](/posts/deerflow-01-chat-request-lifecycle)
> - [第二篇：系统提示词工程与上下文架构](/posts/deerflow-02-prompt-engineering-context)
> - [第三篇：主从 Agent 协作与安全边界](/posts/deerflow-03-multi-agent-collaboration)
> - [第四篇：Skills、MCP 与工具生态](/posts/deerflow-04-skills-mcp-tools)
> - [第五篇：沙箱隔离与代码执行](/posts/deerflow-05-sandbox-isolation)
> - [第六篇：长期记忆、IM 通道与多端接入](/posts/deerflow-06-memory-im-channels)
> - **第七篇（本文）**：Harness Engineering 工程实践

---

> 前六篇深入了各个子系统的实现细节，本篇退后一步，审视支撑这些子系统的工程基础设施——AI Agent 指导文件、架构边界强制、CI/CD 管线、代码规范，以及对整个项目工程实践的综合评估。

一个 AI Agent 系统的代码质量不只取决于 Agent 本身写得多好，还取决于一个更底层的问题：**这个项目是否有足够的工程纪律来让多人（包括 AI 助手）安全地协作**。DeerFlow 在这方面做了大量工作，有些做得扎实，有些还在进化中。

## 一、CLAUDE.md——给 AI Agent 写的架构文档

### 1.1 文档定位

`backend/CLAUDE.md`（523 行）不是一份普通的 README。它的开头就表明了身份：

> This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

这是一份专门为 AI 编程助手撰写的架构指导文档。设计目标是让 AI 助手在不看代码的情况下理解架构决策，并做出正确的修改——而非教人类开发者"怎么用这个项目"。

### 1.2 文档结构

CLAUDE.md 的组织遵循"从全局到细节"的信息架构：

```
1. Project Overview        — 一段话定位项目
2. Architecture            — 四服务架构 + 端口
3. Project Structure       — 完整目录树
4. Important Guidelines    — 文档更新政策（全大写 CRITICAL）
5. Commands                — 可执行的命令列表
6. Architecture Details    — 每个子系统的详细说明
   - Harness/App Split
   - Agent System
   - Middleware Chain
   - Configuration System
   - Gateway API
   - Sandbox System
   - Subagent System
   - Tool System
   - MCP System
   - Skills System
   - Model Factory
   - IM Channels System
   - Memory System
   - Reflection System
   - Config Schema
   - Embedded Client
7. Development Workflow    — TDD 要求 + 运行方式
8. Key Features            — 用户可见的功能特性
9. Code Style              — 代码风格约定
10. Documentation Links    — 详细文档指引
```

### 1.3 为什么这样的文档很重要

在传统软件工程中，架构文档是给人读的，可以假设读者会"浏览代码来补全理解"。但 AI Agent 的上下文窗口有限，不能随意浏览整个代码库。CLAUDE.md 需要在一个文件内提供足够的信息，让 AI 做出正确的决策。

几个设计选择值得展开说：

**文档更新政策前置**：`CLAUDE.md:66-74` 用全大写 CRITICAL 标注了文档更新要求，这放在"Commands"之前——因为 AI Agent 最容易犯的错误是"改了代码不更新文档"：

```markdown
### Documentation Update Policy
**CRITICAL: Always update README.md and CLAUDE.md after every code change**
```

**Import 约定用代码示例**：不是说"Harness 不能导入 App"，而是直接给出正确和错误的代码示例（`CLAUDE.md:117-131`）：

```python
# App → Harness (allowed)
from deerflow.config import get_app_config

# Harness → App (FORBIDDEN — enforced by test_harness_boundary.py)
# from app.gateway.routers.uploads import ...  # ← will fail CI
```

**Middleware 顺序带编号**：12 个中间件按执行顺序编号列出（`CLAUDE.md:153-166`），附带每个中间件的一句话说明和条件标记（optional, conditional）。AI Agent 在添加新中间件时可以立即知道应该插在哪个位置。

**配置优先级用编号列表**：Config 查找路径按优先级排列（`CLAUDE.md:179-183`），不用 AI 去推断代码逻辑。

### 1.4 多 Agent 指导文件矩阵

DeerFlow 不止一个 CLAUDE.md。完整的 AI Agent 指导文件矩阵：

| 文件 | 行数 | 目标 Agent | 覆盖范围 |
|------|------|-----------|---------|
| `backend/CLAUDE.md` | 523 | Claude Code | 后端完整架构 |
| `backend/AGENTS.md` | 2 | Codex/其他 | 指向 CLAUDE.md |
| `frontend/CLAUDE.md` | 89 | Claude Code | 前端架构 |
| `frontend/AGENTS.md` | 105 | Codex/其他 | 前端架构 + 交互所有权 |
| `.github/copilot-instructions.md` | 213 | GitHub Copilot | 全栈操作指南 |

三份文件的侧重点不同：

- **backend/CLAUDE.md**：深度架构知识，适合需要做代码修改的场景
- **frontend/AGENTS.md**：明确标注了"交互所有权"（Interaction Ownership），即哪个文件负责哪个 UI 行为，这对前端 AI 助手特别重要
- **copilot-instructions.md**：运维导向，验证命令序列、故障排查、命令执行顺序——适合不深入代码但需要执行构建/测试的场景

`backend/AGENTS.md` 只有 2 行，纯粹是一个指针：

```markdown
For the backend architecture and design patterns:
@./CLAUDE.md
```

这说明项目团队意识到不同的 AI Agent（Claude Code vs Codex vs Copilot）读取不同的文件名，用 `AGENTS.md` 做跳转来统一入口。

### 1.5 copilot-instructions.md 的独特价值

`.github/copilot-instructions.md`（213 行）的设计理念与 CLAUDE.md 截然不同。它不关心架构细节，而是关心"**验证过的命令序列**"：

```markdown
## 3) Build/Test/Lint/Run - Verified Command Sequences

These were executed and validated in this repository.
```

每个命令都附带了"Observed"注释——即实际执行时观察到的输出。比如：

```markdown
- `make lint`: pass (`ruff check .`)
- `make test`: pass (`277 passed, 15 warnings in ~76.6s`)
```

它还专门有一节"Non-Obvious Dependencies and Gotchas"（`copilot-instructions.md:180-186`），列出了容易踩的坑：

```markdown
- Proxy env vars can silently break frontend network operations
- `BETTER_AUTH_SECRET` is effectively required for reliable frontend build
- `make config` is non-idempotent by design
```

这种"操作手册"风格的文档对 AI Agent 来说比架构文档更实用——它减少了"试错"的次数。

## 二、Harness/App 分层——从设计到强制

### 2.1 设计文档

`backend/docs/HARNESS_APP_SPLIT.md`（343 行）是一份完整的架构决策记录（ADR），记录了将后端从单一 `src/` 包拆分为 `deerflow-harness` + `app/` 两层的全过程。

核心动机很清晰（`HARNESS_APP_SPLIT.md:9-14`）：

> - **复用困难**：其他产品想用 agent 能力，必须依赖整个后端
> - **职责模糊**：agent 编排逻辑和用户产品逻辑混在同一个 src/ 下
> - **依赖膨胀**：LangGraph Server 不需要 FastAPI/uvicorn/Slack SDK

分层原则是：

- **Harness**：回答"如何构建和运行 agent"，可独立发布为 PyPI 包
- **App**：回答"如何将 agent 呈现给用户"，不打包、不发布

**边界划分表**（`HARNESS_APP_SPLIT.md:52-68`）非常明确：

| 归属 | 模块 |
|------|------|
| Harness | config/, reflection/, utils/, agents/, subagents/, sandbox/, tools/, mcp/, skills/, models/, community/, client.py |
| App | gateway/, channels/ |

### 2.2 为什么 App 不打包

`HARNESS_APP_SPLIT.md:183-192` 的对比表解释了这个看似"不对称"的决策：

| 方面 | 打包 | 不打包 |
|------|------|--------|
| 命名空间 | 需要 pkgutil extend_path | 天然独立 |
| 发布需求 | 没有——App 是项目内部代码 | 不需要 pyproject.toml |
| 复杂度 | 管理两个包的构建/版本/依赖 | 直接运行 |
| 运行方式 | `pip install deerflow-app` | `PYTHONPATH=. uvicorn ...` |

这是一个务实的决策：App 的唯一消费者是 DeerFlow 项目自身，增加包管理的复杂度没有收益。

### 2.3 架构边界测试

设计文档再好，如果没有强制手段，边界迟早会被打破。`backend/tests/test_harness_boundary.py`（46 行）是 DeerFlow 的"边界防火墙"：

```python
HARNESS_ROOT = Path(__file__).parent.parent / "packages" / "harness" / "deerflow"
BANNED_PREFIXES = ("app.",)

def _collect_imports(filepath: Path) -> list[tuple[int, str]]:
    source = filepath.read_text(encoding="utf-8")
    tree = ast.parse(source, filename=str(filepath))
    results = []
    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            for alias in node.names:
                results.append((node.lineno, alias.name))
        elif isinstance(node, ast.ImportFrom):
            if node.module:
                results.append((node.lineno, node.module))
    return results

def test_harness_does_not_import_app():
    violations = []
    for py_file in sorted(HARNESS_ROOT.rglob("*.py")):
        for lineno, module in _collect_imports(py_file):
            if any(module == prefix.rstrip(".") or module.startswith(prefix)
                   for prefix in BANNED_PREFIXES):
                rel = py_file.relative_to(HARNESS_ROOT.parent.parent.parent)
                violations.append(f"  {rel}:{lineno}  imports {module}")
    assert not violations, (
        "Harness layer must not import from app layer:\n" + "\n".join(violations)
    )
```

实现方式很聪明：

1. **AST 解析而非正则**：用 `ast.parse` 而不是 `grep`，不会被注释、字符串中的 `import app` 误导
2. **精确报告**：违规信息包含文件路径和行号，CI 失败时一眼就能定位
3. **单向检查**：只检查 Harness → App 方向。App → Harness 是允许的，不需要检查

这个测试在 CI 中对每个 PR 执行（通过 `backend-unit-tests.yml`），任何试图从 Harness 导入 App 代码的 PR 都会被自动拒绝。

### 2.4 历史遗留问题的解决

`HARNESS_APP_SPLIT.md:245-265` 记录了拆分前存在的两处跨层依赖：

1. `client.py` 导入了 `gateway/routers/skills.py` 中的 `_validate_skill_frontmatter` → 解决方案：提取到 `deerflow/skills/validation.py`
2. `client.py` 导入了 `gateway/routers/uploads.py` 中的文件转换逻辑 → 解决方案：提取到 `deerflow/utils/file_conversion.py`

两处都是"纯逻辑函数"被错误地放在了 App 层。提取到 Harness 层后，App 和 Harness 都能使用，且不违反依赖方向。这种"先识别违规、再系统修复"的方法比"一刀切重构"更安全。

### 2.5 实施计划

文档规划了 3 个 PR 的递进实施：

| PR | 风险 | 内容 |
|----|------|------|
| PR 1 | Low | 提取共享工具函数 |
| PR 2 | High | 物理拆分 + 全局 rename（原子操作） |
| PR 3 | Low | 边界检查 + 文档 |

风险评估务实：PR 2 是高风险的原子操作（全局 rename），风险缓解措施包括"正则精确匹配 `\bsrc\.`，review diff"。

## 三、CI/CD 管线

### 3.1 后端单元测试

`.github/workflows/backend-unit-tests.yml`（40 行）：

```yaml
on:
  push:
    branches: [ 'main' ]
  pull_request:
    types: [opened, synchronize, reopened, ready_for_review]

concurrency:
  group: unit-tests-${{ github.event.pull_request.number || github.ref }}
  cancel-in-progress: true

jobs:
  backend-unit-tests:
    if: github.event.pull_request.draft == false
    runs-on: ubuntu-latest
    timeout-minutes: 15
    steps:
      - uses: actions/checkout@v6
      - uses: actions/setup-python@v6
        with: { python-version: '3.12' }
      - uses: astral-sh/setup-uv@v7
      - run: uv sync --group dev
        working-directory: backend
      - run: make test
        working-directory: backend
```

几个设计决策：

- **Draft PR 跳过**：`if: github.event.pull_request.draft == false`，草稿 PR 不浪费 CI 资源
- **并发控制**：相同 PR 的新 push 会取消前一次运行
- **15 分钟超时**：`copilot-instructions.md` 记录的实际运行时间是 ~76.6 秒，15 分钟留了充足余量
- **uv 而非 pip**：使用 `astral-sh/setup-uv` 安装 uv，包安装速度远快于 pip

### 3.2 Lint 检查

`.github/workflows/lint-check.yml`（71 行）包含两个并行 job：

**后端 Lint**：Python 3.12 + uv + `make lint`（即 `ruff check .`）

**前端 Lint**：Node.js 22 + pnpm 10.26.2 + 三步检查：
1. `pnpm lint`（ESLint）
2. `pnpm typecheck`（`tsc --noEmit`）
3. `BETTER_AUTH_SECRET=local-dev-secret pnpm build`（完整构建验证）

前端 build 需要 `BETTER_AUTH_SECRET` 环境变量才能通过环境验证——这是 `copilot-instructions.md` 中特别标注的 gotcha。

### 3.3 Ruff 配置

`backend/ruff.toml`（13 行）简洁但考虑周全：

```toml
line-length = 240
target-version = "py312"

[lint]
select = ["E", "F", "I", "UP"]

[lint.isort]
known-first-party = ["deerflow", "app"]

[format]
quote-style = "double"
indent-style = "space"
```

**240 字符行宽**：这是一个有争议但合理的选择。Agent 系统的代码往往有长函数签名、长工具描述字符串、长链式调用。240 字符减少了不必要的换行，提升了可读性。

**known-first-party**：将 `deerflow` 和 `app` 都标记为 first-party，确保 isort 正确分组 import。这与 Harness/App 分层设计一致——虽然它们是不同的包，但在 import 排序上应该被视为同一个项目。

**规则选择**：
- `E`：pycodestyle 错误
- `F`：pyflakes（未使用的 import、未定义的变量等）
- `I`：isort（import 排序）
- `UP`：pyupgrade（Python 版本升级建议）

没有选择更激进的规则集（如 `B` bugbear 或 `C4` comprehensions），保持了"不过度约束"的平衡。

## 四、贡献指南与代码模板

### 4.1 CONTRIBUTING.md

`backend/CONTRIBUTING.md`（426 行）不仅是一份"如何提 PR"的指南，更是一份带代码模板的开发手册。

**工具开发模板**（`CONTRIBUTING.md:274-298`）：

```python
# packages/harness/deerflow/tools/builtins/my_tool.py
from langchain_core.tools import tool

@tool
def my_tool(param: str) -> str:
    """Tool description for the agent.

    Args:
        param: Description of the parameter

    Returns:
        Description of return value
    """
    return f"Result: {param}"
```

配合注册配置：

```yaml
tools:
  - name: my_tool
    group: my_group
    use: deerflow.tools.builtins.my_tool:my_tool
```

**中间件开发模板**（`CONTRIBUTING.md:302-328`）：

```python
class MyMiddleware(BaseMiddleware):
    def transform_state(self, state: dict, config: RunnableConfig) -> dict:
        return state
```

并标注了注册位置（`lead_agent/agent.py` 中的 middlewares 列表）。

**API Endpoint 模板**（`CONTRIBUTING.md:332-357`）：给出了 FastAPI router 的创建和注册方式。

**Skills 开发模板**（`CONTRIBUTING.md:390-416`）：SKILL.md 的 frontmatter 格式。

这些模板的价值在于：不仅人类开发者可以照着写，AI Agent 也能直接复制模板开始工作。

### 4.2 Commit 规范

`CONTRIBUTING.md:186-202` 定义了 Conventional Commits 风格的提交消息规范：

```
feat: add support for Claude 3.5 model

- Add model configuration in config.yaml
- Update model factory to handle Claude-specific settings
- Add tests for new model
```

前缀类型：`feat`、`fix`、`docs`、`refactor`、`test`、`chore`。

### 4.3 TDD 强制要求

`CLAUDE.md:411-427` 明确标注了 TDD 是**强制性**的：

```markdown
### Test-Driven Development (TDD) — MANDATORY

**Every new feature or bug fix MUST be accompanied by unit tests. No exceptions.**
```

这不仅是对人类开发者的要求，更是对 AI Agent 的约束——如果 AI 提交了没有测试的代码，review 时应该被拒绝。

## 五、Feature Tracking

`backend/docs/TODO.md`（34 行）记录了项目的功能路线图。

**已完成**（9 项）：沙箱延迟启动、澄清流程、上下文摘要、MCP 集成、文件上传、标题生成、Plan Mode、Vision 支持、Skills 系统。

**计划中**（7 项）：沙箱池化、认证授权、限流、监控指标、更多文档格式、Skill 市场、异步并发优化。

最后一项"异步并发优化"的细节特别有意思（`TODO.md:24-29`）：

```markdown
- Replace `time.sleep(5)` with `asyncio.sleep()` in task_tool.py
- Replace `subprocess.run()` with `asyncio.create_subprocess_shell()` in local_sandbox.py
- Replace sync `requests` with `httpx.AsyncClient` in community tools
- Replace sync `model.invoke()` with async `model.ainvoke()` in title_middleware and memory updater
- Consider `asyncio.to_thread()` wrapper for remaining blocking file I/O
- For production: use `langgraph up` (multi-worker) instead of `langgraph dev`
```

这是一份非常具体的优化清单，精确到文件和函数名。任何 AI Agent 或人类开发者都能直接开始执行。

## 六、综合评估

经过七篇文章的深度分析，我们可以从多个维度对 DeerFlow 的工程实践做一个综合评估。

### 6.1 评估矩阵

| 维度 | 评级 | 依据 |
|------|------|------|
| **上下文架构** | A | 12 个条件 section 动态提示词 + 三防线（摘要/记忆预算/工具过滤）+ tiktoken 精确计数 |
| **结构化执行** | B | 中间件链设计优秀，但部分中间件（Title、Memory）仍使用同步 LLM 调用 |
| **Agent 专业化** | B- | 主/子 Agent 的 5 重隔离做得好，但子 Agent 类型只有 2 种（general + bash），不够细分 |
| **持久化记忆** | C+ | LLM 驱动的提取和注入设计精良，但 JSON 文件存储不适合多实例部署，缺乏向量检索能力 |
| **工具生态** | A- | Skills 三层加载 + MCP 完整集成 + 社区工具，生态最丰富的开源 Agent 之一 |
| **沙箱隔离** | B+ | 双 Provider + 4 层路径安全，但 LocalSandboxProvider 无真正隔离 |
| **安全防御** | A- | 7 层死循环防御 + 路径安全 + Guardrail 框架，缺少认证授权（在 TODO 中） |
| **IM 集成** | B+ | Hub-and-Spoke 架构清晰，三平台覆盖，Feishu 渐进更新是亮点 |
| **AI Agent 协作** | A | CLAUDE.md + AGENTS.md + copilot-instructions.md 矩阵，开源项目中少见的完整实践 |
| **架构治理** | A- | Harness/App 分层 + AST 边界测试 + CI 强制，缺少更细粒度的模块边界检查 |
| **CI/CD** | B | 单元测试 + Lint 双管线，但缺少集成测试、E2E 测试、覆盖率报告 |
| **代码质量** | B+ | Ruff 格式统一，类型提示覆盖率高，但部分文件过长（feishu.py 536 行）|

### 6.2 突出优点

**1. 三层 AI Agent 指导文件**

DeerFlow 在开源项目中对"AI Agent 协作"下了很大功夫。三份不同定位的指导文件——面向代码修改的 CLAUDE.md、面向 UI 协作的 AGENTS.md、面向运维操作的 copilot-instructions.md——覆盖了 AI Agent 参与软件开发的三个主要场景。

**2. AST 级架构边界强制**

不靠文档约定或 Code Review 人力来维护边界，而是用自动化测试 + CI 强制。46 行 Python 代码保护了一个关键的架构决策。

**3. 完整的设计文档**

`HARNESS_APP_SPLIT.md` 记录了从动机到替代方案比较、跨层依赖修复方案、分 PR 实施计划到风险评估的完整决策链条。后来的维护者不用猜"为什么这样设计"。

**4. 可执行的贡献模板**

CONTRIBUTING.md 中的代码模板可以直接复制粘贴开始开发，不是伪代码。这降低了新贡献者（人类或 AI）的上手成本。

### 6.3 改进空间

**1. 测试覆盖度**

CI 运行的是单元测试（277 个），但缺少：
- 集成测试（Agent 端到端执行）
- E2E 测试（IM 通道 → Agent → 回复 的完整链路）
- 覆盖率报告和门槛

`frontend/CLAUDE.md:23` 直言："No test framework is configured。" 前端完全没有测试。

**2. 记忆系统的扩展性**

JSON 文件存储在单实例场景下够用，但：
- 多实例部署时缺乏并发控制（原子 rename 只保证单机原子性）
- 没有向量检索能力，facts 只能做文本匹配去重
- 100 条 facts 上限可能不够长期使用的场景

**3. 异步一致性**

TODO.md 中列出的异步优化清单说明，项目中仍有不少同步阻塞调用（`time.sleep`、`subprocess.run`、`model.invoke`）。在 IM 通道的多并发场景下，这些阻塞调用会成为性能瓶颈。

**4. 模块边界的颗粒度**

当前只有一个"Harness 不能导入 App"的边界检查。随着项目增长，可能需要更细粒度的模块依赖规则——比如"sandbox 不应该导入 memory"、"tools 不应该导入 subagents"等。

### 6.4 DeerFlow 的工程哲学

通过七篇文章的分析，DeerFlow 的工程哲学可以总结为几个关键词：

**务实**：JSON 文件而非数据库、LocalSandbox 而非强制 Docker、30 秒防抖而非实时更新。每个选择都在"够用"和"过度工程"之间找到了平衡。

**可观测**：CLAUDE.md 详尽到可以不看代码就理解架构；TODO.md 具体到文件名和函数名；边界测试的错误信息精确到行号。

**渐进式**：Harness/App 分层通过 3 个 PR 递进执行；Skills 通过三层加载渐进暴露复杂度；IM 通道从简单（Telegram 长轮询）到复杂（Feishu 渐进卡片）覆盖不同需求。

**AI-first**：不是"项目做好了，顺便写个 CLAUDE.md"，而是"CLAUDE.md 是项目工程实践的核心组件"。文档更新被标记为 CRITICAL，与代码变更同等重要。

## 七、系列总结

七篇文章走完了 DeerFlow 的完整技术栈：

| 篇目 | 主题 | 核心发现 |
|------|------|---------|
| [第一篇](/posts/deerflow-01-chat-request-lifecycle) | 请求生命周期 | 四服务架构、Chat 不经过 Gateway、Agent Loop 5 步循环 |
| [第二篇](/posts/deerflow-02-prompt-engineering-context) | 提示词工程 | 12 个条件 section 动态组装、上下文三防线 |
| [第三篇](/posts/deerflow-03-multi-agent-collaboration) | 主从 Agent | 5 重隔离、7 层死循环防御、双线程池模型 |
| [第四篇](/posts/deerflow-04-skills-mcp-tools) | 工具生态 | Skills 三层加载、MCP 完整集成、工具 7 层分组 |
| [第五篇](/posts/deerflow-05-sandbox-isolation) | 沙箱隔离 | 双 Provider、虚拟路径系统、4 层路径安全 |
| [第六篇](/posts/deerflow-06-memory-im-channels) | 记忆与 IM | LLM 驱动记忆、30s 防抖、Hub-and-Spoke 消息总线 |
| 第七篇（本文） | 工程实践 | AI Agent 指导文件矩阵、AST 边界测试、综合评估 |

DeerFlow 作为一个开源 AI Agent 系统，在工程实践上做到了"认真"二字。它不是一个只关心 demo 效果的项目，而是一个认真思考过"如何让多人（包括 AI）安全协作"的工程化产品。对于正在构建 Agent 系统的团队，这套工程实践的参考价值不亚于它的技术实现本身。
