extends "res://tests/hospital_relic_packing_check.gd"
## One actual L2-to-L3 chain. Initial actors/key and unlocked CONTROL/50N
## are fixtures; no packed receipts, arrival/storage/read/recognition
## results or number glyphs are injected. GUI execution belongs to root.
var checkpoints:Array=[]

func intake_chain():return app.asylum.intake

func facts_of(kind:String) -> int:
 var count:int=0
 for fact in app.rules.facts:
  if str(fact.get("kind",""))==kind:count+=1
 return count

func checkpoint(id:String) -> void:
 checkpoints.append({"id":id,"level":int(app.session.data.level),"room":app.room_id,"hero_pos":[app.hero_pos.x,app.hero_pos.y],"world_time":app.rules.world_time,"actual_packing_count":facts_of("hospital_relic_packed"),"actual_transport_count":facts_of("patient_transport_completed"),"arrival_count":facts_of("asylum_relic_delivery_arrived"),"receive_count":facts_of("asylum_relic_container_received"),"stored_count":facts_of("asylum_relic_container_stored"),"container_owner":str(app.rules.owners.get("hospital_relic_container","")),"photo_owner":str(app.rules.owners.get("family_photo","")),"shoe_owner":str(app.rules.owners.get("patient_shoe",""))})

func finish_chain_lines() -> void:
 for index in range(16):
  if app.dialogue_queue.is_empty():return
  await continue_live_line()

func chain_live_until(predicate:Callable,seconds:float=8.0) -> bool:
 # Ordinary process only once CRT opens. Continue genuine dialogue using
 # actual Enter input; do not erase it or advance a second manual world clock.
 var elapsed:float=0.0
 while elapsed<seconds:
  if predicate.call():return true
  var before_frame:int=Engine.get_process_frames()
  if app.dialogue_queue.is_empty():await frames(1)
  else:await continue_live_line()
  elapsed+=float(maxi(1,Engine.get_process_frames()-before_frame))*get_process_delta_time()
 return predicate.call()

func click_actual_bag() -> bool:
 for item in app.view.asylum_props():
  if str(item.id)!=intake_chain().bag_id() or str(item.room)!=app.room_id:continue
  # Same pixel used by production hit-testing, including the final tabletop
  # layer offset. The click is genuine viewport mouse input, not begin().
  var pixel:Vector2=app.view.asylum_item_pixel(item)
  var screen:Vector2=(app.world_viewport.get_canvas_transform()*pixel)*2.0
  var movement:=InputEventMouseMotion.new();movement.position=screen;movement.global_position=screen
  Input.parse_input_event(movement);await frames(2)
  for down in [true,false]:
   var button:=InputEventMouseButton.new();button.position=screen;button.global_position=screen;button.button_index=MOUSE_BUTTON_LEFT;button.pressed=down
   Input.parse_input_event(button);await frames(2)
  return true
 return false

func finish_chain() -> void:
 var output:=FileAccess.open(ProjectSettings.globalize_path(folder).path_join("result.json"),FileAccess.WRITE)
 output.store_string(JSON.stringify({"passes":passes,"failures":failures,"rendered":true,"checkpoints":checkpoints,"source_manifest":app.hospital.data.get("relic_delivery",{}),"actual_intake":intake_chain().state(),"scope":"Actual same-original L2 transfer, footplate photograph contact, porter's return for dropped shoe and physical container exit; normal keyed route/opening triggers L3 transition hook; actual nurse approach/receive/carry/store and separate real tabletop-bag mouse label/content reading. Mid-door and mid-receive checksummed JSON prove no repeated packing or scene arrival. Normal process/CRT mouse/Enter only during final CONTROL reading segment.","fixtures":"Initial L2 guide/wheelchair/porter positions and original photograph owner, initially held L2 key, initially unlocked CONTROL/50N and isolated scheduled groups; L3 existing registration nurse's initial desk presence. CONTROL is submitted through actual CRT and its ordinary fee is paid. No completed receipt, delivered/stored container, reading/recognition result or concrete number glyph is injected. Fixed game-time driver and screenshots are not a natural new-profile full playthrough, all random combinations or formal art/audio acceptance."},"  "));output.close()
 print("ASYLUM_INTAKE_CHAIN_CHECK %d passed %d failed"%[passes.size(),failures.size()])
 frontend.request_exit(0 if failures.is_empty() else 1)

