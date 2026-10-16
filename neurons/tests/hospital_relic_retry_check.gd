extends "res://tests/asylum_intake_chain_check.gd"
## S4:T27R3 long-term originals across the real restart handler. Each case
## starts an independent trio fixture, then keeps actual runtime history.
var retry_cases:Array=[]

func retry_fixture() -> void:
 relic_fixture();app.asylum.data={};app.asylum.enabled=true

func fact_for(id:String) -> Dictionary:
 for fact in app.rules.facts:
  if str(fact.get("event_id",""))==id:return fact
 return {}

func actual_actor_positions() -> Dictionary:
 var result:Dictionary={}
 for id in ["guide","wheelchair","porter"]:
  var actor:Dictionary=app.hospital.actor(id)
  result[id]={"phase":actor.phase,"room":actor.room,"pos":actor.pos.duplicate(),"route":actor.route.duplicate(true)}
 return result

func actual_retry() -> void:
 app.restart_attempt(1,false);app.session.data.exploration_boundary=true
 # Ordinary groups are isolated only as declared scheduling fixtures, not
 # completed bodies/medical outcomes. The retained original trip is untouched.
 for group in app.hospital.data.groups:
  app.hospital.data.groups[group].drawn=true;app.hospital.data.groups[group].pending=false

func receive_retry_bag() -> bool:
 # This explicit outlet-key fixture isolates item continuity from the
 # separately tested random key search. All doors/contact/hook steps are real.
 app.rules.owners.key="hero";app.session.data.key_owner="hero"
 app.session.data.exploration_boundary=false;app.route_to_door("lobby")
 if not hospital_until(func():return app.room_id=="lobby",12):return false
 app.route_to_door("stairs")
 if not hospital_until(func():return int(app.session.data.level)==3,12):return false
 app.session.data.exploration_boundary=true
 if facts_of("asylum_relic_delivery_arrived")!=1 or intake_chain().bag_holder()!="asylum_intake_delivery":return false
 for group in app.asylum.data.groups:
  app.asylum.data.groups[group].drawn=true;app.asylum.data.groups[group].pending=false
 var nurse:Dictionary=app.asylum.actor("registration_nurse")
 var desk:Vector2=app.asylum.layout_for("lobby").furniture[0].at
 nurse.phase="idle";nurse.room="lobby";nurse.pos=[desk.x,desk.y];nurse.route=[]
 return hospital_until(func():return intake_chain().state().phase=="stored",20) and intake_chain().bag_holder()=="asylum_registration_desk" and intake_chain().current_items().size()==2

func finish_retry() -> void:
 var output:=FileAccess.open(ProjectSettings.globalize_path(folder).path_join("result.json"),FileAccess.WRITE)
 output.store_string(JSON.stringify({"passes":passes,"failures":failures,"rendered":true,"cases":retry_cases,"scope":"S4:T27R3 actual restart handler preserves ready and incomplete original-object packing. Production source attempt remains distinct from current attempt; genuine pickup facts retain source receipt IDs and record actual occurrence attempt. Two partial cases then use normal keyed door/navigation/hook and real L3 nurse reception/storage.","fixtures":"Independent initial L2 trio/photo fixtures and isolated random groups. Restart is explicitly invoked through the same production restart_attempt handler; this is not a claim of naturally walking the full return-to-bed route. Each cross-chapter case declares only a held exit-key fixture and existing B3 nurse's initial desk presence. No completed transfer/packing/intake/read, source attempt alignment, concrete glyph or recognition is injected."},"  "));output.close()
 print("HOSPITAL_RELIC_RETRY_CHECK %d passed %d failed"%[passes.size(),failures.size()])
 frontend.request_exit(0 if failures.is_empty() else 1)

