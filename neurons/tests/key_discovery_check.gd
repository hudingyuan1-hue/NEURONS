extends "res://tests/asylum_check.gd"
## Fixed seeds and initial schedules never preplace a new gameplay key.
## Walking, searches, contact, interruption, rest and doors use real handlers.
const Cortex=preload("res://scripts/core/cortex_map.gd")
var visited_rooms:Array=[]
var cases:Array=[]

func key_fixture(level:int=1,room:String="bedroom") -> void:
 app.rules=Neural.new();app.menu.rules=app.rules
 app.session=Session.new();app.session.data.unlocked=range(1,level+1)
 app.session.data.key_seed_root="gpu-key-v2-root:"+str(level);app.session.new_attempt(level,app.rng)
 app.rules.actual_attempt=1;app.rules.search_limit=[10,12,14,16][level-1];app.rules.allow_supplemental_search=level==4
 app.rules.owners.key=""
 app.home.enabled=false;app.family.enabled=false;app.hospital.enabled=false;app.asylum.enabled=false;app.cortex.enabled=false
 app.completed.clear();app.deferred_targets.clear();app.motion.clear();app.death_left=0
 app.search_actions.states.clear();app.search_actions.receipts.clear();app.search_actions.observing_index=-1
 app.first_damage=false;app.first_damage_pending=false
 app.room_id="";app.enter_room(room)
 app.home.start_attempt({"dog":false,"cat":false,"cat_point":1});app.family.start_attempt()
 app.cortex.data={};app.cortex.start_attempt({})
 app.hero_route=PackedVector2Array();app.target_index=-1;app.action_phase="autonomy";app.hero_state="idle"
 app.paused_manual=true;app.menu.close_menu();app.closing_left=0;clear_lines()

func bedroom_sample() -> void:
 # Ten legal sampled points. The fan remains searchable outside the group.
 var targets:Array=[]
 for index in range(10):targets.append("bedroom:%d"%index)
 app.session.data.targets=targets
 app.session.data.key_discovery=app.session.key_rules.begin(1,1,"gpu-key-v2",targets)

func focus_initial_target(index:int) -> void:
 # Initial target selection only; no actor position or contact is changed.
 app.target_index=index;app.hero_route=app.layout.path(app.hero_pos,app.layout.furniture[index].at)

func same_saved_verdict(before:Dictionary,after:Dictionary) -> bool:
 if before.is_empty() or after.is_empty():return false
 for key in ["receipt","finder","eligible","found","guaranteed","evidence"]:
  if before.get(key)!=after.get(key):return false
 return is_equal_approx(float(before.get("probability",-1)),float(after.get("probability",-2))) and is_equal_approx(float(before.get("draw",-1)),float(after.get("draw",-2)))

func choose_seed(must_hit:Array,must_miss:Array) -> String:
 var state:Dictionary=app.session.data.key_discovery
 var original:String=str(state.seed)
 for number in range(100000):
  state.seed="gpu-key-v2:"+str(number)
  var valid:bool=true
  for target in must_hit:
   if app.session.key_rules.draw(state,str(target))>=app.session.key_rules.probability(state,str(target)):valid=false;break
  if valid:
   for target in must_miss:
    if app.session.key_rules.draw(state,str(target))<app.session.key_rules.probability(state,str(target)):valid=false;break
  if valid:return str(state.seed)
 state.seed=original;check(false,"finite fixture seed found")
 return original

func step3(seconds:float=.025) -> void:
 super.step3(seconds)
 if app!=null and int(app.session.data.level)==4 and not app.room_id in visited_rooms:visited_rooms.append(app.room_id)

func l4_fixture_order() -> Array:
 # Read-only prediction only selects the seed. Runtime still executes every
 # route/search; no completed point or reward is injected by this helper.
 var pending:Array=app.session.data.targets.duplicate()
 var order:Array=[];var room:String=app.room_id;var at:Vector2=app.hero_pos
 for guard in range(200):
  if pending.is_empty():return order
  var space=app.layout_for_room(room)
  var selected:String="";var selected_at:=Vector2.ZERO;var distance:float=INF
  for index in range(space.furniture.size()):
   var id:String="%s:%d"%[room,index]
   if not id in pending:continue
   var point:Vector2=space.furniture[index].at
   if at.distance_to(point)>.035 and space.path(at,point).is_empty():continue
   if at.distance_to(point)<distance:selected=id;selected_at=point;distance=at.distance_to(point)
  if not selected.is_empty():order.append(selected);pending.erase(selected);at=selected_at;continue
  var next:String=app.session.next_room(room,str(pending[0]).get_slice(":",0))
  if next.is_empty() or next==room:break
  at=Cortex.doorway(next,room);room=next
 check(false,"L4 initial group fixture has a finite reachable order")
 return order

