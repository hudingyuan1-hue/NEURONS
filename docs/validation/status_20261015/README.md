# B1接续：状态显示与首关演出 · 2026-10-15

沿main/b479f12和上一轮未提交成果继续；无Git写操作，原有Word锁文件删除保留。Godot4.7.2.stable.official.ed1daf0bf，GL Compatibility / RTX4060。未增加正式图像或音频资产，未调用生图/付费服务，桌面NEW表单未改。

## 实际完成

- 体验P421/P431–442：独立生命/精神面板只读规则。真实生命/精神损失触发，攻击与反馈对白后显示，下一实际导航/搜寻/食用完成收起；取消不当完成。X可固定/关闭，设置可关自动；模式、待显示状态、已完成动作随schema2保存，偏好在preferences.cfg独立保存。老档的已显示状态兼容为手动固定，未递增schema。
- S3:P99–249：母亲先走近，再关心/挠头/回答/请求休息/实际交付；原赠粥句与入库提示在接触完成后。驱猫等待实际退场，返床后二维卧床变换、世界变暗与剪影、“乖孩子...”先于休息完成。父亲抱猫真实离开后才播放三句反思。动作中断与已交物品规则保留。
- S3:P42–92及P102–201：大黄A/B整组、猫阻挡/受伤/退场、互殴、父母问候与关心、搜寻开场原文备选均配置化。人物分组与节点选择保存，同节点不重播/重抽；后续尝试用原短开场。home_dialogue.json内70次原句引用逐字匹配S3，见original_lines.json；不追加人工配音任务。
- 卧床图使用现有主角占位贴图围绕身体中心变换并附着床面，不修改贴图母版；逻辑位置仍为实际到达的床边站位。身体点击区域跟随画面，左右键菜单/世界暂停/读档/真实GUT打断分别检查。崩塌明确取消旧普通动作阶段。

## 实际检查

|入口|通过/失败|范围|
|---|---|---|
|status（本目录result.json）|27/0|真实按键/鼠标、自然猫接触伤害、暂停、下一动作、手动固定、设置CFG、JSON存读与继续|
|rest-input|10/0|真实卧床身体左右键、剩余休息冻结、JSON读回、实际GUT打断、费用/物权/未通关|
|family-sequence|53/0|原文备选覆盖/配对/不重抽、实际接近与挠头、交付/驱猫/返床/父亲离场次序、干扰时崩塌与实际正常进程复活|
|family / animals|59/0、26/0|现有分支回归；不等于全部自然概率组合|
|search-actions / awareness|77/0、11/0|11点与认知回归|
|b1 / campaign|25/0、70/0|既有界面/声音通道、探索、替换与存档回归|
|persistence-ui / tutorial-input / tutorial|10/0、25/0、30/0|保存失败/返回/继续、真实教程输入与既有教程处理器|
|neural|384/0|规则回归，不等于全战斗验收|
|export_pack|29/0|同版本引擎加载最终PCK，含home_dialogue动态JSON、贴图、15声音流、建档/冰柜/保存；不是独立EXE全流程|
|export_pack/normal_exe_startup.json|通过|实际release EXE正常入口创建窗口与WM_CLOSE正常退出0，stderr空|

相关GUI检查stderr均空。卧床表现修改后重跑rest-input/family-sequence/family/campaign/tutorial-input/status；其余在本轮该修改前通过，后续没有改相应规则。所有测试存档在忽略tmp，不使用正式玩家档。

status_sequence.mp4为Godot MovieMaker实际681帧/30fps/22.7秒，真实注入鼠标/键盘与正常世界推进，含固定动物/目标夹具。rest_sequence.mp4实际89帧/30fps/2.966667秒；母亲前段由固定游戏时钟驱动，卧床菜单/读档/中断段为正常进程和实际输入。两者无声，截图和录屏抽样帧已查看，未声称人工完整游玩/全片观看/听音。

早期状态测试遗漏猫开场/惊猫/退场/觉察对白而超时，修的是驱动继续方式，没有让世界在对白中偷跑；一次隐藏测试窗口初建抢焦点，补窗口就绪/焦点与实际重试。演出检查首版把尚未起步的猫路段当成中途保存、用普通advance_world推进专属崩塌，已修为实际起步和正常进程复活；JSON数值变浮点导致备选索引类型不一致，现读取时转回整数。截图复查发现原返床仍站立，故本轮追加可见卧床与对应点击/中断验证。失败日志留tmp/resume_20261015，不作为通过记录。

## 复验与断点

```text
<godot472> --path neurons -- --status-check --save-root=res://../tmp/status_local --validation-root=res://../docs/validation/status_local
<godot472> --path neurons -- --family-sequence-check --save-root=res://../tmp/family_local --validation-root=res://../docs/validation/family_local
<godot472> --path neurons -- --rest-input-check --save-root=res://../tmp/rest_local --validation-root=res://../docs/validation/rest_local
```

真实鼠标窗口检查串行执行。需要导出时见tools/check_export.gd和tools/check_windows_startup.ps1的范围区别。当前构建exports/status_20261015/NEURONS.exe与同目录NEURONS.pck一起使用（忽略目录，不提交）；build_manifest.json记录代码/构建哈希。这是开发构建，不是完整游戏发布候选。

B1仍需食用味觉/救援系统提示与相应局部反馈、首伤X图标动效，以及自然组合/不利路线整批收尾；完整开场、医院人物、隐藏Street追逐/E1与后关仍按B2–B7。不等待正式素材即可继续，正式美术、配音和音乐耳验/许可未获新批准。
