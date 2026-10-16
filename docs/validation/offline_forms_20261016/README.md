# 两份现有网页离线分享改造（2026-10-16 本机）

入口仍是 deliverables/NEURONS_2D_资产需求_20261015/ 下的两份01 HTML；**每份只需分享单个HTML**，无需工程、data或服务器。美术约11.36MiB，41张参考图原字节内嵌；音频约1.95MiB。个人源路径仅为来源记录，不是可点击外链。旧版/JSON/原进度备份在同目录history/20261016_offline_share_before。

增加兼容schema4进度、两表未知ID/元数据保留、原填写/导入填写/取消的冲突选择、手动复制后备、下载当前填写版网页。原869美术/496音频子项和全部原句/ID不改；当前几何约束附在房组，不删历史规格。data/progress.json哈希与备份一致；未改桌面NEW。

实际程序验证：tools/check_share_forms.cjs → result.json **50/0**。Node/jsdom执行内联脚本、真实DOM事件、无外部资源请求；模拟浏览器Blob/下载/对话框API，序列化已填HTML到仓库外路径并在全新DOM中恢复。包括恶意script样式备注转义、未知两表ID、冲突取消/选择、无效导入原子性、原字节图像和JSON。脱离仓库的测试填写版位于result.json所记目录，只含测试备注，不是人工生产进度。

**不能算通过的部分：** 浏览器工具拒绝打开file://，安全策略禁止替代浏览器/本地服务器等绕过；因此未进行真实离线双击、OS下载、关闭重开、浏览器剪贴板、视觉布局、手机/异机实测。响应式CSS存在不代表手机显示已验收，jsdom不是浏览器。这项限制不影响工程代码修复。

重建仅用tools/upgrade_share_forms.py（从已保存旧HTML注入新运行段），不运行旧build_planning_forms.py/build_asset_forms.py。程序测试需本机tmp/form_dom_validation中的jsdom 26.1.0；HTML成品不依赖它，也不需要接收者安装任何工具。
