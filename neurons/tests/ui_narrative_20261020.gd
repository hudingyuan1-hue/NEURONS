extends "res://tests/ui_visual_20261020.gd"
const Art=preload("res://scripts/ui/narrative_art.gd")
const Opening=preload("res://scripts/ui/opening_flow.gd")
const EndingArt=preload("res://scripts/ui/ending_art.gd")
const AttemptNotice=preload("res://scripts/ui/attempt_notice.gd")
const Body=preload("res://scripts/ui/rig_body_preview.gd")
class HiddenFixture extends RefCounted:
 var data:Dictionary={"status":""}
 var frame:Dictionary={}
 func ending_frame()->Dictionary:return frame.duplicate(true)
class ViewFixture extends RefCounted:
 var hidden_route=HiddenFixture.new()
 var street:Dictionary={"data":{"ending":{}}}
class NoticeFixture extends RefCounted:
 var runtime_generation:int=1
 var rules:Dictionary={"hp":100,"actual_attempt":1}
 var session:Dictionary={"data":{"cycle":1,"attempts":{"1":1},"level":1}}
 var status_note:String="进入卧室"
 var paused_manual:bool=false
 var reduced_effects:bool=true
 var menu:Dictionary={"visible":false}
 var audio_panel:Dictionary={"visible":false}
 var ending_panel:Dictionary={"visible":false}
 var dialogue_queue:Array=[]
 var opening_ui=null
 var tutorial_ui=null