func choose_last_seed(order:Array) -> String:
 var state:Dictionary=app.session.data.key_discovery
 for number in range(100000):
  state.seed="gpu-key-v2-last:"+str(number)
  var valid:bool=true
  for index in range(maxi(0,order.size()-1)):
   if app.session.key_rules.draw(state,str(order[index]))<1.0/float(order.size()-index):valid=false;break
  if valid:return str(state.seed)
 check(false,"finite L4 last-eligible fixture seed found")
 return str(state.seed)

func finish_key_check() -> void:
 var file:=FileAccess.open(ProjectSettings.globalize_path(folder).path_join("result.json"),FileAccess.WRITE)
 file.store_string(JSON.stringify({"passes":passes,"failures":failures,"rendered":true,"cases":cases,"visited_L4_rooms":visited_rooms,
  "fixtures":"Fixed v2 roots/seeds; full 10/12/14/16-point groups; initial target priority; paid CONTROL destination; explicit same-point dog contact; historical-style v1 all-empty L1 save. NPC branches disabled. L4 seed selects fifteen misses in the real eight-plus-eight sample, not 62 misses.",
  "scope":"Production world handlers advanced in 0.025s game-time steps; original dialogue advanced automatically. Actual paths, searches, paid SKIN, physical dog delivery, checksummed JSON, old-save migration, rest and doors. Not normal human pacing, natural RNG distribution, all NPC combinations, UI input acceptance or formal art/audio."},"  "));file.close()
 print("KEY_DISCOVERY_CHECK %d passed %d failed"%[passes.size(),failures.size()])
 frontend.request_exit(0 if failures.is_empty() else 1)

