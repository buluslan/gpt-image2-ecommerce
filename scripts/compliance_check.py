#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ecom-image2 合规质检脚本

对生成的电商图片做 3 项主图技术规范检测：
  1. 背景白度   — 采样四角 + 四边边缘 RGB，判断是否接近纯白 RGB(255,255,255)
  2. 前景占比   — 区分前景/背景，算前景像素占比（Amazon 主图要求 ≥85%）
  3. OCR 文字   — 扫描图中是否有文字（Amazon 主图要求无文字）

设计原则：
  - 「告警」非「阻断」：先积累真实数据再调阈值
  - 隐形合规：只检测不修改画面
  - 零硬依赖：只用 Pillow + Python 标准库；numpy 故意不依赖（很多卖家环境 numpy 架构不匹配）
  - OCR 可选降级：无 tesseract / pytesseract 时跳过该项，不报错

────────────────────────────────────────────────────────────────────────────────
依赖：
  必需：Pillow       (pip install Pillow)        — 图像处理
  可选：pytesseract  (pip install pytesseract)   — OCR 文字扫描
        tesseract    (brew install tesseract)    — pytesseract 的后端二进制
  无 tesseract 时脚本仍可跑（只做白度+占比），stderr 提示「OCR skipped」。

────────────────────────────────────────────────────────────────────────────────
用法：
  python3 compliance_check.py <image_path>
  python3 compliance_check.py <image_path> --platform amazon
  python3 compliance_check.py <image_path> --platform amazon --strict
  python3 compliance_check.py --help

输出：stdout 一个 JSON envelope
  {
    "ok": bool,                      # 是否全部通过（violations 为空）
    "platform": "amazon",
    "image": "/path/to/img.png",
    "checks": {
      "white_bg":        { "status": "pass|warn|fail|skipped", ... },
      "foreground_ratio":{ "status": ..., "ratio": 0.88, ... },
      "ocr_text":        { "status": ..., "text_found": false, ... }
    },
    "violations": [ "amazon: foreground ratio 0.72 < 0.85", ... ],
    "suggestions": [ "...", ... ]
  }

exit code：
  0 = 全部通过
  1 = 有违规（warning/fail，非致命）
  2 = 参数错误 / 文件不存在 / Pillow 未装

────────────────────────────────────────────────────────────────────────────────
平台阈值表（与 references/platform-constraints.md Layer 1 对齐）：
  amazon    : 白度容差 12 / 前景 ≥ 85% / 文字 = 禁止
  tiktok    : 白度容差 25 / 前景 ≥ 70% / 文字 = 允许少量（告警不阻断）
  shopify   : 不强制（info only）
  aliexpress: 同 amazon
  temu      : 同 amazon
