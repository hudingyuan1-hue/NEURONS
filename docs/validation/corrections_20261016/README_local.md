# 本机空间纠偏与实际运行（main/730bd37后）

本批二层剩余五房已接同一布局/事件体系；下文两房版为历史。最新证据：

|范围|结果/目录|实际边界|
|---|---|---|
|七房与规则组合|upper_all_visual_last/asylum-space 255/0|七门/44点（楼梯既有1点另计）、原6秒与一次奖励、真实报告隔离/推床/护士/遗体/病友、录音纸件/折盒抽手、旧章/两房版JSON和实际返床、四档缩放。演员/资源/纸件/调度起始夹具明确，非全NPC排列|
|几何|upper_all_last/test_institution_layout 3767/0、1212路径|headless，分段足迹、接触对及桌上物件/双方触及；非完整床体扫掠|
|历史夹具回归|upper_all_final：145/0、70/0、58/0、85/0|均geometry1夹具；不冒充新房验证|
|自然新档|upper_all_natural 7136帧；upper_all_natural_last 11651帧，均3/0|无seed/玩法字段夹具，普通_process到L4真实持钥出口，固定30FPS，非人工通玩/结局|
|连续实机|upper_all_record_last/workshop_withdraw_retry_silent.mp4，281帧/30FPS=9.37秒，5/0|真实Enter结束提示、CRT鼠标WITHDRAW付2N、夹空、6秒自主重搜+1N；50N/解锁技能/单督导为明确初始夹具。无声未听验|
|Windows最终|upper_all_export_delivery 56/0；normal_exe_startup.json passed=true|exports/upper_all_20261016；最终浴室排序修复后重导出，包内五房原索引/布局/版本与主入口/菜单/保存，独立EXE仅正常窗口/OS关闭退出0；非EXE通玩|

实际查看：group/bath/work/double原生图、成品桌上/分开站位、最终录像半秒抽样03/06、浴室14/15遮挡前后。发现并修材料架误画衣帽架、物件锚误作走位、柜前/手点/可见抽屉面不一致、浴室地台盖住地面遗体及装板前误画床；显示只读原事件，不创建回执。地台现在先画，屏只遮对应淋浴，覆盖/装板/移出分开。

失败保留upper_all_r1–r4：角落原件因距离/停止展示错时，按原2m改柜侧视线站位；JSON浮点/整型比较误报，实际两房版本未被强迁；桌上物件不该作为人物可走锚，分开后保留真实支撑与触及检查。upper_all_record第一次正式对白未结束就开菜单未生效，真的夹伤，修真实Enter驱动重录才通过，未延长规则。详见HANDOFF顶部。

两表原子项/进度保留，DOM50/0；浏览器离线/真实下载/异机未验。B3五项未知、L4/隐藏空间、B5/B6/E2/E3/B7和完整床体/人工正式音画仍待。最终哈希在upper_all_export_delivery/build_manifest.json。

---

## 前批两房记录（历史）

本次继续二层走廊/活动室，复用当前处理器与原动作/对白规则；新版本只用于新进入L3，旧本章几何继续保留。最新结果覆盖前批相应范围，前批证据不删除：

|范围|本次结果/目录|边界|
|---|---|---|
|两房几何|upper_combinations_final/test_institution_layout：3280/0，1110路径|headless；新增命名核单站位/桌面接触对，身体半径不缩|
|两房实际|upper_combinations_final/asylum-space：104/0|GPU；七门与新旧邻房往返、12点原6秒结算；伤口4秒实目击→报告签联→普通护工带离→原8秒隔离；护士原件跨层写表；真实推床等待/清路/腕带原地、可选核单签联送达；遗体单体移出停放回房清理、角落病友原件目击/带离；旧档/真实返床、四档缩放。明确初始演员/继承纸件/调度边界夹具，无完成收据注入|
|历史几何回归|upper_space_r6：ward145/0、isolation70/0、nurse-duty51/0、trace58/0、combinations85/0|原夹具坐标明确geometry1；不是新房全人群验证|
|下层受影响|upper_space_final：institution-space140/0、events44/0|原实际门、搜寻、医疗/原物/抓握/窗口，不增加规则|
|自然新档|upper_space_final/natural-hospital：3/0|8697普通_process帧，未改seed/玩法字段，L1→L2→L3→L4真实持钥出口；固定30FPS自动观察，开发边界非结局，非人工通玩|
|连续实机|upper_record_last：6/0；corridor_bed_pause_door_silent.mp4|436帧/30FPS=14.53秒，MovieMaker原AVI在tmp/corrections_local；真实Space、CRT鼠标扣5N、平移后门面点击。无声副本/未听验；初始演员与CONTROL/50N夹具明确|

