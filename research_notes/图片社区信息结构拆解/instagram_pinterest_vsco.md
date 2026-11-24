# Instagram / Pinterest / VSCO 图片社区信息结构拆解

> 调研日期 2026-11-24。每条事实附 URL；"截图观察"指 App Store 官方截图（本地文件 scratchpad/shots/*.jpg），为目测、未逐像素核对，数量为近似值。未找到来源的放在"Gaps"。**没有编造任何数字**。

## Instagram：首页/Explore/Reels/主页、hashtag 页、Add Yours、网页与 iPad 侧栏

### Takeaway
Instagram 的骨架是"关注流 + 算法流（Reels/Explore）+ 私信"，hashtag 和 Add Yours 都只是**同一个作品池的索引**，不是独立频道；2025–2026 年导航持续向 Reels 和私信倾斜。大屏（网页、iPad）用左侧固定图标栏（约 7–8 项）+ 右侧单列内容，没有真正的"目录栏"。

### Cited Findings

**1) 内容清单表（以已核实信息为限）**

| 模块 | 内容 | 每屏数量 | 首页级/二级 |
|---|---|---|---|
| Home（关注流） | 关注者的帖子与 Reels；顶部 Stories 头像条 | 单列，一屏约 1 张大图（截图观察：iPad 首页一屏 1 帖 + 顶部约 8 个 Story 头像） | 一级 |
| Reels | 全屏竖版短视频，评论可在旁侧面板打开（iPad） | 1 条/屏 | 一级 |
| 私信 DMs | 会话列表 + 对话 | 列表若干行（iPad 两栏） | 一级（2025 新导航测试中位于中央） |
| Search/Explore | 搜索 + 推荐网格 | 网格（具体数量未核实） | 一级 |
| Profile | 作者主页网格 | 网格（未核实） | 一级 |
| Hashtag 页 | Top（及历史上的 Recent、Reels） | 网格 | 二级 |
| Add Yours 串 | 同一提示下所有人的 Story 回应 | 逐条浏览 | 二级（从贴纸进入） |

- iPad 应用 2025-09-03 首发，默认落在 Reels，Stories 在顶部；左侧边栏含关注流、DMs、Search、Explore、通知 — [TechCrunch 2025-09-03](https://techcrunch.com/2025/09/03/instagram-is-finally-launching-an-ipad-app/)
- 当时 iPad 的 Following 流有三种视图：All（关注者帖子+推荐）、Friends（互关）、Latest（时间倒序），可重排顺序 — [TechCrunch 2025-09-03](https://techcrunch.com/2025/09/03/instagram-is-finally-launching-an-ipad-app/)
- iPad 上看 Reels 时评论在视频旁的侧面板展开；私信页左侧保留会话列表、右侧是具体对话 — [TechCrunch 2025-09-03](https://techcrunch.com/2025/09/03/instagram-is-finally-launching-an-ipad-app/)
- 2026-05-08：iPad 版改为与 iPhone 一致，放弃 Reels 优先；Reels 移到第二个导航位，删除 iPad 独有的 Following 标签（文章未说明栏数和横屏布局） — [9to5Mac 2026-05-08](https://9to5mac.com/2026/05/08/instagram-redesigns-ipad-app-to-what-it-always-should-have-been)

**2) 入口层级**
- 2025-10 Mosseri 宣布可选测试的新底栏：Home、Reels、DMs、Search、Profile 五项；"发布"按钮从底栏移到左上角；各标签可左右滑动切换。Mosseri 原话："Reels and DMs have driven most all our growth…we are exploring making them the first two tabs" — [Engadget](https://www.engadget.com/social-media/instagram-tests-new-layout-that-puts-the-spotlight-on-reels-and-dms-215407062.html)；[Social Media Today](https://socialmediatoday.com/news/instagram-prompting-more-users-test-new-ui-reels-dms/803178)
- 各来源对 Search 位置说法不一（第 4 位 vs 与 Reels 互换） — [Engadget](https://www.engadget.com/social-media/instagram-tests-new-layout-that-puts-the-spotlight-on-reels-and-dms-215407062.html)。**是否已全量上线未核实**（见 Gaps）。
- 首页放：Stories 条 + 关注/推荐帖子流 — [TechCrunch](https://techcrunch.com/2025/09/03/instagram-is-finally-launching-an-ipad-app/)；截图观察（instagram_ipad.jpg 第 1 张）。
- 二级页 —— hashtag 页：2020 年美国大选前曾临时下线 Recent；2022-04 起测试移除 Recent，只留 Top 和 Reels，官方称新内容会出现在 Top 里 — [TechCrunch 2022-04-19](https://techcrunch.com/2022/04/19/instagram-removes-recent-tab-hashtag-pages/amp/)；[9to5Mac 2022](https://9to5mac.com/2022/04/19/instagram-ios-hashtag/)
- 二级页 —— Add Yours：在 Story/Reel 里写一个提示，别人点贴纸添加自己的内容 — [Instagram Help](https://help.instagram.com/iphone-app/204990845482566)；回应形成公开串，任何人可浏览或加入（第三方说明） — [Bustle](https://www.bustle.com/life/add-yours-sticker-instagram-stories)；卡住时可点骰子随机生成提示（第三方，未在官方页核实） — [Beebom](https://beebom.com/how-use-add-yours-sticker-instagram-story/amp/)

**3) 题目/挑战、分类、精选的关系**
- hashtag 页的 Top 是按互动和相关性排序的同一池内容（2020 年移除 Recent 后用户只能看 Top） — [TechCrunch 2022](https://techcrunch.com/2022/04/19/instagram-removes-recent-tab-hashtag-pages/amp/)
- Add Yours 串就是普通 Story 按同一提示聚合而成 — [Instagram Help](https://help.instagram.com/iphone-app/204990845482566)
- 没有找到 Instagram 设官方"题材/器材分类"频道或编辑精选频道的来源。

**4) "人聚在一起"信号**
- 截图观察（instagram_ipad.jpg）：帖子卡顶部有作者头像+名字，底部有点赞/评论/分享图标和"liked by …"；Reels 有右侧评论面板、表情快速回复；Stories 头像环表示近况。
- Add Yours 贴纸本身是一种"同题接力"信号，显示参与串 — [Instagram Help](https://help.instagram.com/iphone-app/204990845482566)

**5) iPad/网页两栏布局**
- 网页版（2022-11 起）：主菜单竖放在左侧，包含 Home、Search、Explore、Messages、Notifications、Create、Profile + More（约 8 项）；侧栏随页面展开/收起 — [TechCrunch 2022-11-08](https://techcrunch.com/2022/11/08/instagram-is-updating-its-web-interface-to-take-advantage-of-large-screens)；[Digit](https://www.digit.in/news/apps/instagram-web-ui-gets-a-user-friendly-facelift-here-is-what-has-changed-65885.html)（Reels 项是否在其中，两来源未统一）
- iPad：左侧窄图标栏（截图观察约 7 个图标：Home、Reels、DM、Search、通知、新建、头像），右侧单列内容；私信页是"会话列表 | 对话"两栏；Reels 页是"视频 | 评论"两栏 — 截图观察 + [TechCrunch](https://techcrunch.com/2025/09/03/instagram-is-finally-launching-an-ipad-app/)
- 左栏是**固定的导航图标**，不是可滚动的话题索引。

**6) 冷启动**
- Instagram 本身不是冷启动参照；可借鉴的诚实做法：Add Yours 提供"提示词 + 骰子随机提示"，让人有东西可接 — [Instagram Help](https://help.instagram.com/iphone-app/204990845482566)；[Beebom](https://beebom.com/how-use-add-yours-sticker-instagram-story/amp/)

### Inferences
- 对 Koco：Instagram 证明"话题页"可以只是一个索引视图（Top 排序），不必单独建频道；但它取消 Recent 的做法对小社区不适合——人少时"最新"才能让参与者看到自己。
- 大屏左栏只放 5–8 个固定入口是主流做法，可滚动目录不是 Instagram 的模式。

### Gaps
- 2025-10 新底栏测试是否在 2026 已全量上线：一篇第三方文章（inro.social）声称 2026 布局，但页面 404，未核实。
- Hashtag 页 2026 年的确切标签（Top/Reels/Recent）未找到官方当前说明。
- Explore 网格每屏数量、Profile 网格列数没有官方来源（行业常识为 3 列，但未引证）。
- 2026-05 iPad 改版后的横屏栏数、侧栏项数未见报道。

## Pinterest：首页、Today/Explore、搜索/分类、Boards 与 Group boards、iPad 与网页

### Takeaway
Pinterest 是"一个巨大 Pin 池 + 多种索引"：Home（个性化）、Today/Explore（编辑+趋势）、搜索（带分类筛选 Shop/Profiles/肤色等）、Boards（用户自建收藏夹）。协作单位是 group board，权限由板主控制。网页版左侧是窄图标栏，右侧是瀑布流。

### Cited Findings

**1) 内容清单表**

| 模块 | 内容 | 每屏数量 | 首页级/二级 |
|---|---|---|---|
| Home | 关注的人和 board 的 Pin + 推荐 Pin/账号；为你挑选 | 瀑布流（截图观察 iPad 竖屏 3 列、一屏约 9–10 张） | 一级 |
| Today / Explore | 基于站内趋势的策展合集，每日更新 | 未核实 | 一级（部分地区无） |
| Search | 建议话题、Pin/board/人；Shop、Profiles 分栏；美妆肤色/发型筛选；Lens | 瀑布流 | 一级 |
| Pin 详情 | 大图 + 作者、点赞/评论数、Save、Visit site；下滑"相关想法" | 1 张主图 + 相关流 | 二级 |
| Board | 用户收藏夹；底部 Find more ideas | 瀑布流 | 二级 |
| Group board | 多人共建 board | 瀑布流 | 二级 |

- Home 显示关注的人与 board 的 Pin 以及推荐 Pin/账号；"Click Home to view Pins that have been picked for you" — [Pinterest Help](https://help.pinterest.com/en/article/discover-ideas-on-pinterest)
- Today："a curated collection of ideas based on what's trending on Pinterest"，每天有新内容 — [Pinterest Help](https://help.pinterest.com/en/article/discover-ideas-on-pinterest)；[Pinterest Help: Today tab](https://help.pinterest.com/en/article/today-tab)
- Today 于 2020-03 推出，每日刷新，启动时由 Pinterest 团队策展，计划邀请客座编辑 — [TechCrunch 2020-03-24](https://techcrunch.com/2020/03/24/pinterest-launches-a-today-tab-featuring-daily-recommendations-and-trending-topics)
- Explore 部分地区不可用（帮助中心提示） — [Pinterest Help](https://help.pinterest.com/en/article/discover-ideas-on-pinterest)
- 搜索：点搜索框给出基于兴趣和趋势的建议话题；可搜 Pin、board、人；Shop / Profiles 分栏；美妆可按肤色、发型筛选；Guided Search 仅美国 iPhone — [Pinterest Help](https://help.pinterest.com/en/article/discover-ideas-on-pinterest)
- 截图观察（pinterest_ipad.jpg）：Pin 详情有"♡ 65 / 评论 4 / 分享 / Save / Visit site"，作者名（Katie's Kitchen）、评分；搜索结果顶部有可横滑的细分标签（Modern rustic / Holiday table / Centerpiece…）；底部浮动栏为"主页 + 搜索框 + 头像"。

**2) 入口层级**
- 网页（帮助中心描述）：顶部左侧有 Home、Explore 两个标签；左侧竖排图标：Boards、Messages、Notifications、Create（方形加号），设置齿轮在左下 — [Pinterest Help: explore the home feed](https://help.pinterest.com/article/explore-the-home-feed)；另一帮助页说 Create 在"左上"，官方文档之间有出入 — [Pinterest Help node/3431](https://help.pinterest.com/en/node/3431)
- 移动端一级入口的确切数量：未找到 2026 官方说明（见 Gaps）。

**3) 题目/分类/精选关系**
- 都是同一 Pin 池的不同索引：Home=个性化排序，Today/Explore=编辑+趋势策展，Search=关键词+细分标签+筛选，Board=用户手工整理 — 依据上述 [Pinterest Help](https://help.pinterest.com/en/article/discover-ideas-on-pinterest)
- 没有找到 Pinterest 当前运营"挑战"频道的来源。

**4) "人聚在一起"信号**
- Group board：板主决定协作者能否保存/整理 Pin、评论和表态、邀请他人；可移除协作者；被邀请者收到通知 — [Pinterest Help: group boards](https://help.pinterest.com/en/article/group-boards)
- 社区帖反映过协作者不可见、无法移除的 bug — [Pinterest Business Community](https://community.pinterest.biz/t/group-board-collaborators-are-invisible-unable-to-remove-them-help/13662.md)
- 卡片信号（截图观察）：瀑布流卡片多数只有图 + "…"菜单，个别带一行标题；作者和计数主要在详情页出现——Pinterest 刻意弱化卡片上的人。

**5) iPad/网页两栏布局**
- 网页：左侧窄竖栏放固定功能图标（约 4–5 个 + 设置），右侧整宽瀑布流 — [Pinterest Help](https://help.pinterest.com/article/explore-the-home-feed)
- iPad：截图观察为全宽瀑布流（竖屏 3 列）+ 底部浮动导航，未见左侧栏；Pin 详情在 iPad 上以上图下"Shop the Pin"横排呈现。**横屏布局未核实**。

**6) 冷启动**
- Today 启动时由内部团队策展、计划引入客座编辑 — [TechCrunch 2020](https://techcrunch.com/2020/03/24/pinterest-launches-a-today-tab-featuring-daily-recommendations-and-trending-topics)；这是诚实的"编辑推荐"，标明为策展。
- 搜索框的"建议话题"相当于提示词，降低空白感 — [Pinterest Help](https://help.pinterest.com/en/article/discover-ideas-on-pinterest)

### Inferences
- 对 Koco：Pinterest 的 board 模型最接近"相册/活页夹"——每个人的收藏夹就是一页相册，group board 就是"大家往同一本册子里放照片"。用板主权限分级（能放/能评/能邀请）可直接借用。
- 卡片上弱化作者、详情页再显示人，适合图片优先的相册页；但对"人聚在一起"的感受较弱。

### Gaps
- 2026 年 Pinterest 移动端底栏确切项目和数量未找到官方来源（截图只见浮动的 主页/搜索/头像）。
- iPad 横屏是否有左侧栏：无来源。
- Today 与 Explore 是否已合并/改名：帮助中心两者并存，未确认。
- 2025 年网页侧栏是否重做：搜索无结果。

## VSCO：Feed、Discover/Search、Spaces、Challenges、编辑精选、iPad/网页

### Takeaway
VSCO 的社区 = 策展 Feed + Spaces（最多 150 人、按主题的共享相册，无点赞数）+ Challenges（官方/品牌发题，按指定 hashtag 投稿）+ 官方 Curation（按 #VSCO 选图转发到 VSCO 账号/Collection）。三者都建立在同一作品池上：hashtag 是投稿与精选的连接件，Spaces 是独立的小组相册。长期坚持"不做公开点赞计数"。

### Cited Findings

**1) 内容清单表**

| 模块 | 内容 | 每屏数量 | 首页级/二级 |
|---|---|---|---|
| Feed | "top curated VSCO content"；截图中有 Creator Spotlight 横条 | 单列大图（截图观察：1 张 + 讨论预览） | 一级 |
| Search | 找摄影师与灵感 | 未核实 | 一级 |
| Spaces | 主题共享相册，列表每项含封面、名称、描述、成员头像数、Join | 截图观察：分类列表 3 行 + 1 个 Space 卡 | 一级（有 Spaces 标签页；Browse 子页） |
| Profile | Recent / Galleries / Spaces / Blogs 四个标签；Follow / Message；PRO 与 OPEN TO WORK 标记 | 两列网格（截图观察） | 一级 |
| Challenges | 官方/品牌出题、截止日期、hashtag 投稿 | 未核实 | 二级（入口位置未核实） |
| Curation / Collection | 官方转发精选 | 未核实 | 二级 |
| Discussions / Messages | 作品下讨论、私信 | — | 二级/一级（未核实） |

- Feed 显示 "top curated VSCO content"；导航含 Search；有 "From the Community" 展示与 "Get noticed" 计划 — [VSCO Community](https://www.vsco.co/features/community)
- 社区页列出的版块：Studio Pro、Discussions、Challenges、Reposts、Curation、Creator stories、In Focus、Messages、Blogs、Profile、Spaces、Coaching（这是官网介绍页的导航，**不等于 App 底栏**） — [VSCO Community](https://www.vsco.co/features/community)
- 截图观察（vsco_iphone.jpg）：Feed 卡片 = 大图 + 作者（Robinson）+ 星标/转发/讨论图标 + "Join the discussion" 讨论预览 + "CREATOR SPOTLIGHT"；Profile 标签 Recent/Galleries/Spaces/Blogs；Spaces 页有 Portrait / Fashion / Nature 分类行，Space 卡 "Daily Minimalism" 显示成员头像+"20"、描述、JOIN 按钮。

**2) 入口层级**
- Spaces：在 App 的 Spaces 标签点 Create，填名称与可选描述、邀请协作者、上传图片 — [VSCO Spaces](https://www.vsco.co/features/spaces)
- 公开 Spaces 在 Browse 标签出现，突出热门与精选，可搜索；可按话题和最近更新排序/查找；私密 Space 不可搜索，只能链接进入 — [VSCO Spaces](https://www.vsco.co/features/spaces)
- 二级 —— Challenges：读题和截止日期 → 在 VSCO 编辑并发布 → caption 里写确切的挑战 hashtag；可在该 hashtag 下浏览其他投稿；完成的挑战会被展示；品牌挑战面向 Pro 会员，入选者获报酬 — [VSCO Photography Challenges](https://www.vsco.co/features/photography-challenges)
- 二级 —— Curation：用 #VSCO 分享即有资格；每天策展；精选转发到 VSCO Collection — [VSCO Curation](https://www.vsco.co/features/curation)

**3) 题目/挑战、分类、精选的关系**
- Challenges 与 Curation 都通过 hashtag 从同一作品池取图（挑战用专属 hashtag，精选用 #VSCO） — [Challenges](https://www.vsco.co/features/photography-challenges)；[Curation](https://www.vsco.co/features/curation)
- Spaces 是独立容器（有成员、有权限），可按话题浏览 — [VSCO Spaces](https://www.vsco.co/features/spaces)
- 分类：Daily Dot 报道称 VSCO 的策展合集按内容（人像、自然）或季节组织（年份未核实） — 来源为搜索摘要 [Daily Dot](https://dailydot.com/?p=641469)，**未直接打开核实**
- 2026 年 VSCO 摄影师故事提到"社区提示（prompts）"、出色投稿会被团队策展高亮 — [VSCO: Marin Kirkman](https://www.vsco.co/photographer-stories/marin-kirkman)（仅见搜索摘要）

**4) "人聚在一起"信号**
- Spaces：最多 150 名协作者；无点赞计数；可就单张作品讨论；板主可审批加入、移除成员、删帖删评论；非会员也可通过只读链接查看 — [VSCO Spaces](https://www.vsco.co/features/spaces)
- 活跃度不一："some Spaces update several times an hour, while others post every few days" — [VSCO Spaces](https://www.vsco.co/features/spaces)
- 2022 推出 Spaces；2023-03 起可发纯文字帖、加入前可预览；VSCO 总裁："This is why we still don't do likes and comments."；免费用户每天可向非关注者新开 3 个对话 — [TechCrunch 2023-02-27](https://techcrunch.com/2023/02/27/vsco-is-growing-into-a-legit-social-network-for-photographers)
- 注：2023 年 VSCO 称不做点赞和评论，但现行官网已有 "Discussions"（作品下讨论），截图中也有 "Join the discussion"——"无评论"已部分改变，"无公开点赞计数"在 Spaces 页仍成立 — [VSCO Spaces](https://www.vsco.co/features/spaces)；[VSCO Community](https://www.vsco.co/features/community)
- 线下：照片漫步常配一个 Space 供参与者分享 — [VSCO Spaces](https://www.vsco.co/features/spaces)
- 入选信号：作品被 VSCO 官方转发 / Creator Spotlight — [Curation](https://www.vsco.co/features/curation)；截图观察

**5) iPad/网页两栏布局**
- 截图观察（vsco_ipad.jpg）：App Store 上 iPad 截图是旧版界面（展示 "Journal / Collection"、文章日期 2018-04-11），**不能代表 2026 现状**；画面为单栏放大，不见左侧栏。
- 未找到 VSCO 2026 iPad 或网页两栏布局的来源。

**6) 冷启动**
- Spaces 页公开列出精选/热门 Space 名称（Daily Minimalism、Film + Film Aesthetic、Beauty in the Mundane 等）作为示范 — [VSCO Spaces](https://www.vsco.co/features/spaces)
- 每日官方策展 + 挑战题目提供"有东西可看、有题可答" — [Curation](https://www.vsco.co/features/curation)；[Challenges](https://www.vsco.co/features/photography-challenges)
- 坦白承认低频："others post every few days"——官方并不假装每个 Space 都热闹 — [VSCO Spaces](https://www.vsco.co/features/spaces)

### Inferences
- 对 Koco 最可借鉴：Space = "一本主题相册 + 一句描述 + 成员头像数 + 加入"，这正好对应"右页是相册活页"的形态；无点赞数也降低人少时的冷清感。
- "题目 → hashtag → 同池投稿 → 官方精选转发"是一条低成本、诚实的链路：题目和精选都不需要独立内容库。

### Gaps
- VSCO App 2026 底栏确切项（截图未显示底栏）未核实。
- Discover 页是否仍独立存在：官方现行页面只提 Feed 与 Search。
- Challenges 在 App 内的入口位置、频率未说明（官网只说看 Blogs）。
- iPad/网页布局：无可靠来源。

## 跨产品：冷启动的诚实与造假边界（综合）

### Takeaway
三家可查证的冷启动手段都是"编辑策展（明示）+ 提示词/题目 + 搜索建议"，没有找到它们使用虚构用户的来源。

### Cited Findings
- Pinterest Today 明示由团队策展 — [TechCrunch 2020](https://techcrunch.com/2020/03/24/pinterest-launches-a-today-tab-featuring-daily-recommendations-and-trending-topics)
- VSCO 每日策展并转发到官方账号（署原作者） — [VSCO Curation](https://www.vsco.co/features/curation)
- Instagram Add Yours 骰子提示 — [Beebom](https://beebom.com/how-use-add-yours-sticker-instagram-story/amp/)
- VSCO 公开承认部分 Space 几天才更新一次 — [VSCO Spaces](https://www.vsco.co/features/spaces)

### Inferences
- 诚实：官方账号署名发的示范作品、标明"编辑精选"、题目/提示词、显示真实（哪怕很小的）计数或干脆不显示计数（VSCO 做法）、标明"最近更新于 X 天前"。
- 算造假：用假账号发作品或留言、虚增计数、把官方样片伪装成用户投稿、伪造"刚刚有人加入"类近况。（此为推论，非引用。）

### Gaps
- 未找到三家早期冷启动的一手资料（如 Instagram 2010、VSCO 2014 的种子用户策略）。