func _ready() -> void:
 folder="res://../docs/validation/b3_finish_20261016/relic-retry"
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--validation-root="):folder=argument.trim_prefix("--validation-root=")
 name="CampaignCheck";frontend=get_parent();DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 await frames();frontend.show_profile();await frames();frontend.name_field.text="原物跨重试保存验证"
 frontend.overwrite_armed=true;frontend.new_game();await frames();app=frontend.active
 if app.tutorial_ui!=null:app.tutorial_ui.finish()

 retry_fixture()
 check(hospital_until(func():return delivery().get("ready",false),40),"ready-container case first physically collects both originals and reaches real exit")
 var manifest:String=canonical_relic(delivery());var actors:String=canonical_relic(actual_actor_positions())
 var source_attempt:int=int(delivery().source_attempt)
 var packing_count:int=facts_of("hospital_relic_packed");var transport_count:int=facts_of("patient_transport_completed")
 actual_retry()
 check(app.rules.actual_attempt==source_attempt+1 and app.room_id=="ward" and int(delivery().source_attempt)==source_attempt,"genuine L2 restart increments current attempt and returns to bed without changing source trip attempt")
 check(canonical_relic(delivery())==manifest and app.rules.owners.family_photo=="hospital_relic_container" and app.rules.owners.patient_shoe=="hospital_relic_container","ready long-term container and both unique originals survive restart unchanged")
 check(canonical_relic(actual_actor_positions())==actors and app.hospital.data.groups.lobby.drawn,"already appeared source trio retains actual locations/gone states rather than respawning another patient")
 check(str(app.hospital.data.receipts.get(str(delivery().transport_receipt),""))=="patient_transport_completed" and str(app.hospital.data.receipts.get(str(delivery().packed_receipts.family_photo),""))=="hospital_relic_packed","retained ready manifest still references its actual original source receipts")
 check(roundtrip() and canonical_relic(delivery())==manifest,"checksummed JSON retains ready container after actual restart")
 hospital_step(3)
 check(facts_of("hospital_relic_packed")==packing_count and facts_of("patient_transport_completed")==transport_count and app.rules.sp==100,"ready retry does not repeat original collection, transfer or witness mental loss")
 retry_cases.append({"id":"ready_restart","manifest":delivery().duplicate(true),"current_attempt":app.rules.actual_attempt,"original_packing_count":facts_of("hospital_relic_packed"),"original_transport_count":facts_of("patient_transport_completed")})

 retry_fixture()
 check(hospital_until(func():return photo_phase()=="photo_contact",35),"first partial case reaches real original photograph contact before collection")
 hospital_step(0.1)
 var elapsed:float=float(app.hospital.data.transport.elapsed)
 actors=canonical_relic(actual_actor_positions());source_attempt=app.hospital.relic_source_attempt()
 check(elapsed>0 and app.rules.owners.family_photo=="wheelchair_footplate" and delivery().is_empty(),"unfinished photo contact has an existing physical footplate anchor but no packed manifest")
 actual_retry()
 check(app.rules.actual_attempt==source_attempt+1 and app.hospital.relic_source_attempt()==source_attempt and photo_phase()=="photo_contact" and is_equal_approx(float(app.hospital.data.transport.elapsed),elapsed),"retry preserves same uncompleted source photo contact while current attempt advances normally")
 check(canonical_relic(actual_actor_positions())==actors and app.rules.owners.family_photo=="wheelchair_footplate","partial retry preserves actual appeared actors and original photo on still-present chair")
 check(roundtrip() and photo_phase()=="photo_contact" and app.hospital.relic_source_attempt()==source_attempt,"partial photo JSON preserves frozen source and unfinished contact without a forged pickup")
 check(hospital_until(func():return delivery().get("ready",false),20),"continued original actors genuinely finish photo, original transfer, shoe and carry exit after retry")
 var photo_key:String="hospital:%d:relic_packed:family_photo"%source_attempt
 var transfer_key:String="hospital:%d:patient_transport"%source_attempt
 var photo_fact:Dictionary=fact_for(photo_key);var transfer_fact:Dictionary=fact_for(transfer_key)
 check(delivery().packed_receipts.family_photo==photo_key and int(photo_fact.get("occurrence_attempt",0))==app.rules.actual_attempt and int(photo_fact.get("source_attempt",0))==source_attempt,"actual post-retry photo fact uses original source receipt and separately records current occurrence attempt")
 check(delivery().transport_receipt==transfer_key and int(transfer_fact.get("occurrence_attempt",0))==app.rules.actual_attempt and facts_of("patient_transport_completed")==1,"post-retry original transport finishes once under the same original source ID")
 check(facts_of("hospital_relic_packed")==2 and app.rules.sp==100,"partial offscreen retry yields exactly two original pickups and no replayed witness penalty")
 check(receive_retry_bag(),"photo-contact retry crosses actual keyed doors and normal hook then genuinely receives/stores same source container in L3")
 check(int(intake_chain().state().delivery.source_attempt)==source_attempt and facts_of("asylum_relic_delivery_arrived")==1 and facts_of("asylum_relic_container_received")==1 and facts_of("asylum_relic_container_stored")==1,"L3 validates original-attempt receipt chain after real retry without duplicating arrival or intake")
 retry_cases.append({"id":"partial_photo_retry_then_actual_intake","manifest":app.hospital.data.relic_delivery.duplicate(true),"photo_fact":photo_fact,"transport_fact":transfer_fact,"intake":intake_chain().state().duplicate(true)})

 retry_fixture()
 check(hospital_until(func():return app.hospital.data.get("relic_packing",{}).get("phase","")=="shoe_contact",40),"second partial case really finishes transfer and returns to shoe before its pickup contact")
 hospital_step(0.1)
 elapsed=float(app.hospital.data.relic_packing.elapsed);source_attempt=app.hospital.relic_source_attempt()
 actors=canonical_relic(actual_actor_positions())
 check(delivery().items==["family_photo"] and app.rules.owners.patient_shoe=="lobby_floor" and facts_of("patient_transport_completed")==1,"partially loaded original container and still-uncollected shoe remain separate before retry")
 actual_retry()
 check(app.hospital.data.relic_packing.phase=="shoe_contact" and is_equal_approx(float(app.hospital.data.relic_packing.elapsed),elapsed) and canonical_relic(actual_actor_positions())==actors,"return-shoe retry preserves real porter position, existing partial bag and remaining contact clock")
 check(roundtrip() and delivery().items==["family_photo"] and app.rules.owners.patient_shoe=="lobby_floor","post-retry partial bag JSON cannot swallow the original shoe or create its pickup receipt")
 check(hospital_until(func():return delivery().get("ready",false),8),"same retained porter truly finishes shoe pickup and original exit after retry")
 var shoe_key:String="hospital:%d:relic_packed:patient_shoe"%source_attempt
 var shoe_fact:Dictionary=fact_for(shoe_key)
 check(delivery().packed_receipts.patient_shoe==shoe_key and int(shoe_fact.get("occurrence_attempt",0))==app.rules.actual_attempt and facts_of("hospital_relic_packed")==2 and facts_of("patient_transport_completed")==1,"continued shoe contact writes only its one original-source receipt and no second patient transfer")
 check(receive_retry_bag(),"return-shoe retry also uses normal keyed transition and actual nurse storage rather than seeding L3 acceptance")
 check(facts_of("asylum_relic_delivery_arrived")==1 and facts_of("asylum_relic_container_stored")==1 and app.rules.owners.family_photo=="hospital_relic_container" and app.rules.owners.patient_shoe=="hospital_relic_container","second partial path preserves one actual arrival/container with both unique originals")
 retry_cases.append({"id":"partial_shoe_retry_then_actual_intake","manifest":app.hospital.data.relic_delivery.duplicate(true),"shoe_fact":shoe_fact,"intake":intake_chain().state().duplicate(true)})

 # An old gone/support save has no new physical history to preserve or infer.
 retry_fixture();app.hospital.actor("wheelchair").phase="gone";app.hospital.data.wheelchair_gone=true
 app.rules.owners.family_photo="wheelchair_footplate";app.rules.owners.patient_shoe="lobby_floor"
 actual_retry();hospital_step(1)
 check(delivery().is_empty() and not app.hospital.data.has("transport_relics") and facts_of("hospital_relic_packed")==0,"old support strings without actual new anchors or manifest do not manufacture preserved packing history on retry")
 finish_retry()
