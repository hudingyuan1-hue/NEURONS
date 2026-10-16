extends "res://tests/hospital_check.gd"
## Same two original objects, same porter, real contacts and finite explicit
## fixtures. Does not assert natural random branches or subjective art/audio.

func relic_fixture() -> void:
 hospital_fixture("lobby");app.hero_pos=Vector2(3.5,2.2)
 spawn_actor("guide",Vector2(2.4,1.4));spawn_actor("wheelchair",Vector2(2.8,1.4));spawn_actor("porter",Vector2(3.15,1.4))
 app.rules.owners.family_photo="wheelchair"
 app.rules.owners.erase("patient_shoe");app.rules.owners.erase("hospital_relic_container")

func canonical_relic(value) -> String:return JSON.stringify(JSON.parse_string(JSON.stringify(value)),"",true)

func delivery() -> Dictionary:return app.hospital.data.get("relic_delivery",{})

func photo_phase() -> String:return str(app.hospital.data.get("transport",{}).get("phase",""))

func walk_observer_until(to:Vector2,predicate:Callable,seconds:float=6.0) -> bool:
 var from:Vector2=app.hero_pos
 app.hero_route=app.layout.path(app.hero_pos,to)
 if app.hero_route.is_empty():return false
 app.motion={"speed":1.2}
 # Inspect the target contact during the real walk. Waiting until a distant
 # observer finishes walking can silently step past the short pickup window.
 return hospital_until(predicate,seconds) and app.hero_pos.distance_to(from)>0.4

func finish_suite() -> void:
 var file:=FileAccess.open(ProjectSettings.globalize_path(folder).path_join("result.json"),FileAccess.WRITE)
 file.store_string(JSON.stringify({"passes":passes,"failures":failures,"rendered":true,"scope":"S3:P436/P656/T20 original photo and shoe, real wheelchair/drop anchors, final-doorway collection before chair exit, same porter's body-obstructed return and pickup, contact/finish clocks, actual receipt-backed manifest, manual pause/JSON, protagonist-owned and departed-old-chair boundaries. Fixed actors/observer position are explicit reproducible fixtures; no new patient/dialogue/gate, no natural random all-branch or art/audio acceptance."},"  "));file.close()
 print("HOSPITAL_RELIC_PACKING_CHECK %d passed %d failed"%[passes.size(),failures.size()])
 frontend.request_exit(0 if failures.is_empty() else 1)

