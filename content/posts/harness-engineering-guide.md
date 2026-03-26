---
title: Harness Engineering 实践指南：让 AI Agent 可靠地写代码
date: 2026-03-26T16:00:00+08:00
draft: false
tags:
  - AI
  - 技术
---

2026 年 2 月，"Harness Engineering"这个词在 AI 工程圈突然火了。Mitchell Hashimoto 在博客里首次命名，OpenAI 紧接着发了百万行代码的实验报告，Anthropic 和 Martin Fowler 相继跟进。几周之内，它成了讨论 AI Agent 开发绕不开的话题。

这篇文章把 Harness Engineering 的核心概念和实战经验做一次精简梳理，帮你理解它是什么、为什么重要，以及怎么落地。

## 一、Harness 是什么

Harness 本意是马具——缰绳、鞍具那一套东西，把马的力气引到正确方向上。用来类比 AI Agent 很合适：LLM 就像一匹蛮力十足但方向感不太行的马，跑得快但容易跑偏。

**Harness Engineering 是围绕 AI Coding Agent 设计约束机制、反馈回路、工作流控制和持续改进循环的系统工程实践。**

它和 Prompt Engineering、Context Engineering 构成嵌套关系：

- **Prompt Engineering** — 怎么跟模型说话
- **Context Engineering** — 给 Agent 看什么
- **Harness Engineering** — 系统怎么防崩、怎么量化、怎么修

Phil Schmid 打了个比方：模型是 CPU，Harness 是操作系统。CPU 再强，OS 拉胯也白搭。

## 二、Agent 为什么会翻车

别急着纠结选哪个模型。Can.ac 的实验给出了一个惊人的数据：**仅改变 Harness 的工具格式（编辑接口），就让 Grok Code Fast 1 从 6.7% 跃升至 68.3%**——没有修改任何模型权重。LangChain 也验证了类似结论：同一模型靠 Harness 改进在 Terminal Bench 2.0 上从第 30 名跳到第 5 名。

瓶颈不在模型智能，而在基础设施。

Anthropic 在做长时间运行 Agent 的过程中，总结了四种典型的翻车模式：

**1. 一步到位。** Agent 试图一次做完所有事情，上下文窗口耗尽后留下半成品和没有文档的代码。下个会话启动时只能花大量时间猜测之前发生了什么。

**2. 过早宣布完成。** 项目后期，Agent 看到已有进展就直接宣布任务结束——即使还有大量功能未实现。

**3. 不测试就标记完成。** 写完代码就算 done，单元测试通过不代表功能端到端可用。

**4. 环境启动困难。** 每次新会话花大量 token 弄清楚怎么跑项目，而不是把时间花在实际开发上。

另一个关键经验来自 Dex Horthy：**上下文窗口利用率存在甜蜜区间，大约 40% 就开始走下坡路**。超过这个阈值，给 Agent 塞再多工具和文档只会让它变笨，而不是变聪明。

这些都不是模型能力问题，是工程结构问题。Harness 解决的就是这些事。

## 三、四大支柱

综合 OpenAI、Anthropic、Stripe 等多个独立团队的实践，四种模式反复出现并形成收敛。

### 支柱一：上下文架构

> Agent 应当恰好获得当前任务所需的上下文——不多不少。

所有团队都发现，把所有指令塞进一个文件无法扩展。解决方案是分层上下文与渐进式披露：

| 层级 | 加载时机 | 内容示例 | 占用 |
|------|---------|---------|------|
| Tier 1 | 每次会话自动加载 | `AGENTS.md`、项目结构概览 | 最小 |
| Tier 2 | 特定子 Agent 调用时 | 专业化 Agent 上下文、领域知识 | 中等 |
| Tier 3 | Agent 主动查询时 | 设计文档、规格说明、历史记录 | 按需 |

核心思路：让 Agent 在 Smart Zone（上下文 < 40%）内工作，而不是把它推进 Dumb Zone。

### 支柱二：Agent 专业化

> 专注特定领域、拥有受限工具的 Agent，优于拥有全部权限的通用 Agent。

专业化本身就是上下文管理策略——每个 Agent 携带更少无关信息，自然运行在 Smart Zone 内。实践中的角色分工：

| 角色 | 职责 | 工具权限 |
|------|------|---------|
| 研究 Agent | 探索代码库、分析实现 | 只读 |
| 规划 Agent | 需求分解为任务 | 只读 |
| 执行 Agent | 实现单个具体任务 | 限定范围读写 |
| 审查 Agent | 审计完成的工作 | 只读 + 标记 |
| 清理 Agent | 对抗熵积累 | 读写 |

Carlini 在用 16 个 Claude 实例构建 C 编译器时，就是随着项目成熟逐步拆分出编译器核心、去重、性能优化、文档四类角色。

### 支柱三：持久化记忆

> 进度持久化在文件系统上，而非上下文窗口中。

每次新 Agent 会话从零开始，通过文件系统制品重建上下文。关键实践：

- 用 **JSON 而非 Markdown** 追踪 feature 状态——Agent 不太会错误修改结构化数据
- 每次会话结束时提交 git commit + 更新进度文件
- 新会话启动时先读 git log + 进度文件重建上下文

