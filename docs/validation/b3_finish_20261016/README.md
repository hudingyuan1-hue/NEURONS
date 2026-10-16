# B3 无阻塞实施项收口 · 2026-10-16

从本机main/ecbed12干净工作区接续，与本地origin/main同引用；未Fetch、不声称远端实时最新，没有Git写操作。继续同一Godot工程，桌面NEW、正式音画、人工填写未动。原两层/人物/签联隔离成果复用，本轮未重新规划全案。

## 实际完成

- 32项实物观察（保留原23项，新增9项）：已有离院单副本独立翻页、病友实际收到的陈述纸、主任原记录夹签字附页、真正完成贴标的成品。屏幕/白板只检查原有表面，本人伤照位没有实际摄影就无照片。阅读不等于认同、照读、签名或身份确认。
- 原医院转运工在原照片/鞋的真实位置接触装入同一容器，携袋退出。正常L2钥匙门的进入钩子只接受有效源回执、实际退出与一致物权；L3原登记护士实走接袋、携袋归台、放下。袋号与袋内原物分次读；前关真正见过原照片才触发P659–660原句。不从旧gone标记或未知编号造运输史。
- 长期原物在L2真实重试后保留同趟演员位置/装袋中段/源回执；完成不重演，部分可继续并正常跨关。先离开L2时已启动的原运输继续按L3世界时钟真实走到源出口，再接到L3；暂停/JSON保留，L3同名房间与主角不能隔空挡路、目击、受损或听见旧医院对白。源level/attempt与实际发生level/attempt分记；普通医疗事件仍按原重试重置。
- 单人病房门观察窗为独立开闭状态，只有门外侧可操作；真实接近、准备/接触/收手，接触才换状态，暂停/存读档保留。内侧不开放操作，开窗不增加搜寻、奖励、读心信息或门的通行条件。0.2/0.2/0.2秒为可替换表现参数，非新增原文数值。
- 修复JSON数字别名导致的休息计数停在旧attempt、同一护士对同一源纸重复转抄。旧计数取最高不相加；已写历史保留并标共同源，不追加第三份。旧离院纸仅有真实原记录、page标记和实际护士时补缺失holder；已有holder含空串不覆盖，不新增纸/事实/知识。
- 动作/接触与结算继续使用现有世界时钟、稳定ID、独立资源映射。新增物件和观察窗为代码占位，复用现有声音，没有新增正式美术、配音或音效制作订单。

## 本机实际验证

Godot4.7.2.stable.official.ed1daf0bf、OpenGL Compatibility/RTX4060。下列为有明确初始条件的实际GPU自动驱动；部分使用小步游戏时间加速，不是人工正常速度全流程或所有随机排列。正常CRT/world鼠标路径及连续_process记录单列，不用断言数替代体验验收。

|证据|通过/失败|范围|
|---|---|---|
|[ward-evidence-r1](ward-evidence-r1/result.json)|38/0|实际递纸、签字附页、有限作业成品|
|[packing-r4](packing-r4/result.json)|44/0|原转运工实际装照片/鞋、携袋退出|
|[relic-retry-r4](relic-retry-r4/result.json)|27/0|ready及两类接触中段真实重试、JSON、跨关入库|
|[intake-r4](intake-r4/result.json)|41/0|护士实际接袋/携带/放下、分次读袋号与原物|
|[intake-chain-r4](intake-chain-r4/result.json)|38/0|L2装原物→正常钥匙门→L3接收→CRT鼠标读袋|
|[details-final](details-final/result.json)|44/0|独立读纸、旧页持有人保守兼容、实际鼠标与中断|
|[window-r2](window-r2/result.json)|43/0|观察窗内外侧、接触节点、暂停/JSON、实际CRT鼠标|
|[observations-r1](observations-r1/result.json)|58/0|原23项观察及新增目标结构回归|
|[nurse-duty-r1](nurse-duty-r1/result.json)|51/0|同一护士、实际写表/跨层转抄|
|[combinations-final](combinations-final/result.json)|85/0|三次真实跨层返床、旧数字键及转抄去重、隔离并发|
|[first-floor-final](first-floor-final/result.json)|38/0|原一层人物事件回归|
|[registration-final](registration-final/result.json)|45/0|原登记答复/追问/实写/实读回归|
|[hospital-r4](hospital-r4/result.json)|95/0|原医院事件回归|
|[campaign-regression](campaign-regression/result.json)|70/0|原基础流程/规则集成回归|
|[exploration-regression](exploration-regression/result.json)|145/0|两层13室/45候选14目标/导航/暂停/JSON|
|[ward-regression](ward-regression/result.json)|145/0|二层人物事件回归|
|[records-regression](records-regression/result.json)|59/0|档案/报告/实际交接/抓握|
|[trace-regression-r2](trace-regression-r2/result.json)|58/0|原遗物/实体锚点/归属|
|[isolation-regression](isolation-regression/result.json)|70/0|真实隔离门/8游戏秒/中断|
|[chain-regression](chain-regression/result.json)|11/0|推床现场→签联→实际隔离整链|
|[continued-r2](continued-r2/result.json)|2/0|既有真实医院存档Continue、普通_process至L3持钥出口|
|[early-transfer-final](early-transfer-final/result.json)|44/0|先离开医院后原运输继续、暂停/JSON及实际接袋|
|[registration-mouse-regression](registration-mouse-regression/result.json)|21/0|原登记真实鼠标链|
|[recording-r2](recording-r2/result.json)|4/0|普通_process连续CRT干预→实际读纸→恢复自主搜寻|
|[export_pack](export_pack/result.json)|43/0|匹配引擎加载本轮PCK、资源与正式UI|