实际查看新走廊/活动室/护士台、最远点缩放图及录像抽样，发现并修复转运患者站立穿床：两代renderer均在随床marker画临时卧姿/真实hand_grab手势，不再另画站立副本。相邻旧安静室仍旧尺度，跨门比例突变是待迁移问题；完整床扫掠/正式人物与前景美术未验收，不能拿此批路径通过代替。

保留失败：upper_space_r2真实伤口时机不够，调整站位未延长原4秒；r3局部窗接近/宽通道终点挡住；r5旧夹具错用新一层坐标和误等不存在done状态（未完成护士旧批仅停止自有进程，r6完整重跑）；upper_space_final最初返床夹具未关development boundary；upper_combinations_last核单护士离桌0.6946m超过原0.65m，且驱动未防空数组中止。最后把护士锚从[1.85,2.1]移到[1.85,2.0]，保留8秒限时，补桌面接触对，原核单/写联/签发/退还/真实送达均104/0中通过。

本次Windows最新结果在upper_export_final：PCK51/0（包内两房配置/原元数据/版本范围也检查），独立release EXE正常窗口与OS关闭退出0、stderr空；导出在最终核单锚/卧姿修正后重做。二进制exports/upper_space_20261016/，源码/资源/表单/证据哈希见同目录build_manifest.json。前批local_export_last包不覆盖本次；两份HTML仍50/0程序契约，浏览器/异机未验。自有测试/导出进程已结束。

---

## 前批本机记录（保留）

接收完整同步后实施；同一Godot纯2D工程，未Git写、未生图/采购/增加音频订单，未改用户候选母图/桌面NEW/人工填写。最新入口为HANDOFF顶部；旧失败与当时证据保留。

|范围|当前结果/证据目录|实际方法与限制|
|---|---|---|
|连续线段/版本|local_space_r1/test_navigation_segments 15/0|headless，擦角/共线/端点/旧章重试版本|
|卧室几何|local_space_r1/test_bedroom_layout 1700/0；local_exact/before.json原14失败|实际路径/增量/逐帧重算；不等于实玩|
|机构几何|local_space_r1/test_institution_layout 2442/0、782路径；最终观察窗站位后重跑同值，geometry_last.json|headless真实布局/连续移动/宽通道/接触双人|
|卧室交互|local_space_r2/metric-bedroom 182/0|Godot GPU，11点、移物、点击/缩放、替换与旧档|
|机构空间|local_window_final/institution-space 140/0|实际5门往返/开门/门槛、32点搜寻、JSON/付费中断、同层异化、上下楼/返床及旧档|
|医疗与原物/带离/窗|local_window_final/institution-events 44/0|实际针刺/2秒样本/独立处方；两种源几何的真实装袋/新L3接袋；旧L2半取照实际重试不换几何；真实抓握跨门；CONTROL实际鼠标/窗外侧开关与内侧拒绝。明确起始角色/持钥匙/已接报告夹具；不是自然全NPC排列|
|隐藏/钥匙|local_regression_r1/hidden-campaign 57/0、key-discovery 64/0|父亲抓握到真实E1出口/尾声/死亡；v2真实完成/取消/付费/去重等有限条件|
|声音时钟|local_events_r1/dialogue-playback 23/0|真实时间与播放游标；内存静音测试流，无听验。固定步长r1原失败不能解释为音频实现失败|
|B4末次修订|local_contention_r2/cortex-events 89/0、cortex-upper 70/0、cortex-sequence 16/0|原页退位、朝向/遮挡、回放来源/时序、两面罩、转身撤手/空夹/真实重搜；有限夹具|
|新自然软锁回放|local_contention_final/cortex-navigation 29/0|保留两个此前未经修改的真实新档失败snapshot，再实际恢复；影像室目标占点/纸件NPC绕观察者，不移动身体凑测试|
|卧床输入/家庭|local_navigation_r1/rest-input 10/0、family-sequence 54/0|修旧视口点击/常量床坐标的测试，规则不变；实际卧床鼠标/菜单/存档/GUT|
|自然新档普通流程|local_natural_final/natural-hospital 3/0|9475帧；建档/跳教程/原对白继续真实鼠标，普通_process、自然RNG，无玩法字段夹具，L1→L2→L3→L4实际唯一钥匙/已越出口。30FPS固定步长自动观察，不是人工速度体验、全分支或结局|
|当前Windows|local_export_last_r2 48/0；local_export_last/normal_exe_startup.json true|最新PCK动态JSON包括room_spaces/institution_spaces；匹配引擎+外部驱动，Dummy音频；独立release EXE仅证明正常窗口/OS关闭退出0，非EXE全程/听验|

