extends "res://tests/asylum_ward_check.gd"
## Declared finite initial actor/contact fixtures; actual source event updates,
## completed/cancelled searches and checksummed disk JSON. Not natural play QA.
const Presentation=preload("res://scripts/core/character_presentation.gd")
var presenter
var search_index:int=0
var legacy_door_source:Dictionary={}
var door_trace:Array=[]

func presentation_fixture(room:String="workshop",events:bool=false) -> void:
 fixture3(room,events);app.set_process(false);presenter=Presentation.new(app)
 search_index=0

func real_search(cancelled:bool=false) -> String:
 var index:int=search_index%app.layout.furniture.size();search_index+=1
 var id:String=app.room_id+":"+str(index)
 app.hero_pos=app.layout.furniture[index].at;app.hero_route=PackedVector2Array();app.target_index=index
 if not app.rules.begin_search(id):return ""
 var receipt:String=app.rules._search_id
 if cancelled:app.rules.cancel_search()
 else:
  var result:Dictionary=app.rules.tick(app.rules.search_duration+.001)
  if not result.search_completed:return ""
 app.target_index=-1;app.action_phase="autonomy"
 return receipt

func integrated_search() -> String:
 var index:int=search_index%app.layout.furniture.size();search_index+=1
 var id:String=app.room_id+":"+str(index)
 app.hero_pos=app.layout.furniture[index].at;app.hero_route=PackedVector2Array();app.target_index=index;app.action_phase="autonomy";clear_lines()
 if not app.rules.begin_search(id):return ""
 var receipt:String=app.rules._search_id
 for frame in range(1000):
  if not app.rules.search_active:break
  step3()
 return receipt if str(app.rules.settled.get(receipt,""))=="completed" else ""

func dispatch() -> void:
 clear_lines();app.hero_route=PackedVector2Array();app.motion.clear();app.action_phase="autonomy";app.paused_manual=false
 presenter.tick();app.paused_manual=true

func line_count(text:String) -> int:
 var count:int=0
 for line in app.dialogue_queue:
  if str(line.text)==text:count+=1
 return count

func facts_of(kind:String) -> int:
 var count:int=0
 for fact in app.rules.facts:
  if str(fact.kind)==kind:count+=1
 return count

func read_hospital_page(id:String) -> bool:
 var reader=app.hospital.observations;var target:Dictionary=reader.specification(id)
 app.hero_pos=reader.target_position(target);app.hero_route=PackedVector2Array();app.action_phase="autonomy"
 if not reader.begin(id):return false
 reader.tick(2.0)
 return reader.state().read.has(id)

func street_actor(id:String,at:Vector2) -> Dictionary:
 var actor:Dictionary=app.street.data.actors[id]
 actor.present=true;actor.hp=int(app.street.spec(id).hp);actor.room=app.room_id;actor.pos=[at.x,at.y];actor.phase="idle";actor.hurt=0.0;actor.cooldown=0.0;actor.route=[];actor.last_seen=[];actor.follow=""
 return actor

func trace_door(label:String,battle) -> void:
 door_trace.append({"label":label,"room":app.room_id,"stage":presenter.state().stage,"door_left":battle.data.door_left,"destination":battle.data.destination,"presentation_action_serial":battle.data.get("presentation_action_serial",0),"hero":[app.hero_pos.x,app.hero_pos.y],"route_points":app.hero_route.size(),"stage_facts":facts_of("character_stage_changed")})

func restored_pre_presentation_source() -> bool:
 # A declared older-build snapshot: preserve all genuinely executed source
 # events/reads, omitting only the then-nonexistent presentation subsystem.
 var legacy:Dictionary=legacy_door_source.duplicate(true)
 legacy.session.erase("character_presentation")
 var facts:Array=[]
 for fact in legacy.rules.facts:
  if str(fact.get("kind","")) not in ["character_stage_changed","character_reflection"]:facts.append(fact)
 legacy.rules.facts=facts
 if not app.restore_snapshot(legacy):return false
 app.set_process(false);app.paused_manual=false;clear_lines();presenter=Presentation.new(app)
 return true