[独立Windows release EXE](export_exe/normal_exe_startup.json)正常入口创建窗口、OS关闭、退出0、stderr空；没有用外部脚本冒充EXE全流程。导出为`exports/b3_finish_20261016/NEURONS.exe`及同目录PCK（本地忽略，不提交），使用本机已有匹配模板。资源包包含新增动态JSON，排除测试脚本、DOCX与生产中间件。正式导出全流程及另一机仍待验。

另有[真实存档继续](continued-r2/result.json)：从既有观察所得医院入口快照，通过标题Continue保留原RNG/演员/资源/路线，普通_process和实际对白继续至L3持钥出口。正常抽样未必出现登记护士，原袋可正确等待原护士到场；不强制刷新NPC。具体运输与接收状态原样写入结果，不把到达出口说成每个支线已发生。

### 可视证据

[16.07秒连续无声录像](b3_evidence_sequence.mp4)，482帧/30fps，普通_process真实CRT付费掌控→接近/读原纸→掌控结束→恢复自主搜寻完成；仅初始团体室/演员/50N/解锁技能/两个目标是声明夹具，后续不手动推进世界或补完成事实。实际查看准备/接触与恢复自主截图、8秒抽样画面，未声称全片观看或听验。

- [L2原照片接触](intake-chain-r4/01_real_l2_photo_contact.png)、[L3同袋入库后实际鼠标阅读](intake-chain-r4/02_l3_real_stored_bag_and_reading.png)。
- 观察窗和旧纸兼容检查截图见对应测试目录；root实际查看的画面在`build_manifest.json.visual_inspection`逐项记录。
- 当前角色/门/纸件为标注占位；部分后排世界标签拥挤、浅色字与亮底对比不足，未标正式UI/美术验收。观察窗新标记使用深色底牌，后续正式房图需按门位置/遮挡统一接入。

### 失败与修复记录

旧失败结果保留，不删除也不计为通过：combinations-r1/r2暴露真实数字键与转抄源问题；details-r1/recording初始站位占用家具膨胀碰撞区，改驱动合法站位，未放宽碰撞；hospital-regression的主角挡住取鞋路径，改驱动真实走开；packing-r1漏过短接触观察窗口，intake-r1夹具残留上个袋状态且断言不安全，均修测试条件。combinations-r3/trace-regression旧截图等待在遮挡窗口下不返回，改强制绘制真实GPU画面后通过；不是补造结果。window-final的第二次点击落在原正式对白暂停中，改驱动先真实Enter继续，再点击，运行规则不变。continued-final虽到L3出口，但原物carry_exit冻结，root检查快照发现后补离场运输续接，再测continued-r2；前一包不作为最终源码通过。early-transfer-r1进一步发现原导诊护士挡住最后网格步，补实际动态绕路和精确门口末段，未降低原人物间距；final44/0。其他失败/中止的日志及部分结果留原目录，最终选择见上表和构建清单。

## 依据、边界与下一步

[源核查](source_check.md)记录12份DOCX、18个第五阶段ZIP/122份说明哈希；135次原对白引用逐字匹配，原133次不变，新增仅照片辨认两句；45搜寻点/21身份不变。重试原物按S4:T27R3，观察窗按S1:P103及计划EV_L3_WARD；登记/转运细动作、联系时长和接近站位是最小技术安排，不改身份或因果。

`asylum_observations.json.deferred`已清空，旧“8项功能待接”由真实入口和5项`content_pending`取代：编号屏字形、袋号、本人真实摄影及照片、实际签署原件/来源、白板具体原文。不能称拍照/签署剧情或这些文字内容已经完成；缺源不擅自指定摄影人/签署者，也不阻塞其余已知功能。

B3有依据且无阻塞的范围已实施并完成本节点验证；全部人群路径/技能/持握顺序、无限期长期尝试、人工正常速度全玩、正式音画和双机发布尚未全部验收。L3持钥出口仍是明确L4开发边界，不是结局。下一项依原计划B4：脑皮层/白质11室、62候选16目标、补查、人物事件和唯一钥匙，不重做B3、不把骨架当整款完成。
