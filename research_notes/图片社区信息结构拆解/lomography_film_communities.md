# Lomography 与其他胶片社区的信息结构拆解

> 取证说明（先读）：lomography.com 在 2026-11-24 对直接抓取返回 Cloudflare 403（"Just a moment..." 验证页），Reddit 官方接口同样 403。以下 Lomography 和 r/analog 的页面事实全部来自 Wayback Machine 的 2026 年快照（链接里带日期），每条都标了快照日期。快照是抓取时的原始 HTML，只能看到结构、文案和计数，看不到登录后的界面和 JS 动态部分。凡是我没在页面上亲眼读到的，都标了"未核实"或放在 Gaps。

## 1) 内容清单表：模块｜内容｜每屏数量｜首页级还是二级

### Takeaway
Lomography 是一个"一个照片池 + 很多索引页"的结构：顶栏 8 个一级入口（Shop 之外是 Photos / Magazine / Competitions / Meetups / School / Travel / Homes），每个一级页都是"一个人工精选位 + 一条大网格 + 指向其他索引的链接"。数量上很克制：照片网格 50 张一页，比赛页 2 个进行中 + 20 个历史，最新投稿和获奖条各 24 张。

### Cited Findings
**内容清单（Lomography，2026 快照）**

| 模块 | 内容 | 每屏/每页数量（从快照数出来的） | 级别 |
|---|---|---|---|
| Photos 首页 | 顶部"Photo of the Day by justopenit"一张 + 一句编辑评语；下面 Trending/Recent/Popular 三个排序标签；网格；底部是按相机、胶卷、镜头、国家、城市、年代的入口词云 | 网格 50 张一页（有分页）；相机入口 20 个、胶卷 20 个、镜头 20 个、国家 40 个、城市 40 个 | 一级 — [Photos 2026-07-19](https://web.archive.org/web/20260719180147/https://www.lomography.com/photos) |
| Selected Photos | 官方精选，纯图片网格 | 约 60 张一页，有分页 | 二级（在 Photos 菜单下）— [Selected 2026-11-09](https://web.archive.org/web/20261109150141/https://www.lomography.com/photos/selected/) |
| Random Photo / Random Home | 随机看一张照片、一个主页 | 1 | 二级菜单项 — [Competitions 页菜单 2026-07-21](https://web.archive.org/web/20260721002944/https://www.lomography.com/competitions) |
| Films 索引 | 文案"Discover photos taken with over 49,000 different films"；按字母列的胶卷名单；"Popular Photos"条，每张图配胶卷名 | 名单约 90 个常用胶卷；Popular Photos 约 10 个胶卷 | 二级（在 More 菜单和页脚"Browse our Photos"下）— [Films 2026-11-09](https://web.archive.org/web/20261109150432/https://www.lomography.com/films/) |
| 单个胶卷的照片页 | 标题"Kodak Portra 400 / Photos"；计数"Discover over 115,586 photos taken with Kodak Portra 400"；商店推广块；排序 Trending / Recent / Popular / Selected（默认 Selected）；Watchlist（关注这个胶卷）；"Browse Combinations"热门组合 | 50 张一页；热门组合 10 个，每个带数量（如"Canon AE-1 Program × Kodak Portra 400 (3k)"） | 三级 — [Portra 400 photos 2026-11-06](https://web.archive.org/web/20261106150733/https://www.lomography.com/films/871910984-kodak-portra-400/photos) |
| 单个相机的照片页 | "Browse through 962,624 creative analogue photos shot with the Lomo LC-A"；商店块；排序；热门组合 10 个；"Related Articles"（杂志文章，每篇带作者、日期、标签、评论数、点赞数） | 50 张一页；组合 10 个 | 三级 — [LC-A photos 2026-02-06](https://web.archive.org/web/20260206195140/https://www.lomography.com/cameras/3322586-lomo-lc-a/photos) |
| Competitions 首页 | 总计数文案；Ongoing；Award Winning 获奖图条；Finished 列表；Latest Submissions | 进行中 2；历史 20 一页；获奖图 24；最新投稿 24 | 一级 — [Competitions 2026-07-21](https://web.archive.org/web/20260721002944/https://www.lomography.com/competitions) |
| 比赛详情 | 类型 + 标题 + 投稿数 + 状态 + 截止时间 + 一句口号 + 正文（奖品、每人限投几张、截止日）+ Submit（登录投稿，或者不登录用邮箱投稿）；结束后多一块"The Winners" | 结束后的页面：获奖 5 张 + 最新投稿约 36 张 | 二级 — [Snapdash 进行中 2026-02-01](https://web.archive.org/web/20260201140706/https://www.lomography.com/competitions/3783-snapdash)；[FPD 2026 已结束 2026-06-26](https://web.archive.org/web/20260626152030/https://www.lomography.com/competitions/3804-film-photography-day-2026) |
| 比赛投稿页 | 纯投稿网格 | 50 张一页 | 三级 — [Snapdash submissions 2026-04-09](https://web.archive.org/web/20260409190256/https://www.lomography.com/competitions/3783-snapdash/submissions) |
| Winners 页 | 按奖项分组，每个奖项一段描述 + 历年获奖者（年份 + 用户名） | 每奖每年约 5 人 | 二级 — [Winners 2026-02-21](https://web.archive.org/web/20260221065129/https://www.lomography.com/competitions/winners) |
| Homes 首页 | "Join over 1 million Lomographers"；In the Spotlight："LomoHome of the Week"；Trending Photos；按兴趣（Film Swaps、Development & Printing Sessions、Postcard Prints Exchange via Snail Mail、Road Trips、Casual Hangouts 等）和国家找人；Featured LomoWall "Wall of the Week"；"Happening Right Now"（一个用户卡片）；Trending Users | Trending Photos 18；Trending Users 约 49；Happening Right Now 1 张卡（带 4 张缩略图） | 一级 — [Homes 2026-11-01](https://web.archive.org/web/20261101155324/https://www.lomography.com/homes) |
| 个人主页（LomoHome） | 用户名、签名、"Get in touch with me for: Road Trips"、"Here since 2025"、评论数 8 / 获赞 3,462 / 照片 339、所在地；My Photos / Albums / Walls / Likes / Most Trending；相册列表；"My Metas"（自己用过的标签、相机、胶卷） | 相册 6 个，然后"Show More" | 二级 — [bromo35 2026-03-08](https://web.archive.org/web/20260308172840/https://www.lomography.com/homes/bromo35) |
| 单张照片页 | 上一张/下一张；元数据：Photographer、Uploaded、Tags、Camera、Film、City、Country、Decade、Year、Albums；6 个主色（可点进去按颜色看）；"6 Likes" + 点赞人名单；"No Comments"；关联的 Travel 城市指南；"More photos by" | — | 三级 — [kopanskarchive 照片 2026-03-02](https://web.archive.org/web/20260302082824/https://www.lomography.com/homes/kopanskarchive/photos/28831457) |
| Magazine 首页 | 系列栏目介绍（Around the World in Analogue、Lomography Partners、Making a Moment、Lomopedia、In Depth）；杂志总评论数 307,334、总点赞 702,793；Featured 一篇；Most Recent Articles（每篇：标题、"written by"作者主页链接、日期、#分类、摘要、评论数、点赞数） | 最近文章约 15+ 篇一页 | 一级 — [Magazine 2026-11-15](https://web.archive.org/web/20261115140939/https://www.lomography.com/magazine) |

**r/analog（2026-08-22 快照）**

| 模块 | 内容 | 数量 | 级别 |
|---|---|---|---|
| 置顶公告 | POTW（Photographer of the Week）公告、每周 Ask Anything、每月 Self Promotion | 2–3 条置顶 | 首页 — [old.reddit r/analog 2026-08-22](https://web.archive.org/web/20260822130748/https://old.reddit.com/r/analog/) |
| 帖子流 | 每帖：投票数、标题（必须带 [相机, 镜头, 胶卷]）、作者、用户 flair（例如"POTW-2025-W04"）、评论数 | Reddit 默认一页 25 条（Reddit 通用设定，未在快照中逐条数） | 首页 |
| 侧栏 | 订阅数"2,723,614 readers"、10 条规则、Wiki 链接（相机评测、冲洗、扫描、现有胶卷列表、冲洗店列表、POTW 名单）、Flickr 群和 Instagram、固定栏目、相关子版 | — | 首页侧栏 |

### Inferences
- Lomography 每个一级页面的结构都一样："一个人工选出的焦点（今日一图 / 本周主页 / 本周照片墙 / 杂志 Featured）+ 一条按热度排的网格 + 入口链接"。Koco 右页的相册也可以照这个套：一个封面位 + 几页插袋。
- Lomography 的网格里只有图，没有作者名和点赞数（看 Portra 页的 HTML，每格只有一个 `<a><img>`）。作者、计数这些信息都放在单张照片页里。Koco 的照片插袋也可以只放图，信息放进"抽出来细看"那一层。

### Gaps
- Lomography 首页（lomography.com/）没有抓，首页具体放什么没核实。
- 登录后的个人信息流（例如 /my/watchlist）看不到。

## 2) 入口层级：一级入口几个、是什么；首页放什么；二级页放什么

### Takeaway
Lomography 顶栏是 8 个一级入口加登录和搜索。浏览照片的维度（相机、胶卷、镜头、标签、国家、城市、年代、年份、时段、颜色）没有放进一级，而是放在"More"菜单、页脚的"Browse our Photos"和 Photos 页底部，此外每张照片的元数据本身就是链接，点了就能跳到对应维度。

### Cited Findings
- 顶栏：Shop、Photos、Magazine、Competitions、Meetups、School、Travel、Homes、Corporate、About，再加 Login 和 Search — [Competitions 2026-07-21](https://web.archive.org/web/20260721002944/https://www.lomography.com/competitions)
- 二级菜单：Photos 下有 Random Photo、Selected Photos；Homes 下有 Random Home、Search Homes、Walls、Movies；"More"下有 Tags、Cameras、Films、Lenses、Countries & Regions、Cities、Decades、Years、Times、Colors、Browse、Search、Shoutbox — 同上
- 页脚"Browse our Photos"：Tags / Cameras / Films / Lenses / Countries/Regions / Cities / Decades / Years / Times；杂志分类：News / People / Gear / Tutorials / Places / Videos；比赛：About Our Competitions / Ongoing Competitions — 同上
- 二级页内容：
  - 比赛页：见第 3 节。
  - 按胶卷/相机看：计数文案 + 排序标签 + 50 张网格 + 关注 + 组合筛选（+ 相机页还有相关文章）— [Portra 400](https://web.archive.org/web/20261106150733/https://www.lomography.com/films/871910984-kodak-portra-400/photos)、[LC-A](https://web.archive.org/web/20260206195140/https://www.lomography.com/cameras/3322586-lomo-lc-a/photos)
  - 作者主页：身份信息、三个计数、照片/相册/照片墙/喜欢、自己的标签/相机/胶卷 — [bromo35](https://web.archive.org/web/20260308172840/https://www.lomography.com/homes/bromo35)
  - "话题页"在 Lomography 就是 Tags（/tags/），杂志则另有系列栏目（Making a Moment、Lomopedia 等）— [Magazine](https://web.archive.org/web/20261115140939/https://www.lomography.com/magazine)
- 胶卷的根地址 /films/871910984-kodak-portra-400 在 2025-11 的快照里会跳转到 /photos，也就是说胶卷"详情页"就是它的照片页（Wayback 里的跳转记录：请求 /films/871910984-kodak-portra-400，落在 [20251125 /photos](https://web.archive.org/web/20251125061335/https://www.lomography.com/films/871910984-kodak-portra-400/photos)）
- r/analog 只有一层：帖子流加侧栏。所谓"二级"就是 Wiki 和固定栏目的搜索链接（例如 `flair:community "OTW"` 的搜索结果就是 POTW 的历史）— [r/analog 2026-08-22](https://web.archive.org/web/20260822130748/https://old.reddit.com/r/analog/)

### Inferences
- Koco 的结构可以对上：一级 = 本期题目（日/周）、相册（全部作品）、我的；按胶卷看是相册的一个筛选或一个分页，不需要自己的一级入口。Lomography 放了十个维度，都不在一级，这一点可以参考。

### Gaps
- /browse 组合筛选页的界面（下拉框还是标签）没抓到。

## 3) 题目/比赛、分类（按相机、按胶卷）、精选三者的关系

### Takeaway
三者用的是同一个作品池，是这个池子的不同索引，不是各自独立的频道。一张照片上传到 LomoHome 后带着相机、胶卷等元数据，自动出现在对应的相机页、胶卷页、城市页里；投比赛时是"从你的 LomoHome 存档里选一张"；"Selected"是官方给照片打的精选标记，而且在胶卷页上它是排序方式之一（默认就是它）。

### Cited Findings
- **比赛从照片池里取图**："If you have a LomoHome, any picture from it can be uploaded directly from your archive to the competition post"；没有账号也可以填邮箱直接上传 — [Competitions About 2026-11-09](https://web.archive.org/web/20261109150142/https://www.lomography.com/competitions/about)
- 不登录投稿要邮件确认："We will send you an email to confirm the submission – please note if you don't confirm your photos won't enter the competition"；每人限投："up to 10 photographs taken on film"（Snapdash）/"up to five photographs"（FPD 2026）— [Snapdash](https://web.archive.org/web/20260201140706/https://www.lomography.com/competitions/3783-snapdash)、[FPD 2026](https://web.archive.org/web/20260626152030/https://www.lomography.com/competitions/3804-film-photography-day-2026)
- 投稿在比赛下有自己的编号（/competitions/3804/submissions/2140234），和照片编号（/photos/29596998）是两套。也就是说，投稿是"照片池里一张照片在某场比赛里的一条记录" — 同上两页的链接格式
- **按胶卷看的组织方式**（重点）：
  - 地址：/films/{id}-{名字}/photos。页面上有：面包屑 Films > Kodak Portra 400 > Photos；计数句"Discover over 115,586 photos taken with Kodak Portra 400, in the largest global archive of analogue photography"；商店块（这卷 Lomography 自己不卖时写"We don't stock this film, but our film category is full of great options"）；排序 Trending / Recent / Popular / Selected — [Portra 400](https://web.archive.org/web/20261106150733/https://www.lomography.com/films/871910984-kodak-portra-400/photos)
  - 默认排序是 Selected，旁边有提示："You're currently browsing selected photos – a curated collection handpicked by us, representing a smaller subset of all available photos… Use the Trending, Recent or Popular filter" — 同上
  - 可以"Watchlist"关注这个胶卷（也可以关注相机、国家等），关注后的照片出现在 /my/watchlist — 同上
  - "Browse Combinations"给出 10 个热门组合，带数量：Holga 120 CFN × Portra 400 (2k)、Canon AE-1 Program × Portra 400 (3k)、Contax G1 × Portra 400 × Carl Zeiss Planar 45mm f2 (1k) 等，点了进 /browse?camera=…&film=… — 同上
  - 页面上没有"热门摄影师"，没有评测/评论，也没有胶卷参数介绍（这份快照里没看到）— 同上
  - 胶卷总索引页写着"over 49,000 different films"，是用户自己填出来的条目，同一卷有好几个写法（"Kodak Color Plus 200 (35mm)"、"Kodak ColorPlus 200"、"Kodak Colorplus 200 (35mm)" 各是一个条目）— [Films](https://web.archive.org/web/20261109150432/https://www.lomography.com/films/)
  - 单张照片的元数据一层层往外链：Camera 链到"这个人用这台相机拍的"（/homes/kopanskarchive/cameras/…/photos），Film 链到"这个人用这卷拍的"，还有 City、Country、Decade、Year、Albums、6 个主色 — [照片 28831457](https://web.archive.org/web/20260302082824/https://www.lomography.com/homes/kopanskarchive/photos/28831457)
  - 按相机看结构相同，另外多了"Related Articles"（杂志里提到这台相机的文章）— [LC-A](https://web.archive.org/web/20260206195140/https://www.lomography.com/cameras/3322586-lomo-lc-a/photos)
- **精选**：Photo of the Day 放在 Photos 页顶部，配编辑评语："A stunning portrait of movement flowing gracefully with the water. From everyone here in Lomography, congratulations to justopenit on winning Photo of the Day!"，链接带 ref=potd_teaser — [Photos](https://web.archive.org/web/20260719180147/https://www.lomography.com/photos)；同类的还有"LomoHome of the Week"（ref=hotd_teaser）和"Wall of the Week"（ref=wotw_teaser）— [Homes](https://web.archive.org/web/20261101155324/https://www.lomography.com/homes)
- 杂志和照片池的关系：相机页底部列出相关杂志文章；杂志文章作者都链回他的 LomoHome — [LC-A](https://web.archive.org/web/20260206195140/https://www.lomography.com/cameras/3322586-lomo-lc-a/photos)、[Magazine](https://web.archive.org/web/20261115140939/https://www.lomography.com/magazine)
- 比赛和年度奖的关系："all competitions now serve as qualifying rounds to enter our TEN AND ONE Annual Lomography Photo Awards"；年度奖有 10 个固定类别，外加一个每年换的特别主题（2016 Identity and Migration … 2024 Analogue Intelligence、2025 Memento Mori, Memento Vivere；列表里没有 2023）— [About](https://web.archive.org/web/20261109150142/https://www.lomography.com/competitions/about)
- r/analog：POTW 是从帖子流里选出来的，不是单独开的栏目。wiki 的说法是"Photographer of the Week (aka POTW) was started to help the community get to know itself"；被选中的人得到一个 flair，比如"POTW-2025-W04"，此后跟着他的每条帖子显示 — [r/analog wiki 2025-09-13](https://web.archive.org/web/20250913140209/https://old.reddit.com/r/analog/wiki/index)、[r/analog 2026-08-22](https://web.archive.org/web/20260822130748/https://old.reddit.com/r/analog/)
- r/analog 规则 1 要求标题写"[相机, 镜头, 胶卷]"，不知道就写 Unknown Film 或 [Found Film]，在没有结构化字段的情况下用标题来按胶卷检索；规则 2：每人每天最多 1 帖 — 同上
- 第三方镜像里看到的说法："This accolade has been awarded based upon the number of votes during week 19"，即 POTW 有时按当周票数选（来自 Reddit 镜像的搜索摘要，未核实原帖）— [搜索结果镜像](https://redlib.belloworld.it/r/analog/comments/1gby5bn/city_dwellings_portra_800/ltrw4p2)

### Inferences
- 对 Koco 来说：每张作品带上胶卷字段（应用里拍摄时就能自动知道，比 Lomography 让用户手填准确得多，不会出现一卷胶卷好几个名字的情况），这样"按胶卷看"不用另做内容，就是作品池按胶卷字段过滤。题目投稿是"作品 × 题目"的一条记录，精选是作品上的一个标记。这和 Lomography 的模型一致。
- Lomography 让胶卷页默认显示 Selected，是一个现成的冷启动做法：数量少的时候只露出精选，而且明说这是精选。

### Gaps
- Photo of the Day 怎么选、谁来选，页面没写（未核实）。
- 胶卷页有没有 Reviews 标签：这份 2026 快照里没看到。Lomography 商店的商品页有评价，但那是商店，不是社区（未核实）。

## 4) "人聚在一起产出内容"的信号

### Takeaway
Lomography 用的是大计数（累计投稿、累计照片）、每张照片下面的点赞人名单、"本日/本周"人工点名，以及名单式的获奖公告（列出用户名并链接到主页）；线下有 LomoWalk 回顾和每月社区回顾。r/analog 用的是投票数、评论数、POTW flair 和固定周期的帖子。

### Cited Findings
- 比赛页总计数："Lomography Community members around the world have submitted 2,025,250 photos to 3,381 competitions and counting!" — [Competitions 2026-07-21](https://web.archive.org/web/20260721002944/https://www.lomography.com/competitions)
- 每个比赛卡片：类型（LomoMission: / Lomography Awards:）、标题、"423 Submissions"、状态（In Progress / Finished）、截止"2026-08-15 23:59"、一句口号 — 同上
- 投稿量的量级（真实数，同一快照）：一般 LomoMission 125–1,868；"Lomography Japan Turns 25!" 10,020；年度奖各类 2,282–14,875 — 同上
- 节奏：LomoMission 截止日集中在每月 1 日和 15 日（07-01、06-15、06-01、05-15、05-01、04-01、03-15、02-15、02-01），通常同时有 2 个进行中，联名活动另外插进来 — 同上（节奏是我根据日期推出来的）
- 获奖公告："The Winners — Congratulations to: emled, zoda, ilcontrariodime_, kazuya & ienyamasaki"，每个名字链接到他的主页，5 张获奖图放在投稿网格上面；奖品"one of five lucky winners to snag a voucher worth 20 USD/EUR" — [FPD 2026](https://web.archive.org/web/20260626152030/https://www.lomography.com/competitions/3804-film-photography-day-2026)
- 比赛首页的"Award Winning"条：24 张历届获奖图 — [Competitions](https://web.archive.org/web/20260721002944/https://www.lomography.com/competitions)
- 评选：月赛由"members of our own staff and partners"选；决赛评审团包括"a selection of trusted Lomographers from the community, LomoAmigos, and experts" — [About](https://web.archive.org/web/20261109150142/https://www.lomography.com/competitions/about)
- 单张照片："6 Likes"，后面列出 6 个点赞人的用户名；没有评论时显示"No Comments" — [照片 28831457](https://web.archive.org/web/20260302082824/https://www.lomography.com/homes/kopanskarchive/photos/28831457)
- 用户卡片计数：评论 218、获赞 52,909、照片 1,481，"Here since 2026" — [Homes](https://web.archive.org/web/20261101155324/https://www.lomography.com/homes)
- "Get in touch with me for: Film Swaps, Sharing My Hobbies & Casual Hangouts"：兴趣标签既能当找人的筛选条件，又在资料卡上告诉别人可以找他做什么 — 同上
- 杂志的近况信号：2026-11-15 发了"Lomography Community Recap: October 2026"，摘要是"Here's your monthly dose of the latest happenings in the Lomography Community! … the latest scoop on our ongoing Competitions"；每月一篇（4、5、6 月都有）— [Magazine](https://web.archive.org/web/20261115140939/https://www.lomography.com/magazine)、[Magazine/news 2026-08-01](https://web.archive.org/web/20260801164241/https://www.lomography.com/magazine/news)
- 杂志里大量社区成员内容：例如"Community Callout: Lomo MC-A Travelling Book Project: 10 empty books that will go from hand to hand"；"Synesthesia Mixtape … inviting Community members to curate image-inspired playlists"；"Together Through Analogue"系列 — [Magazine](https://web.archive.org/web/20261115140939/https://www.lomography.com/magazine)
- 线下：LomoWalk 回顾文章，例如"Recap: London Graphic Centre LomoWalk"、"Recap: Bristol Folk House 35 mm Camera LomoWalk"；顶栏有 Meetups — [Magazine/news](https://web.archive.org/web/20260801164241/https://www.lomography.com/magazine/news)
- 杂志文章的计数很小也照样显示：每篇点赞 1–8、评论 2–7 — [Magazine](https://web.archive.org/web/20261115140939/https://www.lomography.com/magazine)
- r/analog：每帖的投票数（例如 1677）和评论数（63 comments）；"4 users here now"；固定栏目：每周 Ask Anything、每周 POTW、每周 Gear Photos、每月 Self Promotion；曾有"Best of the Year 2021"评选 — [r/analog 2026-08-22](https://web.archive.org/web/20260822130748/https://old.reddit.com/r/analog/)
- EMULSIVE Santa：一年一次的胶片礼物交换，2017 年有 783 人参加，来自 46 个国家；2022 年是第 8 届（2022 之后的情况未核实）— [Elfster 博客 2017](https://www.elfster.com/blog/2017/10/20/emulsive-hosts-global-exchange-of-gifts-for-film-photographers-who-love-their-art/)、[EMULSIVE 2022](https://emulsive.org/articles/emulsive-secret-santa-2022-registration-for-year-8-open-until-november-13th)
- FPP（Film Photography Project）的社区主要在 Flickr 群"Film Photography Podcast"：约 13,399 成员、47.16 万张照片，每人每天限投 1 张进群照片池（数据来自搜索摘要，快照日期不明，未核实）— [Flickr 群](https://www.flickr.com/groups/1227372@N20/)
- 35mmc 是"由读者撰写、小团队编辑"的社区博客，读者投稿走固定栏目"5 Frames With [相机] and [胶卷]"（搜索摘要，未逐页核实）— [35mmc 5 Frames With](https://www.35mmc.com/category/photography/5-frames-with/page/35)

### Inferences
- Lomography 的计数是"累计"，数字越大越好看；Koco 刚上线没有这种底气，应该用"本期""本卷"的小计数，或者干脆显示名单（谁按了喜欢，列出名字），而不是一个孤零零的数字。Lomography 自己在单张照片上也是列名字，数字只是附带。
- "获奖名单 + 链回主页"的做法成本低，效果好，适合 Koco 的每周题目。

### Gaps
- Lomography 单张照片页的评论区样式（这张照片没有评论）没看到。
- Lomography 是否有"关注用户"：主页上没看到 Follow 按钮的文字（可能在 JS 或登录后才出现，未核实）；能确认的是关注胶卷/相机的 Watchlist。

## 5) 网页版/横屏两栏布局：左栏/侧栏放什么、右侧放什么

### Takeaway
Lomography 的公开页面基本是单栏、通栏网格，没有常驻侧栏，"侧栏"的功能被挪到页面底部（入口词云、组合筛选、关注）。r/analog（old.reddit）是典型的两栏：左边帖子流，右边侧栏放身份、规则、Wiki 和固定栏目。

### Cited Findings
- Lomography 的胶卷页从上往下依次是：标题和计数、商店块、排序、网格、分页、关注、组合筛选。HTML 里是一串连续的 section，没有 aside（从快照结构判断，未在浏览器里渲染核实）— [Portra 400](https://web.archive.org/web/20261106150733/https://www.lomography.com/films/871910984-kodak-portra-400/photos)
- Lomography 的照片网格是按比例排的不等宽行（每格带 data-ratio，用 flex 按比例分宽度，行高 256px），不裁成方块 — 同上（HTML）
- 单张照片页：先是照片和上一张/下一张，元数据列表（Photographer / Uploaded / Tags / Camera / Film / City / Country / Decade / Year / Albums）、主色、点赞、评论、"More photos by"依次往下排 — [照片 28831457](https://web.archive.org/web/20260302082824/https://www.lomography.com/homes/kopanskarchive/photos/28831457)
- old.reddit r/analog 右侧栏依次是：订阅数和在线人数、公告、简介、规则、Wiki、社交账号、固定栏目、相关子版 — [r/analog 2026-08-22](https://web.archive.org/web/20260822130748/https://old.reddit.com/r/analog/)

### Inferences
- Koco 的横屏相机包两页对应关系可以这样排：左页 = r/analog 侧栏那一类（本期题目卡：题目、说明、截止、投稿数、上期获奖名单；以及筛选：按胶卷/按题目）；右页 = Lomography 式的纯图网格（插袋，只有图），点开一张再显示元数据（胶卷、拍摄者、喜欢的人、留言）。
- Lomography 不裁图、按比例排，和插袋固定格子有冲突。插袋可以用"照片在袋里留白边"来解决，不必裁图。

### Gaps
- 没有拿到 Lomography 和 Reddit 在宽屏下的渲染截图，栏宽比例没核实。

## 6) 冷启动：如何避免显空，哪些诚实、哪些算造假

### Takeaway
从这些社区里能看到的诚实做法有：默认只展示精选并说明是精选（Lomography 胶卷页）、人工每天/每周点名一个人、官方自己写内容（杂志）、按固定节奏开题（每月 1 日和 15 日）、用历史和获奖作品填页面，以及计数小也照实显示。没有看到任何一家用假用户或虚增计数。

### Cited Findings
- 默认 Selected 并写明"a curated collection handpicked by us, representing a smaller subset of all available photos" — [Portra 400](https://web.archive.org/web/20261106150733/https://www.lomography.com/films/871910984-kodak-portra-400/photos)
- 比赛首页即使只有 2 个进行中，也用"Award Winning"24 张和 20 个历史比赛把页面填满 — [Competitions](https://web.archive.org/web/20260721002944/https://www.lomography.com/competitions)
- 小比赛照样显示真实投稿数："Lomography × The Luna Collective: Shoot the Show on Film — 125 Submissions" — 同上
- 杂志文章点赞只有 1、2 也照样显示 — [Magazine](https://web.archive.org/web/20261115140939/https://www.lomography.com/magazine)
- "Random Photo / Random Home"提供不依赖新内容的浏览入口 — [Competitions 菜单](https://web.archive.org/web/20260721002944/https://www.lomography.com/competitions)
- Homes 页在没有个性化内容时给出现成的搜索建议："why not start in Thailand, France or the United States? Or … searching for those mentioning doubles, cats or coffee in their biographies" — [Homes](https://web.archive.org/web/20261101155324/https://www.lomography.com/homes)
- Lapse 的冷启动是强制拉人："The app forces you to add at least five friends before you're able to use Lapse"；每个群一卷 36 张，大家一起拍 — [Bustle](https://www.bustle.com/life/what-is-lapse-app-how-to-use-get-invite)、[TechCrunch 2021](https://techcrunch.com/2021/12/20/lapse-an-app-that-lets-you-snap-and-develop-rolls-of-film-with-groups-of-friends-raises-11m-from-gv-and-others)
- Lapse 的热度下滑：Photo & Video 分类排名从 2024-02-29 的第 29 名降到 2025-03-10 的第 99 名（第三方统计，未核实）— [onlineoptimism](https://www.onlineoptimism.com/blog/lapse-app-stats/)
- Dispo：照片"don't appear in the app until 9 am the next day"；投资方 Spark Capital 撤资，David Dobrik 退出董事会；2024–2025 是否停运没找到报道，App Store 页面仍在 — [Wikipedia](https://en.wikipedia.com/wiki/Dispo)、[PetaPixel tag](https://petapixel.com/tag/dispo/)、[App Store](https://apps.apple.com/cy/app/id1491684197)

### Inferences
- 诚实的做法：①官方账号用自己的样片开第一期（署名写明是官方）；②精选默认展示并写明"精选"；③历史题目和获奖作品当作"往期"展示；④计数照实（0 就写"还没有人投稿，第一张会是你的"）；⑤官方做每周回顾。
- 算造假的做法：假用户名、机器人留言或点赞；虚增"本期 128 人参加"；把官方样片伪装成用户作品；"正在看"这类假的实时信号。这份调研里的社区没有发现任何一家这样做。
- Koco 的"发布前审核"和 Lomography 的"Selected"可以合成一件事：通过审核就进作品池，其中再挑出精选；冷启动期间默认只看精选，并且写明。

### Gaps
- 没找到 Lomography、Reddit 早期冷启动的一手资料。

---

## 附：其他社区和应用逐项（2026 现状）

### Cited Findings
- **r/AnalogCommunity**：讨论区，和 r/analog 分工："This subreddit is to complement, not replace r/analog. The r/analog subreddit is for sharing your photos. This subreddit is for discussion"（镜像搜索摘要，未在 2026 快照中核实）— [镜像](https://reddit.fabiomanganiello.com/r/AnalogCommunity/comments/1aqjabj/meta_when_and_when_not_to_post_photos_here)；r/analog 规则 3 也写着"No gear/film cache posts, these should go in /r/AnalogCommunity" — [r/analog 2026-08-22](https://web.archive.org/web/20260822130748/https://old.reddit.com/r/analog/)
- **r/analog** 有 2,723,614 名订阅者（2026-08-22）— 同上
- **#believeinfilm（Instagram）**：第三方统计约 2,710 万帖、每天约 671 新帖（估算，未核实）；起源没找到 — [iqhashtags](https://iqhashtags.com/hashtags/hashtag/believeinfilm)
- **EMULSIVE**：社区活动以一年一度的 Santa 礼物交换为主（见第 4 节）；2022 年后的情况未核实
- **FPP**：Flickr 群加站内论坛（见第 4 节）
- **35mmc**：读者投稿博客（见第 4 节）
- **Lapse**：好友制，"friends not followers"；照片要在"暗房"里放几个小时才能看，不能修图；2023 年改得更像普通社交平台，加了个人主页 — [Medium/Lapse](https://medium.com/@lapse/introducing-lapse-the-shared-disposable-camera-for-friends-not-followers-b845d362f3ac)、[TIME](https://time.com/6334440/lapse-photo-app-instagram)
- **Dispo**：第二天早上 9 点冲出来，可以按"胶卷"整理照片 — [Axios 2021](https://www.axios.com/2021/02/16/retro-photo-app-is-winning-buzz)

### Gaps
- **Kodak / Ilford 官方社区页**：这次没查（工具调用次数到了上限），未核实。
- **NOMO、Dazz、1998 Cam、Huji、Retro**：没有找到它们有站内社区的资料。这些应用以滤镜/相机模拟为主，分享走系统分享到 Instagram 等（这是我的已有印象，没核实）。按要求标记为"未发现社区（未核实）"。
- r/analog 规则页的最新全文（官方 rules 页 2026 版）没抓到，用的是侧栏里的规则文本（2026-08-22）。
