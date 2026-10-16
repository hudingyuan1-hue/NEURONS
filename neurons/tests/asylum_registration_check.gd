extends "res://tests/asylum_events_check.gd"
## This suite fixtures only prior hospital transport facts and initial actors.
## Every new reply, question, written accusation and reading uses real timing.

func registration3() -> Dictionary:return app.asylum.registration_state()
func registration_fixture(prior_transport:bool=true,sp:int=100) -> void:
 fixture3("lobby",true);app.session.data.exploration_boundary=true
 app.rules.sp=sp
 app.asylum.data.carry={"wheelchair_gone":prior_transport}
 actor3("registration_nurse","lobby",Vector2(3.7,1.4))
func label_count3() -> int:
 var count:int=0
 for entry in app.rules.institutional_records:
  if str(entry.get("id","")).begins_with("asylum_registration_followup:"):count+=1
 return count
func writing3() -> bool:
 return app.asylum.data.body.get("kind","")=="registration_followup" and app.asylum.data.body.get("phase","")=="write" and float(app.asylum.data.body.get("elapsed",0))>0.2
func finish3() -> void:
 var f:=FileAccess.open(ProjectSettings.globalize_path(folder).path_join("result.json"),FileAccess.WRITE)
 f.store_string(JSON.stringify({"passes":passes,"failures":failures,"rendered":true,
  "scope":"B3 finite registration follow-up cases. Initial fixture states only an actual prior wheelchair transfer or its absence, initial walkable registration nurse and protagonist, and fixed SP. Autonomous new reply/question, writing and read phases use the real game clock, paid neural skills and actual JSON. No natural-RNG/full-game, mouse UI, formal-art or subjective audio acceptance.",
  "fixtures":"All random groups held drawn; stationary development boundary isolates this interaction. Prior wheelchair_gone, initial SP and final held-key condition are explicit history/resource fixtures; no registration reply, repeated question, accusation, completion or knowledge is injected. One direct common-damage-handler call checks interrupted reading, not a new narrative attack.",
  "untested":"Every other medical/guard/isolation interleaving, normal-speed human playthrough, approved concrete patient-number glyphs, actual CONTROL mouse desk/nurse routing, formal assets and audio."},"  "));f.close()
 print("ASYLUM_REGISTRATION_CHECK %d passed %d failed"%[passes.size(),failures.size()])
 frontend.request_exit(0 if failures.is_empty() else 1)

