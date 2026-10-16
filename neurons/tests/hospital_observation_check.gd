extends "res://tests/hospital_check.gd"
## Finite physical-reading cases, not a claim that every page or narrative
## interpretation is accepted. Explicit placement/body/skill fixtures are named.
func obs():return app.hospital.observations

func observation_fixture(room:String="ward") -> void:
 hospital_fixture(room)
 app.hero_pos=app.layout.furniture[0].at
 app.action_phase="autonomy";app.hero_state="idle"
 app.session.data.key_target="office:9";app.session.data.key_owner="office:9";app.rules.owners.key="office:9"

func balances() -> Array:
 return [app.rules.hp,app.rules.sp,app.rules.neurons,app.rules.plexus]

func observed(id:String) -> bool:
 return obs().state().completed.has(id)

func observe_receipt(id:String) -> bool:
 var spec:Dictionary=obs().specification(id)
 return receipt("observe:"+id+":"+obs().revision(spec))

func read_here(id:String) -> bool:
 var spec:Dictionary=obs().specification(id)
 if spec.is_empty():return false
 app.hero_pos=obs().target_position(spec)
 clear_lines()
 if not obs().begin(id):return false
 hospital_step(1.025)
 return observed(id) and observe_receipt(id)

func click_bed() -> void:
 await click_world_point(app.layout.furniture[0].rect.get_center())

func read_control_feedback() -> void:
 # CONTROL has its own formal two-line response before world input resumes.
 # Dismiss it through the existing live Enter handler, preserving pause.
 await frames(3)
 for index in range(12):
  if app.dialogue_queue.is_empty() and app.rules.body_feedback.is_empty():return
  if not app.dialogue_queue.is_empty():await continue_live_line()
  else:await frames(2)

func click_world_point(at:Vector2) -> void:
 # Room transitions deliberately reject their first three input frames.
 # Wait for that real guard to expire, rather than bypassing its field.
 await frames(4)
 var pixel:Vector2=app.layout.project(at)
 var point:Vector2=(app.world_viewport.get_canvas_transform()*pixel)*2.0
 var motion_event:=InputEventMouseMotion.new();motion_event.position=point;motion_event.global_position=point
 Input.parse_input_event(motion_event)
 for down in [true,false]:
  var event:=InputEventMouseButton.new();event.position=point;event.global_position=point
  event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;Input.parse_input_event(event)
 await frames(2)

func finish_suite() -> void:
 var file:=FileAccess.open(ProjectSettings.globalize_path(folder).path_join("result.json"),FileAccess.WRITE)
 file.store_string(JSON.stringify({"passes":passes,"failures":failures,"rendered":true,"matrix":matrix,
  "scope":"representative physical hospital observation preparation/contact/finish, cancellation, actual JSON/pause, null-glyph relations, actual office search and routing, viewport mouse controlled reading and original dialogue hooks; explicit actor/location/prior-phase/resource fixtures; not all page semantics, natural probability coverage, human play or final-art/audio acceptance"},"  "));file.close()
 print("HOSPITAL_OBSERVATION_CHECK %d passed %d failed"%[passes.size(),failures.size()])
 frontend.request_exit(0 if failures.is_empty() else 1)

