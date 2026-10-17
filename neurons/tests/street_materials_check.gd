extends "res://tests/street_chapter_check.gd"
## Finite declared cast/position/timing fixtures; real state/physics/save handlers.
func actor_at(id:String,at:Vector2) -> Dictionary:
 var a:Dictionary=app.street.data.actors[id]
 a.present=true;a.room=app.room_id;a.pos=app.street.xy(at);a.hp=40;a.hurt=0.0;a.phase="idle";a.follow="";a.route=[];a.goal=[]
 return a
func advance_actor(id:String,seconds:float) -> void:
 for i in range(ceili(seconds/.025)):app.street._actor(id,.025)
func known_id(id:String) -> bool:return app.street.materials.known(id)
func capture(value:String) -> void:
 app.update_ui();app.keep_metric_actor_visible();app.view.queue_redraw()
 await super.capture(value)
func count_fact(kind:String) -> int:
 var n:int=0
 for fact in app.rules.facts:
  if str(fact.kind)==kind:n+=1
 return n
func _ready() -> void:
 name="CampaignCheck";frontend=get_parent();folder="res://../docs/validation/street_materials_20261018/finite"
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--validation-root="):folder=argument.trim_prefix("--validation-root=")
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 await frames();await frontend.show_profile();frontend.name_field.text="Street纸条与物权验证";frontend.overwrite_armed=true;frontend.new_game();await frames();app=frontend.active
 if app.tutorial_ui!=null:app.tutorial_ui.finish()
 app.set_process(false);clear_lines();app.paused_manual=true;app.home.enabled=false;app.family.enabled=false;app.unlock_combat();no_actors();app.unlock_street();no_street()
 app.enter_room("street_twisted");no_street();app.rules.end_control();app.hero_pos=Vector2(14,4)
 var speaker:Dictionary=actor_at("speaker",Vector2(13,4));var material=app.street.materials;var state:Dictionary=material.state()
 advance_actor("speaker",.3);var torn:float=state.speaker.tear
 check(torn>0 and torn<1.2 and state.speaker.holder=="neck","real first contact tears only part of the same neck strip")
 speaker.hurt=.25;advance_actor("speaker",.2)
 check(is_equal_approx(state.speaker.tear,torn),"hurt suspends tear and preserves existing damage")
 speaker.hurt=0
 var enemy:Dictionary=actor_at("self",Vector2(15,4));enemy.hostile=true
 advance_actor("speaker",.3)
 check(speaker.phase=="point" and speaker.point_actor=="self" and is_equal_approx(state.speaker.tear,torn),"actually seen pursuer interrupts tearing and supplies the real direction")
 enemy.room="street_node";advance_actor("speaker",.025)
 check(speaker.phase=="tear" and speaker.point_actor=="","lost line of sight ends precise threat direction instead of remote tracking")
 advance_actor("speaker",1.1);var papers:int=count_fact("street_paper_removed");advance_actor("speaker",2)
 check(state.speaker.holder=="hand" and papers==1 and count_fact("street_paper_removed")==1,"only remaining strip tears off and later approach makes no repeated fragments")
 check(known_id("street_statement_strip") and not known_id("asylum_heard_retraction") and not known_id("asylum_heard_original"),"reading retained paper cannot invent heard retraction or deleted original recording")
 material.tick();check(app.dialogue_queue.is_empty(),"no reunion line without actual earlier L3 experience")
 app.rules.observe("人物","asylum_heard_retraction","fixture: actually heard the original scripted retraction","亲历事实","declared prior-event fixture")
 material.tick();check(not app.dialogue_queue.is_empty() and app.dialogue_queue[0].text=="不用再念了。","original recognition line requires the saved actually-heard event")
 clear_lines();material.tick();check(app.dialogue_queue.is_empty(),"speaker recognition line has a once receipt")
 await capture("01_speaker_strip_actual")

 app.enter_room("street_maintenance");no_street();app.hero_pos=Vector2(7,4);actor_at("treatment_pharmacist",Vector2(6,4))
 var hp:int=app.rules.hp;var sp:int=app.rules.sp;var key_owner:String=str(app.session.data.key_owner)
 advance_actor("treatment_pharmacist",.65)
 check(known_id("street_empty_box_number") and state.pharmacist.seen,"only an actually visible lifted empty box provides its limited observation")
 check(app.rules.hp==hp and app.rules.sp==sp and str(app.session.data.key_owner)==key_owner,"empty boxes and key ring give neither medicine nor escape key")
 check(not known_id("street_box_batch_match"),"unknown number glyphs do not manufacture a batch match")
 await capture("02_empty_boxes_actual")
 material.tick();clear_lines()

 no_street();app.hero_pos=Vector2(5.4,5.7)
 var cleaner:Dictionary=actor_at("cleaner",Vector2(3.3,5.9));var c:Dictionary=state.cleaner
 c.phase="select";c.target="";c.elapsed=0.0
 state.surfaces.street_maintenance_scuff.progress=1.0
 var label:Dictionary=state.surfaces.street_maintenance_label
 advance_actor("cleaner",.3)
 check(label.progress>0 and label.progress<1 and label.holder=="floor","pickup begins only at the actual ground label, not at remote display time")
 var progress:float=label.progress;cleaner.hurt=.25;advance_actor("cleaner",.2)
 check(is_equal_approx(label.progress,progress) and c.bag.is_empty(),"interrupted pickup keeps partial progress and grants no premature bag contents")
 cleaner.hurt=0
 app.set_process(true);app.paused_manual=true;await frames(8);app.set_process(false)
 check(is_equal_approx(label.progress,progress),"real manual pause freezes material progress")
 var snapshot:Dictionary=JSON.parse_string(JSON.stringify(app.snapshot_data()))
 check(app.restore_snapshot(snapshot) and is_equal_approx(app.street.materials.state().surfaces.street_maintenance_label.progress,progress),"half pickup survives real snapshot JSON restoration")
 app.set_process(false);app.paused_manual=true;clear_lines();material=app.street.materials;state=material.state();c=state.cleaner;label=state.surfaces.street_maintenance_label;cleaner=app.street.data.actors.cleaner
 advance_actor("cleaner",.4)
 check(label.holder=="cleaner:hand" and c.bag.is_empty(),"contact pickup first transfers the single label into the hand, not a remote bag")
 for i in range(240):
  app.street._actor("cleaner",.025)
  if label.holder=="street_cleaner_bag":break
 check(label.holder=="street_cleaner_bag" and c.bag==[label.id] and c.phase=="seal","same held label reaches the parked cart and is actually deposited once")
 advance_actor("cleaner",1)
 check(c.phase=="select" and c.target=="" and c.bag.size()==1,"bag sealing completes without restoring the floor label")
 material.tick()
 check(c.pickup_seen and state.spoken.has("cleaner") and not known_id("street_label_number"),"witnessed pickup allows original line but supplies no unread label number")
 clear_lines();await capture("03_cleaner_bag_actual")
 var owned:Dictionary=label.duplicate(true);owned.id="already_owned_original_fixture";owned.progress=0.0;owned.holder="floor";owned.original_id="asylum_corpse_wristband"
 state.surfaces[owned.id]=owned;app.rules.owners.asylum_corpse_wristband="hero";var owner_before:Dictionary=app.rules.owners.duplicate(true)
 check(not material.available(owned),"same original already in hero inventory is not a floor candidate or duplicate display")
 advance_actor("cleaner",2)
 check(app.rules.owners==owner_before and owned.holder=="floor","cleaning cannot reclaim the hero's earlier original or erase its ownership")
 var before:int=state.surfaces.size();hp=app.rules.hp
 app.street._damage_hero("materials:new_damage",5,0,"self");app.street._damage_hero("materials:new_damage",5,0,"self")
 check(state.surfaces.size()==before+1 and app.rules.hp==hp-5,"new real injury creates one persistent local trace; same damage receipt does not duplicate it")
 app.rules.hurt_left=0
 var blood:Dictionary=state.surfaces["street_blood:materials:new_damage"]
 actor_at("cleaner",app.street.vector(blood.pos));c.phase="select";c.target="";c.elapsed=0
 advance_actor("cleaner",.6);hp=app.rules.hp
 check(blood.progress>0 and blood.progress<1 and label.holder=="street_cleaner_bag","partial wiping affects only the contacted trace and cannot restore a collected label")
 cleaner.hp=0;advance_actor("cleaner",2)
 check(blood.progress<1 and app.rules.hp==hp,"cleaner death leaves unfinished trace and never heals the actual wound")

 no_street();app.rules.hp=100;app.rules.hurt_left=0;app.hero_pos=Vector2(8,5)
 var stitched:Dictionary=actor_at("stitched",Vector2(7,5));stitched.cooldown=0;app.street.data.next_attack=0
 advance_actor("stitched",.3);torn=state.stitched.tear
 check(stitched.phase=="tear" and torn>0 and torn<1.2,"stitched-mouth enemy first tears its own existing finger paper before grabbing")
 stitched.hurt=.4;advance_actor("stitched",.2)
 check(is_equal_approx(state.stitched.tear,torn),"hurt interrupts finger-paper preparation without recreating intact paper")
 stitched.hurt=0;advance_actor("stitched",1.1)
 check(state.stitched.tear>=1.199 and stitched.phase=="windup","remaining preparation finishes into the existing grab state machine")
 var hp_before:int=app.rules.hp
 for i in range(40):app.street._advance_attack("stitched",.025)
 check(app.rules.hp==hp_before-10 and app.rules.gripped,"existing real grab contact retains original damage and finite hold")
 stitched.phase="idle";stitched.cooldown=0;app.street.data.clock+=3;app.street.data.next_attack=0;app.rules.gripped=false;app.street.data.holder="";app.street.data.grip_safe_until=0;app.rules.hurt_left=0
 app.street._actor("stitched",.025)
 check(stitched.phase=="windup" and state.stitched.tear>=1.199,"next grab skips already-torn paper and does not repeat debris production")
 check(app.rules.owners.asylum_corpse_wristband=="hero" and known_id("asylum_heard_retraction"),"enemy tearing and cleaner activity preserve actual prior evidence and memory")
 await capture("04_stitched_real_grab")
 no_street();clear_lines();app.hero_pos=Vector2(7,3);app.rules.gripped=false;app.rules.hurt_left=0;app.street.data.holder=""
 var debris:Dictionary={};var pipe:Dictionary={}
 for prop in app.layout.furniture:
  if prop.id=="street_prop_3":debris=prop
  if prop.id=="street_prop_0":pipe=prop
 var old_rect:Rect2=debris.rect;var pipe_rect:Rect2=pipe.rect
 var faceless:Dictionary=actor_at("faceless",Vector2(old_rect.position.x-.4,old_rect.get_center().y))
 var blocker:Dictionary=actor_at("treatment_pharmacist",old_rect.get_center())
 advance_actor("faceless",.3)
 check(debris.rect==old_rect and state.faceless.shift==0,"real person in the debris footprint prevents pushing; no force or phantom clearance")
 blocker.present=false;advance_actor("faceless",.5)
 check(float(state.faceless.shift)>.1 and float(state.faceless.shift)<.5 and pipe.rect==pipe_rect,"only the specified maintenance debris moves, never the first pipe rack")
 var shift:float=state.faceless.shift;faceless.hurt=.4;advance_actor("faceless",.2)
 check(is_equal_approx(state.faceless.shift,shift),"hurt preserves partial real debris movement without resetting or completing it")
 faceless.hurt=0;advance_actor("faceless",2)
 check(state.faceless.done and is_equal_approx(float(state.faceless.shift),.5),"remaining push completes once, retaining original prop identity")
 var pushed:Rect2=debris.rect;advance_actor("faceless",2)
 check(debris.rect==pushed and faceless.phase=="idle","finished helper retreats aside without replaying the spatial change")
 check(not app.layout.walkable(pushed.get_center()) and app.layout.grid.is_point_solid(Vector2i((pushed.get_center()/app.layout.CELL).round())),"local navigation cells reflect the real moved obstacle")
 snapshot=JSON.parse_string(JSON.stringify(app.snapshot_data()))
 check(app.restore_snapshot(snapshot),"actual moved-prop save restores successfully")
 app.set_process(false);app.paused_manual=true;clear_lines();material=app.street.materials;state=material.state();faceless=app.street.data.actors.faceless
 var restored:Dictionary={}
 for prop in app.layout.furniture:
  if prop.id=="street_prop_3":restored=prop
 check(restored.rect==pushed and state.faceless.done,"JSON reload keeps moved debris and completed help instead of reconstructing the original position")
 faceless.hp=0;advance_actor("faceless",1)
 check(restored.rect==pushed,"helper death leaves the actual rearranged maintenance debris")
 app.enter_room("street_side");no_street();app.hero_pos=Vector2(3.5,4.5);actor_at("corner",Vector2(2.3,4.5));app.street._actor("corner",.025)
 var pursuer:Dictionary=actor_at("self",Vector2(4.2,4.5));pursuer.hostile=true
 var corner_at:Vector2=app.street.position("corner");advance_actor("corner",.3)
 check(app.street.data.actors.corner.phase=="idle" and app.street.position("corner").distance_to(corner_at)>.01,"corner stops pointing and physically retreats when a real pursuer enters sight")
 app.street.reactions.tick(.1)
 check(app.dialogue_queue.is_empty(),"actual nearby pursuer suppresses friendly garbled dialogue without blocking combat")
 pursuer.present=false;app.street._actor("corner",.025);app.street.reactions.tick(.1)
 check(not app.dialogue_queue.is_empty() and app.dialogue_queue[0].text==app.street.config.dialogue.corner.text,"safe gap plays the source-exact Street corner line after real pointing")
 clear_lines();app.street.reactions.tick(.1)
 check(app.dialogue_queue.is_empty(),"same actual Street attempt cannot repeatedly queue original garbled line")
 check(not app.layout.path(app.layout.spawn(),app.layout.portal("street_plaza").threshold).is_empty(),"side room retains the original sole return route with no invented rear door")
 await capture("05_corner_original_route")
 var f:=FileAccess.open(ProjectSettings.globalize_path(folder).path_join("result.json"),FileAccess.WRITE)
 f.store_string(JSON.stringify({"passes":passes,"failures":failures,"rendered":DisplayServer.get_name()!="headless","scope":"Declared actor/position and one prior-heard-event fixture, production paper/empty-box/cleaner/grab/damage handlers, actual JSON and manual pause. Not human play, all NPC combinations or formal art/audio acceptance."},"  "));f.close()
 print("STREET_MATERIALS_CHECK %d passed %d failed"%[passes.size(),failures.size()]);app.audio.reset_scene();frontend.request_exit(0 if failures.is_empty() else 1)
