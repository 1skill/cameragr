# 进度日志（最新在上）

## 2026-11-22 看 VNTG 设计 + 胶卷改成凹槽（dev ddee6ea，已装机）
- VNTG：装片页左边一个可滑的大胶片盒、右边是相机打开的片仓，底部一句“Swipe to choose · close to load”；相册是一本打开的书；画廊左大图右网格；外屏合着时可以是相册封面；拍照有相片吐出的动画。拟物和干净界面混用。可借鉴点写进 QUEUE B17。
- 胶卷改成躺在凹槽里：GPT 按新模板出了带手指缺口的凹槽图；胶卷名字完整可见，槽沿阴影落在罐子上沿；正在看/选中的卷会抬起。58 个测试全过。

## 2026-11-22 你选了相机包 B + 左右结构 → 已做出来（dev 5eae245，已装机）；竞品分析
- INFO 挪到液晶屏左边（GPT 改机身图，1eb399e）。
- 内屏：先做了上下版，你说改左右（左胶卷右详情）。重画模板让 GPT 出了两版图：第一版弹力带压在罐身中间、名字被挡，改成短带子只压金属端头（第二版）。左边 9 卷横躺+价签（短名+状态）+“全部胶卷”位；右边说明卡（名字、ISO、介绍、试拍/购买/装上这卷）+ 6 格插袋（你的照片，没拍过显示样张）；点照片铺满看大图。商店合一。跟随系统方向，竖屏锁定时转 90°。
- GPT 审了一轮，改了：底部说明会被裁→挪到卡片和插袋之间；点缩略图可能开错照片→同一份列表；全部胶卷没价格时可重试；英文价签用 Loaded；大图加关闭按钮。58 个测试全过。
- 竞品分析（VNTG、Duorama、FocalWell 66、CR Film、Halide、Film Camera）：合盖换卷 VNTG 已先做；左胶卷右印样 Film Camera 在宣传；半折腰平 4 家都有。建议见 QUEUE B16。

## 2026-11-22 你回来了：INFO 挪位 + 内屏第三轮（dev 1eb399e，已装机）
- **INFO 挪到液晶屏左边**：相机控制按钮的系统菜单从顶边下来正好压住 INFO。INFO 是画在机身图里的，按规矩让 GPT 改图；第一次 GPT 把字塞进了液晶框、还把绿玻璃缩了 15 像素（读数会出框），重来一次放在框外，玻璃位置误差 2 像素以内。
- **内屏第三轮**：你说之前浪费空间、没连商店。这次实物铺满上下两半、不画包外框桌面；展开页 = 胶卷库 + 商店：每卷挂价签写状态（相机里/已拥有/试拍 3/¥12），点价签买或装；没拍过的卷下半屏显示样张对比；点照片铺满整个内屏看大图。三个方向：A 货架+灯箱（推荐）、B 相机包铺满版、C 一卷一张大签。https://claude.ai/artifact/LLoTQvHB2ZPNTG3b93AJJZ

## 2026-11-22 空闲时做的增长准备：3.4 新胶卷候选（不急，等你挑）
- v1 的事都在等你，所以用空闲做了不需要你定的 3.4 准备：从开源胶片库挑 11 种和现有九卷不同的胶卷，在同 4 张样张上渲染，算和现有最接近那卷的色差。
- 结论：推荐 Velvia 50（浓烈反转片）、FP-100C（通透撕拉片）、Double-X（柔和电影黑白）、Agfa Vista 100（暖色超市卷）；Ektar、Ultramax 和 Portra 几乎一样不值得加；红外 Aerochrome 普通照片做不出来（没有红外信息）。
- 对比页：https://claude.ai/artifact/U9SHaP6hqGhzNorrg98iVA （QUEUE B15），页尾附节日限定的想法。工具 tools/film_candidates.py。

## 2026-11-21 接力暂停：v1 剩下的事基本都在等你定
- 额度没问题（Claude +4、Codex +2 / 各 10）。暂停原因：v1 里不用等你的任务都做完了，剩下的都卡在你的决定上；增长类（M3）按回顾约定放在 v1 核心之后，所以没有接着开。
- 最影响进度的几件（按顺序）：①B10 相机包选哪个变体 → 我就能出定稿图接线 ②B12 半折取景选哪个 ③B6 App Store Connect（真实商品/沙盒/TestFlight 都卡在这）④B11 截图风格 ⑤B13 原图开关 ⑥B3 品牌名 ⑦B14 找母语朋友校对。
- 你回复任何一项，每 3 小时一次的定时任务或你的消息会让我接着做。

## 2026-11-21 任务 4.1 繁中/日语/韩语 ✔（dev 见 git log，**待母语校对**）
- 139 条界面文字、权限说明、9 卷胶卷的介绍，都加了繁体中文（台湾用语：相機、底片、相簿、設定）、日语、韩语。我翻的，全部标“needs_review”。
- 修了：胶卷介绍原来把所有中文都当简体，繁体用户会看到简体 → 台湾、香港用繁体。
- 测试：每条文字五种语言都齐、占位符一致；日韩“6 卷中 1 卷”语序对；每卷都有五种语言的介绍。58 个全过。商店、胶卷页、设置、使用技巧三种语言都截图看过，没有截断。
- 合并脚本 tools/i18n/merge.py：缺翻译或占位符不对就拒绝写入。
- 请你找母语朋友看（QUEUE B14）；商店文案还没出这三种语言。

## 2026-11-21 任务 1.4 购买边界：本地部分 ✔（dev 见 git log）
- 发现：正式版里如果商品加载失败（启动时没网、App Store 连不上），所有“购买”按钮会悄悄消失，没有任何说明，也没法重试。
- 修了：买过的卷照样能用（系统自己存着购买记录）；缺价格的地方显示“价格没能加载，请检查网络后点这里重试”；打开商店/胶卷页、App 回到前台时自动再试。只补缺的商品、已加载的保留、同时只加载一次（GPT 必须改+建议，已改）。
- 新测试：模拟商品加载失败 → 购买仍有效 → 恢复后价格回来。55 个全过。
- 家人共享撤销：和退款走同一条路（交易带撤销时间，胶卷重新上锁），退款测试已覆盖；真正的家人共享和冷启动离线要在真机/沙盒上验（等 2.1）。

## 2026-11-21 任务 2.9 发布资料一致性核对 ✔（dev 见 git log）
- 报告：design/appstore/consistency.md。对得上的：7 个商品、价格、家人共享、3 卷免费、每卷试拍 3 张、隐私说法。
- 当场改了：①样张对比把 AI 原图标成“iPhone”——App 里（含读屏）改成“原图”，自己的照片才叫 iPhone；商店描述同步。②描述说“每卷都按胶卷光谱数据计算”——GR 负片和 CCD 其实是按实拍照片拟合，已如实写。③内购审核截图还是旧罐子，重拍了 7 张。
- 还开着的（大多等你）：品牌名能用到什么程度（B3）、半折取景那句要等 F2、版权署名、支持网址和邮箱、App 名可用性、版本号到时改 1.0、商店截图、**新问题 B13：设置里“同时保存 iPhone 原图”和早先“不保留原图”的决定矛盾**。
- 顺手修了一个偶发失败的退款测试（等退款生效再判断），连跑两次 54 个全过。

## 2026-11-21 任务 1.13 照片库生命周期 ✔（dev 见 git log）
- 修了：记录文件损坏或读不懂时，原来下一张照片会把旧记录覆盖掉 → 现在先挪到一边保存；挪不动就暂停写入。
- 原打算“相册里删掉的照片就从记录里删”，GPT 指出隐藏的照片在 App 看来也像被删了，取消隐藏后就再也归不回卷 → 改成永远不删，只是灯箱上不显示；记录很小（每张约 120 字节，2000 张测过每张约 2 毫秒）。
- 已有的：锁屏照片导入一次且记好才清理会话（有测试）；记录放在 Application Support，App 更新不丢；权限撤回只是看不到，记录还在。测试 54 个全过。

## 2026-11-21 展开页：相机包方向的四个变体
- 你定了相机包方向，要求：两屏是一个整体、能看已拍照片、能放大。做法：手机折痕 = 包盖折线，展开 = 掀开包盖，上下是同一张俯拍照片。上半包盖内侧插照片（点一张抽出放大，左右滑看前后，插袋翻页），下半包里插卷、前口袋放“下一卷”。
- GPT 出了 4 个变体：帆布邮差包（推荐）、复古皮包、黑色内胆包、卷口背包；我合成了一张“抽出照片放大”的示意。比较页：https://claude.ai/artifact/UBRzUypgAzfxWmnTBiHj8W ，等你选（B10）。选定后画版式模板、GPT 出定稿图、换上我们的罐子，接到现有逻辑。

## 2026-11-21 第 2 次蓝图回顾 + 半折腰平取景 3 个方案
- **回顾**（GPT，reviews/blueprint-2.md）：几个 ✔ 说多了——1.2（没测存相册和发热）、1.5（真机双半屏没验）、1.9（“存下来”没做）、F1b（你还没选定外观）改回“进行中”；1.4 其实做了一大半，改成“进行中”。新增 1.13 照片库生命周期、1.14 定稿后中英文走查、2.9 发布资料一致性核对、2.10 候选版统一验收。GPT 排的等你定的紧迫度写在 QUEUE B 顶部（App Store Connect 最急）。
- **半折腰平取景**：半折时下半屏平放在手里低头看、上半屏立着朝你。3 个方向（GPT 出图）：大号反光取景窗（我首选，3:2 画幅、指针测光表、水平气泡、拇指拨杆快门）、中画幅镀铬遮光罩（取景最大、放大镜对焦）、双反（经典，但上半屏画了镜头朝你，逻辑不通）。比较页：https://claude.ai/artifact/VAPqgdekj4cLqdkcV3QLcH ，等你选（B12）。

## 2026-11-21 展开页第二轮创意（和 GPT 一起）
- 你说第一轮都不特别中意，问我最喜欢哪个、让 GPT 也想。我上一轮最喜欢相机包（选卷进前口袋最直观），但都没让“展开”这个动作本身有意义。
- GPT 独立想了 6 个（reviews/inner-ideas.md），推荐“胶卷纸盒摊开”和“摄影师工作箱”。我想的是“打开相机后盖”：展开=开后盖，上半片仓+片门上的照片（滑动=过片），下半后盖内侧的备忘插槽，把盒盖推进插槽=选卷。
- 出了 4 张图：相机后盖、胶卷纸盒、工作箱、皮腔相机：https://claude.ai/artifact/WjnWNZPALkDjs8kkkAw1hP ，等你选（QUEUE B10）。

## 2026-11-21 任务 1.2 性能 ✔（dev d33af89，已装机）
- 调试版加了计时：取景器每 2 秒记一次新帧率、重复帧、最长间隔、GPU 每帧耗时；每张照片记“按快门→到手→冲印→存好”。-perfRun 自动逐卷取景、拍照（只计时不存相册、试拍会退还）。
- 在你手机上跑的结果：取景每卷都是 30 fps（相机本身的帧率），GPU 每帧 1–3 毫秒、最慢 5% 也不到 7 毫秒；照片到手 0.25 秒、冲印 0.18–0.35 秒（CCD 最慢）。**远低于目标，不需要优化。**
- **抱歉**：跑测时你应该正在用手机（中途 App 被切到后台两次、胶卷被换过）。以后不在手机上自动启动测试，除非先跟你说好。
- GPT 审查：改了帧率统计（只算新帧）；“真的存进相册的连拍测试”没做，理由见 QUEUE D4。

## 2026-11-21 任务 2.5 App Store 截图：样稿 ▶（dev c9c3a70）
- 横版 2868×1320（6.9 英寸）。桌面场景 GPT 出图（手机屏幕先画成纯绿，方便准确放入）；手机里是 App 真实截图（模拟器，取景器里放样张，加了调试参数 -feed）；标题放在桌面空白处。中英文各一张，绿边已处理干净。合成工具 tools/appstore_compose.swift，6 张规划在 design/appstore/shots/plan.md。
- GPT 审查：改了两处文案（样张是 AI 生成，不能说“iPhone 原图”；锁屏那张注明用相机控制按钮或锁屏控件），合成工具加了输入检查。
- **等你定风格**（QUEUE B11）：https://claude.ai/artifact/Exs3yMoFt513ZrWoKmZD4K

## 2026-11-21 真机开合数据（第二段）→ 合上流程定稿（dev b7368bf，已装机）
- 你用手机开合了几次，日志读到：合上时系统在约 83° 就报“合上”并切到外屏，之后角度在外屏继续一路报到 0°（约 2 秒）。所以“角度 < 8° 且在外屏才算完全合上”正好卡在真正合上那一刻，**不需要兜底**。
- 发现一个闪动：从全开合上时，“合上”比切外屏早 70 毫秒，内屏会从胶卷库闪成腰平画面并启动相机。已修：合的过程中胶卷库保持到外屏接管。测试 50 个全过。
- 相机从胶卷库回来约 0.3 秒，够快。

## 2026-11-21 合上换卷改时机 + 展开页 4 个新方案（dev 9fb8f7a，已装机）
- 你说“应该完全合上才开始动画”。原因有两个：①我之前让半开就直接装卷，合手机路过半开就悄悄换了；②系统铰链状态不可靠。现在要同时满足铰链报合上、角度 < 8°、界面在外屏，再等 0.4 秒让你翻过来看，才开门换卷。半折取景时取景器先显示选好的卷，按第一下快门才装上。GPT 审了一轮，2 条必须改都改了（其中一个“静止 1 秒也算合上”的兜底会误判，删了，等真机数据再定）。测试 49 个全过。
- 展开页按你的要求又想了 4 个方向，都考虑了“看卷不换卷 → 选定看得出 → 购买/试拍 → 合上看到换卷 → 看单张、翻页”的流程，GPT 出了风格图：B 相机包+接触印样（推荐）、D 胶片店柜台+相册、E 转盘+投影、C 冰箱+晾片（不推荐：暗房灯会让照片偏色）。比较页：https://claude.ai/artifact/EzuLmcVqh1YTX1VTnwcp3k ，等你选（QUEUE B10）。

## 2026-11-21 任务 2.7 审核备注 ✔（dev 见 git log）
- design/appstore/review-notes.md：英文（贴进 App Store Connect 的审核备注）+ 中文对照。写了怎么试、免费卷、单卷内购+全部胶卷、每卷试拍 3 张、锁屏相机和相机控制按钮、折叠 iPhone 的三种状态、AI 样张说明、隐私（不收集数据）、模拟购买只在调试版。
- 自己核对代码改了 2 处说法（片仓是点机身上的胶卷小窗打开；兑换码只在设置里）；GPT 指出锁屏失败的试拍仍会扣（D3），已照实写。
- 联系方式留占位；文末有提交前核对清单（半折取景是否完成、家人共享、联系方式、胶卷品牌名）。

## 2026-11-21 任务 1.6 胶卷罐美术 ✔（dev 18590a9，已装机）
- 7 卷换成 GPT 出的实物罐（以 Gold 200 为参照，同角度同光）：C200、Cine 500T、Chrome 64、Tri-X 400、Instant 800、GR Neg 200、CCD 100。抽屉、商店、片仓、详情、小组件全部生效。
- 自检发现我提示词写错：GR Neg 侧条写成了 “Positive film”，让 GPT 重出成 “Negative 200”。
- GPT 审查：无必须改。建议罐身写 “Kodachrome 64”——品牌名还在等你定（B3），先保持 “CHROME 64”。
- 效果图同一页：https://claude.ai/artifact/FfQxii8Z7SbTg5hjZoumxe

## 2026-11-21 展开界面重做 + 合上换卷动画 ✔（dev 0b71058，已装机）
- 你要求重新设计展开界面、合上要有放入动画。按新规则（我出创意、GPT 出拟物图）：
  - **上半：胶卷柜抽屉**（胡桃木+黑色泡棉格子，前沿红黄条纹+黄铜卡片框）。每卷立在格子里；相机里那卷的格子空着写“在相机里”；黄铜卡片写当前看的卷和操作（再点一下选它/试拍/购买、合上即装入·再点撤回）。点一卷=看（抬起），再点=选。
  - **下半：看片灯箱**，照片像幻灯片插在 12 个片框里，左右滑翻页；纸胶带上手写卷名和张数，没权限时点胶带去授权。
  - 先给 GPT 画了带准确格子位置的版式模板（design/library/），所以罐子和照片能准确放进去。
- **合上换卷动画**：选了卷合上 → 片仓门自己打开 → 旧卷倒片取出 → 新卷放入拉片 → 关门，LCD 变新卷。复用片仓原有素材和动作。动画中按快门也是新卷；动画中又打开就直接装好；不会被旧计时器装回之前的卷（GPT 必须改，已修+测试）。
- 测试 48 个全过。图给你看：https://claude.ai/artifact/FfQxii8Z7SbTg5hjZoumxe
- 发现：抽屉里 9 卷有 7 卷是程序画的占位罐子，很显眼——1.6 胶卷盒美术提前做。

