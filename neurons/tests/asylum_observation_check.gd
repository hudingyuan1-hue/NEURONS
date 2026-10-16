extends "res://tests/asylum_events_check.gd"
## Finite physical-read checks and two real CRT/world-mouse sequences.
## Starting room/position/learned-earlier-clue fixtures are declared; no test
## writes a completed observation or manufactures read knowledge as an outcome.

func observations3():return app.asylum.observations
func observation_fixture(room:String,index:int=0) -> void:
 fixture3(room,true);app.session.data.exploration_boundary=true
 app.hero_pos=app.layout.furniture[index].at;app.hero_route=PackedVector2Array();app.target_index=-1

func observe3(id:String,seconds:float=2.0) -> bool:
 step3()
 if not observations3().begin(id,false):return false
 return until3(func():return observations3().state().active.is_empty(),seconds) and observations3().state().read.has(id)

func observation_fact_count() -> int:
 var count:int=0
 for fact in app.rules.facts:
  if str(fact.get("kind",""))=="asylum_observation":count+=1
 return count

func world_click(at:Vector2) -> void:
 var screen:Vector2=(app.world_viewport.get_canvas_transform()*app.layout.project(at))*2.0
 var motion_event:=InputEventMouseMotion.new();motion_event.position=screen;motion_event.global_position=screen
 Input.parse_input_event(motion_event);await frames(2)
 for down in [true,false]:
  var event:=InputEventMouseButton.new();event.position=screen;event.global_position=screen;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down
  Input.parse_input_event(event);await frames(2)

func legal_control() -> bool:
 give_skill("CONTROL");app.paused_manual=false
 app.open_neuron_menu();await click(app.menu.nodes.CONTROL)
 var active:bool=await await_live(func():return app.rules.control_left>0 and app.closing_left<=0,3)
 while not app.dialogue_queue.is_empty():await continue_live_line()
 await frames(4)
 return active

func finish3() -> void:
 var output:=FileAccess.open(ProjectSettings.globalize_path(folder).path_join("result.json"),FileAccess.WRITE)
 output.store_string(JSON.stringify({"passes":passes,"failures":failures,"rendered":true,
  "scope":"Original twenty-three B3 physical observations within thirty-two configured targets: finite prepare/contact/finish, interruption, source/knowledge boundaries, JSON plus real CRT/world mouse. Added dynamic papers and intake are checked in separate finite suites; not all natural-RNG or formal art/audio acceptance.",
  "fixtures":"Real walkable initial stands; no random arrivals; source-declared prior laundry movement or earlier cuff clue only in their dedicated carry tests. Diagnosis positive case uses real doctor writing/order timing. No successful read/overlay exposure or matching unknown number is assigned as a fixture.",
  "content_pending":"Physical checks and source-bound intake now have separate suites. Number glyphs, real self-photograph capture, actual signature and whiteboard text remain unavailable source content, never invented from a read. Nurse-duty writing has its own event suite."},"  "));output.close()
 print("ASYLUM_OBSERVATION_CHECK %d passed %d failed"%[passes.size(),failures.size()]);frontend.request_exit(0 if failures.is_empty() else 1)

