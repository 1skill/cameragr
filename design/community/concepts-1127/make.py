"""Build index.html for the 11/27 community concepts page.

python3 make.py  (from this directory). Wireframes come from wf.py; concept
images are the GPT renders copied next to this file.
"""
import os
import wf

HERE = os.path.dirname(os.path.abspath(__file__))


def img(name, alt, cap, cls=""):
    if not os.path.exists(os.path.join(HERE, name)):
        return f'<figure class="{cls}"><div class="miss">（这张 GPT 没出成功：{alt}）</div><figcaption>{cap}</figcaption></figure>'
    return f'<figure class="{cls}"><img src="{name}" alt="{alt}"><figcaption>{cap}</figcaption></figure>'


def svgfig(svg, cap, outer=False):
    return (f'<figure class="{"ph-fig" if outer else ""}"><div class="{"" if outer else "scroll"}">{svg}</div>'
            f'<figcaption>{cap}</figcaption></figure>')


def legend(items):
    return "<ol class=\"lg\">" + "".join(f"<li>{i}</li>" for i in items) + "</ol>"


def pc(fit, cost, few):
    return (f'<div class="pc"><div><b>适合</b>{fit}</div><div><b>牺牲</b>{cost}</div>'
            f'<div><b>人很少时（5 人、20 张）</b>{few}</div></div>')


HEAD = """<title>社区设计图：两个方向（11/27）</title>
<meta name="claude:viewport-fit-sides" content="cover">
<style>
:root{--bg:#f4efe6;--fg:#231d17;--muted:#6d645a;--card:#fbf8f2;--line:#ddd3c3;--accent:#a8361d;--box:#ebe4d8;--ph:#cfc6b7;--sel:#fff3e8}
@media (prefers-color-scheme:dark){:root:not([data-theme="light"]){--bg:#16130f;--fg:#ece5d8;--muted:#9c9385;--card:#201c17;--line:#36302a;--accent:#e57a55;--box:#2a251f;--ph:#3e372f;--sel:#33241c;color-scheme:dark}}
:root[data-theme="dark"]{--bg:#16130f;--fg:#ece5d8;--muted:#9c9385;--card:#201c17;--line:#36302a;--accent:#e57a55;--box:#2a251f;--ph:#3e372f;--sel:#33241c;color-scheme:dark}
body{background:var(--bg);color:var(--fg);font:16px/1.7 -apple-system,"PingFang SC",system-ui,sans-serif;padding-left:max(16px,env(safe-area-inset-left,0px));padding-right:max(16px,env(safe-area-inset-right,0px));padding-block:24px 64px;margin:0}
main{max-width:1000px;margin:0 auto}
h1{font-size:24px;margin:0 0 6px;text-wrap:balance}
h2{font-size:19px;margin:38px 0 8px;padding-top:8px;border-top:1px solid var(--line);text-wrap:balance}
h3{font-size:16px;margin:18px 0 6px}
.sub,.small{color:var(--muted)}.small{font-size:14px}
.lead{background:var(--card);border:1px solid var(--line);border-left:4px solid var(--accent);border-radius:10px;padding:12px 16px;margin:14px 0}
figure{margin:10px 0;min-width:0;background:var(--card);border:1px solid var(--line);border-radius:10px;padding:8px}
figure img{width:100%;height:auto;display:block;border-radius:6px}
figcaption{font-size:14px;color:var(--muted);padding:6px 4px 2px}
.miss{padding:40px 10px;text-align:center;color:var(--muted)}
.pair{display:grid;grid-template-columns:7fr 3fr;gap:10px;align-items:start}
.pair3{display:grid;grid-template-columns:1fr 1fr;gap:10px;align-items:start}
@media (max-width:760px){.pair,.pair3{grid-template-columns:1fr}.ph-fig{max-width:360px;margin-inline:auto}}
.pair>*,.pair3>*{min-width:0}
.scroll{overflow-x:auto}.scroll svg{min-width:640px}
svg{width:100%;height:auto;display:block;font-family:-apple-system,"PingFang SC",system-ui,sans-serif}
ul,ol{padding-left:20px;margin:6px 0}li{margin:4px 0}
.lg{font-size:14px;columns:2;column-gap:24px}@media (max-width:760px){.lg{columns:1}}
.tw{overflow-x:auto}table{border-collapse:collapse;font-size:14px;width:100%;min-width:560px}
th,td{border-bottom:1px solid var(--line);padding:7px 8px;text-align:left;vertical-align:top}th{color:var(--muted);font-weight:600;font-size:13px}
.pc{display:grid;grid-template-columns:1fr 1fr 1fr;gap:10px;margin:10px 0}
@media (max-width:760px){.pc{grid-template-columns:1fr}}
.pc div{background:var(--card);border:1px solid var(--line);border-radius:10px;padding:8px 12px;font-size:14px}
.pc b{display:block;color:var(--muted);font-size:13px}
.rec{border:2px solid var(--accent);border-radius:12px;padding:4px 14px 12px;margin-top:30px}
.rec h2{border-top:none}
.q{background:var(--card);border:1px solid var(--line);border-radius:10px;padding:10px 14px;margin:10px 0}
.ok{color:#2f7d4a;font-weight:600}.no{color:var(--accent);font-weight:600}
"""


