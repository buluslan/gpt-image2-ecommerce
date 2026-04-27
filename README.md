<div align="center">

<!-- Banner image placeholder - will be replaced after generation -->
<img src="https://github.com/buluslan/gpt-image2-ecommerce/raw/main/assets/banner.png" alt="E-Commerce Image Generator" width="100%">

# E-Commerce Image Generator

**可在任意Agent上驱动 GPT-Image-2 生成电商素材的一键生成工具Skill**

**想了解更多最新AI行业动态，AI+电商/广告的行业实践方法，人与AI如何协作共生的思考，请关注公众号：【新西楼】**
![qrcode_for_gh_e3b954bd3859_258](https://github.com/user-attachments/assets/d8f068d9-c4f8-46c7-914c-fbcab5d52f2a)

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Version](https://img.shields.io/badge/version-0.1.0-black.svg)]()
[![Codex CLI](https://img.shields.io/badge/Codex-CLI-orange.svg)](https://github.com/openai/codex)

**25个电商场景模板 | 智能模板匹配 | 参考图一致性 | 反AI感处理**

**Created By Buluu@新西楼**

</div>

---

## 项目简介

E-Commerce Image Generator 是一款基于 GPT-Image-2 的电商素材图片生成工具，通过 Codex CLI 调用生图能力。内置 **25 个专业电商场景的结构化提示词模板**，用自然语言描述需求即可自动匹配模板并生成高质量素材图。

**兼容性广泛**：本工具基于 Codex CLI 命令行调用，可在任何能执行 shell 命令的 AI Agent 中使用：
- Claude Code（作为 Skill 加载）
- OpenClaw
- Cursor
- Windsurf
- 直接终端命令行

只要环境安装了 [Codex CLI](https://github.com/openai/codex)，任何 Agent 都可以直接调用 `codex exec` 命令使用这些模板生成图片。

---

## 核心特性

### 25 个电商场景模板

全面覆盖电商视觉素材需求：

| # | 场景 | 触发词示例 |
|---|------|-----------|
| 01 | 白底/纯色主图 | 白底图, 主图, hero image |
| 02 | 生活场景图 | 场景图, 生活图, lifestyle |
| 03 | 平铺图 | 平铺图, flat lay, 俯拍 |
| 04 | 细节微距 | 细节图, 微距, macro |
| 05 | 海报/Banner | 海报, poster, banner, 促销 |
| 06 | 社交媒体 | 小红书, Instagram, TikTok |
| 07 | UGC 买家秀 | UGC, 买家秀, GRWM |
| 08 | 模特展示 | 模特, model, 人物展示 |
| 09 | 使用前后对比 | 对比, before after |
| 10 | 包装设计 | 包装, packaging, 礼盒 |
| 11 | 信息图/A+ | 信息图, A+, 详情页 |
| 12 | 创意概念广告 | 创意, 概念, creative |
| 13 | 尺寸规格图 | 尺寸, 规格, 使用步骤 |
| 14 | 多产品套装 | 套装, 组合, bundle |
| 15 | 直播间场景 | 直播, livestream |
| 16 | 虚拟试穿 | 试穿, 融入, try on |
| 17 | 技术拆解图 | 拆解图, 爆炸图, exploded view |
| 18 | 隐形模特 | 隐形模特, ghost mannequin |
| 19 | 多角度网格 | 多角度, 网格, grid |
| 20 | 杂志封面 | 杂志, 封面, editorial |
| 21 | 季节营销 | 季节, 四季, campaign |
| 22 | 奢华氛围 | 奢华, 氛围, 烟雾, luxury |
| 23 | 设备模型 | mockup, SaaS, APP |
| 24 | 店铺门面 | 店铺, 门面, storefront |
| 25 | 运动广告 | 运动, 健身, sports |

### 智能模板匹配

自然语言描述 → 自动匹配最佳模板 → 组装精简 Prompt → 调用生图

### 参考图支持

传入产品白底图，保持品牌和产品外观一致性，生成结果更可靠。

### 反 AI 感处理

UGC、直播间、社交媒体场景内置 CCD 复古胶片质感、可见瑕疵等反 AI 处理，让素材更真实。

### 风格变体

每个场景提供 4 种风格变体，例如运动广告：产品主视觉 / 运动员动态 / 三联画 / 健身力量感。

---

## 快速开始

### 前置要求

- [Codex CLI](https://github.com/openai/codex) 已安装并登录
- （可选）Claude Code 用于 Skill 模式自动匹配

### 安装

```bash
git clone https://github.com/buluslan/gpt-image2-ecommerce.git
```

### 使用方式一：在 Agent 中（推荐）

在 Claude Code / OpenClaw 等支持 Skill 的 Agent 中，直接描述需求：

```
帮我生成一张电动自行车的运动广告图，暗色背景，速度感
```

```
做一组护肤品白底主图，高端感
```

```
咖啡豆的平铺图，温暖色调
```

Agent 会自动匹配模板、组装 prompt、调用 Codex CLI 生成图片。

### 使用方式二：直接命令行

```bash
# 无参考图
codex exec --ephemeral --skip-git-repo-check --sandbox read-only --color never - <<< "Use imagegen to create an image with this request:
{
  \"type\": \"product photography\",
  \"subject\": \"frosted glass serum bottle with matte white cap\",
  \"background\": \"clean white background\",
  \"lighting\": \"soft diffused studio lighting\",
  \"quality\": \"8K, commercial e-commerce photography\"
}"

# 带参考图
codex exec --ephemeral --skip-git-repo-check --sandbox read-only --color never \
  --image /path/to/product.png \
  - <<< "Use imagegen to create an image with this request:
{...prompt JSON...}

Reference image(s) are attached."
```

---

## 项目结构

```
gpt-image2-ecommerce/
├── SKILL.md                        # Skill 入口（Claude Code 工作流定义）
├── README.md                       # 项目说明
├── LICENSE                         # MIT 许可证
├── scripts/
│   └── imagegen.sh                 # Codex CLI 调用脚本（混合模式）
└── references/
    └── templates/                  # 25 个场景提示词模板（JSON）
        ├── 01-hero-image.json      # 白底主图
        ├── 02-lifestyle-scene.json # 生活场景
        ├── ...
        └── 25-sports-campaign.json # 运动广告
```

## 工作原理

```
用户输入（自然语言 + 可选产品图）
    → 意图识别（场景类型 + 产品信息 + 风格偏好）
    → 模板匹配（从 25 个模板中匹配最佳）
    → Prompt 组装（填充变量 + 应用变体 + 精简输出）
    → 调用生图（codex exec / HTTP 服务）
    → 返回结果（清理临时文件 + 优化建议）
```

## Prompt 编写原则

- **简洁为王**：只传核心信息，不过度约束
- **自然语言优先**：Image2 理解描述性句子优于关键词堆砌
- **材质描述**：明确写出纹理（磨砂玻璃、拉丝金属、哑光质感）
- **光照很重要**：始终包含光照方向和质感
- **善用参考图**：传入产品图可显著提升一致性

## 许可证

[MIT License](LICENSE) - 详见 LICENSE 文件

## 联系方式

**Buluu@新西楼**

- **公众号**：新西楼 — AI+电商/广告行业实践，人与AI协作思考
- **GitHub Issues**：https://github.com/buluslan/gpt-image2-ecommerce/issues

---

如果这个项目对您有帮助，请给一个 ⭐️

[![GitHub Stars](https://img.shields.io/github/stars/buluslan/gpt-image2-ecommerce?style=social)](https://github.com/buluslan/gpt-image2-ecommerce/stargazers)
