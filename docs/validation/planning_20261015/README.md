# 规划/表单验证 · 2026-10-15

本目录只记录规划产物检查。本轮未运行Godot、未验收游戏玩法、未生成正式音画。旧游戏测试结果见其他历史目录，不是本目录的新结论。

- validation.json：54项静态检查全部通过。原793/496子ID与顺序保留、ID唯一、子项各归并一次、别名/事件资产引用有效、原状态/文件/许可/备注/台本与随机项保留、共用规格引用/HTML与JSON一致；39基础房型、150搜寻点、45身份、12技能及事件段号范围检查。
- browser_results.json：Playwright驱动实际Edge，检查默认人工视图（99美术包/8音乐包）、负责人切换、子ID搜索、提示词与交付单复制、编辑、DOM导入旧JSON、重复ID原子拒绝、未知未来ID保留、另一表进度保留、实际下载进度JSON。连接/保存用内存文件句柄验证读最新另一表再写，并拒绝覆盖需求JSON；未用测试数据覆盖仓库progress.json。
- 六张最终浏览器截图：art/audio 的 human、codex、mobile。实际查看了主要桌面/窄屏画面；长表全部条目的逐屏视觉未穷举。首次音频台本场景select在430px溢出已修正（max-width/min-width），最终两表窄屏无横向溢出、无页面脚本异常。
- source_checks.json：三份人工原稿与两PDF哈希匹配此前完整读取（共89原稿图）；S1–S4/R1源哈希在production_plan及静态检查；20个第五阶段已读后期文本与当前ZIP逐字节一致；第4/9/12轮补读条目哈希和明确范围。
- runtime_before.json：本轮开工81个neurons目录非缓存文件SHA256；静态检查在结束时重新枚举并比对，路径/数量/内容完全一致。前一轮未提交游戏改动仍保留，Git状态里的旧变更不代表本规划轮修改。

复现：使用本机bundled Python运行 tools/build_planning_forms.py、tools/validate_planning_forms.py；bundled Node设置NEURONS_NODE_MODULES后运行tools/check_planning_forms.cjs。当前生成器保留live progress.json，使用history/before_planning_20261015不可变输入；旧build_asset_forms.py会恢复旧结构，不应覆盖新版。

无Git写操作、无额外费用、无采购/生图、无新增游戏运行/导出结论。测试浏览器均已关闭，没有本轮常驻工程写入进程。交付后停止，等待下一轮制作指令。
