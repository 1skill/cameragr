"""The four community wireframes (Duo open spread + ordinary iPhone portrait).

Names and comments in the drawings are placeholders, not real users.
"""
from wf import t, box, photo, tag, line, duo, phone, grid

CAPS = ["小川 · Porto 400", "Momo · C200", "Lena · Cine 500T", "竹子 · Tri-Ax",
        "阿木 · Golden 200", "Kai · CCD"]
LIKES = [12, 8, 5, 3, 9, 2]
SPINE = line(338, 34, 338, 606, "spine")


def me_bar(x, y, w, h=40, compact=False):
    s = box(x, y, w, h, None, "card")
    s += t(x + 12, y + h / 2 + 5, "我的", 13, "t", weight=700)
    s += t(x + 52, y + h / 2 + 5,
           "连续 2 天 ●●○ · 待审 1 · 新消息 2" if not compact else "连续 2 天 · 消息 2",
           11, "m")
    return s


def quote(x, y, w, who, what, h=46):
    s = box(x, y, w, h, None, "note", r=4)
    s += t(x + 8, y + 18, who, 11, "t", weight=600)
    s += t(x + 8, y + 36, what, 11, "m")
    return s


# ---------------------------------------------------------------- A 期刊
def a_duo():
    b = SPINE
    for i, (n, sel) in enumerate([("今日", 1), ("本周", 0), ("限定", 0), ("往期", 0)]):
        b += box(40 + i * 70, 34, 64, 26, n, "ear sel" if sel else "ear", 12,
                 lcls="a" if sel else "m")
    b += box(36, 58, 290, 214, None, "card sel")
    b += t(52, 84, "今日题目 · 11 月 27 日", 11, "m")
    b += t(52, 120, "它睡着了", 28, "t", weight=700)
    b += t(52, 146, "拍一个睡着的人、猫，或一座睡着的城", 12, "m")
    b += t(52, 170, "周日 24:00 截止 · 还剩 20 小时", 12, "t")
    b += t(52, 202, "12 人已投：", 12, "m")
    b += t(52, 222, "小川  Momo  Lena  竹子  阿木 …", 13, "t", weight=600)
    b += box(214, 232, 100, 30, "＋ 投一张", "btn", 13, lcls="bt")
    b += t(40, 300, "本周入选", 14, "t", weight=700)
    b += t(320, 300, "周一公布", 11, "m", "end")
    for i in range(3):
        b += photo(40 + i * 96, 310, 88, 70, ["Momo", "竹子", "Kai"][i])
    b += t(40, 412, "大家在说", 14, "t", weight=700)
    b += quote(40, 420, 284, "阿木 → Momo《午后》", "“好像我家猫，连姿势都一样。”")
    b += quote(40, 472, 284, "Lena → 小川", "“这卷的绿好舒服，是傍晚吗？”")
    b += me_bar(36, 556, 290)
    b += box(350, 34, 565, 26, None, "card")
    b += t(362, 52, "《它睡着了》的投稿 · 31 张", 12, "t", weight=600)
    b += t(905, 52, "最新 | 入选    胶卷：不限 ▾", 11, "m", "end")
    b += grid(352, 70, 3, 3, 181, 118, 10, CAPS, {1: "阿木：像我家猫", 3: "2 条留言 ›"},
              LIKES)
    b += tag(22, 66, 1) + tag(22, 230, 2) + tag(22, 296, 3) + tag(22, 410, 4)
    b += tag(22, 552, 5) + tag(932, 70, 6)
    return duo(b, "A 期刊式 Duo")


def a_phone():
    b = ""
    for i, (n, sel) in enumerate([("今日", 1), ("本周", 0), ("限定", 0), ("往期", 0)]):
        b += box(16 + i * 66, 54, 60, 26, n, "ear sel" if sel else "ear", 12,
                 lcls="a" if sel else "m")
    b += box(330, 54, 56, 26, "我的●", "ear", 12)
    b += box(16, 80, 370, 176, None, "card sel")
    b += t(30, 104, "今日题目 · 还剩 20 小时", 11, "m")
    b += t(30, 140, "它睡着了", 28, "t", weight=700)
    b += t(30, 166, "拍一个睡着的人、猫，或一座睡着的城", 12, "m")
    b += t(30, 196, "12 人已投：小川 Momo Lena 竹子 …", 12, "t")
    b += box(256, 212, 116, 32, "＋ 投一张", "btn", 13, lcls="bt")
    b += t(16, 282, "本周入选", 14, "t", weight=700)
    for i in range(3):
        b += photo(16 + i * 125, 292, 118, 78, ["Momo", "竹子", "Kai"][i])
    b += quote(16, 380, 370, "阿木 → Momo《午后》", "“好像我家猫，连姿势都一样。”")
    b += t(16, 448, "全部投稿 · 31 张", 13, "t", weight=700)
    b += t(386, 448, "胶卷：不限 ▾", 11, "m", "end")
    b += grid(16, 458, 2, 2, 180, 132, 10, CAPS, None, LIKES)
    b += t(201, 790, "往下滑：封面收成一行题目条，相册继续", 11, "a", "middle")
    return phone(b, "A 期刊式 iPhone")


