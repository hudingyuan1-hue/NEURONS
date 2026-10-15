# 早期音频接收清单 · 2026-10-15

用户新增来源目录：`DOCX/早期音乐素材/音频/`。仅做文件枚举、WAV文件头与SHA256核对；**本轮未试听、未剪辑、未转换、未导入Godot**，不把文件名或参数合格视为声音内容验收。

17个WAV，合计265,141,188字节（252.86MiB）：7段音乐、1段风扇环境声、9个门/界面音效。均为PCM 48kHz/24bit/双声道。原目录未发现附带作者、生成方式或授权说明；用户提供用于项目，不据此猜测第三方再分发许可。

## 按稳定ID接收，原件不重命名

|ID / 文件名|实际时长|现行交付包|接收状态|
|---|---:|---|---|
|AMB_FAN / AMB_FAN_v001.wav|24.147s|AUD_CODE_WORLD|已发现；未听验/未接入|
|MUS_DANGER / MUS_DANGER_v001.wav|220.166s|AUD_MUSIC_DANGER|已发现；未听验/未接入|
|MUS_END / MUS_END_v001.wav|13.324s|AUD_MUSIC_ENDINGS|已发现；未听验/未接入|
|MUS_MENU / MUS_MENU_v001.wav|158.403s|AUD_MUSIC_ROOM|已发现；未听验/未接入|
|MUS_OPEN / MUS_OPEN_v001.wav|123.931s|AUD_MUSIC_OPEN|已发现；未听验/未接入|
|MUS_ROOM / MUS_ROOM_v001.wav|191.047s|AUD_MUSIC_ROOM|已发现；未听验/未接入|
|MUS_STORY / MUS_STORY_v001.wav|143.811s|AUD_MUSIC_OPEN|已发现；未听验/未接入|
|MUS_STREET / MUS_STREET_v001.wav|41.039s|AUD_MUSIC_DANGER|已发现；未听验/未接入|
|SFX_DOOR_CLOSE / SFX_DOOR_CLOSE_v001.wav|1.565s|AUD_CODE_SEARCH|已发现；未听验/未接入|
|SFX_DOOR_OPEN / SFX_DOOR_OPEN_v001.wav|1.419s|AUD_CODE_SEARCH|已发现；未听验/未接入|
|SFX_UI_BACK / SFX_UI_BACK_v001.wav|0.100s|AUD_CODE_UI|已发现；未听验/未接入|
|SFX_UI_CONFIRM / SFX_UI_CONFIRM_v001.wav|0.184s|AUD_CODE_UI|已发现；未听验/未接入|
|SFX_UI_DENIED / SFX_UI_DENIED_v001.wav|0.371s|AUD_CODE_UI|已发现；未听验/未接入|
|SFX_UI_FOCUS / SFX_UI_FOCUS_v001.wav|0.224s|AUD_CODE_UI|已发现；未听验/未接入|
|SFX_UI_PANEL / SFX_UI_PANEL_v001.wav|0.340s|AUD_CODE_UI|已发现；未听验/未接入|
|SFX_UI_REWARD / SFX_UI_REWARD_v001.wav|0.323s|AUD_CODE_UI|已发现；未听验/未接入|
|SFX_UI_SAVE / SFX_UI_SAVE_v001.wav|0.194s|AUD_CODE_UI|已发现；未听验/未接入|

## 交给执行Codex的处理要求

1. B1先试听MUS_MENU、MUS_ROOM、界面/门声与AMB_FAN，适用就复用；MUS_OPEN/STORY/DANGER/STREET/END留给相应演出/危险/隐藏分支，不凭名字认定情绪已经符合。当前运行audio_bindings.json还是空数组，这17项尚无真实运行引用。
2. 保留原件；只把选定处理副本放入neurons/assets/。音乐可按工具支持转换运行压缩格式，保留母版和处理参数；定位世界声按需要下混，普通UI双声道可以保留。48kHz/24bit源规格与母版建议相符，不因声道或长度直接判废。
3. 音乐实际长度多于初表建议，MUS_STREET约41秒短于部分建议，MUS_END约13秒；这些是制作建议差异，不是规则冲突。听后选循环区/剪分段/淡入收尾，不强迫原作者全重做；循环点尚未测，不能写无缝通过。
4. 检查削波、静音头尾、接缝、响度/对白空间与事件是否被烘入；结构性音质问题可离线分析，主观合适与否需要实际听验。无法听音时记录未听验，提供可试听文件，不编造评价。
5. 作者/来源/许可/处理参数另登记。可先列开发候选，不宣称已获商业再分发授权；授权核验只影响相应正式发布使用，不阻塞其他程序开发，不擅自购买替代品。
6. 先做菜单音乐、房间音乐与一个UI/门声的“原件→处理副本→Godot导入→真实播放/暂停恢复→导出引用”链路，再扩其余已适配音频。按稳定ID接入，事件限频和循环去重，声音不能提交玩法结果。
7. 新路径和实际进度写回现有音频表及data/progress.json；保留旧ID/填写。重建HTML前核对当前生成器的输入，避免把本轮新增路径又覆盖回旧快照。

## 双机同步注意

当前音频原目录为Git未跟踪文件，总约253MiB，单个最大约60.47MiB。仓库根未发现.gitattributes，neurons/.gitattributes仅文本行尾规则，未见音频LFS配置；本轮没有改追踪规则、提交或上传。

由用户在首次提交前决定使用现有Git同步、Git LFS（先核配置/额度）或另行传递母版；不要由Codex擅自切换。接手机逐文件核JSON清单SHA256，确认拿到的是真实WAV而非缺文件或LFS指针。不得把DOCX里的全部原始母版打入游戏导出包。

完整机器可读元数据与哈希见同目录EARLY_AUDIO_INTAKE.json。其他制作要求沿docs/NEXT_CODEX_PROMPT.md和现行资产表，不另建一套音频需求标准。
