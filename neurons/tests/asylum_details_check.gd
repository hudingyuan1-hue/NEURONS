extends "res://tests/asylum_observation_check.gd"
## Source-gated dynamic reading, not authored capture/signature events.

func finish3() -> void:
 var out:=FileAccess.open(ProjectSettings.globalize_path(folder).path_join("result.json"),FileAccess.WRITE)
 out.store_string(JSON.stringify({"passes":passes,"failures":failures,"rendered":true,"scope":"Finite real source-gated paper/box reads, conservative pre-owner-field departure-copy JSON compatibility, unknown-number/whiteboard checks, empty self-photo slot, saved partial read and actual CRT/world-mouse paper selection. The legacy positive page is first earned through actual nurse paperwork; only its newer ownership key is removed before real save/restore. Negative page/record/present-holder conditions are explicit fixtures. No all-RNG or formal-art/audio acceptance.","content_pending":"Number and whiteboard glyphs, an authored self-photo capture and actual signature remain absent; runtime checks never invent them."},"  "));out.close()
 print("ASYLUM_DETAILS_CHECK %d passed %d failed"%[passes.size(),failures.size()]);frontend.request_exit(0 if failures.is_empty() else 1)

func _ready() -> void:
 folder="res://../docs/validation/b3_finish_20261016/details"
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--validation-root="):folder=argument.trim_prefix("--validation-root=")
 name="CampaignCheck";frontend=get_parent();DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 await frames();frontend.show_profile();await frames();frontend.name_field.text="独立纸件与未知内容验证"
 frontend.overwrite_armed=true;frontend.new_game();await frames();app=frontend.active
 if app.tutorial_ui!=null:app.tutorial_ui.finish()

 observation_fixture("lobby",1)
 var count:int=app.rules.neurons;var searches:int=app.rules.search_attempts
 check(observe3("asylum_number_screen"),"actual approach and finite screen inspection completes without a supplied number")
 var fields:Dictionary=observations3().state().read.get("asylum_number_screen",{}).get("fields",{})
 check(fields.get("displayed_number")==null and not fields.get("identity_confirmed",true) and not fields.get("departure_proved",true),"screen check cannot turn an undelivered number into a seen identity or departure fact")
 check(app.rules.neurons==count and app.rules.search_attempts==searches,"new physical inspections give neither search income nor another key attempt")
 observation_fixture("group_therapy",5)
 check(observe3("asylum_whiteboard_text"),"actual whiteboard surface inspection leaves the existing tray-search mechanics separate")
 check(observations3().state().read.get("asylum_whiteboard_text",{}).get("fields",{}).get("written_text")==null,"missing original whiteboard wording remains null instead of new diagnosis or dialogue")
 observation_fixture("office",5)
 app.asylum.damage("details_source_injury",5,0);clear_lines()
 until3(func():return not app.rules.body_busy(),2)
 check(observe3("asylum_self_injury_photo"),"a genuinely hurt protagonist can inspect the existing self-photo filing position")
 fields=observations3().state().read.get("asylum_self_injury_photo",{}).get("fields",{})
 check(not fields.get("actual_photo_present",true) and fields.get("capture_record")==null,"actual injury alone creates no photograph, camera operator or capture receipt")

 observation_fixture("lobby",0)
 check(not observations3().available(observations3().specification("asylum_departure_page")),"no departure source page is invented before actual nurse paperwork")
 app.asylum.data.carry={"wheelchair_gone":true};app.asylum.data.registered=true;actor3("registration_nurse")
 check(not observations3().available(observations3().specification("asylum_departure_page")) and not app.rules.owners.has("asylum_departure_copy"),"legacy wheelchair departure and registration flags alone cannot create a readable page or missing owner")
 app.asylum.data.departure_page=true
 check(not observations3().available(observations3().specification("asylum_departure_page")) and not app.rules.owners.has("asylum_departure_copy"),"even a legacy page flag and actual nurse without its real source record cannot fabricate paper ownership")
 observation_fixture("lobby",0)
 app.asylum.data.carry={"wheelchair_gone":true};actor3("registration_nurse")
 check(until3(func():return app.asylum.data.get("departure_page",false),4),"existing registration action actually finishes before its source copy becomes readable")
 check(app.rules.owners.get("asylum_departure_copy","")=="registration_nurse" and not observations3().state().read.has("asylum_departure_page"),"presented copy has a real holder and is not already independently read")
 var prior_facts:int=app.rules.facts.size();var prior_records:int=app.rules.institutional_records.size()
 var legacy_paper:Dictionary=observations3().matching_record("asylum_departure_copy:")
 app.rules.owners.erase("asylum_departure_copy")
 check(observations3().available(observations3().specification("asylum_departure_page")) and app.rules.owners.get("asylum_departure_copy","")=="registration_nurse","legacy integer-attempt source ID recovers its already-present original paper holder")
 app.rules.owners.erase("asylum_departure_copy");legacy_paper.id="asylum_departure_copy:unknown"
 check(not observations3().available(observations3().specification("asylum_departure_page")) and not app.rules.owners.has("asylum_departure_copy"),"unknown source attempt string cannot recover a paper owner")
 legacy_paper.id="asylum_departure_copy:%d.5"%app.rules.actual_attempt
 check(not observations3().available(observations3().specification("asylum_departure_page")) and not app.rules.owners.has("asylum_departure_copy"),"fractional source attempt cannot be rounded into a matching original copy")
 legacy_paper.id="asylum_departure_copy:%d.0"%app.rules.actual_attempt
 app.rules.owners.erase("asylum_departure_copy");app.asylum.data.departure_page=false
 check(not observations3().available(observations3().specification("asylum_departure_page")) and not app.rules.owners.has("asylum_departure_copy"),"real source record alone without presented-page state cannot restore a missing owner")
 app.asylum.data.departure_page=true;app.asylum.actor("registration_nurse").phase="gone"
 check(not observations3().available(observations3().specification("asylum_departure_page")) and not app.rules.owners.has("asylum_departure_copy"),"legacy original page with departed nurse remains unavailable rather than recreating its carrier")
 app.asylum.actor("registration_nurse").phase="idle";app.rules.owners.asylum_departure_copy="hero"
 check(not observations3().available(observations3().specification("asylum_departure_page")) and app.rules.owners.asylum_departure_copy=="hero","explicit existing alternate ownership is never overwritten by legacy compatibility")
 app.rules.owners.asylum_departure_copy=""
 check(not observations3().available(observations3().specification("asylum_departure_page")) and app.rules.owners.has("asylum_departure_copy") and app.rules.owners.asylum_departure_copy=="","explicit existing empty owner is retained rather than interpreted as a missing legacy field")
 app.rules.owners.erase("asylum_departure_copy")
 check(roundtrip(),"older-style real departure page without newly introduced ownership key survives normal checksummed JSON")
 check(observations3().available(observations3().specification("asylum_departure_page")) and app.rules.owners.get("asylum_departure_copy","")=="registration_nurse","actual legacy page/source record/present original nurse conservatively recover only missing holder metadata")
 check(app.rules.facts.size()==prior_facts and app.rules.institutional_records.size()==prior_records and not observations3().state().read.has("asylum_departure_page"),"legacy holder recovery creates no factual event, institutional copy, signature or completed read")
 until3(func():return app.asylum.data.get("registration_state",{}).get("read",false),8);step3()
 app.hero_pos=app.asylum.position("registration_nurse")+Vector2(0.4,0)
 check(observations3().begin("asylum_departure_page"),"actual nearby holder permits separate page-turn preparation")
 step3(0.35);var partial:float=float(observations3().state().active.get("elapsed",-1))
 check(not observations3().state().read.has("asylum_departure_page") and partial>0,"unfinished contact does not prematurely record the departure page")
 check(roundtrip() and is_equal_approx(float(observations3().state().active.get("elapsed",-2)),partial),"normal disk JSON retains the independent partly turned page")
 observations3().cancel();step3(1)
 check(not observations3().state().read.has("asylum_departure_page"),"cancelled page turning does not finish after reload")
 check(observe3("asylum_departure_page"),"a fresh actual page turn reads the existing nurse-held copy")
 fields=observations3().state().read.get("asylum_departure_page",{}).get("fields",{})
 check(not fields.get("identity_confirmed",true) and not fields.get("transfer_witnessed",true) and str(fields.get("paper",{}).get("text","")).contains("自行离院"),"reading institutional self-departure wording is not identity confirmation or a new transfer witness")
 await capture("01_departure_copy_after_actual_read")

 observation_fixture("group_therapy",5);actor3("therapist")
 check(observations3().begin("asylum_signature_record"),"existing clinician clipboard has an independently reachable signature attachment")
 step3(0.3);app.asylum.actor("therapist").room="corridor";step3(0.8)
 check(not observations3().state().read.has("asylum_signature_record") and observations3().state().active.is_empty(),"holder leaving the room interrupts unfinished signature-page reading")
 app.asylum.actor("therapist").room="group_therapy"
 check(observe3("asylum_signature_record"),"actual attachment can be inspected when its original holder returns")
 fields=observations3().state().read.get("asylum_signature_record",{}).get("fields",{})
 check(fields.get("actual_signature")==null and fields.get("proxy_signature")==null and fields.get("prefilled_name")==null,"inspecting a signature sheet never manufactures signing, proxy signing or a prefilled name")

 observation_fixture("group_therapy",2)
 check(not observations3().available(observations3().specification("asylum_statement_paper")),"a sheet not handed over is not exposed to the reader")
 actor3("therapist","group_therapy",app.asylum.ward_events.target_point("group_therapy",5));actor3("speaker","group_therapy",app.asylum.ward_events.target_point("group_therapy",2))
 check(until3(func():return app.asylum.ward_events.state().therapy.paper=="speaker",30),"original recording and real handover expose the one statement sheet")
 app.hero_pos=app.asylum.position("speaker")+Vector2(-0.4,0);step3()
 check(observe3("asylum_statement_paper"),"original handed-over statement has its own completed read")
 fields=observations3().state().read.get("asylum_statement_paper",{}).get("fields",{})
 check(fields.get("text","")=="此前所述均不属实" and fields.get("acknowledged")==null and fields.get("actually_signed")==null,"only the exact supplied sentence is acquired, without manufacturing assent or signature")
 check(app.rules.owners.get("asylum_statement_paper","")=="speaker","reading leaves the original statement owned by its actual recipient")
 await capture("02_statement_after_real_handover")

 observation_fixture("workshop",1)
 check(not observations3().available(observations3().specification("asylum_product_label")),"loose material cannot be read as a completed labelled box")
 actor3("labor_patient","workshop",app.asylum.ward_events.target_point("workshop",7))
 check(until3(func():return app.asylum.ward_events.state().work.phase=="done",35),"worker really takes paper, folds, flattens, fetches label, pastes and places product")
 app.hero_pos=app.asylum.ward_events.target_point("workshop",1);step3()
 check(observe3("asylum_product_label"),"physically finished label permits separate completed read")
 fields=observations3().state().read.get("asylum_product_label",{}).get("fields",{})
 check(fields.get("folded",false) and fields.get("label_pasted",false) and fields.get("batch")==null and fields.get("contents")==null,"real product states are known while unknown batch and box contents remain unknown")
 await capture("03_finished_product_read")

 observation_fixture("group_therapy",5);actor3("therapist","group_therapy",Vector2(3.0,1.5));app.hero_pos=Vector2(2.5,1.5)
 check(await legal_control(),"normal CRT submits the paid CONTROL before mouse-reading an attached paper")
 var paper:Dictionary={}
 for item in app.view.asylum_props():
  if item.id=="asylum_signature_record":paper=item
 check(not paper.is_empty(),"real held-paper marker is rendered and selectable at its holder")
 if not paper.is_empty():
  var pixel:Vector2=app.view.asylum_item_pixel(paper)
  var screen:Vector2=(app.world_viewport.get_canvas_transform()*pixel)*2
  var motion_event:=InputEventMouseMotion.new();motion_event.position=screen;Input.parse_input_event(motion_event);await frames(2)
  for down in [true,false]:
   var event:=InputEventMouseButton.new();event.position=screen;event.global_position=screen;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;Input.parse_input_event(event);await frames(2)
  check(await await_live(func():return observations3().state().read.has("asylum_signature_record"),3),"actual world mouse selects the paper and completes normal approach/contact/read rather than a debug grant")
  await capture("04_real_control_mouse_signature_read")
 finish3()
