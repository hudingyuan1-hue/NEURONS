# B3精神病院续作 · 2026-10-16

沿main/cbdac8f及上轮B2未提交成果继续，无Git写操作；桌面NEW、正式音画、人工填写与未知DOCX新增目录未动。Godot4.7.2.stable.official.ed1daf0bf，Windows/OpenGL Compatibility/RTX4060，固定游戏30FPS，Dummy音频。固定夹具/GPU与无界面几何分别标记，不代替人工全流程、正式音画或主观听验。

## 当前最终结果

|目录|通过/失败|真实范围|
|---|---|---|
|layout_unit.json|45点/0问题|引擎网格与逐段碰撞，无界面|
|exploration-r2|145/0|两层13室、45抽14、6秒搜寻、唯一钥匙、L2真实楼梯进入L3、下楼返床、半程/跨层JSON；无NPC有限夹具|
|first-floor-r4|38/0|核腕/拒绝后真实抓取、诊断/独立医嘱、配药/举杯/吞服/拒服/假记录；低SP优先、旧档未来材料污染修复|
|trace-r2|58/0|独立尸体搬运清理、读/取分账、原patient真实跨层、两凭条及角落带离、JSON|
|records-r2|59/0|8页真实读、档案员制止收档/写报留桌、保安实收单/5HP与10SP/门口≤6秒释放、真实上楼|
|ward-r4|145/0|夹手、实际缩手/技能费用、有限纸料/成品、录音启停/删除/递纸/提问、推床真实门口/阻挡/腕带归属、现场护士长核号/写联/独立签联/返单与缺席/晚到/中途离场、术后暴露告密签联带离、内档搜寻到护工抓握与站侧释放/受阻超时|
|isolation-r3|70/0|明确已签联中段输入后真实取单/抓取/带入/闭门8秒/室内行动/开门，角色与NPC、暂停/JSON/JOY/死亡；已开始离房路线遇关门重检|
|ui-r3|15/0|真实CRT掌控/家具点击翻看、新命令取消、散落物左读/Shift取、持有标记复读；初始解锁/50N夹具，随后正常_process|
|regression-hospital|89/0|原医院场景接触/动作/处方/服药/记录/抓握、CRT鼠标/JSON回归|
|regression-campaign|70/0|原探索/保存/替换，旧医院开发边界断言改为实际L3进入奖励，未删旧验证|
|recording-r2|3/0|明确初始作业室/两目标/50N/已解锁WITHDRAW后，正常_process/实际Enter与CRT缩手→夹手未命中→恢复自主搜寻完成；不手动推进世界tick|
|continued-r2|2/0|真实旧医院档案原RNG/演员/位置/资源，标题Continue和对白继续，正常_process到L3持钥出口；非新L1全程|
|registration-r2|45/0|原初次答复后自主追问、实际书写/阅读分时、打断/已写未读/JSON/低SP与持钥优先；无须CONTROL|
|observations-r2|58/0|23观察配置：接近/准备/翻看/收手、14null/条件原句/袋实际结果、诊断落笔、覆盖标签、双床擦名、暂停/JSON、真实CRT/家具鼠标与命令取消|
|nurse-duty-r4|51/0|同一药房组共享剩余检查、原门口落地/药师先清门/护士真实上楼，吞服目击后实写、拒服/历史源精确visit、读核写夹回/公共读表，泛known不代同源证据|
|chains-r2|11/0|无预写报告夹具；推床真实现场核号/写签联/原单返还/送达→隔离接单/清场/闭门8秒/开门，原身份/JSON/无重复|
|registration-mouse-r2|21/0|实际CRT CONTROL与登记台/护士身体点击→路径接触/写/读，地面命令取消与实际Enter消费反馈，再读原纸，无新增费用|
|export_pack_r2|42/0|同版本引擎加载最终PCK，18个动态JSON/15声音流/图集、实际标题建档开场/教程/冰柜/保存|
|export_exe_r2|退出0|实际release EXE正常入口创建窗口、OS关闭成功，stderr空；不是EXE全流程|

最终所列过程stderr均空，最终无界面editor import/Windows export返回0。各result.json保留每项条件与失败列表，数字只表示对应有限范围。

## 连续路线与实际画面

