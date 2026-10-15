# B1接续：食用、父亲反馈与教程 · 2026-10-15至16

沿main/b479f12和既有未提交成果续作；无Git写操作，保留原Word锁文件删除。Godot4.7.2.stable.official.ed1daf0bf，GL Compatibility / RTX4060。未新增正式图像/声音，未生图/采购，桌面NEW表未改。

## 本节点完成

- 食用准备、入口和吞服共用原1.5秒逻辑时序，手与小物为代码占位。完成才消费/收益，幸存且未进入崩塌时选择原三句中一条；不赋予食物额外伤害。DRYMOUTH仍只延迟未完成交接2秒。
- 修复食用使父亲行动/压力停走：父亲正常推进先于同tick吞服，抓住/失神/死亡中断未完成食用。准备音每次合法重试使用持久尝试序号，消费收据不变。
- 父亲思考、低于60被迫跟随与救援原系统提示按真实窗口只播一次；老档缺提示收据时先补提示再续原压力。实时卡仅显示已解锁且当前可尝试的节点，点击只打开CRT选中，不施放/赠技能/免收费。
- 血门局部血污、有限场景色调和软边属于占位表现；没有新增伤害/倒计时，软边不是完整景深Shader。首伤X键帽UI最多3次轻动效，降低反馈时静态，世界暂停不偷跑，JSON读回不重演已见提示。

## 运行范围与结果

|检查|通过/失败|范围|
|---|---|---|
|feedback（本目录）|39/0|食用各节点、DRYMOUTH、父亲压力/抓握、提示旧档迁移、真实鼠标实时卡/CRT成功与抵抗、X动效和JSON|
|home-adverse|32/0|普通双亲调度两种顺序/排队JSON/实际同场才崩塌；已交物保留；猫抓伤与吞服/交付接触边界；食用中断重试/实际新尝试；思考60→59实际CRT提交成功及抵抗跨关闭/存读|
|family / family-sequence|59/0、54/0|全部已有家庭分支、原句备选及演出次序；非全自然概率组合|
|status / rest-input|27/0、10/0|状态设置/X/真实卧床身体点击、暂停、存读、GUT中断|
|animals / search-actions / awareness|26/0、77/0、11/0|动物实际接触、11点动作、认知既有回归|
|b1 / campaign / persistence-ui|25/0、70/0、10/0|真实界面/声音加载和暂停、探索替换、保存返回失败保护|
|neural/neural_rules.json|384/0|十二技能规则回归；非全战斗验收|
|tutorial-input / tutorial|32/0、31/0|真实鼠标逐句读完19句玩家对白，1秒CRT初始等待、灰节点2秒、未读不可施放、解锁/预览/完整退出；角色两句回到正式对白；详解不重插|

教程21句逐字匹配实际人工原稿，见tutorial_original_lines.json；仅P372旧5簇按S4新档3C修订，展示独立demo当前余额，不补资源。现有12阶段编号、实际操作及正式资源隔离保留。左/右键图、目标圈与有限按压已接；目标外暗罩/局部虚化、正式小怪物姿态、其余技能人体预览与CRT多语言表现仍待，不称完整教程演出验收。

教程第一次新驱动在星点按下即断言阶段9，早于原定0.18秒面板展开，造成后续连锁失败；已改为等待真实面板展开，未跳阶段或删除检查。失败日志tutorial_final_*保留tmp，最终tutorial_verified_*均无stderr。

|导出检查|结果|范围|
|---|---|---|
|export_pack|30/0|匹配引擎实际加载当前PCK，新增tutorial_dialogue动态JSON，15声音流、角色/家具映射、建档/冰柜/存档|
|export_pack/normal_exe_startup.json|通过|独立release EXE正常入口创建窗口，OS关闭后退出0，stderr空；非EXE完整游玩|

最终构建：exports/feedback_20261015/NEURONS.exe 与同目录NEURONS.pck，两者一起使用，不提交Git。build_manifest.json记录最终源码/构建哈希。使用已核验4.7.2 Windows模板在便携编辑器缓存中导出，不下载新模板，不依赖D盘。PCK检查是匹配引擎加载真实包，独立EXE另做入口/关闭，两种验证不混称。

## 自然游玩观察

三次均使用真实标题/建档/跳过教程/对白继续按钮，保留普通随机姓名编号/种子、无资源或位置夹具，不调用tick或advance_world：

- natural-home：4倍引擎时间，552帧，7次对白继续，无NPC出现；自主完成3次搜寻后实际拿钥匙、开门进医院。
- natural-second：4倍引擎时间，299帧，6次对白继续，初始黑猫出现；实际搜寻与开门后进医院。
- natural-realtime：正常时间、限60FPS，1044帧，10次对白继续，有NPC；世界实际经过约15.72秒，完成3次搜寻后进入医院。

各目录保存初始及最终完整快照、实际事实/所知/机构记载、资源和阶段观察，result.json均3/0。此观察只验证抽到的三次路线，不证明所有NPC组合、主动干预、正常速度的全部动作可读性、医院后续或完整B1通过。自然终点不是游戏结局。home-adverse包含显式概率/位置/接触时刻夹具，用于复现组合，不称自然概率游玩。

## 可视证据与限制

feedback_sequence.mp4为Godot MovieMaker实际224帧/30fps/7.466667秒，无声；食用/救援段使用固定状态与小步规则驱动，卡片/CRT/X段使用实际输入和进程。截图、录屏抽样帧及自然流程截图已查看，没有声称完整逐帧看完或主观听验。教程录屏tutorial_sequence.mp4为834帧/30fps/27.8秒，无声、真实鼠标完整练习及正式冰柜操作；带固定等待以检查台词不会被自动覆盖。截图及抽样帧已查看。原句逐字匹配见original_lines.json：home_dialogue内79次引用全部匹配实际S3 DOCX，含源文件哈希。

相关最终GUI检查stderr空。第一次受限沙箱运行虽断言通过，但报平板配置/根证书读取和GPU shader缓存权限；保留tmp/feedback_20261015/v1_errors.txt，不当作干净通过。随后用仓库忽略目录的便携引擎缓存，在正常Windows权限下复验消除，无须新服务或费用。日志与独立测试档均在忽略tmp；没有使用正式玩家存档。

## 复验

```text
<godot472> --path neurons -- --feedback-check --save-root=res://../tmp/feedback_local --validation-root=res://../docs/validation/feedback_local
<godot472> --path neurons -- --home-adverse-check --save-root=res://../tmp/adverse_local --validation-root=res://../docs/validation/adverse_local
<godot472> --path neurons --max-fps 60 -- --natural-home-check --save-root=res://../tmp/natural_local --validation-root=res://../docs/validation/natural_local
```

真实窗口检查串行。新测试目录应独立，避免覆盖历史证据。正式美术未验收，音频只验证加载/时钟/播放状态，发布许可和听验仍待核，不扩大人工配音任务。

## 当前断点

本节点食用/父亲反馈/首伤X/教程原句完成并留证；B1尚未整批验收。接续先补其他技能人体预览、CRT原三句/多语言呈现及教程目标外局部突出，再做B1剩余组合验收，按既定B2接完整开场/医院人物/隐藏Street。正式素材和听验不足不阻塞无关功能。人工继续既有NEW表母图、卧室分层底图、主要音乐，无新增订单。
