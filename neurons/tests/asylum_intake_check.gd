extends "res://tests/asylum_events_check.gd"
## Explicit saved L2 handoff fixtures exercise source/ownership validation.
## The positive fixture does not count as a test of L2 collection itself.
## Subsequent L3 movement/contact/placement/reading use normal world methods.

const Intake=preload("res://scripts/core/asylum_intake.gd")

func intake3():return app.asylum.intake

func intake_fixture(items:Array=["family_photo","patient_shoe"],recognised:bool=false) -> void:
 fixture3("lobby",true);app.session.data.exploration_boundary=true
 var receipt:String="hospital:1:patient_transport"
 var receipts:Dictionary={receipt:"patient_transport_completed"}
 var packed:Dictionary={};var origins:Dictionary={}
 for id in items:
  var key:String="hospital:1:relic_pack:"+str(id)
  receipts[key]="hospital_relic_packed";packed[id]=key
  origins[id]="wheelchair_footplate" if id=="family_photo" else "lobby_floor"
  app.rules.owners[str(id)]="hospital_relic_container"
 app.rules.owners.hospital_relic_container="hospital_relic_carry"
 app.asylum.data.carry={"wheelchair_gone":true,"receipts":receipts,"relic_delivery":{"version":1,"ready":true,"bag_departed":true,"exit_room":"lobby","exit_pos":[1.25,0.2],"source_attempt":1,"transport_receipt":receipt,"bag_id":"hospital_relic_container","items":items.duplicate(),"packed_receipts":packed,"source_owners":origins}}
 app.hero_pos=Vector2(4.2,1.3)
 actor3("registration_nurse","lobby",app.layout.furniture[0].at)
 if recognised:app.rules.known.append("hospital_family_photo_seen")

func intake_read(id:String) -> bool:
 var target:Dictionary=intake3().observation_target(id)
 if target.is_empty():return false
 app.hero_pos=Vector2(float(target.pos[0]),float(target.pos[1]));app.hero_route=PackedVector2Array();app.target_index=-1
 # A completed read can legitimately lead into the nearby registration
 # event. Let its real paperwork finish; never assign its success flags.
 if not until3(func():return app.asylum.data.get("body",{}).is_empty() and app.dialogue_queue.is_empty(),12):return false
 if not app.asylum.observations.begin(id,false):return false
 return until3(func():return app.asylum.observations.state().active.is_empty(),2) and intake3().state().read.has(id)

func has_photo_lines() -> bool:
 for line in app.dialogue_queue:
  if str(line.get("text","")) in ["照片是他一直拿着的。","再对一下袋上的号。"]:return true
 return false

func intake_receipts(kind:String) -> int:
 var count:int=0
 for fact in app.rules.facts:
  if str(fact.get("kind",""))==kind:count+=1
 return count

func finish_intake() -> void:
 var output:=FileAccess.open(ProjectSettings.globalize_path(folder).path_join("result.json"),FileAccess.WRITE)
 output.store_string(JSON.stringify({"passes":passes,"failures":failures,"rendered":true,
  "scope":"Finite L3 real path/contact/container placement plus source-bound validation and physical readings. L2 handoff provenance is an explicit saved-history fixture, not a claim of naturally playing the L2 collection sequence. GUI screenshot frames are only the captured finite cases; no formal-art/audio acceptance.",
  "fixtures":"L2 source receipt and unique original ownership only; no stored bag, completed L3 observation, recognition result or same-number identity is injected. The positive photo-prior fixture explicitly declares previously seen hospital_family_photo_seen."},"  "));output.close()
 print("ASYLUM_INTAKE_CHECK %d passed %d failed"%[passes.size(),failures.size()])
 frontend.request_exit(0 if failures.is_empty() else 1)

