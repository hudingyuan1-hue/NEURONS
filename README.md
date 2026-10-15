# NEURONS — 纯2D自主行动与神经干预

工程入口`neurons/project.godot`，Godot4.7.2 / GL Compatibility；默认场景`scenes/front_end.tscn`。当前批次可从标题建档，经第一关自主找钥匙/拿取/开门进入医院，并进行五室跨房搜寻到楼梯开发边界。完整游戏仍在开发，全部未完成范围见`docs/FEATURE_COVERAGE.md`。

## 制作与接手入口

- **当前转交另一台Codex先做只读接手确认。** 可直接发送的任务提示词：`docs/NEXT_CODEX_PROMPT.md`。用户确认开工后按既定B1推进，无须重新规划。全案顺序见`docs/PRODUCTION_PLAN.md`。
- 早期音频17个WAV已收到，尚未试听/导入：`docs/audio/EARLY_AUDIO_INTAKE.md`及JSON记录格式、时长、哈希和稳定ID。原件在`DOCX/早期音乐素材/音频/`，处理副本与正式发布记录另管。
- 两份全游戏需求表及首批制作单：`deliverables/NEURONS_2D_资产需求_20261015/`。描述、拆层、使用范围和验收详细；提示词简短。原表/稳定ID保留，五选一停用。
- 用户负责主要美术，同伴负责配乐/核心氛围音乐；Codex负责全部UI、通用图标动效/Shader、零碎音效合成加工复用及处理导入测试。配音只按已有约定。HTML默认人工交付包，其余折叠；保存/导出`data/progress.json`随仓库同步，Git操作由用户完成。
- 当前交接`docs/HANDOFF.md`，功能覆盖`docs/FEATURE_COVERAGE.md`，来源`docs/SOURCES.md`，美术参数`docs/ART_SPEC.md`。不每轮重新读取所有原稿。

## 游玩与真实范围

F5运行：NEW GAME输入姓名，固定入侵者编号；已有档案再次确认后覆盖。CONTINUE恢复已保存状态。世界中主角自主移动和搜寻，玩家不能常驻WASD直接控制。左键身体（Tab为测试快捷）开CRT，提交SKIN后关屏/恢复实际反应；空格暂停。滚轮0.8/1/1.15/1.3，R复位。下栏保存/读取、音量与反馈设置可用。

新档5N/3C只发一次。取消搜寻消耗已占次数且不发奖励；钥匙固定至实际新尝试，拿取完成才改归属。门口真实动作后切场，医院0+6+8+7+11点共32，抽12点。搜寻、物件位置、暂停/剩余时间与RNG均随存档；损坏主档可恢复上一有效备份。休息真实完成才结算，冷却保留。

人物事件目前仍在隔离场景验证，没有接入正式自然概率调度；完整开场/教程与后续关卡/分支尚未完成。角色A/B为程序占位，家具为已有候选；未将一条探索路线称作全游戏。被否决的小怪物v001保留原图但停止运行展示。

## 替换资产

`neurons/data/presentation.json`映射CHR_MAIN与ENV_BEDSIDE。主角基础图集、各动作独立sheet支持规格检查；同画布/脚锚/方向，实际手锚按接触对象测量。家具主体/抽屉/前沿独立，可替换纹理和显示配置而不重写规则。声音映射在`data/audio_bindings.json`，包含稳定ID、stream路径、通道、循环、授权；正式声音尚未收到。

## 检查

```text
<godot> --headless --editor --path neurons --import --quit
<godot> --headless --path neurons --script res://tests/test_rules.gd
<godot> --headless --path neurons --script res://tests/test_layout.gd
<godot> --path neurons -- --campaign-check --save-root=res://../tmp/campaign_saves_local
```

规则71/0、布局158/0、新GPU70/0；浏览器表单结果和真实运行帧见`docs/validation/`本批目录。新主菜单保留`--visual-check`/`--bedside-check`到旧隔离场景，旧结果不等于新关卡/分支通过。

Windows导出预设已建；PCK构建成功，EXE缺本机4.7.2模板，尚无已验收发布包。资源/源码用相对路径，无D盘运行依赖。保留.uid与.import，排除.godot/、tmp/、exports、密钥；用户通过GitHub Desktop人工提交、推送与拉取。
