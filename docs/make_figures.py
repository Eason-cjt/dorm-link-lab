"""生成期末大作业报告所需的两张示意图：系统架构图、规则执行流程图。"""

from PIL import Image, ImageDraw, ImageFont
import os

FONT_REG = "C:/Windows/Fonts/msyh.ttc"
FONT_BD = "C:/Windows/Fonts/msyhbd.ttc"
OUT_DIR = os.path.dirname(os.path.abspath(__file__))

# 配色（浅色主题）
C_TITLE = "#111827"
C_SUB = "#4B5563"
C_MUTED = "#6B7280"
C_LINE = "#9CA3AF"

LAYER_STYLES = {
    "ui": ("#EFF6FF", "#BFDBFE", "#1D4ED8"),
    "svc": ("#ECFDF5", "#A7F3D0", "#047857"),
    "eng": ("#FFF7ED", "#FED7AA", "#C2410C"),
    "model": ("#F5F3FF", "#DDD6FE", "#6D28D9"),
    "store": ("#F3F4F6", "#D1D5DB", "#374151"),
}


def font(size, bold=False):
    return ImageFont.truetype(FONT_BD if bold else FONT_REG, size, index=0)


def text_center(draw, box, text, fnt, fill):
    x0, y0, x1, y1 = box
    bb = draw.textbbox((0, 0), text, font=fnt)
    w, h = bb[2] - bb[0], bb[3] - bb[1]
    draw.text(((x0 + x1 - w) / 2 - bb[0], (y0 + y1 - h) / 2 - bb[1]), text, font=fnt, fill=fill)


def text_right(draw, x, y, text, fnt, fill):
    bb = draw.textbbox((0, 0), text, font=fnt)
    draw.text((x - (bb[2] - bb[0]) - bb[0], y), text, font=fnt, fill=fill)


def arrow_down(draw, x, y1, y2, color=C_LINE, width=3):
    draw.line([(x, y1), (x, y2 - 14)], fill=color, width=width)
    draw.polygon([(x - 9, y2 - 14), (x + 9, y2 - 14), (x, y2)], fill=color)


def arrow_left(draw, x1, x2, y, color=C_LINE, width=3):
    draw.line([(x1, y), (x2 + 14, y)], fill=color, width=width)
    draw.polygon([(x2 + 14, y - 9), (x2 + 14, y + 9), (x2, y)], fill=color)


def dash_line(draw, pts, color=C_LINE, width=2, dash=8, gap=6):
    for i in range(len(pts) - 1):
        x1, y1 = pts[i]
        x2, y2 = pts[i + 1]
        dx, dy = x2 - x1, y2 - y1
        length = (dx * dx + dy * dy) ** 0.5
        if length == 0:
            continue
        ux, uy = dx / length, dy / length
        pos = 0.0
        while pos < length:
            seg = min(dash, length - pos)
            draw.line([(x1 + ux * pos, y1 + uy * pos),
                       (x1 + ux * (pos + seg), y1 + uy * (pos + seg))], fill=color, width=width)
            pos += dash + gap


def module_box(draw, box, name, desc, accent="#FFFFFF"):
    x0, y0, x1, y1 = box
    draw.rounded_rectangle(box, radius=10, fill="#FFFFFF", outline="#D1D5DB", width=2)
    draw.rounded_rectangle([x0, y0, x0 + 6, y1], radius=3, fill=accent)
    if desc:
        text_center(draw, (x0, y0 + 6, x1, y0 + (y1 - y0) * 0.58), name, font(20, True), C_TITLE)
        text_center(draw, (x0, y0 + (y1 - y0) * 0.55, x1, y1 - 6), desc, font(14), C_MUTED)
    else:
        text_center(draw, box, name, font(20, True), C_TITLE)


def layer_band(draw, box, kind, label, sub):
    bg, border, accent = LAYER_STYLES[kind]
    draw.rounded_rectangle(box, radius=14, fill=bg, outline=border, width=2)
    x0, y0, x1, y1 = box
    draw.text((x0 + 18, y0 + 10), label, font=font(19, True), fill=accent)
    draw.text((x0 + 18 + (len(label) * 20 + 16), y0 + 13), sub, font=font(13), fill=C_MUTED)
    return accent


