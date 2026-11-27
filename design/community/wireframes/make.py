"""Build index.html for the community wireframes. Run: python3 make.py"""
import os
import layouts as L

HERE = os.path.dirname(os.path.abspath(__file__))

CSS = """
:root{--bg:#f4efe6;--fg:#231d17;--muted:#6d645a;--card:#fbf8f2;--line:#ddd3c3;--accent:#a8361d;--box:#ebe4d8;--ph:#cfc6b7;--sel:#fff3e8}
@media (prefers-color-scheme:dark){:root:not([data-theme="light"]){--bg:#16130f;--fg:#ece5d8;--muted:#9c9385;--card:#201c17;--line:#36302a;--accent:#e57a55;--box:#2a251f;--ph:#3e372f;--sel:#33241c;color-scheme:dark}}
:root[data-theme="dark"]{--bg:#16130f;--fg:#ece5d8;--muted:#9c9385;--card:#201c17;--line:#36302a;--accent:#e57a55;--box:#2a251f;--ph:#3e372f;--sel:#33241c;color-scheme:dark}
body{background:var(--bg);color:var(--fg);font:16px/1.7 -apple-system,"PingFang SC",system-ui,sans-serif;padding-left:max(16px,env(safe-area-inset-left,0px));padding-right:max(16px,env(safe-area-inset-right,0px));padding-block:24px 64px;margin:0}
main{max-width:1000px;margin:0 auto}
h1{font-size:24px;margin:0 0 6px;text-wrap:balance}
h2{font-size:19px;margin:38px 0 8px;padding-top:8px;border-top:1px solid var(--line);text-wrap:balance}
h3{font-size:16px;margin:16px 0 6px}
.sub,.small{color:var(--muted)}.small{font-size:14px}
.lead{background:var(--card);border:1px solid var(--line);border-left:4px solid var(--accent);border-radius:10px;padding:12px 16px;margin:14px 0}
ul,ol{padding-left:20px;margin:6px 0}li{margin:4px 0}
.tw{overflow-x:auto}table{border-collapse:collapse;font-size:14px;width:100%;min-width:560px}
th,td{border-bottom:1px solid var(--line);padding:7px 8px;text-align:left;vertical-align:top}th{color:var(--muted);font-weight:600;font-size:13px}
.figs{display:grid;grid-template-columns:7fr 3fr;gap:12px;align-items:start;margin:12px 0}
@media (max-width:760px){.figs{grid-template-columns:1fr}.figs .ph-fig{max-width:340px;margin:0 auto}}
.figs>*{min-width:0}
figure{margin:0;min-width:0;background:var(--card);border:1px solid var(--line);border-radius:10px;padding:8px}
figcaption{font-size:13px;color:var(--muted);padding:6px 4px 0}
.scroll{overflow-x:auto}
.scroll svg{min-width:620px}
svg{width:100%;height:auto;display:block;font-family:-apple-system,"PingFang SC",system-ui,sans-serif}
.pc{display:grid;grid-template-columns:1fr 1fr 1fr;gap:10px;margin:10px 0}
@media (max-width:760px){.pc{grid-template-columns:1fr}}
.pc div{background:var(--card);border:1px solid var(--line);border-radius:10px;padding:8px 12px;font-size:14px}
.pc b{display:block;color:var(--muted);font-size:13px}
.rec{border:2px solid var(--accent);border-radius:12px;padding:4px 14px 12px;margin-top:30px}
.rec h2{border-top:none}
.q{background:var(--card);border:1px solid var(--line);border-radius:10px;padding:10px 14px;margin:10px 0}
/* wireframe parts */
.fr{fill:var(--bg);stroke:var(--fg);stroke-width:2}
.isl{fill:var(--fg)}
.bx{fill:var(--box);stroke:var(--line)}
.card{fill:var(--card);stroke:var(--muted);stroke-width:1}
.card.sel{fill:var(--sel);stroke:var(--accent);stroke-width:1.6}
.ear{fill:var(--box);stroke:var(--muted)}
.ear.sel{fill:var(--sel);stroke:var(--accent);stroke-width:1.6}
.row{fill:var(--card);stroke:var(--line)}
.pill{fill:none;stroke:var(--muted)}
.btn{fill:var(--accent)}
.nav{fill:var(--box);stroke:var(--muted)}
.note{fill:var(--card);stroke:var(--accent);stroke-dasharray:3 2}
.slot{fill:none;stroke:var(--muted);stroke-dasharray:5 4}
.divider{fill:var(--box);stroke:var(--muted);stroke-dasharray:6 3}
.ph{fill:var(--ph)}
.phx{stroke:var(--bg);stroke-width:1;opacity:.6}
.cap{fill:var(--card);opacity:.92}
.spine{stroke:var(--muted);stroke-width:1.5;stroke-dasharray:8 5}
.t{fill:var(--fg)}.m{fill:var(--muted)}.a{fill:var(--accent)}.bt{fill:#fff}
.mk{fill:var(--accent)}.mkt{fill:#fff}
"""


