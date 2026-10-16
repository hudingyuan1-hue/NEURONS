extends "res://tests/asylum_events_check.gd"
## Initial/middle-action fixtures are explicit. No completed duty row is seeded.
## All tested swallowing, writing, walking, clipping and reading use world time.
var nurse_rooms:Array=[]

func duty() -> Dictionary:return app.asylum.nurse_duty.state()
func duty_fixture(room:String="corridor") -> void:
 app.asylum.data={};fixture3(room,true);app.session.data.exploration_boundary=true
 app.hero_pos=Vector2(4.35,3.2);duty()

func institution_count(id:String) -> int:
 var result:int=0
 for entry in app.rules.institutional_records:
  if str(entry.get("id",""))==id:result+=1
 return result

func canonical(value) -> String:return JSON.stringify(JSON.parse_string(JSON.stringify(value)),"",true)

func wait_duty(predicate:Callable,seconds:float=90.0) -> bool:
 for i in range(ceili(seconds/0.025)):
  if predicate.call():return true
  if app.asylum.present("med_nurse"):
   var room:String=str(app.asylum.actor("med_nurse").room)
   if nurse_rooms.is_empty() or nurse_rooms[-1]!=room:nurse_rooms.append(room)
  step3()
 return predicate.call()

func read_duty() -> bool:
 app.room_id="";app.enter_room("corridor");app.session.data.exploration_boundary=true
 app.hero_pos=app.layout.furniture[0].at
 if not app.asylum.observations.begin("asylum_nurse_duty_table",false):return false
 return until3(func():return app.asylum.observations.state().read.has("asylum_nurse_duty_table") and app.asylum.observations.state().active.is_empty(),4)

func start_false_copy(known:bool=true) -> bool:
 app.asylum.data={}
 if not pharmacy3(true):return false
 give_skill("GUT");cast("GUT")
 if not until3(func():return rec3("false_medicine"),6):return false
 if not known:app.rules.known.erase("asylum_false_medicine_seen")
 clear_lines();app.room_id="";app.enter_room("corridor");app.session.data.exploration_boundary=true
 app.hero_pos=Vector2(4.35,3.2);nurse_rooms.clear()
 return true

func finish3() -> void:
 var result:Dictionary={"passes":passes,"failures":failures,"rendered":true,
  "scope":"B3 one shared med_nurse: actual medication witness followed by independent physical writing, no upstairs or remote swallow witness, refusal/false-paper mutual exclusion, physical source reading/number checking/real inter-floor movement/duty writing/clipping, existing prior-paper source preservation and null number, save/pause/once-only accounting, and real public-table observation with conditional original dialogue. Explicit inherited-paper and staff-busy fixtures do not assert a complete prior-level or natural-RNG run. No formal art, subjective audio, all NPC combinations or whole-game acceptance.",
  "actual_nurse_rooms":nurse_rooms,"methods":{"normal_campaign_update":true,"actual_checksummed_json":true,"world_step_seconds":0.025,"human_natural_rng_playthrough":false,"formal_art_accepted":false,"audio_listened":false}}
 var f:=FileAccess.open(ProjectSettings.globalize_path(folder).path_join("result.json"),FileAccess.WRITE)
 f.store_string(JSON.stringify(result,"  "));f.close()
 print("ASYLUM_NURSE_DUTY_CHECK %d passed %d failed"%[passes.size(),failures.size()])
 frontend.request_exit(0 if failures.is_empty() else 1)