# ---------------------------------------------------------------- B 名册
def b_duo():
    b = SPINE
    b += t(40, 50, "这期在拍", 14, "t", weight=700)
    b += box(36, 58, 290, 58, None, "card sel")
    b += box(44, 66, 38, 18, "今日", "pill", 10)
    b += t(90, 80, "它睡着了", 15, "t", weight=700)
    b += t(318, 80, "还剩 20 小时", 11, "m", "end")
    b += t(46, 106, "小川、Momo、Lena 等 12 人", 11, "t")
    b += box(266, 90, 52, 20, "投一张", "btn", 11, lcls="bt", r=10)
    b += box(36, 122, 290, 58, None, "card")
    b += box(44, 130, 38, 18, "本周", "pill", 10)
    b += t(90, 144, "窗边", 15, "t", weight=700)
    b += t(318, 144, "周日截止", 11, "m", "end")
    b += t(46, 170, "Kai、竹子 等 5 人", 11, "t")
    b += t(40, 206, "胶卷房间", 14, "t", weight=700)
    b += t(322, 206, "有新作品的排前面", 10, "m", "end")
    rooms = [("●", "Porto 400", "小川 · 2 小时前"), ("●", "C200", "Lena · 昨天"),
             ("", "Cine 500T", "Kai · 3 天前"), ("", "Golden 200", "上周")]
    for i, (dot, n, who) in enumerate(rooms):
        y = 214 + i * 30
        b += box(36, y, 290, 26, None, "row")
        b += t(46, y + 18, dot, 12, "a")
        b += t(60, y + 18, n, 12, "t", weight=600)
        b += t(318, y + 18, who, 11, "m", "end")
    b += t(46, 352, "全部 16 卷 ›", 11, "a")
    b += t(40, 384, "本周入选", 14, "t", weight=700)
    for i in range(3):
        b += photo(40 + i * 96, 392, 88, 56, ["Momo", "竹子", "Kai"][i])
    b += t(40, 476, "最近的留言", 14, "t", weight=700)
    b += quote(40, 484, 284, "阿木 → Momo《午后》", "“好像我家猫。”", 30 + 12)
    b += t(40, 546, "Lena → 小川：“这卷的绿好舒服”", 11, "m")
    b += me_bar(36, 562, 290, 38)
    b += box(350, 34, 565, 26, None, "card")
    b += t(362, 52, "范围：今日《它睡着了》 · 胶卷：不限", 12, "t", weight=600)
    b += t(905, 52, "12 人 · 31 张", 11, "m", "end")
    b += grid(352, 70, 3, 2, 181, 118, 10, CAPS, None, LIKES)
    b += box(352, 330, 563, 24, "以下是 Koco 暗房选片（官方作品，已标明）", "divider", 11)
    b += grid(352, 362, 3, 2, 181, 118, 10, ["Koco 官方 · Porto 400"], None, None)
    b += tag(22, 54, 1) + tag(22, 202, 2) + tag(22, 380, 3) + tag(22, 472, 4)
    b += tag(22, 560, 5) + tag(932, 330, 6)
    return duo(b, "B 名册式 Duo")


