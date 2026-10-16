extends SceneTree
const Session=preload("res://scripts/core/campaign_session.gd")
const Discovery=preload("res://scripts/core/key_discovery.gd")
var checks:int=0
var errors:Array=[]
var measured:Array=[]

func expect(value:bool,label:String) -> void:
 checks+=1
 if not value:errors.append(label)

func sample_state(engine,level:int,seed_value:String) -> Dictionary:
 var all:Array=Session.all_candidates(level)
 return engine.begin(level,1,seed_value,all.slice(0,[10,12,14,16][level-1]))

func _init() -> void:
 var engine=Discovery.new()
 var rng:=RandomNumberGenerator.new();rng.seed=109
 for level in range(1,5):
  var session=Session.new();session.new_attempt(level,rng)
  expect(session.data.key_target=="" and session.data.key_owner=="" and not session.data.key_seen,"no initial physical key "+str(level))
  expect(session.data.targets.size()==[10,12,14,16][level-1],"unchanged sample count "+str(level))
  expect(session.data.key_discovery.eligible_targets==session.data.targets,"only public initial sample is eligible "+str(level))
  expect(session.data.key_discovery.completed.is_empty(),"begin creates no verdict "+str(level))
  if level==4:
   var first:int=0
   for target in session.data.targets:
    if target.get_slice(":",0) in Session.CortexMap.FIRST_ROOMS:first+=1
   expect(first==8,"L4 remains 8 + 8")
 var missing:Dictionary=engine.begin(1,1,"old-three-argument-fixture")
 expect(missing.diagnostic=="eligible_targets_required","legacy call is diagnostic, not implicit all-candidates")
 expect(not engine.resolve(missing,"bedroom:0","receipt","hero",Session.all_candidates(1)).accepted,"undeclared eligible set cannot draw")

 var state:Dictionary=sample_state(engine,1,"stable-save")
 var target:String=str(state.eligible_targets[0])
 var p:float=engine.probability(state,target)
 expect(is_equal_approx(p,.1),"initial uniform hazard")
 expect(not engine.note_interference(state,target,{"id":"SKIN","event_id":"resist","success":false,"search_cancelled":true}),"resistance does not create interference fact")
 expect(not engine.note_interference(state,target,{"id":"JOY","event_id":"joy","success":true}),"unrelated benefit is not search interference")
 var event:Dictionary={"id":"SKIN","event_id":"skin","success":true,"search_cancelled":true}
 expect(engine.note_interference(state,target,event),"real cancellation records fact")
 expect(not engine.note_interference(state,target,event),"same interference fact does not duplicate")
 expect(engine.note_interference(state,target,{"id":"TEMP","event_id":"temp","success":true}),"TEMP records delay only")
 expect(engine.note_interference(state,target,{"id":"TINNITUS","event_id":"tinnitus","success":true}),"TINNITUS records pause only")
 expect(is_equal_approx(engine.probability(state,target),p),"no cancellation or temperature/tinnitus probability debuff")
 expect(state.completed.is_empty() and state.completion_receipts.is_empty() and state.discovered=="","interference and preview make no draw")
 var outside:Dictionary=engine.resolve(state,"bedroom:10","outside-actual","hero",Session.all_candidates(1))
 expect(outside.accepted and not outside.newly_found and outside.verdict.draw==-1 and not outside.verdict.eligible,"legal CONTROL point records completion without widening key eligibility")
 expect(engine.remaining_eligible(state)==10 and is_equal_approx(engine.probability(state,target),p),"outside completion cannot advance guarantee")
 expect(not engine.resolve(state,"ward:0","invalid","hero",Session.all_candidates(1)).accepted,"non-search room invalid")
 expect(not engine.resolve(state,target,"","hero",Session.all_candidates(1)).accepted,"missing completion receipt invalid")
 var clone:Dictionary=JSON.parse_string(JSON.stringify(state))
 for i in range(1000):rng.randf()
 var left:Dictionary=engine.resolve(state,target,"actual-first","hero",Session.all_candidates(1))
 var right:Dictionary=engine.resolve(clone,target,"actual-first","hero",Session.all_candidates(1))
 expect(left==right and state.discovered==clone.discovered,"save and unrelated NPC RNG preserve exact verdict")
 expect(not engine.resolve(state,target,"dog-replay","dog",Session.all_candidates(1)).accepted,"hero/dog same target settles once")
 expect(not engine.resolve(state,str(state.eligible_targets[1]),"actual-first","hero",Session.all_candidates(1)).accepted,"one receipt cannot settle two targets")
 expect(state.completed[target].evidence.size()==3,"interference retained only as verdict facts")

 # Finite, deterministic distribution sanity checks. They do not measure real
 # gameplay clear rates; no NPC, resource, timing or route process is simulated.
 for level in range(1,5):
  var n:int=[10,12,14,16][level-1]
  var hits:Array=[];hits.resize(n);hits.fill(0)
  var all:Array=Session.all_candidates(level)
  for seed_value in range(1600):
   var trial:Dictionary=sample_state(engine,level,"uniform:%d:%d"%[level,seed_value])
   var found:int=-1
   for ordinal in range(n):
    var result:Dictionary=engine.resolve(trial,str(trial.eligible_targets[ordinal]),"search:"+str(ordinal),"dog" if ordinal%3==1 else "hero",all)
    if result.newly_found:
     found=ordinal;hits[ordinal]+=1;break
   expect(found>=0,"all initial targets guarantee "+str(level)+":"+str(seed_value))
  for count in hits:expect(absf(float(count)/1600.0-1.0/float(n))<.03,"finite uniform rank "+str(level))
  measured.append({"level":level,"seeds":1600,"completed_initial_group_found":1600,"discovery_rank_counts":hits,"scope":"headless distribution, not gameplay clear rate"})
  var last:Dictionary=sample_state(engine,level,"explicit-final-fixture")
  for t in last.eligible_targets.slice(0,n-1):last.completed[t]={"found":false,"receipt":"prior:"+t}
  var result:Dictionary=engine.resolve(last,str(last.eligible_targets[-1]),"final-actual","hero",all)
  expect(result.newly_found and result.verdict.guaranteed and result.verdict.probability==1.0,"last initial eligible, not last entire world, guarantees "+str(level))
  expect(not engine.resolve(last,str(last.eligible_targets[-1]),"replay","dog",all).accepted,"guarantee does not duplicate "+str(level))
  var noninitial:String=""
  for t in all:
   if not t in last.eligible_targets:noninitial=t;break
  expect(engine.resolve(last,noninitial,"after-key","hero",all).accepted and last.discovered==last.eligible_targets[-1],"existing key does not respawn on supplemental completion "+str(level))

 # Sampling is on a dedicated root/level/actual-attempt stream.
 var initial=Session.new();initial.new_attempt(1,rng)
 var saved:Dictionary=JSON.parse_string(JSON.stringify(initial.data))
 for next_level in range(1,5):
  var a=Session.new();a.data=saved.duplicate(true);a.normalize_restored_numbers()
  var b=Session.new();b.data=saved.duplicate(true);b.normalize_restored_numbers()
  if next_level==1:a.data.attempts["1"]=2;b.data.attempts["1"]=2
  var ra:=RandomNumberGenerator.new();ra.seed=123
  var rb:=RandomNumberGenerator.new();rb.seed=987;for j in range(411):rb.randf()
  var prior_a:int=ra.state;var prior_b:int=rb.state
  a.new_attempt(next_level,ra);b.new_attempt(next_level,rb)
  expect(a.data.targets==b.data.targets and a.data.key_discovery==b.data.key_discovery,"unrelated waiting/NPC RNG cannot change next sample "+str(next_level))
  expect(ra.state==prior_a and rb.state==prior_b,"sample does not consume NPC RNG "+str(next_level))
  expect(engine.draw(a.data.key_discovery,"probe")!=engine.draw(saved.key_discovery,"probe"),"new level/attempt draw namespace "+str(next_level))

 # The cooldown only excludes one real result on the immediately next attempt.
 for level in range(1,5):
  var s=Session.new();s.new_attempt(level,rng)
  var found:String=""
  for t in s.data.targets:
   if s.resolve_key(t,"find:"+t,"hero").newly_found:found=t;break
  expect(not found.is_empty() and s.data.key_discovery_history.size()==1,"real result recorded once "+str(level))
  var history:Dictionary=s.data.key_discovery_history[0].duplicate()
  s.data.attempts[str(level)]=2;s.new_attempt(level,rng)
  expect(not found in s.data.targets and s.data.targets.size()==[10,12,14,16][level-1],"cooldown excludes only from next sample "+str(level))
  expect(found in Session.all_candidates(level),"cooldown never deletes legal world point "+str(level))
  expect(s.data.key_discovery_history.size()==1 and s.data.key_discovery_history[0]==history,"empty new attempt never refreshes found history "+str(level))
  var same=Session.new();same.data=JSON.parse_string(JSON.stringify(s.data));same.normalize_restored_numbers();same.new_attempt(level,rng)
  expect(same.data.targets==s.data.targets and same.data.key_discovery_history.size()==1,"replaying same attempt does not extend cooldown "+str(level))
  s.data.attempts[str(level)]=3
  expect(s._recent_target(level,3)=="","cooldown expires by actual attempt even without another discovery "+str(level))
  s.new_attempt(level,rng)
  if level==4:
   var floor_one:int=0
   for t in s.data.targets:
    if t.get_slice(":",0) in Session.CortexMap.FIRST_ROOMS:floor_one+=1
   expect(floor_one==8,"cooldown maintains L4 floor counts")
 expect(initial._take_sample(["a","b"],2,"a")==["a","b"],"insufficient alternatives restore cooled point rather than shrink sample")

 # Explicit v1 migration: preserve completed verdicts, evidence and physical key.
 var trial=Session.new();trial.new_attempt(1,rng)
 var empty_target:String=trial.data.targets[0]
 var old_verdict:Dictionary={"receipt":"old-search","finder":"hero","probability":.01048,"draw":.5,"found":false,"guaranteed":false,"evidence":["old-temp"]}
 trial.data.key_discovery={"version":1,"level":1,"attempt":1,"seed":"v1","completed":{empty_target:old_verdict.duplicate(true)},"interference":{empty_target:["old-temp"]},"evidence":{"old-temp":{"target":empty_target,"skill":"TEMP"}},"discovered":"","group_rate":.1,"interference_factor":.65,"last_candidate_guarantee":true}
 trial.data.key_target="bedroom:6";trial.data.key_owner="bedroom:6";trial.data.key_seen=false
 var old_snapshot:Dictionary=JSON.parse_string(JSON.stringify(trial.data))
 expect(trial.migrate_key_discovery([empty_target],"old-rng"),"v1 migrates explicitly")
 expect(trial.data.key_discovery.version==2 and not trial.data.key_discovery.has("group_rate") and not trial.data.key_discovery.has("interference_factor") and not trial.data.key_discovery.has("last_candidate_guarantee"),"old tuning removed from live policy")
 expect(trial.data.key_discovery.completed[empty_target]==old_verdict,"past verdict and receipt preserved verbatim")
 expect(trial.data.key_discovery.evidence.has("old-temp"),"past interference evidence preserved")
 expect(trial.data.key_target=="" and trial.data.key_owner=="","old undiscovered placement removed")
 expect(is_equal_approx(engine.probability(trial.data.key_discovery,str(trial.data.targets[1])),1.0/9.0),"remaining eligible points use new hazard")
 expect(not trial.resolve_key(empty_target,"replay-empty","hero").accepted,"historical empty is never rerolled")
 var repeat=Session.new();repeat.data=old_snapshot.duplicate(true);repeat.normalize_restored_numbers();repeat.migrate_key_discovery([empty_target],"old-rng")
 expect(repeat.data.key_discovery==trial.data.key_discovery,"migration deterministic from same old JSON")
 expect(not trial.migrate_key_discovery([],"other-rng"),"migration idempotent")

 var all_empty=Session.new();all_empty.data=old_snapshot.duplicate(true);all_empty.normalize_restored_numbers()
 for t in all_empty.data.targets:all_empty.data.key_discovery.completed[t]={"receipt":"old:"+t,"found":false}
 all_empty.migrate_key_discovery(all_empty.data.targets,"old-rng")
 expect(all_empty.data.key_target=="" and engine.remaining_eligible(all_empty.data.key_discovery)==0 and all_empty.data.key_discovery.discovered=="","old fully empty trial is not retroactively awarded key")
 expect(all_empty.data.targets.all(func(t):return all_empty.data.key_discovery.completed.has(t)),"fully empty trial retains normal return/rest completion condition")
 expect(not all_empty.data.key_discovery.has("migration_recovery_targets"),"L1 old empty trial never receives L4 recovery")

 # The obsolete v1 group-rate policy could leave all sixteen L4 points empty.
 # L4 cannot rest: only this old-save condition recovers via unfinished legal
 # supplemental targets. No prior empty result, public sample or physical key
 # is rewritten. These are completion-contract tests, not live contact tests.
 var legacy4=Session.new();legacy4.new_attempt(4,rng)
 var initial4:Array=legacy4.data.targets.duplicate()
 var old4_completed:Dictionary={}
 for t in initial4:old4_completed[t]={"receipt":"old4:"+t,"found":false,"probability":.05,"draw":.8}
 var supplemental_done:Array=[]
 for t in Session.all_candidates(4):
  if not t in initial4 and supplemental_done.size()<2:
   supplemental_done.append(t);old4_completed[t]={"receipt":"old4:"+t,"found":false,"probability":.05,"draw":.9}
 legacy4.data.key_discovery={"version":1,"level":4,"attempt":1,"seed":"legacy-L4","completed":old4_completed.duplicate(true),"interference":{},"evidence":{},"discovered":"","group_rate":.65,"interference_factor":.65,"last_candidate_guarantee":true}
 var old4_snapshot:Dictionary=legacy4.data.duplicate(true)
 expect(legacy4.migrate_key_discovery(old4_completed.keys(),"legacy-rng"),"v1 L4 exhausted initial sample migrates")
 var recovery_state:Dictionary=legacy4.data.key_discovery
 var recovery_targets:Array=recovery_state.get("migration_recovery_targets",[])
 expect(recovery_state.migration_recovery_reason=="v1_l4_initial_group_empty_without_key_no_rest","L4 recovery explicitly explains compatibility exception")
 expect(recovery_state.eligible_targets==initial4 and legacy4.data.targets==initial4,"L4 recovery keeps original initial sixteen and route sample")
 expect(recovery_state.completed==old4_completed,"L4 recovery preserves every old empty verdict verbatim")
 expect(recovery_targets.size()==Session.all_candidates(4).size()-old4_completed.size(),"recovery includes all and only unfinished legal supplemental points")
 expect(recovery_targets.all(func(t):return t in Session.all_candidates(4) and not t in old4_completed),"old completed points never enter recovery")
 expect(legacy4.data.key_target=="" and legacy4.data.key_owner=="" and recovery_state.discovered=="","migration never awards or materializes the recovery key")
 expect(is_equal_approx(engine.probability(recovery_state,str(recovery_targets[0])),1.0/float(recovery_targets.size())),"recovery uses deferred uniform hazard over unfinished points")
 expect(not legacy4.resolve_key(str(initial4[0]),"retry-old4","hero").accepted,"L4 old empty point cannot reroll")
 expect(not legacy4.resolve_key(str(recovery_targets[0]),"old4:"+str(initial4[0]),"hero").accepted,"recovery cannot reuse an old receipt")
 var recovery_json:Dictionary=JSON.parse_string(JSON.stringify(legacy4.data))
 var recovery_replay=Session.new();recovery_replay.data=recovery_json.duplicate(true);recovery_replay.normalize_restored_numbers()
 expect(not recovery_replay.migrate_key_discovery(old4_completed.keys(),"different-rng"),"restoring migrated recovery does not reopen migration")
 expect(recovery_replay.data.key_discovery.migration_recovery_targets==recovery_targets,"recovery survives real JSON without resampling")
 var recovery_repeat=Session.new();recovery_repeat.data=old4_snapshot.duplicate(true);recovery_repeat.migrate_key_discovery(old4_completed.keys(),"legacy-rng")
 expect(recovery_repeat.data.key_discovery==recovery_state,"same legacy L4 snapshot migrates identically")
 var recovered:String=""
 for t in recovery_targets:
  var actual:Dictionary=legacy4.resolve_key(str(t),"recovery:"+str(t),"hero")
  var replayed:Dictionary=recovery_replay.resolve_key(str(t),"recovery:"+str(t),"hero")
  expect(actual==replayed,"recovery completion verdict survives JSON "+str(t))
  if actual.newly_found:recovered=str(t);break
 expect(not recovered.is_empty() and legacy4.data.key_owner==recovered,"real completion materializes exactly one recovered key")
 expect(legacy4.data.key_discovery_history.size()==1 and legacy4.data.key_discovery_history[0].target==recovered,"recovered real discovery enters persistent result history")
 expect(not legacy4.resolve_key(recovered,"recovery-replay","dog").accepted,"recovery key cannot be rediscovered by dog or replay")
 var final_recovery=Session.new();final_recovery.data=recovery_json.duplicate(true);final_recovery.normalize_restored_numbers()
 for t in recovery_targets.slice(0,recovery_targets.size()-1):final_recovery.data.key_discovery.completed[t]={"receipt":"fixture-recovery:"+t,"found":false}
 var final_recovery_result:Dictionary=final_recovery.resolve_key(str(recovery_targets[-1]),"recovery-final","hero")
 expect(final_recovery_result.newly_found and final_recovery_result.verdict.guaranteed and final_recovery_result.verdict.probability==1.0,"last genuine recovery completion guarantees key")
 var partial4=Session.new();partial4.data=old4_snapshot.duplicate(true)
 partial4.data.key_discovery.completed.erase(initial4[-1])
 partial4.migrate_key_discovery(partial4.data.key_discovery.completed.keys(),"legacy-rng")
 expect(not partial4.data.key_discovery.has("migration_recovery_targets") and engine.remaining_eligible(partial4.data.key_discovery)==1,"partial v1 L4 sample remains only its initial eligible points")
 var physical4=Session.new();physical4.data=old4_snapshot.duplicate(true)
 physical4.data.key_owner="hero";physical4.data.key_seen=true;physical4.data.key_target=initial4[0];physical4.data.key_discovery.discovered=initial4[0]
 physical4.migrate_key_discovery(old4_completed.keys(),"legacy-rng")
 expect(not physical4.data.key_discovery.has("migration_recovery_targets") and physical4.data.key_owner=="hero","existing L4 physical key never enters recovery")
 legacy4.data.attempts["4"]=2;legacy4.new_attempt(4,rng)
 expect(legacy4.data.targets.size()==16 and legacy4.data.key_discovery.eligible_targets==legacy4.data.targets and not legacy4.data.key_discovery.has("migration_recovery_targets"),"next new L4 attempt clears compatibility recovery and retains sixteen")
 for holder in ["hero","dog","floor","bedroom:6"]:
  var physical=Session.new();physical.data=old_snapshot.duplicate(true);physical.normalize_restored_numbers()
  physical.data.key_target="bedroom:6";physical.data.key_owner=holder;physical.data.key_seen=false;physical.data.key_discovery.discovered="bedroom:6"
  physical.migrate_key_discovery([empty_target],"old-rng")
  expect(physical.data.key_target=="bedroom:6" and physical.data.key_owner==holder and physical.data.key_discovery.discovered=="bedroom:6","v1 physical ownership retained "+holder)
  for t in physical.data.targets:
   if not physical.data.key_discovery.completed.has(t):
    expect(not physical.resolve_key(t,"after-migration","hero").newly_found,"already discovered prevents duplicate "+holder);break
  expect(physical.data.key_discovery_history.size()==1,"migrated real discovery remembered "+holder)
 var fixed=Session.new();fixed.data=old_snapshot.duplicate(true);fixed.normalize_restored_numbers();fixed.data.erase("key_discovery")
 fixed.data.key_target="bedroom:6";fixed.data.key_owner="hero";fixed.data.key_seen=true
 expect(fixed.migrate_key_discovery([empty_target],"fixed-rng") and fixed.data.key_owner=="hero","pre-v1 discovered fixed-save key preserved")
 expect(fixed.data.key_discovery.completed.has(empty_target),"pre-v1 empty result preserved")
 print(JSON.stringify({"checks":checks,"failures":errors,"finite_uniform_samples":measured,"scope":"Headless discovery/session/migration only; caller contact, live resources, actual rest, rendering and gameplay clear rates require GPU tests"}))
 quit(0 if errors.is_empty() else 1)

