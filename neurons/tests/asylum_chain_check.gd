extends "res://tests/asylum_ward_check.gd"
## Complete finite chains from initial actual actors, never pre-written reports.
func _ready() -> void:
 folder="res://../docs/validation/b3_20261016/chains"
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--validation-root="):folder=argument.trim_prefix("--validation-root=")
 name="CampaignCheck";frontend=get_parent();DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 await frames();frontend.show_profile();await frames();frontend.name_field.text="真实签联至隔离连续验证"
 frontend.overwrite_armed=true;frontend.new_game();await frames();app=frontend.active
 if app.tutorial_ui!=null:app.tutorial_ui.finish()
 station_transfer_fixture()
 actor3("isolation_orderly","corridor",Vector2(3.2,0.65))
 check(ward_state().reports.is_empty() and not ward_state().transfer.isolation_authorized,"transport chain begins with actual live patient/porter/head nurse, no written isolation result")
 check(until3(func():return bool(ward_state().transfer.delivered),30),"original porter really receives order, checks patient, obtains nurse signature and delivers bed across real door")
 check(rec3("transfer_order_to_nurse") and rec3("transfer_nurse_verified") and rec3("transfer_isolation_written") and rec3("transfer_isolation_signed") and rec3("transfer_order_to_porter"),"full onsite paper/contact/signature/return receipts arise from the one actual transfer")
 var report_id:String=str(ward_state().reports[0].id) if not ward_state().reports.is_empty() else ""
 check(not report_id.is_empty() and until3(func():return bool(app.asylum.isolation.state().door_closed),30),"isolation worker actually fetches the original signed authorization after delivery and closes on that same patient")
 check(app.asylum.actor("transport_patient").room=="quiet" and app.asylum.actor("porter").room=="corridor" and app.room_id=="corridor","real porter exits before close while the original live target stays inside and observing hero remains outside")
 check(app.asylum.isolation.state().target=="transport_patient" and app.asylum.isolation.order_id()==report_id and ward_state().reports.size()==1,"transport and isolation keep one stable report, target and live identity without an ordinary duplicate")
 await capture("01_full_transport_signature_to_real_closed_door")
 var closed:float=float(app.asylum.isolation.state().closed_elapsed)
 check(roundtrip() and is_equal_approx(float(app.asylum.isolation.state().closed_elapsed),closed),"full-chain mid-isolation JSON retains real closed-door time and paper receipt")
 await frames(10)
 check(is_equal_approx(float(app.asylum.isolation.state().closed_elapsed),closed),"pause freezes the full-chain isolation without resetting it")
 check(until3(func():return not app.asylum.isolation.state().door_closed and app.asylum.isolation.state().handled.has(report_id),10),"same patient's real closed-door eight-second observation opens and completes")
 check(app.asylum.isolation.state().handled.get(report_id,"")=="completed" and app.rules.hp==100 and app.rules.sp==100 and not app.rules.gripped,"NPC chain adds no hero injury, false treatment or permanent control")
 var receipts:String=canonical3(app.asylum.data.receipts)
 step3(4)
 check(ward_state().reports.size()==1 and not app.asylum.isolation.state().door_closed and canonical3(app.asylum.data.receipts)==receipts,"completed transfer/isolation does not respawn patient, duplicate paper or restart confinement")
 await capture("02_original_live_patient_after_observation")
 var f:=FileAccess.open(ProjectSettings.globalize_path(folder).path_join("result.json"),FileAccess.WRITE)
 f.store_string(JSON.stringify({"passes":passes,"failures":failures,"rendered":true,"scope":"Initial actor/position fixture only, then actual porter/head-nurse paper/verification/signature/delivery through real doors and isolation fetch/target/close/eight-second/open chain. No prewritten report or fabricated outcome; finite game-time automatic driver, not natural RNG/human play or formal audio/art acceptance."},"  "));f.close()
 print("ASYLUM_CHAIN_CHECK %d passed %d failed"%[passes.size(),failures.size()]);frontend.request_exit(0 if failures.is_empty() else 1)