## 2026-11-21 任务 1.9 导入照片与所见即所得 ✔（dev f5a9bc5）
- **所见即所得**：写了自动测试，同一帧画面分别走取景器和存图两条路，9 卷逐格比对颜色、亮度、裁切、暗角，**全部差在 3% 以内**（取景窗 707×472 正好 3:2，和成片裁切一致）。模拟器测不了的：真机上取景用视频流、成片用拍照流，系统处理不同，需你拍一张对比看（取景器和相册里那张颜色是否一样）。
- **用我的照片试试**：现在会读照片的方向和拍摄 ISO（颗粒/噪点跟着走）；打不开会提示“这张照片打不开，换一张试试”；同一张可以再选；处理中不能再选（避免旧的盖掉新的）。测试：竖图保持竖、2700 万像素降到 2048、HEIC 能开、非图片不崩。共 47 个全过。
- GPT 审查（reviews/1.9.md）：唯一必须改是“处理后没法存下来”——这是产品要不要的问题，按规则记 QUEUE B9 问你，没自己加。

## 2026-11-21 1.12 第一批真机数据 → 改规则（dev b3d9542，已装机）
- 手机上已有一段开合记录（不是完整 7 步，没走胶卷库选卷）。读到的事实：
  - 系统的铰链“状态”不稳：一次打开到 18° 还是“合上”、22° 变“半开”；另一次到 **84°** 还是“合上”。
  - 界面先换到内屏，状态后变：内屏上会先画半秒多外屏机身。
  - 进后台前有一次 68° 时报“合上”。
  - 全开读数直接是 180°；半开→全开按设计 1 秒后进胶卷库。相机没停时恢复只要 0.01–0.11 秒。
- 改法：**用“在哪块屏幕”判断开/合**（内屏只在打开时用，这个不会错），铰链只判断半开还是全平。加 3 个测试，共 42 个全过。
- 仍需要你按 7 步脚本完整做一遍（重点是 ③④：胶卷库选卷→合上→LCD 换卷→拍一张），我再读日志。

## 2026-11-21 1.12 折叠即操作：F0 采样 + F1 全开选卷/合上装卷 ✔（dev 9d6e52a，已装机）
- 你说“做吧”，我按方案开干；两个待定点按建议默认（见 QUEUE A6）。
- **三态**：合上=外屏相机；全开=胶卷库；半开=现在的两半布局（腰平取景是 F2）。合上立刻生效；其它变化要稳住一会儿才切（从合上直接打开到平，中途经过“半开”不会停下）；腰平状态要连续全开 1 秒才去胶卷库；拍照过程中只有合上能改模式。规则写成纯逻辑，测试里模拟了一分钟反复轻晃——不误切。
- **胶卷库**（全开）：上半是胶卷卡片，点卡片只是看，不换卷；“装上这卷”=待装入，再点或点“不换了”就撤回；下半是这卷拍过的照片网格。付费卷试拍用完显示购买；待批准、买不了都有提示。照片权限：没问过给“允许访问”，拒绝了给“打开设置”，回到前台自动刷新。
- **合上**：有待装入就装上，没有就保持原卷。全开时相机暂停（不亮相机指示），音量键/相机控制按钮不拍照。
- **照片属于哪卷**：每张存好后记下它在相册里的编号和胶卷；锁屏拍的也记在会话文件里，App 打开后导入，记好了才清理会话。
- 测试 39 个全过（新增：折叠规则 7、胶卷库规则 5、照片记录 2）。GPT 两轮（reviews/fold-1*.md）共 5 条必须改，都已改。
- **需要你做（约 2 分钟，F0 采样）**：打开 Koco，按这个顺序慢慢做，每步停 3 秒：①合上拍一张 ②完全打开平放 ③在胶卷库点几卷看看，再选一卷“装上这卷” ④合上，看外屏 LCD 是不是新卷，拍一张 ⑤打开到一半（像笔记本电脑）手持 30 秒，轻轻晃铰链 ⑥再完全打开 ⑦合上。做完说一声，我从手机里读日志调参数，并检查第 ④ 步是否真用了新卷。

## 2026-11-21 任务 1.11 其它 iPhone 尺寸 ✔（dev 见 git log）
- 在 iPhone SE（最小）、16e、17 Pro、16 Pro Max 上，中英文各截了相机、开仓、商店、详情、设置（project/shots/1.11/）。机身在非 Duo 手机上居中显示、两边留黑，各页没有截断。
- 修了：**非 Duo 屏幕上详情页底部“样张原图由 AI 生成”的说明被挤出屏幕**（1.10 时 GPT 提的必须改）——对比图下方预留的空间从 50 改到 130，Duo 上布局不变。
- 补了 1.1 欠的两份许可全文页截图；顺手把许可正文缩小一号，原来 80 列的行在 Duo 上会在行尾多折一次，现在整齐。
- GPT 审查（reviews/1.11.md）：**通过**，无必须改。

## 2026-11-21 任务 1.10 发布构建检查 ✔（dev 见 git log）
- Release 编译（真机架构、未签名）：通过，无警告。
- 调试入口：在 Release 二进制里搜了 snap、resetStore、settingsPage、widgets、模拟价格 ¥68、调试打印等，**全都不在**；模拟购买只在 DEBUG 里，Release 没商品时不会白给解锁。
- **补上了隐私清单**（之前三个包都没有，上架会被拒）：App、锁屏相机声明 UserDefaults（理由 CA92.1，只存自己的设置、购买和试拍次数）；小组件不用这类接口；都声明不追踪、不收集数据。
- 权限文案：主 App 和锁屏相机的中英文都在包里；两份第三方许可（DSEG 字体、Spectral Film LUT）在包里。
- iOS 18：建了 iOS 18.3 模拟器，App 正常启动，相机、商店、详情都能显示（project/shots/1.10/）。
- GPT 审查（reviews/1.10.md）：修改后通过。它的必须改是 iPhone 16 Pro 尺寸下详情页底部的“样张由 AI 生成”说明被裁掉——属于 1.11 其它尺寸，下一个就做。
- 待做（等 2.4）：签名 Archive 检查、iOS 18 真机跑锁屏相机和小组件。

## 2026-11-21 第 1 次蓝图回顾 + 任务 2.2a 本地内购测试 ✔（dev 579eb50）
- **蓝图回顾**（GPT 建议 reviews/blueprint-1.md，已整合进 BLUEPRINT）：1.3/1.5/1.8 标成“代码完成、真机待验”；新增 1.9 导入照片与所见即所得、1.10 发布构建检查（Release 关调试、隐私清单、iOS 18）、1.11 其它 iPhone 尺寸（原 4.4 提前）；2.2 拆成本地(a)与沙盒(b)；M3 增长后移到 v1 核心验收之后。没有改方向的事，所以没进 QUEUE B。
- **2.2a**：加了本地商品配置 Config/Koco.storekit（6 卷 + 全部胶卷，$1.99/$14.99，中英文名，家人共享）。现在不用等 App Store Connect 就能测真实购买流程。
  - 修了：“问家长”/待确认的购买原来被当成失败，现在详情页显示“购买正等待批准”，批准后自动解锁。
  - 修了：给锁屏相机的更新原来同时开多个、可能乱序覆盖，现在一次一个、总是最新、失败重试。
  - 新增 8 个测试：购买、取消、退款（自动收到）、等待批准、恢复购买、锁屏同步失败后仍拿到最新。共 25 个全过（两次）。
- GPT 审查（reviews/2.2a.md）：修改后通过，2 条必须改（恢复要真走 restore、补取消与锁屏同步测试）都已补上。

## 2026-11-21 任务 1.8 小组件/控制/锁屏回归：我能做的部分 ✔（dev 见 git log）
- 静态检查：小组件、控制中心按钮、锁屏相机、相机控制按钮里的所有文字都有中文（胶卷架、一卷胶卷、选择胶卷、Koco 相机、闪光灯 关/自动/开 等）；两个扩展都打包了中英文和 App Intents 元数据。
- 发现并修了：**大号“胶卷架”小组件只显示前 6 卷**，新加的 Instax、GR Neg、CCD 没位置 → 改成 3 层 × 3 卷，9 卷全有。中号仍是 6 卷一排。
- App 内小组件预览（-widgets 1）改成竖排，中英文截图在 project/shots/1.8/。
- GPT 审查（reviews/1.8.md）：修改后通过，没有代码缺陷；它要求的真机回归需要你的手。
- **待真机手动验（需要你）**：①桌面加小/中/大三种小组件，中英文下看名字和说明 ②点大号上 9 卷各进对应胶卷 ③控制中心的 Koco 相机、锁屏相机、相机控制按钮各拍一张 ④锁屏用付费卷试拍到用完，确认会被拦。

## 2026-11-21 任务 1.5 折叠屏展开时的面板 ✔（dev 919e5d2）
- 内屏一半约 669×475 点（按以前真机日志 951×669 推算），和外屏 678×466 很接近。加了调试参数 `-half 669x475` 在模拟器上按这个尺寸画机身，加了 `tools/snap.sh` 一条命令截任何页面。
- 截了相机、开仓、商店、详情（4 卷）、设置，中英文（project/shots/1.5/）。
- 发现并修了：**详情页标签在放置时比测量时多换一行**（浮点误差），最后一个标签压在下面说明文字上（英文 Instax 明显）。外屏同样受影响，一起修好。
- GPT 审查（reviews/1.5.md）：修改后通过。它指出的重叠正是我第一次没修对的地方，第二次改了换行判断后已截图确认。调试参数加了正数检查。
- 还没覆盖：真机展开后双半屏的整体摆放和触摸（以前你说内屏布局还不对，需要你描述现象）。

## 2026-11-21 任务 1.3 稳定性：代码部分 ✔（dev 632a283，已装机）
- 找到并修了：
  - 照片还在处理时换胶卷/画幅，会用新胶卷冲印上一张 → 每张照片记住按快门时的胶卷、画幅、方向。
  - 试拍在拍照、冲印、保存任一步失败时白白扣掉 → 失败就退还（只限主 App；锁屏那边已写进记录，暂不退，见 D3）。
  - 相机权限被拒时还能按快门、照样扣试拍 → 改为提示去设置，不扣任何东西。
  - 连拍时冲印/保存积压不计数，内存可能一直涨 → 从快门到存进相册全程最多 4 张。
  - 拍完马上切走 App 可能丢照片 → 从按快门起向系统申请后台时间直到存好。
  - 相机会话出错（媒体服务重启）后不会自己恢复 → 自动重启。
  - 内存警告时清掉样张缩略图缓存。
- 测试 17 个全过（新增“失败试拍退还”）。GPT 审查两轮（reviews/1.3.md、1.3-r2.md），都是“修改后通过”，第一轮 3 条必须改都改了；第二轮那条见 D3。
- **待真机手动验（需要你的手）**：①设置里关掉相机权限再开 App 按快门 ②关掉相册权限拍一张 ③相册设为“受限”拍一张 ④连按快门十几下 ⑤拍完立刻上滑回桌面，再看相册里有没有 ⑥拍照时来电话/用别的相机 App 后回来。有问题告诉我现象即可。

## 2026-11-21 任务 1.7 单元测试 ✔（dev 171754e）
- 新增测试目标 cameragrTests，一条命令跑：`tools/test.sh`。16 个测试全过：免费/付费解锁、试拍 3 张用完、单卷与全部购买、锁屏试拍按会话只计一次（重复读入不多扣）、每卷文件与中英文说明齐全、每卷 LUT 在灰/肤色/天空/红 4 个点的数值（变了就报警）、黑白保持中性、中文已打包。
- GPT 审查（project/reviews/1.7.md）：修改后通过。已改：测试前的重置改为等待权益刷新完；test.sh 先建目录、xcodegen 失败就停、日志重定向顺序；补了锁屏同步测试和 LUT 数值测试。
- 另：审查脚本加了 15 分钟超时并关掉输入（之前一次审查卡住半小时）。单独提交 326787a。

## 2026-11-21 任务 1.1 全页面走查 ✔（dev bfee091，已装机）
- 截了 9 个页面 × 中英文（project/shots/1.1/）：相机、开仓、换卷架子、商店、详情、设置、使用技巧、隐私、开源许可。
- 修了：架子胶卷名截断（缩小罐子、名字可换行、只显示 ISO、没买的加锁）；英文详情左栏太挤（标签挪到对比图下面）；会员卡那句话截断；设置左栏版本号溢出（挪进“关于”）；商店和设置里胶卷盒挤在一起。
- GPT 审查（project/reviews/1.1.md）：修改后通过。必须改 1 条已修（架子上的锁要随购买状态刷新）；改动很小，没再审第二轮。
- GPT 提到“GR 负片、CCD 与 v1 只做胶卷的决定冲突”：那是过时的记忆，11/20 你已同意加入；已更新记忆。
- 留到后续：详情正文滚到底时取消渐隐（D2）；两份许可全文页还没截图核对。

## 2026-11-21 流程建立后的第一次提交（dev efd57c9）
- 内容：锁屏相机同步购买和试拍、详情页英文排版、C200 样张重做、分享视频引擎（未接入）、App Store 文案与内购审核截图、GPT 审查脚本 tools/codex_review.sh。
- 自检：编译通过；英文详情页 6 卷截图无截断（design/appstore/iap/）。
- GPT 审查两轮（project/reviews/pending-0*.md），结论“修改后通过”：
  - 已改：退款后锁屏仍解锁（改为整份替换）；锁屏试拍不回传（改为写入会话文件、主 App 每会话计一次）；锁屏记录写不进就不给试拍；详情页显示滚动条；视频写入失败时报错、清理、可取消。
  - 不改（理由）：主 App 尚未读到锁屏记录的短暂窗口里可能多出几张试拍——堵住它要在启动时禁止试拍，影响正常使用；最坏只多不到 3 张免费试拍。
  - 留到后续：滚到底后取消渐隐（1.1 走查时做）；锁屏同步改成串行发送并重试（1.4 购买边界时做）。
- 经验：一批改动混了多个任务，审查不好对照完成标准。以后一个任务一审。

## 2026-11-21 建立流程
- 定下自动推进流程（见记忆 cameragr-autonomous-workflow）；起草蓝图 v1、待你过目清单。
- 之前已完成（截至提交 2e61483）：九卷胶卷与颗粒/暗角/CCD 质感、胶卷商店与购买（开发版模拟）、详情页拖动对比、设置页、胶卷仓控制栏、36 张 AI 样张、中英文、隐私与支持页（GitHub Pages 已上线）。
- 未提交的改动：C200 新样张、锁屏购买状态同步、详情页英文排版修复、App Store 文案与内购审核截图、分享视频引擎（半成品）。将作为第一次 dev 提交。

## 2026-11-22 · Velvet cradles (8c2dbca)
- Rolls lie snug in black velvet cradles (GPT art), the velvet rim drawn over each roll's edges; rolls stretch end to end (≤3%).
- Tenth cradle: GPT "ALL FILMS" collector roll + tag replaces the old purchase card; tap roll or tag to buy.
- Codex review passed; accessibility label added. 58 tests pass. Installed on the Duo (not launched).

