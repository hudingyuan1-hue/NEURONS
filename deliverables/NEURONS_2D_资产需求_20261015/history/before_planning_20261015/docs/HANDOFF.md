# 当前交接 2026-10-15：全游戏资产初表与第一批正式功能

## 本次最高优先级

用户已替代“仅卧室/等美术确认才开发”的旧限制：继续同一Godot纯2D工程，目标完整功能＋可替换美术/声音，按依赖交付可玩批次。用户制作正式美术，同伴制作声音；程序不等美术，不批量生图/购买服务。本次额外生图0张。旧历史约束已归档至`docs/history/`，不能当当前禁令。

## 接手核对

本机仓库`C:/Users/23623/Documents/GitHub/NEURONS`，分支main；开工时工作区干净，HEAD与本地origin/main均`9d50abe3680ca875af37d455f3ae81ad54ef3cd4`。远程地址`https://github.com/hudingyuan1-hue/NEURONS.git`，未Fetch/Pull或核验实时远端。本轮没有Git写操作。当前变更均未提交，交由用户在GitHub Desktop处理。

## 已完成产物

1. `deliverables/NEURONS_2D_资产需求_20261015/`：两份HTML、完整JSON、同步进度JSON、ID迁移表、原表history、首批制作单。793美术记录/496音频记录，含复用/代码/停用/候选，并非全部新资产必做。全部773/244旧ID保留；3D制作要求转二维，玩家五选一停用。描述详细，提示词保持简短；拆层、动作、范围、验收和工程操作分列。原D盘与旧表不改。
2. 用户已否决小怪物v001，运行中停止展示，原图保留。主角明确帅气/瘦弱/男性、第一关崭新浅蓝睡衣；旧表擅定高中生不作为已确认事实。`Doctor.docx`P1–27已定向核对，旧行动次数/数值不因此回退。
3. R1原件已从旧只读目录补回`DOCX/AI整理后文档/`，SHA256与既有阅读记录一致`201488a3...bf44`。重新核对66段/9表，结局原句/尾声/失我表现用于需求表。E1无原出口对白，不擅加旁白；E2/E3复用原出口互斥台词。原合同/样片边界不覆盖本次任务。
4. 新默认主场景`neurons/scenes/front_end.tscn`：可操作标题/继续/建档/覆盖提示/设置/退出；真实音量设置传给播放器。原`bedroom_sample.tscn`及`bedroom_art_trial.tscn`保留为隔离验证入口。
5. `scripts/campaign.gd`＋`core/campaign_session.gd`：第一/二关真实自主探索。L1固定10/11抽样、唯一隐藏钥匙、发现/伸手拾取/实际走门开门；首次解锁医院+3N/+2C一次。L2入口候诊、四室辐射连接，32候选抽12、真实跨房搜寻与楼梯边界。无调试按钮代替正式推进。NPC分支未接，不宣称两关全部完成。
6. 低精神/次数耗尽实际返床，完成后新尝试、HP/SP恢复、N不足5补足、提交已登记SKIN抗性；冷却不清。存档`core/save_store.gd`写校验包和上一有效备份，持久化动作/钥匙/目标/RNG/物件/暂停/待发技能/冷却/完成收据，读档提升运行代际。快照深复制防未来运行污染；schema=1，无跨版本承诺。
7. `presentation/asset_catalog.gd`＋`data/presentation.json`：主角图集/每动作sheet、家具活动层按稳定ID配置。A/B占位替换不改规则快照；不兼容资源拒绝。`world/campaign_view.gd`只表现；`data/audio_bindings.json`提供正式声音映射入口，`feedback_audio.gd`延用注册/暂停/分通道机制。

## 实际验证

- 两HTML用bundled Playwright/Edge真实浏览器验证搜索、编辑、合并、重复ID拒绝、下载JSON；结果/截图在`docs/validation/assets_20261015/`。测试备注未写进仓库进度。
- Godot4.7.2规则71/0、布局158/0，新GPU场景70/0；7张运行帧与细项在`docs/validation/campaign_20261015/`。GPU实际渲染，长过程由相同处理器小步加速，并非人工全程游玩/录屏。旧机217节点不作本批证明。
- 首轮修复错误门点、跨关实际尝试索引；次轮修复共享快照污染。具体失败/复测、沙箱Wacom/证书/缓存诊断见验证README，不谎称stderr为空。
- Windows PCK已构建；EXE因本机缺4.7.2导出模板失败。PCK不能冒充目标平台可执行包；exports被忽略，未提交。

## 下一步与未完成

先读取`docs/FEATURE_COVERAGE.md`。当前真实功能到第二关楼梯开发边界；正式开场/教程、自然NPC全部分支、其余11技能与冰柜星环、图书/成长/掌控/死亡重开/成就/三结局、第三至六关、正式声音及目标平台验收均待实现，绝不视为删除。下一批优先接技能数据/冰柜星环与首关自然事件调度，同时补医院人物事件；随后按关卡依赖推进。每个小任务更新覆盖表与此文件，资产到齐即接入实测。

## 运行与同步

Godot打开`neurons/project.godot`，F5进入新主菜单。命令与验证入口见根README。首次接手先导入资源，保留.import/.uid，忽略.godot/tmp/exports。用户在GitHub Desktop Commit/Push；接手机Fetch/Pull并核对状态后再写。建议本批提交说明：`Add full 2D asset intake forms and persistent exploration campaign`。收到“准备交接”才停止新工作并停写；不要执行Git写命令。
