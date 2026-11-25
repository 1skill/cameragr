# 正式链路接通清单（第 12 次复盘 ①，11/25）

目标：手机上的 App 用真实的 Apple 登录连上正式 Worker，按 `acceptance-community.md` 两账号 + 管理员走一遍。

| # | 事 | 谁 | 现状 |
|---|---|---|---|
| 1 | App ID com.oneskill.cameragr 开 Sign in with Apple | 用户（已做） | ✔ 只读核对过 |
| 2 | 建只含 com.oneskill.cameragr、带 Apple 登录、包含这台 Duo 的开发描述文件 | 我用已有 ASC API 密钥建 | 看板 siwa-profile 选了“用 API 建”，但写开发者账号被自动模式拦下：**需要你在对话里说“同意建描述文件”** |
| 3 | project.yml 加回 `com.apple.developer.applesignin` 权限，装机改用新描述文件 | 我 | 等 2 |
| 4 | `CommunityConfig.apiBase` 指向正式 Worker；Debug 不再用模拟后台（留 `-mockClub` 开关给截图和测试） | 我 | 等 2（不先改：否则手机上社区登不上） |
| 5 | S2 作者页两个接口部署到正式 Worker | 我 | **需要你在对话里说“部署到正式服务器”**（看板 s2-deploy） |
| 6 | 举报真实发信：willll.com 开 Cloudflare Email Routing、验证收件邮箱、Worker 加 send_email 绑定 | 你点一次验证邮件，其余我做 | willll.com 已在 Cloudflare；发信绑定未建。S5 私信要等这一步跑通 |
| 7 | 正式库有题目、你的账号 is_admin=1 | 我 | 题目已写到 2027-02-01；管理员在你第一次登录后设 |
| 8 | 按 acceptance-community.md 走 1–27 步（含 17a–17k 新增） | 你 + 第二台 iPhone / 第二个 Apple ID | 等 2–7 |

顺序：2 → 3/4（装 build）→ 5 → 7 → 8；6 可以并行。每一步完成写进 PROGRESS。