func _ready() -> void:
 folder="res://../docs/validation/b3_20261016/observations"
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--validation-root="):folder=argument.trim_prefix("--validation-root=")
 name="CampaignCheck";frontend=get_parent();DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 await frames();frontend.show_profile();await frames();frontend.name_field.text="实物观察与原句验证"
 frontend.overwrite_armed=true;frontend.new_game();await frames();app=frontend.active
 if app.tutorial_ui!=null:app.tutorial_ui.finish()
 if app.asylum.observations==null:
  check(false,"observations module is attached to the real B3 owner and clock");finish3();return

 observation_fixture("ward")
 var ids:Dictionary={}
 for target in observations3().config.targets:ids[str(target.id)]=true
 check(ids.size()==32 and ids.size()==observations3().config.targets.size(),"all thirty-two physical observation IDs remain unique as dynamic papers and intake are added")
 check(observations3().config.deferred.is_empty() and observations3().config.content_pending.size()==5,"physical target implementations remain separate from five explicit unknown-content conditions")
 var before_n:int=app.rules.neurons;var before_search:int=app.rules.search_attempts
 app.hero_pos=Vector2(4.2,1.3)
 check(not observations3().begin("asylum_bed_card_under"),"distant old-card observation cannot start without actually approaching its stand")
 check(not "asylum_bed_card_under" in app.rules.known and app.rules.neurons==before_n and app.rules.search_attempts==before_search,"failed reach gives neither hidden text, income nor a search attempt")
 app.hero_pos=app.layout.furniture[0].at
 check(observations3().begin("asylum_bed_card_under"),"actual bed-card stand begins a finite lift-and-read gesture")
 step3(0.35)
 check(observations3().state().active.phase=="contact" and not "asylum_bed_card_under" in app.rules.known,"contact phase is visible before any completed reading knowledge")
 var elapsed:float=float(observations3().state().active.elapsed);var world:float=app.rules.world_time
 check(roundtrip() and is_equal_approx(float(observations3().state().active.elapsed),elapsed),"real JSON saves and restores the partly lifted card and its remaining action clock")
 await frames(12)
 check(is_equal_approx(app.rules.world_time,world) and is_equal_approx(float(observations3().state().active.elapsed),elapsed),"manual pause freezes the actual observation stage and world clock")
 await capture("01_old_card_contact")
 observations3().cancel();step3(1.5)
 check(not "asylum_bed_card_under" in app.rules.known and not observations3().state().read.has("asylum_bed_card_under"),"cancelled reveal cannot complete later or award unread old text")
 check(app.rules.public_action.is_empty() and not observations3().blocks_hero(),"cancelling the observation closes only its own public action and releases autonomy")
 check(observe3("asylum_bed_card_under"),"a new actual lift and complete read reveals only the old card's supplied portion")
 check(observations3().state().read.asylum_bed_card_under.fields.old_name==null and not observations3().state().links.has("same_identity"),"undelivered old-name glyph stays null and does not manufacture an identity")
 check(app.dialogue_queue.size()==1 and app.dialogue_queue[0].text=="下面还有字。","only completed card reading queues its exact original line")
 check(not observations3().begin("asylum_bed_card_under"),"same completed observation does not leave a new action waiting on an old receipt")
 step3(0.1)
 check(app.rules.neurons==before_n and app.rules.search_attempts==before_search and observation_fact_count()==1,"one read creates one observation receipt without search income or consumed search capacity")
 check(roundtrip() and observations3().state().read.has("asylum_bed_card_under"),"completed physical-read knowledge survives ordinary saved-game restore")

 observation_fixture("ward")
 check(observations3().begin("asylum_bed_straps"),"bed-strap inspection starts from the actual low stand")
 step3(0.3);app.asylum.damage("observation_hurt_fixture",5,0);step3(1.2)
 check(observations3().state().active.is_empty() and not "asylum_bed_straps" in app.rules.known,"real damage interrupts unfinished strap inspection rather than granting late knowledge")
 observation_fixture("ward");app.hero_pos=Vector2(2.55,1.6)
 app.layout.movable_blockers.append(Rect2(2.35,1.36,0.4,0.08))
 check(app.layout.walkable(app.hero_pos) and not observations3().begin("asylum_bed_card_under"),"nearby but physically occluded card cannot be read through an intervening obstacle")

 observation_fixture("ward")
 check(not observations3().available(observations3().specification("asylum_laundry_bag_label")) and not observations3().available(observations3().specification("asylum_laundry_vacancy")),"missing inherited bag outcome is not guessed as a returned bag or a proven vacant site")
 app.asylum.data.carry={"bag":"removed"}
 check(not observations3().available(observations3().specification("asylum_laundry_bag_label")) and observe3("asylum_laundry_vacancy"),"actual prior removal permits only inspection of the empty original site")
 check(not "asylum_laundry_bag_label" in app.rules.known and not app.rules.owners.has("new_asylum_uniform"),"vacant-site inspection never respawns a second garment or its unread label")

 observation_fixture("lobby")
 check(observe3("asylum_family_contact_closed"),"real reception contact reads the closed family-contact field")
 var family_fields:Dictionary=observations3().state().read.asylum_family_contact_closed.fields
 check(family_fields.closed_by==null and family_fields.closed_at==null and app.rules.institutional_records.is_empty(),"seeing a closed field does not reveal who/when, file a harassment charge or create patient departure records")

 observation_fixture("clinic")
 check(not observations3().available(observations3().specification("asylum_diagnosis_page")),"unwritten diagnosis cannot be read as if the doctor already filled it")
 actor3("doctor")
 check(until3(func():return app.asylum.data.diagnosed and app.asylum.data.body.is_empty(),8),"doctor really listens, writes diagnosis and independently finishes the order handoff")
 check(not "asylum_diagnosis_page" in app.rules.known and observe3("asylum_diagnosis_page"),"paper exists after writing, but its content becomes known only through a separate actual reading")
 check(observations3().state().read.asylum_diagnosis_page.fields.paper.id=="asylum_diagnosis:1" and not app.asylum.data.swallowed and app.rules.hp==100,"read diagnosis preserves this source record and cannot manufacture medication or injury")

 observation_fixture("clinic",1)
 check(observe3("asylum_clinic_coat_sleeve") and not observations3().state().links.has("coat_correspondence"),"current sleeve can be examined without inventing an earlier bedroom encounter")
 check(not app.rules.settled.has("asylum_observation_line:COAT_RECOGNISE"),"without earlier cuff knowledge the before-seen original lines are not played")
 observation_fixture("clinic",1);app.rules.known.append("cuff_seam")
 check(observe3("asylum_clinic_coat_sleeve") and observations3().state().links.has("coat_correspondence"),"genuinely inherited cuff-detail fixture permits physical comparison of the same visual feature")
 check(app.dialogue_queue.size()==2 and app.dialogue_queue[0].text=="这个袖口……房间里那件也是这样。","conditional recognition keeps the exact source line without merging the doctors' identities")

 observation_fixture("pharmacy",1)
 check(observe3("asylum_waste_label_outer") and not "asylum_waste_label_under" in app.rules.known,"outer waste label alone gives no hidden lower number")
 step3();check(observations3().begin("asylum_waste_label_under"),"actual close contact begins lifting the cover-label corner")
 step3(0.45);give_skill("SKIN");check(cast("SKIN").get("success",false),"real paid skin reaction interrupts the unfinished label reveal")
 step3(1)
 check(not "asylum_waste_label_under" in app.rules.known and not observations3().state().links.has("label_layers_exposed"),"interrupted reveal gives no lower-layer text or delayed exposure receipt")
 check(observe3("asylum_waste_label_under"),"a fresh uninterrupted label action really reaches its reveal/finish node")
 check(observations3().state().read.asylum_waste_label_under.fields.transport_number==null and observations3().state().links.label_layers_exposed,"physical layers are known while the unprovided number remains unknown")
 check(app.dialogue_queue.size()==2 and app.dialogue_queue[0].text=="新标签压着旧的。" and not observations3().state().links.has("transport_match"),"source reveal dialogue does not turn two unknown numbers into a cross-level match")
 await capture("02_label_lower_layer_completed")

 observation_fixture("quiet",0)
 check(observe3("asylum_prefilled_isolation_record"),"quiet-room observation form is really approached and read as a pre-existing paper")
 check(app.dialogue_queue.size()==2 and app.dialogue_queue[0].text=="我刚进来，这里已经写完了？" and app.dialogue_queue[1].text=="连结果都填好了。","only completed prefilled-form reading queues both exact original lines")
 check(app.rules.hp==100 and app.rules.sp==100 and not app.rules.gripped and app.asylum.isolation.state().phase=="idle","reading a prefilled result neither isolates nor calms, heals or injures the protagonist")
 check(observations3().state().read.asylum_prefilled_isolation_record.fields.filled_time==null,"prefilled paper's missing timestamp remains unresolved rather than fabricated")
 observation_fixture("quiet",2)
 check(observe3("asylum_call_no_response") and not "asylum_call_wire_broken" in app.rules.known,"actual button press with no response does not remotely diagnose a severed line")
 check(observe3("asylum_call_wire_broken") and "asylum_call_wire_broken" in app.rules.known,"separate physical inspection of the visible wire establishes the actual break")

 observation_fixture("double_ward",4)
 check(observe3("asylum_bed1_erased_name") and app.dialogue_queue.size()==1 and app.dialogue_queue[0].text=="名字擦过，床号还留着。","actual first-bed erasure inspection preserves the exact original name/bed line")
 app.hero_pos=app.layout.furniture[5].at
 check(observe3("asylum_bed2_erased_name"),"second bed and its own bedside-card are separately inspected")
 check(app.dialogue_queue.is_empty() and observations3().state().read.asylum_bed1_erased_name.fields.bed_number==null and observations3().state().read.asylum_bed2_erased_name.fields.bed_number==null,"shared remark plays once while two unspecified bed glyphs stay distinct null fields")
 check(not observations3().state().links.has("same_name") and app.rules.neurons==5 and app.rules.search_attempts==0,"erased names do not merge two people or reward a non-search")
 await capture("03_two_distinct_erased_cards")
 observation_fixture("corridor")
 check(not observations3().available(observations3().specification("asylum_nurse_duty_table")),"public nurse-duty table is unreadable until actual writing and clip-back create at least one entry")

 observation_fixture("ward");app.session.data.exploration_boundary=false;app.session.data.targets=[];app.hero_pos=Vector2(3.25,1.45)
 check(await legal_control(),"real CRT mouse selection pays and starts the legal CONTROL window for bed inspection")
 await world_click(app.layout.furniture[0].rect.get_center())
 check(app.action_phase in ["asylum_read_route","asylum_reading"] or not observations3().state().active.is_empty(),"actual controlled bed click requests its optional physical observation, not a nonexistent first-floor key search")
 check(await await_live(func():return "asylum_bed_card_under" in app.rules.known,4),"ordinary process really walks to the bed and completes the original-card observation after mouse input")
 check(app.rules.neurons==45 and app.rules.search_attempts==0 and observations3().state().read.has("asylum_bed_card_under"),"real mouse observation uses one CONTROL payment and grants no search income or invented action count")
 app.paused_manual=true;await capture("04_actual_crt_bed_card_mouse")

 observation_fixture("ward");app.session.data.exploration_boundary=false;app.session.data.targets=[]
 check(await legal_control(),"new live command-cancel case starts through the actual CRT again")
 await world_click(app.layout.furniture[0].rect.get_center())
 check(await await_live(func():return not observations3().state().active.is_empty(),2),"real furniture mouse input reaches a genuine in-progress read")
 await world_click(Vector2(3.4,1.8))
 await await_live(func():return app.hero_route.is_empty(),3)
 check(observations3().state().active.is_empty() and not "asylum_bed_card_under" in app.rules.known,"new valid controlled floor command cancels unfinished reading without late knowledge")
 check(app.rules.public_action.get("target","")!="asylum_bed_card_under" and not observations3().blocks_hero(),"cancelled mouse reading does not leave its public observe action or block autonomy")
 app.paused_manual=true;await capture("05_actual_mouse_cancels_read")
 finish3()
