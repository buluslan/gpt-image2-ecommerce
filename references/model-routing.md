# Model Routing · GPT-Image-2.5 双模型选型与参数指南

> 何时读：组装完 prompt、调用 imagegen.sh 之前——决定 `IMAGE_MODEL`（或 `--quality`）。
> 依据：OpenAI 官方 prompting guide（2026-09 迁移建议）+ 多家社区 cookbook 的一致用法。
> 原则：**skill 不替用户锁通道，但替用户做模型选型判断**——选错模型等于白花钱。

## 一、Flare vs Sunburst（一张表定夺）

| | `gpt-image-2.5-flare` | `gpt-image-2.5-sunburst` |
|---|---|---|
| 官方定位 | small model，速度优先（比 2.0 延迟低 50%） | base model，质量优先（画质**超过** 2.0） |
| 画质 | **与 GPT-Image-2 相当**（不是升级项！） | 2.5 真正的画质升级档 |
| 擅长 | 从零生成、批量草稿、多变量探索 | 精修编辑：保产品/标签/logo 不动，多轮修改不降质 |
| 何时用 | 套图初稿、多变体 SKU、A/B 风格探索、漏斗上层试错 | **定稿出图**、edit 矩阵全部场景、透明抠图、A+/信息图文字密集图 |

**选型三问**（按顺序）：
1. 这张图要「保住原有产品的某个细节」（标签/logo/形状）吗？→ 是 → **sunburst**
2. 这是最终交付图吗（直接上 listing / 投放）？→ 是 → **sunburst**
3. 只是过程稿 / 批量探索？→ **flare**

官方原文口径："flare covers most everyday generation; sunburst is the one to pick when an edit must keep an object, a logo or a product label intact across iterations."

## 二、Quality 档位（2.5 新增 xhigh/max）

`low / medium / high / xhigh / max / auto`（默认 auto）

- **批量草稿**：low/medium（flare 配 low，速度成本双优）
- **常规出图**：high（大多数场景的性价比点）
- **xhigh/max**：只给最终定稿的精修场景（文字密集的信息图/A+、保标签编辑）；档位越高 token 消耗越大——2.5 的 token 单价已是 2.0 的 **2 倍**（image 输出 $30/1M vs $15/1M），max 档要克制
- 官方迁移建议的节奏：**一次只调一个参数**，先验质量再动档位

## 三、成本心智（写给卖家的话术）

- 2.5 两模型 token 单价相同；**实际成本差异来自消耗量**（模型×quality×尺寸共同决定）——官方原话 "Equal token rates don't mean equal cost per image"
- 批量任务用「flare + low/medium」先跑通内容方向，方向定了再用「sunburst + high」出定稿——**试水档/定稿档双档位**是控制总成本的主手段
- 若走按张计费的通道（部分中转有 ext 路线），成本可预估性更好；imagegen.sh 的 envelope 会透出通道返回的 `cost` 字段，跑完看一眼
- 多格帧图（动图）默认 2K 不要上 4K——"4K 是把 2K 放大交差，多花 2.5 倍的钱"（product-motion-gif 实测结论）

## 四、官方迁移六步法（精简）

从 2.0 工作流迁到 2.5 时：

1. 存好 2.0 baseline（含难例：精确文字、产品几何、透明素材）
2. 先测一个候选模型（质量诉求 → sunburst 打头）
3. 同 prompt 完整对比：指令遵循 / 产品保真 / 文字准确性 / 无关变更 / 透明度，重复请求看稳定性
4. 质量过了再测延迟
5. 一次只调一个参数；价格以实时账单为准，别假设快的便宜
6. 按工作流灰度切换，别一刀切

## 五、与场景模板的联动

- `references/scenarios/*.json` 的 `model_hint` 字段（部分模板携带）给出该场景的建议模型——edit 类模板一律 sunburst，质量敏感类（A+/信息图/杂志/品牌故事）sunburst，其余默认 flare
- `model_hint` 是建议不是强制：用户的通道若只有 2.0 模型（`gpt-image-2`），路由逻辑照常工作，只是放弃 2.5 增益
- 调用侧：`IMAGE_MODEL` 环境变量或请求 JSON 的 `model` 字段最终决定——编排层把建议写进组装说明，通道层尊重用户配置