func _ready() -> void:
 folder="res://../docs/validation/b3_20261016/registration"
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--validation-root="):folder=argument.trim_prefix("--validation-root=")
 name="CampaignCheck";frontend=get_parent();DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 await frames();frontend.show_profile();await frames();frontend.name_field.text="登记二次追问验证"
 frontend.overwrite_armed=true;frontend.new_game();await frames();app=frontend.active
 if app.tutorial_ui!=null:app.tutorial_ui.finish()

 registration_fixture(false)
 check(app.layout.walkable(app.asylum.position("registration_nurse")),"registration nurse fixture begins at an actual walkable lobby position")
 check(until3(func():return bool(app.asylum.data.registered),4),"ordinary nurse contact can finish registration without a fabricated departed patient")
 step3(2)
 check(not app.asylum.data.get("departure_page",false) and not registration3().reply_received,"absent prior transport cannot create that patient's departure page or answer")
 check(not app.asylum.begin_registration_followup(false) and label_count3()==0,"passing or ordinary registration alone cannot generate a repeated-question accusation")

 registration_fixture(true)
 var neurons:int=app.rules.neurons;var clusters:int=app.rules.plexus
 check(until3(func():return bool(app.asylum.data.registered),4),"real registration contact exposes the genuinely carried departure-copy branch")
 check(registration3().reply_pending and not registration3().reply_received and not registration3().asked,"queued first answer is not yet a completed reply or repeated question")
 check(app.asylum.registration_interaction(false).is_empty(),"no second interaction starts while the formal first answer remains open")
 var witnessed_line:bool=false
 for line in app.dialogue_queue:
  if str(line.text)=="他抓着门框不肯走，我看见了。":witnessed_line=true
 check(not witnessed_line and not "wheelchair_identity_confirmed" in app.rules.known,"unknown number identity cannot turn a paper-only question into a full-witness assertion")
 check(until3(func():return bool(registration3().asked),4),"autonomous protagonist really receives answer then asks the original follow-up without unlocking CONTROL")
 check(rec3("registration_reply_received") and rec3("registration_question") and not app.rules.skill_states.CONTROL.unlocked,"reply and actual question have separate receipts while CONTROL stays locked")
 check(not registration3().written and label_count3()==0,"original follow-up speech alone cannot create a completed written accusation")
 check(until3(func():return writing3(),2),"after original P649 dialogue the nurse begins actual interruptible writing")
 var elapsed:float=float(app.asylum.data.body.elapsed);var time:float=app.rules.world_time
 await frames(12)
 check(is_equal_approx(app.rules.world_time,time) and is_equal_approx(float(app.asylum.data.body.elapsed),elapsed),"manual pause freezes actual writing rather than finishing paper in real time")
 check(roundtrip() and is_equal_approx(float(app.asylum.data.body.elapsed),elapsed) and not registration3().written,"partial writing JSON preserves elapsed time without issuing a label")
 check(until3(func():return bool(registration3().written),2),"nurse completes the configured actual writing before institutional label exists")
 check(label_count3()==1 and app.rules.owners.asylum_registration_followup=="registration_nurse","one finished sheet has one institutional entry and one physical owner")
 check(not registration3().read and not "asylum_registration_accusation_seen" in app.rules.known,"written record is not automatically protagonist knowledge")
 step3(0.8)
 check(not registration3().read,"less than the actual one-second viewing window cannot reveal the written allegation")
 check(until3(func():return bool(registration3().read),1),"actual post-writing read completes before original P651 and P652 reactions")
 check("asylum_registration_accusation_seen" in app.rules.known and app.dialogue_queue.size()==2,"source feedback is queued only after protagonist really sees the finished record")
 check(app.rules.hp==100 and app.rules.sp==100 and app.rules.neurons==neurons and app.rules.plexus==clusters,"question, paper allegation and reading create no extra injury or resources")
 step3(1)
 check(app.asylum.registration_interaction(false).is_empty() and not app.asylum.begin_registration_followup(false),"completed one-time interaction cannot continually reask or rewrite")
 check(roundtrip() and registration3().read and label_count3()==1,"finished accusation and actually-known reaction survive JSON without a second settlement")
 await capture("01_actual_autonomous_followup_read")

 registration_fixture(true)
 check(until3(func():return writing3(),6),"interruption fixture earns real first reply and actual follow-up writing")
 give_skill("SKIN");check(cast("SKIN").get("success",false),"paid protagonist skin reaction really interrupts unfinished follow-up writing")
 step3(1.2)
 check(app.asylum.data.body.is_empty() and not registration3().written and label_count3()==0,"interrupted writing cannot later issue paper while unrelated world time runs")
 check(registration3().asked and not "asylum_registration_accusation_seen" in app.rules.known,"actual prior question stays true while unfinished accusation and unseen text remain absent")
 check(not app.asylum.begin_registration_followup(true),"requesting a controlled interaction without active lawful control is rejected")
 give_skill("CONTROL");check(cast("CONTROL").get("success",false),"legal paid CONTROL enables optional physical continuation rather than debug completion")
 clear_lines()
 check(app.asylum.begin_registration_followup(true),"same-room physically near nurse can resume the already-asked unfinished interaction")
 check(until3(func():return bool(registration3().written),3),"continued writing actually finishes one original sheet")
 app.asylum.cancel_registration_interaction()
 check(registration3().written and not registration3().read and label_count3()==1,"new valid command interrupts viewing while preserving already-written paper")
 check(roundtrip() and registration3().written and not registration3().read,"written-but-unread JSON retains paper while withholding character knowledge")
 check(app.asylum.begin_registration_followup(true),"later actual contact can view the same finished allegation without rewriting")
 check(until3(func():return bool(registration3().read),3) and label_count3()==1,"optional repeat contact reads one sheet and never duplicates the institutional accusation")
 check(rec3("registration_question") and rec3("registration_followup_written") and rec3("registration_followup_read"),"question, writing and seeing remain three independent one-time facts")
 await capture("02_interrupted_write_then_same_paper_read")

 registration_fixture(true)
 check(until3(func():return bool(registration3().written),6),"hurt fixture earns the actual written record before receiving an independent hit")
 check(app.asylum.damage("registration_validation_hurt",5,0),"shared real damage handler executes a finite independent injury")
 step3(0.4)
 check(registration3().written and not registration3().read and app.asylum.data.body.is_empty(),"injury cancels unfinished read but cannot erase the already-written accusation")
 check(app.rules.hp==95 and app.rules.sp==100 and label_count3()==1,"the allegation itself causes no second injury or SP loss")

 registration_fixture(true)
 check(until3(func():return writing3(),6),"room-leave fixture starts a real unfinished writing phase")
 app.enter_room("clinic");app.session.data.exploration_boundary=true;step3(2)
 check(not registration3().written and label_count3()==0 and app.asylum.data.body.is_empty(),"leaving the interaction room cancels unfinished writing instead of settling it remotely")
 check(app.asylum.registration_interaction(false).is_empty() and not app.asylum.begin_registration_followup(false),"nurse in another actual room cannot be questioned or read through walls")
 await capture("03_remote_followup_rejected")

 registration_fixture(true,40);step3(3)
 check(not app.asylum.data.registered and not registration3().auto_started,"low-SP autonomous character does not accept a new registration invitation before returning to bed")
 registration_fixture(true);app.rules.owners.key="hero";app.session.data.key_owner="hero";step3(3)
 check(not app.asylum.data.registered and label_count3()==0,"explicit held-key fixture keeps exit priority over a new optional registration exchange")
 finish3()
