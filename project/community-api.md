# Koco 社区 API v1（App ↔ Cloudflare Worker 约定，2026-11-24）

（11/24 第 7 次复盘后与代码对齐：server/worker.js 为准。）
用户定：社区进 v1、不做小册；先审后公开、首次批准当天计打卡；后台全 Cloudflare（Worker + D1 + R2）；只用 Apple 登录；必须在主题下公开发帖才算打卡；3/7/14 天奖励（Porto 400、暮紫、火叶），只能领一次；审核要管理员模式、文字过滤、新举报通知；大陆不上架。

App 端实现在 `cameragr/Community/`（`CommunityClient` 协议；`MockCommunityClient` 在后台到位前给界面用）。服务端照本文实现。

## 认证
- `POST /v1/auth/apple`  body `{ identityToken, authorizationCode, nonce, name? }`（第 6 次复盘：验签/轮换/iss/aud/exp/nonce 防重放；用授权码换 refresh token 存着，删号时撤销 Apple 授权） → `{ token, user: Profile, isNew }`
  - 服务端用 Apple 公钥验证 identityToken（aud = com.oneskill.cameragr），取 `sub` 为账号。
  - `token`：服务端签发的会话令牌，服务端记在 sessions 表，可即时撤销（封号、删号立即失效）。之后请求都带 `Authorization: Bearer <token>`。
  - 首次登录建档：`name` 为空时用“Koco 用户 + 4 位”。`tz` 取请求头 `X-Koco-TZ`（IANA），建档后不变。
- `DELETE /v1/me` → 204。删除账号、全部帖子、照片、点赞、举报、拉黑、奖励记录（App Review 5.1.1(v)）。

## 读
- `GET /v1/themes?at=<ISO8601>` → `[Theme]`（开放中的 + 最近结束的 7 天内）
- `GET /v1/themes/:id/posts?cursor=&limit=30` → `{ posts: [Post], next? }`（公开的 + 我自己待审的；隐藏的、被我拉黑的人的不返回；按时间倒序；cursor 为 `createdAt|id`）
- `GET /v1/posts/:id` → `Post`
- `GET /v1/me` → `Me`（profile、streak、rewards、blocked）

## 写（需要登录）
- `POST /v1/uploads` body `{}` → `{ uploadId }`；两张图 PUT 到 Worker（`PUT /v1/uploads/:uploadId/photo|thumb`，image/jpeg），Worker 校验归属、大小（1.5 MB / 200 KB）、JPEG 结构与尺寸（长边 ≤1600 / ≤400）后写入私有 R2（`<userId>/<uploadId>/…`）。未成帖的上传 24 小时后清理。每人每小时 30 次。
- `POST /v1/posts` body `{ themeId, uploadId, filmId, clientId, caption?, takenAt? }` → `Post`（201；`state: "pending"`）
  - `clientId` 是 App 为这次投稿生成的 id，重试时不变：同一人同一 clientId 返回同一帖，不会重复。
  - 主题必须开放中；caption ≤ 80 字、过敏感词表（命中 422 `{ error: "words" }`）；每人每天 20 帖。
- `DELETE /v1/posts/:id` → 204（本人的，或管理员）。打卡记在 checkins 表、在首次批准时写入；删帖一般不撤销那天，但批准后一小时内删除（不论此刻是否已隐藏）会收回那天（同一天没有其他批准过的帖时），连同那之后达到的资格。
- `PUT /v1/posts/:id/like` / `DELETE /v1/posts/:id/like` → `{ likeCount, liked }`
- `POST /v1/posts/:id/report` body `{ reason, note? }` → 204。reason ∈ nudity / violence / hate / spam / not-koco / other。同一帖 3 个不同的人举报自动隐藏；每条新举报记一条提醒（管理员模式可见）；邮件通知待有发信域名。每人每天 30 次。
- `PUT /v1/blocks/:userId` / `DELETE /v1/blocks/:userId` → 204
- `POST /v1/rewards/:milestone/claim` → `{ filmId }`；milestone ∈ 3 / 7 / 14；服务端按 checkins 算连续天数（本人 tz 的自然日），不够返回 409 `{ error: "not-yet" }`，领过返回同一 filmId。达标资格（某档首次达到的时间）永久记下：断签后仍可领。