func _ready() -> void:
 folder="res://../docs/validation/b3_20261016/intake"
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--validation-root="):folder=argument.trim_prefix("--validation-root=")
 name="CampaignCheck";frontend=get_parent();DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 await frames();frontend.show_profile();await frames();frontend.name_field.text="遗物原件实际接收验证"
 frontend.overwrite_armed=true;frontend.new_game();await frames();app=frontend.active
 if app.tutorial_ui!=null:app.tutorial_ui.finish()
 if app.asylum.get("intake")==null:
  check(false,"intake module must be integrated before this real-world suite runs");finish_intake();return

 intake_fixture()
 app.asylum.data.carry={"wheelchair_gone":true}
 check(not intake3().arrive_from_hospital() and intake3().markers().is_empty(),"wheelchair_gone alone creates neither a relic bag nor readable evidence")
 intake_fixture();app.asylum.data.carry.receipts.erase("hospital:1:patient_transport")
 check(not intake3().arrive_from_hospital(),"even an explicit manifest cannot replace the missing real transport receipt")
 intake_fixture();app.asylum.data.carry.relic_delivery.source_attempt=2
 check(not intake3().arrive_from_hospital(),"receipt from another attempt cannot certify this source delivery")
 intake_fixture();app.asylum.data.carry.relic_delivery.bag_departed=false
 check(not intake3().arrive_from_hospital(),"packed objects whose same carrier has not finished its outgoing route cannot arrive early")
 intake_fixture();app.asylum.data.carry.receipts.erase("hospital:1:relic_pack:family_photo");app.rules.owners.patient_shoe="lobby_floor"
 check(not intake3().arrive_from_hospital() and app.rules.owners.patient_shoe=="lobby_floor","unpacked floor shoe and unreceipted photo are never pulled into L3")
 intake_fixture();app.rules.owners.family_photo="hero";app.rules.owners.patient_shoe="hero"
 check(not intake3().arrive_from_hospital() and app.rules.owners.family_photo=="hero" and app.rules.owners.patient_shoe=="hero","player-held originals cannot be copied into an otherwise valid saved manifest")

 intake_fixture();app.rules.owners.family_photo="hero"
 check(intake3().arrive_from_hospital() and intake3().current_items()==["patient_shoe"],"real packed shoe can arrive independently without duplicating the player's photo")
 check(app.rules.owners.family_photo=="hero" and app.rules.owners.patient_shoe=="hospital_relic_container","arrival moves only the actual container, preserving each original's sole owner")
 check(not intake3().arrive_from_hospital() and intake3().actor_reserved("registration_nurse"),"arrival is idempotent and the actual receiver is reserved during intake")

 intake_fixture()
 var before_n:int=app.rules.neurons;var before_search:int=app.rules.search_attempts
 check(intake3().arrive_from_hospital(),"validated serialized L2 container arrives only through the explicit transition hook")
 if intake3().state().phase=="waiting_source":finish_intake();return
 check(intake3().observation_target("asylum_relic_bag_number").is_empty(),"arriving container is not already stored or automatically read")
 check(until3(func():return intake3().state().phase=="receive",12),"same registration nurse actually navigates from the desk to the entrance container")
 check(app.asylum.position("registration_nurse").distance_to(intake3().bag_position())<=float(intake3().config.contact_distance),"nurse reaches genuine contact rather than collecting the bag across the room")
 step3(0.3)
 var elapsed:float=float(intake3().state().elapsed);var clock:float=app.rules.world_time
 check(intake3().bag_holder()=="asylum_intake_delivery" and elapsed>0,"visible receive preparation/contact precedes ownership transfer")
 check(roundtrip() and is_equal_approx(float(intake3().state().elapsed),elapsed),"checksummed JSON retains the partial receive clock and original container")
 await frames(10)
 check(is_equal_approx(app.rules.world_time,clock) and is_equal_approx(float(intake3().state().elapsed),elapsed),"manual pause freezes receiving and the world clock together")
 await capture("01_receive_contact")
 app.asylum.actor("registration_nurse").pos=[4.4,1.2];step3(0.05)
 check(intake3().state().phase=="approach" and intake3().bag_holder()=="asylum_intake_delivery","receiver losing actual contact cannot finish the pending handoff remotely")
 check(until3(func():return intake3().state().phase=="carry",14),"receiver reapproaches and completes one genuine container handoff")
 check(intake3().bag_holder()=="registration_nurse" and app.rules.owners.family_photo=="hospital_relic_container","carrying bag follows its nurse while the photo stays inside the same container")
 check(roundtrip() and intake3().bag_holder()=="registration_nurse","saved carrying stage restores physical ownership rather than redoing arrival")
 var carrier_pos:Vector2=app.asylum.position("registration_nurse")
 var bag_pos:Vector2=intake3().bag_position()
 var old_attempt:int=app.rules.actual_attempt
 app.restart_attempt(1,false);app.session.data.exploration_boundary=true
 check(app.rules.actual_attempt==old_attempt+1 and app.asylum.present("registration_nurse") and app.asylum.position("registration_nurse").is_equal_approx(carrier_pos),"genuine new attempt keeps the one already carrying nurse at its real saved location")
 check(intake3().bag_holder()=="registration_nurse" and intake3().bag_position().is_equal_approx(bag_pos) and app.asylum.data.groups.registration.drawn,"new attempt cannot erase its carrier, move the bag or roll a second registration nurse")
 check(until3(func():return intake3().state().phase=="stored",14),"nurse actually walks back to the desk and completes a distinct placement action")
 check(intake3().bag_holder()=="asylum_registration_desk" and not intake3().actor_reserved("registration_nurse"),"placement alone stores bag and releases nurse for ordinary registration")
 check(intake_receipts("asylum_relic_container_received")==1 and intake_receipts("asylum_relic_container_stored")==1,"receive and desk storage have separate one-time actual-event receipts")
 check(not "asylum_relic_bag_photo" in app.rules.known and intake3().state().read.is_empty(),"offscreen storage gives no protagonist photo recognition or read bag number")
 check(intake3().observation_target("asylum_relic_bag_photo").is_empty(),"bag contents require a separate earlier actual inspection of the bag label")
 app.enter_room("lobby");app.session.data.exploration_boundary=true
 check(intake_read("asylum_relic_bag_number"),"actual preparation/contact/finish reads bag label before its contents")
 var number_fields:Dictionary=intake3().state().read.get("asylum_relic_bag_number",{})
 check(not number_fields.is_empty() and number_fields.get("bag_number")==null,"unprovided bag-number glyph remains unknown rather than manufacturing a patient match")
 check(intake_read("asylum_relic_bag_photo"),"actual second inspection sees only the original objects actually received")
 var unrecognised:Dictionary=intake3().state().read.get("asylum_relic_bag_photo",{})
 check(not unrecognised.is_empty() and not unrecognised.get("photo_recognised",false) and not has_photo_lines(),"without prior sight of the original photo there is no recognition dialogue or invented identity")
 check(app.rules.neurons==before_n and app.rules.search_attempts==before_search,"receiving and inspecting relics gives no search income or consumed search attempt")
 await capture("02_stored_unknown_number")
 step3(2)
 check(intake_receipts("asylum_relic_container_received")==1 and intake_receipts("asylum_relic_container_stored")==1,"continued world time never replays storage settlement")

 intake_fixture(["family_photo","patient_shoe"],true)
 check(intake3().arrive_from_hospital() and until3(func():return intake3().state().phase=="stored",20),"prior-photo case still requires real intake and desk placement")
 check(intake_read("asylum_relic_bag_number") and intake_read("asylum_relic_bag_photo"),"recognition case still requires both actual bag inspections")
 var fields:Dictionary=intake3().state().read.get("asylum_relic_bag_photo",{})
 check(not fields.is_empty() and fields.get("photo_recognised",false) and fields.get("bag_number")==null and not fields.get("identity_confirmed",false),"recognising the original photo does not turn null bag-number glyph into verified patient identity")
 check(app.dialogue_queue.size()==2 and app.dialogue_queue[0].text=="照片是他一直拿着的。" and app.dialogue_queue[1].text=="再对一下袋上的号。","prior visual knowledge enables only the two exact conditional source lines")
 check(roundtrip() and intake3().state().read.get("asylum_relic_bag_photo",{}).get("photo_recognised",false),"ordinary JSON preserves the actual inspection and recognition separately from scene arrival")
 await capture("03_recognised_original_photo")
 clear_lines();app.restart_attempt(1,false);app.enter_room("lobby");app.session.data.exploration_boundary=true
 check(intake3().state().phase=="stored" and intake3().bag_holder()=="asylum_registration_desk","later new attempt preserves the actually stored bag without requiring a newly spawned carrier")
 check(intake_read("asylum_relic_bag_photo") and not has_photo_lines(),"a fresh real read in a later attempt cannot replay already spoken photo-recognition dialogue")
 check(intake_receipts("asylum_relic_photo_recognised")==1,"recognition has one actual receipt across saved reload and genuine later attempts")
 finish_intake()