## 画面/录像实际查看

local_record_final/clinic_continuous_silent.mp4：原始连续MovieMaker 266帧/30FPS=8.87秒，完整诊室针刺→CRT膝击→样本中断→处方交接，4/0。起始已有医生/助手与50N/解锁KNEE为明确夹具，之后普通_process及真实Enter/菜单鼠标。原AVI在忽略目录tmp/corrections_local/institution_continuous_final.avi，压缩副本去音轨且明确无声；没有听验。实际查看viewed_01–08的1秒视频抽样（不是逐帧）以及相关运行截图。

另实际查看机构接待/诊室截图及观察窗修改前local_window_r4、修改后local_window_final/metric_actual_window_mouse.png，确认窗已贴门墙面；角色、家具、标签/动作仍是占位，不称美术认可。前景透明/低细节/多人显示重叠仍需正式素材和人工体验校准。

## 原失败与修正依据

- local_space_r1两个GUI曾因campaign_view门点击多传参数而编译失败/超时；先修编译再复跑，不能拿几何通过代替场景。
- local_space_r2/institution-space发现SKIN成功却未清穿门动作；修等待阶段取消后140/0。
- local_events_r1/v1来源入库钩子在目标布局前检查旧同名房，调整时序后原物完整连续；无补造收据/物品。
- 两个新自然观察分别在影像室NPC占路、记忆室NPC接近原页被角色挡住停滞，原snapshot位于local_more/natural-hospital及local_navigation_r1/natural-hospital。新增圆形动态占点绕行和合法接触范围接近；不缩身体/不穿人/不瞬移。
- B4测试错用clamp_handle_started事件ID（实际稳定ID为clamp_handle），JSON源浮点文本比较和初始补查自行转身；修测试的输入/比较/隔离，保留背向/遮挡等真实反例，不改原触发规则。
- 观察窗首轮测试误点了另一个房间的同ID标记、未等CONTROL反馈输入盾结束；修驱动后通过。实际看图再发现窗框悬空，定向修贴墙/投影/手点/门点击优先级，44/0。
- local_contention_final自然跑已在snapshot中实际越过L4出口，但旧观察驱动只识别旧L2开发边界而报帧限；保留原失败，修识别真实cortex_exit_crossed后另开自然新档跑到同一开发边界3/0，不将开发边界改成结局。
- 最终包第一次非固定步长驱动教程后停滞，未写完整result；停止仅本次驱动并保留local_export_last的不完整内容。固定30FPS/Dummy重跑local_export_last_r2才完成48/0；独立EXE启动退出另测。

HTML独立分享与浏览器限制见../offline_forms_20261016/README.md。B3五项未知具体内容、上层剩余空间/全组合、B5/B6/E2/E3/B7和正式音画/人工完整试玩仍未完成。
