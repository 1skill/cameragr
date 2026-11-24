# 社区数据：备份与恢复（C11）

**数据在哪**
- D1 `koco-community`：账号、帖子、留言、打卡、资格、奖励、举报、日志。Cloudflare 自带 Time Travel，可恢复到最近 **7 天**内任一时刻（免费版是 7 天，付费版 30 天），每个库每 10 分钟最多恢复 10 次。超过 7 天就恢复不了，所以出了问题要尽快处理。
- R2 `koco-photos`：照片（`<userId>/<uploadId>/photo|thumb.jpg`），以及删号台账（`ledger/deleted/<userId>`）。R2 不随 D1 恢复。

**演练**：`python3 tools/backup_drill.py`，只动测试库。11/24 跑过并通过：恢复后各表行数一致、被破坏的题目复原；删掉的人随恢复回来了，重放后再次消失，照片不在，防重领记录在；重放两次无害。

## 什么时候恢复
只在数据被弄坏时恢复，比如误删一批、迁移出错、被攻击。单条内容的问题用管理员操作处理，不动整库。

## 步骤（正式库）
1. **进入维护**：`printf 1 | python3 tools/cf_deploy.py --secret MAINTENANCE`。之后普通请求都回 503，App 会显示“没能载入”；管理员接口照常可用，第 4 步的重放要用它。
2. **找恢复点**（只能找 7 天以内的）：先定一个出事之前的时刻（UTC），然后
   `GET /accounts/<acc>/d1/database/<db>/time_travel/bookmark?timestamp=<ISO>` 取得 bookmark。
   不带 timestamp 时，取的是 D1 自己的“现在”。
   **注意**：时间要按 Cloudflare 的时钟来，不要拿本机时间直接换算。拿不准就往前多留几分钟。
3. **恢复**：`POST .../time_travel/restore?bookmark=<bookmark>`。返回结果里有“恢复前”的 bookmark，记下来，万一恢复错了可以撤回。
4. **重放删号**：管理员账号调用 `POST /v1/admin/replay-deletions`。恢复点之后删掉的账号会再删一次，防重领记录补回，照片再清一遍。这一步**必须做**：账号删了，就不能因为恢复又回来。
5. **对照**：
   - 抽查几条恢复点之后发生的操作：它们应该消失。
   - `GET /v1/admin/status` 正常。
   - 照片能打开。恢复点之后才删的帖子，数据库行回来了，但照片已经没了：显示会是空白，由管理员隐藏或删除。
6. **退出维护**：`printf 0 | python3 tools/cf_deploy.py --secret MAINTENANCE`。如果重放结果里 `complete` 不是 true，先等每小时任务把照片清完再退出。然后在 `admin_log` 和 PROGRESS 里记一笔：恢复到哪个时刻、为什么、重放删了几个账号。

## 为什么照片（R2）不另做备份
R2 没有快照功能。照片只会在两种情况下被删：作者删帖、作者删号。这两种恰恰是恢复后**不该**回来的。除此之外，照片丢失只可能是有人误操作了整个桶，而能写这个桶的只有 Worker 和部署令牌。另存一份要多开一个桶，用量翻倍，免费的 10 GB 会更快用完。
决定：v1 不备份照片。以后要的话，开第二个桶，每天做一次增量复制，由用户来定。

## 日志
- Worker 每个请求写一行 JSON：请求编号 `rid`、方法、路由形状（id 换成 `:id`，**不含查询串**，因为签名链接在查询串里）、状态码、耗时、错误码。
- 不记令牌、授权码、签名、照片或文字内容。
- 在 Cloudflare 后台 Workers → koco-community → Logs 查看（Observability 已开）。
- 用户报问题时问“大概几点、做了什么”，再按时间和路由找对应那一行。