def b_phone():
    b = t(16, 72, "社区", 20, "t", weight=700) + box(330, 54, 56, 26, "我的●", "ear", 12)
    b += box(16, 86, 370, 50, None, "card sel")
    b += box(26, 94, 36, 18, "今日", "pill", 10)
    b += t(70, 108, "它睡着了 · 还剩 20 小时", 13, "t", weight=700)
    b += t(28, 128, "小川、Momo、Lena 等 12 人", 11, "t")
    b += box(306, 106, 70, 22, "投一张", "btn", 11, lcls="bt", r=11)
    b += box(16, 142, 370, 40, None, "card")
    b += box(26, 152, 36, 18, "本周", "pill", 10)
    b += t(70, 166, "窗边 · 周日截止 · Kai、竹子 等 5 人", 12, "t")
    b += t(16, 206, "胶卷房间", 13, "t", weight=700)
    for i, n in enumerate(["全部", "● Porto 400", "● C200", "Cine 500T", "Gol…"]):
        b += box(16 + i * 82, 214, 76, 26, n, "ear sel" if i == 0 else "ear", 11)
    b += box(16, 248, 370, 30, None, "note", r=4)
    b += t(26, 268, "最近留言  阿木 → Momo：“好像我家猫。”", 11, "m")
    b += t(16, 300, "范围：今日《它睡着了》", 12, "t", weight=600)
    b += grid(16, 310, 2, 3, 180, 132, 10, CAPS, None, LIKES)
    b += t(201, 790, "往下滑：名册收起，只留范围条", 11, "a", "middle")
    return phone(b, "B 名册式 iPhone")


