# NEURONS — 纯2D自主行动与神经干预

工程入口`neurons/project.godot`，Godot4.7.2 / GL Compatibility；默认`scenes/front_end.tscn`。已接正式开场/建档/独立教程、卧室自主探索与神经干预、医院五室十身份及信息观察、隐藏Street/E1与存读档。已接B3精神病院两层13室探索与主要人物事件，第三关持钥出口仍是L4开发边界；剩余实物观察/组合见功能覆盖。人物与空间主要为标注占位，完整游戏/正式美术声音未验收。

## 制作与接手入口

- **用户已拉取另一台成果并授权沿计划继续B3。** 接手记录与下一条任务见`docs/HANDOFF.md`；`NEXT_CODEX_PROMPT.md`的只读确认是历史轮次，不重复等待。全案顺序见`docs/PRODUCTION_PLAN.md`。
- 早期音频17个WAV已收到，已选择处理副本与离线候选接入15个声音ID，未主观听验：`docs/audio/EARLY_AUDIO_INTAKE.md`及JSON记录格式、时长、哈希和稳定ID。原件在`DOCX/早期音乐素材/音频/`，处理副本与正式发布记录另管。
- 两份全游戏需求表及首批制作单：`deliverables/NEURONS_2D_资产需求_20261015/`。描述、拆层、使用范围和验收详细；提示词简短。原表/稳定ID保留，五选一停用。
- 用户负责主要美术，同伴负责配乐/核心氛围音乐；Codex负责全部UI、通用图标动效/Shader、零碎音效合成加工复用及处理导入测试。配音只按已有约定。HTML默认人工交付包，其余折叠；保存/导出`data/progress.json`随仓库同步，Git操作由用户完成。
- 当前交接`docs/HANDOFF.md`，功能覆盖`docs/FEATURE_COVERAGE.md`，来源`docs/SOURCES.md`，美术参数`docs/ART_SPEC.md`。不每轮重新读取所有原稿。

## 游玩与真实范围

F5运行：NEW GAME输入姓名，固定入侵者编号；已有档案再次确认后覆盖。CONTINUE恢复已保存状态。世界中主角自主移动和搜寻，玩家不能常驻WASD直接控制。左键身体开CRT，右键身体开冰柜；使用已解锁技能，确认解锁或升级时才扣簇，人体预览不施放到世界。新档教程有独立资源并可跳过，之后可重看详解。空格暂停。实际受伤反馈后出现生命/精神面板，下一次行动完成收起；X手动固定或关闭，设置可关闭自动弹出，选择随机器设置保存。滚轮0.8/1/1.15/1.3，R复位。下栏保存/读取、保存并回标题、设置与降低反馈可用；保存失败会留场暂停。

新档5N/3C只发一次。取消搜寻消耗已占次数且不发奖励；钥匙固定至实际新尝试，拿取完成才改归属。门口真实动作后切场，医院0+6+8+7+11点共32，抽12点。搜寻、物件位置、暂停/剩余时间与RNG均随存档；损坏主档可恢复上一有效备份。休息真实完成才结算，冷却保留。

第一关四人物、原句与分支已接；医院治疗/处方/取样/服药与假记录/转运/档案保安及24目标真实翻看已接。角色靠近后才翻看，完成记知识不奖资源；合法掌控可对已完成点/病房床发出翻看指令，打断不补知识。第三关二层45候选抽14、原6秒搜寻/真实上下楼/返床；23项实物观察、登记自主追问/实际写读、同一护士跨层值班转抄；一层核腕医嘱、档案报告保安、二层录音/遗物/作业/推床/告密和签联隔离已接。闭门8秒内可在室内行动。合法掌控可左键查看纸张/遗物，Shift+左键拿取可取散落物；持有标记可复读，读与归属分开。隐藏Street猎手到E1可运行，失败按L1复活。十二人体预览、13种CRT语法与教程局部突出保留。正式怪物造型未批准，五选一停用，后续关卡与完整组合仍待。

## 替换资产

`neurons/data/presentation.json`映射CHR_MAIN与ENV_BEDSIDE。主角基础图集、各动作独立sheet支持规格检查；同画布/脚锚/方向，实际手锚按接触对象测量。家具主体/抽屉/前沿独立，可替换纹理和显示配置而不重写规则。声音映射在`data/audio_bindings.json`，包含稳定ID、stream路径、通道、循环、授权；正式声音尚未收到。

## 检查

```text
<godot> --headless --editor --path neurons --import --quit
<godot> --headless --path neurons --script res://tests/test_rules.gd
<godot> --headless --path neurons --script res://tests/test_layout.gd
<godot> --path neurons -- --campaign-check --save-root=res://../tmp/campaign_saves_local
```

最新B3续作见`docs/validation/b3_20261016/README.md`：探索145/0、一层38/0、遗物58/0、档案59/0、二层145/0、隔离70/0及真实鼠标15/0；真实旧医院存档继续到第三关持钥出口，补观察58/0、登记45/0、护士51/0、签联隔离整链11/0、登记真实鼠标21/0，12.6秒无声CRT缩手连续录像、新Windows导出资源42/0与独立EXE入口关闭。固定夹具/连续路线的范围分别记录，不是全B3验收。上一节点`docs/validation/continue_20261016/README.md`：医院89/0、边界64/0、观察28/0及开场/隐藏分支、本机Windows导出，含8.9秒连续真实CRT录像。历史节点`docs/validation/feedback_20261015/README.md`记录食用/父亲提示/X动效、不利组合及三次自然新档观察；正常速度也自然进入医院；教程21句/逐句原操作32/0、当前Windows包资源30/0与独立EXE入口退出通过，仍非全游戏验收。上一节点`docs/validation/status_20261015/README.md`包含状态面板/设置、家庭演出次序、原句匹配和22.7秒真实输入录像。上一节点`docs/validation/resume_20261015/README.md`：含真实鼠标教程、保存失败/回标题/继续、动物路线持久化、关联回归与19秒无声录像。数字只表示对应范围，不替代人工完整游玩或美术/声音验收。新主菜单保留`--visual-check`/`--bedside-check`到旧隔离场景，旧结果不等于新关卡/分支通过。

Windows4.7.2开发EXE/PCK已构建并分别验证正常启动/OS关闭、导出包资源与界面；尚非全游戏发布包。见本机验证目录及`tools/fetch_windows_templates.py`、`tools/check_windows_startup.ps1`。资源/源码用相对路径，无D盘运行依赖。保留.uid与.import，排除.godot/、tmp/、exports、密钥；用户通过GitHub Desktop人工提交、推送与拉取。