func _ready() -> void:
 folder="res://../docs/validation/takeover_20261016/hospital-observation"
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--validation-root="):folder=argument.trim_prefix("--validation-root=")
 name="CampaignCheck";frontend=get_parent()
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 await frames();frontend.show_profile();await frames();frontend.name_field.text="医院物件观察验证"
 frontend.overwrite_armed=true;frontend.new_game();await frames();app=frontend.active
 if app.tutorial_ui!=null:app.tutorial_ui.finish()

 observation_fixture()
 var card_at:Vector2=app.hero_pos;var money:Array=balances()
 app.hero_pos=card_at+Vector2(1.2,0)
 check(not obs().begin("bed_card_old") and not "bed_card_old" in app.rules.known,"distant card cannot begin physical reading or grant knowledge")
 app.hero_pos=card_at+Vector2(0.5,0)
 app.layout.movable_blockers.append(Rect2(card_at.x+0.22,0,0.08,app.layout.SIZE.y))
 check(not obs().begin("bed_card_old") and obs().state().active.is_empty(),"near card behind LOS blocker cannot be read")
 app.layout.movable_blockers.clear();app.hero_pos=card_at
 var began:bool=obs().begin("bed_card_old");hospital_step(0.2)
 check(began and obs().state().active.get("phase","")=="prepare" and not observed("bed_card_old") and balances()==money,"actual preparation begins with no early read, reward or resource change")
 hospital_step(0.2)
 var contact:bool=obs().state().active.get("phase","")=="contact"
 await capture("00_read_card_contact")
 hospital_step(0.55)
 check(contact and obs().state().active.get("phase","")=="finish" and not "bed_card_old" in app.rules.known and balances()==money,"contact then finish remain visible and unread before the complete one second")
 hospital_step(0.075)
 check(observed("bed_card_old") and observe_receipt("bed_card_old") and "bed_card_old" in app.rules.known and balances()==money,"only full physical reading commits one receipt and knowledge without income")
 var facts:int=app.rules.facts.size()
 check(not obs().begin("bed_card_old") and app.rules.facts.size()==facts,"completed same-revision card cannot replay a read or fact")
 await capture("01_read_card_completed")

 observation_fixture();obs().begin("bed_card_old");hospital_step(0.4)
 var saved_elapsed:float=float(obs().state().active.elapsed)
 var restored:bool=roundtrip()
 await frames(12)
 check(restored and is_equal_approx(float(obs().state().active.get("elapsed",-1)),saved_elapsed) and not observed("bed_card_old"),"actual half-read JSON and manual pause retain exact contact progress without completion")
 hospital_step(0.575)
 var still_unread:bool=not observed("bed_card_old")
 hospital_step(0.05)
 check(still_unread and observed("bed_card_old") and observe_receipt("bed_card_old") and roundtrip() and not obs().begin("bed_card_old"),"saved contact resumes remaining duration once and completed JSON cannot duplicate it")

 observation_fixture();obs().begin("bed_card_old");hospital_step(0.3);cast("SKIN")
 check(obs().state().active.is_empty() and not "bed_card_old" in app.rules.known and not observe_receipt("bed_card_old"),"actual SKIN interrupts unfinished card without completed knowledge")
 observation_fixture();obs().begin("bed_card_old");hospital_step(0.3);give_skill("GUT");cast("GUT")
 check(obs().state().active.is_empty() and not "bed_card_old" in app.rules.known,"actual GUT interrupts unfinished card rather than completing it")
 observation_fixture();obs().begin("bed_card_old");hospital_step(0.3)
 spawn_actor("doctor");app.hospital.set_body("exam","doctor")
 app.hospital.actor("doctor").phase="grab";app.hospital.actor("doctor").left=0.01
 hospital_step(0.025)
 check(app.hospital.data.holder=="doctor" and app.rules.hp==95 and obs().state().active.is_empty() and not observed("bed_card_old"),"actual needle/grip contact from explicit final-windup fixture interrupts unfinished card first")
 observation_fixture();obs().begin("uniform_label");hospital_step(0.3)
 spawn_actor("porter",Vector2(3.05,1.3));app.hospital.data.bag_order=true;app.rules.owners.hospital_laundry_manifest="ward_tray"
 app.hospital.data.transport={"kind":"bag","phase":"lift","elapsed":0.54,"witness":[]}
 hospital_step(0.05)
 check(app.hospital.data.bag=="porter" and receipt("laundry_order_received") and obs().state().active.is_empty() and not observed("uniform_label"),"actual remaining lift contact moves bag and cancels unfinished label reading")
 observation_fixture();obs().begin("bed_card_old");hospital_step(0.3);app.enter_room("lobby")
 check(obs().state().active.is_empty() and not observed("bed_card_old"),"room transition cancels an unfinished read without granting card knowledge")

 observation_fixture("office")
 var removal:bool=read_here("case_removal");var death:bool=read_here("case_death")
 var fees:bool=read_here("case_fees");var discharge:bool=read_here("case_discharge")
 check(removal and death and fees and discharge and obs().readable_field("case_removal","case_number")==null and not obs().same_number(["case_removal","case_death","case_fees","case_discharge"],"case_number") and not "hospital_case_link" in app.rules.known,"four actually read pages with null case glyphs remain separate rather than proving same-number identity")
 observation_fixture("office");var original_read:bool=read_here("complaint_original")
 var rewrite_read:bool=read_here("complaint_rewrite")
 check(original_read and rewrite_read and "complaint_changed" in app.rules.known and obs().readable_field("complaint_original","person_number")==null,"both actually read texts retain the explicitly authored same-person rewrite without inventing number glyphs")
 observation_fixture("clinic");delivered_prescription()
 var signed:bool=read_here("presigned_form")
 app.enter_room("lobby");spawn_actor("guide");app.hospital.set_body("registration","guide");hospital_step(0.7)
 var timed:bool=read_here("hospital_registration_time")
 check(signed and timed and obs().readable_field("presigned_form","signature_date")==null and obs().readable_field("hospital_registration_time","registration_time")==null and not "presigned_before_registration" in app.rules.known,"actually read unspecified signature and registration glyphs cannot invent date order")

 observation_fixture("office");app.hero_pos=app.layout.furniture[5].at;app.target_index=5
 app.rules.begin_search("office:5")
 var searched:bool=hospital_until(func():return "case_removal" in app.hospital.records.state().read,7.0)
 var candidate:Dictionary=obs().candidate("office",5)
 check(searched and candidate.get("id","")!="case_removal" and "case_removal" in app.rules.known,"actual completed office search removes its already-read page from optional reading candidates")
 observation_fixture();app.hospital.data.bag="removed"
 check(not obs().available(obs().specification("uniform_label")) and not obs().available(obs().specification("laundry_tag")) and obs().candidate("ward",0).get("id","") not in ["uniform_label","laundry_tag"],"removed bag leaves no readable label or empty-location information")

 observation_fixture();app.hero_pos=card_at+Vector2(1.0,0)
 var start:Vector2=app.hero_pos;candidate=obs().candidate("ward",0)
 var routed:bool=app.route_hospital_observation(candidate,false)
 hospital_step(0.025)
 check(routed and app.hero_pos.distance_to(start)>0 and app.hero_pos.distance_to(card_at)>0.65 and obs().state().active.is_empty(),"autonomous observation route actually moves without teleporting or starting remotely")
 var reached:bool=hospital_until(func():return not obs().state().active.is_empty(),5.0)
 check(reached and app.hero_pos.distance_to(card_at)<=0.035 and not observed("bed_card_old"),"route starts preparation only after reaching the actual legal anchor")

 observation_fixture();give_skill("CONTROL");var paid:int=app.rules.neurons;var control:Dictionary=cast("CONTROL")
 var control_id:String=app.rules.control_event
 app.paused_manual=false;get_window().grab_focus();await read_control_feedback();await click_bed();app.paused_manual=true
 var mouse_started:bool=app.action_phase in ["hospital_observation_route","hospital_observing"] or not obs().state().active.is_empty()
 matrix.append({"case":"controlled_bed_click","result":control,"action_phase":app.action_phase,"input_lock_frames":app.input_lock_frames,"menu":app.menu.visible,"closing":app.closing_left,"dialogue":app.dialogue_queue.duplicate(true),"status_note":app.status_note,"hospital_body":app.hospital.data.body.duplicate(true),"hero":app.hero_pos,"public_action":app.rules.public_action.duplicate(true)})
 var no_early_execution:bool=not app.rules.control_evidence_receipts.has(control_id)
 check(control.get("ok",false) and app.rules.control_left>0 and app.rules.neurons==paid-int(app.rules.spec("CONTROL").cost) and mouse_started and no_early_execution,"actual CONTROL and viewport bed click start optional observation without key-search or premature controlled-execution evidence")
 var completed:bool=hospital_until(func():return observed("bed_card_old"),5.0)
 check(completed and observe_receipt("bed_card_old") and app.rules.control_evidence_receipts.has(control_id) and app.rules.search_attempts==0,"controlled bed observation records actual execution only at full reading completion, with no fictitious ward search")
 await capture("02_controlled_card_read")

 observation_fixture();give_skill("CONTROL");cast("CONTROL")
 app.paused_manual=false;await read_control_feedback();await click_bed();app.paused_manual=true
 var partial:bool=hospital_until(func():return not obs().state().active.is_empty(),2.0)
 hospital_step(0.2)
 app.paused_manual=false;await click_world_point(Vector2(3.4,1.9));app.paused_manual=true
 var replaced:bool=obs().state().active.is_empty()
 hospital_step(1.2)
 check(partial and replaced and not observed("bed_card_old") and not "bed_card_old" in app.rules.known and not observe_receipt("bed_card_old"),"actual controlled floor click replaces unfinished reading without its late knowledge or receipt")

 observation_fixture("clinic");delivered_prescription();clear_lines()
 var held:Dictionary=obs().specification("presigned_form")
 var held_target:Dictionary={"id":held.id,"name":held.name,"pos":obs().target_position(held)}
 var same_anchor:Vector2=app.hero_pos
 app.route_hospital_observation(held_target,false);hospital_step(0.025)
 check(app.hero_pos==same_anchor and not obs().state().active.is_empty() and app.rules.public_action.get("kind","")=="observe","same-position owned page closes navigation and begins its separate actual observe public action")
 hospital_step(1.025)
 var closed_complete:bool=observed("presigned_form") and app.rules.public_action.is_empty()
 observation_fixture("clinic");delivered_prescription();clear_lines()
 held=obs().specification("presigned_form");held_target={"id":held.id,"name":held.name,"pos":obs().target_position(held)}
 app.route_hospital_observation(held_target,false);hospital_step(0.25);cast("SKIN")
 check(closed_complete and obs().state().active.is_empty() and app.rules.public_action.is_empty() and not observed("presigned_form"),"separate held-page public observation closes on real completion and on actual SKIN cancellation")

 observation_fixture("clinic");spawn_actor("doctor");app.hospital.set_body("exam","doctor")
 app.hero_pos=obs().target_position(obs().specification("donor_screening"))
 check(not obs().begin("donor_screening") and not observed("donor_screening"),"existing medical body action has priority over optional clinic page reading")

 observation_fixture();read_here("bed_card_old");spawn_actor("nurse");app.hospital.set_body("nurse_register","nurse")
 hospital_step(0.6)
 var early:bool=receipt("old_card_question")
 hospital_until(func():return receipt("old_card_question"),0.3)
 var expected:Array=obs().config.event_hooks.nurse_old_card_question.dialogue
 var actual:Array=app.dialogue_queue.duplicate(true)
 check(not early and receipt("old_card_question") and actual.size()==expected.size() and actual[0].text==expected[0].text and actual[1].text==expected[1].text and actual[2].text==expected[2].text,"previously read old card produces exact configured three original lines only at completed nurse number-check contact")
 observation_fixture("lobby");spawn_actor("guide");app.hospital.set_body("registration","guide")
 hospital_step(0.6);var covered_early:bool="registration_cover_seen" in app.rules.known
 hospital_step(0.075)
 check(not covered_early and app.hospital.data.registered and "registration_cover_seen" in app.rules.known and not "hospital_ticket_back" in app.rules.known,"guide cover behavior becomes known only at completed registration contact and reveals no hidden back fields")
 finish_suite()