func _ready() -> void:
 folder="res://../docs/validation/b3_20261016/nurse_duty"
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--validation-root="):folder=argument.trim_prefix("--validation-root=")
 name="CampaignCheck";frontend=get_parent();DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 await frames();frontend.show_profile();await frames();frontend.name_field.text="同一病区护士值班验证"
 frontend.overwrite_armed=true;frontend.new_game();await frames();app=frontend.active
 if app.tutorial_ui!=null:app.tutorial_ui.finish()

 duty_fixture("stairs")
 app.asylum.data.groups.pharmacy={"checks":0,"pending":false,"drawn":false}
 # This seed fixes only this finite scheduling example; on_enter still draws
 # the production shared linked-group roll and consumes its real budget.
 var first_seed:int=0
 for candidate_seed in range(100):
  var trial:=RandomNumberGenerator.new();trial.seed=candidate_seed
  if trial.randf()<0.5:first_seed=candidate_seed;break
 app.rng.seed=first_seed;app.enter_room("corridor");app.session.data.exploration_boundary=true;app.hero_pos=Vector2(4.35,3.2)
 check(app.asylum.data.groups.pharmacy.drawn and app.asylum.data.groups.pharmacy.checks==1,"unvisited-pharmacy corridor entry uses the original linked pharmacy group roll and remaining check budget")
 check(wait_duty(func():return app.asylum.present("med_nurse"),2),"successful shared corridor roll actually spawns the existing linked group at its original pharmacy door offscreen")
 check(str(app.asylum.actor("med_nurse").room)=="pharmacy" and str(app.asylum.actor("pharmacist").room)=="pharmacy","both one-per-ID actors begin at pharmacy instead of a second upstairs nurse clone")
 var nurse_entry:Vector2=app.asylum.position("med_nurse");var pharmacist_entry:Vector2=app.asylum.position("pharmacist")
 step3(0.15)
 check(not app.asylum.actor("pharmacist").get("work_stand_done",false) and app.asylum.position("med_nurse").is_equal_approx(nurse_entry) and app.asylum.position("pharmacist").distance_to(pharmacist_entry)>0.02,"nurse physically waits while linked pharmacist first walks clear of the single pharmacy doorway instead of both racing into each other")
 nurse_rooms.clear()
 check(wait_duty(func():return duty().get("posted",false),45),"same nurse physically travels to upstairs duty station with no fabricated source paper")
 check(nurse_rooms.has("pharmacy") and nurse_rooms.has("lobby") and nurse_rooms.has("stairs") and nurse_rooms.has("corridor"),"first corridor scheduling retains actual pharmacy/lobby/stairs/corridor passage")
 check(duty().entries.is_empty() and app.asylum.actor("pharmacist").room=="pharmacy" and app.asylum.data.actors.size()==21,"no-source duty posting writes no classification, moves no pharmacist and creates no identity")
 var checks_before:int=int(app.asylum.data.groups.pharmacy.checks)
 app.enter_room("stairs");app.enter_room("corridor");app.session.data.exploration_boundary=true;step3(0.1)
 check(app.asylum.data.groups.pharmacy.checks==checks_before and str(app.asylum.actor("med_nurse").room)=="corridor","already-drawn group's corridor revisit does not reroll, duplicate or reset the posted nurse")

 app.asylum.data={}
 check(pharmacy3(true),"actual doctor/pharmacist/cup flow reaches visible pre-swallow while the one nurse is onsite")
 check(until3(func():return bool(app.asylum.data.swallowed),2),"real complete cup raise commits original swallowing once")
 var swallow_id:String="asylum_nurse_swallow:"+str(app.rules.actual_attempt)
 check(not duty().swallow_pending.is_empty() and institution_count(swallow_id)==0,"continuous swallowing witness queues work without pretending nurse has already written")
 check(app.rules.sp==80 and float(app.asylum.data.medicine_stop)>0,"actual drug effect is independent of later nurse paperwork")
 check(until3(func():return duty().swallow_written,1.2),"onsite nurse really finishes writing while protagonist drug stop is still active")
 check(institution_count(swallow_id)==1 and float(app.asylum.data.medicine_stop)>0,"own witnessed record forms once and hero body stop cannot freeze nurse writing")
 var sp:int=app.rules.sp;step3(1)
 check(institution_count(swallow_id)==1 and app.rules.sp==sp,"continued writing/copying cannot repeat medication or own-witness record")

 app.asylum.data={};check(pharmacy3(false),"unaccompanied pharmacist reaches same real cup window without spawning an upstairs witness")
 actor3("med_nurse","corridor",Vector2(1.3,2.7))
 check(until3(func():return bool(app.asylum.data.swallowed),2),"pharmacist completes actual ingestion with nurse genuinely upstairs")
 check(duty().swallow_pending.is_empty() and institution_count("asylum_nurse_swallow:"+str(app.rules.actual_attempt))==0,"upstairs nurse receives no remote full-swallow witness or onsite record")
 check(app.asylum.data.actors.size()==21 and str(app.asylum.actor("med_nurse").room)=="corridor","one nurse identity remains upstairs instead of duplicating a pharmacy observer")

 check(start_false_copy(),"actual refusal and actual false-record writing produce a real source before duty copying")
 check(app.asylum.data.refused and not app.asylum.data.swallowed and institution_count("asylum_false_medicine:1")==1,"refusal facts and institution's written already-taken paper stay separate")
 check(wait_duty(func():return duty().job.get("phase","")=="write",90),"same nurse physically reads/checks actual lower-floor source and arrives at upstairs writing stand")
 check(duty().entries.is_empty() and duty().job.read_completed and duty().job.number_checked and not duty().job.written,"read/check/contact do not produce an already-finished duty row")
 check(nurse_rooms.has("pharmacy") and nurse_rooms.has("lobby") and nurse_rooms.has("stairs") and nurse_rooms.has("corridor"),"one actor really crosses pharmacy/lobby/stairs/corridor rather than teleporting between records")
 step3(0.2);var elapsed_before:float=float(duty().job.elapsed);var saved_job:String=canonical(duty().job)
 await frames(12)
 check(is_equal_approx(float(duty().job.elapsed),elapsed_before),"manual pause freezes actual upstairs writing game clock")
 check(roundtrip() and canonical(duty().job)==saved_job,"real checksummed JSON retains exact mid-writing source, timing and physical actor")
 check(until3(func():return not duty().entries.is_empty(),3),"resumed nurse physically completes writing and clipping before public row exists")
 var entry:Dictionary=duty().entries[0]
 check(entry.source_id=="asylum_false_medicine:1" and entry.source_text=="给药护士：已服用（实际拒服；造假落笔后才形成）。" and entry.source_attempt==1,"duty copy preserves exact source ID/text/attempt instead of rewriting provenance")
 check(entry.number==null and entry.number_match==null and entry.category==null and entry.clipped,"unprovided number stays null and no idle or false-paper label is fabricated")
 check(not entry.own_swallow_witness and not entry.eyewitness_origin and not entry.original_owner_changed,"copying an already-taken page does not become a new swallowing witness or move the original owner")
 check(app.rules.sp==100 and app.rules.hp==100 and not app.rules.gripped and not app.asylum.data.swallowed,"institutional duty classifications do not alter body facts, health, mental state or control")
 await capture("01_actual_nurse_duty_clipped")
 clear_lines();check(read_duty(),"actual public-table preparation/contact/finish invokes nurse-duty reading")
 check("asylum_duty_copied_error" in app.rules.known and rec3("nurse_copy_error_line"),"actual read of this known false source enables exact original P805–808 once")
 check(duty().read_entries.has(entry.id),"public-table read remembers this completed copy without internal-folder punishment")
 check(not rec3("chief_internal_seen"),"public duty-table reading does not create chief internal-folder search offense")
 var count:int=duty().entries.size();clear_lines();step3(0.5)
 check(institution_count(str(entry.id))==1 and duty().entries.size()>=count,"continued updates do not append same completed source again")

 check(start_false_copy(false) and wait_duty(func():return not duty().entries.is_empty(),90),"same physical false source can be copied without a protagonist full-writing-witness knowledge flag")
 check(read_duty() and "asylum_duty_copied_error" in app.rules.known and rec3("nurse_copy_error_line") and not "asylum_false_medicine_seen" in app.rules.known,"own actual refusal plus actual read of the matching already-taken copy permits original challenge without inventing a full-writing eyewitness")

 duty_fixture("corridor");actor3("med_nurse","pharmacy",Vector2(3.5,1.0))
 # Explicit inherited-paper fixture: the existing historical entry is the
 # source. This does not claim that an earlier level was played in this case.
 app.rules.institutional_records.append({"id":"false_medicine:old-duty-fixture","text":"已服用（机构贴签；实际未服另账）。","source":"医院记录","attempt":4})
 app.asylum.data.carry.visit="old-duty-fixture"
 app.rules.known.append("false_medicine_seen")
 app.asylum.data.staff_targets.med_nurse="other_actual_task"
 var position_before:Vector2=app.asylum.position("med_nurse");step3(2)
 check(app.asylum.position("med_nurse").is_equal_approx(position_before) and duty().entries.is_empty(),"another real nurse task reserves the same identity and cannot be overwritten by duty movement")
 app.asylum.data.staff_targets.erase("med_nurse")
 check(wait_duty(func():return duty().job.get("phase","")=="read" and str(app.asylum.actor("med_nurse").room)=="office",45),"prior source is read only after actual travel to the existing office archive copy")
 check(duty().entries.is_empty(),"global historical records alone cannot remotely fill the upstairs duty sheet")
 app.rules.owners.asylum_prior_copy="hero";step3(0.1)
 check(duty().entries.is_empty() and duty().job.is_empty(),"taking archived copy away before actual read completion cancels that unavailable source")
 app.rules.owners.asylum_prior_copy="office:6"
 check(wait_duty(func():return not duty().entries.is_empty(),90),"restored real archive paper permits new actual read/check/upstairs-write/clip")
 entry=duty().entries[0]
 check(entry.source_kind=="prior_copy" and entry.source_attempt==4 and entry.number==null and not entry.own_swallow_witness,"prior source/attempt/null number survive copying without becoming nurse's ingestion eyewitness")
 check(app.rules.sp==100 and not app.asylum.data.dispensed and not app.asylum.data.swallowed,"old already-taken paper neither creates a new valid dose nor changes actual current medication")
 check(read_duty() and not rec3("nurse_copy_error_line"),"generic old false-medication knowledge without this visit's actual refusal cannot identify the historical copy as this known contradiction")
 await capture("02_prior_copy_provenance")

 duty_fixture("corridor");actor3("med_nurse","pharmacy",Vector2(3.5,1.0));actor3("pharmacist","pharmacy",Vector2(3.0,1.0))
 # Explicit middle-action inherited-valid-order fixture: ownership is already
 # pharmacist's. Subsequent source reading/copying is the real module path.
 app.asylum.data.carry={"visit":"inherited-B","prescription_visit":"inherited-B","prescribed":true,"dispensed":false,"swallowed":false,"refused":false}
 app.asylum.data.order_source="hospital_prescription";app.asylum.data.order_delivered=true
 app.rules.owners.hospital_prescription="asylum_pharmacist"
 app.rules.institutional_records.append({"id":"prescription:older-A","text":"旧就诊A已签处方。","source":"医院记录","attempt":2})
 app.rules.institutional_records.append({"id":"prescription:inherited-B","text":"本次继承B已签处方。","source":"医院记录","attempt":3})
 app.rules.known.append("false_medicine_seen")
 check(not app.asylum.nurse_duty.source_error_known({"source_id":"false_medicine:older-A"}) and not app.asylum.nurse_duty.source_error_known({"source_id":"false_medicine:inherited-B"}),"two historical visits plus a generic old known flag cannot bind either wrong visit or non-refused current visit to a false-record challenge")
 check(until3(func():return not duty().job.is_empty(),1) and duty().job.source.source_id=="prescription:inherited-B","multiple historical prescriptions bind medical-order reading to the exact inherited current visit, never first global record")
 check(wait_duty(func():return not duty().entries.is_empty(),60),"nurse physically reads the actual pharmacist-held inherited order and writes/clips at upstairs station")
 entry=duty().entries[0]
 check(entry.source_kind=="medical_order" and entry.source_id=="prescription:inherited-B" and entry.source_text=="本次继承B已签处方。" and entry.source_attempt==3,"completed current-order copy preserves exact inherited source B rather than unrelated older prescription A")
 check(app.rules.owners.hospital_prescription=="asylum_pharmacist" and not app.asylum.data.dispensed and not app.asylum.data.swallowed and app.rules.sp==100,"nurse reading inherited valid command does not take its ownership, re-dispense or apply drug")
 finish3()