func _ready() -> void:
 folder="res://../docs/validation/b3_20261016/hospital_relic_packing"
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--validation-root="):folder=argument.trim_prefix("--validation-root=")
 name="CampaignCheck";frontend=get_parent();DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 await frames();frontend.show_profile();await frames();frontend.name_field.text="原物实际装袋验证"
 frontend.overwrite_armed=true;frontend.new_game();await frames();app=frontend.active
 if app.tutorial_ui!=null:app.tutorial_ui.finish()

 relic_fixture()
 check(app.hospital.relic_position("family_photo").is_empty() and app.hospital.relic_position("patient_shoe").is_empty(),"before real frame contact no dropped photograph or shoe is invented")
 check(hospital_until(func():return photo_phase()=="fingers",25),"actual paperwork and wheelchair motion reach original door-frame event")
 var shoe:Dictionary=app.hospital.relic_position("patient_shoe").duplicate(true)
 var photo:Dictionary=app.hospital.relic_position("family_photo").duplicate(true)
 check(not shoe.is_empty() and not photo.is_empty() and app.rules.owners.patient_shoe=="lobby_floor" and app.rules.owners.family_photo=="wheelchair_footplate","real frame contact leaves original shoe on floor and original photo on actual footplate")
 check(not receipt("patient_transport") and delivery().is_empty(),"physical falling alone is neither completed transfer nor a packed bag")
 check(hospital_until(func():return photo_phase()=="photo_contact",12),"same porter finishes actual push and prepares to collect at still-visible chair")
 check(app.hospital.present("wheelchair") and app.rules.owners.family_photo=="wheelchair_footplate" and not app.hospital.data.get("wheelchair_gone",false),"chair remains physically present until photograph contact; no distant departed-chair recovery")
 var before:String=canonical_relic(app.hospital.data.transport)
 check(roundtrip() and canonical_relic(app.hospital.data.transport)==before,"actual mid-contact JSON preserves original photo owner and remaining collection clock")
 var clock:float=float(app.hospital.data.clock)
 await frames(5)
 check(canonical_relic(app.hospital.data.transport)==before and is_equal_approx(float(app.hospital.data.clock),clock),"real manual pause freezes photo contact and hospital clock")
 check(hospital_until(func():return photo_phase()=="photo_finish",2),"photo transfers only after actual preparation and contact")
 check(app.rules.owners.family_photo=="hospital_relic_container" and delivery().items==["family_photo"] and not receipt("patient_transport"),"one original photograph is in the same container before ordinary transfer completion")
 var key:String=str(delivery().packed_receipts.get("family_photo",""))
 check(str(app.hospital.data.receipts.get(key,""))=="hospital_relic_packed" and delivery().source_owners.family_photo=="wheelchair_footplate","manifest stores a real one-time physical packing receipt and original support")
 check(hospital_until(func():return app.hospital.data.get("wheelchair_gone",false),2),"same transfer then completes and original patient really leaves")
 check(receipt("patient_transport") and str(app.hospital.data.receipts.get(str(delivery().transport_receipt),""))=="patient_transport_completed","original departure receipt is distinct from photo packing and satisfies source contract")
 check(not delivery().ready and app.rules.owners.patient_shoe=="lobby_floor","shoe remains at original floor location while porter still has to return")
 check(canonical_relic(app.hospital.relic_position("patient_shoe").pos)==canonical_relic(shoe.pos),"moving chair and porter never move original dropped shoe along with them")

 # Mid-state body blocker fixture occupies the real pickup stand. It does
 # not forge packing completion and is then removed by an actual walk.
 var at:Vector2=Vector2(float(shoe.pos[0]),float(shoe.pos[1]))
 app.hero_pos=at+Vector2(0,0.5)
 hospital_step(7)
 check(app.rules.owners.patient_shoe=="lobby_floor" and not delivery().ready,"occupied pickup stand blocks actual return and cannot trigger a remote shoe collection")
 before=canonical_relic(app.hospital.data.relic_packing)
 check(roundtrip() and canonical_relic(app.hospital.data.relic_packing)==before,"JSON preserves blocked packing route instead of finishing it during load")
 check(walk_observer_until(Vector2(3.6,2.2),func():return app.hospital.data.relic_packing.phase=="shoe_contact",6),"blocking observer physically walks away along existing collision navigation while each actual pickup phase is inspected")
 check(hospital_until(func():return app.hospital.data.relic_packing.phase=="shoe_contact",12),"same porter reaches original shoe before a visible separate pickup contact")
 check(app.rules.owners.patient_shoe=="lobby_floor" and not delivery().ready,"shoe preparation is not yet ownership or completed manifest")
 check(hospital_until(func():return app.hospital.data.relic_packing.phase=="shoe_finish",2),"actual shoe pickup puts original item into porter's already-held container")
 check(app.rules.owners.patient_shoe=="hospital_relic_container" and not delivery().ready,"real contact and final packing completion remain separate nodes")
 check(hospital_until(func():return app.hospital.data.relic_packing.phase=="carry_exit",2) and not delivery().ready,"pickup finish starts actual carry-to-exit movement without remotely delivering container")
 check(hospital_until(func():return delivery().get("ready",false),5),"actual same porter reaches original transfer exit before source container becomes ready")
 check(delivery().items.size()==2 and app.rules.owners.hospital_relic_container=="hospital_relic_carry" and int(delivery().source_attempt)==app.rules.actual_attempt,"same original photograph and shoe share one actually carried source-attempt container")
 check(delivery().get("bag_departed",false) and Vector2(float(delivery().exit_pos[0]),float(delivery().exit_pos[1])).distance_to(Vector2(1.25,0.2))<0.035 and app.hospital.present("porter"),"manifest preserves actual bag exit position without deleting porter needed by original laundry task")
 check(hospital_until(func():return app.hero_pos.distance_to(Vector2(3.6,2.2))<0.04,6),"same observer continues the remaining actual route after contact observations")
 key=str(delivery().packed_receipts.patient_shoe)
 check(str(app.hospital.data.receipts.get(key,""))=="hospital_relic_packed" and delivery().source_owners.patient_shoe=="lobby_floor","shoe manifest entry has its own actual contact receipt and original floor support")
 before=canonical_relic(delivery())
 check(roundtrip() and canonical_relic(delivery())==before,"actual checksummed JSON preserves complete source contract and original-object ownership")
 hospital_step(3)
 check(canonical_relic(delivery())==before and delivery().items.size()==2,"continued frames never duplicate photograph, shoe or packing receipt")
 await capture("01_actual_original_relic_container")

 relic_fixture();app.rules.owners.family_photo="hero"
 check(hospital_until(func():return app.hospital.data.get("wheelchair_gone",false),35),"patient transfer still completes when protagonist already holds the photo")
 check(hospital_until(func():return delivery().get("ready",false),15),"same porter may really collect remaining shoe without recovering protagonist's photo")
 check(app.rules.owners.family_photo=="hero" and delivery().items==["patient_shoe"] and not delivery().packed_receipts.has("family_photo"),"protagonist-owned photo is neither overwritten, copied nor included as bag content")

 relic_fixture()
 check(hospital_until(func():return photo_phase()=="photo_contact",35),"interrupted photo-contact case reaches genuine physical contact window")
 app.rules.owners.family_photo="hero"
 hospital_step(0.1)
 check(app.rules.owners.family_photo=="hero" and not receipt("relic_packed:family_photo"),"ownership lost before contact cancels unfinished packing without recovering hero item")

 relic_fixture()
 check(hospital_until(func():return app.hospital.data.get("wheelchair_gone",false),35),"shoe-owned boundary first executes genuine photograph packing and patient departure")
 app.rules.owners.patient_shoe="hero"
 check(hospital_until(func():return delivery().get("ready",false),8),"container with actual photograph can finish departure without taking protagonist's shoe")
 check(app.rules.owners.patient_shoe=="hero" and delivery().items==["family_photo"] and not delivery().packed_receipts.has("patient_shoe"),"source contract contains only actually packed photo and preserves independently held original shoe")

 relic_fixture()
 check(hospital_until(func():return app.hospital.data.get("wheelchair_gone",false),35),"departed-porter boundary begins with actual partial container")
 app.hospital.actor("porter").phase="gone"
 before=canonical_relic(delivery())
 hospital_step(5)
 check(canonical_relic(delivery())==before and not delivery().ready and app.rules.owners.patient_shoe=="lobby_floor","absent real carrier cannot remotely complete pending shoe pickup or leave a ready bag")
 check(roundtrip() and canonical_relic(delivery())==before,"JSON preserves partial container when its actual carrier has departed")

 # Explicit old-save fixture: prior code recorded gone/support ownership but
 # no real recoverable prop anchor or packing receipts. It must stay partial.
 hospital_fixture("lobby");spawn_actor("porter",Vector2(1.25,0.2));spawn_actor("guide",Vector2(2.4,1.4))
 app.hospital.actor("wheelchair").phase="gone";app.hospital.data.wheelchair_gone=true
 app.hospital.data.receipts["hospital:%d:patient_transport"%app.rules.actual_attempt]="patient_transport_completed"
 app.rules.owners.family_photo="wheelchair_footplate";app.rules.owners.patient_shoe="lobby_floor"
 check(roundtrip(),"old departed-chair snapshot loads through actual save pipeline")
 hospital_step(8)
 check(app.hospital.relic_position("family_photo").is_empty() and delivery().is_empty() and app.rules.owners.family_photo=="wheelchair_footplate","stale old ownership does not fabricate an accessible departed footplate or packed photo")
 check(not receipt("relic_packed:family_photo") and not receipt("relic_packed:patient_shoe"),"old gone snapshot without real prop anchors cannot fabricate any new packing receipt")
 finish_suite()
