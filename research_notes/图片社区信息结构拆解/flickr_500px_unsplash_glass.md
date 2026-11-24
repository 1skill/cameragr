# Flickr / 500px / Unsplash / Glass 信息结构拆解（2026-11 调研）

说明：
- 标【已核实】的事实都附 URL。标【截图】的来自本地 App Store 官方截图（路径见文末），只记录肉眼能看清的内容。标【未核实】的来自记忆或第三方，需要复查。
- 抓取受阻：glass.photo 全站返回 403，web.archive.org 不能用，500px.com/quests 返回空页，Flickr 帮助中心返回 403。所以 Glass 的说法主要来自搜索摘要和截图，可信度低于 Flickr 和 Unsplash。
- 不编数字。没有来源的数字都列在 Gaps 里。

---

## 1) 内容清单表（模块｜内容｜每屏数量｜首页级还是二级）

### Takeaway
四家都以"一个作品池 + 几种索引"组织内容。首页放作品流（Flickr、Glass 是关注流，500px 是 For You/Following，Unsplash 是编辑精选），题目/分类/器材都放在二级。

### Cited Findings

**Flickr**
| 模块 | 内容 | 每屏数量 | 层级 |
|---|---|---|---|
| 首页流 | 关注者的照片，单列大图卡，带作者、收藏数、评论数、"Priya… +27 more" 式点赞者 | iPad 竖屏约 1.5 张大图【截图】 | 首页 |
| Explore | 每天 500 张新图，由算法选（interestingness + 活跃度），每月一次人工 Takeover | iPad 截图里是瀑布/砖墙拼图，约 8–10 张/屏【截图】 | 一级入口 |
| 搜索 | Photos / People / Groups 三个标签，结果分区："Your Photos / People you follow / Everyone on Flickr"，带标签 chips（street、night、urban…） | 每区一行 4 张【截图】 | 一级入口 |
| 群组 | 群组页：头图、名称、成员数（截图 "Epic Adventures 282 Members"），下方是照片池拼图 | 约 4 张/屏【截图】 | 二级 |
| 个人页 | 头图、头像、简介、粉丝/关注数；标签：Camera Roll / Public / Albums / Faves / Groups / Stats | 网格 4 列约 16 张/屏【截图】 | 二级 |
| Camera Finder | 热门品牌、热门机型、按类型的热门机型、对比、相关群组；品牌页显示上月上传量 | 不明 | 二级（只在网页版，App 里没有） |

