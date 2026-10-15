# 本机接续验证 · 2026-10-15

接手 main / b479f12，使用 Godot 4.7.2.stable.official.ed1daf0bf / GL Compatibility / NVIDIA RTX4060。只保留用户已有Word锁文件删除，不进行Git写操作。现有教程/认知实现来自另一台电脑，不重复归功于本轮；本轮补真实鼠标链、冰柜预览、读档路线、保存回标题与退出清理。

## 实际结果

|入口|结果|边界|
|---|---|---|
|test_neural.gd|384/0|十二技能/认知/成长等规则；不是全战斗实机|
|test_rules.gd / test_layout.gd|71/0、158/0|原有交互与布局回归|
|tutorial-input|25/0|真实InputEvent鼠标，从建档、教程悬停/暂停/施放/解锁到正式身体左/右键；含正式GUT确认与预览隔离|
|tutorial|30/0|既有逐阶段教程处理器回归，按实际阶段等待，不再依赖暂停偷跑关屏时间|
|persistence-ui|10/0|真实保存回标题/继续按钮；写入失败保留场景与暂停，实际JSON和备份/资源/物权/路线/RNG保持|
|animals|26/0|原22项保留；新增JSON存读后黑猫沿原路线离窗、不重抓伤|
|search-actions / family|77/0、59/0|11点/碰撞/线索与父母分支回归；未代替所有自然概率组合|
|awareness / b1 / campaign|11/0、25/0、70/0|既有认知、UI/声音暂停、跨房/替换/存档回归|
|export_pack/result.json|28/0|同版本引擎加载最终导出PCK，实际JSON、贴图目录、15声音流、建档/教程/冰柜/保存；不是独立EXE全流程|
|export_pack/normal_exe_startup.json|通过|真实release EXE正常入口，创建窗口后向本进程窗口投递WM_CLOSE，经游戏退出流程正常退出0，无stderr；未做EXE全分支游玩|

最终九套GUI回归 stderr 均为空。最终源代码已重新导出并串行复测PCK 28/0与独立EXE正常关闭通过；并行启动两个GPU窗口时曾抢焦点导致鼠标测试未进建档，失败日志留tmp/export_pack_final*，未记为通过。涉及真实鼠标的窗口检查应串行执行。规则/几何使用headless，截图与界面检查使用真实GPU；没有用无界面测试代替视觉。截图已查看，录屏只抽看画面，没有声称人工全片游玩/完整观看或音频听验。音频使用Dummy驱动检查加载、播放状态、通道与暂停，未主观听音。

`tutorial_input.mp4`：Godot MovieMaker实际572帧/30fps，19.066667秒，无声，自动注入真实鼠标事件；部分高级操作使用独立测试档资源。原AVI和失败日志在忽略目录tmp/resume_20261015。该录像早于最后退出清理修正，展示的教程/预览/暂停流程未随后改变；最终截图和回归结果见各同名目录。

## 修复依据与失败记录

- 动态Campaign根Control原为零尺寸，教程锚定到零范围；旧测试直接调用处理器没有暴露。补全范围并让前台非交互底层不吞鼠标。教程自身仍拦截输入，关屏加保护帧。
- 原教程暂停仍推进悬停/预览/关屏时钟；现统一暂停练习UI，正式世界始终冻结。教程错误节点不能花掉必需的练习簇。
- 原冰柜仅红圈；按体验P325–358补检查面板返回/收起、稍延迟捂腹两秒和恢复T姿。四向和星环均为二维绘制；人体仍是可替换占位，非批准造型。
- 重建已保存家具几何时不应清空已保存NPC路径；实际挪家具仍使路线重新计算。没有放宽原22项动物断言。
- 体验P424的保存回标题：保存成功后才切标题，失败留在游戏。保存后停止本帧世界推进。
- 首轮EXE退出0仍有Ogg资源警告，已定位到音频线程异步退役；正常退出先冻世界并停止声音，再留100ms实际清理时间，不推进玩法时钟。最终OS关闭与最终PCK检查无该警告。`--quit-after`强制引擎退出绕过游戏清理，早期失败记录不冒充正常关闭通过。
- release模板拒绝--path、忽略外部--script；因此资源检查明确用同版本引擎--main-pack，不把它写成EXE实操。EXE正常启动/OS关闭另测。

## 运行方法

从仓库根目录，用本机Godot4.7.2：

```text
<godot> --path neurons -- --tutorial-input-check --save-root=res://../tmp/check_saves/input --validation-root=res://../docs/validation/local_input
<godot> --path neurons -- --persistence-ui-check --save-root=res://../tmp/check_saves/persistence --validation-root=res://../docs/validation/local_persistence
<godot> --headless --path neurons --export-release "Windows Desktop" <绝对路径>/NEURONS.exe
<godot> --main-pack <绝对路径>/NEURONS.pck --script <仓库绝对路径>/tools/check_export.gd -- --save-root=<独立测试目录> --validation-root=<结果目录>
```

可重现真实EXE关闭检查：`tools/check_windows_startup.ps1 -Executable <EXE> -ReportDirectory <结果目录> -SaveRoot <独立测试目录>`。它只向已启动测试进程拥有的NEURONS窗口发关闭消息，不操作其他窗口。

模板来自 https://godotengine.org/download/archive/4.7.2-stable/ ，团队工具`tools/fetch_windows_templates.py --destination <模板目录>`只下载Windows x64所需5文件，官方ZIP CRC核验后才写入。实际传输72,299,258字节，未下载1,281,349,702字节全平台ZIP。引擎EXE签名Valid；官方导出模板NotSigned，如实登记，不将其冒充已签名。模板与引擎不提交Git，各机自行获取；SHA256清单见windows_templates.json。

当前开发构建在忽略目录`exports/resume_20261015/NEURONS.exe`与同目录PCK。两者一起保留；不是发布候选或全游戏完成。

B1仍待状态UI自动停留/设置、全部原对白备选与演出、自然组合和不利路线覆盖；隐藏Street、医院人物及后关继续按B2–B7，不因本轮通过而删项。正式美术/音乐/配音未获新批准。