# ---------------------------------------------------------------- C 题目墙
def c_column(x, y, kind, title, due, names, n_photos):
    s = box(x, y, 270, 116, None, "card sel" if kind == "今日" else "card")
    s += box(x + 10, y + 10, 40, 18, kind, "pill", 10)
    s += t(x + 260, y + 24, due, 11, "m", "end")
    s += t(x + 12, y + 58, title, 20, "t", weight=700)
    s += t(x + 12, y + 82, names, 11, "t")
    s += box(x + 170, y + 88, 90, 22, "＋ 投一张", "btn", 11, lcls="bt", r=11)
    py = y + 128
    for k in range(6):
        cx, cy = x + (k % 2) * 138, py + (k // 2) * 104
        if k < n_photos:
            s += photo(cx, cy, 132, 92, CAPS[(k + len(title)) % 6], LIKES[k % 6])
        elif k == n_photos:
            s += box(cx, cy, 132, 92, "这里可以是你", "slot", 11)
    return s


def c_duo():
    b = box(36, 30, 879, 32, None, "card")
    b += t(50, 51, "进行中的题目 · 3", 13, "t", weight=700)
    b += t(330, 51, "胶卷：不限 ▾", 12, "m")
    b += t(560, 51, "本周入选 ›", 12, "a")
    b += t(900, 51, "我的 · 连续 2 天 · 消息 2", 12, "m", "end")
    b += c_column(40, 72, "今日", "它睡着了", "还剩 20 小时", "小川 Momo Lena 等 12 人", 6)
    b += c_column(330, 72, "本周", "窗边", "周日截止", "Kai 竹子 等 5 人", 4)
    b += c_column(620, 72, "限定", "初雪", "12/10 截止", "还没有人投", 0)
    b += box(898, 72, 18, 530, None, "slot", r=4)
    b += t(907, 340, "往", 11, "m", "middle") + t(907, 356, "期", 11, "m", "middle")
    b += t(175, 600, "看全部 31 张 ›", 11, "a", "middle")
    b += t(465, 600, "看全部 9 张 ›", 11, "a", "middle")
    b += tag(22, 82, 1) + tag(22, 210, 2) + tag(932, 290, 3) + tag(932, 60, 4)
    return duo(b, "C 题目墙 Duo")


def c_phone():
    b = box(16, 54, 370, 30, None, "card")
    b += t(28, 74, "题目 1 / 3  ● ○ ○", 12, "t", weight=700)
    b += t(376, 74, "胶卷 ▾   我的●", 11, "m", "end")
    b += box(16, 92, 370, 140, None, "card sel")
    b += box(28, 104, 40, 18, "今日", "pill", 10)
    b += t(374, 118, "还剩 20 小时", 11, "m", "end")
    b += t(28, 160, "它睡着了", 26, "t", weight=700)
    b += t(28, 188, "小川 Momo Lena 等 12 人", 12, "t")
    b += box(262, 196, 112, 28, "＋ 投一张", "btn", 12, lcls="bt", r=14)
    b += grid(16, 244, 2, 3, 180, 140, 10, CAPS, None, LIKES)
    b += t(201, 790, "左右滑：换下一个题目 / 往期", 11, "a", "middle")
    return phone(b, "C 题目墙 iPhone")


# ---------------------------------------------------------------- D 近况
def d_entry(x, y, who, what, when):
    s = photo(x, y, 44, 44)
    s += t(x + 54, y + 16, who, 12, "t", weight=600)
    s += t(x + 54, y + 34, what, 11, "m")
    s += t(x + 284, y + 16, when, 10, "m", "end")
    return s


def d_duo():
    b = SPINE
    b += box(36, 34, 290, 74, None, "card sel")
    b += t(48, 56, "今日《它睡着了》 · 还剩 20 小时", 12, "t", weight=700)
    b += t(48, 78, "本周《窗边》 · 周日截止", 12, "m")
    b += box(234, 76, 84, 24, "＋ 投一张", "btn", 11, lcls="bt", r=12)
    b += t(40, 136, "近况", 14, "t", weight=700)
    b += t(322, 136, "只写已公开的事", 10, "m", "end")
    ev = [("小川 投了《它睡着了》", "Porto 400", "2 小时前"),
          ("Lena 对 Momo 的《午后》说", "“光真好，是傍晚吗？”", "3 小时前"),
          ("Momo 回复 Lena", "“六点多，西晒。”", "3 小时前"),
          ("本周入选公布", "Momo、竹子、Kai", "周一"),
          ("新题目《窗边》开始", "已有 5 人投稿", "周一"),
          ("Kai 第一次投稿", "CCD", "上周")]
    for i, e in enumerate(ev):
        b += d_entry(40, 146 + i * 66, *e)
    b += me_bar(36, 562, 290, 38)
    b += box(350, 34, 565, 26, None, "card")
    b += t(362, 52, "最近公开 · 全部 | 关注", 12, "t", weight=600)
    b += t(905, 52, "胶卷：不限 ▾", 11, "m", "end")
    for k in range(4):
        x, y = 352 + (k % 2) * 286, 70 + (k // 2) * 272
        b += photo(x, y, 277, 190, CAPS[k] + " · 《它睡着了》", LIKES[k])
        b += box(x, y + 194, 277, 44, None, "note", r=4)
        b += t(x + 8, y + 212, ["阿木：好像我家猫", "还没有留言 · 写一句", "Momo：这光！",
                                "竹子：Tri-Ax 好颗粒"][k], 11, "t")
        b += t(x + 8, y + 230, ["+ 2 条", "", "+ 1 条", ""][k], 10, "m")
    b += tag(22, 40, 1) + tag(22, 150, 2) + tag(22, 560, 3) + tag(932, 270, 4)
    return duo(b, "D 近况式 Duo")


def d_phone():
    b = box(16, 54, 370, 52, None, "card sel")
    b += t(28, 76, "今日《它睡着了》 · 还剩 20 小时", 12, "t", weight=700)
    b += t(28, 96, "本周《窗边》 · 周日", 11, "m")
    b += box(300, 66, 76, 26, "投一张", "btn", 11, lcls="bt", r=13)
    b += t(16, 130, "最近 · 全部 | 关注", 13, "t", weight=700)
    b += t(386, 130, "我的●", 11, "m", "end")
    b += box(16, 140, 370, 34, None, "row")
    b += t(26, 162, "Lena 对 Momo 说：“光真好，是傍晚吗？” · 3 小时前", 11, "m")
    b += photo(16, 182, 370, 250, "小川 · Porto 400 · 《它睡着了》", 12)
    b += box(16, 436, 370, 40, None, "note", r=4)
    b += t(26, 460, "阿木：好像我家猫  · + 2 条", 11, "t")
    b += box(16, 484, 370, 34, None, "row")
    b += t(26, 506, "本周入选公布：Momo、竹子、Kai · 周一", 11, "m")
    b += photo(16, 526, 370, 250, "Momo · C200 · 《午后》", 8)
    b += t(201, 795 - 8, "", 11)
    return phone(b, "D 近况式 iPhone")


# ---------------------------------------------------------------- E 同题共拍（推荐）
def e_duo():
    b = SPINE
    for i, (n, sel) in enumerate([("题目", 1), ("大家", 0), ("关注", 0)]):
        b += box(40 + i * 74, 34, 68, 26, n, "ear sel" if sel else "ear", 12,
                 lcls="a" if sel else "m")
    b += box(36, 58, 290, 170, None, "card sel")
    b += box(48, 68, 38, 18, "今日", "pill", 10)
    b += t(318, 82, "还剩 20 小时", 11, "m", "end")
    b += t(48, 120, "它睡着了", 26, "t", weight=700)
    b += t(48, 144, "拍一个睡着的人、猫，或一座睡着的城", 11, "m")
    b += t(48, 170, "最近公开：", 11, "m")
    b += t(48, 190, "小川  Momo  Lena  竹子  +8", 13, "t", weight=600)
    b += box(222, 194, 94, 26, "＋ 投这题", "btn", 12, lcls="bt", r=13)
    for i, (k, n, d) in enumerate([("本周", "窗边", "周日截止 · 5 人"),
                                     ("限定", "初雪", "12/10 · 还没人投")]):
        y = 234 + i * 32
        b += box(36, y, 290, 28, None, "row")
        b += box(44, y + 5, 36, 18, k, "pill", 10)
        b += t(88, y + 19, n, 13, "t", weight=600)
        b += t(318, y + 19, d, 11, "m", "end")
    b += t(40, 320, "本周入选", 14, "t", weight=700)
    b += t(322, 320, "看全部 7 张 ›", 11, "a", "end")
    for k in range(4):
        b += photo(40 + (k % 2) * 144, 330 + (k // 2) * 92, 138, 84,
                   ["Momo · 它睡着了", "竹子 · 午后", "Kai · 窗边", "Lena · 午后"][k])
    b += box(36, 522, 140, 28, "胶卷：不限 ▾", "row", 11)
    b += box(186, 522, 140, 28, "往期题目 ›", "row", 11)
    b += box(36, 558, 290, 42, None, "card")
    b += f'<circle cx="58" cy="579" r="12" class="ph"/>'
    b += t(78, 584, "Koco 昵称", 13, "t", weight=700)
    b += t(318, 584, "连续 2 天 · 待审 1 · ●2", 11, "m", "end")
    b += box(350, 34, 565, 26, None, "card")
    b += t(362, 52, "《它睡着了》 · 12 人 · 31 张", 12, "t", weight=600)
    b += t(905, 52, "最新 | 入选    胶卷：不限", 11, "m", "end")
    b += grid(352, 70, 3, 3, 181, 118, 10, CAPS,
              {0: "阿木：好像我家猫", 4: "Momo：这光！ +1"}, LIKES)
    b += tag(22, 47, 1) + tag(22, 112, 2) + tag(22, 248, 3) + tag(22, 330, 4)
    b += tag(22, 518, 5) + tag(22, 560, 6) + tag(932, 70, 7)
    return duo(b, "E 同题共拍 Duo")


def e_phone():
    b = ""
    for i, (n, sel) in enumerate([("题目", 1), ("大家", 0), ("关注", 0)]):
        b += box(16 + i * 70, 54, 64, 26, n, "ear sel" if sel else "ear", 12,
                 lcls="a" if sel else "m")
    b += f'<circle cx="372" cy="67" r="13" class="ph"/>' + t(352, 72, "●2", 10, "a", "end")
    b += box(16, 80, 370, 150, None, "card sel")
    b += box(28, 90, 38, 18, "今日", "pill", 10)
    b += t(374, 104, "还剩 20 小时", 11, "m", "end")
    b += t(28, 142, "它睡着了", 26, "t", weight=700)
    b += t(28, 166, "拍一个睡着的人、猫，或一座睡着的城", 11, "m")
    b += t(28, 192, "最近公开：小川 Momo Lena 竹子 +8", 12, "t")
    b += box(268, 198, 106, 26, "＋ 投这题", "btn", 12, lcls="bt", r=13)
    b += box(16, 236, 370, 28, None, "row")
    b += t(28, 255, "还有 2 个题目：本周《窗边》 · 限定《初雪》  ▾", 11, "m")
    b += t(16, 290, "本周入选", 13, "t", weight=700)
    b += t(386, 290, "看全部 ›", 11, "a", "end")
    for k in range(4):
        b += photo(16 + k * 94, 298, 88, 66, ["Momo", "竹子", "Kai", "Lena"][k])
    b += t(16, 392, "《它睡着了》全部投稿", 13, "t", weight=700)
    b += t(386, 392, "胶卷 ▾", 11, "m", "end")
    b += grid(16, 402, 2, 2, 180, 150, 10, CAPS, {0: "阿木：好像我家猫"}, LIKES)
    b += t(201, 790, "往下滑：题目卡收成一行，入选条收起", 11, "a", "middle")
    return phone(b, "E 同题共拍 iPhone")
