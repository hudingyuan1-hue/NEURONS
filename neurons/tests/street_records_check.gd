extends "res://tests/street_materials_check.gd"
const Appearance=preload("res://scripts/core/appearance_history.gd")
func reset_archivist(at:Vector2) -> Dictionary:
 var a:Dictionary=actor_at("archivist_asylum",at)
 a.last_seen=[];a.last_seen_at=-100;a.cooldown=2.0
 app.street.data.archivist_papers={};app.street.data.erase("archivist_papers");app.street.archivist.state()
 return a
func floor_paper(key:String,at:Vector2,original:String="",text:String="") -> Dictionary:
 # Declared floor-content fixture, never spawned by the production collector.
 var p:Dictionary={"id":key,"kind":"number_paper","room":app.room_id,"pos":app.street.xy(at),"holder":"floor","progress":0.0,"seen":false,"number_glyph":null,"readable_text":text,"original_id":original,"source":"declared finite numbered-paper fixture; not new story content"}
 app.street.materials.state().surfaces[key]=p
 if not original.is_empty():app.rules.owners[original]="street_floor:"+key
 return p
func _ready() -> void:
 name="CampaignCheck";frontend=get_parent();folder="res://../docs/validation/street_records_20261018/finite"
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--validation-root="):folder=argument.trim_prefix("--validation-root=")
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 await frames();await frontend.show_profile();frontend.name_field.text="Street纸件与真实旧伤验证";frontend.overwrite_armed=true;frontend.new_game();await frames();app=frontend.active
 if app.tutorial_ui!=null:app.tutorial_ui.finish()
 app.set_process(false);clear_lines();app.paused_manual=true;app.home.enabled=false;app.family.enabled=false;app.unlock_combat();no_actors();app.unlock_street();no_street();app.enter_room("street_end");no_street()
 app.hero_pos=Vector2(4.5,5);var collector=app.street.archivist;var materials=app.street.materials
 var a:Dictionary=reset_archivist(Vector2(7,5));var surfaces:int=materials.state().surfaces.size()
 advance_actor("archivist_asylum",1)
 check(collector.state().target=="" and materials.state().surfaces.size()==surfaces,"no actual floor paper means no pickup or fabricated surface")
 a.last_seen=[];a.phase="windup";a.elapsed=.1;a.direction=[1,0];a.attack_id="declared:launched";a.hits={}
 var paper:Dictionary=floor_paper("fixture:paper",Vector2(7,5),"fixture:original","测试编号纸：只用于验证实际读纸与收取，不构成故事线索。")
 advance_actor("archivist_asylum",.1)
 check(a.phase=="windup" and collector.state().target=="","an already launched attack takes priority and cannot start a paper task")
 a=reset_archivist(Vector2(7,5));a.present=false
 check(app.street.observations.begin_surface(str(paper.id),false),"existing observe interface can approach an actual floor paper without taking it")
 for i in range(300):
  app.street.observations.advance(.025)
  if app.street.data.inspection.is_empty():break
 check(paper.read_complete and paper.holder=="floor" and known_id("combat_evidence:fixture:paper:fixture:paper"),"only real approach and complete reading mark this paper read, without transferring the original")
 var n:int=app.rules.neurons;var hp:int=app.rules.hp;var sp:int=app.rules.sp
 app.hero_pos=Vector2(4.5,5);a.present=true;advance_actor("archivist_asylum",.25)
 check(paper.holder=="floor" and collector.state().phase=="pick","partial contact preparation leaves the original on the floor")
 a.hurt=.2;advance_actor("archivist_asylum",.1)
 check(paper.holder=="floor" and collector.state().phase=="idle","hurt before actual lift cancels pickup without moving the paper")
 a.hurt=0;a.last_seen=[];advance_actor("archivist_asylum",.65)
 check(paper.holder=="street_archivist:hand" and app.rules.owners["fixture:original"]=="street_archivist:hand","one actual completed contact transfers the same original into the archivist hand")
 var snapshot:Dictionary=JSON.parse_string(JSON.stringify(app.snapshot_data()))
 check(app.restore_snapshot(snapshot),"actual hand-held paper snapshot restores through campaign schema")
 app.set_process(false);app.paused_manual=true;clear_lines();collector=app.street.archivist;materials=app.street.materials;paper=materials.state().surfaces["fixture:paper"];a=app.street.data.actors.archivist_asylum
 check(paper.holder=="street_archivist:hand" and collector.state().folder.is_empty(),"JSON restore cannot pre-file or respawn a held original")
 var elapsed:float=collector.state().elapsed;app._process(.5)
 check(is_equal_approx(collector.state().elapsed,elapsed),"manual pause cannot advance filing or its ownership commit")
 a.hurt=.2;advance_actor("archivist_asylum",.1)
 check(paper.holder=="street_archivist:hand","hurt after lift does not copy the physical original back to the floor")
 a.hurt=0;advance_actor("archivist_asylum",.5)
 check(paper.holder=="street_archivist:folder" and collector.state().folder==["fixture:paper"] and app.rules.owners["fixture:original"]=="street_archivist:folder","remaining stow completes at the same body and folder with one ownership")
 check(collector.state().witnessed_read.has("fixture:paper") and known_id("combat_evidence:fixture:paper:fixture:paper"),"actually witnessed collection preserves specifically this previously read paper")
 app.street._move_actor("archivist_asylum",Vector2(7.8,5),.2);collector.tick()
 check(app.street.vector(paper.pos).distance_to(app.street.position("archivist_asylum"))<.001 and paper.room==a.room,"stored original follows actual holder movement rather than retaining its old floor coordinates")
 a.hp=0;advance_actor("archivist_asylum",1);collector.tick()
 check(paper.holder=="street_archivist:folder" and collector.state().folder.size()==1,"death after filing retains the same stored original")
 check(not app.dialogue_queue.is_empty() and app.dialogue_queue[0].text=="收走了，也改不了我看见的。","safe retrospective original line requires both actual prior reading and witnessed filing")
 clear_lines();collector.tick();check(app.dialogue_queue.is_empty(),"retrospective line has one saved receipt")
 check(app.rules.neurons==n and app.rules.hp==hp and app.rules.sp==sp,"reading and collection do not grant resources, damage or escape rules")
 await capture("01_one_original_filed")

 a=reset_archivist(Vector2(7,5));app.hero_pos=Vector2(4.5,5)
 paper=floor_paper("fixture:unread",Vector2(7,5));advance_actor("archivist_asylum",1.2)
 check(paper.holder=="street_archivist:folder" and not collector.state().witnessed_read.has(str(paper.id)),"visible pickup cannot fill unread or unauthored paper content")
 a.hp=0;collector.tick();check(app.dialogue_queue.is_empty(),"unread collection cannot unlock the remembered-content line")
 a=reset_archivist(Vector2(7,5));paper=floor_paper("fixture:owned",Vector2(7,5),"fixture:owned_original");app.rules.owners["fixture:owned_original"]="hero";advance_actor("archivist_asylum",1)
 check(paper.holder=="floor" and app.rules.owners["fixture:owned_original"]=="hero","stale floor representation cannot steal or duplicate a hero-owned original")
 materials.state().surfaces.erase("fixture:owned");a=reset_archivist(Vector2(7,5));paper=floor_paper("fixture:race",Vector2(7,5));advance_actor("archivist_asylum",.2)
 paper.holder="cleaner:hand";advance_actor("archivist_asylum",.5)
 check(paper.holder=="cleaner:hand" and collector.state().folder.is_empty(),"another real holder winning first cancels the collector without a second copy")
 materials.state().surfaces.erase("fixture:race");a=reset_archivist(Vector2(7,5));paper=floor_paper("fixture:lost",Vector2(7,5));app.hero_pos=Vector2(13,7);advance_actor("archivist_asylum",.2)
 var cooldown:float=a.cooldown;app.hero_pos=Vector2(6,5);advance_actor("archivist_asylum",.025)
 check(collector.state().target=="" and paper.holder=="floor" and a.last_seen.size()==2 and a.cooldown<=cooldown,"new actual rediscovery cancels an unfinished pickup and resumes pursuit without resetting cooldown")
 no_street();app.hero_pos=Vector2(4.5,5);paper=floor_paper("fixture:reading_race",Vector2(5,5));app.street.observations.begin_surface(str(paper.id),false)
 for i in range(30):app.street.observations.advance(.025)
 paper.holder="street_archivist:folder";app.street.observations.advance(1)
 check(not paper.get("read_complete",false) and app.street.data.inspection.is_empty(),"paper removed before read completion cancels without granting missing content")

 app.enter_room("street_maintenance");no_street();app.hero_pos=Vector2(5.2,4.5)
 a=reset_archivist(Vector2(4.7,5.9));var cleaner:Dictionary=actor_at("cleaner",Vector2(3.3,5.9));var cleaning:Dictionary=materials.state().cleaner;cleaning.phase="select";cleaning.target="";cleaning.elapsed=0.0
 for i in range(80):
  app.street._actor("archivist_asylum",.025);app.street._actor("cleaner",.025)
 var actual_label:Dictionary=materials.state().surfaces.street_maintenance_label
 check(actual_label.holder in ["cleaner:hand","street_cleaner_bag"] and collector.state().folder.is_empty(),"production cleaner winning the same existing label cancels the real approaching archivist without duplicate ownership")
 await capture("01b_real_cleaner_competition")
 app.enter_room("street_end");no_street();app.hero_pos=Vector2(4.5,5)

 no_street();app.rules.facts.clear();app.rules.hp=35
 app.street.reactions.refresh_appearance(true)
 check(app.street.data.appearance.marks.is_empty() and app.street.data.appearance.incidents.is_empty(),"low HP alone cannot fabricate an injury history or anatomical mark")
 app.rules._record("institutional_claim","fixture:photograph",{"hp_damage":10,"part":"face"});app.rules._record("combat_actor_hit","fixture:npc",{"hp_damage":10,"target":"nurse"});app.rules._record("cortex_injury","cortex:9:clamp_wound",{"part":"hand","source":"clamp","hp_damage":0})
 app.street.reactions.refresh_appearance(true)
 check(app.street.data.appearance.marks.is_empty() and app.street.data.appearance.incidents.is_empty(),"other people's records or an unpaired anatomical annotation cannot create hero scars")
 app.rules.hp=100;app.street._damage_hero("records:sp_only",0,5,"pharmacist");app.rules.hurt_left=0
 app.street.reactions.refresh_appearance(true);check(app.street.data.appearance.incidents.is_empty(),"real SP-only damage is not a physical injury")
 app.street._damage_hero("records:actual_contact",5,0,"guard_hospital");app.rules.hurt_left=0;app.street.reactions.refresh_appearance(true)
 check(app.street.data.appearance.incidents.size()==1 and app.street.data.appearance.marks.is_empty(),"real health damage is retained without inventing a body location")
 # Declared L4 hand-contact fixture uses the existing actual damage + anatomical
 # receipt handlers. Full original clamp animation is covered by its regression.
 app.cortex.start_attempt();app.cortex.damage("clamp_damage",10,0);app.cortex.claim("clamp_wound","cortex_injury",{"part":"hand","source":"clamp","hp_damage":0})
 app.rules.hurt_left=0;app.rules.gripped=false;app.street.reactions.refresh_appearance(true)
 var marks:Dictionary=app.street.data.appearance.marks.duplicate(true)
 check(marks.size()==1 and marks.values()[0].part=="hand","paired actual clamp contact localizes exactly one existing hand mark")
 app.rules.hp=100;app.street.reactions.refresh_appearance(true)
 check(app.street.data.appearance.marks==marks,"healing cannot erase the original actual hand injury")
 var self_actor:Dictionary=actor_at("self",Vector2(6,5));app.hero_pos=Vector2(4.5,5);var evidence:int=app.rules.evidence.size();app.street.reactions.tick(.025)
 check(known_id("street_seen:existing_hand_mark") and app.rules.evidence.size()==evidence,"actual close view gives a limited old-hand comparison, not identity or fourth-wall proof")
 await capture("02_actual_existing_hand_mark")
 snapshot=JSON.parse_string(JSON.stringify(app.snapshot_data()));snapshot.street_state.appearance={"fact_count":app.rules.facts.size(),"marks":{"fake":{"part":"face"}},"incidents":[]}
 check(app.restore_snapshot(snapshot),"existing-injury state restores through the real campaign path")
 app.set_process(false);app.paused_manual=true;clear_lines()
 check(app.street.data.appearance.marks==marks,"restore rebuilds appearance from facts instead of trusting stale cached or invented facial marks")
 app.restart_street(3);app.set_process(false);app.paused_manual=true;clear_lines();app.street.reactions.refresh_appearance(true)
 check(app.rules.hp==100 and app.street.data.appearance.marks==marks,"actual Street revival retains established injury history while restoring health")
 check(app.cortex.actual_injuries().size()==2,"existing L4 body-map query reuses physical hero facts without counting unrelated claims")
 var file:=FileAccess.open(ProjectSettings.globalize_path(folder).path_join("result.json"),FileAccess.WRITE)
 file.store_string(JSON.stringify({"passes":passes,"failures":failures,"rendered":DisplayServer.get_name()!="headless","scope":"Explicit floor-content/ownership/actor positions and one declared L4 clamp-contact fixture using real damage/claim handlers. Production collection/reading, paused world, interruption, competition, JSON and real L6 revival. No authored number glyphs or facial scar placement invented. Not natural all-cast/human art/audio acceptance."},"  "));file.close()
 print("STREET_RECORDS_CHECK %d passed %d failed"%[passes.size(),failures.size()]);app.audio.reset_scene();frontend.request_exit(0 if failures.is_empty() else 1)
