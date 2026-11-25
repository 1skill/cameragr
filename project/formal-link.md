# 正式链路接通清单（第 12 次复盘 ①，11/25）

目标：手机上的 App 用真实的 Apple 登录连上正式 Worker，按 `acceptance-community.md` 两账号 + 管理员走一遍。

| # | 事 | 谁 | 现状 |
|---|---|---|---|
| 1 | App ID com.oneskill.cameragr 开 Sign in with Apple | 用户（已做） | ✔ 只读核对过 |
| 2 | 建只含 com.oneskill.cameragr、带 Apple 登录、包含这台 Duo 的开发描述文件 | 我用已有 ASC API 密钥建 | ✔ 11/25 用户同意，已建“Koco Dev Sign in with Apple”（到 2027-11-25，含 Duo） |
| 3 | project.yml 加回 `com.apple.developer.applesignin` 权限，装机改用新描述文件 | 我 | ✔ 代码完成（build 84 已签名带权限）；真机登录待验 |
| 4 | `CommunityConfig.apiBase` 指向正式 Worker；Debug 不再用模拟后台（留 `-mockClub` 开关给截图和测试） | 我 | ✔ 代码完成：真机连正式服务器，模拟器仍用模拟后台（`-realClub 1` 可切）；真机待验 |
| 5 | S2 作者页两个接口部署到正式 Worker | 我 | ✔ 11/25 已部署（S2 + S4a 服务端 + notice_marks 迁移） |
| 6 | 举报真实发信：willll.com 开 Cloudflare Email Routing、验证收件邮箱、Worker 加 send_email 绑定 | 你点一次验证邮件，其余我做 | willll.com 已在 Cloudflare；发信绑定未建。S5 私信要等这一步跑通 |
| 7 | 正式库有题目、你的账号 is_admin=1 | 我 | 题目已写到 2027-02-01；管理员在你第一次登录后设 |
| 8 | 按 acceptance-community.md 走 1–27 步（含 17a–17k 新增） | 你 + 第二台 iPhone / 第二个 Apple ID | 等 2–7 |

顺序：2 → 3/4（装 build）→ 5 → 7 → 8；6 可以并行。每一步完成写进 PROGRESS。