## 2026-11-22 · Bag fitted to the Duo inner screen (b14f946)
- User: corners cut on the Duo. Real inner screen 951×669 pt, 55 pt corners (simulator only shows the outer screen). New `-inner 1` debug renders the library at the real size + corner mask.
- Discussed with GPT first (project/discuss/bag-velvet.md, bag-corners.md). Agreed: leather edge follows screen corners, hinge margin, rows moved up for a hint line, note into card, page tab. Disagreed: separate foreground velvet layer (GPT art can't give clean layers) — kept rim cut from the same art, mask now = measured opening.
- New GPT art from template bag_fit_template.png; art fits whole (min scale). Hint line (B17① done as part of this). Codex review: 修改后通过 — zh hint was a stale screenshot (re-checked), hint brightened.
- Next (agreed with GPT): next-roll red cloth tab, in-camera tag across empty cradle, all-films tap = look + certificate card.

## 2026-11-22 · Next-roll tab + all-films certificate (B17 ②③, allfilms=cert)
- Red cloth tab (GPT, next_ribbon.png) on the next roll's cradle; only the looked-at roll lifts. All-films roll: tap = look; card = certificate, sleeve = one sample per film (tap → that film), page tab 1/2; tag/buy line buys.
- Codex review 修改后通过: added AI-sample note on the certificate, useTag leaves all-films view, pending-approval text, VoiceOver "Next roll". Tests pass. Installed on Duo.
- Next: item 2 — half-fold reflex finder (B12).

## 2026-11-22 · Half-fold reflex finder deck (B12, 594c0ff)
- Discussed with GPT (discuss/b12-reflex.md): keep upper body; lower half = GPT deck (window 3:2 upright, bubble top-right, lever bottom-right), no counter/meter on the deck. Disagreed: GPT wants half-fold to use only the loaded roll — kept user's A6 (shows chosen roll, loads on first shot). Not done yet: tap-to-focus instead of grid toggle (no focus control in model), left-hand variant.
- Art: finder_v1 (deck), lever_v1, bubble_v1 (transparent). Bubble = gravity.y along the hinge, ±10° full travel — direction unverified on device.
- Codex review 修改后通过: fixed burst cleanup (onDisappear/scene), strict 3:2 inside window, removed vignette. Skipped: printed label on lever (deck stays clean).

## 2026-11-22 · B8 old pages — concepts out, waiting on user
- GPT discussion (discuss/b8-old-pages.md): outer-screen store = bag's film drawer; tap roll → info card pulled out (big drag-compare sample, try-with-my-photo + save); settings = maintenance kit (3 physical switches, booklet with tabs, long text full-sheet ≥17pt); restore/redeem on the certificate.
- Concept renders: https://claude.ai/artifact/Azm5cRW6797Eh6QWttdpK5 (design/outer/concepts). Decision items B8-store, B8-settings.

## 2026-11-22 · B4 share from review (commit above)
- Reviewing the last picture: format key → SHARE (face + printed name), makes ComparisonVideo from a kept 1350px before/after pair, share sheet via SwiftUI sheet (works in the capture extension too). Codex: pair now also kept when Photos denied; temp mp4 removed on dismiss; key name switches. Not tested on device (needs a real shot).
- B9 (save full-size from "try with my photo") folded into the B8 detail redesign — waits on the user's B8 pick.

## 2026-11-22 · B11 Duo screenshots — samples out, waiting on user
- App Store has iPhone Duo slots: outer 2034x1398, inner 2853x2007 (badge "made for iPhone Duo"); slab-iPhone (Dynamic Island medium) still required.
- GPT plan (discuss/b11-shots.md): 8 shots, first three = the three postures. New: -render inner|finder (full-res), tools/appstore_duo.py. Samples https://claude.ai/artifact/S9S7mVAyCj3Dm9potBzjSQ ; decision item B11-duo.
- Store copy (9c939f1): keywords without brands, copyright 水婴, zh-Hant/ja/ko listings.

## 2026-11-22 · Seven new films (B15) — baked, held back
- f9e577d: LUTs from SFL (exposure: mid-grey ~140), `upcoming` flag hides them (-upcoming 1 in debug).
- Next commit: GPT canisters (3 rounds: label text must read when lying; 5 fixed), notes ×5 languages, 4 samples each reused from existing originals, StoreKit config + metadata rows.
- Still to do: the bag's second tray (16 films + all films > 10 cradles) — design with GPT; then flip `upcoming` off. App Store Connect IAPs are the user's (B6).

## 2026-11-22 · Second tray, seven films offered (e53dfd0)
- GPT discussion (discuss/bag-tray2.md): hinged two-layer tray; all-films only on top; fixed order; open on the tray of next/loaded roll; never auto-flip while open. Art: GPT leather loop; top tray = crop of the bag's own left page, rotation3D 88° about its top edge (perspective 0.12) leaving an edge strip; lower tray = the bag background.
- upcoming removed; golden values added; store copy counts sixteen. Codex 修改后通过: hidden tray now hidden from VoiceOver. Skipped: extra text hint for the loop (strip has no room; loop is visible).
- Installed on Duo. Waiting on user: B8-store, B8-settings, B11-duo, b12-bubble, new-films check.

## 2026-11-22 · EV thumb (user: 拨块很丑 大小也不合适)
- GPT body-black ribbed thumb with white index line replaces the code-drawn yellow knob; sized to the drawn slot (~57 px), ~2.0x groove height.

## 2026-11-22 · 第 3 次蓝图复盘 + F3 托盘提示 + 商品审核截图
- 复盘（discuss/blueprint-3.md）：商品数改 14、新增 1.16 十六卷回归；品牌名商标风险、半折换卷规则 → 决定页（brand-names、halffold-rule）。预算起点更正为真实读数 54%（之前的“+8”是估算，未读真实数据）。
- 55eff5e：有下层托盘时，提示行末尾“拉皮环看下层”（五种语言）。GPT 审查：通过。
- 14 张商品审核截图改用相机包原尺寸渲染（design/appstore/iap），-look 自动翻到所在托盘。现有测试已覆盖 16 卷：每卷付费都有商品、全部胶卷解锁所有。

## 2026-11-22 · 1.16 十六卷回归
- 查过：渲染（单元测试覆盖 16 卷中灰）、说明与商品（测试）、锁屏同步（按商品编号，通用）、锁屏扩展打包全部 LUT、外屏换卷列表可滚动、小组件选单胶卷列表。
- 唯一写死处：大号胶卷架小组件只放 9 卷 → 改 4×4；GPT 审查要求名字不截断 → 名字用满格宽，已修。真机小组件/锁屏待看。

## 2026-11-22 · 4.3 官网必要补缺
- 支持页加 Duo 折叠用法、分享对比视频两条问答（中英）；GPT 要求说明纸签在试拍用完时会先购买，已补。联系邮箱仍等 B5。
- 停止接力（2026-11-22 12:2x）：额度 go（Claude 55%，本段 +1；Codex 剩 84%），但剩余任务都在等用户（B8、B11-duo、brand-names、halffold-rule、气泡、新胶卷真机看）或需真机（F3 切换动画）或已被复盘建议后移（3.3 长图）。品牌名未定前不做新的美术。

## 2026-11-22 · 托盘改成平抬左移（用户：折起本页好丑、不符合物理）
- GPT（discuss/tray-physics.md）：硬托盘整体平抬→左移出包→留提耳“放回”。GPT 皮提耳 tray_tab.png（代码转 90°）。去掉 3D 翻折和底部拉环。审查：工程文件残留引用已清。

## 2026-11-22 · 胶卷架小组件可选卷（用户要求）
- AppIntentConfiguration：中号最多 6、大号最多 16，按选的顺序；固定格位留空。GPT 审查：查询按传入顺序返回，已修。真机编辑小组件待看。

## 2026-11-22 · 用户新提两件事
- 1.17 暗光取景（245fd96）：GPT（discuss/dark-finder.md）建议先让真实曝光撑起取景，不先做取景专用提亮。已做：暗处取景帧最长 1/15 秒、弱光增强、调试日志每 2 秒记曝光/ISO/帧率；审查修了帧时长范围检查。装开发版。下一步等用户暗处试用 + 读日志定数。
- 3.6 增长与社区：GPT（discuss/growth.md）+ 我补自定义产品页/每卷官网页。方案页 https://claude.ai/artifact/PScCJwJA3EwByzgezAMKcZ ；决定页 growth-plan、community-form、dark-finder。

## 2026-11-22 · 半折：快门在上（红色方键）、气泡在下（用户 b12-bubble 意见）
- GPT 重画取景板 finder_v2 + 红键 shutter_key_v1；拨杆资源移出。审查通过。手机不在线，未装机。

## 2026-11-22 · 第二批回答落地
- 540d16e 暗处成片补到取景亮度（按快门记取景曝光，照片暗多少在胶片前补多少，≤2 档，闪光不补；原图不动）。GPT 审查：原图不能被改，已修。
- 4a7ded6 半折：快门红方键在上、气泡在下（GPT 重画底图+红键）。
- b225de6 / de7dec2 相机包左页改为可上下滑的胶卷带（去掉托盘），相机内存根+顶部存根，提示固定在底部压印带，“上下滑看更多”。GPT 讨论 bag-r4，审查通过。
- 改名方案已放决定页（brand-names-2），确认后重画 10 个罐子。手机不在线，以上未装机。
- 下一步：右页顶部“维护”皮盖 + 维护夹（设置），Duo 截图背景与文案。

## 2026-11-22 · 相机 App 爆发路径分析（用户要求）
- 查了 Huji、Gudak、Dispo、Lapse、Dazz、NOMO；GPT（discuss/growth-cases.md）提炼。页面 https://claude.ai/artifact/93v7QhPAB6qjb6nTEHRjpJ 。
- 结论：Koco 的一句话是“合上手机，就装好一卷”；这一轮四件：15 秒装卷短片、“同卷来信”分享样式、第一期主题、App Store 推荐提名（上线前 6–8 周）。决定页：launch-date、first-theme、brand-names-3。

## 2026-11-22 · 胶卷改名（bf2e2bc）
- 11 卷改名，五语介绍去品牌，GPT 重画 10 罐（两罐拼写错重画），商店文案/StoreKit/审核截图跟改。审查通过，已装机（手机已连上）。

## 2026-11-22 · 维护夹设置页（B8-settings）
- 右页上沿提耳“维护/收起”；GPT 底图 kit_v1 + 推钮 + 亮灯；三开关、手册（四页签，标题上页、正文下页）、凭证（恢复购买、兑换码）；许可全文铺满整张纸。
- GPT 审查两轮：英文提耳截断、许可字太小、折缝压字、技巧过时、权限不刷新 → 全修。

## 2026-11-22 · App Store 推荐提名草稿（design/appstore/nomination.md）
- 类型 App Launch；英文说明 + 中文对照；等用户定具体日期后在 Connect 提交（≥3 周前）。补充链接里的 Duo 演示短片待录。

## 2026-11-22 · 分屏 bug（用户截图）
- 分屏/侧拉窗口不铺满屏幕时，机身跟界面方向摆正、整体缩放，不按玻璃方向转。GPT 要求分屏也按内屏走折叠逻辑——不同意：半屏放不下相机包，相机控制按钮唤起时应能拍；记为分歧。模拟器无分屏，待真机验证。

## 2026-11-22 · 用时间换胶卷（用户点子）
- GPT 讨论 discuss/earn-films.md；页面 https://claude.ai/artifact/8ghHu8dG78HLkWLu2VaTn6 ；决定页 earn-rule、earn-scope。建议 12 月：主题小册「它睡着了」7 个不连续拍摄日 + 来信分享，赠卷看时间。

## 2026-11-22 · 胶卷飞到卡片（用户点子）+ 三个 bug
- 卡片托槽（GPT），点卷飞过去、原卷飞回；去掉纸存根和顶部存根；胶卷带下铺平铺绒布、去掉重复压印带。审查：红签跟到卡片、连点不出分身，已修。

## 2026-11-22 · Duo 截图第二版样稿
- GPT 定 8 张中英文标题（discuss/shot-titles.md）；GPT 桌面背景；合成脚本支持背景。样稿 1、3 张中英文已发，等用户 B11-duo-2。

## 2026-11-22 · 演示短片分镜（design/growth/demo-video.md），等用户拍

## 2026-11-22 — Bag pages turn: films / kit spreads
- User: the kit was cramped on the right page, the tab too small; turn the whole page; plan for the community.
- Discussed with GPT (project/discuss/spreads.md): pairs of pages behind big index tabs on the bag's right edge (films → kit → club later); the kit uses both pages (left: switch plate + certificate; right: handbook + bookmarks + nameplate).
- GPT art: kit_spread.jpg (from design/kit/kit_spread_template), index_tab.png. Old kit_page/kit_tab moved to design/kit.
- Rigid page turn about the spine, 0.54 s: front up to edge-on, then the next pair's page comes down; old left page stays until covered; shading on the pages under; reduce motion fades. Each page drawn once (the belt keeps its scroll).
- Codex review: pass. Took its suggestions: handbook shows a scroll bar; restoring purchases now says what happened.
- Tests 59 pass; Debug build installed on the Duo. Not yet felt on device.

## 2026-11-22 — Card well and press-in flight
- User: the pad and roll didn't match, the yellow rim must go, the roll should press in from straight above, more room for the card's text.
- GPT drew a well cut into the card to the canister's own outline (template from the roll's alpha; design/kit/card_slot_v1.png); the old stitched pad moved to design/. Roll smaller (166×86); text starts 72 px further left.
- Flight is now lift → carry → press: the card's roll rises straight up then goes home; the new one is carried over the well, held up, and pressed straight down.
- Codex review: pass; took its notes (a little more clearance so the well shows, old comments).