func _ready() -> void:
 folder="res://../docs/validation/key_discovery_20261016"
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--validation-root="):folder=argument.trim_prefix("--validation-root=")
 name="CampaignCheck";frontend=get_parent();DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 await frames();frontend.show_profile();await frames();frontend.name_field.text="钥匙完成结算验证"
 frontend.overwrite_armed=true;frontend.new_game();await frames();app=frontend.active
 if app.tutorial_ui!=null:app.tutorial_ui.finish()
 if app.opening_ui!=null:app.opening_ui.skip()

 # 1. Real completion/pickup, pause and save replay, old owned-key migration,
 # then the same actual keyed door replay into the next canonical group.
 key_fixture();bedroom_sample()
 var target:String="bedroom:6";var seed:String=choose_seed([target],[]);focus_initial_target(6)
 check(app.session.data.key_target=="" and app.rules.owners.key=="" and app.session.data.key_discovery.version==2,"fresh v2 attempt has no assigned key or owner")
 check(app.session.data.targets.size()==10 and app.session.data.key_discovery.eligible_targets==app.session.data.targets and is_equal_approx(app.session.key_rules.probability(app.session.data.key_discovery,target),.1),"first L1 completion uses full ten-point group and probability 1/10")
 check(until3(func():return app.rules.search_active,35),"hero actually walks to selected clothes search and begins")
 step3(.8)
 var elapsed:float=app.rules.search_elapsed
 app._process(.7)
 check(is_equal_approx(app.rules.search_elapsed,elapsed) and app.session.data.key_discovery.completed.is_empty(),"pause cannot complete search or draw key")
 check(not app.resolve_completed_key(target,app.rules._search_id).accepted,"unsettled completion callback cannot draw key")
 check(roundtrip(),"checksummed JSON accepts in-progress v2 discovery state")
 var middle:Dictionary=app.snapshot_data();var start_neurons:int=app.rules.neurons
 check(until3(func():return app.has_key(),15),"continued real search discovers and physically picks up key")
 var first:Dictionary=app.session.data.key_discovery.completed.get(target,{}).duplicate(true)
 check(not first.is_empty() and app.rules.neurons==start_neurons+1 and app.session.data.key_target==target,"completed point gives one N and only then a physical key location")
 var copy:Dictionary=app.resolve_completed_key(target,str(first.get("receipt","")))
 check(not copy.accepted and app.rules.owners.key=="hero","replayed completion cannot create or transfer another key")
 check(app.restore_snapshot(middle),"restore actual pre-completion snapshot")
 for index in range(120):app.rng.randf()
 check(until3(func():return app.has_key(),15),"same saved search completes without borrowing world RNG")
 var second:Dictionary=app.session.data.key_discovery.completed.get(target,{})
 check(not first.is_empty() and first==second and app.rules.neurons==start_neurons+1,"same save and actions preserve verdict and reward after unrelated random consumption")
 var owned:Dictionary=app.snapshot_data()
 owned.session.key_discovery.version=1;owned.session.key_discovery.erase("eligible_targets");owned.session.key_discovery.erase("completion_receipts")
 check(app.restore_snapshot(owned) and app.session.data.key_discovery.version==2 and app.has_key(),"declared v1 format of actual owned-key save migrates without losing physical holder")
 check(app.session.data.key_discovery.completed.get(target,{})==second and app.session.data.key_discovery.seed==seed and app.rules.neurons==start_neurons+1,"v1 migration preserves actual receipt, verdict, seed and earned resource")
 await capture("01_actual_completion_and_key")
 check(until3(func():return app.action_phase=="opening",30),"actual key owner approaches and starts opening the door")
 check(roundtrip(),"keyed doorway in progress survives checksummed JSON")
 var before_exit:Dictionary=app.snapshot_data()
 check(until3(func():return int(app.session.data.level)==2,3),"keyed doorway actually enters hospital")
 var hospital_seed:String=str(app.session.data.key_discovery.seed);var hospital_targets:Array=app.session.data.targets.duplicate()
 check(hospital_targets.size()==12 and app.session.data.key_discovery.eligible_targets==hospital_targets,"hospital starts its own twelve eligible targets without preassigned key")
 check(app.restore_snapshot(before_exit),"restore actual in-progress keyed doorway")
 for index in range(120):app.rng.randf()
 check(until3(func():return int(app.session.data.level)==2,3) and app.session.data.key_discovery.seed==hospital_seed and app.session.data.targets==hospital_targets,"same saved door and unrelated RNG preserve next-level root and target schedule")
 cases.append({"case":"actual_completion_save_migration_and_keyed_transition","seed":seed,"target":target,"L2_targets":hospital_targets})

 # 2. Real cancellation cost/attempt without a hidden probability penalty.
 key_fixture();bedroom_sample();seed=choose_seed([],[target]);focus_initial_target(6)
 check(until3(func():return app.rules.search_active,35),"interference fixture begins real search")
 var before:int=app.rules.neurons
 var p:float=app.session.key_rules.probability(app.session.data.key_discovery,target)
 var draw:float=app.session.key_rules.draw(app.session.data.key_discovery,target)
 var cast:Dictionary=app.rules.submit_skill("SKIN",app.skill_context());app.apply_cast()
 check(cast.ok and cast.success and app.rules.neurons==before-1 and not app.rules.search_active,"successful paid SKIN actually cancels unfinished search")
 check(app.session.data.key_discovery.completed.is_empty() and app.session.data.key_discovery.evidence.size()==1,"cancellation records one fact without a completion draw")
 check(is_equal_approx(app.session.key_rules.probability(app.session.data.key_discovery,target),p) and app.session.key_rules.draw(app.session.data.key_discovery,target)==draw,"cancelled action preserves group probability and deterministic draw")
 check(until3(func():return app.session.data.key_discovery.completed.has(target),20),"hero resumes and actually completes interrupted target")
 var affected:Dictionary=app.session.data.key_discovery.completed.get(target,{})
 check(not affected.is_empty() and not affected.get("found",true) and affected.get("evidence",[]).size()==1 and is_equal_approx(float(affected.get("probability",-1)),p) and app.rules.search_attempts==2,"cancelled plus completed attempts count separately without extra probability penalty")
 check(app.rules.neurons==before,"cancellation cost and single completion income settle once each")
 check(roundtrip() and same_saved_verdict(affected,app.session.data.key_discovery.completed.get(target,{})),"completed empty verdict, interference fact and receipt survive JSON with numeric tolerance")
 await capture("02_paid_interruption_without_probability_penalty")
 cases.append({"case":"paid_SKIN_without_extra_penalty","seed":seed,"target":target})
 key_fixture();bedroom_sample();app.rules.skill_states.CONTROL.unlocked=true;app.rules.neurons=50
 var control:Dictionary=app.rules.submit_skill("CONTROL",app.skill_context());app.apply_cast()
 check(control.ok and control.success and app.rules.control_left>0,"declared unlocked funded fixture submits and pays for real CONTROL")
 before=app.rules.neurons
 # A controlled destination fixture, not a claim of mouse-input acceptance.
 focus_initial_target(10);app.action_phase="controlled_search";app.controlled_route=false
 check(until3(func():return app.session.data.key_discovery.completed.has("bedroom:10"),20),"controlled protagonist actually walks and completes legal outside-group fan search")
 var outside:Dictionary=app.session.data.key_discovery.completed.get("bedroom:10",{})
 check(not outside.is_empty() and not outside.get("eligible",true) and not outside.get("found",true) and float(outside.get("probability",-1))==0 and float(outside.get("draw",0))==-1,"outside-group completion cannot discover key or consume key draw")
 check(app.rules.neurons==before+1 and app.session.key_rules.remaining_eligible(app.session.data.key_discovery)==10,"outside-group point earns one N without consuming eligible targets")

 # 3. Separate-target physical dog delivery, followed by explicit same-point
 # late-dog-contact fixtures exercising shared completion and ownership.
 key_fixture();bedroom_sample();seed=choose_seed(["bedroom:0"],[target]);focus_initial_target(6)
 app.home.enabled=true;app.home.start_attempt({"dog":true,"cat":false,"cat_point":1});clear_lines()
 app.home.data.dog.target=0;app.home.data.dog.phase="walk";app.home.data.dog.route=[]
 check(until3(func():return app.session.data.key_owner=="dog",45),"dog actually walks and searches its declared target before discovering key")
 check(app.session.data.key_discovery.discovered=="bedroom:0" and app.rules.owners.key=="dog" and not app.has_key(),"discovered dog key has one physical holder before delivery")
 check(roundtrip(),"dog-held key and current route survive checksummed JSON")
 check(until3(func():return app.has_key(),25),"dog physically returns and commits actual key transfer")
 check(app.rules.owners.key=="hero" and app.session.data.key_discovery.completed.has("bedroom:0"),"dog delivery retains one discovery receipt and one final holder")
 await capture("03_actual_dog_delivery")
 for dog_finds in [false,true]:
  key_fixture();bedroom_sample();var shared:String="bedroom:0"
  app.session.data.exploration_boundary=true
  choose_seed([shared] if dog_finds else [],[] if dog_finds else [shared])
  app.home.enabled=true;app.home.start_attempt({"dog":true,"cat":false,"cat_point":1});clear_lines()
  app.hero_pos=app.layout.furniture[0].at;app.target_index=0
  app.home.data.dog.pos=app.home.xy(app.hero_pos);app.home.data.dog.target=0
  app.home.data.dog.phase="search";app.home.data.dog.left=.3
  app.rules.begin_public_action("search",shared,"controlled","bedroom")
  check(app.rules.begin_search(shared),"same-point fixture starts real protagonist search "+str(dog_finds))
  var shared_before:int=app.rules.neurons
  step3(5.0)
  check(app.rules.neurons==shared_before+1 and app.rules._completed_targets.size()==1 and app.completed.count(shared)==1,"dog-first same-point completion gives one reward only "+str(dog_finds))
  check(app.session.data.key_discovery.completed.size()==1 and bool(app.session.data.key_discovery.completed[shared].found)==dog_finds,"human and dog share exactly one verdict "+str(dog_finds))
  check(app.has_key()==dog_finds and app.rules.owners.key==("hero" if dog_finds else ""),"same-point result is empty or actually delivered with one owner "+str(dog_finds))
 cases.append({"case":"dog_actual_delivery_and_shared_point","delivery_seed":seed,"contact_fixture":"dog 0.3s remaining, hero full real search; autonomous follow-up disabled"})

 # 4. Explicit historical-style v1 empty ledger, NOT a new v2 all-empty run.
 # Preserve old settled results; only actual return/rest starts attempt 2.
 key_fixture();bedroom_sample()
 var old:Dictionary=app.snapshot_data();var scheduled:Array=app.session.data.targets.duplicate()
 old.session.key_discovery.version=1;old.session.key_discovery.erase("eligible_targets");old.session.key_discovery.erase("completion_receipts")
 old.session.key_discovery.group_rate=.1;old.session.key_discovery.interference_factor=.65
 old.session.key_target=target;old.session.key_owner=target;old.session.key_seen=false;old.rules.owners.key=target
 old.completed=scheduled.duplicate();old.rules.search_attempts=10;old.rules.search_count=10;old.rules.neurons=15
 var legacy_position:Vector2=app.layout.furniture[6].at
 old.hero_pos=[legacy_position.x,legacy_position.y]
 for id in scheduled:
  old.rules._completed_targets[id]=true
  old.session.key_discovery.completed[id]={"receipt":"legacy_trial:"+str(id),"finder":"hero","found":false,"probability":.1,"draw":.9,"evidence":[]}
 check(app.restore_snapshot(old),"explicit historical-style v1 all-empty snapshot is accepted")
 check(app.session.data.key_discovery.version==2 and app.session.data.key_discovery.eligible_targets==scheduled and app.session.data.key_discovery.completed.size()==10,"migration preserves original group and ten historical empty verdicts")
 check(app.session.data.key_target=="" and app.rules.owners.key=="" and not app.session.data.key_discovery.has("group_rate") and not app.session.data.key_discovery.has("interference_factor"),"migration removes undiscovered preassignment and obsolete probability policy")
 var cycle:int=int(app.session.data.cycle)
 check(until3(func():return app.action_phase=="resting",35),"migrated exhausted old group physically reaches bed and starts rest")
 check(roundtrip(),"actual pre-rest-completion state survives checksummed JSON")
 var before_rest:Dictionary=app.snapshot_data()
 check(until3(func():return int(app.rules.actual_attempt)==2,3),"actual rest completes next attempt without retroactive key")
 var next_seed:String=str(app.session.data.key_discovery.seed);var next_targets:Array=app.session.data.targets.duplicate()
 check(app.restore_snapshot(before_rest),"restore saved real rest before completion")
 for index in range(120):app.rng.randf()
 check(until3(func():return int(app.rules.actual_attempt)==2,3),"saved rest physically completes again")
 check(app.session.data.key_discovery.seed==next_seed and app.session.data.targets==next_targets,"same saved rest and unrelated RNG preserve next-attempt seed and sample")
 check(int(app.session.data.cycle)==cycle+1 and app.rules.neurons==15 and not app.has_key() and app.session.data.key_target=="","one real rest advances one attempt without duplicate old reward or preplaced key")
 cases.append({"case":"explicit_v1_empty_ledger_migration_then_real_rest","historical_empty_count":10,"next_targets":next_targets})

 # 5. New L4: eight per floor; last initial eligible completion guarantees key.
 key_fixture(4,"atrium")
 var original_targets:Array=app.session.data.targets.duplicate();var original_cycle:int=int(app.session.data.cycle)
 var order:Array=l4_fixture_order();seed=choose_last_seed(order)
 var first_floor_count:int=0
 for id in original_targets:
  if str(id).get_slice(":",0) in Cortex.FIRST_ROOMS:first_floor_count+=1
 check(original_targets.size()==16 and first_floor_count==8 and app.session.data.key_discovery.eligible_targets==original_targets and not app.session.data.key_discovery.has("migration_recovery_targets"),"new L4 starts eight plus eight eligible points without legacy recovery expansion")
 check(order.size()==16,"seed selection covers complete reachable initial group")
 before=app.rules.neurons
 check(until3(func():return app.has_key(),600),"actual L4 room routes and sixteen searches reach last-eligible key and physical pickup")
 check(app.completed.size()==16 and app.rules.search_attempts==16 and app.session.data.key_discovery.completed.size()==16 and app.rules.neurons==before+16,"sixteen unique completions give sixteen rewards without a 62-point debug fallback")
 var last:Dictionary=app.session.data.key_discovery.completed.get(str(app.session.data.key_target),{})
 check(not last.is_empty() and last.get("guaranteed",false) and float(last.get("probability",0))==1.0,"actual final eligible completion records probability one and group guarantee")
 check(app.session.data.targets==original_targets and int(app.session.data.cycle)==original_cycle,"group traversal does not reroll sample or increment cycle")
 var stayed_in_group:bool=true
 for id in app.completed:
  if not id in original_targets:stayed_in_group=false
 check(stayed_in_group and visited_rooms.has("bridge"),"actual completions stay in initial group while traversing both floors")
 check(until3(func():return bool(app.session.data.get("cortex_exit_crossed",false)),150),"newly discovered key follows real two-floor route and actual final doorway")
 check(app.session.data.exploration_boundary and app.rules.mode=="exploration","L4 exit remains declared development boundary, not invented ending")
 cases.append({"case":"L4_initial16_last_eligible_guarantee","seed":seed,"eligible":original_targets,"fixture_order":order,"completed":app.completed.duplicate(),"key_target":app.session.data.key_target})
 await capture("04_actual_L4_initial_group_exit")
 finish_key_check()
