extends "res://tests/asylum_check.gd"
## Finite B4 exploration fixtures; NPC events are isolated in separate suites.
## Physical movement/search/contact, actual JSON and real UI input are retained.
const CMap=preload("res://scripts/core/cortex_map.gd")
const CLayout=preload("res://scripts/world/cortex_layout.gd")
const FIXED_TARGETS=["atrium:0","atrium:1","atrium:2","memory:0","memory:1","visual:0","decision:0","body:0",
 "bridge:0","bridge:1","rhythm:0","index:0","switch:0","verify:0","identity:0","identity:6"]
var traversed:Array=[]

func fixture4(room:String="atrium") -> void:
 app.rules=Neural.new();app.menu.rules=app.rules
 app.session=Session.new();app.session.data.unlocked=[1,2,3,4];app.session.new_attempt(4,app.rng)
 app.session.data.targets=FIXED_TARGETS.duplicate();app.session.data.key_target="identity:6";app.session.data.key_owner="identity:6"
 app.rules.actual_attempt=1;app.rules.search_limit=16;app.rules.allow_supplemental_search=true;app.rules.owners.key="identity:6"
 app.home.enabled=false;app.family.enabled=false;app.hospital.enabled=false;app.asylum.enabled=false;app.cortex.enabled=false
 app.cortex.data={};app.cortex.start_attempt({})
 app.completed.clear();app.deferred_targets.clear();app.motion.clear();app.death_left=0
 app.room_id="";app.enter_room(room)
 app.hero_pos=CMap.SPAWN if room=="atrium" else CMap.doorway(room,str(CMap.doors(room)[0]))
 app.hero_route=PackedVector2Array();app.target_index=-1;app.action_phase="autonomy";app.hero_state="idle"
 app.paused_manual=true;app.menu.close_menu();app.closing_left=0;clear_lines()

func walk_to_room(target:String) -> bool:
 for guard in range(20):
  if app.room_id==target:return true
  var before:String=app.room_id
  var next:String=CMap.next_room(before,target)
  if next.is_empty():return false
  app.route_to_door(next)
  if not until3(func():return app.room_id!=before,30):return false
  traversed.append(app.room_id)
 return app.room_id==target

func move_actual_to(point:Vector2) -> bool:
 app.hero_route=app.layout.path(app.hero_pos,point)
 if app.hero_route.is_empty():return app.hero_pos.distance_to(point)<0.035
 for i in range(4000):
  if app.hero_route.is_empty():break
  app.move_hero(0.025)
 return app.hero_pos.distance_to(point)<0.035 and app.hero_route.is_empty()

func click_world(point:Vector2,shift:bool=false) -> void:
 var screen:Vector2=(app.world_viewport.get_canvas_transform()*app.layout.project(point))*2.0
 var motion:=InputEventMouseMotion.new();motion.position=screen;motion.global_position=screen;Input.parse_input_event(motion)
 await frames(2)
 for down in [true,false]:
  var event:=InputEventMouseButton.new();event.position=screen;event.global_position=screen
  event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;event.shift_pressed=shift
  Input.parse_input_event(event);await frames(2)

func finish4() -> void:
 var file:=FileAccess.open(ProjectSettings.globalize_path(folder).path_join("result.json"),FileAccess.WRITE)
 file.store_string(JSON.stringify({"passes":passes,"failures":failures,"rendered":true,"traversed":traversed,
  "fixtures":"Original L3 keyed exit fixture; independent L4 initial 8+8 public targets and key at identity:6; NPC events disabled. Sixteen genuinely begun/cancelled searches, then seventeenth completion. One paid CONTROL with actual Shift mouse. Explicit zero-SP and lethal-HP initial conditions.",
  "scope":"B4 real exploration handlers, metre movement/collision, both-floor doors, search time, real checksummed JSON, pause, once-only rewards, revival and keyed B5 development boundary. Deterministic small-step simulation plus real rendered/input/ordinary-process death frames; not natural-RNG full play, all NPC combinations or formal art/audio acceptance."},"  "));file.close()
 print("CORTEX_CHECK %d passed %d failed"%[passes.size(),failures.size()])
 frontend.request_exit(0 if failures.is_empty() else 1)

