extends SceneTree
const Neural=preload("res://scripts/core/neural_rules.gd")
const Store=preload("res://scripts/core/save_store.gd")
var checks:int=0
var failed:int=0
var results:Array=[]

func check(condition:bool,label:String) -> void:
 checks+=1
 results.append({"label":label,"ok":condition})
 if not condition:failed+=1;push_error(label)

func full():
 var r=Neural.new()
 r.plexus=100
 for id in r.skill_states:
  if id!="SKIN":check(r.unlock(id).ok,"unlock follows actual prerequisite: "+id)
 r.neurons=100
 return r

func _init() -> void:
 test_costs()
 test_effects()
 test_growth()
 test_control()
 test_attacks()
 test_storage()
 test_book()
 test_awareness()
 var folder:String=ProjectSettings.globalize_path("res://../docs/validation/b1_20261015")
 DirAccess.make_dir_recursive_absolute(folder)
 var file:=FileAccess.open(folder.path_join("neural_rules.json"),FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":checks,"failed":failed,"results":results,"scope":"rules only; combat world/NPC not certified"},"  "))
 print("NEURONS neural rules: %d checks, %d failures"%[checks,failed])
 quit(1 if failed>0 else 0)

func test_costs() -> void:
 var r=Neural.new()
 check(r.skill_states.size()==12 and r.skill_states.SKIN.unlocked,"exactly twelve definitions; SKIN initially unlocked")
 check(not r.unlock("CONTROL").ok and r.plexus==3,"missing prerequisites never charges")
 check(not r.submit_skill("GUT").ok and r.neurons==5,"locked cast never charges")
 r.plexus=22
 for id in r.skill_states:
  if id!="SKIN":check(r.unlock(id).ok,"twenty-two-cluster tree: "+id)
 check(r.plexus==0,"entire tree costs exactly 22 clusters")
 r.plexus=1
 var power:int=r.skill_states.GUT.power
 check(r.upgrade("GUT").ok and r.plexus==0 and r.skill_states.GUT.power==power+1,"one cluster upgrade changes strength only")
 check(r.spec("GUT").cost==1 and r.spec("GUT").cooldown==2,"upgrade does not change cost or cooldown")
 r=full()
 for id in r.skill_states:
  r.skill_states[id].resistance=int(r.skill_states[id].power)
  if id=="SKIN":r.skin_resistance=r.skin_power
  var before:int=r.neurons
  var cast:Dictionary=r.submit_skill(id)
  check(cast.ok and not cast.success and r.neurons==before-int(r.spec(id).cost),"equal resistance still pays: "+id)
  check(not r.apply_pending().success,"resistance cannot fabricate reaction: "+id)
  check(not r.submit_skill(id).ok,"resistance still cools down: "+id)
  r.tick(21)
 check(not r.submit_skill("MISSING").ok,"unknown id invalid")
 r.neurons=0
 var until:float=r.skill_states.GUT.until
 check(not r.submit_skill("GUT").ok and r.skill_states.GUT.until==until,"insufficient funds no cooldown")

func test_effects() -> void:
 for id in ["PORES","TEMP","TINNITUS","JOY"]:
  var r=full()
  r.begin_search("desk")
  r.tick(0.5)
  var progress:float=r.search_elapsed
  r.submit_skill(id);r.apply_pending()
  check(r.search_active,"skill preserves unfinished search: "+id)
  r.tick(0.4)
  var expected:float=progress+(0.0 if id=="TINNITUS" else 0.3 if id=="TEMP" else 0.4)
  check(is_equal_approx(r.search_elapsed,expected),"specified progress rate: "+id)
  check(is_equal_approx(r.world_time,0.9),"world clock independent of effect: "+id)
  r.tick(1.0)
  if id=="TINNITUS":check(is_equal_approx(r.search_elapsed,progress+0.4),"tinnitus resumes same action after exactly one second")
 for id in ["SKIN","GUT","KNEE","WITHDRAW","STARTLE","FEAR","CONTROL"]:
  var r=full();r.begin_search("drawer");var balance:int=r.neurons
  r.submit_skill(id);var applied:Dictionary=r.apply_pending()
  check(applied.success and not r.search_active and r.neurons==balance-int(r.spec(id).cost),"specified search cancellation: "+id)
  check(r.search_attempts==1 and r.search_count==0,"cancel neither refunds opportunity nor awards income: "+id)
 var r=full();r.sp=10;r.submit_skill("FEAR");r.apply_pending()
 check(r.sp==0 and r.stun_left==1.0,"fear causing zero-SP gives one actual stupor")
 r.tick(1.0);r.submit_skill("JOY");r.apply_pending()
 check(r.sp==20,"joy gives exactly twenty SP without health change")
 r=full();r.submit_skill("TEMP");r.apply_pending();var before:int=r.neurons
 r.tick(2.01)
 check(not r.submit_skill("TEMP").ok and r.neurons==before,"unexpired sustained effect cannot be refreshed for payment")
 r=full();r.gripped=true;before=r.neurons
 check(not r.submit_skill("WITHDRAW").ok and not r.submit_skill("STARTLE").ok and r.neurons==before,"ordinary reflex cannot free established grip")
 r=full();r.submit_skill("DRYMOUTH");r.apply_pending()
 check(r.owners.porridge=="mother","drymouth does not retroactively transfer or consume anything")
 r.observe("物品","cup","已见杯子")
 check(r.observations.size()==1 and r.plexus==78,"basic observations free")

func test_growth() -> void:
 var r=full()
 for i in range(3):r.submit_skill("GUT");r.apply_pending();r.tick(2)
 check(r.skill_states.GUT.growth and r.skill_states.GUT.resistance==0,"three actual reactions queue growth only")
 r.submit_skill("GUT");r.apply_pending();r.tick(2)
 check(r.skill_states.GUT.reactions==0,"growth cannot accumulate twice in same attempt")
 check(r.record_awakening("dog") and not r.record_awakening("dog"),"awakening has unique receipt")
 r.next_actual_attempt()
 check(r.skill_states.GUT.resistance==1 and not r.skill_states.GUT.growth and r.global_resistance==1,"real attempt commits targeted and global growth once")
 r.next_actual_attempt()
 check(r.skill_states.GUT.resistance==1 and r.global_resistance==1,"subsequent attempt cannot replay committed growth")
 r=Neural.new();r.mode="combat";r.skin_resistance=1;r.plexus=0
 check(r.emergency_available() and r.emergency_reconnect().ok,"combat resistance lockout emergency reconnect")
 check(r.neurons==0 and r.skin_power==2 and r.reaction_left==0,"emergency is paid strength change, no fabricated cast")
 r.tick(4)
 check(r.neurons==1,"combat natural recovery capped route recovers one after four seconds")
 check(not r.emergency_available(),"emergency disabled once any owned skill passes resistance")

func test_control() -> void:
 var r=full();r.submit_skill("CONTROL");r.apply_pending()
 check(r.control_left==6 and r.neurons==95 and r.skill_states.CONTROL.until==0,"control pays five; cooldown starts only after window")
 var before:int=r.neurons
 check(not r.submit_skill("SKIN").ok and r.neurons==before,"control blocks concurrent neural skill payment")
 r.tick(1)
 r.gripped=true;r.tick(2)
 check(r.control_ms==1000 and r.control_left==3,"grip consumes window but not effective milliseconds")
 r.gripped=false;r.hurt_left=0.25;r.tick(0.5)
 check(r.control_ms==1250,"partial hit-stop excludes exact blocked interval")
 r.loading=true;r.tick(3)
 check(r.control_left==2.5 and r.control_ms==1250,"loading freezes window and effective total")
 r.loading=false;r.tick(2.5)
 check(r.control_left==0 and r.control_ms==3750 and is_equal_approx(r.skill_states.CONTROL.until,r.world_time+20),"expiration counts effective remainder then twenty-second cooldown")
 r.tick(20);r.submit_skill("CONTROL");r.apply_pending();r.tick(0.25);r.end_control()
 check(r.control_ms==4000 and r.control_left==0,"early end retains earned milliseconds")
 r=full();r.control_ms=29999;r.control_left=6;r.tick(0.001)
 check(r.control_ms==30000 and r.control_stage==1 and r.control_feedback==[1],"thirty-second boundary queued once")
 r.control_ms=59999;r.tick(0.001)
 check(r.control_stage==2 and r.control_feedback==[2],"sixty-second boundary replaces deferred feedback for an already-passed stage")
 r.control_ms=119999;r.tick(0.001)
 check(r.control_stage==3 and r.control_ms==120000,"120000ms exact internal ending boundary")
 r.tick(0.1)
 check(r.control_feedback==[3] and r.control_stage_receipts.size()==3,"stage effects not queued again each tick; all stage receipts retained")
 r=full();r.mode="combat";r.submit_skill("CONTROL");r.apply_pending();r.neurons=0;r.tick(6)
 check(r.neurons==0 and r.combat_regen==0,"control time never produces natural recovery")

func test_attacks() -> void:
 var r=full();r.mode="combat"
 check(not r.submit_skill("SKIN").ok,"combat sidestep needs explicit mouse direction before charge")
 r.submit_skill("KNEE",{"direction":[1,0]});r.apply_pending()
 check(not r.kick_contact("enemy",0.5,true,true),"preparation cannot deal damage")
 r.advance_kick(0.16)
 check(not r.kick_contact("enemy",1.001,true,true),"kick cannot hit beyond one metre")
 check(not r.kick_contact("enemy",0.5,false,true),"kick cannot hit behind")
 check(not r.kick_contact("enemy",0.5,true,false),"kick cannot hit through obstacle")
 check(r.kick_contact("enemy",1.0,true,true) and not r.kick_contact("enemy",1.0,true,true),"actual front contact commits once per target")
 r.advance_kick(0.5);r.control_left=6
 check(not r.begin_kick({"direction":[1,0]},true).ok,"controlled kick shares neural knee cooldown")
 r.tick(4);var balance:int=r.neurons;var reactions:int=r.skill_states.KNEE.reactions
 check(r.begin_kick({"direction":[1,0]},true).ok and r.neurons==balance and r.skill_states.KNEE.reactions==reactions,"controlled physical kick has no second neural fee or adaptation")

func test_storage() -> void:
 var store=Store.new();store.root="res://../tmp/b1_20261015/migration"
 check(store.save_snapshot({"schema":1,"marker":"old-valid"}).ok,"legacy schema one remains writable and valid")
 var r=full();r.submit_skill("PORES")
 var state:Dictionary={}
 for info in r.get_property_list():
  if int(info.usage)&PROPERTY_USAGE_SCRIPT_VARIABLE:state[info.name]=r.get(info.name)
 check(store.save_snapshot({"schema":2,"rules":state}).ok,"new nested pending skill state saves with checksum")
 var loaded:Dictionary=store.load_snapshot()
 check(loaded.ok and loaded.data.rules.pending_neural.id=="PORES","pending paid cast survives JSON roundtrip")
 var legacy:String=ProjectSettings.globalize_path(store.root).path_join("profile.schema1.json")
 check(store._read(legacy).ok and store._read(legacy).data.marker=="old-valid","migration preserves original valid legacy slot separately")

func test_book() -> void:
 var r=Neural.new();r.plexus=20
 check(not r.buy_book_extension("book_role_resistance").ok and r.plexus==20,"unseen category cannot sell invented information")
 r.observe("角色","skin_seen","实际发生的皮肤反应")
 check(r.observations.size()==1 and r.plexus==20,"basic observed fact is free")
 check(r.buy_book_extension("book_role_resistance").ok and r.plexus==15,"optional resistance parameter extension costs exactly five clusters")
 check(not r.buy_book_extension("book_role_resistance").ok and r.plexus==15,"already-open extension never charges again")
 var details:String=r.book_details("角色")
 check(details.contains("SKIN") and not details.contains("CONTROL") and not details.contains("120000"),"extension lists owned nodes only and never exposes hidden self-loss threshold")
 check(r.known.is_empty() and r.institutional_records.is_empty(),"buying parameter UI cannot invent protagonist knowledge or institutional fact")

func test_awareness() -> void:
 var r=Neural.new()
 r.add_evidence("one","SKIN",{"room":"bedroom","action":"search","target":"bed"},true)
 check(r.awareness_stage==1,"one actual perceived reaction produces suspicion only")
 r.add_evidence("one","SKIN",{"room":"bedroom","action":"search","target":"desk"},true)
 check(r.evidence.size()==1,"replayed perception event cannot count as a new context")
 r.add_evidence("two","SKIN",{"room":"bedroom","action":"search","target":"bed"},true)
 r.add_evidence("three","SKIN",{"room":"bedroom","action":"search","target":"bed"},true)
 check(r.awareness_stage==1,"repeat movement or same target context never fakes the second context")
 r.add_evidence("four","GUT",{"room":"bedroom","action":"search","target":"desk"},true)
 check(r.awareness_stage==2,"three-plus perceptions, two contexts, repeated same skill permit awareness")
 r.begin_public_action("search","desk","autonomous","bedroom")
 check(not r.trial.is_empty(),"aware protagonist marks next real autonomous action as a trial")
 r.add_evidence("five","SKIN",{"room":"bedroom","action":"search","target":"desk"},false)
 check(r.awareness_stage==2,"perception without changing trial intent does not recognize player")
 r.add_evidence("six","SKIN",{"room":"bedroom","action":"search","target":"desk"},true)
 check(r.awareness_stage==3 and r.intervention_lock,"new contrary reaction in actual trial recognizes once")
 check(not r.submit_skin().ok and r.neurons==5,"first recognition restriction rejects without payment")
 r.finish_public_action("autonomous")
 check(r.intervention_lock,"cancelled recognition-triggering action cannot immediately clear restriction")
 r.begin_public_action("search","bed","controlled","bedroom")
 r.control_left=0;r.finish_public_action("controlled")
 check(r.intervention_lock,"controlled action remains controlled after takeover expires")
 r.begin_public_action("navigation","bed","autonomous","bedroom");r.finish_public_action("autonomous")
 check(not r.intervention_lock,"one completed new autonomous action clears exploration restriction")
 r=Neural.new();r.tutorial_demo=true
 r.submit_skin();r.apply_pending()
 check(r.evidence.is_empty() and r.skin_reactions==0,"tutorial body response adds neither formal perception nor adaptation")
 r=Neural.new();r.awareness_stage=2;r.control_event="control_case"
 r.control_context={"room":"bedroom","action":"search","target":"desk"}
 r.controlled_execution("search","desk",false)
 check(r.awareness_stage==2,"taking over same intended interaction does not fabricate a contrary act")
 r.control_event="control_case2";r.controlled_execution("navigation","floor",true)
 check(r.awareness_stage==3 and r.evidence.size()==2,"actual contrary controlled movement can recognize without trial")
 r.controlled_execution("navigation","floor",true)
 check(r.evidence.size()==2,"one takeover contributes at most one perception event")
