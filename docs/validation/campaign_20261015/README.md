# 新批次验证 2026-10-15

Godot 4.7.2.stable.official.ed1daf0bf / NVIDIA RTX4060 Laptop / OpenGL3.3 Compatibility。

- 规则：71项，0失败；布局：158项，0失败；新真实GPU场景：70项，0失败。结构化细项见`result.json`。
- `01_title.png`：真实标题界面；`02_search.png`：主角实际到点搜寻；`03_replacement_b.png`：同一玩法状态切到B图集与家具映射；`04_hospital_lobby.png`：经过第一关钥匙/拾取/开门后的医院入口；`05_hospital_exit_boundary.png`：经过医院跨房搜寻到楼梯开发边界；`06_drawer_a.png`/`07_drawer_b.png`：真实到点开屉后，同一动作中切换人物/家具表现且手锚和逻辑不变。
- 使用真实窗口和渲染设备截图。UI建立档案、设置、技能提交走相同处理器；长时搜寻/跨房以0.05秒小步驱动同一`advance_world`加速，不是逐秒人工游玩。截图证明所示帧；时序与持久结算由断言补证，没有全流程录屏。
- 默认姓名与正式档案使用相同编号再补检查，当时65/0；补真实走近开屉/活动中替换4项及非循环准备/收势1项，最终70/0。
- 正式美术/配音尚未到齐。角色A/B均明确程序占位；家具使用此前分层候选。没有新生图或付费服务。

## 修复记录

1. 第一轮51通过/9失败：卧室用通用门点，恰好落在床的碰撞内。卧室/病房改回原`Layout.DOOR`，不改门连接；同时修进入第二关后的独立实际尝试索引。
2. 第二轮57通过/4失败：内存快照中的规则字典/数组与运行对象共享，推进后快照被污染。保存与恢复均深复制，增加快照不随未来运行改变的断言。
3. 修复后62/0；补标题设置真实控件/音量应用后64/0。故意破坏测试主存档，仅在忽略的`tmp/campaign_saves_*`内；上一有效备份恢复通过。
4. 导入与GPU启动有本环境系统级诊断：Wacom配置不可读、user://着色缓存目录不可写、系统证书库不可读。它们未造成脚本错误或上述检查失败；不宣称stderr全空。编辑器缓存/设置也受沙箱路径限制。所有测试存档/日志显式写入仓库tmp，不覆盖用户正式档案。

## 导出

新增`neurons/export_presets.cfg`，运行目录外输出`exports/`（忽略，不提交）。首轮缺输出目录导致失败，建目录后PCK打包成功；最终重新打包14,778,272字节并用引擎无界面载包启动标题，无脚本错误（不是目标EXE运行）。Windows EXE失败明确报告缺`4.7.2.stable/windows_debug_x86_64.exe`和release模板；没有把PCK成功当作EXE成功，未下载额外包。

复现（Godot路径由各电脑确定）：

```text
<godot> --headless --editor --path neurons --import --quit
<godot> --headless --path neurons --script res://tests/test_rules.gd
<godot> --headless --path neurons --script res://tests/test_layout.gd
<godot> --path neurons -- --campaign-check --save-root=res://../tmp/campaign_saves_local
<godot> --headless --path neurons --export-pack "Windows Desktop" ../exports/NEURONS.pck
```

完整第三至六关、自然人物事件/并发分支、正式开场教程、完整技能树、成长/掌控/结局/重开和导出目标机验收均待实现；当前存档不声称可迁移到尚不存在的后续schema。准确范围见`docs/FEATURE_COVERAGE.md`。