### 支柱四：结构化执行

> 将思考与执行分离。

所有团队都施加了刻意的执行序列：**理解 -> 规划 -> 执行 -> 验证**。

Boris Tane 的原则最简洁："永远不要让 Agent 在你审查和批准书面计划之前写代码。"审查计划远比审查代码快。当规格正确时，实现自然可靠；当规格有误时，可以在写出 500 行代码之前及时纠正。

## 四、Anthropic 的双阶段方案

这是目前最完整、最可复制的长时间运行 Agent 实战模式，值得单独展开。

核心问题：Agent 必须在离散会话中工作，每个新会话对之前发生的事一无所知。就像一个全员轮班、交接时零记忆的工程团队。

### 初始化 Agent（首次会话）

用专门的 prompt 要求模型建立初始环境：

- 生成 `init.sh` 脚本（启动开发服务器）
- 创建 `claude-progress.txt` 进度日志
- 基于高级 prompt 生成结构化 feature list（200+ 个功能，全部标记为 failing）
- 做初始 git commit

Feature list 的数据结构示例：

```json
{
  "category": "functional",
  "description": "New chat button creates a fresh conversation",
  "steps": [
    "Navigate to main interface",
    "Click the 'New Chat' button",
    "Verify a new conversation is created",
    "Check that chat area shows welcome state",
    "Verify conversation appears in sidebar"
  ],
  "passes": false
}
```

### 编码 Agent（后续每次会话）

每次会话有固定的启动流程：

1. `pwd` 确认工作目录
2. 读 git log + 进度文件，了解最近工作
3. 读 feature list，选最高优先级的未完成功能
4. 启动开发服务器，跑基础端到端测试
5. 确认基础功能正常后，开始新功能开发

会话结束时：提交 git commit（描述性消息）+ 更新进度文件，留下干净状态。

### 几个关键技巧

- **严禁删改测试项。** prompt 中明确写 "It is unacceptable to remove or edit tests"，防止 Agent 通过降低标准来"完成"任务。
- **每次先验证再开发。** 先确认 app 没坏，再做新功能。否则 Agent 会在已有 bug 上叠加更多问题。
- **提供浏览器自动化工具。** 通过 Puppeteer MCP 让 Agent 像人类一样做端到端测试，能发现代码层面看不到的 bug。

## 五、落地 Checklist

按优先级分三档，从本周就能做的事情开始。

### P0：本周就能做

**创建 `AGENTS.md` 反馈循环。** 仓库根目录放一个 Markdown 文件，写入项目结构、编码规范、架构约束。核心原则：每当 Agent 犯错就更新这个文件。Hashimoto 的 Ghostty 项目里，这个文件的每一行都对应一个历史失败案例——文档变成了"错误疫苗库"。

**自定义 Linter + 错误消息嵌入修复指令。** 传统 Linter 只说"你违规了"。给 Agent 用的 Linter 要同时说"怎么修"。例如：`ERROR: Service layer cannot import from UI. Move this type to Types layer. See docs/architecture.md`。这样工具在 Agent 工作时同时"教会"它。

**CI 作为强制执行层。** 自动化测试、类型检查、Lint 跑在 CI 上。文档里写"不要这样做"没用——如果不能机械化执行，Agent 就会偏离。

### P1：一两周内搭建

**JSON 格式的进度文件 + feature list。** 参考 Anthropic 方案，用结构化 JSON 追踪状态而非 Markdown。

**分层上下文体系。** 把 Tier 1/2/3 的上下文分离，避免把所有信息堆在一个文件里。

**思考与执行分离的工作流。** 强制 Agent 走 Research -> Plan -> Implement -> Verify 流程，规划阶段输出计划文件，审核后才执行。

### P2：成熟后演进

**Agent 角色专业化。** 按研究/规划/执行/审查/清理拆分角色，限定工具权限。

**熵管理 Agent。** 定期跑后台 Agent 清理低质量代码、检查文档一致性。OpenAI 的经验：清理吞吐量要与生成吞吐量成比例。

**可观测性集成。** 给 Agent 接入浏览器自动化（Puppeteer MCP）、日志查询、指标查询，让性能目标变得可度量。

## 六、最后几句话

Harness Engineering 标志着 AI 辅助开发从"让模型写代码"到"设计让模型可靠工作的系统"的范式转变。

有三个判断值得记住：

**模型越强，Harness 越重要。** Carlini 的 C 编译器项目证明了这一点——Opus 4.5 能产出能用的编译器，Opus 4.6 能编译 Linux 内核，但每个能力级别都得重新设计 Harness。

**Harness 应趋向简化。** Manus 团队半年重写五次 Harness，每次方向都是简化。如果越做越复杂，大概率是过度工程化了。

**三个开放问题仍待解答。** 棕地项目如何改造（零成功案例）、功能验证如何系统化（擅长"约束不做错事"但不擅长"验证做对了事"）、AI 代码的长期可维护性（技术债积累方式不同于人类代码）。

用 Addy Osmani 的话收尾："AI 编码的兴起并没有取代软件工程的工艺——它抬高了工艺的门槛。"

工程师的核心工作正在转变：从写代码，到设计让 AI 可靠地写代码的系统。