"""

import argparse
import json
import os
import sys
from collections import Counter

# ---------------------------------------------------------------------------
# 依赖说明
# ---------------------------------------------------------------------------
# Pillow 是必需依赖（图像像素处理），但 import 延迟到 run_checks() 内部——
# 这样 --help / --version 等参数解析不依赖 Pillow，环境探查更友好。
# OCR（pytesseract + tesseract）可选，无则该项 skipped，不阻断。
#
# 常见坑：macOS 上若 Pillow 装成 x86_64（如通过 x86 python 装的），
# `from PIL import Image` 会因 C 扩展 _imaging.so 架构不匹配而 ImportError。
# 修复：用匹配架构的 python 重装 ——
#   arm64 Mac:  arch -arm64 pip3 install --force-reinstall Pillow
#   x86 Mac:    pip3 install --force-reinstall Pillow

# Image 模块的占位（真正 import 在 run_checks 内）
Image = None

# ---------------------------------------------------------------------------
# 平台阈值（单一真理源的镜像，改这里要同步改 platform-constraints.md）
# ---------------------------------------------------------------------------
# white_tolerance: RGB 与 (255,255,255) 的最大欧氏距离，<= 视为「白」
# fg_min:         前景占比下限（0-1）
# text_policy:    "forbid" = 出现文字即 fail；"warn" = 仅告警；"ignore" = 不查
PLATFORM_THRESHOLDS = {
    "amazon":     {"white_tolerance": 12, "white_bg_policy": "forbid", "fg_min": 0.85, "text_policy": "forbid"},
    "tiktok":     {"white_tolerance": 25, "white_bg_policy": "warn",   "fg_min": 0.70, "text_policy": "warn"},
    "shopify":    {"white_tolerance": 40, "white_bg_policy": "ignore", "fg_min": 0.00, "text_policy": "ignore"},
    "aliexpress": {"white_tolerance": 12, "white_bg_policy": "forbid", "fg_min": 0.85, "text_policy": "forbid"},
    "temu":       {"white_tolerance": 12, "white_bg_policy": "forbid", "fg_min": 0.85, "text_policy": "forbid"},
}

# strict 模式：阈值更紧（白更纯、占比更高）
STRICT_OVERRIDES = {
    "amazon":     {"white_tolerance": 6,  "fg_min": 0.90},
    "tiktok":     {"white_tolerance": 12, "fg_min": 0.80},
    "shopify":    {"white_tolerance": 20, "fg_min": 0.00},
    "aliexpress": {"white_tolerance": 6,  "fg_min": 0.90},
    "temu":       {"white_tolerance": 6,  "fg_min": 0.90},
}

# 采样参数
FG_RESIZE_TO = 300            # 前景占比/背景探测计算前缩放到此尺寸（加速，保持精度够用）
FG_TOLERANCE_BOOST = 18       # 前景判定容差相对背景基准的增量


# ---------------------------------------------------------------------------
# 工具函数
# ---------------------------------------------------------------------------
def color_distance(rgb1, rgb2):
    """两个 RGB 元组的欧氏距离（不依赖 numpy）。"""
    return (
        (rgb1[0] - rgb2[0]) ** 2
        + (rgb1[1] - rgb2[1]) ** 2
        + (rgb1[2] - rgb2[2]) ** 2
    ) ** 0.5


def average_rgb(pixels):
    """对一组 [(r,g,b), ...] 求平均 RGB。"""
    n = len(pixels)
    if n == 0:
        return (255, 255, 255)
    r = sum(p[0] for p in pixels) // n
    g = sum(p[1] for p in pixels) // n
    b = sum(p[2] for p in pixels) // n
    return (r, g, b)


def detect_background_base(img_rgb, w, h):
    """
    用「最外圈像素环」的众数确定「实际背景色」基准。

    关键设计：取画面最外圈 1-2px 的像素（上/下/左/右四条边），
    而不是四角方块。因为产品在画面中央，背景在边缘——
    即使产品占 85%+（合规主图），最外圈仍是背景白边；
    而四角方块采样在产品贴边时会被产品色主导。

    Amazon 主图理想背景是 (255,255,255)，但实际可能有轻微偏色，
    取边缘众数做基准比硬编码纯白更准（避免偏色误判）。

    抗噪：像素 RGB 量化到 16 级再取众数。
    """
    # 缩放加速（保比例）
    img_small = img_rgb.copy()
    img_small.thumbnail((FG_RESIZE_TO, FG_RESIZE_TO))
    sw, sh = img_small.size
    if sw < 4 or sh < 4:
        return (255, 255, 255)
    data = list(img_small.getdata())

    # 取最外圈 2px 环（产品贴边 1px 时仍能多取一圈提高鲁棒性）
    ring_depth = 2
    ring_pixels = []
    for y in range(sh):
        for x in range(sw):
            if (y < ring_depth or y >= sh - ring_depth
                    or x < ring_depth or x >= sw - ring_depth):
                ring_pixels.append(data[y * sw + x])

    if not ring_pixels:
        return (255, 255, 255)

    # 量化到 16 级取众数（抗噪）
    bucket = Counter()
    for px in ring_pixels:
        key = (px[0] & 0xF0, px[1] & 0xF0, px[2] & 0xF0)
        bucket[key] += 1
    most_common_bucket = bucket.most_common(1)[0][0]
    # 把桶中心当作基准（如 240 → 248 近似；已是 240 档 → 255）
    return (
        most_common_bucket[0] + 8 if most_common_bucket[0] < 240 else 255,
        most_common_bucket[1] + 8 if most_common_bucket[1] < 240 else 255,
        most_common_bucket[2] + 8 if most_common_bucket[2] < 240 else 255,
    )


# ---------------------------------------------------------------------------
# 检测 1：背景白度
# ---------------------------------------------------------------------------
def check_white_bg(img_rgb, w, h, bg_base, tolerance):
    """
    判断「背景区域」是否接近纯白 RGB(255,255,255)。

    算法（产品大小不影响白度判断）：
      1. 缩放到固定尺寸加速
      2. 全图扫描，像素与「边缘背景基准色 bg_base」距离 < BG_IDENTIFY_TOLERANCE
         → 判为背景像素（画面里的非产品区域）
      3. 背景像素中，与 (255,255,255) 距离 ≤ tolerance → 合格白背景
      4. white_ratio = 合格白背景像素 / 总背景像素
    这样无论产品占 85% 还是 50%，白度只看背景区域本身白不白，
    不会被产品颜色污染（早期「四角方块采样」在产品贴边时会误判）。

    同时采样外圈 1px 边框做诊断 detail（帮助判断「产品是否贴边无白边」）。

    返回 dict: {status, white_ratio, tolerance, bg_base, bg_pixel_ratio,
                worst_sample_rgb, worst_distance, edge_diagnostic, note}
    """
    pure_white = (255, 255, 255)
    BG_IDENTIFY_TOLERANCE = 28.0  # 像素与 bg_base 距离 ≤ 此值 → 视为背景

    # 缩放（保比例）加速全图扫描
    img_small = img_rgb.copy()
    img_small.thumbnail((FG_RESIZE_TO, FG_RESIZE_TO))
    sw, sh = img_small.size
    data = list(img_small.getdata())

    bg_pixels = 0
    white_bg_pixels = 0
    worst_distance = 0.0
    worst_sample_rgb = (255, 255, 255)
    for px in data:
        if color_distance(px, bg_base) <= BG_IDENTIFY_TOLERANCE:
            bg_pixels += 1
            d = color_distance(px, pure_white)
            if d <= tolerance:
                white_bg_pixels += 1
            if d > worst_distance:
                worst_distance = d
                worst_sample_rgb = px

    if bg_pixels > 0:
        ratio = white_bg_pixels / bg_pixels
        bg_pixel_ratio = bg_pixels / len(data)
    else:
        # 极端：找不到背景像素（产品贴满画面）→ 无法判定白度
        ratio = 0.0
        bg_pixel_ratio = 0.0

    # 通过标准：背景区域几乎全白（ratio ≥ 0.95）；warn = 多数白；fail = 明显不白
    if bg_pixels == 0:
        status = "warn"  # 贴满画面无法判定，告警提示留白边
    elif ratio >= 0.95:
        status = "pass"
    elif ratio >= 0.80:
        status = "warn"
    else:
        status = "fail"

    # 外圈诊断（1px 边框环采样，判断产品是否贴边）
    edge_diag = {}
    if sw >= 4 and sh >= 4:
        top = [data[i] for i in range(sw)]
        bottom = [data[(sh - 1) * sw + i] for i in range(sw)]
        left = [data[j * sw] for j in range(sh)]
        right = [data[j * sw + sw - 1] for j in range(sh)]
        for name, strip in (("edge_top", top), ("edge_bottom", bottom),
                            ("edge_left", left), ("edge_right", right)):
            avg = average_rgb(strip)
            edge_diag[name] = {
                "avg_rgb": avg,
                "distance_to_white": round(color_distance(avg, pure_white), 2),
            }

    return {
        "status": status,
        "white_ratio": round(ratio, 4),
        "bg_pixel_ratio": round(bg_pixel_ratio, 4),
        "tolerance": tolerance,
        "bg_base_rgb": bg_base,
        "bg_sampled_pixels": bg_pixels,
        "white_bg_pixels": white_bg_pixels,
        "worst_sample_rgb": worst_sample_rgb,
        "worst_distance": round(worst_distance, 2),
        "edge_diagnostic": edge_diag,
        "note": "white_ratio = 白背景像素 / 背景总像素；产品大小不影响判定",
    }


# ---------------------------------------------------------------------------
# 检测 2：前景占比
# ---------------------------------------------------------------------------
def check_foreground_ratio(img_rgb, bg_base, fg_min):
    """
    缩放到固定尺寸，遍历像素，与「实际背景色基准」距离 > 阈值视为前景。
    返回 dict: {status, ratio, threshold, bg_base, fg_pixels, total_pixels}
    """
    # 缩放（保比例，长边缩到 FG_RESIZE_TO）
    img_small = img_rgb.copy()
    img_small.thumbnail((FG_RESIZE_TO, FG_RESIZE_TO))
    w, h = img_small.size
    total = w * h

    # 前景判定阈值 = max(背景到纯白距离 + BOOST, 固定下限)
    bg_to_white = color_distance(bg_base, (255, 255, 255))
    fg_threshold = max(bg_to_white + FG_TOLERANCE_BOOST, 25.0)

    fg_pixels = 0
    data = list(img_small.getdata())
    for px in data:
        if color_distance(px, bg_base) > fg_threshold:
            fg_pixels += 1

    ratio = fg_pixels / total if total else 0.0

    if ratio >= fg_min:
        status = "pass"
    elif ratio >= fg_min - 0.10:
        # 差一点点 → warn
        status = "warn"
    else:
        status = "fail"

    return {
        "status": status,
        "ratio": round(ratio, 4),
        "threshold_fg_min": fg_min,
        "fg_threshold_distance": round(fg_threshold, 2),
        "bg_base_rgb": bg_base,
        "fg_pixels": fg_pixels,
        "total_pixels": total,
        "sampled_size": [w, h],
        "note": "非白像素视为前景；含阴影/渐变时占比偏高（保守告警）",
    }


# ---------------------------------------------------------------------------
# 检测 3：OCR 文字
# ---------------------------------------------------------------------------
def check_ocr_text(img_rgb, text_policy):
    """
    用 pytesseract 扫描文字。无 tesseract/pytesseract 时降级 skipped。
    返回 dict: {status, text_found, text_preview, engine}
    """
    if text_policy == "ignore":
        return {"status": "skipped", "text_found": None, "reason": "platform text_policy=ignore"}

    # 检查 pytesseract 模块
    try:
        import pytesseract  # noqa
    except ImportError:
        sys.stderr.write(
            "OCR skipped: pytesseract not installed (pip install pytesseract). "
            "Only white_bg + foreground_ratio checked.\n"
        )
        return {
            "status": "skipped",
            "text_found": None,
            "reason": "pytesseract not installed",
            "engine": "none",
        }

    # 检查 tesseract 二进制
    tesseract_bin = _which("tesseract")
    if not tesseract_bin:
        sys.stderr.write(
            "OCR skipped: tesseract binary not installed "
            "(brew install tesseract on macOS / apt install tesseract-ocr on Debian). "
            "Only white_bg + foreground_ratio checked.\n"
        )
        return {
            "status": "skipped",
            "text_found": None,
            "reason": "tesseract binary not installed",
            "engine": "none",
        }

    try:
        # 转 PIL Image 给 pytesseract；预处理提升识别（灰度+放大）
        gray = img_rgb.convert("L")
        # 放大（小字识别）—— 长边拉到至少 1000
        w, h = gray.size
        if max(w, h) < 1000:
            scale = 1000 / max(w, h)
            gray = gray.resize((int(w * scale), int(h * scale)))
        text = pytesseract.image_to_string(gray, lang="eng").strip()
        text = " ".join(text.split())  # 折叠空白
        text_found = len(text) > 0
        status = ("fail" if text_found else "pass") if text_policy == "forbid" else \
                 ("warn" if text_found else "pass")
        return {
            "status": status,
            "text_found": text_found,
            "text_preview": text[:120] if text else "",
            "text_length": len(text),
            "engine": "pytesseract+tesseract",
        }
    except Exception as e:
        # OCR 引擎报错不阻断其他检测
        sys.stderr.write("OCR skipped: tesseract raised {0}\n".format(e))
        return {
            "status": "skipped",
            "text_found": None,
            "reason": "tesseract error: {0}".format(e),
            "engine": "pytesseract+tesseract",
        }


def _which(cmd):
    """简易 which（不依赖 Unix which 命令，跨平台）。"""
    for p in os.environ.get("PATH", "").split(os.pathsep):
        full = os.path.join(p, cmd)
        if os.path.isfile(full) and os.access(full, os.X_OK):
            return full
    return None


# ---------------------------------------------------------------------------
# 主流程
# ---------------------------------------------------------------------------
def run_checks(image_path, platform, strict):
    global Image

    if platform not in PLATFORM_THRESHOLDS:
        return {"ok": False, "error": "unknown platform: {0}".format(platform)}, 2

    if not os.path.isfile(image_path):
        return {"ok": False, "error": "image not found: {0}".format(image_path)}, 2

    # 延迟 import Pillow（让 --help 不依赖它）
    if Image is None:
        try:
            from PIL import Image as _PILImage
            Image = _PILImage
        except ImportError as e:
            msg = (
                "ERROR: Pillow is required for compliance_check but could not be loaded.\n"
                "  Reason: {0}\n".format(e)
            )
            # 检测常见的架构不匹配（arm64 mac 装了 x86 Pillow）
            if "incompatible architecture" in str(e) or "_imaging" in str(e):
                msg += (
                    "  This looks like an architecture mismatch (Pillow's C extension "
                    "doesn't match your Python).\n"
                    "  Fix on Apple Silicon:  arch -arm64 pip3 install --force-reinstall Pillow\n"
                    "  Fix on Intel Mac:      pip3 install --force-reinstall Pillow\n"
                )
            else:
                msg += "  Install with: pip3 install Pillow\n"
            sys.stderr.write(msg)
            sys.exit(2)

    # 合并阈值
    thresholds = dict(PLATFORM_THRESHOLDS[platform])
    if strict:
        thresholds.update(STRICT_OVERRIDES.get(platform, {}))

    try:
        with Image.open(image_path) as img:
            img_rgb = img.convert("RGB")
    except Exception as e:
        return {"ok": False, "error": "cannot open image: {0}".format(e)}, 2

    w, h = img_rgb.size

    # 实际背景色基准
    bg_base = detect_background_base(img_rgb, w, h)

    # 跑 3 项检测
    white_bg = check_white_bg(img_rgb, w, h, bg_base, thresholds["white_tolerance"])
    fg_ratio = check_foreground_ratio(img_rgb, bg_base, thresholds["fg_min"])
    ocr_text = check_ocr_text(img_rgb, thresholds["text_policy"])

    checks = {
        "white_bg": white_bg,
        "foreground_ratio": fg_ratio,
        "ocr_text": ocr_text,
    }

    # 汇总违规
    violations = []
    suggestions = []
    plat_label = platform

    white_bg_policy = thresholds.get("white_bg_policy", "forbid")
    if white_bg_policy != "ignore":
        if white_bg["status"] == "fail":
            violations.append(
                "{0}: background not white enough (white_ratio={1}, worst_distance={2} > tolerance {3})".format(
                    plat_label, white_bg["white_ratio"], white_bg["worst_distance"],
                    thresholds["white_tolerance"]
                )
            )
            suggestions.append(
                "主图背景必须纯白 RGB(255,255,255)。检查是否有渐变/边框/阴影；"
                "Amazon 主图严禁渐变背景。"
            )
        elif white_bg["status"] == "warn":
            violations.append(
                "{0}: background mostly white but some bg pixels off "
                "(white_ratio={1}, worst_distance={2})".format(
                    plat_label, white_bg["white_ratio"], white_bg["worst_distance"]
                )
            )
            suggestions.append("部分背景区域未达纯白，建议检查角落是否有阴影/杂物。")

    if fg_ratio["status"] == "fail":
        violations.append(
            "{0}: foreground ratio {1} < required {2}".format(
                plat_label, fg_ratio["ratio"], fg_ratio["threshold_fg_min"]
            )
        )
        suggestions.append(
            "产品占比不足（{0:.0%}）。建议：①产品放大填充画面 ②裁掉过多留白 ③使用更近的构图。".format(
                fg_ratio["ratio"]
            )
        )
    elif fg_ratio["status"] == "warn":
        violations.append(
            "{0}: foreground ratio {1} slightly below required {2}".format(
                plat_label, fg_ratio["ratio"], fg_ratio["threshold_fg_min"]
            )
        )
        suggestions.append("产品占比接近下限，建议放大产品主体。")

    if ocr_text["status"] == "fail":
        violations.append(
            "{0}: text detected in main image (len={1}): \"{2}\"".format(
                plat_label, ocr_text.get("text_length", 0),
                ocr_text.get("text_preview", "")[:60]
            )
        )
        suggestions.append(
            "Amazon/速卖通/Temu 主图严禁文字、Logo、水印。请把文字移到副图或 A+ 内容。"
        )
    elif ocr_text["status"] == "warn":
        violations.append(
            "{0}: text detected (policy=warn): \"{1}\"".format(
                plat_label, ocr_text.get("text_preview", "")[:60]
            )
        )
        suggestions.append("该平台允许少量文字，但建议精简以提升转化。")

    ok = len(violations) == 0
    result = {
        "ok": ok,
        "platform": platform,
        "strict": strict,
        "image": os.path.abspath(image_path),
        "image_size": [w, h],
        "checks": checks,
        "violations": violations,
        "suggestions": suggestions,
    }
    # exit code：0 通过 / 1 有违规（warning 级，非阻断）
    return result, (0 if ok else 1)


def main():
    parser = argparse.ArgumentParser(
        prog="compliance_check.py",
        description="ecom-image2 主图合规质检：背景白度 / 前景占比 / OCR 文字。"
                    "输出 JSON envelope，exit 0=通过 / 1=有违规 / 2=参数错。",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""\
示例:
  python3 compliance_check.py out/main.png
  python3 compliance_check.py out/main.png --platform amazon
  python3 compliance_check.py out/main.png --platform amazon --strict

平台阈值（与 references/platform-constraints.md 对齐）:
  amazon     纯白 RGB255 容差≤12 / 占比≥85% / 文字禁止
  tiktok     白度容差≤25 / 占比≥70% / 文字仅告警
  shopify    无强制（info only）
  aliexpress 同 amazon
  temu       同 amazon

OCR 可选：无 tesseract 时该项自动 skipped，不报错。
依赖：Pillow 必需；pytesseract + tesseract 可选（用于 OCR）。
""",
    )
    parser.add_argument("image", help="待检测图片路径（PNG/JPEG 等 Pillow 支持的格式）")
    parser.add_argument(
        "--platform",
        default="amazon",
        choices=list(PLATFORM_THRESHOLDS.keys()),
        help="目标平台，决定阈值（默认 amazon，最严）",
    )
    parser.add_argument(
        "--strict",
        action="store_true",
        help="严格模式：白度容差更紧、占比要求更高",
    )
    args = parser.parse_args()

    result, code = run_checks(args.image, args.platform, args.strict)
    sys.stdout.write(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
    sys.exit(code)


if __name__ == "__main__":
    main()
