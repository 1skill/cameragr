# Koco 社区 API v1（App ↔ Cloudflare Worker 约定，2026-11-24）

用户定：社区进 v1、不做小册；后台全 Cloudflare（Worker + D1 + R2）；只用 Apple 登录；必须在主题下公开发帖才算打卡；3/7/14 天奖励（Porto 400、暮紫、火叶），只能领一次；审核要管理员模式、文字过滤、新举报通知；大陆不上架。

App 端实现在 `cameragr/Community/`（`CommunityClient` 协议；`MockCommunityClient` 在后台到位前给界面用）。服务端照本文实现。

## 认证
- `POST /v1/auth/apple`  body `{ identityToken, authorizationCode, nonce, name? }`（第 6 次复盘：验签/轮换/iss/aud/exp/nonce 防重放；用授权码换 refresh token 存着，删号时撤销 Apple 授权） → `{ token, user: Profile, isNew }`
  - 服务端用 Apple 公钥验证 identityToken（aud = com.oneskill.cameragr），取 `sub` 为账号。
  - `token`：服务端签发的会话令牌，服务端记在 sessions 表，可即时撤销（封号、删号立即失效）。之后请求都带 `Authorization: Bearer <token>`。
  - 首次登录建档：`name` 为空时用“Koco 用户 + 4 位”。`tz` 取请求头 `X-Koco-TZ`（IANA），建档后不变。
- `DELETE /v1/me` → 204。删除账号、全部帖子、照片、点赞、举报、拉黑、奖励记录（App Review 5.1.1(v)）。

## 读
- `GET /v1/themes?at=<ISO8601>` → `[Theme]`（开放中的 + 最近结束的 7 天内）
- `GET /v1/themes/:id/posts?cursor=&limit=30` → `{ posts: [Post], next? }`（隐藏的、被我拉黑的人的不返回；按时间倒序）
- `GET /v1/posts/:id` → `Post`
- `GET /v1/me` → `Me`（profile、streak、rewards、blocked）

## 写（需要登录）
- `POST /v1/uploads` body `{ contentType: "image/jpeg", bytes }` → `{ uploadId }`；照片直接 PUT 到 Worker（`PUT /v1/uploads/:uploadId/photo|thumb`），Worker 校验大小、JPEG 头、归属后写入私有 R2。未成帖的上传 24 小时后清理。
- `POST /v1/posts` body `{ themeId, photoKey, thumbKey, filmId, caption?, takenAt? }` → `Post`
  - 主题必须开放中；caption ≤ 80 字、过敏感词表（命中返回 422 `{ error: "words" }`）；photoKey 前缀必须是本人 id。
- `DELETE /v1/posts/:id` → 204（本人的）。删帖不撤销那天的打卡：打卡另记在 checkins 表（每人每天一行），否则删旧帖会打断连续天数、和已领奖励对不上。
- `PUT /v1/posts/:id/like` / `DELETE /v1/posts/:id/like` → `{ likeCount, liked }`
- `POST /v1/posts/:id/report` body `{ reason, note? }` → 204。reason ∈ nudity / violence / hate / spam / not-koco / other。同一帖 3 个不同的人举报自动隐藏；每条新举报通知管理员。
- `PUT /v1/blocks/:userId` / `DELETE /v1/blocks/:userId` → 204
- `POST /v1/rewards/:milestone/claim` → `{ filmId }`；milestone ∈ 3 / 7 / 14；服务端按 checkins 算连续天数（本人 tz 的自然日），不够返回 409 `{ error: "not-yet" }`，领过返回同一 filmId。达标资格（某档首次达到的时间）永久记下：断签后仍可领。

## 管理员（只有管理员账号）
- `GET /v1/admin/reports?state=open` → `[ { report, post } ]`
- `POST /v1/admin/posts/:id/hide` / `.../restore` → 204
- `POST /v1/admin/users/:id/ban` → 204（隐藏其全部帖子、禁止发帖）
- `POST /v1/admin/reports/:id/handled` → 204

## 数据
- Theme `{ id, kind: daily|weekly|festival, startsAt, endsAt, title: {lang: text}, prompt: {lang: text}, coverURL?, suggestedFilm?, limitedFilm? }`
- Post `{ id, author: { id, name }, themeId, photoURL, thumbURL, filmId, caption?, takenAt?, createdAt, likeCount, likedByMe }`
- Me `{ profile: { id, name, tz }, streak, rewards: [ { milestone, filmId, claimedAt } ], blocked: [userId], isAdmin }`
- 错误 `{ error: code }`，HTTP 4xx。

## 照片
- App 发帖前处理：长边 1600 px JPEG（质量约 0.82）+ 长边 400 px 缩略图；去掉 GPS 和其他元数据。
- R2 桶私有；图片只经 Worker 读取 `GET /v1/photos/:postId/(full|thumb)`，按帖子状态返回（隐藏/删帖/封号后 404）。不用 r2.dev。