func _ready() -> void:
 folder="res://../docs/validation/b3_finish_20261016/intake-chain"
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--validation-root="):folder=argument.trim_prefix("--validation-root=")
 name="CampaignCheck";frontend=get_parent();DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 await frames();frontend.show_profile();await frames();frontend.name_field.text="原物跨关完整交接验证"
 frontend.overwrite_armed=true;frontend.new_game();await frames();app=frontend.active
 if app.tutorial_ui!=null:app.tutorial_ui.finish()

 relic_fixture();app.asylum.enabled=true
 # Explicit initial key fixture; no unlock function or transition is called.
 app.rules.owners.key="hero";app.session.data.key_owner="hero"
 app.rules.skill_states.CONTROL.unlocked=true;app.rules.neurons=50
 check(app.hospital.data.receipts.is_empty() and delivery().is_empty() and facts_of("hospital_relic_packed")==0 and facts_of("patient_transport_completed")==0,"chain starts with physical trio/key fixtures and no completed transport or packing history")
 check(app.rules.owners.family_photo=="wheelchair" and app.hospital.relic_position("family_photo").is_empty(),"same original photograph starts with patient before any real footplate drop")
 checkpoint("initial_actors_and_key_only")
 check(hospital_until(func():return photo_phase()=="photo_contact",35),"actual paperwork/push/frame/fingers reaches visible original photograph collection contact")
 check(app.hospital.present("wheelchair") and app.rules.owners.family_photo=="wheelchair_footplate" and not receipt("patient_transport"),"contact window retains live original chair and uncompleted transfer")
 await capture("01_real_l2_photo_contact")
 check(hospital_until(func():return delivery().get("ready",false),20),"same actual porter contact-packs photograph, returns for original shoe and carries container to source exit")
 check(delivery().items.size()==2 and delivery().get("bag_departed",false) and facts_of("hospital_relic_packed")==2 and facts_of("patient_transport_completed")==1,"ready manifest has exactly two real original-object pickup receipts and one genuine patient transfer")
 check(app.rules.owners.family_photo=="hospital_relic_container" and app.rules.owners.patient_shoe=="hospital_relic_container" and app.rules.owners.hospital_relic_container=="hospital_relic_carry","one source container retains both original objects before crossing chapters")
 var source_manifest:String=canonical_relic(delivery())
 var source_receipts:String=canonical_relic(app.hospital.data.receipts)
 checkpoint("actual_l2_packing_departed")

 app.session.data.exploration_boundary=false
 app.route_to_door("stairs")
 check(hospital_until(func():return app.action_phase=="opening" and int(app.session.data.level)==2,12),"initial key uses real L2 navigation and stair-door opening without calling a chapter unlock directly")
 check(app.hero_pos.distance_to(app.door_point("stairs"))<0.04 and app.has_key(),"protagonist physically reaches actual keyed door before chapter transition")
 hospital_step(0.2)
 var opening_left:float=app.action_left
 check(opening_left>0 and facts_of("asylum_relic_delivery_arrived")==0,"unfinished normal door animation cannot create early L3 arrival")
 check(roundtrip() and int(app.session.data.level)==2 and app.action_phase=="opening" and is_equal_approx(app.action_left,opening_left),"real mid-door JSON restores unfinished chapter transition without replaying source packing")
 check(canonical_relic(delivery())==source_manifest and facts_of("hospital_relic_packed")==2,"mid-door restore preserves actual source manifest and both original packing receipts")
 check(hospital_until(func():return int(app.session.data.level)==3,3),"remaining actual door time invokes normal L2-to-L3 transition and arrival hook")
 app.session.data.exploration_boundary=true
 check(app.room_id=="stairs" and intake_chain().state().phase=="approach" and facts_of("asylum_relic_delivery_arrived")==1,"chapter transition delivers one original container at actual L3 entrance, not already received or stored")
 check(intake_chain().bag_holder()=="asylum_intake_delivery" and intake_chain().state().read.is_empty(),"arrival changes only container ownership and grants no read information")
 check(canonical_relic(app.asylum.data.carry.relic_delivery)==source_manifest and canonical_relic(app.hospital.data.receipts)==source_receipts,"normal transition passes unchanged actual L2 source manifest and receipts")
 checkpoint("normal_door_hook_arrived_once")

 # Existing B3 nurse initial-presence fixture, with all intake results left
 # untouched. Other random groups remain isolated for this finite chain.
 for group in app.asylum.data.groups:
  app.asylum.data.groups[group].drawn=true;app.asylum.data.groups[group].pending=false
 var nurse:Dictionary=app.asylum.actor("registration_nurse")
 nurse.phase="idle";nurse.room="lobby"
 var desk:Vector2=app.asylum.layout_for("lobby").furniture[0].at
 nurse.pos=[desk.x,desk.y];nurse.route=[]
 check(hospital_until(func():return intake_chain().state().phase=="receive",15),"existing nurse actually walks from original desk to the container delivered by transition hook")
 hospital_step(0.3)
 var receive_elapsed:float=float(intake_chain().state().elapsed)
 check(receive_elapsed>0 and intake_chain().bag_holder()=="asylum_intake_delivery" and facts_of("asylum_relic_container_received")==0,"real nurse preparation/contact is visible before transfer of container ownership")
 check(roundtrip() and is_equal_approx(float(intake_chain().state().elapsed),receive_elapsed) and facts_of("asylum_relic_delivery_arrived")==1,"mid-receive JSON preserves partial contact without repeating chapter arrival")
 check(facts_of("hospital_relic_packed")==2 and canonical_relic(app.hospital.data.receipts)==source_receipts,"cross-chapter restore cannot replay original hospital object collection")
 check(hospital_until(func():return intake_chain().state().phase=="stored",20),"same nurse genuinely receives, carries and places original container at desk")
 check(intake_chain().bag_holder()=="asylum_registration_desk" and facts_of("asylum_relic_container_received")==1 and facts_of("asylum_relic_container_stored")==1,"one actual receipt per handoff and placement preserves both originals inside one stored bag")
 check(intake_chain().state().read.is_empty() and not "asylum_relic_bag_photo" in app.rules.known,"offscreen actual storage alone cannot teach bag contents or recognition")
 checkpoint("actual_nurse_stored_unread")

 app.session.data.exploration_boundary=false;app.route_to_door("lobby")
 check(hospital_until(func():return app.room_id=="lobby",10),"protagonist actually uses existing stair/lobby doorway to approach stored evidence")
 app.session.data.exploration_boundary=true
 var before_search:int=app.rules.search_attempts;var before_n:int=app.rules.neurons
 check(intake_chain().observation_target("asylum_relic_bag_photo").is_empty(),"contents remain unavailable before a separate actual bag-number inspection")
 await finish_chain_lines()
 app.paused_manual=false;app.open_neuron_menu();await click(app.menu.nodes.CONTROL)
 check(await chain_live_until(func():return app.rules.control_left>0 and app.closing_left<=0,3),"real CRT mouse submits initially unlocked CONTROL and starts ordinary paid intervention window")
 await finish_chain_lines();await frames(4)
 check(app.rules.neurons==before_n-int(app.rules.spec("CONTROL").cost),"cross-chapter CONTROL uses exactly original five-neuron submission cost, without refilling earned resources")
 check(await click_actual_bag(),"first actual viewport mouse click targets original container's visible tabletop marker")
 check(await chain_live_until(func():return intake_chain().state().read.has("asylum_relic_bag_number"),5),"normal process really approaches and reads bag label after tabletop mouse click through prepare/contact/finish")
 var number:Dictionary=intake_chain().state().read.get("asylum_relic_bag_number",{})
 check(not number.is_empty() and number.get("bag_number")==null and "asylum_relic_bag_number" in app.rules.known,"actual label read records unprovided number as unknown and does not fabricate matching digits")
 await finish_chain_lines()
 check(await click_actual_bag(),"second actual tabletop-container mouse click requests separately unread contents")
 check(await chain_live_until(func():return intake_chain().state().read.has("asylum_relic_bag_photo"),3),"ordinary process second click completes physical reading of actually received original photograph and shoe")
 await finish_chain_lines()
 app.paused_manual=true
 var contents:Dictionary=intake_chain().state().read.get("asylum_relic_bag_photo",{})
 check(contents.get("photo_visible",false) and contents.get("shoe_visible",false) and not contents.get("identity_confirmed",true),"real contents read sees two original objects without converting null bag number to a confirmed patient match")
 check(not contents.get("photo_recognised",true) and not "hospital_family_photo_seen" in app.rules.known,"no prior photo reading or recognition flag was seeded to manufacture conditional dialogue")
 check(app.rules.search_attempts==before_search and app.rules.neurons==before_n-int(app.rules.spec("CONTROL").cost),"two actual evidence mouse inspections add no search attempt, income or extra intervention charge")
 check(roundtrip() and intake_chain().state().read.has("asylum_relic_bag_number") and intake_chain().state().read.has("asylum_relic_bag_photo"),"actual final JSON retains both distinct completed physical reads")
 hospital_step(2)
 check(facts_of("hospital_relic_packed")==2 and facts_of("asylum_relic_delivery_arrived")==1 and facts_of("asylum_relic_container_received")==1 and facts_of("asylum_relic_container_stored")==1,"later frames and restored read history cannot repeat packing, arrival, handoff or storage")
 check(app.rules.owners.family_photo=="hospital_relic_container" and app.rules.owners.patient_shoe=="hospital_relic_container" and intake_chain().bag_holder()=="asylum_registration_desk","same two original objects and one actual container retain unique final physical owners")
 checkpoint("actual_route_label_and_contents_read")
 await capture("02_l3_real_stored_bag_and_reading")
 finish_chain()
