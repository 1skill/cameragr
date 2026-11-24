# 双栏（左导航 + 右内容）布局：社区与图片产品的左栏怎么用、装多少

调研日期：2026-11-24。截图证据来自已下载的 App Store iPad 截图（本地路径 `/private/tmp/claude-501/-Users-shuiying-cameragr/0ba8fed5-d9eb-51f8-bbdc-5f5771c7495b/scratchpad/shots/*.jpg`，下文写作"[截图: xxx_ipad.jpg]"）。截图是营销图，未必等于当前线上版本，按"截图所示"处理。Apple HIG 原文通过其公开 JSON 接口取得（developer.apple.com/tutorials/data/design/human-interface-guidelines/*.json），对应网页链接见下文。

---

## 问题一：左栏里放什么、放多少（固定区、可滚动列表、计数、预告、个人状态）

### Takeaway
主流产品的左栏分两种：**窄图标栏**（Instagram、Flickr iPad、Pinterest web：约 5–8 个固定入口，不承载"内容"）和**宽列表栏**（Reddit、Discord、Slack、Apple Photos、图虫圈子：上方 3–6 个固定入口 + 下方可折叠的分组列表，列表长度可以很长，靠折叠/筛选控制）。只有宽列表栏才真正"装社区"：群组、频道、话题、收藏。

### Cited Findings
**窄图标栏（只装一级入口）**
- Instagram 网页版 2022 年把主菜单改成左侧竖栏：Home、Search、Explore、Messages、Notifications、Create、Profile，加一个 More；侧栏会依所在页面展开/收起 — [TechCrunch 2022](https://techcrunch.com/2022/11/08/instagram-is-updating-its-web-interface-to-take-advantage-of-large-screens)；[iDownloadBlog](https://www.idownloadblog.com/?p=927102)（列表里没有 Reels；2026 年当前内容未找到来源核实）。
- Instagram iPad 截图：左侧一条窄图标栏约 7 个图标，无文字，右侧是单列 feed；私信页变成"图标栏 + 会话列表（头像+名字+最近一句）+ 对话"三栏 — [截图: instagram_ipad.jpg]。
- Flickr iPad 截图：左侧黑色窄图标栏约 6 个图标；右侧是信息流 / 拼贴网格 / 群组页（群组页头部显示 "Epic Adventures · 282 Members"）— [截图: flickr_ipad.jpg]。
- 小红书 iPad 截图：不用左栏，用顶部"关注/发现/附近"分段 + 底部 tab（首页/购物/+/消息/我），右侧 4 列瀑布流 — [截图: xiaohongshu_ipad.jpg]；[App Store](https://apps.apple.com/cn/app/xiao-hong-shu-gou-wu-bi-ji/id741292507)。小红书网页版左侧导航的具体条目未找到可靠来源（只知道网页端后来才补上发布与通知）— [woshipm 评测](https://www.woshipm.com/evaluating/5750106.html)、[IT之家](https://www.ithome.com/0/672/374.htm)。
- Pinterest iPad 截图未见左栏，主页为 3 列瀑布流 + 底部搜索 — [截图: pinterest_ipad.jpg]。未找到 2025–2026 年 Pinterest 网页版左栏改版的来源；历史改版都是把导航收到顶部 — [Digital Trends](https://www.digitaltrends.com/social-media/pinterest-testing-out-a-redesigned-look-with-engagement-in-mind/)。

**宽列表栏（装社区本身）**
- Reddit 桌面版左栏的分区（从屏蔽脚本的可隐藏项反推）：Start a Community、Games on Reddit、Custom Feeds、Recent、Communities、Resources；分类可折叠，但整个侧栏关闭时不能单独折叠 — [Greasy Fork: Reddit Cleanup](https://greasyfork.org/scripts/572151-reddit-cleanup)；[Firefox 插件 Reddit Nav Sidebar Collapser](https://addons.mozilla.org/firefox/addon/reddit-nav-sidebar-collapser)。（非官方来源；顶部固定的 Home/Popular 等条目未取得官方说明。）2023 年起桌面侧栏是吸顶的，和内容独立滚动 — [TechCrunch 2023](https://techcrunch.com/2023/08/01/reddit-updates-its-site-design-for-logged-out-users/amp)。
- Slack 侧栏：可建自定义分区（只自己可见），每个分区可单独筛选，默认 "Active only" 隐藏 30 天无新动态的会话；每区可按 A-Z / Recency / Priority 排序 — [Slack Help](https://slack.com/help/articles/360043207674-Organize-your-sidebar-with-custom-sections)。
- Apple Photos（iOS/iPadOS 18）把原来的 tab 合并为一个滚动视图，含 Pinned Collections（默认 Favourites、Recently Saved、Map、Videos、Screenshots）、Albums（含加入的共享相簿）、Memories 等，可重排、可隐藏 — [MacRumors iOS 18 Photos](https://www.macrumors.com/guide/ios-18-photos/)；[Apple Support](https://support.apple.com/en-au/121870)；[Cult of Mac](https://www.cultofmac.com/how-to/new-photos-app-ios-18)。iOS 26 又恢复了 Library / Collections 两个 tab，Collections 依次为 Recent Days、People and Pets、Pinned、Memories、Trips、Albums、Featured Photos，再加 Media Types 和 Utilities — [MacRumors iOS 26 Photos](https://macrumors.com/guide/ios-26-photos-app)。iPadOS 26 侧栏具体条目未找到来源核实。
- Threads 网页版没有传统左栏，而是"可钉住的列"：For You、Following、搜索、话题、账号、通知、收藏、点赞、Activity、Insights 等，最多钉 100 个 feed，每列可自动刷新 — [MacRumors 2024](https://www.macrumors.com/2024/05/16/threads-tweetdeck-web-view)、[Engadget](https://www.engadget.com/the-tweetdeck-clone-for-threads-is-finally-here-191132892.html)、[Meta 2025-04](https://about.fb.com/news/2025/04/new-features-threads-web-experience/)。
- Unsplash 2025-06-11 改版：顶栏只留搜索，"其余全部移进一个跟着你走的新侧栏"，侧栏放常用快捷入口、下载记录、收藏集等 — [Unsplash Blog](https://unsplash.com/blog/a-smarter-way-to-navigate-unsplash)。此前约 20 个常设 Topics 在顶栏随机排序，另有限时 Topic（约一个月、标明截止日期）— [Unsplash Help: Topics](https://help.unsplash.com/en/articles/3923698-topics)。
- 图虫 iPad 截图"发现圈子"：左侧竖排 10 个分类（热门推荐、风光旅行、人像写真、人文纪实、静物创意、独特小众、生活日常、手机摄影、摄影大V、高校·地域），右侧是该类的圈子列表，每行"缩略图 + 圈名 + 人数 · 作品数 + 加入按钮"（如"北京人像摄影 2263人 · 2万件作品"）— [截图: tuchong_ipad.jpg]。
- Glass iPad 截图：顶部分段 Explore / Members / Highlights / Series / Categories / Cameras / Lenses；"Cameras" 页是两列品牌字母表（Apple、Bronica、Canon…）；首页右侧有一列"社区成员动态"（头像+名字+一句评论）贴在照片旁 — [截图: glass_ipad.jpg]。
- Lomography 网站导航：Photos、Magazine、Competitions、Meetups、School、Travel、Homes、Shop；Magazine 下分 News、People、Gear、Tutorials、Places；Competitions 页写"会员已向 3,380 个比赛提交 2,023,583 张照片" — [Lomography Competitions](https://www.lomography.com/competitions?page=1)。（这是顶部导航，非左栏。）
- Dribbble Explore：Popular、New and Noteworthy，以及 Product Design、Web Design、Animation、Branding、Illustration、Mobile、Typography、Print 等分类；有 "Made With" 工具筛选 — [Abduzeedo](https://abduzeedo.com/node/85459)。Behance 当前筛选结构未找到来源。

### Inferences
- "装多少"有两档：一级入口 5–8 个（与 Material 3–7、HIG 默认 ≤5 tab 吻合）；二级列表（群组/圈子/分类）约 8–12 个可见，靠折叠、"仅活跃"筛选、自定义排序控制总量，而不是压缩字号。
- 图片社区（Instagram、Flickr、Pinterest、小红书）普遍把左栏做窄，让照片占满；只有当"社区单位"（圈子、频道、subreddit）是主角时才用宽列表栏。

### Gaps
- 各产品左栏的精确像素宽度、可见条目数没有官方数字；上面数字来自截图目测或非官方脚本。
- Reddit、Discord、小红书网页版、Pinterest 网页版的 2026 当前左栏条目无官方文档。

---

## 问题二：左栏如何表达"热闹"（未读、成员数、在线、新帖、最新动态预览）

### Takeaway
信号分三级：**点**（有新东西，白/蓝点）< **数字徽章**（与你有关，红）< **内容预览**（最近一句话、最近缩略图、人数·作品数）。克制是共识：HIG 要求徽章只留给关键信息，Slack 默认把不活跃的藏起来。

### Cited Findings
- Discord：服务器列表图标旁"小白点"表示有未读，红色徽章表示 @提及；用户长期抱怨即使设为"仅 @提及"仍显示白点 — [Discord 社区反馈](https://support.discord.com/hc/sv/community/posts/360051295334-Disable-unread-indicators-on-dock-taskbar-icons-and-server-list-icon-in-notification-settings)、[另一帖](https://support.discord.com/hc/it/community/posts/360058489651-change-unread-marker-to-highlight-channels-servers-with-notifications-enabled)。新版移动布局用蓝点表示普通未读 — [Discord 社区反馈](https://support.discord.com/hc/da/community/posts/360061629711-Different-colour-unread-message-pill-for-direct-messages)。（均为用户论坛描述，非官方文档；频道名加粗、"pill"细节未找到官方说明。）
- Apple HIG（Tab bars）："用徽章表示有关键信息……徽章是红色椭圆里白字数字或感叹号……只留给关键信息，以免稀释其意义" — [HIG Tab bars](https://developer.apple.com/design/human-interface-guidelines/tab-bars)。
- Slack 默认 "Active only" 隐藏 30 天无新动态的会话，即用"只显示活的"来营造活跃感 — [Slack Help](https://slack.com/help/articles/360043207674-Organize-your-sidebar-with-custom-sections)。
- 成员数/作品数作为活跃度：图虫圈子行"2263人 · 2万件作品"[截图: tuchong_ipad.jpg]；Flickr 群组头"282 Members"[截图: flickr_ipad.jpg]；Flickr 群组页显示 Members / Photos / Discussions 计数，讨论行显示回复数、最后回复人与时间 — [Flickr 群组讨论页示例](https://flickr.com/groups/central/discuss/33996/)。
- 最新动态预览：Instagram 私信列表每行"头像 + 名字 + 最近一句"[截图: instagram_ipad.jpg]；Glass 首页侧边一列成员评论流 [截图: glass_ipad.jpg]；Threads 每列可设自动更新以跟上新帖 — [Engadget](https://www.engadget.com/the-tweetdeck-clone-for-threads-is-finally-here-191132892.html)。
- 时间性：Unsplash 限时 Topic 会标出截止日期 — [Unsplash Help](https://help.unsplash.com/en/articles/3923698-topics)；Lomography 比赛页列出进行中比赛及投稿数（如某 LomoMission 1,051 件投稿）— [Lomography](https://www.lomography.com/competitions?page=1)。
- 社区抱怨：Flickr 帮助论坛有人说"几乎找不到活跃的群组" — [Flickr Help Forum 镜像](https://unoceans.un.org/www.flickr.com/help/forum/en-us/72157714720744427/index.html)（说明计数若长期不动，反而暴露冷清）。

### Inferences
- 对早期人少的社区，"人数·作品数"这类绝对数字可能显冷；"截止日期/本周新增/最近一张缩略图"这类时间性信号更不依赖规模。
- 点 vs 数字徽章的区分（Discord）在拟物里可映射为：小金属铆钉/指示灯 = 有新东西；手写数字小标签 = 与你有关。

### Gaps
- 未找到任何产品公开的"左栏信号对活跃度/点击"效果数据。

---

## 问题三：左栏选中如何改变右栏；所选分区内容稀少时如何让右栏保持饱满

### Takeaway
标准做法是"左栏持续高亮选中项 + 右栏顶部给范围标题/面包屑/二级筛选"。保持饱满的手法：混排相关内容（Flickr 搜索页"你的照片 / 你关注的人 / 所有人"三段）、按时间回溯、"精选"兜底、隐藏空分区；HIG 则要求不要隐藏入口，空时要解释原因。

### Cited Findings
- HIG Split views："在通往详情的每一栏中持续高亮当前选中项，帮助理解各栏关系、保持方向感"；tvOS 场景下"在主栏选筛选类别，结果在副栏显示"；默认主栏占 1/3、副栏 2/3，也可对半 — [HIG Split views](https://developer.apple.com/design/human-interface-guidelines/split-views)。
- HIG Tab bars："即使某区内容不可用也不要禁用或隐藏按钮……若某区为空，说明为什么没有内容" — [HIG Tab bars](https://developer.apple.com/design/human-interface-guidelines/tab-bars)。
- Flickr iPad 搜索结果页按范围分段："Your Photos / People you follow / Everyone on Flickr"，各带 View all，并有一排标签筛选（street、night、urban、sky…）— [截图: flickr_ipad.jpg]。
- 图虫：左侧分类切换，右侧标题保持"我的圈子 / 发现圈子"分段 — [截图: tuchong_ipad.jpg]。
- Apple Photos iOS 26 的 Collections 先放 "Recent Days" 再放其他集合；Pinned 可放 Favourites、Map、Videos 等系统集合 — [MacRumors iOS 26](https://macrumors.com/guide/ios-26-photos-app)、[Apple Support](https://support.apple.com/en-au/121870)（系统生成的集合天然不会空）。
- Slack 按"活跃"筛掉沉寂分区，避免点进去空 — [Slack Help](https://slack.com/help/articles/360043207674-Organize-your-sidebar-with-custom-sections)。
- Unsplash Topic 由编辑团队与客座策展人维护 — [Unsplash Help](https://help.unsplash.com/en/articles/3923698-topics)（人工策展兜底）。
- HIG Split views（watchOS）："启动时自动显示最相关的详情视图……如与位置、时间或最近操作相关的信息" — [HIG Split views](https://developer.apple.com/design/human-interface-guidelines/split-views)。

### Inferences
- 稀疏分区的可行兜底顺序：本分区内容 → 同分区更早内容 → 相关分区/全站同标签 → 编辑精选，并在右页用分隔条写明"以下来自……"，避免混淆范围。
- 打开时默认选中"最近有活动"的分区，而不是固定第一个。

### Gaps
- 未找到 Reddit/Discord 等官方关于"空社区页如何填充"的说明。

---

## 问题四：Apple HIG / Material 对侧栏宽度、条目数、层级深度、侧栏 vs tab 栏的指导

### Takeaway
Apple 2025–2026 的立场是"iPad 优先 tab 栏，复杂再转侧栏"；侧栏最多两级层级，更深用三栏 split view；要能隐藏但默认不隐藏；可让用户自定义。Material 3 Expressive：收起的 rail 96dp、放3–7 项；展开 220–360dp。

### Cited Findings
- 侧栏"需要大量纵向与横向空间。空间有限或想把更多屏幕给其他内容时，tab 栏等更紧凑控件可能更好" — [HIG Sidebars](https://developer.apple.com/design/human-interface-guidelines/sidebars)。
- "一般在侧栏中最多显示两级层级。层级超过两级时，考虑用在侧栏和详情之间加一个内容列表的 split view" — 同上。
- "内容多时用展开/折叠控件分组层级，让侧栏纵向空间保持可控"；"可能时让人自定义侧栏内容与顺序"；"考虑让人隐藏侧栏……避免默认隐藏以保证可发现性" — 同上。
- 图标颜色：默认用 app 强调色；少量固定色可强调含义（如 Mail 的 VIP 黄色）— 同上（2026-06-08 更新）。
- iPadOS："先考虑 tab 栏。tab 栏给内容更多空间……若要暴露的区域多于 tab 栏能容纳，可用 tab 栏可转换的侧栏外观" — 同上；iPadOS tab 栏在屏幕顶部，可固定或带转侧栏按钮；若让用户自选 tab，默认 5 个或更少 — [HIG Tab bars](https://developer.apple.com/design/human-interface-guidelines/tab-bars)。
- macOS："避免把关键信息或操作放在侧栏底部" — [HIG Sidebars](https://developer.apple.com/design/human-interface-guidelines/sidebars)。
- visionOS：层级深时可在某个 tab 内放侧栏做二级导航，侧栏选择不应切换当前 tab — 同上。
- Split view：iPadOS 可两栏（如 Mail）或三栏（如 Keynote）；宜用 1pt 细分隔线；tvOS 默认 1/3 : 2/3 — [HIG Split views](https://developer.apple.com/design/human-interface-guidelines/split-views)。HIG 未给 iPad 侧栏具体宽度数字。
- Material 3 Expressive：收起的 navigation rail 宽 96，展开 220–360；收起 rail 应含 3–7 个导航项，展开状态可显示收起时看不到的目的地 — [SAP Fiori M3 Navigation rail](https://www.sap.com/design-system/fiori-design-android/v26-4/components/m3-standard-components/navigation-rail/usage)、[pub.dev navigation_rail_m3e](https://pub.dev/documentation/navigation_rail_m3e/0.3.4)、[Android WideNavigationRail](https://developer.android.com/reference/kotlin/androidx/compose/material3/WideNavigationRail.composable)（二手来源，m3.material.io 页面为 JS 渲染未能直接读取，需核对）。旧版 rail 72dp（紧凑 56dp）/ 80dp — [Material Components](https://super12138.github.io/material-components-android/components/NavigationRail.html)。
- Material 3 Expressive 2025 年把 drawer 收进可展开的 rail — [9to5Google](https://9to5google.com/2025/05/14/material-3-expressive-navigation/)（标注：未打开全文核实细节）。

### Inferences
- 按比例换算：tvOS 默认 1/3 左栏；Material 展开 rail 220–360dp 在 1000+dp 宽横屏上约占 22–35%。一个"左页"如果占跨页一半（50%），比任何主流左栏都宽，必须装比导航更多的东西（活动、预告、状态），否则会显空。
- 两级层级上限意味着：左页 = 一级分区 + 每区一层子项；第三级（某个活动的具体作品）应放到右页。

### Gaps
- Apple 未公开 iPad 侧栏的点数宽度；m3.material.io 原页未能直接抓取。

---

## 问题五：拟物 / 实物隐喻导航的先例

### Takeaway
最清楚的先例是早期 iOS 的 Contacts（实体通讯录：书脊、"订书钉"、右侧字母索引）和图虫/Glass 式的竖排分类；争议点是"像书却不能翻"——隐喻带来的期待必须真的可操作。

### Cited Findings
- iOS 早期 Contacts 像实体通讯录，有假的"订书钉"和"装订" — [Scientific American](https://www.scientificamerican.com/article/apple-shouldnt-make-software-look-like-real-objects/)。
- 读者称赞右侧字母索引标签"像小时候的口袋通讯录，可以用拇指翻" — [MacDailyNews 2013](https://macdailynews.com/2013/02/13/apple-design-jony-ive-and-the-rise-of-skeuomorphobia/)（读者评论，弱证据）。
- 批评：Contacts 有 iBooks 一样的书页装饰却不能翻页 — [MacRumors 论坛](https://forums.macrumors.com/threads/who-hates-skeuomorphism-in-os-x.1576914)；"原物带来的功能限制可能严重伤害体验" — [Rada Lemeden 2011](https://redalemeden.com/blog/2011/on-skeuomorphism)。
- 支持：在 iPad 触屏上翻仿真通讯录/日历"感觉自然"，在笔记本上则多余 — [MacStories: The (Semi)Skeuomorphism](https://www.macstories.net/stories/the-semiskeuomorphism/)（搜索摘要，未逐字核实）。
- 纯装饰（Find My Friends 皮革、Game Center 绿桌）被指无功能目的 — [MacStories](https://www.macstories.net/stories/the-semiskeuomorphism/)；Apple 设计师内部对此分歧 — [AppleInsider 2012](https://appleinsider.com/articles/12/09/11/apple_designers_reportedly_divided_over_use_of_skeuomorphic_uis)。
- 竖排分类索引的现代例子：图虫圈子左侧 10 个分类 + 选中红色竖条 [截图: tuchong_ipad.jpg]；Glass 相机品牌两列字母表 [截图: glass_ipad.jpg]。
- 杂志目录式导航：Lomography Magazine 分 News / People / Gear / Tutorials / Places — [Lomography](https://www.lomography.com/competitions?page=1)。

### Inferences
- 活页夹索引标签、卡片目录抽屉、杂志目录都对应"一级分区 + 二级列表"，与 HIG 两级上限天然匹配；关键是标签真的能点/能拉，不做"不能翻的书"。

### Gaps
- 未找到 2024–2026 年仍在线、把实物索引标签作为主导航的社区/图片产品；未找到 Paper、Moleskine 等笔记本类 app 的导航设计一手资料。

---

## 结论：给"相机包左页 + 右页照片插页相册"的 3–5 个具体模式

（以下为基于上文证据的设计推论，非来源事实。）

1. **左页 = "插袋目录" 两级结构，最多两级**。上部 4–6 个固定隔层（如：大家的 / 我关注的 / 活动 / 胶卷分类 / 我的），每个隔层下最多一层子项（具体活动、具体胶卷），默认只展开当前隔层。依据：HIG"最多两级"、"用折叠控制纵向空间"；Material 3–7 项；Reddit/Slack 的可折叠分区。第三级（某张照片、某个活动的投稿）一律交给右页。
2. **左页必须带"活的"内容，而不只是目录**，因为它占跨页约一半，远宽于任何主流左栏（约 1/3）。放一块"本期活动"卡（主题 + 截止日期 + 最近几张投稿缩略图，像 Unsplash 限时 Topic、Lomography 比赛），和一条"最近动态"小纸条（谁刚上传 / 评论，像 Glass 侧边评论流、Instagram 私信行预览）。人少时优先用时间信号（截止日、本周新增）而非绝对人数。
3. **三级信号，克制使用**：小铆钉/指示灯 = 有新东西（Discord 白点）；手写数字吊牌 = 与我相关（红徽章，HIG 要求只用于关键信息）；内容预览 = 缩略图/一句话。每个隔层最多一个信号，避免满页红点。
4. **选中即标注范围，右页永远不空**：左页选中项持续高亮（如被抽出半截的索引卡、压下的按扣），右页顶部印一张标签条写明范围（"活动：雨天 · 截至 12/1"）。分区稀疏时按"本区 → 本区更早 → 同标签全站 → 编辑精选"往后补，并在相册里插一页分隔纸写"以下来自……"（Flickr 搜索的三段式）。空分区不隐藏入口，写明原因（HIG）。
5. **实物隐喻必须可操作**：索引标签能点、隔层能翻开、活动卡能抽出放大——避免"像书却不能翻"的老批评（Contacts 案例）。左页的分类可做成竖排插卡（图虫 10 类竖排 + 选中竖条的拟物版），总数控制在一屏可见 8–10 张，超过就做"更多"抽屉，而不是缩小。
