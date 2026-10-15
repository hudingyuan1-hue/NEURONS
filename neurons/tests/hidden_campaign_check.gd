extends "res://tests/family_check.gd"
## Real rendered campaign and real running frames. Only initial household,
## owned-item and final fatal-contact setups are fixed; all drag, transition,
## escape, pause, save/load and ending handling use production code.
var initial_snapshot:Dictionary={}
var middle_snapshot:Dictionary={}
var timeline:Array=[]

func await_live(predicate:Callable,timeout:float=15.0,continue_lines:bool=true) -> bool:
 var elapsed:float=0
 var caption_left:float=0
 while elapsed<timeout:
  if predicate.call():return true
  if continue_lines and not app.dialogue_queue.is_empty():
   caption_left-=get_process_delta_time()
   if caption_left<=0:
    var next:Button=find_button(app,"继续 / Enter")
    if next!=null:await click(next)
    else:await key(KEY_ENTER)
    caption_left=0.16
  await get_tree().process_frame
  elapsed+=get_process_delta_time()
 return predicate.call()

func key(code:Key) -> void:
 for down in [true,false]:
  var event:=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=down
  Input.parse_input_event(event);await frames(1)

func find_button(root:Node,text:String) -> Button:
 for child in root.get_children():
  if child is Button and child.text==text:return child
  var found:Button=find_button(child,text)
  if found!=null:return found
 return null

func click(button:BaseButton) -> void:
 if button==null:check(false,"required production button exists");return
 var point:Vector2=button.get_global_rect().get_center()
 var move:=InputEventMouseMotion.new();move.position=point;move.global_position=point;Input.parse_input_event(move)
 await frames(1)
 for down in [true,false]:
  var event:=InputEventMouseButton.new();event.position=point;event.global_position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down
  Input.parse_input_event(event);await frames(1)

func save_and_load() -> Dictionary:
 await click(find_button(app,"保存"))
 await frames(2)
 var disk:Dictionary=app.store.load_snapshot()
 check(disk.ok,"production Save button creates checksummed JSON in independent test root")
 if not disk.ok:return {}
 var previous=app.rules
 await click(find_button(app,"读取"))
 await frames(2)
 check(app.rules!=previous,"production Load button reconstructs rule instance from actual JSON")
 return disk.data

func trace(label:String) -> void:
 timeline.append({"label":label,"world_time":app.rules.world_time,"room":app.room_id,"hp":app.rules.hp,"sp":app.rules.sp,"N":app.rules.neurons,"C":app.rules.plexus,"hero":[app.hero_pos.x,app.hero_pos.y],"hidden":app.hidden_route.data.duplicate(true)})

func finish_run() -> void:
 var result:=FileAccess.open(ProjectSettings.globalize_path(folder).path_join("result.json"),FileAccess.WRITE)
 result.store_string(JSON.stringify({"passes":passes,"failures":failures,"rendered":true,"real_clock_frames":true,"scope":"Actual campaign, fixed father presence/clear initial position/key and owned candy; actual approach/grab/drag, real inputs, real saved JSON, zero-resource autonomous live-hunter escape; separate fixed fatal-contact setup. Graybox art, silent movie, not human playthrough or complete B2 acceptance.","timeline":timeline},"  "));result.close()
 print("HIDDEN_CAMPAIGN_CHECK %d passed %d failed"%[passes.size(),failures.size()])
 app.paused_manual=true;app.audio.reset_scene()
 frontend.remove_child(app);app.queue_free();frontend.active=null;app=null
 await frames(4)
 frontend.request_exit(0 if failures.is_empty() else 1)