func legacy_door_chain_case() -> void:
 check(restored_pre_presentation_source(),"declared old midgame JSON retains real two-class evidence while lacking the later presentation module")
 app.unlock_combat();app.set_process(false);app.enter_room("atrium")
 for id in app.combat.data.actors:app.combat.data.actors[id].present=false;app.combat.data.actors[id].pending=false;app.combat.data.actors[id].checks=3
 var battle=app.combat;var to:String=battle.map.next_room(app.room_id,"brainstem");var portal:Dictionary=battle.hero_portal(to)
 app.hero_pos=Vector2(portal.at)+Vector2(portal.inward)*.8;app.hero_route=app.layout.path(app.hero_pos,portal.at);app.action_phase="autonomy"
 app.session.data.erase("character_presentation");presenter=Presentation.new(app)
 check(not presenter.calm_cause().is_empty() and not presenter.hospital_cause().is_empty() and not presenter.therapy_cause().is_empty(),"old-door fixture genuinely has enough prior source evidence for multiple stages, rather than an empty-evidence false negative")
 check(roundtrip(),"old mid-approach state is persisted and loaded through actual checksummed JSON")
 presenter=Presentation.new(app);app.paused_manual=false;trace_door("ordinary_before_approach",battle)
 for index in range(300):
  if app.hero_route.is_empty():break
  battle.move_hero(.025)
 check(app.hero_pos.distance_to(portal.at)<=.04 and presenter.state().stage==0 and facts_of("character_stage_changed")==0,"real ordinary door-at approach cannot count as a completed normal action in a fully evidenced old save")
 trace_door("ordinary_at_no_advance",battle)
 battle._hero(.025);battle._hero(.3)
 check(float(battle.data.door_left)>0 and presenter.state().stage==0,"normal opening countdown cannot silently advance the old presentation stage")
 check(roundtrip(),"real half-open door persists its countdown without awarding a presentation stage")
 battle=app.combat;presenter=Presentation.new(app);app.paused_manual=false
 for index in range(300):
  if app.hero_pos.distance_to(battle.hero_portal(to).threshold)<=.035:break
  battle._hero(.025)
 check(app.room_id=="atrium" and app.hero_pos.distance_to(battle.hero_portal(to).threshold)<=.035 and presenter.state().stage==0 and facts_of("character_stage_changed")==0,"real threshold arrival is still the same unfinished ordinary door action")
 trace_door("ordinary_threshold_no_advance",battle)
 check(roundtrip(),"actual threshold-midpoint JSON cannot replay the preceding at/threshold as separate completions")
 battle=app.combat;presenter=Presentation.new(app);app.paused_manual=false
 battle._hero(.025)
 check(app.room_id==to and presenter.state().stage==1 and facts_of("character_stage_changed")==1 and str(presenter.state().stage_receipts["1"].normal_action).begins_with("battle_door:"),"one actual cross_door callback advances at most one stage despite all later-stage evidence being ready")
 trace_door("ordinary_actual_cross_one_stage",battle)
 check(roundtrip(),"completed ordinary crossing and its unique presentation receipt survive real disk restore")
 battle=app.combat;presenter=Presentation.new(app);app.paused_manual=false
 battle._hero(.025)
 check(presenter.state().stage==1 and facts_of("character_stage_changed")==1,"resuming the already-completed crossing cannot promote a second stage")
 trace_door("ordinary_restored_cross_not_replayed",battle)

 check(restored_pre_presentation_source(),"final-gate comparison restores the same genuine legacy evidence independently")
 app.unlock_combat();app.unlock_street();app.set_process(false);app.enter_room("street_end")
 for id in app.street.data.actors:app.street.data.actors[id].present=false
 app.session.data.erase("character_presentation");presenter=Presentation.new(app);battle=app.street
 portal=battle.hero_portal("ending_gate");app.hero_pos=Vector2(portal.at)+Vector2(portal.inward)*.8;app.hero_route=app.layout.path(app.hero_pos,portal.at);app.action_phase="autonomy";app.paused_manual=false
 check(roundtrip(),"actual final-gate approach starts from a persisted legacy presentation state")
 battle=app.street;presenter=Presentation.new(app);app.paused_manual=false
 for index in range(300):
  if float(battle.data.door_left)>=0:break
  battle._hero(.025)
 check(app.room_id=="street_end" and app.hero_pos.distance_to(battle.hero_portal("ending_gate").at)<=.04 and float(battle.data.door_left)>=0 and presenter.state().stage==1 and facts_of("character_stage_changed")==1,"the final gate's first interior-at arrival is allowed one normal completion because no destination room exists")
 trace_door("final_gate_first_at_once",battle)
 battle._hero(.25);check(roundtrip(),"final-gate opening preserves the already-consumed interior completion across real save/load")
 battle=app.street;presenter=Presentation.new(app);app.paused_manual=false
 for index in range(300):
  if app.hero_pos.distance_to(battle.hero_portal("ending_gate").threshold)<=.035:break
  battle._hero(.025)
 check(presenter.state().stage==1 and facts_of("character_stage_changed")==1 and app.hero_pos.distance_to(battle.hero_portal("ending_gate").threshold)<=.035,"final-gate threshold movement after restore cannot award a second normal completion")
 trace_door("final_gate_threshold_not_second",battle)
 battle._hero(.025)
 check(not battle.data.ending.is_empty() and presenter.state().stage==1 and facts_of("character_stage_changed")==1,"actual final-gate crossing commits its real ending without replaying presentation advancement")
 trace_door("final_gate_actual_end_not_second",battle)
 var file=FileAccess.open(ProjectSettings.globalize_path(folder).path_join("legacy_door_trace.json"),FileAccess.WRITE);file.store_string(JSON.stringify(door_trace,"  "));file.close()