def variant(vid, name, duo_svg, phone_svg, legend, fits, cost, sparse, extra=""):
    leg = "".join(f"<li>{x}</li>" for x in legend)
    return f"""
<h2 id="{vid}">{name}</h2>
<div class="figs">
<figure><div class="scroll">{duo_svg}</div><figcaption>Duo 内屏展开（951×669，两页）。红圈数字对应下面的说明。手机上可左右拖动看全图。</figcaption></figure>
<figure class="ph-fig">{phone_svg}<figcaption>普通 iPhone 竖屏（402×874）。</figcaption></figure>
</div>
<ol>{leg}</ol>
{extra}
<div class="pc"><div><b>适合</b>{fits}</div><div><b>牺牲</b>{cost}</div><div><b>人很少时</b>{sparse}</div></div>
"""


V = [
    variant("a", "A 期刊式：每次只展开一个题目", L.a_duo(), L.a_phone(), [
        "侧耳切 今日 / 本周 / 限定 / 往期；同一组里有多题时耳下再列题名。",
        "题目“封面”：题名、一句说明、截止、已投的人名，右下“投一张”。",
        "本周入选：3 张小图 + 作者（你在看板上选的左页内容）。",
        "大家在说：两句最新的真实留言，点了跳到那张照片。",
        "“我的”收成一条：连续天数、待审、新消息；点开占两页。",
        "右页只放这道题的投稿；有留言的照片下露出一句。",
    ], "题目最突出，像一期期主题活动（最贴近你做活动的经验）；引导“今天拍什么”。",
       "随便逛大家作品、按胶卷看效果的入口变弱；一次只展开一个题。",
       "封面靠文字撑得住；右页投稿少时会空——用“这里可以是你”空位，不拿别题作品补。"),
    variant("b", "B 名册式：左页列出房间和里面的人", L.b_duo(), L.b_phone(), [
        "这期在拍：进行中的题目各一行，带截止和最近投稿人的名字，各自能“投一张”。",
        "胶卷房间：每卷一行，有新作品打红点，写最近一位和时间；没动静的收进“全部 16 卷”。",
        "本周入选：小图 + 作者。",
        "最近的留言：一两句真实留言摘录。",
        "我的：一条状态。",
        "右页跟着左边选中的范围走；作品不够时，用写明“官方”的分隔纸接官方选片。",
    ], "多题、多卷同时有动静时一眼看全；最像 Discord / 图虫圈子；把胶卷当成社区单位（调研报告的推荐）。",
       "左页文字密，像目录；题目不如 A 突出；照片和对话分在两页。",
       "最容易显空：16 卷里大多写着“上周”“还没有”。GPT 认为人少时不该建胶卷房间（见下面讨论）。"),
    variant("c", "C 题目墙：每个题目一列，投稿钉在下面", L.c_duo(), L.c_phone(), [
        "顶条：进行中题目数、胶卷筛选、本周入选入口、我的。",
        "每列一个题目：题卡在上，大家的投稿钉在下面，“投一张”在题卡上。",
        "右边露出“往期”，横滑看更早的题目。",
        "我的：顶条右端。",
    ], "多题并行时比较“今天想拍哪题”；一眼看到每题有谁回应；节日限定题有存在感。",
       "打破“右页只放相册”的已定规则；照片小；竖屏只能一次一题左右滑，其实是另一种结构；胶卷筛选藏得深。",
       "最空：某列 0 张、三列高低不齐，冷清一目了然。"),
    variant("d", "D 近况式：按时间看谁说了什么", L.d_duo(), L.d_phone(), [
        "题目缩成一张小卡，带“投一张”。",
        "近况流：留言、回复、入选公布、新题开始，只写已经公开的事，带时间。",
        "我的：一条状态。",
        "右页按公开时间排的作品，大图 + 作者 + 第一条留言；可切 全部 / 关注。",
    ], "最能看出“有人在说话”；熟人、关注流最舒服；时间感最强。",
       "题目退成小条（和你“突出话题”的要求相反）；像通知列表；同一件事左右两边各出现一次。",
       "时间会拉长成“3 天前”“上周”，诚实但冷清；没有留言时只剩系统事件。"),
]

