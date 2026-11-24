# App Store 隐私标签对照 · 待确认稿

> App Store Connect 里的“App 隐私”问卷，按当前代码逐项对应。**最终怎么填由你在后台决定**，我不碰后台。填之前请对照 Apple 当时的问卷，选项名称可能有变化。
> 第三方 SDK：没有（project.yml 里没有任何 package 依赖）。只有社区（`RemoteCommunityClient` → Cloudflare Worker）会发起网络请求，另外还有 Apple 自己的 StoreKit 和 Sign in with Apple。

| 问卷里的数据类型 | 收集吗 | 代码依据 | 用途 | 和身份关联吗 | 用于追踪吗 |
|---|---|---|---|---|---|
| 联系信息 · 名字 | 是（只限社区） | `server/worker.js` users.name；`signInWithApple` 取 Apple 给的名字，可在“我的”里改 | App 功能 | 是 | 否 |
| 联系信息 · 邮箱 | **否** | 只请求了 `.fullName`，没请求 email（`ClubSignIn` 里 `requestedScopes = [.fullName]`） | — | — | — |
| 用户内容 · 照片或视频 | 是（只限主动投稿） | `CommunityPhoto.prepare` 去掉元数据 → `/v1/uploads` → R2 | App 功能 | 是 | 否 |
| 用户内容 · 其他用户内容（投稿文字、留言） | 是 | posts.caption、comments.text | App 功能 | 是 | 否 |
| 标识符 · 用户 ID | 是 | users.id，以及 Apple 登录的 sub（apple_sub） | App 功能 | 是 | 否 |
| 使用数据 · 产品交互（点赞、举报、拉黑、打卡） | 是 | likes、reports、blocks、checkins 表 | App 功能 | 是 | 否 |
| 诊断 · 崩溃、性能 | **否**（请求日志在服务端，不含个人内容，只留 3 天）| 服务端每个请求记一行 JSON：rid、路由形状、状态、耗时 | — | — | — |
| 位置 | **否** | 投稿前用 `CommunityPhoto` 去掉 GPS | — | — | — |
| 购买记录 | 由 Apple 处理，Koco 不收集 | StoreKit 只在本机判断拥有哪些胶卷 | — | — | — |

**追踪**：否。没有广告，没有跨 App 或跨网站追踪。`PrivacyInfo.xcprivacy` 里 NSPrivacyTracking 是 false。

**要同步改代码的地方**：`Config/Privacy/App/PrivacyInfo.xcprivacy` 里的 `NSPrivacyCollectedDataTypes` 目前是空的，要按上表补上（名字、照片、其他用户内容、用户 ID、产品交互）。**等你确认标签后我来改，改完再交给 GPT 审查。**

## 必须由你确认
- 最终在后台怎么填；
- 隐私政策的网址（App Store 要求填）。