func _ready() -> void:
 folder="res://../docs/validation/b2_hidden_20261016/campaign"
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--validation-root="):folder=argument.trim_prefix("--validation-root=")
 name="CampaignCheck";frontend=get_parent()
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 await frames(3)
 if is_instance_valid(frontend.startup_opening):frontend.startup_opening.skip()
 await frames(2);frontend.show_profile();await frames(3)
 frontend.name_field.text="隐藏分支实机验证";frontend.overwrite_armed=true;frontend.new_game();await frames(4)
 app=frontend.active
 if app.opening_ui!=null:app.opening_ui.skip()
 if app.tutorial_ui!=null:app.tutorial_ui.finish()
 await frames(2)
 app.hidden_route.data.clear();fixture()
 app.rules.hp=74;app.rules.sp=86;app.rules.neurons=0;app.rules.plexus=0
 app.session.data.key_owner="hero";app.rules.owners.key="hero"
 var item:String=app.family.ensure_food("candy","hero")
 app.family.data.inventory.append(item)
 app.hero_pos=Vector2(4.45,0.65);app.hero_route=PackedVector2Array()
 app.family.spawn("father")
 initial_snapshot=app.snapshot_data();trace("fixed_household_start")
 await capture("01_father_arrival")
 app.paused_manual=false;get_window().grab_focus()
 var grabbed:bool=await await_live(func():return app.rules.gripped,18)
 check(grabbed and app.family.data.blood_door,"father actually approaches, winds up and establishes original grip/blood door")
 check(app.session.data.level==1 and app.has_key() and not 2 in app.session.data.unlocked,"already-owned key cannot replace father blood-door route with hospital")
 if not grabbed:await finish_run();return
 await key(KEY_ESCAPE)
 check(app.paused_manual,"actual Escape key pauses established father grip")
 await capture("02_actual_father_grip")
 var frozen:float=app.rules.world_time
 await frames(12)
 check(app.rules.world_time==frozen and app.rules.gripped,"world pause freezes father pressure and drag before hidden transition")
 await key(KEY_ESCAPE)
 var entered:bool=await await_live(func():return app.room_id=="hidden_street",15)
 check(entered,"actual stabilizing and drag cross blood door and load independent hidden plaza")
 if not entered:trace("entry_failed");await finish_run();return
 await key(KEY_ESCAPE)
 check(app.rules.mode=="combat" and app.world_rate()==1.0 and not app.rules.gripped and not app.family.present("father"),"hidden entry ends father grip/half-rate/pressure and switches to combat")
 check(app.rules.hp==74 and app.rules.sp<=86 and app.rules.sp>70,"hidden entry preserves actual HP and SP already lost to father pressure")
 check(app.rules.neurons==0 and app.rules.plexus==0 and app.rules.owners[item]=="hero","hidden entry preserves zero resources and unique owned candy")
 check(app.session.data.level==1 and app.session.data.unlocked==[1] and app.visible_doors.is_empty() and not app.key_visible(),"hidden route remains L1, grants no hospital/L6 unlock and does not create a key task")
 check(app.layout.furniture[0].id=="fountain" and not app.layout.clear_segment(Vector2(1.5,1.8),Vector2(4,1.8)),"actual 2D layout contains solid, sight-blocking fountain")
 check(app.hidden_route.data.hunter.hp==60 and app.hidden_route.data.hunter.phase in ["chase","windup"],"actual living hunter perceives and pursues after entry")
 trace("hidden_entry");await capture("03_hidden_plaza_live_hunter")
 frozen=app.rules.world_time
 var hunter_position:Array=app.hidden_route.data.hunter.pos.duplicate()
 await frames(15)
 check(app.rules.world_time==frozen and app.hidden_route.data.hunter.pos==hunter_position,"manual pause freezes rendered hunter position and world clock")
 await key(KEY_ESCAPE)
 var midway:bool=await await_live(func():return app.rules.world_time>frozen+1.0 or app.hidden_route.data.status!="active",4)
 check(midway and app.hidden_route.data.status=="active","zero-resource autonomous escape advances normally before exit")
 if app.hidden_route.data.status!="active":trace("premature_ending");await finish_run();return
 await key(KEY_ESCAPE)
 var hero_position:Vector2=app.hero_pos
 hunter_position=app.hidden_route.data.hunter.pos.duplicate()
 var phase:String=app.hidden_route.data.hunter.phase
 frozen=app.rules.world_time
 middle_snapshot=await save_and_load()
 check(not middle_snapshot.is_empty() and app.room_id=="hidden_street" and app.paused_manual and is_equal_approx(app.rules.world_time,frozen),"half-route actual JSON restores hidden map and paused world clock")
 check(app.hero_pos.distance_to(hero_position)<0.00001 and app.hidden_route.vector(app.hidden_route.data.hunter.pos).distance_to(app.hidden_route.vector(hunter_position))<0.00001 and app.hidden_route.data.hunter.phase==phase,"half-route JSON preserves both bodies, AI phase and pursuit state")
 check(app.rules.mode=="combat" and app.rules.owners[item]=="hero" and app.hidden_route.data.hunter.hp==60,"load neither duplicates owned item nor resets enemy HP/mode")
 trace("mid_route_json_restored");await capture("04_mid_route_saved_and_loaded")
 await key(KEY_ESCAPE)
 var ended:bool=await await_live(func():return app.hidden_route.data.get("status","")=="ending",12)
 check(ended and app.rules.hp>0,"zero-resource autonomous body escapes living hunter through actual E1 exit")
 if not ended:trace("escape_failed");await finish_run();return
 check(int(app.hidden_route.data.hunter.hp)==60 and int(app.session.data.level)==1 and app.session.data.unlocked.size()==1 and int(app.session.data.unlocked[0])==1,"E1 does not require killing hunter or grant hospital/L6 unlock")
 await key(KEY_ESCAPE)
 await capture("05_E1_plaza_first_beat")
 var ending_elapsed:float=app.hidden_route.data.ending.elapsed
 frozen=app.rules.world_time;await frames(15)
 check(app.rules.world_time==frozen and app.hidden_route.data.ending.elapsed==ending_elapsed,"Escape pause freezes separate ending presentation as well as world")
 var global:Dictionary=app.achievements.load_progress()
 check(global.ok and global.data.unlocked.has("hidden_clear") and global.data.unlocked.has("host_wins") and global.data.unlocked.size()==2,"actual exit persists exactly the two E1 global achievements")
 var receipt_count:int=global.data.receipts.size()
 var ending_disk:Dictionary=await save_and_load()
 check(app.hidden_route.data.status=="ending" and is_equal_approx(app.hidden_route.data.ending.elapsed,ending_elapsed),"actual ending JSON restores the same light/wake presentation phase")
 check(app.achievements.load_progress().data.receipts.size()==receipt_count,"ending JSON/replay does not duplicate global achievement receipt")
 await key(KEY_ESCAPE)
 check(await await_live(func():return app.hidden_route.ending_frame().get("phase","")=="bed",4),"first plaza beat actually reaches reality-bed wake-up placeholder")
 await capture("06_E1_reality_bed_wake")
 check(await await_live(func():return app.hidden_route.ending_frame().get("complete",false),4),"ending presentation completes without auto revival or hospital transition")
 trace("E1_complete");await capture("07_E1_complete")
 check(is_equal_approx(app.rules.world_time,frozen) and app.rules.owners[item]=="hero","ending retains frozen world, body values and previously owned inventory")

 # Separate actual-contact fixture exercises production death presentation
 # and real L1 revival (not direct hit). Same-node fatal exit precedence is
 # covered separately in test_hidden.gd, not claimed for this GPU segment.
 check(app.store.save_snapshot(middle_snapshot).ok,"older half-route profile is restored independently from global progress")
 var disk:Dictionary=app.store.load_snapshot()
 check(disk.ok and app.restore_snapshot(disk.data),"production JSON restores pre-E1 route while global record remains earned")
 app.hero_pos=Vector2(1.7,0.9);app.hero_route=PackedVector2Array();app.rules.hp=15
 app.hidden_route.data.hunter.pos=[1.3,0.9]
 app.hidden_route.data.hunter.phase="attack";app.hidden_route.data.hunter.elapsed=0
 app.hidden_route.data.hunter.direction=[1,0];app.hidden_route.data.hunter.attack_id="gpu:fatal-contact"
 app.hidden_route.data.hunter.attack_hit=false;app.hidden_route.data.hunter.attack_had_target=true
 var cycle:int=app.session.data.cycle;var invader:int=app.invader_id;var attempt:int=app.rules.actual_attempt
 await capture("08_separate_fatal_contact_setup")
 await key(KEY_ESCAPE)
 check(await await_live(func():return app.rules.hp<=0,2,false),"actual rendered hunter attack commits fatal body contact")
 trace("actual_fatal_contact");await capture("09_hidden_death")
 check(await await_live(func():return app.room_id=="bedroom" and app.rules.hp==100,5,false),"hidden death actually revives in first bedroom instead of hospital/fourth/sixth level")
 check(app.session.data.cycle==cycle+3 and app.invader_id==invader+1 and app.rules.actual_attempt==attempt+1,"hidden death adds three total cycles, one invader ID and one actual L1 attempt")
 check(app.rules.mode=="exploration" and app.hidden_route.data.is_empty() and app.rules.neurons==5 and app.rules.plexus==0,"revival uses existing 5N floor without hidden scene/unlock cluster rewards")
 check(app.achievements.load_progress().data.unlocked.size()==2 and app.achievements.load_progress().data.receipts.size()==receipt_count,"restoring older profile and dying cannot remove or duplicate earned global E1 achievements")
 trace("L1_revival");await capture("10_L1_actual_revival")
 await finish_run()