func _ready() -> void:
 folder="res://../docs/validation/b4_20261016/exploration"
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--validation-root="):folder=argument.trim_prefix("--validation-root=")
 name="CampaignCheck";frontend=get_parent();DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 await frames();frontend.show_profile();await frames();frontend.name_field.text="脑部两层探索验证"
 frontend.overwrite_armed=true;frontend.new_game();await frames();app=frontend.active
 if app.tutorial_ui!=null:app.tutorial_ui.finish()
 fixture3("stairs");app.cortex.enabled=false
 app.rules.owners.key="hero";app.session.data.key_owner="hero"
 var neurons:int=app.rules.neurons;var clusters:int=app.rules.plexus;var cycle:int=app.session.data.cycle
 app.session.data.exploration_boundary=false;app.route_to_door("cortex_exit")
 check(until3(func():return int(app.session.data.level)==4,30),"normal keyed L3 stair contact really enters L4")
 check(app.room_id=="atrium" and app.hero_pos.distance_to(CMap.SPAWN)<0.05,"L4 entry is original atrium wake point")
 check(app.rules.neurons==neurons+3 and app.rules.plexus==clusters+2 and int(app.session.data.cycle)==cycle,"first L4 unlock gives exact 3N/2C once, no cycle")
 var first:int=0;var second:int=0
 for id in app.session.data.targets:
  if str(id).get_slice(":",0) in CMap.FIRST_ROOMS:first+=1
  elif str(id).get_slice(":",0) in CMap.SECOND_ROOMS:second+=1
 check(first==8 and second==8 and app.rules.search_limit==16,"sixteen public targets are sampled eight per floor")
 check(CMap.candidates().size()==62 and app.session.data.key_target in app.session.data.targets,"unique key is one of original sixty-two and inside the fixed sample")
 var initial_targets:Array=app.session.data.targets.duplicate();var initial_key:String=app.session.data.key_target
 check(roundtrip() and app.session.data.targets==initial_targets and app.session.data.key_target==initial_key,"actual L4 entry JSON preserves sample/key")
 check(app.rules.neurons==neurons+3 and app.rules.plexus==clusters+2,"entry JSON does not repeat unlock award")
 await capture("01_actual_L3_to_L4_atrium")

 # Isolated physical floor layouts. Each starting stand is declared; every
 # tested destination is reached by the same movement method as normal play.
 for room in CMap.ALL_ROOMS:
  fixture4(room)
  for door in CMap.doors(room):check(move_actual_to(CMap.doorway(room,door)),"physical movement to door %s -> %s"%[room,door])
  for item in app.layout.furniture:check(move_actual_to(item.at),"physical movement to search stand "+str(item.id))
 fixture4();traversed=[app.room_id]
 check(walk_to_room("identity") and traversed.has("decision") and traversed.has("bridge") and traversed.has("rhythm"),"actual floor crossing uses decision rear and bridge/rhythm path")
 check(walk_to_room("memory") and traversed.count("bridge")>=2 and traversed.count("decision")>=2,"real reverse route returns from white matter to cortex")
 check(CMap.doors("body")==["atrium"] and CMap.next_room("body","bridge")=="atrium","body room has no invented floor exit")
 check(CMap.next_room("atrium","ward").is_empty(),"L4 has no return to replaced hospital/asylum")
 await capture("02_physical_two_floor_return")

 fixture4("memory");app.hero_pos=Vector2(1.25,1.05)
 var target:String="memory:0"
 check(until3(func():return app.rules.search_active,6) and app.point_id(app.target_index)==target,"autonomous hero physically approaches intended original file rack")
 check(is_equal_approx(app.rules.search_duration,7.0) and app.rules.search_attempts==1,"standard L4 search uses original seven seconds and start cost")
 step3(1.0);var elapsed:float=app.rules.search_elapsed;neurons=app.rules.neurons
 check(roundtrip() and is_equal_approx(app.rules.search_elapsed,elapsed) and app.rules.search_attempts==1,"mid-search real JSON keeps elapsed time/attempt")
 var clock:float=app.rules.world_time;await frames(12)
 check(is_equal_approx(app.rules.world_time,clock) and is_equal_approx(app.rules.search_elapsed,elapsed),"manual pause freezes world and active search")
 check(until3(func():return target in app.completed,8),"resumed actual seven-second action finishes")
 check(app.rules.neurons==neurons+1,"completion grants one neuron exactly")
 check(roundtrip(),"completed point actual JSON reloads")
 step3(.1);check(app.rules.neurons==neurons+1 and app.session.data.key_target=="identity:6","reload and further tick do not reward again or reroll key")
 await capture("03_search_prepare_contact_complete")

 fixture4("memory");app.hero_pos=app.layout.furniture[0].at
 var sampled:Array=app.session.data.targets.duplicate();var key:String=app.session.data.key_target
 neurons=app.rules.neurons;cycle=app.session.data.cycle
 var cancel_ok:bool=true
 for index in range(16):
  if not until3(func():return app.rules.search_active,2):cancel_ok=false;break
  step3(.1)
  app.rules.cancel_search();app.hero_route=PackedVector2Array();app.target_index=-1;app.action_phase="autonomy"
 check(cancel_ok and app.rules.search_attempts==16 and not target in app.completed,"sixteen actual start/cancel windows consume starts without fake completion")
 check(app.rules.neurons==neurons and app.session.data.targets==sampled and app.session.data.key_target==key,"cancellation does not give rewards, reroll sample or move unique key")
 check(roundtrip(),"exhausted initial sixteen starts survive actual JSON")
 check(until3(func():return target in app.completed,10) and app.rules.search_attempts==17,"seventeenth supplemental search really completes the same unfinished target")
 check(app.rules.neurons==neurons+1 and int(app.session.data.cycle)==cycle and int(app.rules.actual_attempt)==1,"supplement grants actual completion only, no rest or new attempt")
 await capture("04_seventeenth_search_no_rest")

 fixture4("memory");app.hero_pos=Vector2(1.25,1.05);app.rules.neurons=0;app.rules.sp=1
 app.rules.change_sp(-1);var stopped:Vector2=app.hero_pos
 check(app.rules.stun_left>0.99,"first real SP drop to zero begins one-second loss of action")
 step3(.5);check(app.hero_pos.distance_to(stopped)<.001 and not app.rules.search_active,"zero-SP first half-second cannot sneak movement/search")
 step3(.6);check(app.rules.neurons==0 and app.rules.stun_left<=0,"after one second there is no invented exploration energy regeneration")
 check(until3(func():return target in app.completed,15),"zero-resource zero-SP hero resumes real autonomous search without bed or healer")
 check(app.rules.sp==0 and app.rules.neurons==1 and app.session.data.cycle==1,"low-SP completion gives only ordinary +1N, no healing/cycle")
 check(app.rules.mode=="exploration" and app.rules.combat_regen==0,"B4 has no combat regeneration")

 fixture4("memory");app.hero_pos=Vector2(1.25,2.45);give_skill("CONTROL")
 sampled=app.session.data.targets.duplicate();neurons=app.rules.neurons
 app.paused_manual=false;app.open_neuron_menu();await click(app.menu.nodes.CONTROL)
 check(await await_live(func():return app.rules.control_left>0 and not app.menu.visible and app.closing_left<=0,5),"actual CRT mouse starts paid CONTROL")
 while not app.dialogue_queue.is_empty():await continue_live_line()
 await click_world(app.layout.furniture[2].rect.get_center(),true)
 app.paused_manual=true
 check(app.action_phase=="controlled_search" or app.rules.search_active,"real Shift mouse selects non-sampled rug search")
 check(until3(func():return "memory:2" in app.completed,12),"controlled non-sampled search physically approaches and completes")
 check(app.session.data.targets==sampled and not "memory:2" in sampled and app.session.data.key_target=="identity:6","controlled extra target does not alter original sample or unique key")
 check(app.rules.neurons==neurons-int(app.rules.spec("CONTROL").cost)+1,"paid control cost and one real extra completion are exact")
 await capture("05_paid_control_unsampled_point")

 fixture4("identity");var invader:int=app.invader_id;var attempt:int=app.rules.actual_attempt
 cycle=app.session.data.cycle;app.rules.neurons=0;app.rules.hp=0;app.paused_manual=false
 check(await await_live(func():return app.rules.actual_attempt>attempt,8),"ordinary process performs actual L4 death presentation and revival")
 app.paused_manual=true;clear_lines()
 check(app.room_id=="atrium" and app.hero_pos.distance_to(CMap.SPAWN)<.05,"L4 death returns to original atrium, never new second-floor bed")
 check(app.rules.actual_attempt==attempt+1 and app.session.data.cycle==cycle+3 and app.invader_id==invader+1,"actual revival increments L4 attempt once, total cycle three and intruder one")
 check(app.rules.hp==100 and app.rules.sp==100 and app.rules.neurons==5,"revival uses original vitality reset and minimum five neurons")
 var snapshot:Dictionary=app.snapshot_data();app.finish_rest();app.restart_attempt(1,false)
 check(app.session.data.cycle==snapshot.session.cycle and app.rules.actual_attempt==snapshot.rules.actual_attempt,"L4 rest handlers cannot introduce a new rest or cycle")

 fixture4();app.session.data.key_target="atrium:1";app.session.data.key_owner="atrium:1";app.rules.owners.key="atrium:1"
 traversed=["atrium"];clusters=app.rules.plexus
 var reached:bool=false
 for index in range(16000):
  if app.session.data.exploration_boundary:reached=true;break
  var before:String=app.room_id;step3()
  if app.room_id!=before:traversed.append(app.room_id)
 check(reached and app.has_key() and app.rules.owners.key=="hero","autonomous first-floor found key is actually picked up before real final exit")
 check(traversed.has("decision") and traversed.has("bridge") and app.room_id=="verify","first-floor key still traverses decision/bridge to second-floor verification exit")
 check(app.hero_pos.distance_to(CMap.doorway("verify","combat_exit"))<.05,"exit boundary is actual lock-door position")
 check(app.rules.plexus==clusters and app.session.data.level==4,"B5 development boundary does not pretend to finish B5 or give its unlock")
 await capture("06_actual_keyed_exit_development_boundary")
 var source:String=FileAccess.get_file_as_string("res://scripts/campaign.gd")
 var chooser:String=source.get_slice("func choose_public_target(delta:float) -> void:",1).get_slice("\nfunc ",0)
 var executable:String=""
 for line in chooser.split("\n"):
  if not line.strip_edges().begins_with("#"):executable+=line+"\n"
 check(not executable.contains("key_target") and not chooser.is_empty(),"public autonomous target selector does not inspect hidden key position")
 finish4()
