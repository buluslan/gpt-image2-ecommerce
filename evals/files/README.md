# evals/files/ — 测试用产品图占位目录

本目录存放 `evals/evals.json` 中各条 eval 引用的测试输入产品图。

## 当前状态：占位

**目前目录内无真实图片**，所有 eval 的 `files` 字段引用的均为占位路径。
在跑通完整评估闭环前，需补充以下真实产品图（建议 1024x1024 或更大的电商产品照）：

| 占位文件名 | 引用 eval | 建议内容 |
|---|---|---|
| `waist-belt.jpg` | eval #1 amazon-main-image-compliance | 护腰带产品照（医疗/健康品类，验证主图合规） |
| `protein-powder.jpg` | eval #2 campaign-set-consistency | 蛋白粉罐产品照（验证 5 张套图一致性） |
| `earbuds.jpg` | eval #3 infographic-text-accuracy | 蓝牙耳机产品照（验证卖点文字渲染） |
| `tumbler-black.jpg` | eval #4 variant-consistency | 黑色保温杯产品照（验证 8 色变体一致性） |
| `sheet-mask.jpg` | eval #5 ugc-anti-ai | 面膜产品照（验证反 AI 感 UGC 风格） |
| `mechanical-keyboard.jpg` | eval #6 style-blacklist-trigger | 机械键盘产品照（3C 品类，验证风格黑名单） |
| `aroma-diffuser.jpg` | eval #7 lifestyle-scene-natural | 香薰机产品照（验证生活方式场景） |
| `coffee-beans.jpg` | eval #8 packaging-premium-quality | 咖啡豆/包装产品照（验证包装质感） |
| `mine.jpg` | eval #10 bulk-product-swap | 待替换进去的自有产品图 |
| `competitor-1.jpg` … `competitor-7.jpg` | eval #10 bulk-product-swap | 一套有合法使用权的版式参考图 |

## 补图指南

1. 图片应为**清晰的产品照**（白底或简单背景，产品为主体），模拟真实卖家会提供的素材
2. 建议尺寸 ≥ 1024x1024（GPT-Image-2 参考图输入）
3. 格式 JPG/PNG 均可
4. 放入本目录后，文件名需与上表一致（evals.json 中 `files` 路径为 `evals/files/<name>.jpg`）
5. 可使用公开版权的电商样图或自拍产品照，**避免使用有版权的竞品实拍图**

## 为什么需要真实图

- **eval #1/#3/#4/#5/#6/#7/#8** 都依赖参考图做产品保真（外形/材质/颜色一致性）
- 无参考图时，GPT-Image-2 会"凭空想象"产品外形，无法验证保真度这一核心质量维度
- 跑 `with_skill vs baseline` 对比时，两边需用相同输入图才有可比性