- `continued-r2/`从上轮`continue_20261016/complete/natural-hospital/hospital_entry_snapshot.json`按实际checksummed Store写入独立测试目录，复制源哈希/起始状态记在结果。真实点CONTINUE后未调玩法数据，保留抽样/RNG/演员/位置/资源；5155个process帧、34次实际对白继续，实际L2拿钥匙/楼梯进入L3，L3再次搜寻拿钥匙/真实到楼梯出口。最终HP100/SP100/N31/C7，尝试与周目均未增加。这是旧档续玩与有限随机路线，不是人工新档全关卡全分支。
- 新档随机观察保留：natural-r1实际选隐藏路线；natural-r3真实休息/重开；natural-r4第一关实际死亡。各3/0只检查该端点，不声称它们通到B3；natural-r2因协作文件暂未完整保存造成解析失败，保留原证据而不作玩法结论。
- `asylum_sequence_r2.mp4`为最终源码真实Godot MovieMaker378帧/30fps/12.6秒/1280×720，无音轨；不是静态拼图。原AVI留忽略tmp。已查看记录三截图、隔离室内搜寻、推床护士接触、角落释放、真实旧档终点、导出冰柜、护士实际夹回值班表、登记鼠标返读及新录屏6秒抽样；没有声称观看全片或主观听音。
- 画面继续使用有身份/方向/阶段的占位角色与家具，复用早期房间底图；它不代表医院/精神病院正式风格、母图或美术批准。正式场景、人物、配乐沿原NEW清单交付，无新增人工UI/零碎音效/配音订单。

## 本轮修复和失败保留

exploration-r1：JSON浮点比较、SKIN旧别名被同步覆盖的夹具；first-floor-r1：NPC初置柜内；trace-r1：真实每帧重规划丢AStar转角，另有未结束正式对白即重读的夹具；ward-r1：JSON数字/坐标精度；ward-r2：真实护士长/护工/主角站位重叠，改合法分离接纸站位与动态绕行，不放宽碰撞/6秒上限；records-r1：未解除开发边界冻结的夹具；ui-r1：下一次鼠标前须实际继续身体反馈。失败文件/日志保留，没有降低伤害、放宽规则时间或允许穿墙。

第二批失败保留：nurse-duty-r2与r3均46/3，确认药房整批入场后药师停门与双方抢道；药师真实移至柜台、护士等其清门后才过门，r4为51/0，未松碰撞/瞬移。registration-mouse-r1为18/3，快照显示“刚才怎么回事……”正式身体反馈正常暂停，control_left仍3.633；驱动改用真实Enter消费反馈，r2为21/0，没有删对白或加掌控时长。

最终还修：隔离闭门后已开始的离房动作须重新检查；缺B3段的旧档清当前未来作业状态；新普通医疗/私聊不抢低SP返床；拾取后持有标记可正常再读；推床实际返单/签联，普通护工不重复搬该患者。对应断言已在最终版本实跑。

## 来源与未覆盖

定向复核S1第三关、S3:P614–1059/T18–34、S4搜寻/概率/处置与第五阶段明确补丁；复用既有完整阅读，不重新规划。源文件哈希、原句逐字/45搜寻/资产ID核对见`source_check_r2.json/md`（133原句、135搜寻文本字段、21资产/84子ID，原119前批核对保留为source_check）。未知编号/日期/车次/批次保留null，不以null等于null制造关联；实际结果/已知/机构记载分账。

第二批已补旧牌/束带/家属闭栏/诊断实页/标签/预填表/双床名，登记追问、护士跨层值班及完整推床签联隔离。仍不是全部B3完成：asylum_observations.json明确8项deferred（编号显示/遗物袋照片实际收存/离院副本独立翻页/实际拍伤照/陈述纸独立读/真实签字物件/白板具体文/成品标签独立读）；未知字形/原文缺失不补造，其余事件后续接入。全部人群/持握/十二技能/随机长期组合尚未穷举。L3出口仍是L4开发边界，B4–B7及E2/E3未接。正式声音许可/混音/主观听验、正式美术仍待。

## 复验入口与开发导出

引擎路径每机自行定位；以下以本机同版本为例。各GUI独立存档/验证目录，串行运行，避免覆盖人工档或旧证据。

```text
<godot472> --headless --editor --path neurons --import --quit
<godot472> --path neurons --audio-driver Dummy --fixed-fps 30 --disable-vsync --max-fps 0 -- --asylum-check --save-root=res://../tmp/b3_local/saves --validation-root=res://../docs/validation/b3_local/exploration
```

人物检查参数为`--asylum-events-check`、`--asylum-trace-check`、`--asylum-records-check`、`--asylum-ward-check`、`--asylum-isolation-check`、`--asylum-ui-check`，第二批`--asylum-registration-check`/`--asylum-observation-check`/`--asylum-nurse-duty-check`/`--asylum-chain-check`/`--asylum-registration-mouse-check`，驱动入口见front_end.gd。`--continue-asylum-check`复用已观察旧档，`--asylum-record-check`为连续缩手录屏；特殊fixture和范围各结果明示。

开发导出：`exports/b3_20261016/NEURONS.exe`及同目录`NEURONS.pck`；两者都要保留，不提交Git。匹配engine通过`--main-pack <pck> --script <absolute tools/check_export.gd>`测资源与UI，release EXE不会执行外部自定义脚本，故实际EXE正常入口/OS退出另用`tools/check_windows_startup.ps1`测。构建输入/EXE/PCK哈希见`build_manifest.json`。不是全游戏发布验收。