func _ready()->void:
 folder="res://../docs/validation/asset_production_20261020/ui/narrative"
 name="CampaignCheck";frontend=get_parent();DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 await frames(8)
 check(Art.texture("TITLE_DOOR") is AtlasTexture,"title uses an actual region of the approved BASE painting")
 await capture("01_title_real_painting")
 await click(button(frontend,"建立档案"));await frames(4)
 check(frontend.title_paint.variant=="profile" and Art.texture("PLAYER_PROFILE")!=null,"profile shows the existing user-approved player identity without fake transparency")
 await capture("02_player_profile")
 frontend.launch({"name":"叙事与来源UI隔离夹具","invader_id":8402,"opening_completed":true,"tutorial_completed":true},{})
 app=frontend.active;app.auto_dialogue_enabled=false;await frames(5)
 while not app.dialogue_queue.is_empty():await click(button(app.dialogue_panel,"继续"))
 while app.closing_left>0:await frames()
 var observed:Array=app.rules.observations.duplicate(true)
 app.rules.observe("人物","father","UI独立夹具：已见父亲条目。","亲历事实","UI验证，不是真实剧情进度")
 app.rules.observe("人物","ui_claim","UI独立夹具：机构文字只能按原记载展示。","机构记录","机构文书原页 / 测试来源")
 app.rules.observe("人物","ui_unknown","UI独立夹具：未明确身份的条目不得分配陌生人的画像。","亲历事实","现场长来源："+"来源字段不能截断，不能替代事实。".repeat(12))
 app.rules.observe("物品","hospital_family_photo_seen","UI独立夹具：已见照片，不认定照片人物对应或亲属关系。","亲历事实","测试照片观察入口")
 var clock:float=app.rules.world_time;var balance:int=app.rules.plexus
 app.menu.book_category="人物";app.open_system_page("book");await frames(6)
 check(app.menu.book_cards.get_child_count()>=3,"records are real independent cards in a scroll container")
 check(Art.portrait({"id":"father"})!=null and Art.portrait({"id":"ui_unknown"})==null,"portrait mapping is exact; unknown identities get no invented face")
 var kinds:Array=[]
 for card in app.menu.book_cards.get_children():kinds.append(card.get_meta("record_kind",""))
 check("亲历事实" in kinds and "机构记录" in kinds,"institutional claims and witnessed facts retain distinct source labels")
 await capture("03_fact_and_claim_cards")
 await click(app.menu.extension_button);await frames(3)
 check(app.rules.plexus==balance and app.menu._status.text.contains("不足"),"parameter purchase retains actual insufficient-balance rejection")
 await click(button(app.menu,"物品"));await frames(3)
 var photo_found:bool=false
 for card in app.menu.book_cards.get_children():
  for item in card.find_children("*","TextureRect",true,false):photo_found=photo_found or item.texture==Art.texture("UI_EVIDENCE_FAMILY_PHOTO")
 check(photo_found,"family photo appears only under its exact existing observation ID")
 await capture("04_observed_photo")
 check(app.rules.world_time==clock,"reading/scrolling sources does not advance world time")
 await click(button(app.menu,"关闭"));await frames(4)
 app.rules.observations=observed;app.paused_manual=true;await frames(3)
 var opening:=Opening.new();app.add_child(opening);opening.z_index=60;opening.start("startup");opening.auto_play=false
 var supplied:int=0
 for key:String in ["startup","parasite"]:
  opening.start(key);opening.auto_play=false
  for index in range(opening.cards().size()):
   var card:Dictionary=opening.cards()[index]
   if str(card.visual)=="black":continue
   supplied+=1;check(Art.card(str(card.id))!=null,"stable narrative image exists: "+str(card.id))
  opening.index=1 if key=="startup" else 0;opening.typed=opening.current_text().length();opening.card_clock=1;opening.refresh()
  await capture("05_"+key+"_source_art")
 opening.start("parasite");opening.auto_play=false
 for index:int in [5,7]:
  opening.index=index;opening.typed=opening.current_text().length();opening.card_clock=1;opening.refresh();await capture("06_intro_"+str(index))
 check(supplied==16,"all sixteen non-black opening/parasite cards use real image bindings")
 check(not Art.data().card_bindings.values().has("SLIDE_B04") and not Art.data().card_bindings.values().has("SLIDE_B05"),"withheld planet and spacecraft never leak into opening")
 opening.queue_free();await frames(3)
 var view:=ViewFixture.new();var ending:=EndingArt.new();ending.app=view;app.add_child(ending);ending.z_index=60
 var cases:Array=[
  ["E1_bed",{"hidden":true,"progress":.1}],
  ["E1_eyes_closed",{"hidden":true,"progress":.5}],
  ["E1_eyes_open",{"hidden":true,"progress":.9}],
  ["E2_wake",{"id":"E2","phase":"wake","elapsed":1.5}],
  ["E2_origin",{"id":"E2","phase":"planet","elapsed":1.0}],
  ["E3_wake",{"id":"E3","phase":"wake","elapsed":2.5}]
 ]
 for item in cases:
  view.hidden_route.data.status="ending" if item[1].has("hidden") else ""
  view.hidden_route.frame={"phase":"bed","wake":item[1].get("progress",0)}
  view.street.data.ending=item[1].duplicate(true) if not item[1].has("hidden") else {}
  var before:String=JSON.stringify([view.hidden_route.frame,view.street.data.ending])
  await frames(5);await capture("07_"+str(item[0]))
  check(ending.visible and before==JSON.stringify([view.hidden_route.frame,view.street.data.ending]),"ending art reads phase without changing it: "+str(item[0]))
 check(Art.texture("ENDING_EYES_OPEN").get_size()==Art.texture("ENDING_EYES_CLOSED").get_size(),"closed/open eyes are two equal regions from the original user image")
 ending.queue_free();await frames(3)
 var notice_owner:=NoticeFixture.new();var notice:=AttemptNotice.new();notice.app=notice_owner;app.add_child(notice);notice.z_index=60;await frames(3)
 notice_owner.session.data.cycle=2;notice_owner.session.data.attempts["1"]=2;notice_owner.rules.actual_attempt=2;notice_owner.status_note="休息实际完成：新尝试；抗性增长提交；冷却不清零"
 await frames(4);check(notice.visible and notice.title.text.begins_with("休息完成"),"notice follows actual changed attempt and distinguishes rest")
 await capture("08_actual_attempt_notice")
 notice_owner.runtime_generation=2;await frames(3)
 check(notice.remaining==0 and not notice.visible,"restore generation resets notice baseline instead of replaying an attempt")
 notice.queue_free();await frames(3)
 var body:=Body.new();app.add_child(body);await frames(3)
 var source:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/character_rig.json"))
 var expected:bool=bool(source.rigs[source.default].get("production_ready",false))
 check(not body.is_ready if not expected else body.is_ready,"UI body preview observes the same production readiness gate")
 var clips:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/ui_body_preview_poses.json")).poses
 var unique:Dictionary={}
 for id:String in clips:unique[JSON.stringify([clips[id].tracks,clips[id].hands])]=true
 check(clips.size()==12 and unique.size()==12,"twelve UI reactions have distinct authored tracks; missing clips never silently become idle")
 body.queue_free();await frames(3)
 var result:=FileAccess.open(ProjectSettings.globalize_path(folder).path_join("result.json"),FileAccess.WRITE)
 result.store_string(JSON.stringify({"passes":passes,"failures":failures,"rendered":true,"scope":"actual UI input plus isolated source/phase contracts; no natural ending or formal four-view animation acceptance","body_production_ready":expected},"  "));result.close()
 print("UI_NARRATIVE_CHECK %d passed %d failed"%[passes.size(),failures.size()])
 frontend.request_exit(0 if failures.is_empty() else 1)