- Explore 每天 500 张，算法加上每月人工 Takeover；会员在 Flickr Social 群组的月度帖里投稿，Takeover 在每月最后一个周四上线；入选者会收到 Flickr 的留言；Pro 用户没有优势（2025-09-23 博文）— [Flickr Blog: A Tour of Flickr Explore](https://blog.flickr.net/?p=91697)
- 帮助中心说法：Explore "highlights a rotating array of about 500 photos each day"，信号包括评论、收藏、浏览量、群组参与和热门标签 — [Flickr Help: Flickr Explore](https://www.flickrhelp.com/hc/en-us/articles/4404070823700-Flickr-Explore)（经搜索摘要，原页 403）
- Camera Finder 在 flickr.com/cameras，从网页 Explore 菜单进入；有热门品牌、热门机型、按类型热门、对比、相关群组；品牌页显示上月上传最多的内容和相关群组；"not available in the Flickr app" — [Flickr Help: Camera Finder](https://www.flickrhelp.com/hc/en-us/articles/7940615222420-Flickr-Camera-Finder)（经搜索摘要）；存档版 [2023 存档](https://webcf.waybackmachine.org/web/20231231095704/https://www.flickr.com/cameras)

**500px**
| 模块 | 内容 | 每屏数量 | 层级 |
|---|---|---|---|
| For You / Following 首页 | 双标签；大图卡 + 作者名；穿插 ISO 博文卡和"推荐作者"卡（头像、城市、"Licensed a Photo"徽章） | 2–3 张大图/屏【截图】 | 首页（底栏一级） |
| Explore/Discover | "Your go-to spot to explore, discover, and get inspired"；分区 "Popular Photos — New uploads with the highest Pulse rating"（View All），下面是 "Editors' Choice" | 拼图约 6–8 张/屏【截图】 | 一级 |
| Quests | 顶部大图 + "Challenges to help photographers test their skills, get recognized for their work, and win exciting prizes"；标签 Community / Licensing / Archive；卡片写主办方（"by 500px and Hasselblad"）、奖金（$50 US）、剩余天数（"25 days left"） | 2×2 卡/屏【截图】 | 一级（底栏有 Quests） |
| Galleries | 用户策展的主题图集（截图里有 "Mood Gallery Title"、"Beach Mode" 封面卡） | — | 二级 |
| Upload / Notifications | 底栏 | — | 一级 |

- 底栏一级入口：For You、Explore、Upload、Notifications、Quests【截图 500px_ipad.jpg】
- Discover 的四个流：Popular、Upcoming、Fresh、Editors' Choice — [500px Support: RSS feeds](https://support.500px.com/hc/en-us/articles/204910987-What-RSS-feeds-are-available)（经搜索摘要）
- Pulse 是 0–100 的专有分数，24 小时后和一周后会下降，照片页保留历史最高 Pulse — [500px Support: What is Pulse](https://support.500px.com/hc/en-us/articles/203999378-What-is-Pulse-and-Views)（经搜索摘要）
- Editors' Choice 由每月轮换的客座摄影师挑选并发徽章，目的是"不只是最受欢迎的" — [ISO: Guest Editors' Choice](https://iso.500px.com/guest-editors-choice-page/)（经搜索摘要，年代较早，【未核实】是否仍是每月客座）

**Unsplash**
| 模块 | 内容 | 每屏数量 | 层级 |
|---|---|---|---|
| Featured（编辑精选流） | 三列瀑布流 | iPad 横屏约 9–12 张【截图】 | 首页 |
| Topics | 左栏列出主题（Wallpapers、3D Renders、Nature、Textures & Patterns、Architecture & Interiors、Film、Street Photography、Experimental、Animals、Fashion & Beauty、Business & Work、Food & Drink、Travel…） | 左栏约 15+ 项，可滚动【截图】 | 一级（网页在顶栏，iPad 在左栏） |
| Topic 页 | 描述、"Curated by Unsplash"、"Submit to Film" 按钮、"Monthly top contributors"（截图是 4 人和各自张数）、照片网格 | 约 20 张/页 | 二级 |
| Contribute | "Contribute to Unsplash" + "Submit a photo" + "Submit to topics" 主题卡网格 | 约 9 张卡/屏【截图】 | 一级（左栏） |
| Collections | 用户自建图集，"加入图集"弹层 | — | 二级 |
| Profile | 作者大名 + Photos / Collections 标签 + 瀑布流 | — | 一级（左栏） |

- Film topic 页的实际结构（2026-11 抓取）："Curated by Unsplash"、"Submit to Film"、"Monthly top contributors" 列 4 人：Annie Spratt (52)、Keithen Schwahn (30)、Maximilian Bungart (21)、Ahmed (16)；网格约 20 张，每张有作者名、收藏、下载；部分图标 "For Unsplash+"；页面没有显示开放/关闭状态 — [unsplash.com/t/film](https://unsplash.com/t/film)

**Glass**
| 模块 | 内容 | 每屏数量 | 层级 |
|---|---|---|---|
| Feed（关注流） | 大图，按时间排序【未核实】 | 1 张/屏 或拼图【截图】 | 首页 |
| Explore | 顶部标签：Explore / Members / Highlights / Series / Categories / Cameras / Lenses | 拼图约 6–9 张/屏【截图】 | 一级 |
| Cameras / Lenses | 两列品牌字母表：Apple、Bronica、Canon、Casio、Contax、DJI、DxO、Epson、Fujifilm、GAF、Hasselblad?、KMZ、Kodak、Konica Minolta、Leica、LG、Lomography、Mamiya、MINT、Motorola、Nikon、Nokia… | 约 22 个品牌/屏【截图】 | 二级 |
| Categories | 固定的类型/题材表（Landscape、Portrait、Street、Wildlife…），每张照片最多选 3 个；当月主题标 "Monthly Category" | — | 二级 |
| Highlights | 官方编辑文章：Spotlights、Announcements、Monthly Categories、Glimpse into Glass；月底发一篇当月精选 | 3 列卡片约 6 张【截图】 | 二级 |
| Series | 多图叙事：标题、地点、长文 + 拼图 | — | 二级 |
| Profile | 黑底大头像、名字、简介；Photos / Series / Following / Followers | — | 二级 |
| 评论 | 照片右侧评论栏（iPad 截图 "Inspiring Community Members"） | 约 8 条/屏【截图】 | 照片详情 |

- 分类：固定列表，发布者最多给一张照片选 3 个分类，当月主题标 "Monthly Category" — [Glass: Introducing Categories](https://www.glass.photo/highlights/introducing-categories)；[Glass Help: Discovering photography](https://glass.photo/help/discovering-photography)（两页都 403，内容来自搜索摘要）
- 器材：在 Explore 里打开 Cameras 或 Lenses，搜索品牌/型号，浏览用该器材拍的照片；依赖上传时带的元数据；器材 feed 2022-12-08 上线 — [Glass: Camera & lens feeds (2022-12-08)](https://glass.photo/highlights/camera-lens-feeds)（经搜索摘要）
- Highlights 的类型：Spotlights、Announcements、Monthly Categories、Glimpse into Glass — [Glass Highlights: Glimpse into Glass](https://glass.photo/highlights/category/glimpse-into-glass)（经搜索摘要）
- 2025-11-14 发布 "Glass 5.0" — [Glass Announcements](https://glass.photo/highlights/category/announcements)（经搜索摘要）
- App Store 截图标题："Fall in love with photography again"、"Inspiring Community Members"、"Search, Categories, Cameras and Lenses"、"Showcase your profile in private or public"、"Tell a story using multiple photos with Series"、"Re-shared each time you upload"、"Community Highlights"、"Customizable Widgets"【截图 glass_ipad.jpg】；[App Store](https://apps.apple.com/us/app/id1528446339)

### Inferences
- "Re-shared each time you upload"（Glass）说明 Glass 会在你每次发图时把你重新推到别人面前，这是很小的社区让每个人都能被看见的做法。
- 四家首页都不放分类。分类和题目都在二级。

### Gaps
- Flickr Galleries 现在每个图集的张数上限（我记得早期是 18 张，后来提高了）【未核实】，帮助页 403。
- Glass Categories 的完整列表和数量没拿到（官网 403）。
- 500px Galleries 现在的入口位置和上限没拿到。

---

## 2) 入口层级

### Takeaway
一级入口都是 4–5 个：首页流、发现、发布、通知/我的，再加一个本平台特有的（500px 是 Quests，Unsplash 是 Topics 列表，Glass 是 Highlights/Explore 标签）。

### Cited Findings
- **Flickr iPad**：左边一条细图标栏，约 6 个图标（首页、Explore、群组/人物、通知、搜索、上传）【截图 flickr_ipad.jpg，图标含义按位置推断，【未核实】】。网页版 Explore 菜单里有 Camera Finder — [Flickr Help: Camera Finder](https://www.flickrhelp.com/hc/en-us/articles/7940615222420-Flickr-Camera-Finder)
- **Flickr 二级页**：群组页 = 头图 + 成员数 + 照片池（截图）；群组管理员可审核投稿、管理讨论、最多置顶 20 个讨论；公开群组人人可见，私密群组只能邀请 — [Flickr Help: group management](https://www.flickrhelp.com/hc/en-us/articles/4404070473364-Flickr-group-management-web-only)（经搜索摘要）。大群组页显示 "315,311 Members • 7.6M Photos • 12,929 Discussions"（FlickrCentral）— [FlickrCentral discuss](https://flickr.com/groups/central/discuss/)（经搜索摘要，数字是某一时间的快照）。某些群组规定每人每天只能往池里投 1 张；一张照片最多加入 60 个群组（Pro）或 30 个（免费）— 同上搜索摘要，来源群组页【未逐页核实】
- **500px**：底栏 For You / Explore / Upload / Notifications / Quests【截图】。
- **Unsplash iPad**：左栏顶部 Featured / Contribute / Profile，下面 "Topics" 列表【截图 unsplash_ipad.jpg】。网页版：Topics 在首页顶栏 — [Unsplash Help: Topics](https://help.unsplash.com/en/articles/3923698-topics)
- **Glass iPad**：Explore 页顶栏 7 个标签（Explore、Members、Highlights、Series、Categories、Cameras、Lenses）+ 搜索框；底部有一排小图标作为一级导航【截图】。

### Inferences
- Flickr 和 Unsplash 的 iPad 都用左栏放一级导航；Unsplash 还把主题列表也放进左栏，成了"固定索引"。
- Glass 把分类、器材、Highlights 平铺成 Explore 里的同级标签，没有再分层。

### Gaps
- Flickr App 内 Photo Walks 现状没查到（Flickr Photo Walks 我记得是网页上 Flickr 官方组织的线下拍摄活动入口，【未核实】是否仍存在）。
- Glass 底部导航的具体项目截图太小看不清。

---

## 3) 题目/活动、分类、精选的关系

### Takeaway
四家都是"同一个作品池，几种不同的索引"，没有哪家给题目单独建一个作品池。区别在于"怎么进入索引"：自动（元数据→器材）、作者自己选（分类/Topic 投稿）、编辑挑（精选）。

### Cited Findings
- **Flickr**：Explore 是从全站新图里每天选 500 张（算法）；月度 Takeover 的素材来自 Flickr Social 群组的月度讨论帖，再由员工挑进 Explore — [Flickr Blog](https://blog.flickr.net/?p=91697)。所以群组（作者投稿）→ Explore（编辑挑）是串起来的，同一张照片两边都在。Camera Finder 是按 EXIF 自动索引同一个池子 — [Flickr Help: Camera Finder](https://www.flickrhelp.com/hc/en-us/articles/7940615222420-Flickr-Camera-Finder)
- **500px**：Fresh → Upcoming → Popular 是同一张照片按 Pulse 升级（进 Fresh 要有标题、分类、至少 3 个标签；Upcoming/Popular 的 70/80 阈值只见于第三方 [Comparably](https://www.comparably.com/companies/500px/faqs)，【未核实】）。Editors' Choice 是在同一个池上的人工徽章 — [ISO: Guest Editors' Choice](https://iso.500px.com/guest-editors-choice-page/)。Quests 是投稿制：编辑写 brief，每个 Quest 选赢家；Questmas 每个 Quest 选 1 位赢家 + 10 位亚军；有的 Quest 先出 shortlist 再定前三；Questmas 2025 有两条线：特邀专家的 Judge's Pick，和在 PULSEpx 上社区投票的 People's Choice；Questmas 2024 是 12 月 1–12 日 — [ISO: Questmas 2025](https://iso.500px.com/questmas-2025-the-most-joyful-photography-event/)（原页超时，经搜索摘要）；[ISO: Photos of Photogs winners](https://iso.500px.com/check-out-the-winners-of-our-photos-of-photogs-quest/)。Quests 还分 Community / Licensing 两种（截图里 Licensing 标签），并有品牌合办（"by 500px and Hasselblad"）【截图】。
- **Unsplash**：Topics 分永久和临时两种。永久的"open for submissions indefinitely"，也用来报名年度 Unsplash Awards；临时的"might run for a month and they'll be clearly marked on the site with their end date"。由 "Editorial Team and Guest Curators" 策展；不是每张投稿都会被选上；已上传的旧图不能投进 Topic；投进 Topic 的照片也出现在个人页，并且更有机会上首页 Editorial 流 — [Unsplash Help: Topics](https://help.unsplash.com/en/articles/3923698-topics)。即：投稿 → Topic（编辑挑）→ 首页 Featured（再挑），同一张图。
- **Glass**：分类是作者在发布时自选（最多 3 个）；器材是靠元数据自动；Monthly Category 是分类表里当月被标出的那一个；Highlights 是编辑文章，月底会发当月精选 — [Glass Help: Discovering photography](https://glass.photo/help/discovering-photography)（经搜索摘要）。

### Inferences
- 对 Koco：胶卷是天然的"自动索引"（像 Flickr Camera Finder 和 Glass 的 Cameras/Lenses，不用作者手选，元数据自带）。月度题目可以学 Glass 的做法：在已有的分类轴（胶卷）上标出"本月这一卷"，不另开池子。
- 精选是一层徽章/标记，不是另一个频道。

### Gaps
- 500px 现在（2026）Editors' Choice 是否仍是每月客座编辑，没查到当前说法。
- Glass 的 Monthly Category 是否有获奖/入选机制，没查到（官网 403）。

---

## 4) "人聚在一起产出内容"的信号

### Takeaway
最强的信号是：具体的人名 + 数量（"Priya、Tomás、Maya +27 more"、"282 Members"、"Monthly top contributors 4 人 + 张数"、"25 days left"）。Glass 是反例，刻意不显示公开计数【未核实】，靠评论和 Highlights 显示人气。

### Cited Findings
- **Flickr**：首页卡片显示收藏数、评论数、点赞人名 "+27 more"；照片详情显示 "830 Faves 80 Comments 15.6K views"（截图数字是宣传图）；群组显示成员数；入选 Explore 会收到 Flickr 留言【截图】；[Flickr Blog](https://blog.flickr.net/?p=91697)
- **500px**：Pulse 分数、Editors' Choice 徽章、Quest 卡显示主办方/奖金/剩余天数、推荐作者卡显示 "Licensed a Photo" — [Pulse](https://support.500px.com/hc/en-us/articles/203999378-What-is-Pulse-and-Views)；【截图】
- **Unsplash**：Topic 页 "Monthly top contributors" 带张数；"Curated by"；照片卡上作者名 — [unsplash.com/t/film](https://unsplash.com/t/film)。新账户每 10 天最多上传 10 张 — [Unsplash Help: upload](https://help.unsplash.com/articles/2610243-upload-a-photo-to-unsplash)（经搜索摘要）
- **Glass**：评论栏（截图里约 8 条带头像的评论）、Members 标签、Highlights 里的社区专题（如 2026-01-15 "community camera selfies"）— [Glass Highlights 2026-01-15](https://glass.photo/highlights/community-camera-selfies)（经搜索摘要）；【截图】

### Inferences
- 小社区里"本月贡献者 + 张数"和"剩余天数"成本最低、最诚实，只要数字是真的，哪怕只有 3 个人也显得有人。
- 点赞人名比总数更像"人在这里"。

### Gaps
- Glass 是否隐藏点赞数（我记得 Glass 有 "appreciate" 但不公开计数）【未核实】，官网 403 没法确认。

---

## 5) iPad/网页版两栏布局

### Takeaway
只有 Unsplash（iPad）是标准两栏：左栏固定导航 + 可滚动的主题索引，右栏是作品网格。Flickr 是细图标栏 + 大内容区；Glass 是全宽 + 照片详情时右侧评论栏；500px 是单栏 + 底栏。

### Cited Findings（全部来自截图）
- **Unsplash iPad**：左栏约占 1/4 宽，上面 3 项（Featured、Contribute、Profile），下面 "Topics" 标题 + 约 15 项主题（可滚动，有小缩略图）；右栏：三列瀑布 / 照片详情 / 投稿主题卡网格 / 作者页【unsplash_ipad.jpg】
- **Flickr iPad**：左栏只是一条约 6 个图标的竖条，不放索引；右栏全是内容（流、拼图、群组、个人页）【flickr_ipad.jpg】
- **Glass iPad**：Explore 页是全宽 + 顶部 7 个标签；照片详情时左边大图、右边评论栏（约 1/3 宽）；Cameras 页是两列品牌字母表【glass_ipad.jpg】
- **500px iPad**：单栏内容 + 底部标签栏，横屏没有侧栏【500px_ipad.jpg】

### Inferences
- Koco 的"左页固定索引 + 右页相册"最接近 Unsplash iPad：左边放少量固定入口 + 可滚动的胶卷列表（16 卷 + 限定，数量接近 Unsplash 左栏的 15 项）；右边放作品。
- Glass 的"大图 + 右侧评论"适合单张详情。

### Gaps
- 网页版（桌面）布局没截图验证，以上只基于 iPad App 截图。

---

## 6) 冷启动：怎么不显得空，哪些诚实、哪些算造假

### Takeaway
诚实的做法：限量邀请（并说清原因）、编辑先写内容、官方/员工自己投稿并标明身份、把小数字原样展示、算法/编辑从已有池子里挑。造假的做法：编造用户和计数、把购买的图库伪装成用户投稿。

### Cited Findings
- **Glass**：2021 年 8 月以邀请制上线，会员拿邀请码，通过等候名单分批放人，理由是保证社区体验；2021-09-01 取消邀请，官方说邀请制是"可持续、负责任地扩张的保险" — [Glass: No invite necessary (2021-09-01)](https://glass.photo/highlights/no-invite-necessary)；[TechCrunch 2021-09-03](https://techcrunch.com/2021/09/03/instagram-may-not-be-a-photo-sharing-app-anymore-but-glass-is)；[PetaPixel 2021-08-12](https://petapixel.com/2021/08/12/glass-is-a-subscription-based-photo-sharing-app-for-photographers)。邀请期大约只有 3 周。
- **Glass**：编辑写的 Highlights（Spotlights、月度分类回顾）是持续不断的"官方填充"，内容来自真实会员 — [Glass Highlights](https://glass.photo/highlights/category/glimpse-into-glass)（经搜索摘要）
- **Unsplash**：Topics 由编辑团队和客座策展人维护，并"与外部创作者和社区合作"带来新视角 — [Unsplash Help: Topics](https://help.unsplash.com/en/articles/3923698-topics)。Film topic 的头号月度贡献者是 Annie Spratt（52 张），她长期是 Unsplash 最多产的作者之一 — [unsplash.com/t/film](https://unsplash.com/t/film)。Topics 2.0 的历史说明见 [Medium: Topics 2.0](https://medium.com/unsplash/topics-2-0-92990142d4cc)（没有打开全文）。
- **Flickr**：员工每月从群组帖里挑图做 Takeover，并在入选照片下留言，透明可见 — [Flickr Blog](https://blog.flickr.net/?p=91697)
- **500px**：品牌合办 Quest（Hasselblad）带来奖金和外部流量【截图】；Questmas 2025 请外部专家当评委 — [ISO: Questmas 2025](https://iso.500px.com/questmas-2025-the-most-joyful-photography-event/)

### Inferences
- 诚实：邀请制/限量（Glass）；"Curated by Unsplash"那样标明谁挑的；官方账号投稿并明示是官方；显示真实的小数字；题目有明确截止日（Unsplash 临时 Topic "clearly marked … with their end date"）。
- 造假的边界：编造账号和评论、虚报成员数/张数、把自己拍的图挂在假名下。Unsplash 种子用的是真实、具名的作者和官方策展，所以不算造假。
- 对 Koco：一开始让官方账号（明确标为 Koco）在每卷胶卷下先放几张样片，标"官方样片"；月度题目显示真实参与人数，哪怕是 3。

### Gaps
- 没找到 Unsplash Topics 上线时（2020）种子投稿的具体做法和数量；"Topics 的种子投稿"只能确认由编辑团队和客座策展人维护，具体是否请作者提前投稿【未核实】。
- 没找到 500px 早期冷启动的资料。

---

## 截图文件（本地，App Store 官方宣传图）
- /private/tmp/claude-501/-Users-shuiying-cameragr/0ba8fed5-d9eb-51f8-bbdc-5f5771c7495b/scratchpad/shots/flickr_ipad.jpg
- /private/tmp/claude-501/-Users-shuiying-cameragr/0ba8fed5-d9eb-51f8-bbdc-5f5771c7495b/scratchpad/shots/500px_ipad.jpg
- /private/tmp/claude-501/-Users-shuiying-cameragr/0ba8fed5-d9eb-51f8-bbdc-5f5771c7495b/scratchpad/shots/unsplash_ipad.jpg
- /private/tmp/claude-501/-Users-shuiying-cameragr/0ba8fed5-d9eb-51f8-bbdc-5f5771c7495b/scratchpad/shots/glass_ipad.jpg
- （iPhone 版截图没看，时间有限）