def build():
    a_home, a_detail, a_outer = wf.a_inner_home(), wf.a_inner_detail(), wf.outer_home("A")
    b_home, b_detail, b_outer = wf.b_inner_home(), wf.b_inner_detail(), wf.outer_home("B")
    h = HEAD + wf.CSS + "</style>\n<main>\n"
    h += """<h1>社区设计图：两个方向</h1>
<p class="sub">11 月 27 日 · 只出图和方案，没改 Swift。先和 GPT 讨论，概念图由 GPT 画（是方向图，不是最终美术，图里的字可能有错）。线框按真实 pt 画：1 个单位 = 1pt，蓝字是尺寸标注，红圈数字对应下面的说明。名字、留言都是示意。</p>

<div class="lead"><b>一句话：</b>E 版的问题不在“少了什么模块”，而在<b>东西太多、每样都被挤小</b>：粗书脊、铜环、三列照片袋占了一圈，名字和胶卷只能挤在一条窄纸签里（约 9pt）；左边是三张互不相干的文字卡。两个方向都先把<b>字号和点击区定死</b>（正文 15–17pt、任何字 ≥11pt、可点区 ≥44pt），放不下就少放，不缩字；左边每一块都带图或头像。<br><b>我和 GPT 都推荐 B</b>：整屏一张相册插页，点开作品是左图右文。</div>

<p class="small"><b>概念图里 GPT 自己加的、正式版不要的：</b>“Koco Film”标题（你说过左页不要装饰性标题）；ColorPlus、Ektar、Portra、Superia、CineStill 等真实胶卷品牌名（正式只用我们自己的卷名）；A 图顶上的提手扣、B 详情页中间的三个铜环（GPT 自己说过要去掉环，画时又加上了）。外屏图的右侧圆角画得不够大，正式美术按 59pt 模板来。</p>

<h2>现在（E 版，build 114）和你的反馈</h2>
<div class="pair3">""" + img("now_e.jpg", "现在的 E 版", "现在：Duo 内屏展开。") + """
<div>
<p>你说：“很多都非常非常小，文字和图标根本不太可用；很多地方还是割裂的；左边都是文字很奇怪。”</p>
<ul>
<li><b>小：</b>照片下的名字、胶卷、赞约 9–10pt；会员证里的标签、打卡格、“信件”更小；胶卷选择器是一条细条。</li>
<li><b>割裂：</b>左边三张卡（主题 / 其他主题 / 会员证）各是一块纸，彼此和右边相册没有关系；中间粗铜脊把两页切开。</li>
<li><b>左边全是字：</b>主题卡、其他主题、会员证都是纯文字，只有会员证里一张小缩略图。</li>
</ul>
<p class="small">折叠屏调研的结论一致：别家内屏的左栏只放列表或导航，没人用一整栏文字当主视觉；网格用偶数列，半折时沿中线分开。</p>
</div></div>

<h2>两个方向一览</h2>
<div class="tw"><table>
<tr><th></th><th>A 左窄右网格</th><th>B 整屏网格，点开左图右文</th></tr>
<tr><td>内屏首页</td><td>左栏 284pt：主题卡（带图）、本周精选（封面）、关注的人（头像）、会员证（数字）；右栏 4 列作品</td><td>上方一条 150pt 横带：主题卡、本周精选封面、关注头像 + 小名牌；下面 4 列作品铺满两页</td></tr>
<tr><td>点开作品</td><td>右栏原地变大图 + 留言，左栏不动</td><td>整页变成左大图、右批注纸（作者、胶卷、主题、赞、留言、输入框）</td></tr>
<tr><td>作品卡宽</td><td>143pt</td><td>213pt</td></tr>
<tr><td>首屏作品数</td><td>约 12 张</td><td>约 8 张（横带滑走后约 12 张）</td></tr>
<tr><td>半折（每半 475pt）</td><td>网格不在折痕上分开；半折时左右各半：左栏变宽、右边 2 列</td><td>网格中缝正对折痕，半折正好 2+2；详情页左图右文正好各占一半</td></tr>
<tr><td>外屏（竖拿 466×678）</td><td>主题卡 + 一行（精选封面 + 关注头像）+ 2 列</td><td>一张可左右滑的卡（主题 / 精选 / 关注）+ 2 列</td></tr>
<tr><td>GPT 排序</td><td>2</td><td><b>1</b></td></tr>
</table></div>
"""
    # ---------- A ----------
    h += """<h2>方向 A · 左窄右网格</h2>
<p>左栏是相机包里<b>一个连续的浅皮侧袋</b>（不是四块分开的面板），从上到下每块都有图或头像；右边是一张透明相册插页，4 列照片袋。</p>
<h3>GPT 概念图</h3>
<div class="pair">""" + img("a_home.jpg", "A 内屏首页", "A · Duo 内屏展开首页（GPT 概念图）") \
        + img("a_outer.jpg", "A 外屏首页", "A · 外屏竖拿（GPT 概念图）", "ph-fig") + "</div>"
    h += "<h3>线框（真实尺寸）</h3>"
    h += svgfig(a_home, "A · Duo 内屏首页 951×669pt。蓝色虚线是折痕。")
    h += legend(["主题卡：代表图 + 今日主题 + 主题名 22pt + 3 个头像“12 人参与” + 去发布（40pt 高，可点区补到 44）。下面可再列“本周 · 窗边”同样一行。",
                 "本周精选：<b>做成一张封面入口</b>，和主题同一种样子；点开后右边显示精选。没按交代画 3–4 张缩略图，因为你 11/27 说过“首页不要放这么多图”。",
                 "关注的人：5 个 44pt 头像，有新作品的带红点，点头像看 TA 的作品。",
                 "会员证：头像、连续天数、拍摄 / 获赞 / 粉丝 / 关注四个 20pt 数字；新增用从证边露出的朱红小纸签 +12（不再是圆红点）；7 天打卡格。",
                 "胶卷选择器：44pt 高，带胶卷罐图标，点开选卷。",
                 "4 列作品：照片下两行纸签——头像 20 + 名字 13pt；胶卷 11pt + 赞 13pt。"])
    h += '<div class="pair">' + svgfig(a_detail, "A · 点开作品：右栏原地变成大图 + 留言（像 Lander），左栏变淡但不动，返回回到原来位置。") \
        + svgfig(a_outer, "A · 外屏 466×678pt：左栏那几块收成主题卡 + 一行，2 列作品（卡宽 198pt）。", True) + "</div>"
    h += pc("想一边看作品，一边一直看到今天的主题、关注的人和自己的数据；左栏就是“社区的控制台”。最接近现在的 E 版结构，改动小。",
            "右边只剩 595pt，4 列卡宽 143pt，照片比 E 版还小（GPT 认为 A 应改成 2 列大卡）；网格不在折痕上分开；点开作品时大图只有约 400×300，留言只放得下两三条。",
            "左栏站得住（主题、精选、关注、我的都是真实少量内容），但关注的人和精选里反复是同几个人；右边 20 张 4 列只有 5 行，很快到底。")
    # ---------- B ----------
    h += """<h2>方向 B · 首页整屏网格，点开左图右文</h2>
<p>去掉粗书脊和大铜环，<b>一张透明插页跨两页</b>，左右各 2 列，中缝正好在折痕上。主题、精选、关注收成插页上沿的一条索引纸；相机包只留皮边、底部刻度导航和纸签。</p>
<h3>GPT 概念图</h3>
<div class="pair3">""" + img("b_home.jpg", "B 内屏首页", "B · Duo 内屏展开首页（GPT 概念图）") \
        + img("b_detail.jpg", "B 内屏点开作品", "B · 点开作品：左照片护套、右批注纸（GPT 概念图）") + "</div>"
    h += '<div style="max-width:360px">' + img("b_outer.jpg", "B 外屏首页", "B · 外屏竖拿（GPT 概念图）") + "</div>"
    h += "<h3>线框（真实尺寸）</h3>"
    h += svgfig(b_home, "B · Duo 内屏首页 951×669pt。往下滑时顶带滑走，只留范围耳和胶卷签（看板问题 3）。")
    h += legend(["主题卡：和 A 一样的内容，宽 330pt，按钮 40/44pt。",
                 "本周精选：一张封面 + 6 张 · 5 位作者 + 看全部。",
                 "关注的人：4 个 44pt 头像，带红点。",
                 "会员名牌：头像、昵称、获赞和粉丝 + 朱红纸签 +16；点开是完整会员证（四项数据、新增、打卡）。GPT 说得对：不把四个数字硬塞进小名牌。",
                 "主题 / 大家 / 关注 + 胶卷选择器，都是 44pt 高，放在作品正上方。",
                 "4 列作品，卡宽 213pt，纸签字和 A 一样大，照片大一半。"])
    h += '<div class="pair">' + svgfig(b_detail, "B · 点开作品：左边照片（415×311，原比例，左右切换），右边一张连续的批注纸：作者 + 关注、胶卷签、主题签、一句话、赞、留言流、输入框。半折时左图右文正好各占一半。") \
        + svgfig(b_outer, "B · 外屏：顶带变成一张左右滑的卡（主题 / 精选 / 关注），下面 2 列。点开作品是整页：图在上，留言在下。", True) + "</div>"
    h += pc("看作品、看留言是主角；照片最大、字最大；最符合 Apple 的“偶数列、半折沿中线分开”和小红书的“左图右文”；内外屏是同一套信息减一层。",
            "首屏照片约 8 张（顶带滑走后约 12 张）；看作品时看不到主题和自己的数据（要滑回顶部或点名牌）；相机包的拟物感变成“皮边 + 插页 + 纸签”，没有 E 版那么多道具。",
            "20 张 4 列是 5 行，一屏半就到底，到底自然结束，不重复铺图；顶带的主题、精选封面、关注头像都是真实少量内容，站得住。某主题 0 张时插页写“还没人发，第一张可以是你”。")

    # ---------- sizes ----------
    h += """<h2>尺寸规范（两个方向一样）</h2>
<div class="tw"><table>
<tr><th>元素</th><th>E 版现在（约）</th><th>新设计</th></tr>
<tr><td>主题名</td><td>22pt</td><td>22pt</td></tr>
<tr><td>正文、留言、一句话</td><td>11–12pt</td><td>15–17pt</td></tr>
<tr><td>作者名 / 胶卷名 / 赞</td><td>9–10pt，挤一行</td><td>13 / 11 / 13pt，分两行纸签</td></tr>
<tr><td>头像</td><td>卡里约 20pt</td><td>卡上 20pt；关注栏 44pt；详情 36–44pt</td></tr>
<tr><td>按钮、范围耳、胶卷选择器</td><td>28–32pt 高</td><td>44pt（去发布视觉 40，可点区 44）</td></tr>
<tr><td>会员证数字</td><td>约 14pt</td><td>20pt，标签 13pt</td></tr>
<tr><td>新增提示</td><td>小红圆点 +N</td><td>朱红小纸签 +N（11pt 粗体）</td></tr>
</table></div>

<h2>和 GPT 讨论的结果（拟物怎么结合）</h2>
<div class="tw"><table>
<tr><th>话题</th><th>结论</th></tr>
<tr><td>哪个方向</td><td><span class="ok">一致：</span>B 第一，A 第二。</td></tr>
<tr><td>A 的右栏几列</td><td><span class="no">有分歧：</span>GPT 认为“左栏 1/3 + 右边 4 列”不能同时成立，卡太窄，A 应改 2 列大卡。我按交代画了 4 列（卡宽 143pt，字号够 Apple 下限），但同意这是 A 最大的弱点；选 A 时再定 2 还是 4 列。</td></tr>
<tr><td>本周精选</td><td><span class="ok">采纳 GPT：</span>交代里写的是 3–4 张缩略图，但你 11/27 说过首页不要多张小图、样子跟主题一样。两个方向都画成一张封面入口。</td></tr>
<tr><td>透明插页、照片袋、照片卡 + 纸签</td><td><span class="ok">一致：</span>直接装内容的拟物都保留。纸签可以变高，不能为了“像真的小标签”缩字。</td></tr>
<tr><td>左栏缝几个皮口袋</td><td><span class="ok">采纳 GPT：</span>不给每个模块各缝一个口袋（还是四块拼起来）；A 的左栏做成一个连续侧袋。材料分工：皮是包，塑料装照片，纸写信息。</td></tr>
<tr><td>B 整屏网格时拟物还剩什么</td><td><span class="ok">一致：</span>皮边、底部刻度导航、透明插页、纸签、索引耳；去掉粗书脊和大铜环，它们占地方又把两页切开。</td></tr>
<tr><td>详情页</td><td><span class="ok">采纳 GPT：</span>我原想“看片台 + 便签”，GPT 认为发光看片台是新物件，散便签会把留言切碎；改成“照片护套 + 同册里一张连续批注纸”，长留言和键盘弹出都好处理。</td></tr>
<tr><td>+N 红圈</td><td><span class="ok">采纳 GPT：</span>朱红小纸签从证件上沿露出，写 +12，贴近对应的数字；只有真看过对应的新动态才清零。</td></tr>
<tr><td>人很少时</td><td><span class="ok">一致：</span>少展示几层推荐，比制造热闹好；人数照实写，不留空头像位，不重复铺图。</td></tr>
</table></div>
<p class="small">GPT 原文：同目录 gpt_discussion.md（也在 project/discuss/club-concepts-1127.md）。</p>

<h2>和 E 版比，改了哪些</h2>
<ul>
<li>所有字和按钮按 Apple 规范重定（上面的表），放不下就少放。</li>
<li>左边不再是三张文字卡：主题带代表图和头像，精选是封面，关注是一排头像，会员证是大数字。</li>
<li>B：去掉粗书脊和铜环，一张插页跨两页，列数 3 → 4，中缝对折痕。A：保留左右两页，但右边 3 → 4 列。</li>
<li>照片下的纸签从一行变两行。</li>
<li>胶卷选择器从细条变成 44pt 的胶卷签。</li>
<li>会员证：红圆点 +N 换成朱红纸签；不显示“审核中”。</li>
<li>点开作品：A 在右栏原地打开；B 整页左图右文，留言和输入框更大。</li>
<li>没变的：主题 / 大家 / 关注、去发布、本周精选、底部刻度导航、相机包的皮和纸、先审后公开。</li>
</ul>
"""
    h += """<div class="rec"><h2>推荐：B</h2>
<ul>
<li>三条反馈都正面解决：照片和字都最大；一张插页跨两页，不再左右割裂；左边不再有一栏字。</li>
<li>符合折叠屏的规律：偶数列沿折痕分开，详情页左图右文（小红书），半折时正好一半一半，外屏是同一套减一层。</li>
<li>代价是看作品时主题和数据不在眼前，靠顶带和名牌一步回去。A 可以当备选：如果你更想让主题一直在左边。</li>
<li>选定后，下一步按 Duo 内屏 2853×2007px（55pt 圆角）的模板请 GPT 出正式美术，再拿真机尺寸核对字号，然后才动代码。</li>
</ul></div>

<h2>要你定的问题（已列看板）</h2>
<div class="q"><b>1. 社区选哪个方向？</b> 推荐 B（整屏网格，点开左图右文）。</div>
<div class="q"><b>2. 会员证的 +N 换成什么样？</b> 推荐朱红小纸签（从证边露出）。</div>
<div class="q"><b>3. B 的顶带往下滑时？</b> 推荐跟着滑走，只留范围耳和胶卷签（看作品时照片多一行）。</div>
</main>
"""
    open(os.path.join(HERE, "index.html"), "w").write(h)


if __name__ == "__main__":
    build()