E = variant("e", "E（推荐）同题共拍：A 的题目主轴 + B 的清楚切换", L.e_duo(), L.e_phone(), [
    "顶耳 题目 / 大家 / 关注（之前已定的三个范围），默认在“题目”。",
    "选中的题目整张展开：题名、说明、截止、最近公开的人名、“投这题”。",
    "其他进行中的题目各一行（本周、限定），点一下就换成它展开，右页跟着换。",
    "本周入选：2×2 小图，写作者和来自哪题；“看全部”在右页打开入选作品。",
    "胶卷筛选和往期题目收成两个小入口，不占大块。",
    "“我的”改成名牌：头像、昵称、连续天数、待审、未读；点开占两页。",
    "右页只放当前题目的投稿；只有真有留言的照片才露出一句，没有就不留位。",
], "题目最突出，同时多题并行也看得到；“大家在拍同一道题”最清楚；本周入选跨题发现；左页上下都有内容。",
   "按胶卷逛退成筛选；“大家/关注”要多点一下；时间线式的热闹感比 D 弱。",
   "题目卡和入选区靠真实少量内容就站得住；某题 0 张时右页写“还没人投，第一张可以是你”，不悄悄补别题作品。",
   extra="")

PAGE = f"""<!doctype html>
<html lang="zh-Hans"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">
<meta name="claude:viewport-fit-sides" content="cover">
<title>社区页框架图（5 版）</title>
<style>{CSS}</style>
</head><body><main>
<h1>社区页重新设计：框架图</h1>
<p class="sub">11 月 27 日 · 只是框架图（灰盒 + 文字），不是美术，没改 Swift。和 GPT 讨论过一轮。图里的名字、留言都是占位，正式版只用真实数据。</p>

<div class="lead"><b>一句话：</b>现在的问题是题目、入选、右页照片三者没连起来——看得出“有活动”，看不出“谁在回应它”。四版各试一种思路，第五版 E 是我和 GPT 都推荐的合并方案：<b>左页把一道题整张展开、写出真实的人名，下面放本周入选；右页只放这道题的投稿。</b></div>

<h2>先排清楚：社区要装什么、谁先谁后</h2>
<div class="tw"><table>
<tr><th>优先</th><th>用户来做的事</th><th>对应模块</th><th>放哪</th></tr>
<tr><td>1</td><td>看今天/本周的题目，看大家怎么拍</td><td>题目卡 + 这题的投稿相册</td><td>首屏，左上 + 整个右页</td></tr>
<tr><td>2</td><td>投一张</td><td>“投这题”按钮</td><td>紧贴题目</td></tr>
<tr><td>3</td><td>点赞、留言，看别人在说什么</td><td>照片下一句留言；看片页（照片左、批注右）</td><td>跟着照片走，不另开大块</td></tr>
<tr><td>4</td><td>看本周入选</td><td>入选小图 + 作者</td><td>左页第二块</td></tr>
<tr><td>5</td><td>看某卷胶卷拍出来什么样</td><td>胶卷筛选（拍摄时自动带）</td><td>小入口</td></tr>
<tr><td>6</td><td>看关注的人 / 所有人最新</td><td>“大家 / 关注”范围</td><td>顶耳，一步切换</td></tr>
<tr><td>7</td><td>我的：连续投稿奖励、待审、消息、信件</td><td>“我的”名牌，点开占两页</td><td>左页底</td></tr>
<tr><td>8</td><td>翻往期题目</td><td>往期入口</td><td>小入口</td></tr>
</table></div>
<p class="small">不变的：先审后公开（左页只写“最近公开”）、举报、按人算的连续投稿、Duo 底部长铜窗、看片留在包里、“我的”占两页。作者页从照片或人名进入，返回恢复原来位置。</p>

<h2>五版一览</h2>
<div class="tw"><table>
<tr><th>版</th><th>思路</th><th>题目突出</th><th>“有人在”的感觉</th><th>人少时</th><th>GPT 排序</th></tr>
<tr><td><a href="#a">A 期刊</a></td><td>一次展开一个题</td><td>最强</td><td>中（名字 + 留言）</td><td>右页可能空</td><td>2</td></tr>
<tr><td><a href="#b">B 名册</a></td><td>左页列题目、胶卷房间、留言</td><td>中</td><td>中（名字多）</td><td>最容易显空</td><td>3</td></tr>
<tr><td><a href="#c">C 题目墙</a></td><td>每题一列</td><td>强</td><td>强（同题并排）</td><td>很空</td><td>5（只适合做选题页）</td></tr>
<tr><td><a href="#d">D 近况</a></td><td>按时间的对话流</td><td>弱</td><td>最强</td><td>冷清但诚实</td><td>4（适合当“大家/关注”的排法）</td></tr>
<tr><td><a href="#e">E 同题共拍</a></td><td>A + B 合并</td><td>强</td><td>中上</td><td>站得住</td><td>1</td></tr>
</table></div>

{''.join(V)}
<div class="rec">{E}
<h3>为什么推荐 E</h3>
<ul>
<li>你要的“突出话题”：题目整张展开，字最大；其他并行的题也露在下面，不用猜。</li>
<li>“人聚在一起”：人名写在题目里（谁回应了这题），留言挂在具体照片下，本周入选写作者。都是真实数据，人少也不造假。</li>
<li>“左上满下空”：左页从上到下是 题目 → 其他题 → 本周入选 → 小入口 → 我的，没有空出半页。</li>
<li>层级：只有一张“选中”的题卡是亮的；本周入选次之；筛选和我的最轻。纸可以做薄（这是美术阶段的事，框架里只用细线）。</li>
<li>D 的对话流不丢：放进“大家 / 关注”范围里当作品排法（右页大图 + 留言）。</li>
</ul>
</div>

<h2>和 GPT 讨论的结果</h2>
<div class="tw"><table>
<tr><th>话题</th><th>结论</th></tr>
<tr><td>主方案</td><td><b>一致：</b>推荐 E（GPT 提出的合并方案，我同意）。GPT 排序 E ＞ A ＞ B ＞ D ＞ C。</td></tr>
<tr><td>C 题目墙</td><td><b>一致：</b>不做主页；以后可以当“选题页”（点往期或更多题时打开）。</td></tr>
<tr><td>D 近况</td><td><b>一致：</b>不单独做首页；“大家 / 关注”范围用 D 的右页排法。点赞、入选不各生成一条动态，免得同一件事重复。</td></tr>
<tr><td>本周入选</td><td><b>采纳 GPT：</b>A 里原来写的“本期入选”改回你选的“本周入选”；要有小图和作者，不只列名字。</td></tr>
<tr><td>胶卷房间</td><td><b>有分歧：</b>GPT 认为人少时胶卷房间会变成一长串冷清区，只做筛选。调研报告认为胶卷是唯一自动准确的社区单位。我在 E 里先听 GPT 的（收成筛选），保留 B 给你对比；等作品多了再考虑把筛选升级成房间。</td></tr>
<tr><td>作品不够时补什么</td><td><b>采纳 GPT：</b>不把别的题或官方作品悄悄混进当前题目；E 里改成写明“还没人投”。B 里那张“以下是 Koco 暗房选片”分隔纸是 B 自己的做法，选 B 才用。</td></tr>
<tr><td>“首屏三个名字一句留言”</td><td><b>一致：</b>是内容够多时的检查标准，不是固定坑位；没有留言时不留空位，结构照样成立。</td></tr>
<tr><td>竖屏</td><td><b>一致：</b>不把左页整块堆在照片前面；题目卡和入选条往下滑时收起。</td></tr>
</table></div>
<p class="small">GPT 原文：project/discuss/club-wireframes-1127.md。</p>

<h2>要你定的问题</h2>
<div class="q"><b>1. 选哪版方向？</b>推荐 E（同题共拍）。选定后我再出这一版的拟物概念（GPT 画），然后才动代码。</div>
<div class="q"><b>2. 社区一打开，先看什么？</b>推荐“一道题的大家投稿”；“所有人最新”留在顶耳一步切换。</div>
<div class="q"><b>3. 本周入选在首页多大？</b>推荐左页约三分之一：小图 + 作者，“看全部”在右页打开。</div>
</main></body></html>
"""

if __name__ == "__main__":
    with open(os.path.join(HERE, "index.html"), "w") as f:
        f.write(PAGE)
    print("wrote index.html")
