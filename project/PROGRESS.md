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
