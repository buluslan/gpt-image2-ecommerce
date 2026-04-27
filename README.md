<div align="center">

# E-Commerce Image Generator

**GPT-Image-2 驱动的电商素材一键生成 Claude Code Skill**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Version](https://img.shields.io/badge/version-0.1.0-black.svg)]()
[![Claude Code](https://img.shields.io/badge/Claude-Code-blue.svg)](https://claude.ai/code)

</div>

---

## 概述

通过 Claude Code 调用 GPT-Image-2（via Codex CLI），用自然语言描述需求即可自动匹配提示词模板并生成电商素材图片。内置 **25 个专业电商场景模板**，覆盖从产品白底图到运动广告的全链路视觉需求。

**适用场景**：电商产品图、社交媒体素材、品牌广告图、促销海报、包装设计等

## 核心特性

- **25 个电商场景模板**：白底主图、生活场景、平铺图、细节微距、海报 Banner、社交媒体、UGC 买家秀、模特展示、使用对比、包装设计、信息图、创意概念、尺寸规格、套装组合、直播间、虚拟试穿、拆解图、隐形模特、多角度网格、杂志封面、季节营销、奢华氛围、设备模型、店铺门面、运动广告
- **智能模板匹配**：自然语言描述 → 自动匹配最佳模板
- **参考图支持**：传入产品白底图，保持品牌一致性
- **风格变体**：每个场景提供 4 种风格变体可选
- **反 AI 感**：UGC/直播/社交媒体场景内置 CCD 复古、胶片质感等反 AI 处理
- **混合调用模式**：自动检测 HTTP 服务，CLI/HTTP 无缝切换

## 快速开始

### 前置要求

- [Claude Code CLI](https://claude.ai/code) 已安装并登录
- [Codex CLI](https://github.com/openai/codex) 已安装

### 安装

将本仓库克隆到本地，然后在 Claude Code 中加载 skill：

```bash
git clone https://github.com/buluslan/gpt-image2-ecommerce.git
```

### 使用

在 Claude Code 中描述你的需求即可：

```
帮我生成一张电动自行车的运动广告图，要暗色背景，速度感
```

```
生成一组护肤品白底主图，要有高级感
```

```
做一张咖啡豆的平铺图，温暖色调
```

Claude 会自动匹配模板、组装 prompt、调用 Codex CLI 生成图片。

## 支持的场景

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

## 项目结构

```
gpt-image2-ecommerce/
├── SKILL.md                        # Skill 入口（工作流定义）
├── README.md                       # 项目说明
├── LICENSE                         # MIT 许可证
├── scripts/
│   └── imagegen.sh                 # Codex CLI 调用脚本（混合模式）
└── references/
    └── templates/                  # 25 个场景提示词模板
        ├── 01-hero-image.json
        ├── 02-lifestyle-scene.json
        ├── ...
        └── 25-sports-campaign.json
```

## 工作原理

```
用户输入（自然语言 + 可选产品图）
    → 意图识别（场景类型 + 产品信息 + 风格偏好）
    → 模板匹配（从 25 个模板中匹配最佳）
    → Prompt 组装（填充变量 + 应用变体 + 精简输出）
    → 调用生图（Codex CLI / HTTP 服务）
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

## 作者

**Buluu@新西楼**

---

如果这个项目对您有帮助，请给一个 ⭐️

[![GitHub Stars](https://img.shields.io/github/stars/buluslan/gpt-image2-ecommerce?style=social)](https://github.com/buluslan/gpt-image2-ecommerce/stargazers)
