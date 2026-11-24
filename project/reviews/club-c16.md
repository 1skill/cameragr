## 必须改

- **隐藏照片对作者仍加载失败**：`server/worker.js:830` 将自己的 hidden 投稿加入列表，`cameragr/UI/ClubPage.swift:1699` 也允许打开；但 `server/worker.js:1239` 拒绝所有非管理员的 hidden 图片链接。结果作者看到投稿记录却看不到照片。修复：签发绑定作者权限的图片链接，服务端验证作者身份；其他用户及旧公共链接仍须失效。
- **新增提示缺少翻译**：`cameragr/UI/ClubPage.swift:361` 使用 `Text("Posted.")`，当前 `Shared/Localizable.xcstrings` 无此键，中文等界面会回退英文，违反全部界面可本地化的决定。补齐五语翻译。

## 建议改

- `project/store-drafts/4-review-notes.md:17` 仍称“我的”显示投稿状态，与本次删除状态标签矛盾；同步更新。第 16 行的“⋯”描述也应按当前旗帜、删除按钮核对。
- `cameragr/Community/MockCommunityClient.swift:236` 仍只返回自己的 public/pending 留言，真实 Worker 已返回自己的 hidden 留言；统一假后台行为，避免模拟检查漏掉问题。

## 偏离蓝图

- 当前 `BLUEPRINT.md` 和 `QUEUE.md` 均未找到 **club-c16**，无法核对其独立验收标准。
- `project/BLUEPRINT.md:99` 的 C10 明确要求显示待审、未通过状态，本次将其删除。代码注释称这是用户 11/24 的新决定，但所读决策文件没有对应记录；若确已确认，应同步蓝图和决策记录。

## 测试建议

- 两账号＋管理员验证 pending/public/hidden：作者可见自己的图文，其他账号仅见公开内容；隐藏后旧公共图片链接立即失效。
- 验证作者在待审照片下点赞、留言、删除、重启后读取；批准前不向其他账号泄露，奖励仍只在批准后计算。
- 补充 hidden 投稿与留言的 Worker 回归；目前新增测试只检查待审照片留言返回 201。
- 检查五语提示及 Duo、普通 iPhone 布局。本轮未收到可查看的附图，未验证截断或旋转后的视觉效果；未运行构建、真机或联网测试。

## 结论

修改后通过

