## 必须改

- `PeliWidgets/WidgetViews.swift:29`：配置说明改成了新字符串，但 `Shared/Localizable.xcstrings:3343` 仍只有旧字符串的翻译，中文环境会回退英文，违反已定多语言要求。补齐新键的各语言翻译，或恢复使用已有键。

## 建议改

- `PeliWidgets/WidgetViews.swift:153–163`：为每个胶卷链接添加 `.accessibilityLabel(film.name)`，确保 VoiceOver 直接读出胶卷名称。
- 附图：未见明显截字、错位；但这是 App 内展示图，不能证明真实桌面小组件的点击区域和系统渲染正确。

## 偏离蓝图

- 当前 `project/BLUEPRINT.md` 没有 `widgets-v2` 条目及专属完成标准；只能按 1.8、1.16 和已定的小组件决策核对。应补上任务与验收标准的对应关系。
- `cameragr/UI/RollLibrary.swift:1298` 修改翻页触摸区域，属于胶卷库修复；新增 `letter_base.jpg`、`share_tray.jpg` 的工程资源引用也不属于小组件。建议拆出独立改动。

## 测试建议

- 真机添加小、中、大组件，逐个点击罐子和名称，确认打开对应胶卷；包含七卷新胶卷及已锁定、试拍耗尽的胶卷。
- 配置选满 4／9 卷、少选、删除、重排，确认去重、顺序及空槽正确。
- **重点验证升级兼容**：`WidgetViews.swift:32` 将配置实体从 `FilmEntity` 换成 `ShelfFilm`；旧组件能否保留选择尚未确认。用旧版配置后升级，检查是否重置或失效。
- 在真实组件中检查中文、英文、深色及着色模式；本次未执行构建或运行测试。

## 结论

修改后通过