# ---------------- 图 2.1 系统架构图 ----------------
def make_architecture():
    W, H = 1600, 1200
    img = Image.new("RGB", (W, H), "#FFFFFF")
    d = ImageDraw.Draw(img)

    text_center(d, (0, 34, W, 86), "联动实验室 · 系统架构图", font(36, True), C_TITLE)
    text_center(d, (0, 88, W, 116), "依赖方向自上而下单向：界面层 → 服务层 → 引擎层 → 模型层，引擎层不依赖任何 UI 与存储 API",
                font(15), C_MUTED)

    x0, x1 = 80, 1520

    # 界面层
    ui_box = (x0, 130, x1, 360)
    accent = layer_band(d, ui_box, "ui", "界面层", "ArkUI 声明式页面 · view/ + pages/")
    names = [("pages/Index", "Tabs 容器（4 个页签）"), ("DashboardView", "首页仪表盘"),
             ("RuleListView", "规则列表与冲突提示"), ("SimulatorView", "模拟演练"),
             ("LogView", "执行日志"), ("RuleEditPage", "规则编辑")]
    bw, gap = 448, 22
    for i, (n, s) in enumerate(names):
        row, col = i // 3, i % 3
        bx = x0 + 24 + col * (bw + gap)
        by = 196 + row * 84
        module_box(d, (bx, by, bx + bw, by + 70), n, s, accent)

    arrow_down(d, W // 2, 360, 410)

    # 服务层
    svc_box = (x0, 410, x1, 580)
    accent = layer_band(d, svc_box, "svc", "服务层", "状态编排 · 持久化 · 预置数据")
    svc = [("AppStore", "内存状态与落盘编排"), ("StorageService", "Preferences 读写与序列化"),
           ("ScenarioPresets", "默认规则与两组场景")]
    for i, (n, s) in enumerate(svc):
        bx = x0 + 24 + i * (bw + gap)
        module_box(d, (bx, 470, bx + bw, 550), n, s, accent)

    arrow_down(d, W // 2, 580, 620)

    # 引擎层
    eng_box = (x0, 620, x1, 800)
    accent = layer_band(d, eng_box, "eng", "引擎层", "纯逻辑，无 UI 与存储依赖，可被单元测试独立验证")
    module_box(d, (x0 + 24, 680, x1 - 24, 780), "RuleEngine",
               "条件求值（且 / 或） · 优先级排序 · 冲突裁决 · 设备推演 · 未执行原因记录", accent)

    arrow_down(d, W // 2, 800, 840)

    # 模型层
    model_box = (x0, 840, x1, 1010)
    accent = layer_band(d, model_box, "model", "模型层", "领域数据对象，无外部依赖")
    models = [("DeviceModel", "设备 · 属性 · 状态"), ("EnvModel", "环境字段 · 比较运算符"),
              ("RuleModel", "规则 · 条件 · 动作"), ("LogModel", "执行结果结构")]
    mw = 338
    mgap = (x1 - x0 - 48 - mw * 4) // 3
    for i, (n, s) in enumerate(models):
        bx = x0 + 24 + i * (mw + mgap)
        module_box(d, (bx, 900, bx + mw, 980), n, s, accent)

    arrow_down(d, W // 2, 1010, 1050)

    # 存储层
    st_box = (x0, 1050, x1, 1160)
    layer_band(d, st_box, "store", "本地存储", "HarmonyOS Preferences")
    d.rounded_rectangle((x0 + 24, 1085, x1 - 24, 1142), radius=10, fill="#FFFFFF", outline="#D1D5DB", width=2)
    text_center(d, (x0 + 24, 1085, x1 - 24, 1142),
                "键值存储：rules（规则）　devices（设备状态）　env（环境快照）　logs（执行日志，保留最近 8 条）",
                font(17), C_TITLE)

    img.save(os.path.join(OUT_DIR, "fig2-1_系统架构图.png"))
    print("已生成 fig2-1_系统架构图.png", img.size)


# ---------------- 图 3.1 规则执行流程图 ----------------
def make_flowchart():
    W, H = 1440, 1230
    img = Image.new("RGB", (W, H), "#FFFFFF")
    d = ImageDraw.Draw(img)

    text_center(d, (0, 30, W, 80), "规则引擎执行流程图", font(34, True), C_TITLE)
    text_center(d, (0, 82, W, 108), "一次「执行联动」从读取规则到展示结果的完整处理路径", font(15), C_MUTED)

    fx0, fx1 = 330, 940
    h, step = 74, 118
    top = 140

    steps = [
        ("开始：调整模拟环境数据 或 套用预置场景", "start"),
        ("点击「执行联动」，读取全部规则", "normal"),
        ("按优先级升序排序；同优先级按规则 id 升序", "normal"),
        ("逐条求值：条件按「且 / 或」组合判定", "normal"),
        ("命中的规则按执行顺序应用设备动作", "normal"),
        ("冲突判定：同一「设备 : 属性」是否已被更高优先级写入", "decision"),
        ("汇总 ExecutionResult：触发 / 变化 / 冲突 / 未执行", "normal"),
        ("写入执行日志，持久化设备状态与环境快照", "normal"),
        ("界面展示：触发顺序、设备变化、冲突裁决", "end"),
    ]

    boxes = []
    for i, (txt, kind) in enumerate(steps):
        y = top + i * step
        boxes.append((fx0, y, fx1, y + h))
        if kind == "start":
            fill, outline, tcolor = "#DBEAFE", "#93C5FD", "#1E40AF"
        elif kind == "end":
            fill, outline, tcolor = "#DCFCE7", "#86EFAC", "#166534"
        elif kind == "decision":
            fill, outline, tcolor = "#FEF3C7", "#FCD34D", "#92400E"
        else:
            fill, outline, tcolor = "#FFFFFF", "#D1D5DB", C_TITLE
        d.rounded_rectangle((fx0, y, fx1, y + h), radius=12, fill=fill, outline=outline, width=2)
        text_center(d, (fx0 + 10, y, fx1 - 10, y + h), txt, font(18, kind in ("start", "end")), tcolor)

        if i > 0:
            arrow_down(d, (fx0 + fx1) // 2, y - step + h, y)

    # 右侧分支说明
    notes = [
        (boxes[3], "条件不成立 或 规则已停用\n→ 记入「未执行」列表，继续下一条"),
        (boxes[5], "目标值相同 或 首次写入\n→ 写入设备并记录变化\n\n已被高优先级占用且值不同\n→ 不覆盖，生成冲突记录"),
    ]
    for box, note in notes:
        nx0, nx1 = 1000, 1370
        ny0 = box[1] - 16
        lines = note.split("\n")
        nh = len(lines) * 26 + 24
        ny1 = ny0 + nh
        d.rounded_rectangle((nx0, ny0, nx1, ny1), radius=10, fill="#F9FAFB", outline="#D1D5DB", width=2)
        yy = ny0 + 12
        for line in lines:
            if line:
                d.text((nx0 + 14, yy), line, font=font(14), fill=C_SUB)
            yy += 26
        dash_line(d, [(box[2], (box[1] + box[3]) // 2), (nx0, (box[1] + box[3]) // 2)])

    # 左侧「循环」标注
    loop_y0 = boxes[3][1]
    loop_y1 = boxes[4][3]
    lx = 200
    d.line([(fx0, (boxes[3][1] + boxes[3][3]) // 2), (lx, (boxes[3][1] + boxes[3][3]) // 2)],
           fill=C_LINE, width=2)
    d.line([(lx, (boxes[3][1] + boxes[3][3]) // 2), (lx, (boxes[4][1] + boxes[4][3]) // 2)],
           fill=C_LINE, width=2)
    arrow_left(d, 0, 0, 0, C_LINE, 0) if False else None
    d.polygon([(fx0 - 14, (boxes[4][1] + boxes[4][3]) // 2 - 9),
               (fx0 - 14, (boxes[4][1] + boxes[4][3]) // 2 + 9),
               (fx0, (boxes[4][1] + boxes[4][3]) // 2)], fill=C_LINE)
    d.line([(lx, (boxes[4][1] + boxes[4][3]) // 2), (fx0 - 14, (boxes[4][1] + boxes[4][3]) // 2)],
           fill=C_LINE, width=2)
    d.rounded_rectangle((96, loop_y0 + 8, 300, loop_y1 - 8), radius=10, fill="#F3F4F6", outline="#D1D5DB", width=2)
    text_center(d, (96, loop_y0 + 8, 300, loop_y0 + 44), "循环处理", font(16, True), C_TITLE)
    text_center(d, (96, loop_y0 + 44, 300, loop_y1 - 8), "遍历全部规则", font(14), C_MUTED)

    img.save(os.path.join(OUT_DIR, "fig3-1_规则执行流程图.png"))
    print("已生成 fig3-1_规则执行流程图.png", img.size)


if __name__ == "__main__":
    make_architecture()
    make_flowchart()