func _ready() -> void:
 name="CampaignCheck";frontend=get_parent();folder="res://../docs/validation/character_presentation_20261019/finite_r1"
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--validation-root="):folder=argument.trim_prefix("--validation-root=")
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 await frames();frontend.show_profile();await frames();frontend.name_field.text="长期表现与亲历反思专项";frontend.overwrite_armed=true;frontend.new_game();await frames();app=frontend.active
 if app.tutorial_ui!=null:app.tutorial_ui.finish()
 app.set_process(false)

 presentation_fixture()
 check(presenter.state().stage==0 and presenter.view_state().allow_early_jokes,"new actual session starts initial, with no fabricated late personality or evidence")
 app.rules.known.append("forced_transfer_seen")
 var receipt:String=real_search()
 presenter.normal_action_completed(receipt,"search",app.room_id)
 check(presenter.state().stage==0,"a knowledge flag without an actual witnessed observation cannot make the role steady")
 app.rules.observe("物品","forced_transfer_seen","仅听说被转运","听说","declared negative fixture")
 receipt=real_search();presenter.normal_action_completed(receipt,"search",app.room_id)
 check(presenter.state().stage==0,"hearsay does not substitute for an actual forced-transfer witness")
 app.rules.observe("角色","doctor_harm","真的受过伤，但没有针对本次伤害的假记录","亲历事实","declared unpaired injury fixture")
 receipt=real_search();presenter.normal_action_completed(receipt,"search",app.room_id)
 check(presenter.state().stage==0,"real injury alone does not invent the source's same-injury false-record pairing")

 # Existing household source pipeline, not an injected awakening flag.
 fixture(true,false);app.set_process(false);app.session.data.erase("character_presentation");presenter=Presentation.new(app)
 app.family.spawn("father")
 check(until(func():return not app.home.data.dog.alive),"father's actual existing dog branch produces the formal awakening before presentation reacts")
 check(app.rules.awakening_receipts.has("dog_death") and presenter.state().stage==0,"actual formal awakening does not silently add a second awakening or skip the later normal action")
 var growth:int=app.rules.pending_global_growth;var awareness:int=app.rules.awareness_stage;var neurons:int=app.rules.neurons
 var aborted:String=real_search(true)
 check(not presenter.normal_action_completed(aborted,"search",app.room_id).ok and presenter.state().stage==0,"cancelled real search receipt is rejected, with no long-term advancement")
 receipt=real_search();var result:Dictionary=presenter.normal_action_completed(receipt,"search",app.room_id)
 check(result.get("advanced",false) and presenter.state().stage==1 and not presenter.view_state().allow_early_jokes,"a later genuinely completed search advances source-proved steady exactly once")
 app.paused_manual=false;app.add_dialogue("角色","原专属反馈仍在前面")
 presenter.tick()
 check(line_count(Presentation.CALM_LINE)==0 and presenter.state().pending.size()==1,"existing exclusive dialogue keeps priority over the new optional reflection")
 app.paused_manual=true
 check(roundtrip() and app.session.data.character_presentation.stage==1 and app.session.data.character_presentation.pending.size()==1,"real checksummed JSON preserves the durable stage and its unspoken pending reflection")
 presenter=Presentation.new(app);dispatch()
 check(line_count(Presentation.CALM_LINE)==1 and facts_of("character_stage_changed")==1,"safe gap dispatches the exact source steady sentence once after disk restore")
 check(app.rules.pending_global_growth==growth and app.rules.awareness_stage==awareness and app.rules.neurons==neurons+1,"presentation changes no awakening gain, fourth-wall awareness or independent search income")
 check(roundtrip(),"mid-reflection dialogue itself survives the real save pipeline")
 presenter=Presentation.new(app);clear_lines();presenter.tick()
 check(app.dialogue_queue.is_empty() and presenter.state().spoken.has("steady"),"reloaded completed reflection cannot queue a second copy")
 app.session.new_attempt(1,app.rng);presenter=Presentation.new(app)
 check(presenter.state().stage==1 and presenter.state().spoken.has("steady"),"a real next-attempt session retains long-term stage and consumed dialogue")

 therapy_fixture();app.set_process(false);presenter=Presentation.new(app)
 check(until3(func():return ward_state().therapy.retraction_spoken,15),"actual device, deletion, paper transfer and forced retraction create both local hearings")
 check(ward_state().therapy.heard_original and ward_state().therapy.heard_retraction and not presenter.therapy_cause().is_empty(),"same actual therapy episode supplies both witnessed source receipts without a number invention")
 presenter.tick()
 check(line_count(Presentation.THERAPY_LINE)==0,"the source retraction itself finishes before optional reflection is dispatched")
 check(until3(func():return ward_state().therapy.phase=="done",20),"source questioning and real institutional writing finish without an added standing wait")
 app.hero_route=PackedVector2Array();app.action_phase="autonomy";presenter.tick()
 check(presenter.state().pending.size()==1,"actual therapy reflection remains pending while manually paused")
 check(roundtrip(),"same-episode hearing and pending reflection persist as real disk JSON")
 presenter=Presentation.new(app);var sp:int=app.rules.sp;var hp:int=app.rules.hp;neurons=app.rules.neurons;var resistance:int=app.rules.global_resistance
 app.rules.hp=0;dispatch()
 check(app.dialogue_queue.is_empty() and presenter.state().pending.size()==1,"a dead role cannot speak the pending reflection")
 app.rules.hp=hp;dispatch()
 check(line_count(Presentation.THERAPY_LINE)==1 and presenter.state().spoken.has("therapy_retraction"),"the safe real action gap speaks the exact P1956 retraction reflection once")
 check(app.rules.sp==sp and app.rules.hp==hp and app.rules.neurons==neurons and app.rules.global_resistance==resistance,"reflection adds no damage, recovery, currency, resistance or formal awakening")
 app.update_ui();await capture("01_therapy_reflection")
 check(roundtrip(),"spoken therapy reflection and its current dialogue survive real load")
 presenter=Presentation.new(app);dispatch()
 check(app.dialogue_queue.is_empty() and facts_of("character_reflection")==1,"replaying source-complete frames after restore never duplicates the reflection")

 therapy_fixture(true);app.set_process(false);presenter=Presentation.new(app)
 check(until3(func():return ward_state().therapy.phase=="delete_recording",4),"negative fixture executes original speech outside the protagonist's hearing")
 app.enter_room("group_therapy");app.hero_pos=Vector2(2.8,1.05);app.session.data.exploration_boundary=true
 check(until3(func():return ward_state().therapy.phase=="done",20),"late observer hears only actual retraction from the already running source episode")
 dispatch()
 check(presenter.state().pending.is_empty() and app.dialogue_queue.is_empty(),"hearing only retraction never fabricates the original-testimony reflection")
 app.rules.observe("物品","asylum_heard_original","记得别次的原发言","亲历事实","declared cross-attempt memory fixture")
 dispatch()
 check(presenter.therapy_cause().is_empty() and presenter.state().pending.is_empty(),"remembered one-sided hearing from another attempt cannot be combined into a fully witnessed local episode")

 hospital_fixture("office");app.set_process(false);presenter=Presentation.new(app)
 var all_read:bool=true
 for id in ["case_removal","case_death","case_fees","case_discharge"]:all_read=read_hospital_page(str(id)) and all_read
 check(all_read,"actual contact readers can finish the four original case pages separately")
 dispatch()
 check(not presenter.hospital_cause().is_empty() and presenter.state().spoken.has("hospital_case") and app.hospital.observations.readable_field("case_removal","case_number")==null,"actual four-page authored same-case relation permits the source reflection while concrete number glyphs remain unknown")

 # The original explicitly provides one case's four pages. No synthetic or
 # production patient number is needed to exercise this actual source relation.
 hospital_fixture("lobby");app.set_process(false);presenter=Presentation.new(app)
 spawn_actor("guide",Vector2(2.4,1.4));spawn_actor("wheelchair",Vector2(2.8,1.4));spawn_actor("porter",Vector2(3.15,1.4));app.rules.owners.family_photo="wheelchair"
 app.hero_pos=app.layout.furniture[0].at;app.target_index=0;app.rules.begin_search("lobby:0")
 check(hospital_until(func():return app.hospital.data.get("wheelchair_gone",false),38),"later-stage fixture obtains forced-transfer knowledge only through the actual hospital transport event")
 presenter.tick();check(not presenter.calm_cause().is_empty() and presenter.cold_cause().is_empty(),"a real forced transfer supports steady, but alone proves neither independent false-record class")
 app.enter_room("office");clear_lines();app.hero_route=PackedVector2Array();app.action_phase="autonomy";app.rules.cancel_search();search_index=0
 all_read=true
 for id in ["case_removal","case_death","case_fees","case_discharge"]:all_read=read_hospital_page(str(id)) and all_read
 presenter.tick()
 check(all_read and not presenter.hospital_cause().is_empty() and app.hospital.observations.readable_field("case_removal","case_number")==null,"the actual source-related four-page reader proves its one authored case without inventing any patient-number glyph")
 check(presenter.cold_cause().is_empty(),"hospital contradiction alone does not substitute for the separate asylum contradiction class")
 receipt=integrated_search()
 check(not receipt.is_empty() and presenter.state().stage==1 and presenter.state().stage_receipts["1"].normal_action==receipt,"campaign's real completed-search callback advances at most initial-to-steady without a direct presenter call")
 check(not presenter.normal_action_completed(receipt,"search",app.room_id).ok and presenter.state().stage==1,"reusing the same real action cannot advance another personality stage")
 app.unlock_asylum();app.set_process(false)
 for group in app.asylum.data.groups:app.asylum.data.groups[group].drawn=true
 app.session.data.exploration_boundary=true;app.session.data.asylum_space_versions={};app.room_id="";app.enter_room("group_therapy");app.hero_pos=Vector2(2.8,1.05);app.hero_route=PackedVector2Array();app.action_phase="autonomy"
 actor3("therapist","group_therapy",app.layout.furniture[5].at);actor3("speaker","group_therapy",app.layout.furniture[2].at)
 check(until3(func():return ward_state().therapy.phase=="done",25),"actual chapter carry keeps the hospital proof while a later real therapy episode completes its independent contradiction")
 presenter.tick();check(not presenter.cold_cause().is_empty(),"the two source-specified independent contradiction classes are now objectively paired")
 legacy_door_source=JSON.parse_string(JSON.stringify(app.snapshot_data()))
 receipt=real_search(true);presenter.normal_action_completed(receipt,"search",app.room_id)
 check(presenter.state().stage==1,"having both classes still cannot turn a cancelled action into advancement")
 receipt=integrated_search()
 check(not receipt.is_empty() and presenter.state().stage==2 and presenter.view_state().label=="冷漠" and presenter.state().stage_receipts["2"].normal_action==receipt,"campaign's later real completed-search callback advances cold with both independently proved classes")
 for index in range(8):
  if line_count(Presentation.COLD_LINE)>0:break
  dispatch()
 check(line_count(Presentation.COLD_LINE)==1,"integrated completed-search stage reaches its exact original cold reflection through the safe queue")
 app.update_ui();await capture("02_cold_after_actual_search_callback")
 check(roundtrip() and app.session.data.character_presentation.stage==2,"two-class proof and cold stage survive the existing real disk save")
 presenter=Presentation.new(app)
 check(presenter.state().evidence.has("hospital_case") and presenter.state().evidence.has("therapy_retraction"),"source-paired knowledge persists independently of later local attempts")

 app.unlock_combat();app.unlock_street();app.set_process(false);app.family.enabled=false;clear_lines();app.enter_room("street_plaza")
 for id in app.street.data.actors:app.street.data.actors[id].present=false
 app.layout.furniture.clear();app.layout.rebuild_grid()
 app.rules.hp=100;app.rules.sp=75;app.rules.hurt_left=0;app.rules.stun_left=0;app.rules.effects.clear();app.rules.end_control();app.rules.action.clear();app.rules.transitioning=false
 var father:Dictionary=street_actor("father",Vector2(4,4));father.phase="windup";father.elapsed=0.0;father.direction=[1,0];father.hits={};father.attack_id="declared_character_loss:%d"%app.rules.actual_attempt
 street_actor("dog",Vector2(4.95,4.1));app.hero_pos=Vector2(4.9,4);app.hero_route=PackedVector2Array();app.action_phase="autonomy"
 app.street._advance_attack("father",.8);app.street._advance_attack("father",.3)
 check(app.street.data.actors.dog.hp==0 and app.street.data.speed_deaths.dog.witnessed,"one actual father hit kills one eligible witnessed character; the other six are not required")
 app.paused_manual=false;presenter.normal_action_completed("declared_recovery_not_done","navigation",app.room_id,{"origin":"autonomous","from_position":[4.8,4],"toward":"street_narrow"});app.paused_manual=true
 check(presenter.state().stage==2,"a witnessed death during the ongoing attack is not yet cold-blooded escape")
 var goal:Vector2=app.street.hero_portal("street_narrow").at
 var safe_waypoint:Vector2=goal+app.street.hero_portal("street_narrow").inward
 app.hero_route=app.layout.path(app.hero_pos,safe_waypoint)
 for index in range(4000):
  if app.hero_route.is_empty():break
  app.street.move_hero(.025)
 app.rules.hurt_left=0;app.rules.stun_left=0;app.action_phase="autonomy"
 check(app.hero_pos.distance_to(safe_waypoint)<.04,"a real collision-checked route first leaves the attack and reaches the existing door's interior approach")
 app.street.losses.tick(.1);drain_real_dialogue()
 check(not presenter.witnessed_street_loss().is_empty(),"actual witnessed loss plus acknowledged original madness, not a generic death counter, supplies later-stage evidence")
 while not presenter.state().pending.is_empty():dispatch();drain_real_dialogue()
 var start:Vector2=app.hero_pos
 app.paused_manual=false
 presenter.normal_action_completed("declared_controlled_endpoint","navigation",app.room_id,{"origin":"controlled","from_position":[start.x,start.y],"toward":"street_narrow"})
 check(presenter.state().stage==2,"player-directed endpoint alone does not claim the character chose to continue escape")
 presenter.normal_action_completed("declared_wrong_branch_endpoint","navigation",app.room_id,{"origin":"autonomous","from_position":[start.x,start.y],"toward":"street_side"})
 check(presenter.state().stage==2,"walking into the optional side branch is not presented as exitward progress")
 app.hero_route=app.layout.path(app.hero_pos,goal)
 for index in range(1000):
  if app.hero_route.is_empty():break
  app.street.move_hero(.025)
 check(app.hero_pos.distance_to(goal)<.04 and presenter.state().stage==2,"ordinary Street door-at arrival alone cannot promote the already-cold character")
 app.street._hero(.025)
 for index in range(300):
  if app.room_id=="street_narrow":break
  app.street._hero(.025)
 app.paused_manual=true
 check(app.room_id=="street_narrow" and presenter.state().stage==3 and presenter.view_state().prioritize_escape and str(presenter.state().stage_receipts.get("3",{}).get("normal_action","")).begins_with("street_door:"),"real successful Street cross-door callback advances cold-blooded from one witnessed eligible loss, without a direct presenter call")
 dispatch();check(line_count(Presentation.UNSPARING_LINE)==1,"integrated actual Street endpoint produces the exact escape-priority reflection after original loss feedback")
 app.keep_metric_actor_visible();app.update_ui();await capture("03_unsparing_after_actual_street_callback")
 check(roundtrip() and app.session.data.character_presentation.stage==3,"final long-term presentation persists without resetting actual Street deaths or its movement gain")
 presenter=Presentation.new(app)
 while not presenter.state().pending.is_empty():dispatch();drain_real_dialogue()
 check(presenter.state().spoken.has("cold") and presenter.state().spoken.has("unsparing") and facts_of("character_stage_changed")==3,"all three stages keep exact source feedback once, without extra formal awakening")

 # The real Street-revival handler returns through the retained L5 snapshot.
 # Only the initial body/observer placement is a finite comparison fixture.
 app.restart_street(3);app.set_process(false);clear_lines();app.enter_room("hippocampus")
 for id in app.combat.data.actors:app.combat.data.actors[id].present=false;app.combat.data.actors[id].pending=false
 var reader=app.combat.observations;var prop_index:int=-1
 for index in range(app.layout.furniture.size()):
  if not reader.entry(str(app.layout.furniture[index].id)).is_empty():prop_index=index;break
 check(prop_index>=0,"source-defined retained L5 return room has a real static record candidate")
 var prop:Dictionary=app.layout.furniture[prop_index];var original:Dictionary=reader.entry(str(prop.id));var stand:Vector2=reader.station(prop.rect)
 app.hero_pos=stand;app.hero_route=PackedVector2Array();app.action_phase="autonomy"
 app.advance_world(.025)
 check(not app.combat.data.inspection.is_empty() and not app.combat.data.inspection.controlled,"ordinary combat scheduling still stops for a genuinely unread static original at stage3")
 for index in range(200):
  if app.combat.data.inspected.get(str(original.id),{}).has(str(prop.id)):break
  step3()
 var static_id:String="combat_evidence:"+str(original.id)+":"+str(prop.id)
 check(presenter.actually_observed(static_id),"normal staged reading really completes the same stable static original before any repeat is suppressed")
 app.restart_street(3);app.set_process(false);clear_lines();app.enter_room("hippocampus")
 for id in app.combat.data.actors:app.combat.data.actors[id].present=false;app.combat.data.actors[id].pending=false
 reader=app.combat.observations;app.combat.data.inspected={}
 prop=app.layout.furniture[prop_index];stand=reader.station(prop.rect);app.hero_pos=stand;app.hero_route=PackedVector2Array();app.action_phase="autonomy"
 app.advance_world(.025)
 check(presenter.state().stage==3 and app.combat.data.inspection.is_empty(),"normal return scheduling skips the already-known static original across an actual attempt transition")
 app.hero_pos=stand;app.hero_route=PackedVector2Array();give_skill("CONTROL");cast("CONTROL");clear_lines()
 check(app.rules.control_left>0 and reader.begin(prop_index,true),"real paid CONTROL can deliberately inspect the known static original; escape priority blocks no player command")
 reader.cancel();app.rules.end_control();app.rules.effects.clear();app.hero_route=PackedVector2Array();app.hero_pos=stand;clear_lines()
 presenter.state().stage=2
 app.advance_world(.025)
 check(not app.combat.data.inspection.is_empty(),"declared pre-stage3 comparison retains the existing autonomous repeat-read behavior")
 reader.cancel();presenter.state().stage=3;clear_lines()
 app.unlock_street();app.enter_room("street_maintenance")
 for id in app.street.data.actors:app.street.data.actors[id].present=false
 var surface:Dictionary=app.street.materials.state().surfaces.street_maintenance_label
 var at:Vector2=app.street.vector(surface.pos);var surface_reader=app.street.observations
 app.hero_pos=surface_reader.station(Rect2(at-Vector2(.08,.05),Vector2(.16,.1)));app.hero_route=PackedVector2Array();app.action_phase="autonomy"
 app.advance_world(.025)
 check(app.street.data.inspection.get("surface",false) and app.street.data.inspection.get("prop","")=="street_maintenance_label","ordinary stage3 Street scheduling still accepts a newly available real dynamic fallen label")
 legacy_door_chain_case()
 var final:Dictionary={"passes":passes,"failures":failures,"methods":{"declared_actor_contact_fixtures":true,"production_source_events":true,"real_search_completion_and_cancellation":true,"actual_checksummed_disk_json":true,"hospital_positive_comparison_uses_only_T17R5_authored_relation":true,"manual_natural_play":false,"formal_art_accepted":false},"scope":"All four presentation stages: actual formal awakening/forced transfer, same-episode therapy reflection, source-related four original hospital pages with null numeral glyphs, two independent contradiction classes, and one actual witnessed qualified Street death followed by original loss feedback and successful exitward door crossing. Actual campaign completed-search/Street cross-door callbacks advance later stages. Legacy fully evidenced mid-door snapshots verify that ordinary at/threshold movement is unfinished, one real room crossing advances at most one stage, and the no-destination final gate allows only its first interior endpoint completion across save/load. Normal combat scheduling skips known static originals on a later return, while unread originals, dynamic surfaces, controlled inspection and the pre-stage3 behavior remain available. No fabricated number is supplied. Finite source branch checks do not claim natural-RNG branch occurrence or formal stance art acceptance.","source":"S3:T17R5/T59R2–5/P1950–1957"}
 var file=FileAccess.open(ProjectSettings.globalize_path(folder).path_join("result.json"),FileAccess.WRITE);file.store_string(JSON.stringify(final,"  "));file.close()
 print("CHARACTER_PRESENTATION_CHECK %d passed %d failed"%[passes.size(),failures.size()]);frontend.request_exit(0 if failures.is_empty() else 1)