## 管理员（只有管理员账号；服务端检查；每步与改动同批写 admin_log）
- `GET /v1/admin/queue` → `[Post]`（待审，最早的在前）
- `GET /v1/admin/reports?state=open|all` → `[ { report, post } ]`
- `GET /v1/admin/hidden` → `[Post]`；`GET /v1/admin/alerts` → `[ { kind, day, text(数字或理由), created_at } ]`；`GET /v1/admin/log`
- `POST /v1/admin/posts/:id/approve|hide|restore` body `{ reason? }` → 204。帖子第一次公开（批准，或拒后恢复）时：公开 + 当天打卡 + 达到的资格同批写入，只算一次。封号用户的帖要先解封才能恢复。
- `POST /v1/admin/users/:id/ban|unban` → 204（封号：隐藏其全部帖子、会话立即失效；不能封管理员）
- `POST /v1/admin/reports/:id/handled` → 204

## 数据
- Theme `{ id, kind: daily|weekly|festival, startsAt, endsAt, title: {lang: text}, prompt: {lang: text}, coverURL?, suggestedFilm?, limitedFilm? }`
- Post `{ id, author: { id, name }, themeId, photoURL, thumbURL, filmId, caption?, takenAt?, createdAt, likeCount, likedByMe, state: pending|public|hidden }`
- Me `{ profile: { id, name, tz }, streak, rewards: [ { milestone, filmId, claimedAt } ], blocked: [userId], isAdmin }`
- 错误 `{ error: code }`，HTTP 4xx。

## 照片
- App 发帖前处理：长边 1600 px JPEG（质量约 0.82）+ 长边 400 px 缩略图；去掉 GPS 和其他元数据。
- R2 桶私有；图片只经 Worker 读取 `GET /v1/photos/:postId/(full|thumb)?exp=&adm=&sig=`：HMAC 签名链接（PHOTO_KEY），普通 1 小时、管理员 10 分钟；按帖子状态返回（隐藏/删帖/封号后 404，管理员链接可看隐藏图），`no-cache` 每次回源校验。待审帖的链接只发给作者和管理员。不用 r2.dev。

## S4 notices（站内通知，11/25）

`GET /v1/me/notices[?cursor=]` → `{ notices: [...], unread: n (≤99), nextCursor }`
- 每条：`key`（`c:<留言id>` / `l:<照片id>` / `f:<日期>`）、`kind`（comment / likes / follows）、`at`、`count`、`people`（最多 2 人，最新在前）、`postId`、`text`（留言前 60 字）、`thumbURL`、`unread`。
- 只算最近 30 天；别人在我公开照片上的公开留言、按照片合并的赞（每人一次）、按天合并的新关注。不含自己的审核结果、自己的动作、拉黑双方、封号和注销中的人。暗房入选暂无来源，不出现。
- 每页 30 条，按 (at, key) 倒序；`nextCursor` 原样带回取下一页。

`POST /v1/me/notices/seen` body `{ shown: [{ key, at, count }] }`（1–30 条）→ 204
- “已读 = 已展示”：只确认 App 真正显示过的条目，原样回传返回时的 `at` 与 `count`（这就是条目的版本）。组里后来又有新赞/新关注，版本变了，再次未读。
- 标记只往前走：更早的版本不会覆盖更新的；30 天前的标记自动清掉。

## S5 私信（11/25，最小安全版）

- `POST /v1/dms/:userId` `{ text, clientId }` → 201 消息 `{id, mine, text, at}`；同一 clientId 重发返回同一条。403 not-mutual（没有互相关注、拉黑、对方封号或注销）；409 wait-reply（对方从没回过时只能发第一条；回过之后双方连续发）；429 too-many（24 小时内已发 20 条，失败的不计）；422 words（1–300 字，拦网址/联系方式/脏话）。
- `GET /v1/dms[?cursor=]` → `{ threads: [{with:{id,name}, last, unread}], unread, next }`，每页 30 个会话；unread 是所有能看到的会话的未读总数（与 `/v1/me` 的 dmUnread 一致）。
- `GET /v1/dms/:userId[?cursor=]` → `{ messages（新的在前，50 条一页，含 unread）, canWrite, mutual, waiting, next }`；取到不算已读。
- `POST /v1/dms/:userId/read` `{ ids }`（1–50）→ 204：只把 App 真正显示过的对方来信记为已读（复盘 13）。取关后旧消息仍可读、不能再发；拉黑/封号/注销则会话整个不见（404）。
- `POST /v1/dms/:userId/report` `{ reason, messageId? }` → 204；附到被举报那条为止的最近 20 条（标出被举报的那条）给管理员，并发邮件提醒（与照片举报同一封小时汇总）。
- 管理员：`GET /v1/admin/dm-reports`（未处理的，含对话），`POST /v1/admin/dm-reports/:id/handled`。
- 顺序一律按写入顺序（rowid），不按写入前读的时钟。
