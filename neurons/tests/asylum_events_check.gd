extends "res://tests/asylum_check.gd"

func actor3(id:String,room:String="",at:Vector2=Vector2.INF) -> void:
 var a:Dictionary=app.asylum.actor(id)
 a.phase="idle";a.room=app.room_id if room.is_empty() else room
 var side:float=-1.0 if app.hero_pos.x>2.8 else 1.0
 a.pos=app.asylum.xy(app.hero_pos+Vector2(0.35*side,0) if at==Vector2.INF else at);a.route=[]

func rec3(id:String) -> bool:
 return app.asylum.data.receipts.has("asylum:%d:%s"%[app.rules.actual_attempt,id])

func pharmacy3(nurse:bool=false) -> bool:
 fixture3("clinic",true);app.session.data.exploration_boundary=true;actor3("doctor")
 if not until3(func():return app.rules.owners.get("asylum_medical_order","")=="hero",6):return false
 app.enter_room("pharmacy");app.hero_pos=Vector2(2.7,1.4);app.session.data.exploration_boundary=true;actor3("pharmacist")
 if nurse:actor3("med_nurse","",app.hero_pos+Vector2(-0.35,0))
 return until3(func():return app.asylum.data.body.get("kind","")=="raise_cup",8)

func _ready() -> void:
 folder="res://../docs/validation/b3_20261016/first_floor"
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--validation-root="):folder=argument.trim_prefix("--validation-root=")
 name="CampaignCheck";frontend=get_parent();DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 await frames();frontend.show_profile();await frames();frontend.name_field.text="精神病院人物验证"
 frontend.overwrite_armed=true;frontend.new_game();await frames();app=frontend.active
 if app.tutorial_ui!=null:app.tutorial_ui.finish()
 fixture3("ward",true);app.session.data.exploration_boundary=true;actor3("ordinary_orderly")
 check(app.asylum.data.actors.size()==21 and app.asylum.data.groups.size()==14,"B3 keeps twenty-one identities and fourteen linked scheduling groups")
 check(until3(func():return bool(app.asylum.data.wrist_done),4),"orderly actually approaches and finishes the normal wrist-card check")
 check(app.asylum.data.wrist_checked and app.rules.hp==100 and app.rules.sp==100 and not app.rules.gripped,"normal wrist check creates no injury or lingering holder")
 await capture("01_normal_wrist_check")
 fixture3("ward",true);app.session.data.exploration_boundary=true;actor3("ordinary_orderly")
 until3(func():return app.asylum.data.body.get("kind","")=="wrist_check",2);give_skill("WITHDRAW")
 check(cast("WITHDRAW").get("success",false),"real paid withdrawal refuses an unfinished wrist check")
 check(app.asylum.data.body.get("kind","")=="wrist_reach" and app.rules.hp==100,"refusal starts visible reach before any wrist injury")
 check(until3(func():return app.rules.gripped,3),"actual wrist contact establishes the sole holder")
 check(app.rules.hp==95 and app.rules.sp==95 and app.asylum.data.holder=="ordinary_orderly","one real wrist twist costs exactly five HP and five SP")
 check(roundtrip() and app.rules.gripped,"real JSON retains the mid-hold remaining clock")
 check(until3(func():return not app.rules.gripped,2.1),"wrist hold releases within original two-second cap")
 step3(2);check(app.rules.hp==95 and app.rules.sp==95,"continued frames cannot duplicate wrist injury")
 check(pharmacy3(),"doctor writes diagnosis, independently signs and hands over order; pharmacist really receives, mixes and gives cup")
 check(rec3("diagnosis") and rec3("order_written") and rec3("order_received") and rec3("order_to_pharmacist"),"diagnosis, signed order and physical handovers retain separate receipts")
 check(app.rules.sp==100 and not app.asylum.data.swallowed and app.rules.owners.asylum_cup=="hero","holding full cup is not ingestion")
 step3(0.45);var sp:int=app.rules.sp
 check(roundtrip() and not app.asylum.data.swallowed,"half-raised-cup JSON preserves the visible swallowing window")
 check(until3(func():return bool(app.asylum.data.swallowed),2) and app.rules.sp==sp-20,"full one-second raise commits exactly original twenty-SP medicine effect")
 check(not app.asylum.data.cup_full and app.rules.owners.asylum_cup=="hero" and float(app.asylum.data.medicine_stop)>0,"swallow leaves one empty owned cup plus independent body stop")
 await capture("02_medicine_stop")
 step3(2);check(not app.rules.body_busy() and float(app.asylum.data.medicine_stop)<=0,"original medicine stop expires under world clock")
 sp=app.rules.sp;app.enter_room("corridor");app.enter_room("pharmacy");app.session.data.exploration_boundary=true;step3(3)
 check(app.rules.sp==sp and not app.asylum.data.cup_full,"cross-floor revisit cannot refill cup or repeat medication")
 check(pharmacy3(true),"refusal case receives an actual cup while nurse is present")
 give_skill("GUT");check(cast("GUT").get("success",false),"real GUT before swallowing performs refusal")
 check(app.asylum.data.refused and not app.asylum.data.swallowed and app.rules.sp==100,"refusal closes course without invented medicine injury")
 check(app.rules.owners.asylum_cup=="asylum_counter" and app.asylum.data.has("false_record"),"same cup is placed while separate nurse writing is still pending")
 check(until3(func():return rec3("false_medicine"),5),"nurse physically approaches cup and completes false record")
 check("asylum_false_medicine_seen" in app.rules.known and not app.asylum.data.swallowed,"full witness reveals paper falsification without changing real ingestion")
 check(roundtrip() and app.asylum.data.refused,"JSON preserves refusal and forged paper independently")
 await capture("03_false_record")
 check(pharmacy3(true),"remote writing case receives same actual full cup")
 give_skill("GUT");cast("GUT");app.enter_room("clinic");app.session.data.exploration_boundary=true
 check(until3(func():return rec3("false_medicine"),7),"nurse can physically finish offscreen after protagonist leaves")
 check(not "asylum_false_medicine_seen" in app.rules.known and not app.asylum.data.swallowed,"offscreen record gives no fabricated full-view evidence or ingestion")
 fixture3("clinic",true);app.session.data.exploration_boundary=true;app.hero_pos=app.layout.furniture[3].at
 actor3("doctor");actor3("assistant","",app.hero_pos+Vector2(-0.35,0))
 check(until3(func():return app.asylum.data.exam.get("phase","")=="reach",4),"assistant receives instruction and physically reaches before closing cuff")
 check(app.rules.hp==100 and not app.rules.gripped,"assistant reach is not already a grip or injury")
 give_skill("WITHDRAW");cast("WITHDRAW")
 check(until3(func():return app.asylum.data.exam.is_empty(),4) and app.rules.hp==100 and not app.rules.gripped,"effective pre-contact withdrawal prevents cuff injury")
 fixture3("clinic",true);app.session.data.exploration_boundary=true;app.hero_pos=app.layout.furniture[3].at
 actor3("doctor");actor3("assistant","",app.hero_pos+Vector2(-0.35,0))
 check(until3(func():return rec3("assistant_grip"),5),"real cuff contact creates its own receipt")
 check(app.rules.hp==95 and app.rules.sp==100,"real cuff tightening costs only original five HP")
 check(until3(func():return not app.rules.gripped,3.1),"assistant releases at record finish or three-second cap")
 await capture("04_assistant_released")
 fixture3("clinic",true);app.session.data.targets=[];app.rules.sp=40;actor3("doctor");actor3("assistant","",app.hero_pos+Vector2(-0.35,0))
 step3(0.5)
 check(not app.asylum.data.diagnosed and app.asylum.data.body.is_empty() and app.asylum.data.exam.is_empty(),"new medical invitation cannot steal low-SP return-to-bed priority")
 check(app.action_phase=="door" and app.destination=="lobby","low-SP hero really starts the existing clinic-to-ward return path")
 hospital_fixture("lobby")
 var old:Dictionary=app.snapshot_data();old.erase("asylum_state")
 app.asylum.data.ward_events.work={"phase":"future-marker","products":123}
 check(app.store.save_snapshot(old).ok and app.restore_snapshot(app.store.load_snapshot().data),"older L2 JSON without B3 state genuinely loads through the existing save pipeline")
 check(app.asylum.data.ward_events.is_empty(),"loading an older save cannot inherit workshop materials or products from the abandoned future runtime")
 finish3()