## 2026-11-22 — Bag taps fixed; widgets redone (user)
- Bug: rolls could no longer be tapped. The right page is drawn over the whole bag (clipped only visually) and swallowed the belt's taps; each page now takes touches only on its own half (contentShape).
- Widgets: GPT art in the camera body's material (black textured plastic, KOCO nameplate, yellow/red stripe), moulded pockets + label windows measured on the art. Medium 4 rolls, large 9, small 1. The picker offers only rolls not already picked (ShelfFilm entity, query depends on the intent's own list); repeats are also skipped when drawn.
- Codex review: fixed its must (widget description translations) and added VoiceOver names.
- Screenshot copy v3 published (decision B11-duo-3); new item earn-first (how low the first roll's bar is).
- Share letter: GPT design (discuss/share-letter.md), art letter_v1 / tray_v1 made; code not started, paused for the user's widget request.

## 2026-11-22 — Page turn second half, sewn-in tabs, tap regression test (user)
- Turn: the landing half now keeps coming over towards the viewer (free edge large, shrinking as it lands) instead of rising from below.
- Rolls not tappable: proved with a new UI test target (cameragrUITests, BagTouchTests): fails on 6e43bac, passes now. Each page now draws only its own half of the bag picture (a clipped full picture still takes touches), and still pages get no perspective transform.
- Tabs: GPT discussed (discuss/bag-tabs.md; its first choice needs the whole bag redrawn, so not now). New tab cut from the bag's own leather (index_tab_v2), tucked under the bag's right edge (the edge strip from the open pair's picture laid over the roots); open tab pulled further out; embossed words centred on what shows; ≥44 pt hit width.
- Codex review: pass; took both suggestions (brighter emboss, min hit width). Installed on the Duo.

## 2026-11-22 — 「轮到你拍了」来信分享（队列①）
- 回看时按 SHARE：取景窗里出现出片夹（GPT 图 share_tray），三档滑钮 视频 / 来信 / 照片，再按 SHARE 发出；点预览可换纸签上的话；点夹子别处收起。默认来信，记住上次选择。
- 来信图 1080×1350（GPT 底图 letter_base：桌面、透明照片袋、牛皮纸签）：成片完整放进相纸、旁边立着这卷的胶卷罐、纸签写 “Koco Film · 胶卷名” 和一句话（两句：今天被这一幕治愈了 / 我家这只又睡着了，轮到你拍了）。
- 外屏截图修好：新增调试 -render outer（按 Duo 外屏实际尺寸渲染真外屏）；之前截图第一张“两个框”是误用了第一版成图。截图标题改由用户来写（决定页 B11-copy）。
- 用户定：第一卷“三天连续参加活动”（earn-first）。
- Codex 两轮：修了“缺原图时三种都不能分享”（现在只禁视频）、来信预览跟随最新照片、提示字号下限。不同意“纯照片分享全尺寸”：要多存一份大图、每拍多一次渲染；1350px 足够社交平台。新增 2 个单元测试（61 个全过）。已装 Duo。

## 2026-11-22 — 翻页中轴和收尾闪动（用户）
- 包框和书脊改成一层固定不动（始终取胶卷页那张图），只有里面的页板翻；页板绕自己靠书脊的那条边转（以前绕书脊中线转，边上会错开）。
- 收尾闪动：以前翻完那一刻包框从一张图换成另一张、下层阴影还在 50% 突然消失；现在包框不换，阴影按正弦在结束前回到 0。
- Codex：通过。建议“两块板转轴差 48px、50% 时会跳”——不改：50% 时两块板都正好侧立、宽度为 0，看不见。
- 用户说“胶卷页的示例照片没了”：模拟器里没拍过的卷样张正常显示，复现不了，已请用户给截图/说是哪一卷。

## 2026-11-22 — 「它睡着了」小册（第三组双页「小册 / BOOK」）
- GPT 定形态（discuss/sleeping-book.md）：相机包第三个页签「小册」；当天用 Koco 实拍、当天放进小册算一天；按开始时的时区、零点换日；连续三天得 Porto 400；断一天从头算，旧照片保留；不补签、无倒计时。已有这卷的人只领纪念章。
- 美术 GPT：book_spread（蓝布小册封面＋睡狗插画、纸条、带相角的内页三格、日期章圈、牛皮纸赠卷袋），第三枚页签沿用皮页签。
- 代码：BookStore（本地 books.json、连续天数、领取一次）、FilmStore 新增赠卷记录（与购买分开、恢复购买不丢、同步到锁屏相机）、快门时刻记日期、册内保存照片副本、点封面看全部照片、失败有提示、坏文件另存不覆盖。新增 4 个规则测试（65 个全过）、UI 触摸测试仍通过。
- Codex 两轮，必须改的都修了。后放：放入前的“夹进小册”确认纸签、封面换成用户第一张、Porto 价签上写“也可连拍三天获得”、回看里的快捷放入、14 天期。
- 审核备注草稿要写进 design/appstore/review-notes.md（活动规则、不需账号、不换评分/下载/邀请）。

## 2026-11-22 — 小册后续四项
- 放入前确认：今天的照片先点选（红框），再点页脚「夹进小册 →」才算，避免误触；每张有拍摄时间的无障碍名称。
- 小册完成后，封面插画窗换成三天里第一天的照片。
- Porto 400 卡片（还没有这卷、没领过时）加一句「也可以连续三天、每天拍一张放进小册，免费领。」，这时简介收成两行；调试开关 -bookHint 1。
- 审核备注 design/appstore/review-notes.md 加「小册」一节（中英）：3.2.2(x) 奖励 App 内拍照行为、免费胶卷可完成、无账号/上传/评分/下载/邀请/站外付款、Porto 照常内购、恢复购买不含赠卷、已有者只得纪念章。
- Codex：通过；采纳两条建议（提示措辞写清“每天放进小册”、无障碍名称）。65 个测试全过，已装 Duo。

## 2026-11-22 — 第 4 次复盘（GPT，discuss/retro-4.md）＋ 小册持久化与赠卷故障回归
- 复盘结论：视觉统一了，但“功能完成”跑在“上线验收”前面，该收口不再加页。提案已写进 QUEUE。
- 本轮做复盘里的第 4 条：
  - 写失败不改任何状态（连时区也不先写）；坏文件另存。
  - 当天换照片时删掉旧副本；副本存了但没放进小册时也删掉。
  - 副本的编码和读取都放到后台，并加缓存；换照片时不会让旧结果盖住新的。
  - 纯照片分享改为分享时从相册读原成片（不多存、不多渲染），读不到才用回看的小图。之前我说 1350px 够用，GPT 不同意，我改了主意。保存失败的那张不会误分享成上一张。
- 新增 6 个测试：重启后读回、零点前拍零点后放不算、坏文件另存、写失败什么都不变、换照片删旧副本、已买的人只得纪念章（71 个全过）。
- Codex：两处必须改已修（保存失败时清掉上一张的相册标识；照片切换时旧的读取结果不覆盖新的）。已装 Duo。

## 2026-11-22 — 发布资料重核（复盘④）＋ 五语界面走查（复盘③）
- consistency.md 重写：16 卷、14 个商品、半折已做、相机包三页签、分享、小册；新增待办第 1 条“小册只在 Duo 内屏能进”。
- metadata.md 五语：补全 16 卷名单、相机包、分享（照片/视频/来信）、小册（写明仅 iPhone Duo、Porto 400、当天用 Koco 拍）；去掉“第二托盘未上”的注释。review-notes：13 卷付费、相机包三页签、checklist 14 个商品与小册录屏。BLUEPRINT 2.9 改 14 个商品。
- 走查：五种语言 × 三组双页 + 外屏渲染。修：卡片右侧让出页签（ISO 被盖）、日文试拍价签截断（試写 %lld）、日文赠卷纸舌断行。
- Codex：两条必须改——“仅 Duo”已加；“截图标题应由开发者写”不同意：用户在决定页原话“我来写吧”，QUEUE 那行已改清楚。

## 2026-11-22 — 外屏/普通 iPhone 也能打开相机包（第一段）
- GPT 定方案（discuss/outer-bag.md）：外屏三个键不变；FILMS 打开整只相机包（胶卷页），SETUP 打开维护页，小册从页签进；以后替代老商店/设置页（B8）。装卷：点签选“下一卷”，扣上包扣才装入（Duo 内屏仍是合上手机）。
- 做了：CameraModel.bag / openBag / closeBag（扣包＝phoneShut，片仓打开、新卷落进去）；外屏 FILMS/SETUP 改开相机包（锁屏相机仍用旧页，买不了也存不了小册）；试拍用完也打开相机包并看着那卷；包开着时快门、音量键、相机控制键都不拍照、不装卷。
- 美术 GPT：合扣皮带 bag_clasp（同皮料、黄铜按扣），放在右边缘页签下；页签缩短让位。外屏文案改“扣上包就装入”。
- 买了不再自动选卷（GPT 建议：买是买，选是选）。
- UI 测试新增“外屏打开相机包 → 点卷 → 扣包关闭”；发现模拟器 Duo 外屏竖着时，合扣贴着屏幕底边，点中间会被系统的 Home 条手势区吃掉，点上半部分可以——真机要确认。修了一个测试竞争（小册测试送出 Porto，退款测试也用 Porto）。
- 还差（下一段）：外屏/普通 iPhone 上字太小（0.455 倍时正文约 7pt），要做紧凑排版；“用我的照片试试”和“存下来”搬进相机包；锁屏 FILMS 改成请求解锁进主 App；然后去掉文案里的“仅 iPhone Duo”。

## 2026-11-22 — 相机包小屏排版（外屏 / 普通 iPhone，第二段）
- 量出的问题（外屏 0.455 倍）：价签字约 5.5pt、卡片简介约 7pt、提示行约 8pt。
- 加 bagBoost（相机包字号放大系数）：内屏 1×，外屏约 1.32×，普通 iPhone 竖着约 1.58×，上限 1.6。
- 小屏时：卡片只留卷名、ISO、一句话和动作（简介隐藏）；价签只写状态（试拍 3 / 免费 / 价格，卷名罐子上有），单行缩放；提示行隐藏；维护开关只留标题；手册、凭证、书签、小册标题/纸袋都放大；小册纸条上限 1.15× 以免挤掉恢复说明；卡片动作热区加大但不占卡片空间。
- Codex：必须改一条（英文小册纸条最后一行被裁）已修。UI 测试 3 个、单元测试全过；内屏截图与改前一致。已装 Duo。
- 还差：“用我的照片试试 / 存下来”进相机包、锁屏 FILMS 请求解锁，再去掉“仅 iPhone Duo”。

## 2026-11-22 — “用我的照片试试 / 存下来”进相机包（第三段，B9）
- 右页照片袋下面、页码纸签旁加一张牛皮纸签「用我的照片试试」（GPT 图 kraft_slip）：点开系统照片选择器，选的照片按正在看的这卷渲染，全屏左右拖动对比；下面两张纸签「‹ 返回」「存下来（全尺寸）」。
- 存下来：按原图尺寸重新冲印、存进相册（单元测试确认 3000×2000 存出来还是 3000×2000）。
- Codex 两轮：①没买的卷也能无限导出全尺寸 → 改成：已拥有免费；没买的每存一张用掉一次免费试拍（失败退回）；用完了纸签变“买下 $x 再存”，买成功后接着存。②购买中连点会重复保存 → 购买到保存全程忙碌、防重入。
- 72 个测试全过，已装 Duo。
- 还差：锁屏 FILMS 请求解锁进 App；然后去掉“仅 iPhone Duo”，老商店/设置页（FilmPanels）只剩锁屏在用。

## 2026-11-22 — App Store 截图：按竞品方向重做（用户选 B11-direction=yes）
- 先看了 10 个竞品（design/appstore/competitors/），用户选“相机整屏 + 成片整屏”。
- 新脚本 tools/appstore_iphone.py：普通 iPhone 6.9 寸竖屏 1320×2868，暖白纸色底、不套手机框，相机/相机包整块，成片做成大照片 + 小胶卷罐和卷名；标题占位（用户写，B11-copy）。8 张：外屏+成片、原图/Instant 800 对比、相机包、Cine 500T 夜景×2、Golden 200 + Chroma 64、来信图、小册、隐私三句。
- 素材：新增调试 -exportSamples 1（每卷样张原图与胶片版导出到 Documents/samples）；-demoShare 来信也改成真套胶片。
- 样稿页：https://claude.ai/artifact/S9S7mVAyCj3Dm9potBzjSQ

## 2026-11-22 — 锁屏相机 FILMS/SETUP 解锁后进 App 打开相机包（第四段，收尾）
- 锁屏相机里点 FILMS / SETUP（以及试拍用完）：请求解锁（LockedCameraCaptureSession.openApplication，带上要开的页和要看的卷）；App 打开后直接开相机包到那一页。取消解锁就留在取景器，什么都不变。
- 相机包已打开时再收到新的“开到哪页”也会跟着翻过去（Codex 必须改，已修）。新增 2 个测试（74 个全过）。已装 Duo；锁屏跳转需真机走一遍。
- 小册在所有 iPhone 上都能进了：商店文案五语去掉“仅 iPhone Duo”，写成“打开胶卷仓就是相机包，胶卷、设置和小册都在里面”；审核备注同步；consistency.md 第 1 条关闭。
- 老的商店/设置/详情页（FilmPanels）现在只在锁屏相机拿不到解锁回调时兜底用。

## 2026-11-22 — 小组件回归（4/9 格，复盘⑤）＋ 真机验收页（复盘①）
- 小组件：选卷逻辑和格子排布抽成可测函数；新增 4 个测试：按选的顺序、同一卷不重复、失效卷跳过、中号 4 格大号 9 格空格留空、每卷链接 peli://film/<id> 正确并装上那卷、跳转时关掉相机包。日文小组件截图核对，长卷名放得下。
- Codex 必须改：包里选了 A 又点小组件的 B，拍照会装回 A → 小组件跳转时取消待装卷和装卷动画状态，加测试（78 个全过）。
- 真机验收页（可勾选、备注，存在页面数据库里我能读）：https://claude.ai/artifact/B3su793GmwTYMsyX61uXVe ——12 项：选卷合上装入、拍照进相册、半折、暗处、切后台、拒绝权限、外屏相机包合扣、锁屏 FILMS 解锁、小册三天、来信分享、用我的照片存下来、小组件；每项写了怎么做、怎样算过、我能从日志读到什么。已装 Duo。

## 2026-11-22 — 小屏大号价签；Duo 横屏截图（同 8 个画面）
- 小屏（外屏/普通 iPhone）时，在原价签上挂一张放大 1.38 倍的同款价签（从包的画上裁出来的 GPT 原图，不改像素），状态字约 9pt；三语核对，“全部胶卷 $14.99”两行放得下。
- 新脚本 tools/appstore_duo_v4.py：按 iPhone 竖屏同样 8 个画面排 Duo 横屏，内屏 2853×2007、外屏 2034×1398 各一套，中英文都出了（标题占位）。样稿页已加。
- Codex：只有一条“样稿页图片路径不存在”——不改：发布时已把 duo4 图映射成 duo_1…8，页面上能正常显示。
- 验收页还没有勾选记录；截图标题仍等用户（B11-copy）。

## 2026-11-22 — 小组件统一成中号样式、去掉凹槽（用户）
- 用户：小组件都用中型的样式，不要凹槽，铭牌也复用中组件那种。
- GPT 把中号背景改成去掉凹槽和标签窗的版本（design/widgets/medium_plain_v1.png）；从这一张裁出三块：塑料面、KOCO 铭牌、黄红条纹，三种尺寸都在同样位置摆铭牌和条纹（不改像素，只裁切和摆放）。
- 胶卷直接立在塑料面上，卷名像机身按键名那样印在下面（大写、浅灰）。小号 1 卷、中号 4 卷、大号 3×3。旧背景移到 design/widgets/old/。
- Codex：通过。78 个测试全过，已装 Duo（桌面上的小组件要等系统刷新，或删掉重加一次）。

## 2026-11-22 — 普通 iPhone（iPhone 16 模拟器，竖持）走查
- 用户说“继续”。剩下的都要等用户，做了不等用户的一项：普通 iPhone 走查（相机机身、相机包三组双页）。
- 结果：机身和相机包在竖持时整块横过来（按设计：相机要横着拿）；小屏放大字后价签、卡片、手册、小册纸条都看得清；合扣离屏幕底边约 170pt，不在 Home 条手势区。
- 局限（等用户定）：竖持时相机包只占屏幕约 2/3 高，上下黑边；要用满得改成普通 iPhone 一次只显示一页，改动大，记入 QUEUE B。

## 2026-11-22 — App Store Connect 准备（用户在场）
- 密钥文件 chmod 600；团队密钥 gr（M9BUC6BUJK）有效、权限“管理”；Issuer ID 核对通过（只读查询 200）。Issuer/Key/App ID 存在 ~/.appstoreconnect/koco.env（600），不进仓库。tools/asc_jwt.py 用 openssl 签令牌。
- 用户同意后用接口注册 3 个套装 ID：com.oneskill.cameragr、.widgets、.capture。
- 用户用 GPT（浏览器代理）新建 App：Koco Film，iOS，简体中文，SKU koco-ios-001，Apple ID 6838100352；接口核对一致。内购商品 0 个。
- 下一步待用户同意：用接口建 14 个内购（13 卷 + 全部胶卷，非消耗型、家人共享、$1.99/$14.99）。付费 App 协议由用户自己处理。
- 用户说“建吧”：tools/asc_iap.py 用接口建好 14 个内购（13 卷 + 全部胶卷），非消耗型、家人共享、中英文名字说明、美国基准价 $1.99/$14.99、全部地区上架；tools/asc_iap_shots.py 上传按当前界面重渲的 14 张审核截图（design/appstore/iap2）。核对：14 个全是 READY_TO_SUBMIT。
- 中国区自动换算 ¥15 / ¥98，和 metadata 里写的 ¥12 / ¥68 不同——价格交用户定（决定页 cn-price）。

## 2026-11-22 — Store listing written to App Store Connect (user approved "商店那个可以填")
- tools/asc_metadata.py: reads design/appstore/metadata.md (en-US, zh-Hans, zh-Hant, ja, ko), checks lengths, sets category Photo & Video, copyright, name/subtitle/privacy URL, description/keywords/promo/support URL on version 1.0. `--dry` prints without writing. Re-runnable.
- Read back from ASC: all 5 languages present, version still PREPARE_FOR_SUBMISSION, nothing submitted.
- Japanese keyword 写ルンです風 → 使い捨てカメラ風 (trademark).
- Done in the browser by GPT (Codex thread): App Privacy "no data collected" published with the privacy URL; Paid Apps agreement Active until 2027-05-07. Sandbox tester filled (Koco/Test/US) but waits for a never-used email from the user.
- Still open: screenshots (wait for B11 titles), age rating questionnaire, price/availability (needs user OK).
- Same day, user OK ("好 你做吧"): age rating questionnaire answered all None/No (4+); app price Free (USA base); availability 174 of 175 territories, China mainland off until ICP, new territories on. Done by API, nothing submitted.

## 2026-11-22 — 英文截图换成英文界面（自动推进）
- 用户说先试填标题；之后自动推进挑了不用等用户的一项：英文截图里相机包、小册、来信原来是中文界面。
- 在 Duo 模拟器用英文重渲外屏、相机包、小册、来信四张素材（design/appstore/iphone/src/en/）；两个截图脚本按语言取素材，英文素材缺了就报错，不悄悄混入中文。
- GPT 审查：必须改一条——普通 iPhone 合不上，第 3 张“合上手机就装好了”不对。已改成按设备写：普通 iPhone“挑一卷，扣上包扣就装好了 / Pick a roll, buckle the bag, it's loaded”，Duo 保留合机。采纳建议：finder→viewfinder，with a line→with a note。
- 全部 48 张（iPhone、Duo 内外屏 × 中英 × 8）尺寸核对无误；样稿页已更新（中英切换）。标题仍是试填稿，等用户改。提交 f89d0fd。

## 2026-11-23 — 自动推进暂停（额度）
- Claude 本周用量这一段已多用约 10 个百分点（估计 64%，起点见 project/budget.json），到了 A2 规定的上限；Codex 多用 5 个点。不开新任务。
- 用户给了沙盒测试员邮箱，转述文本已给出（GPT 在浏览器建，密码用户自己输）。
- 下一个不用等用户的任务：1.14 最终界面中英文走查。用户说“继续”时以当时用量为新起点。

## 2026-11-23 — 单卷可以直接买（用户真机反馈）
- 用户绑好沙盒测试员后说“胶卷没有单个购买的选项”。原因：设计上单卷只在 3 张试拍用完后才显示价格可买；全部胶卷一直可买。
- 改：卡片上“试拍 · 免费 3 张 →”下面加一行“或直接买下 · 价格”（已装入相机的试拍卷也有）。五种语言文字已加。78 个测试全过。
- GPT 审查：必须改“已装入的卷也要能买”→已改；建议两行点按区域分开→已改。提交 d139f3a。
- 真机装的是 Release 配置（开发签名）：Debug 版在拉不到商品时会假装购买成功、显示占位价，测沙盒会误判。

## 2026-11-23 — 沙盒购买实测通过
- 用户在 Duo 上用沙盒测试员买下 Cine 500T。从手机拷出 App 设置核对：store.owned 只有 cine500t（来自苹果的交易记录），试拍没被扣；开发版留下的两条假购买记录（ccd、portra400）在正式配置里不生效。
- 正式配置不写 Diag 日志，所以这次购买本身没有日志；之前开发版的日志里没有错误。

- 11/23 续：重装后恢复购买（Cine 500T 回来）、买全部胶卷，真机通过。清除沙盒购买记录不会撤销手机上已存的交易，也不算退款；退款逻辑由自动测试覆盖，用户同意真机不测。手机数据备份在 project/phone-backup-1123。

## 2026-11-23 — 小组件 KOCO 改成凹刻（用户）
- 用户：KOCO 铭牌太显眼、有点丑，换成凹刻。GPT 在同一张底图上把银色铭牌换成压进黑塑料的凹字（design/widgets/medium_debossed_v1.png）。
- 只裁切不改像素：铭牌块从新图原位置裁；塑料底纹也改从新图、和铭牌同一高度处裁（原底纹取自偏暗的下半部，会露出方块）；铭牌块四边用遮罩渐隐融进底纹。旧素材在 design/widgets/old/。
- GPT 审查通过。提交 e13ae5f，已装 Duo（Release 配置）。桌面小组件要等系统刷新，或删掉重加。

## 2026-11-23 — 1.14 最终界面走查（自动推进）
- 渲染了 Duo 内屏（胶卷、全部胶卷、维护、小册）、外屏（相机、小包胶卷/维护、出片夹来信/视频）、半折取景，中英文；普通 iPhone 维护页。截图在 project/shots/1.14/。
- 发现并修好：①外屏手册页签字落到布条下面，黄色“权限/Access”看不见；②出片夹英文提示被截断（英文改短，键不变）；③外屏“Redeem a code”顶边框；④外屏小包卡片上的小册提示太小且被截断（小屏换短句“或免费：连续三天放进小册”、字放大）。
- GPT 第一轮必须改两条，均已改：普通 iPhone 的手册写“合上手机/半折”做不了 → 新增“是否折叠屏”判断（窗口短边 >450 点），普通 iPhone 写“打开胶卷仓点 FILMS…扣上包扣”、不显示半折；英文短提示补 running（连续）。第二轮通过。
- 留意（未改）：普通 iPhone 英文维护页“Restore purchases”按钮字被缩成“Restore purch…”，属于 B18 竖持小包的问题。
- 78 个测试全过。提交 5ea207f，已装 Duo（Release）。

## 2026-11-23 — 手册正文底部渐隐（自动推进）
- 1.14 审查里 GPT 的建议：手册还能往下滚时，最后几行淡进纸里；滚到底就完整显示（onScrollGeometryChange 判断）。中英文、内外屏截图正常。GPT 审查通过。提交见 git log。
- 看板加了一题 testflight：上传 TestFlight 要用户点头（动 App Store Connect）。
- 剩下的任务：3.3 长图（复盘建议后移、本阶段收口不加新页）、F3 切换动画要真机，其余都等用户。自动推进停在这里。

## 2026-11-23 — 截图重做：调研 + GPT 讨论 + 前三张样稿
- 用户（B11-copy）：图太丑；先研究好的做法和连续关系，和 GPT 讨论；删“不用账号”；问横屏 Duo 图在哪显示。
- 调研（17 个 App 的现行截图，含 Not Boring Camera、Halide、Kino、NOMO、Hipstamatic、Structured、Flighty、Opal）：最接近我们的是 Not Boring——实物大、敢裁边、深色质感底、短标题。连接方式：同一空间/光线（Opal），一个物体或线索引向下一张（Structured、Flighty）。搜索里竖图并排显示前三张，横图只显示一张。
- GPT 讨论（project/discuss/shots-redo*.md）：选炭黑摄影台；四组双页、主角不跨缝；不画“相片吐出”；同裁切上下对比；不画未上线的社区；删“不用账号”也不换成别的隐私承诺。第二轮点评后改了三处（取景窗做主角、相机包加放大的卡片代替散卷、对比照片加“原图/Instant 800”标签）。
- tools/appstore_v5.py：1206×2622（普通 iPhone 必传尺寸），GPT 背景 design/appstore/v5/table_a.png，真实 App 画面只摆放。前三张中英文 + 搜索预览已发样稿页。等用户看方向。
- TestFlight：1.0 (1) 上传成功，等苹果处理。
- TestFlight 1.0 (1) 处理完成（VALID）：出口合规设为“不含非豁免加密”；建了内部测试组“Koco 内测”（可用所有构建），加了账号持有人。Info.plist 加 ITSAppUsesNonExemptEncryption=false，下一版构建号 2。
- 11/23 用户已通过 TestFlight 邀请邮件装上 1.0 (1)。

## 2026-11-23 — 自动推进兜底唤醒：不开新任务
- 额度 go（Claude 63%，本段 0；Codex 剩 78%）。但剩下的都等用户：截图新方向（看板 shots-v5，前三张已出）、TestFlight 版三项检查、真机验收页。看板状态卡已更新。
- 11/23 截图：用户要求先定每页核心意思再定画法；草稿 design/appstore/story.md（iPhone 7 页、Duo 4 页），等用户回“定了”。兜底唤醒未开新任务。

## 2026-11-23 — 用户报“一按快门就跳到胶卷页”
- 读手机设置：TestFlight 版里没有购买（沙盒买的不带过来），装着的 Porto 400/Pro 400H 试拍 3 张已用完 → 按快门按设计打开相机包。用户选了卷、扣了合扣仍跳：点卷只是“看”，点价签才“选”；外屏小包上又没有这句提示；落到的卡片只写“已在相机里”。
- 修（fb44dc7）：①装着的卷试拍用完时，卡片写“试拍用完了 · 买下 ¥… → 或换一卷”，点价签/卡片就买；②这时没选下一卷就扣合扣，第一下不关包，红字提示“先点一卷的价签选好，再扣上包扣”（各尺寸都显示），再扣一下才关；③购买等批准时优先显示“等待批准”，不再重复购买。
- GPT 第一轮否了我“扣合扣自动装正在看的卷”（违反“只看不换卷”），改成上面的提示；第二轮通过。78 测试过。TestFlight 第 2 版上传中。
- 待用户定：试拍用完时第一下快门是否先提示再跳（方案 A）。
- 11/23 社区方案 v0.2（project/community-plan.md），GPT 讨论 project/discuss/community-plan.md；待用户定 3 处活动规则。
- 11/23 用户定活动规则：任何时间的 Koco 照片可投（须合主题）；3/7/14 天奖励；全胶卷用户得新胶卷兑换资格；徽章/贴纸；限定只能打卡得。记入 community-plan §5、蓝图 3.11、记忆。

## 2026-11-23 — 看板回答落地：试拍用完先提示；小册任何时候的 Koco 照片都能放
- 用户选：used-up-warn=先提示再跳；book-anytime=改；v1-rewards=v1 就做 7/14 天（送哪两卷待定）；shots-story=要改（没写改什么）；shots-v5=不好看。
- 试拍用完：第一下快门不拍、不跳，液晶屏显示 END，取景器写“Porto 400 的试拍用完了 · 再按一下快门，去换一卷或买下这卷”；第二下才打开相机包。长按连拍不算第二下；换卷（任何方式）清除提示。外屏和半折取景都有。
- 小册：任何时候用 Koco 拍的照片都能放，放进去算当天打卡；同一张不能用在两天。五语文案改成“每天放一张用 Koco 拍的照片”“放入今天的一张”；空列表区分“还没拍过”和“都已放进小册”。
- GPT 两轮：第一轮 3 条必须改（连拍、换卷清除、文案），第二轮 1 条（空列表）；都已改。78 测试过。TestFlight 第 3 版上传中。

## 2026-11-23 — 看板回答：限定胶卷、截图第六版第 1 页
- 用户：7/14 天送新做的限定胶卷；截图每页意思“知道了”（按草稿用）；上一版“太空、主角不够大不够精致”。
- 限定胶卷：看板新题 limited-films，5 个候选（紫调幻彩、红外红叶、反装红调、交叉冲洗、大光晕夜片），等用户挑两个。
- 截图：和 GPT 讨论统一画法（project/discuss/shots-form.md）：暖灰影棚底（GPT 画）、标题左上、每页一个真实画面做大且出界、不加小窗。渲染加 -renderScale（5 倍），第 1 页“一台真正的胶片相机”中英文已出（tools/appstore_v6.py，ba01089），发样稿页等用户看。

## 2026-11-23 — 胶卷页第一行点不了（真机反馈）；试拍用完改成“买下 / 换一卷”
- 复现：UI 测试在外屏小包里点 Golden 200 无效；逐点探测发现相机包顶边约 80pt 一条全是死的（手机横拿时第一行正好在这里）。两次猜错（SwiftUI 旋转、UIKit 旋转容器），后来加了调试用的“命中日志”（-logHits 1，记录每次触摸落在哪个 UIKit 视图），查到真因：.onCameraCaptureEvent（相机控制键/音量键拍照）给界面包了一层只有安全区大小（382×644）的视图，超出它的触摸根本进不去。修：这一层也 ignoresSafeArea 铺满全屏。顺带：相机包打开时机身的曝光拨盘、舱门不接收触摸。早先合扣贴底边不好点（模拟器里只能点上半截）也是同一原因。
- 用户：快门不该用来跳页；试拍用完应给两个选项。改：第四下快门不拍，液晶屏 END，取景器里两张牛皮纸签“买下 · 价格”（就地弹系统购买，不跳详情页）和“换一卷”（打开相机包）；再按快门不跳。等批准时显示“等待批准”、不重复购买；买到/批准后 END 自动消失。
- 测试：新增 UI 测试“第一行在内外屏都能点”“试拍用完点换一卷打开相机包”；全部 UI 测试和 78 个单元测试过。GPT 两轮：第一轮“等待批准”已改；第二轮“购买失败要提示”——全 App 所有购买入口都是失败不提示，单独记成任务（QUEUE），不在这一处单改。提交见 git log。TestFlight 第 4 版上传中。

## 2026-11-23 — 内屏分屏打开时相机倒着、被裁（真机反馈）
- 原因：转方向的容器判断“是否分屏”时只问窗口，启动那一刻窗口还没挂上，就当成整屏、按整屏方向转了（倒置），之后不再重排；分屏时机身还会被拉伸成窗口形状。
- 修：判断也看视图自身尺寸，窗口挂上后重新排一次；分屏时外屏机身按原比例整台放进窗口（上下留黑），不转、不拉伸。全屏不受影响（截图与 UI 测试确认）。模拟器无法分屏，需真机验证。GPT 审查通过。TestFlight 第 5 版。
- 11/23 用户定第 1 页背景 A（胶卷平铺）；宣传语待定，五句候选已排在 A 版上发样稿页对比。
- 11/23 用户：第 1 页胶卷背景出多个设计稿 + 多个文案；第 2 页突出胶卷很多（不写 16）；第 3 页所见即所得；加社区页（看很多别人的照片）。已出 5 种排法和 6 组文案；顺序记入 design/appstore/story.md；社区页要等社区上线才能放进商店。
- 11/23 用户定第 1 页用黄底；标题“胶片相机”，副标题暂用“让此刻，慢慢显影”。
- 11/23 第 1 页标题改为用户原话“不是 iPhone，是胶片相机”（英文 Not an iPhone. A film camera.），副标题暂用“让此刻，慢慢显影”。
- 11/23 第 1 页去掉副标题（用户）；修正中文标题字重（之前误用 W3，改 W6 粗体）。
- 11/23 标题排法和 GPT 讨论后定：两行大标题（中 132 / 英 112 px），左 84、顶 150，暖近黑 #211E18，人工断行、不自动缩字；第 2 页副标题去掉“还会越来越多”。缩略图尺寸下可读。
- 11/23 截图第一版整套（普通 iPhone）：1 黄底相机、2 胶卷照片墙、3 所见即所得（相机+同一张成片）、4 先试你的照片（真实对比界面+几张原图）、5 来信、6 小册（GPT 画的睡着的狗+App 自带的猫，调试参数 -bookPhotos 填小册）、8 小组件。第 7 页社区等上线。3–8 页标题为草拟。

## 2026-11-23 — 购买失败要有提示（自动推进）
- 以前所有购买按钮在断网、App Store 连不上、交易验证不过时都只是“没反应”。现在：失败时相机弹出提示“购买没有成功。请检查网络后再试一次。”（验证不过时提示去“恢复购买”）；用户自己关掉购买框不算失败，不提示。五种语言。
- 测试：模拟交易失败会提示；取消类错误识别单独测（测试环境把模拟取消报成 unknown，真机关掉购买框是 userCancelled 结果，不抛错）。80 个测试全过。GPT 审查通过。提交见 git log。
- 已从电脑本地装到 Duo（覆盖 TestFlight 第 5 版）。自动推进停：剩下的截图 Duo 一套要等用户看完 iPhone 一套再做，避免返工；其余等用户。
- 11/23 用户：所有页不要副标题；第 2 页方向“一种胶卷、一种风格、更是一种生活方式” → 标题“换一卷，换一种生活”（另备 3 个）。
- 11/23 用户：第 4 页标题“买之前，先试试”；删来信页、小册页；小组件页留图换字；社区页想方案。GPT 讨论 project/discuss/shots-more.md：小组件标题 6 选、社区页 3 个概念（首选“今日共拍簿”）、普通 iPhone 先 5 页、Duo 套加半折腰平。
- 11/23 加相机包页（挑一卷，装进相机）和社区概念页（GPT 画的“今日共拍簿”竖版：同一道题、不同作者署名；标题“同一道题，各自的生活”）。新顺序 7 页。社区页上线后换真实截图才能进商店。
- 11/23 顺序：1 iPhone、2 换一卷、3 社区（概念）、4 相机包“不是相机包，是摄影师的军火库”、5 所见即所得、6 买之前先试试、7 小组件。
- 11/23 第 7 页：小组件 + 相机控制键合一页（GPT 画的拇指按侧键照片），标题“小组件、相机键，一键直达”。
- 11/23 第 3–7 页重做（用户：前两张可用、其余不好看且风格不一；GPT 讨论 shots-redo3）：主角放大、照片越过画面边缘、黄灰交替。新增调试 -exportOne（一张样张套全部胶卷，用于“先试试”页的扇形照片）。社区页加散出的陌生人照片；第 7 页标题“两种方式，一键直达”，用 GPT 专门画的手握手机按键照片。
- 11/23 第 7 页改为小组件 + 相机控制键示意图（GPT 画的局部，红圈红箭头）；底色两方案：A 全黄、B 每页一色（黄橙红橄榄青玫瑰天蓝）；修了阴影被截成方框的问题（影响所有页）。等用户选方案。
- 11/23 23:5x 自动推进：截图第 8 页相机键提示——红箭头已否、只发光太淡，GPT 重画成手机侧转、相机键亮暖光（无箭头无字，中英通用）；另出“麻绳小挂签”备选。GPT 审查（reviews/shots-p8.md）：①第 4 页卡片底行改为“每天放一张 Koco 照片进来，就算打卡”（与小册规则一致，已改中英）；②7/14 天限定卷尚未实现——这页在功能上线前不能用（记入 QUEUE）；③要求给相机键加文字标注——我没加：用户刚否了箭头式标注，挂签备选已放样张页由用户定；④注释胶卷名已统一。
- 11/23 自动推进：内屏导航改成用户选的“收音机波段窗”（17790e0）。黄铜框 + 拱形玻璃 + 米黄刻度纸 + 红指针 + 滚花小钮（GPT 零件，design/nav/parts），放在左页最下方；页名用文字（各语言可读），点页名或沿窗滑动切页；右边皮书签去掉，扣带保留。维护页、小册的左页整体缩到 92% 放在 GPT 画的空布面上，给导航让出底部；胶卷带底边上移到 926。GPT 审查通过，按建议缩短指针（尖端停在字下方）、热区宽度至少 44pt、改注释。单元测试 80 项、相机包触摸界面测试全过；内外屏中英渲染检查；Release 版已装手机。社区页签等社区上线时再加。
- 11/24 自动推进：①相机包换新导航后重截截图素材（v6/src/{zh,en}/bag4.png），竖屏第 5 页“军火库”重出。②iPhone Duo 横屏截图第一稿（tools/appstore_duo_v7.py，内屏 2853×2007、外屏 2034×1398，中英各 7 页，和竖屏同语法：黄底、两行标题、一个大主体；对比页在横屏里放整张照片）。GPT 审查：默认生成去掉第 4 页（7/14 天奖励未做，已改）、样张页注明“未来功能预览”和“压缩预览”（已改）；建议相机键再亮一点——沿用竖屏同一张图，等用户看。
- 11/24 自动推进：1.14 界面走查（新导航之后）。Duo 内屏五种语言（英、简、繁、日、韩）× 胶卷/维护/小册三组双页逐页渲染看过；外屏中英；普通 iPhone（iPhone 16 模拟器，日语）三页。导航文字五语都放得下（日语“フィルム/メンテ/ブック”、韩语“필름/관리/북”），选中红字和指针对得上；维护页、小册缩小后文字和按钮都完整，热区由界面测试覆盖（BagTouchTests 全过）。没有发现要改的问题，本项无代码改动（不送 GPT 审查）。
- 自动推进停（11/24 00:4x）：剩下的都要等你——社区第三版方向、每日限免进不进 v1、限定胶卷挑哪两卷（看板 limited-films）、Duo 横屏截图意见、真机试新导航。
- 11/24 用户“继续”：社区接着设计——看照片（抽出放大 + 牛皮纸信息卡：作者/胶卷/题目/日期/一句话/红心/同款胶卷/举报）、投一张（只从自己 Koco 拍的照片选、写一句、放进去、提示公开），写进 community-plan.md 第 6 节；截图第 3 页用社区页斜切（标题占位“每天一道题，大家一起拍”）。整套 8 页齐了。
- 11/24 自动推进：两卷限定胶卷 + 7/14 天奖励。暮紫 Dusk 200（紫调：绿变紫、蓝变青、黄变粉，肤色红色不变）和火叶 Ember 400（彩色红外：植物红粉、天空蓝紫、肤色苍白偏暖），都是我们自己设计的色彩变换（tools/creative_looks.py，不用第三方数据；光谱库自带的 Aerochrome 在没有红外信息的照片上只会变青，不能用）。GPT 画同款双色罐子（紫+青、酒红+粉，带金星）。只能在小册连续打卡拿到：不卖、没有试拍、不算在“全部胶卷”里；小册信封先给 3 天的 Porto 400，领完换成 7 天暮紫、再 14 天火叶，断签不丢已达成的天数。五语文案。GPT 审查：修了暮紫色相插值绕圈（橙色变绿）、“连拍”改“连续打卡”、达成后提示可领取。单元测试 81 项（新增限定卷测试）、界面测试全过。
- 11/24 自动推进：每日限免（用户定进 v1）。按手机本地日期轮换，13 卷付费胶卷每天一卷、所有人同一天同一卷；当天不限张数、不扣试拍，照片保留；第二天回到试拍状态，卡片写“昨天的限免 · ¥ 留下它”（试拍用完时）。签上红字“今日限免”，卡片“今日限免，随便拍 · 装上它”，下面仍可“或直接买下”。限定卷、免费卷不参加；“拥有”和“今天能拍”分开，小册领奖、已拥有数量不受限免影响。午夜、改系统时间时页面刷新。GPT 审查：已加跨日刷新、昨天用日历算、旧详情页买断按钮按“拥有”判断。单元测试 82 项、界面测试全过（界面测试用 -dailyFree off）。
- 11/24 自动推进：权益文字统一（复盘①）。维护页凭证加“今日限免：某卷，当天随便拍，照片都留着”和“限定胶卷只能在小册里打卡获得，不卖”；买全后写“所有在售胶卷都是你的”；全部胶卷卡片写“现在出售的和以后新出的…限定胶卷只能小册获得”，外屏小卡片副标题改“所有在售胶卷，永久拥有”；旧详情页同步。五语。GPT 审查两条已改（紧凑布局也说清范围、买全文案）。测试 82 项过。
- 11/24 自动推进：②五语商店描述 + 审核备注待发布稿（metadata_draft.md、review-notes_draft.md；加每日限免、3/7/14 天、限定卷不卖、全部胶卷=在售、去掉“没有账号”、审核备注改波段窗和试拍用完新流程）；③v1 截图提交集 design/appstore/v1（竖屏 6.3 寸 + Duo 内外屏，中英各 7 页，不含社区页）。都没碰 App Store Connect，看板 store-copy-v1、shots-upload-v1 等用户点头。
- 自动推进停（11/24 03:1x）：复盘提案剩下的④回归需要真机、⑤隐私页要用户给真实联系邮箱；其余等看板回答。
- 11/24 03:1x 唤醒：读到看板同意更新商店文案和上传截图；metadata.md 已换新稿，写入 App Store Connect 被自动模式拦下，等用户在对话里当面确认。其余等用户（第 3 页新版、真机导航）。自动推进停。
- 11/24 自动推进：安装包瘦身。装机 127→82 MB，下载估算 ~98→~63 MB：胶卷颜色数据改存半精度（最大误差 0.00024，远小于 8 位输出的 0.004；颜色基准测试通过）、胶卷罐图缩到显示所需尺寸、PNG 无损压缩、锁屏相机不再带相机包的图。构建号 13，未装机（用户正在测 12）。

## 2026-11-23 build 15
- Open phone: exit hint at the real system bottom (bar + "Swipe up from this edge to leave"), wakes on open, hold change, and swipes from other edges.
- Launch on inner screen stays black until gravity is known and layout still 0.3 s (max 1.4 s).
- Finder hinge: tabs and screws removed (GPT edit, design/finder/deck_body_material_plain_gpt.png).
- Board: batches failed silently when they touched existing items without if_version; now pinned.

## 2026-11-24 真机反馈（构建 16–20）
- 16：从外屏展开时，转轴还在动就保持黑屏，全开立刻出胶卷页、停在半开 0.3 秒才出拍照界面（之前先闪拍照界面、全开后还等 1 秒）。内屏选好卷后合上：外屏出现时仓门已开、仓内是空的，新卷直接放进去；装卷动画缩到约 2/3。
- 17：内屏退出提示只在“看到的底边 ≠ 系统底边”时自己出来（胶卷页倒拿、拍照界面）。
- 18–19：锁屏相机展开平放不进无图的相机包；维护页开关面板 GPT 重画（开/关两张，琥珀灯 + 铬拨杆）。
- 20：锁屏展开平放 → 请求解锁并打开 App 胶卷页；点“全部胶卷”后合上不换卷（之前会悄悄装上之前看过的那卷）；外屏退出提示加文字。

## 2026-11-24 自动推进：限定卷的旧入口（构建 21）
- 未获得的暮紫/火叶：旧详情页把灰掉的“试拍”换成“打开小册”；外屏胶卷仓列表点它打开小册而不是装上；万一已装上按快门，提示“只能在小册里打卡获得”，按钮“打开小册”，不再出现没有价格的购买。五语。
- GPT 审查（reviews/limited-paths.md）：①提示句的本地化写法错了 → 已改；②英文正文“被截断”、退出提示挡“用我的照片试试”→ 不改：正文区可滚动，底部是渐隐；退出提示 4.5 秒淡出、不挡点击。82 项测试过，已装到手机（21）。

## 2026-11-24 看板回复处理（构建 22）
- 维护页开关改回滑块（用户：原来是滑块和槽不适配，橘色暖一点，不用拨杆）：原面板 + GPT 在同一面板槽里画的暖铜滑块和暖橘灯，抠出后滑块左右滑。顺带发现 19 版截取原图时 sips 偏移参数顺序弄反（先 y 后 x），拨杆面板整体偏了 10 像素——已随恢复原面板消失。
- 联系邮箱：只存本机 ~/.appstoreconnect/koco.env，不进仓库。App Store Connect 写入再次被自动模式权限拦下，要用户在对话里说一句（看板 asc-go）。
- 看板加：kit-switches-v3、lockscreen-flat-2（解释情形）、book-vs-club-2（v1 带小册、社区下一版的理由）、asc-go。

## 2026-11-24 构建 26–27
- 26：相机包一出来就关相机（以前直接以相机包启动时关相机被跳过，相机控制键还能调曝光条）；维护页左页换成小册页同一块底板，布面通到书脊（面板、凭证、右页原位）。
- 27：“全部胶卷”放到胶卷带第一格（用户：放最上面）。
- 设置扩展概念（GPT）：可滚动面板，滑块行 + 读数窗行（语言跳系统 per-app 语言页）。https://claude.ai/artifact/RrMiPXUEL6YXTFc5ArJ5wv ，看板 settings-growth 等用户定。

## 2026-11-24 构建 28–36（真机反馈）
- 28 日志保留上一次；29 转鼓（后废）；30 相机包里相机待机不关（修“直接进相机包约 10 秒被系统结束”）；31 平面四行面板；32 App 内选语言；33 六行面板（语言纸卡列表 + 相机/相册权限）；34 导航红针换成平行红杆；35 相机包顶边手势先给 App；36 翻页按相机包自身方向量拖动（横拿/倒拿能翻页）。
- Supabase 后台建好（koco-community，东京，免费）但用户随后选“全 Cloudflare”，等 Cloudflare 令牌。审核三样都要（管理员模式、文字过滤、举报通知）。

## 2026-11-24 自动推进暂停（额度）
- Claude 本段已多用 10 个点（0.65→0.75），到暂停线；Codex +6。等用户说“继续”，届时以当时用量为新起点。下一项：Cloudflare 后台（等令牌）、社区 App 端。

## 2026-11-24 自动推进：社区 C1 地基（新额度起点 Claude 75% / Codex 剩 72%）
- App↔Cloudflare 后台的接口约定 project/community-api.md（Apple 登录验签 + 会话令牌、主题、看帖、预签名上传、发帖、点赞、举报、拉黑、领奖、注销、管理员接口）。
- App 端 cameragr/Community：数据结构、CommunityClient 协议、MockCommunityClient（按规则实现，界面先接它）、CommunityPhoto（发帖前缩到 1600/400 px、去掉 GPS 等元数据）。
- 测试 10 项（共 92 项全过）。GPT 审查必须改 1 条（重新登录清空奖励→可重复领）已修；建议采纳：删帖不撤销打卡（服务端另记 checkins）。蓝图加“社区 v1”C1–C6。

## 2026-11-24 自动推进：社区 C3a 正式部件
- GPT 出：社区页底图（同一只包，右页黄铜活页导轨 + 三个环）、可拼接的一行三格透明插袋；活页环抠成单独图层压在插页上；插袋位置量好。预览 https://claude.ai/artifact/84WNcmtixZB3tTgMuFNVy5 （看板 club-c3a）。只有美术部件，未送 GPT 审查。
- 期间真机反馈：38 分屏按屏幕判断内外屏；39 相机包里买了就算选中。

## 2026-11-24 自动推进：社区 C3b 相机包社区页（构建 41，已装机）
- 右页：长插页穿在黄铜活页环上，照片在插袋里，牛皮纸小签“作者 · 胶卷 · ♥ 数”；上下滑停整行、每行一震。左页：开放中的题目（选中的大签 + 题目说明，其余小签可切换）。数据接本地假后台（用 App 样张当别人的帖子）。
- 波段窗改三档“胶卷 · 维护 · 社区”，小册不再可达；“打开小册”入口改“打开社区”（奖励文字 C5 再改）。顺带修正 Porto 400 的内部 id（portra400）。
- GPT 审查两轮：①三档 ②左页最小导航 ③切题目/失败时清空旧照片 ④“打开社区”五语 ⑤图片换地址先清空、防旧请求覆盖——全改。92 单元 + 8 界面测试过。

## 2026-11-24 自动推进：社区 C3c-1 看照片（构建 43，已装机）
- 点插袋里的照片抽出放大（可缩放），下面牛皮纸卡：作者 · 胶卷、题目、日期、一句话；红心点赞；“···”举报（6 种理由）或拉黑；举报/拉黑后相机包上方闪一行提示。
- GPT 审查两轮：样例帖子 ID 跨主题重复、拉黑提示看不到、新提示被旧计时清掉——都改了。92 测试过。
- 用户要的“留言”还没进接口约定（后台和审核都要多一套），记进 QUEUE B 问。

## 2026-11-24 自动推进：社区 C3c-2 投一张（构建 44，已装机）
- 左页题签下“投一张”→ 牛皮纸文件夹，列出所有 Koco 拍的照片（任意日期）→ 选一张、写一句（≤80）→“放进去”：从相册读原图、缩到 1600/400、去元数据、发出，排到插页最前。题目已结束/文字违规/失败都有提示；发送中不能取消。
- GPT 审查两轮：取消 60 张上限；假后台存图失败不算发帖；发送中禁取消；输入提示加深——都改了。92 测试过。
- 已完成任务累计 5 个（C1、C3a、C3b、C3c-1、C3c-2），下一轮先做第 6 次 GPT 复盘。

## 2026-11-24 第 6 次复盘（GPT，discuss/retro-6.md）
- 结论：方向对、但还是原型。蓝图社区顺序改为 C2a 认证 → C2b 联网投稿 → C2c+C6 审核闭环 → C5 奖励搬家（小册退出）→ C4 发布收口；接口约定补授权码与撤销、可撤销会话、私有 R2 经 Worker 出图、达标资格永久。看板加三问：先审还是后巡、谁接举报、秒删与删号重建规则。

## 2026-11-24 自动推进：社区 C2a 认证骨架（Cloudflare，已上线 koco-community.sybbzb.workers.dev）
- D1 建表（用户、会话行、用过的 nonce、题目、帖子、每日打卡、点赞+计数触发器、举报、拉黑、永久达标资格、领奖、上传、待撤销的 Apple 授权）。
- Worker：Apple 令牌验签（签名、公钥轮换、iss/aud/时间、哈希 nonce、防重放）；会话存表，退出/封号/注销立即失效；注销删光数据和照片；Apple 授权码交换与撤销已写好，等“通过 Apple 登录”密钥（配上后登录必须换到凭证；撤销失败每小时重试）。tools/cf_deploy.py 不用 wrangler 部署。
- 线上实测：未登录 401、假令牌拒绝、连续打卡计算、非管理员不能封号、封号后会话立即失效、退出、注销级联、点赞者注销后计数归零。GPT 审查两轮：授权码与撤销闭环、计数残留、撤销重试——已改；“首次登录必须换到凭证”在密钥配上前无法强制（否则谁都登不进），已按“有密钥就严格”处理。
- B：用户要在苹果开发者后台建“通过 Apple 登录”密钥（看板 apple-siwa-key）。

## 2026-11-24 自动推进：社区 C3d 改回 v4（build 46）
- GPT 重画社区底图：活页导轨和三枚环钉在左页靠书脊；插页从环下穿过书脊铺到右页边，占包的大半；题目窄条在导轨左侧。环钉图层重切。
- 插页一直留着（翻页、拖一半取消都不丢滚动位置和题目），翻页时淡出；照片下的名字、胶卷、点赞字号加大。
- 92 个单元测试 + 翻页 UI 测试通过；已装手机。GPT 审查：改后通过（要求翻页时插页随两页分开——两套滚动同步太脆，改为保留状态+翻页淡出，记为后续可做）。
- B：用户真机看 build 46 社区页；用户正在建“通过 Apple 登录”密钥。

## 2026-11-24 看板答复落地
- 先审后公开、举报发邮件（邮箱待补：club-report-email）、边角规则收紧、留言进 v1（新增 C7）、手册黄签放“关于 Koco”。写进蓝图。

## 2026-11-24 自动推进：社区 C3e（build 47，已装手机）
- 导航“胶卷 · 社区 · 设置”（维护改名设置、社区提前）；看照片的“⋯”变淡、挨着红心，举报理由小小地展开在卡片里；手册黄签“关于 Koco”；隐私页改为“只有投到社区的照片离开手机”（C4 再核）。
- 94 单元 + 8 UI 测试通过。GPT：改后通过。

## 2026-11-24 自动推进：社区 C2b 第一段（写好，未上线）
- Worker：私有上传（JPEG 结构/尺寸/归属）、先审、批准当天算打卡、重试不重复、分页、签名图片链接（隐藏/删除即失效）、点赞/举报/拉黑/删帖（批准一小时内删回收那天）、删号后同一 Apple 账号不能再领、迁移脚本。
- App：联网客户端（钥匙串会话）、Apple 登录（题目栏和投稿夹里）、草稿跨断网/登录过期/重启保留、滚动加载更多、载入失败可重试、自己待审帖标“审核中”。
- B：Cloudflare 令牌失效（看板 cloudflare-token-2）；Apple 登录要显式开发描述文件（看板 siwa-profile）；Apple 登录密钥（apple-siwa-key）。三样到位后部署、接真后台、两账号真机验收，再交 GPT 复审。

## 2026-11-24 自动推进：社区 C2c+C6 审核闭环（写好未上线；build 48 已装手机）
- Worker：待审队列、举报列表、隐藏列表、提醒；批准/不通过/隐藏/恢复/封号/解封/结案，每步和改动同批写日志；第一次公开才算打卡（不论批准还是拒后恢复）；封号用户的帖要先解封才能恢复；管理员签名链接能看隐藏图，别人的立即失效（no-cache）；点赞/举报/拉黑限流；每小时查积压、未处理举报、当日投稿量、存储接近免费额度。
- App：左栏底部“我的”（管理员带红色数字）；面板四栏：待审 / 举报 / 隐藏 / 提醒；举报只有隐藏/恢复成功后才结案；理由、补充说明、提醒按语言显示。假后台改为先审，自己是管理员，可在手机上走一遍。
- 96 单元测试通过；GPT 两轮：改后通过。
- B：举报邮件要一个放在 Cloudflare 的域名（看板 report-email-route）；部署等 Cloudflare 新令牌。

## 2026-11-24 第 7 次复盘（GPT，discuss/retro-7.md）+ C2-fix
- 结论：方向对，“审核闭环写好”说得过满。顺序改为 C2-fix → C2-test（部署前用测试 Worker 回归）→ C5 → C7 → C4；Release 禁止假社区；留言统一先审、≤120 字；不承诺“一天内处理”。
- C2-fix（d2c3bc1）：Release 无服务器时显示“社区即将开放”；批准时公开+打卡+资格同一事务、并发批准只算一次；一小时规则按批准时间且在删除事务里判断（并发秒删不漏回收，SQLite 实测）；管理员看隐藏图链接 10 分钟；API 文档对齐。96 测试通过；GPT：改后通过（已改）。

## 2026-11-24 C2-test + C5 + 正式后台上线（build 49 已装手机）
- 用户发来新 Cloudflare 令牌。测试 Worker（独立 D1/R2，只有它开测试登录）上 tools/worker_test.py 38 项全过：投稿只成一帖、待审只有作者可见、四个并发批准跨午夜只算一天、连续三天与资格、一小时规则（先隐藏再删、两帖同时删）、隐藏图、封号、三人举报、领奖、删号重建不能再领。顺手修了迁移注释分号、会话按真实时间、Cloudflare 拒绝默认 User-Agent。
- 正式 Worker：迁移、部署，图片签名密钥与 Apple 登录密钥（Team/Key ID/.p8）已配；正式版没有测试登录。线上还没有题目（看板 first-themes-live 请用户出题）。
- C5：领取路由（一条语句里查资格与删号记录）、“我的”三档凭证（领取 / 已领取 / 已拥有 / 还差几天）、领到的卷进胶卷商店（锁屏、小组件跟着），换手机登录后找回；小册的页面、美术、存储、测试、文案全部退出（已送的卷不收回，手机里旧文件不删）。85 单元 + 8 UI 测试通过；GPT：改后通过。
- B：App 接正式后台还差 Apple 登录描述文件（siwa-profile）和第一批题目；举报邮箱与发信域名；3 天档已拥有者的奖励。

## 2026-11-24 看板答复 + C7 留言（已上线；build 50 已装手机）
- 看板：首批题目（它睡着了 / 窗边，五语，先开到 2027-02-01）写进正式 D1；举报收件邮箱作为 Worker 密钥配好（发信等域名）；描述文件用户选“用 API 建”，但自动模式拦了写开发者账号，已在聊天里请用户确认（只读核对：App ID 已开 Apple 登录、Duo 已登记、本机证书 N2K5YD53T3）。
- C7：照片背面纯文字 ≤120 字、无链接、先审；同 id 重发不重复；留言者/照片作者/管理员可删；三人举报隐藏；拉黑双向不可见且不能在对方照片下写；母帖隐藏/删除则留言下线；不计打卡；“我的”新留言（任何题目的照片都能点开）与计数；管理员“留言”栏；每步记日志。测试 Worker 55 项 + App 86 测试通过；GPT：改后通过（已改）。

## 2026-11-24 C5b 兑换凭证（已上线；build 51 已装手机）
- 已买过 3 天档胶卷的人领 3 天档时得一张兑换凭证，可换任一还没有的普通付费卷；服务端白名单（来自 films.json），换错或未知卷不消耗凭证，只换一次，删号重建不再给。“我的”里三种状态：领兑换凭证 / 兑换凭证·挑一卷 / 换好后显示那卷的名字。
- 全胶卷用户的凭证换什么待定（看板 voucher-allfilms），先显示“已为你留着”。测试 Worker 全过（顺手让测试 Worker 的图片密钥固定），App 87 测试通过；GPT：改后通过（已改）。

## 2026-11-24 C4a App 内上架要件（已上线；build 52 已装手机）
- 首次投稿/留言前看社区规则并同意（六条；服务端记版本，升版本要求重新同意，未同意的投稿/留言服务端拒绝 428）；“我的”底部：改名字（≤30、过滤）、社区规则、退出登录、删除账号（第二步写清删什么，删后本机草稿与状态清空，Apple 授权撤销结果如实显示）；退出/删号后旧请求结果不回填（账号代次）。
- 测试 Worker 全过（加了规则与改名）；正式 Worker 已迁移部署；App 88 测试通过；GPT：改后通过（已改）。
- 需要用户/后台的部分列进看板 c4-checklist。

## 2026-11-24 第 8 次复盘 + C8 并发与账号隔离（测试 Worker 通过、正式已部署）
- 复盘 8（discuss/retro-8.md）：状态分四档记；等用户期间做 C8 → C9 真机验收脚本 → C10 弱网与审核反馈 → C6a 通知发送与重试 → C11 备份恢复 → C12–C14；管理员 Web 后台暂缓。
- C8：测试时钟按请求（AsyncLocalStorage）；批准时连续天数在数据库里用递归查询、和打卡同一事务算资格；删号在同一事务里把已领奖励转存防重领记录；删号先删行再清照片，之后每小时再清两遍（失败不推进）；正式环境没有 Apple 密钥就拒绝登录；App 领奖/兑换每次等待后都校验账号代次。测试 Worker 全过（加了第三天两帖同时批准），App 88 测试通过。GPT 第一轮“不通过”的四条都已改。

## 2026-11-24 C10 弱网与审核反馈 + C9 验收清单（正式已部署；build 53 已装手机）
- 服务端 /v1/me/mine：本人的帖（任何状态）与未公开留言。“我的”里“我的投稿”一排缩略图标 审核中/未通过/已公开，下面是待审/未通过留言的完整列表。
- 投稿失败时投稿纸上写明“草稿还在，再点放进去”，同一个 id 重试不会重复；留言待发的文字和 id 存在本机，重启后回到输入框，已入库就不再发。图片链接过期（403）按帖子 id 重取、各处替换。退出/删号清空本人列表。
- C9：project/acceptance-community.md 写好 27 步真机验收（两用户 + 管理员），描述文件到位后执行。
- 测试 Worker 全过；App 88 测试通过；GPT：改后通过（已改）。

## 2026-11-24 C6a 通知发送与重试（正式已部署；build 54 已装手机）
- 发信队列：举报（同一小时合并成一封，只发新增的几条）、待审积压、用量告警进队列；先认领再发（租约十分钟，两个发送者不会抢同一封）；失败按 2/4/8… 分钟退避，最多 6 小时、八次后标失败；举报后立即试发，每小时任务补发；重复举报不再入队。
- 发送方式可替换：Cloudflare 发信绑定（等 willll.com）；测试 Worker 用记录型假收件箱验证了合并、失败重试、只发新增。正式环境现在没有发信方式，消息等着、不消耗重试次数。
- 管理员“提醒”顶部：待审照片/留言数与最早等待时间、未处理举报（含留言举报）、邮件状态。测试 Worker 全过；App 88 测试通过；GPT：改后通过（已改）。

## 2026-11-24 C11 备份恢复演练与最小日志（正式已部署）
- 演练（tools/backup_drill.py，只动测试库）：建人、帖、打卡、奖励 → 取恢复点 → 弄坏题目 + 删号 → D1 Time Travel 恢复 → 各表行数一致、题目复原、删掉的人随恢复回来 → 重放删号 → 人再消失、照片打不开、防重领记录在、重放两次无害。踩坑：用本机时间取恢复点会差到更早（改用 D1 自己的当前书签）。
- 删号先写 R2 台账（含已领档位），写不进去就不删；重放按台账补防重领记录、清照片，清不掉的进每小时重试并如实报告；维护模式（MAINTENANCE 密钥）只留管理员接口；每请求一行 JSON 日志（编号、路由形状、状态、耗时、错误码，不含查询串、令牌、内容），Cloudflare Observability 已开。
- project/runbook-backup.md 写好正式库恢复步骤，并说明 v1 不另备份照片的理由。GPT：改后通过（已改）。

## 2026-11-24 C12 流量与费用测算（正式已部署）
- 测试 Worker 回每请求真实消耗（只测试环境）；tools/load_test.py 实测：逛一次 35 请求/41 查询/~650 读行/31 次看图，投一张 4 请求/10 写行/2 次存图，重复看图 1 请求。
- 发现并修了：一页 30 张每张单独查作者和点赞，一个请求 61 次查询，超免费版每请求 50 次上限；改成列表一次带出（逛一次 101→41 查询，接口中位 254→131 ms）。
- project/capacity.md：100 日活宽裕；1,000 日活 Worker 请求用到 76%（最先碰顶，主要是看缩略图）；10,000 日活需升级。附超额后果（1027、D1 报错、R2 计费）、告警线、不花钱的降载办法和升级方案。顺手更正：免费版 Time Travel 只有 7 天（手册原写 30 天）。

## 2026-11-24 C13 无障碍与五语收口（build 55 已装手机）
- 看照片、投稿夹、“我的”、规则页的文字跟随系统字号放大；最大字号下“我的”整体滚动、三档奖励改竖排、管理栏可横滑，看照片整体可滚，输入框和发送、关闭都够得着。相册口袋给 VoiceOver 一句话：谁、哪卷、几个赞或审核中（五语、英文单复数）。
- 缩略图本机缓存：按帖子与尺寸记 10 分钟（按内存约 60 MB 封顶），退出登录清空；隐藏后列表刷新即不再出现（capacity.md 的第一招）。
- project/l10n-review.md：繁中/日/韩各 401 条待母语校对的清单（简中为准，用户定过的文案不改）。88 测试通过；GPT：改后通过（已改）。

## 2026-11-24 第 9 次复盘 + C15 收口（已部署；build 56 已装手机）
- 复盘 9（discuss/retro-9.md）：再做一轮有边界的收口（C15）和上架资料稿（C14）后停工程推进，等真机联调；不再加功能。
- C15：投稿（含读相册之后）、留言、改名、同意规则、打开照片——每次等待后都校验账号代次，换号后旧请求不写任何状态；删号先标“离开中”（之后领奖一律拒绝），再按定下的已领档位写台账，最后删号，中断后可重试；维护期间仍可登录；举报邮件主题带编号，八次失败后在“提醒”里可“再发一次”；图片加载失败原位显示可点的重试；删号提示与说明如实（照片一小时内清完、只留 Apple ID 单向编码与已领档位）；手册写清邮件实际重试节奏与恢复边界。
- 测试 Worker 全过（加了：删号中不能领奖、八次失败后人工补发）；备份演练仍通过；App 88 测试通过；GPT：改后通过（已改）。

## 2026-11-24 C14 上架资料待确认稿（build 57 已装手机）+ 按复盘 9 停止工程推进
- project/store-drafts/：1 隐私政策+数据清单（登录时收集与主动发布时收集分开写；删号＝立即停用、照片后台清除失败重试、Apple 授权撤回失败重试，不承诺时限）、2 隐私标签对照（逐类对应代码；PrivacyInfo 的收集项等确认后再改）、3 年龄分级依据（不沿用 4+）、4 审核备注与演示路径（英文）、5 支持页+社区规则、6 五语商店文案社区版（清掉小册与“不上传”，英文宣传文本 160 字符）+截图清单。所有【待填】留给用户。App 删号说明同步去掉“一小时内”。GPT：改后通过（已改）。
- 停止接力：按复盘 9，社区 v1 剩下的都在等——描述文件授权（联调与 C9 真机验收）、willll.com 发信、全胶卷凭证用途、上架资料确认、母语校对、容量选择。用户回复后再继续。

## 2026-11-24 C5c 全胶卷用户的纪念徽章（已上线；build 58 已装手机）
- 用户看板 voucher-allfilms 选“纪念徽章”：拥有全部常规付费卷（买了全部胶卷，或逐卷集齐）的人领 3 天档得一枚纪念徽章，不给胶卷；已经拿到凭证但无卷可换的，可以“换成纪念徽章”。
- 徽章美术由 GPT 画（黄铜边、奶油珐琅、红色胶卷罐和三颗星，design/community/parts/badge_3day_gpt.png），我只抠了白底。“我的”3 天档显示“纪念徽章”和这枚别针。
- 服务端 badge 档与“凭证换徽章”；测试 Worker 全过（加了两项）；App 89 测试通过；GPT：改后通过（已改）。

## 2026-11-24 看板答复 + C3f（build 59 已装手机）
- 看板：缩略图边缘缓存可以接受（要接自己的域名，等 willll.com 的答复）；审核闭环 OK；社区页仍不对（正在按调研重做）；“用户不能感知到被审核”含义待确认（看板 c7-meaning）。
- C3f：社区页的导航波段窗收窄，停在左页、不再压到相册（翻页时随页面平滑变宽变窄）；照片卡上的“⋯”换成一面淡淡的小旗（举报），举报理由改成两行小字，不再是一堆方框；留言：自己的或自己照片下的显示垃圾桶（删除前确认一下），别人的显示小旗；两者都适用时并排。点按区域 44。89 测试通过；GPT：改后通过（已改）。
- 社区左页重做：deep-research 拆解 13 类图片社区（reports/图片社区信息结构拆解.md），等用户认可方向后出线框。

## 2026-11-24 C16 审核不让人察觉（已上线；build 60 已装手机）
- 用户看板选：用户不能感知到被审核。自己的照片和留言在自己这里就像已经发出（不标审核中/未通过，提示“已放进相册”），别人只看到通过的；自己待审中的照片也能留言、点赞；作者能看到自己被隐藏的照片（作者专用链接）。“我的投稿”只放照片不标状态。规则页仍写明所有内容会先审核；上架草稿同步。
- 社区重做：用户选 A（征集夹）+ 认同调研得出的结构方向 → 下一步出结构线框。
- 测试 Worker 全过（加两项）；App 89 测试通过；GPT：改后通过（已改）。

## 2026-11-24 C17a 胶卷页看自己的照片（build 68；手机不在线，未装）
- 用户：胶卷页“我的相册”看照片也要和社区一样。现在用同一套：照片在左、纸条在右（胶卷名、拍摄时间、第几张）；双击全屏铺满屏幕（盖过相机包四周的留边），纸条浮在右下，轻点照片隐藏；左右滑翻同一卷；全屏/关闭按钮两种状态同一角。
- 投过社区的照片：投稿成功后本机记住“照片 → 帖子”（换账号、删号清掉）；纸条显示“已贴到社区”、赞数和“看留言”（打开社区看片卡）。打开时刷新一次“我的投稿”，纸条跟着它走（赞数更新、删帖消失、换账号立即清空）；未登录不发请求。
- 89 测试通过；中英文截图。GPT 两轮：改后通过。第一轮两条必须改已改；第二轮“超过 60 帖”记入 QUEUE D5。
- 未验：已投稿状态的纸条（模拟器假后台里没有本机照片对应的帖子）。
- 同一段还修了（用户报的外屏 bug）：选卷后装片被倒片吞掉、旧卷留着仓门开着（等倒片完再装）；外屏包里选定后自动扣包装卷；退出方向提示被包盖住；回看时换卷取景框停在回看。UI 测试 OuterLoadTests 两项。

## 2026-11-24 C18a 社区左页 v6 第一段（build 69；手机不在线，未装）
- 按用户选的 A 征集夹 + 调研结构：GPT 单独画了海报叠（相片窗抠空）、黄铜夹、铜钉（黄铜/红）、索引卡、红点、带钉纸条、牛皮信封（design/community/v6/parts），我只抠图。
- 左页：题目海报叠，左右滑换题，下面铜钉显示第几张（相册在看该题时为红），海报窗是题目封面或最新一张，海报上“投一张”；九张索引卡＝“全部”+八个常规胶卷小间，点了右边相册换成全站最新/该卷的照片，红点标出，再点回到题目；“我的”信封带新消息数。未登录时卡片位置换成 Apple 登录。
- 服务端：GET /v1/posts（可选 film），两个新索引；测试 Worker 全过（加三项，翻页查找）。正式 Worker 部署被权限拦下 → QUEUE B19。
- GPT 两轮：改后通过。已改：小间里投稿只在合适范围插入；题目加载失败时重试会重拉题目；封面跟结果更新、拉黑后海报不再显示其照片；旧账号的失败回调不影响新账号；读屏选中状态与颜色一致。89 测试通过；中英截图。

## 2026-11-24 第 10 次复盘 + P0-1 统一 C16
- 复盘（discuss/retro-10.md）：五个风险——C18a 未接正式链路、C16 与通知不统一、C17a 关联半成品（撤回 D5）、看片/换卷缺连续验收（浮框触区只有 30）、左页范围不够自明（只有八卷）。顺序见蓝图。
- P0-1：服务端“新消息”不再计“自己的照片过审”（红点只来自别人的留言，打开就有内容）；测试 Worker 全过（加一项）。奖励说明“通过审核那天计入”与规则页一致，不改。正式 Worker 部署仍等 B19。

## 2026-11-24 P0-2 补齐 C17a（build 70；手机不在线，未装）
- 服务端 GET /v1/me/posts?ids=（只回自己的，最多 20 个；没回的就是已删）；测试 Worker 全过（加三项：自己能取、别人取不到、超 20 拒绝）。
- App：胶卷页打开时按本机记住的帖号去取（每 20 个一批），不再依赖最近 60 帖；服务器不再返回的帖号从本机关联里去掉（删帖后不误标），读取失败什么都不改；换账号清空；点赞同步到纸条。
- 模拟后台实测（-ownPosted 1）：纸条显示“已贴到社区”、赞数、“看留言”，中英无截断。89 测试通过。GPT：通过（建议：首次读取失败给轻量重试，记入 P0-3）。

## 2026-11-24 P0-3 看片与换卷固定回归（build 71；手机不在线，未装）
- 触区：“⋯”和浮框里每个选项都至少 44×44（看起来仍小）。最大字号时浮框会被滚动栏裁掉 → 改成直接在卡片里展开（留言的选项竖排），信息行“胶卷·题目·日期”合成一段按词换行。
- 胶卷页纸条首次读取失败时给“点一下重试”。
- 左页胶卷小间的读屏名改成“某卷的照片”，整张卡一个元素（不再和胶卷页的卷名重名）。
- UI 测试共 15 项全过：新增 ViewerTests 4 项（浮框触区、普通双击进全屏不点赞、全屏双击点赞且重复不取消不退出、左右滑换张、放大后拖动不翻页），OuterLoadTests 加“装片途中改选另一卷”（测试开关 -chamberSlow 放慢仓门与保底计时，确认第二次选择发生在装片中途）；BagTouchTests 一项改成计数判断。89 单元测试通过。
- GPT 两轮：改后通过，两轮的必须改都已处理。

## 2026-11-25 C18b 第一段：范围签 + 全部胶卷可达（build 72，已装手机）
- GPT 画了一张带铜孔和红白细绳的吊牌（design/community/v6/parts/tag_gpt.png），挂在信封下：写明右边相册现在是“题目「它睡着了」/大家的全部照片/某卷的照片”（读屏同样读出）；加载失败时重试纸条替换它。
- 九张卡：全部 + 七卷 + “更多胶卷 n/3”翻页，16 卷常规胶卷都能进；正在看的卷不在本页时“更多”带红点。
- 89 单元测试、15 UI 测试全过；中英截图。GPT：改后通过（失败纸条与吊牌重叠，已改；建议的“更多”红点已做）。

## 2026-11-25 用户真机反馈修复（build 73，已装手机）
- 胶卷页自己的照片点不开（样张也是）：照片插页的可点范围只有左上角一格大小（为左右翻页加的 contentShape），六格照片都点不到。改成六格所在的区域。新 UI 测试 OwnPicturesTests 先复现后通过；在 C17a 之前就已存在。
- 看片卡：“⋯”加深加大；浮框改画在最上层（按钮位置用 anchor 传上去），下面垫一层透明“点哪都关”，误开的删除/举报框点外面就消失；留言输入框的键盘点照片、卡片或背景都会收起。新 UI 测试两项。全部 18 项 UI、89 单元测试通过。
- GPT：改后通过（浮框移到根层后“举报理由”字色变浅，已改）。
- 用户问的退出提示：已在对话里说明怎么测（外屏、横拿、打开包、从下边上划）。

## 2026-11-25 N1 第一段：导航窄版（build 74；手机连不上，未装）
- 按用户定的方案：包下沿正中一个窄铜框小窗（GPT 画，design/community/v6/nav/window_narrow_gpt.png），三页位置大小完全一样，社区页不再变窄挪到左边。窗里只露当前页名，红针缩短扎在刻度上；翻页时整条名字纸条平滑滑动；在窗上拖动翻页（松手停在拖到的位置，快甩多走一点），点窗两端翻一页，两端有淡箭头；窗外的名字不接收点按，读屏仍可按名字选。
- UI 测试改成点窗两端翻页；18 项 UI、89 单元测试通过。GPT：改后通过——必须改：底图下沿还没按定稿重画（窗压在页面最底一点），正在请 GPT 只在下沿正中加一块缝线皮托，我只把那一小块拼回原图，其余像素不动。

## 2026-11-25 N1 第二段：小窗的皮托（build 75；手机连不上，未装）
- GPT 在三张底图（胶卷 library_bag、社区 club_spread、设置 kit_spread）下沿正中各加一块缝线皮托；我只取正中那块（x 566…890，y 936 起，羽化 4px）拼回原图，其余像素不动。来源 design/community/v6/nav/seat/。
- 社区页的相册在皮托处挖空（遮罩，按相册自己的坐标）；胶卷页“用我的照片试试”纸条右移让开皮托。
- 18 项 UI、89 单元测试通过。截图页给用户：https://claude.ai/artifact/H8YVydQoYESz1vr4WwN4fY ，看板 nav-seat 等确认。
- 正式 Worker 已部署（用户 11/25 在对话里同意）。

## 2026-11-25 N2 相册铜环随行滚动（build 76；手机连不上，未装）
- GPT 把社区页底图上的铜轨和三个铜环擦掉（只把那一条拼回原图），又画了一个干净的“圆铜座 + 环穿进黑塑料孔”部件（design/community/v6/rings/）。
- 相册的滚动区往左扩到铜轨：每排插页左边带一段铜轨（正反交替拼接，顶端/末端带铆钉端头）和一个铜环，环从铜座出来穿进那一排的孔，全部跟着照片滚动；固定的 club_rings 层删除。导航皮托处的缺口按新原点重算。
- 89 单元、18 UI 测试通过。GPT：通过（删掉旧常量与注释，已做）。

## 2026-11-25 S3 昵称规则（build 77；手机连不上，未装）
- 服务端：names 表按“去空格、统一全半角和大小写”后的写法一人一名；2–12 字，Koco/官方/暗房/管理员/客服/admin 等保留；30 天改一次；改名先占名、本人立刻看到、别人在批准后才看到；被拒静默、名字放出；新账号公开用“Koco xxxxxx”，Apple 给的名字作为待审申请；老账号重名按注册先后归属（先注册的登录时取回，后来者被要求改名），部署后用 /v1/admin/names/settle 每次 10 个补齐。审批带申请版本、在一个事务里条件执行，换了申请就 409 什么都不改；同时两次申请只成一个。
- App：改名失败分别提示（重名/保留字/字数/30 天，附可再改日期）；需要改名时“我的”里红字提醒和“起个名字”；输入限 12 字；管理员“改名”页签（旧名→新名，通过/不通过），读取失败保留原列表；异步结果按账号代次校验。
- 测试 Worker 全过（名字相关 20 项）；89 单元测试通过。GPT 两轮：改后通过，两轮的必须改都已改（先注册者优先、审批绑定版本、并发申请原子、首个名字也先审；审批原子化、账号隔离）。
- 未做：“我的”里的姓名签美术（GPT），暂用现有纸条和输入框。

## 2026-11-25 S1 关注（build 78；手机连不上，未装）
- 服务端：follows 表（一对一条、被关注方向索引），PUT/DELETE /v1/follows/:id、/v1/me/following、/v1/me/followers（只给本人，不在任何地方返回计数）、/v1/feed/following（只有关注的人的公开照片，不含自己的）。关注用一条带条件的插入：对方在、没被封、没在注销、双方都没拉黑、自己关注不到 500 人；拉黑在同一事务里双向删关注。测试 Worker 全过（关注 16 项）。
- App：看片卡第二行右边一张 GPT 画的小纸签“关注/已关注”（关注名单读到前不显示；同一人请求未回时锁住）；左页第二张卡“关注的人”，右边相册换成关注流，吊牌写“相册：我关注的人”；“我的”里“关注的人”（可取消）与“关注我的人”两条名单；登录后、打开“我的”时读名单；拉黑后本地立刻去掉；换账号清空。
- 89 单元、18 UI 测试通过。GPT 两轮：改后通过（登录后读名单、按人串行、关注与拉黑原子；500 上限、名单未知不显示），都已改。

## 2026-11-25 S2 作者页（build 79）
- 服务端：GET /v1/users/:id（别人看到的名字、最常用的胶卷、用过几种胶卷——只按公开作品；是否已关注；没有任何人数）、GET /v1/users/:id/posts（TA 的公开照片，本人页还含自己待审的）；被拉黑（任一方向）、封号、注销中都 404。测试 Worker 全过（9 项）。
- App：看片卡上点作者名 → 收起看片卡，左页海报处抽出 GPT 画的档案夹（圆章写名字首字、名字纸条、“多用某卷 · 拍过几种胶卷”、关注签、口袋上“回到题目”），右边相册换成 TA 的照片，吊牌写“相册：某某的照片”；资料与照片同时读取；读取失败给重试，对方已看不到时提示并回到题目。
- 89 单元、18 UI 测试通过。GPT：改后通过（失败状态与重试、单复数、并发读取已改；简介拆成 S2b 写进蓝图——它要审核，范围单独做；圆章按调研报告用名字首字）。

## 2026-11-25 N1b 长条导航（用户改定；build 80，已装手机）
- 用户在对话里指回之前的长条版（1b），要求高光两端对称、上下做薄、窗里放导航。GPT 画了细长铜窗；三页一致；三个页名在窗里，短红针在当前页名下、随翻页滑动；点名字或沿窗拖动换页（每过一个名字轻震）。皮托恢复原样，相册不再挖缺口，纸条挪开。
- 18 UI、89 单元测试通过。GPT：改后通过（必须改是“与已记录的单词小窗方案不符”——用户本次改定，已补记）。

## 2026-11-25 S6 每日题目提醒（build 81，已装手机）
- 第一次投稿成功后，题目页海报下面一行出现“每天提醒我”小签和 ✕；点了才向系统要通知权限，每天 19:00 本地提醒“看看今天的题目”（不经服务器）。点 ✕ 以后不再问。
- “我的”底部一行有“每天 19:00 提醒：开/关”，只在投过稿后出现；系统里拒绝了就变成“提醒：去设置里允许通知”，点了跳系统设置；回到 App 自动同步权限（两个方向）；排程失败显示“提醒没开成：再试一次”。连点开关有代次保护，不会重复排程。
- 18 UI、89 单元测试通过。GPT：第 1 轮改后通过（只在投稿后可开、合并进账号行、前台同步权限）；第 2 轮改后通过（拒绝后去设置、失败可重试，已改）。

## 2026-11-25 胶卷页贴合修正（用户反馈；build 82，已装手机）
- 底部：导航改细（N1b）后，包底图里那条压进绒布的长条露出一半，滑带下沿把最下一行的大纸签截平。现在滑带下沿放到细导航条上方（912→940），整行纸签完整；下面铺素绒布到缝线边。
- 左列纸签右下角的小豁口：右边槽的绒布边框画在纸签上面了，改成纸签在上。
- 右页卡片上的胶卷凹槽：比胶卷四周大约 8 像素，槽两端的台阶露成“折线”；按现在的胶卷图量过后收紧到贴边。
- 18 UI 测试通过；小修正未走 GPT 审查。前后对比：project/reviews/films-fit/。

## 2026-11-25 第 12 次复盘 + 正式链路准备
- 复盘（discuss/retro-12.md）：先接正式链路、集中真机验收，再做“我的”姓名纸签、S4（已读 = 条目已展示）、S2b、S5。提案写进 QUEUE。
- 准备：project/formal-link.md（8 步接通清单，标明谁做、卡在哪）；acceptance-community.md 补 17a–17k（关注、作者页、每日提醒、自己的照片、导航与触摸）并改了昵称那步。
- B：需要用户在对话里说“同意建描述文件”和“部署到正式服务器”（看板 formal-link）；举报发信要在 willll.com 开邮件转发。

## 2026-11-25 N3 “我的”姓名纸签（第 12 次复盘 ②；build 83，已装手机）
- GPT 画了一张插在信封纸缝里的米色姓名纸签（绿底抠图，design/community/club_nametag_src.png）。名字印在签上，右下小字“点一下改名”；点签就在签上原位输入，签下一行“保存 / 取消”；保存后还是同一张签。底部账号行的“改名字”按钮去掉了。
- 保存中防重复提交；保存已发出时“取消”不起作用（发出的请求撤不回）；旧请求晚到不会清掉新草稿。
- 18 UI、89 单元测试通过。GPT：两轮都是改后通过（编辑按钮挪到签下、可见提示、防重复、保存中不可取消，已改）。

## 2026-11-25 S4a 站内通知：服务端（第 12 次复盘 ③ 第一段）
- GET /v1/me/notices：现算，不建通知表。三类：别人在我公开照片上的公开留言、按照片合并的赞（每人一次，最多显示两个名字）、按天合并的新关注。不含自己的审核结果和自己的动作；拉黑双方、封号、注销中的人都过滤；暗房入选没有真实来源，整类不出。最近 30 天，每页 30 条，三类各自在库里排序翻页再合并，任何一条都翻得到。
- 已读 = 已展示：POST /v1/me/notices/seen 只确认 App 显示过的条目及其版本（时间 + 人数）；组里有新赞/新关注就重新未读；标记只往前走，30 天前的自动清。新表 notice_marks（+ 两个索引）。接口说明写进 project/community-api.md。
- 测试 Worker 已部署，worker_test.py 新增 S4 一节全部通过（含 36 条分两页、同毫秒新增仍未读、拉黑过滤、空/错请求 400）。GPT 两轮改后通过（逐条已读、不先截断、版本含人数，已改）。
- 正式部署等用户在对话里说“部署到正式服务器”（与 S2 一起）。第二段做 App：GPT 蜡封点、通知纸、管理员待办移到管理区。

## 2026-11-25 正式接通（用户在对话里同意）+ 翻页不顺修复（build 84，已装手机）
- 正式服务器部署：S2 作者页 + S4a 通知服务端，迁移建了 notice_marks 和两个索引；未登录访问新接口返回 401（路由在）。
- 描述文件：用 ASC API 建了“Koco Dev Sign in with Apple”（只给 com.oneskill.cameragr，含这台 Duo 和两张开发证书，到 2027-11-25），装到本机。App 加回 com.apple.developer.applesignin；主 App 的 Debug 改手动签名用这个描述文件，扩展仍自动签名；团队写进全局设置。
- App 连正式服务器：CommunityConfig.apiBase = 正式 Worker；模拟器（截图、测试）仍用模拟后台，`-realClub 1` 可切；手机上 `-mockClub 1` 可回模拟。
- 翻页（用户反馈：有时试好几次翻不了）：从可滚动区域边上起手时，系统把手势交给滚动区域，翻页手势被取消却没收尾，“正在翻”的状态卡住，之后的翻页都被挡。现在手势结束或被取消都会收尾（过半翻过去，不到落回）；包两侧皮边加透明抓手（左 0–44、右 1412–1456，避开搭扣），从最边上起手不会被滚动抢走。
- 18 UI 测试通过。GPT：改后通过（无必须改；注释与清单状态已按建议更新）。
- 下一步：用户在手机社区页用 Apple 登录，告诉我后把账号设为管理员，再按 acceptance-community.md 走验收（需第二个 Apple ID）。

## 2026-11-25 S4b 站内通知：App 端（build 85，已装手机）
- 信封：去掉代码画的数字胶囊，有未读时贴一枚 GPT 画的红蜡封点（design/community/club_wax_src.png）；管理员待办数量只留在管理区的标签上。
- “我的”：“新消息”一列，一行一张——缩略图 + 一句话（“Momo 留言…” / “Aki 和另外 3 人赞了这张” / “小林 和 Aki 关注了你”）；点照片类开看片卡，点关注类收起“我的”开作者页。中间部分（奖励、新消息、我的投稿、名单、管理区）合成一个滚动区，名字行和账号行固定，不再挤出纸面。
- 已读 = 已展示：一行在屏上露出六成才算看过，攒一下按 key + at + count 回报；之后从服务器同步未读数（不本地扣）。翻页一次一个、只接到发起时的列表上；刷新请求发出时编号，只收最新的；加载失败保留原列表，翻页失败可点重试。
- 18 UI、89 单元测试通过。GPT 两轮改后通过（未读数按版本对齐并从服务器同步、翻页/刷新乱序防护、失败重试、“新来的”改“新消息”已改）。不同意的一条：从作者页回来不恢复“我的”滚动位置——作者页在包里，“我的”是盖在上面的纸，再打开从最新看起即可。
- 停止接力（11/25 06:5x）：额度 go（周 9%），但复盘 12 顺序里剩下的都等用户——你登录社区后设管理员、两账号真机验收（acceptance-community.md）、S2b 简介能否写站外联系方式、S5 私信要等 willll.com 举报发信跑通（要你点验证邮件）。用户回复后继续。
