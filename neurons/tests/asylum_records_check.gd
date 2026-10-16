extends "res://tests/asylum_events_check.gd"
## Physical office-reading and one finite guard-report branch. The preceding
## trace suite owns the original-patient cross-floor delivery checks.

func records3():return app.asylum.records
func record_fixture() -> void:
 fixture3("office",true);app.session.data.exploration_boundary=true
 records3().state();app.hero_route=PackedVector2Array();app.target_index=-1
func reading3(id:String) -> bool:return id in records3().state().read and id in app.rules.known
func read_page3(id:String) -> bool:
 step3()
 var spec:Dictionary=records3().document_spec(id)
 if spec.is_empty() or not records3().begin_read(int(spec.index),id):return false
 return until3(func():return records3().state().reading.is_empty(),3) and reading3(id)
func existing_report_fixture() -> void:
 # Explicit intermediate fixture for the two alternate guard cases only:
 # a prior actually-written sheet lies on desk II, with a last-seen position.
 # The main case below earns this state through real archivist observation.
 var value:Dictionary=records3().state()
 value.report={"phase":"pending","location":"office:10","room":"office","pos":app.asylum.xy(records3().page_position(10)),"last_room":"office","last_seen":app.asylum.xy(app.hero_pos),"elapsed":0.0,"index":0}
 app.rules.owners.asylum_archive_report="office:10";app.rules.owners.asylum_current_report="office:10"

func finish3() -> void:
 var f:=FileAccess.open(ProjectSettings.globalize_path(folder).path_join("result.json"),FileAccess.WRITE)
 f.store_string(JSON.stringify({"passes":passes,"failures":failures,"rendered":true,
  "scope":"B3 finite real office reading, archivist/report/guard APIs, fixed world ticks, pause and schema2 JSON. One complete chain earns report by an archivist actually observing continued page reading; alternate evade/upstairs cases use an explicitly pre-existing written desk report. No natural-RNG all-branch playthrough, mouse input, original-patient rerun, subjective audio or formal-art acceptance.",
  "fixtures":"Walkable initial observer and actor positions; random arrivals held drawn; one explicit removable physical LOS blocker in the wall case. Later page-contact positions are finite contact fixtures. Alternate guard cases alone seed a pre-existing written desk sheet, never received/gripped/injured/released final outcomes.",
  "untested":"All archive collection/report/medical/isolation interleavings; non-null approved patient-number art; every blocked-drag path; guard death branch; final UI mouse routing and natural random combinations."},"  "));f.close()
 print("ASYLUM_RECORDS_CHECK %d passed %d failed"%[passes.size(),failures.size()])
 frontend.request_exit(0 if failures.is_empty() else 1)

func _ready() -> void:
 folder="res://../docs/validation/b3_20261016/records"
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--validation-root="):folder=argument.trim_prefix("--validation-root=")
 name="CampaignCheck";frontend=get_parent();DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 await frames();frontend.show_profile();await frames();frontend.name_field.text="精神病院档案与保安验证"
 frontend.overwrite_armed=true;frontend.new_game();await frames();app=frontend.active
 if app.tutorial_ui!=null:app.tutorial_ui.finish()
 if app.asylum.records==null:
  check(false,"asylum records module is connected to campaign state and clock");finish3();return

 record_fixture()
 check(records3().config.documents.size()==8 and records3().state().read.is_empty(),"eight physical page identities begin unread rather than as automatic knowledge")
 check(not records3().begin_read(0,"asylum_archive_index"),"far observer cannot start reading an office page")
 check(not records3().begin_read(10,"asylum_current_report"),"a report that has not really been written cannot be read")
 app.hero_pos=Vector2(1.5,0.85)
 var at:Vector2=records3().page_position(0)
 app.layout.movable_blockers.append(Rect2(1.2,0.68,0.1,0.34))
 check(app.layout.walkable(app.hero_pos) and app.layout.walkable(at) and app.hero_pos.distance_to(at)<0.65 and not app.layout.clear_segment(app.hero_pos,at),"wall fixture places two legal in-range endpoints separated by a real blocker")
 check(not records3().begin_read(0,"asylum_archive_index"),"even in range a physical occluder prevents reading through it")
 app.layout.movable_blockers.clear();app.hero_pos=at
 var neurons:int=app.rules.neurons;var clusters:int=app.rules.plexus
 check(records3().begin_read(0,"asylum_archive_index"),"actual clear page contact starts prepare/contact/finish reading")
 step3(0.3);var elapsed:float=float(records3().state().reading.get("elapsed",-1.0))
 check(elapsed>0.25 and not reading3("asylum_archive_index"),"partial page preparation has not prematurely granted knowledge")
 var clock:float=app.rules.world_time;await frames(12)
 check(is_equal_approx(app.rules.world_time,clock) and is_equal_approx(float(records3().state().reading.get("elapsed",-2.0)),elapsed),"manual pause freezes both world and in-flight page reading")
 check(roundtrip() and is_equal_approx(float(records3().state().reading.get("elapsed",-2.0)),elapsed) and not reading3("asylum_archive_index"),"half-read page survives real JSON without premature completion")
 step3(0.65)
 check(not reading3("asylum_archive_index"),"less than one full second still cannot give a completed page")
 check(until3(func():return records3().state().reading.is_empty(),0.2) and reading3("asylum_archive_index"),"resumed one-second physical page really completes")
 check(app.rules.neurons==neurons and app.rules.plexus==clusters and app.rules.search_attempts==0,"reading is not a key search and grants no search resources")
 check(read_page3("asylum_archive_index") and app.rules.known.count("asylum_archive_index")==1,"explicit reread cannot duplicate knowledge entries or page settlement")
 for id in ["asylum_scar_photo","asylum_no_external_injury","asylum_prior_copy","asylum_death_page","asylum_fee_page"]:
  var spec:Dictionary=records3().document_spec(id)
  app.hero_pos=records3().page_position(int(spec.index))
  check(app.layout.walkable(app.hero_pos) and read_page3(id),"actual one-second contact reads separate page "+id)
 check(not "asylum_injury_record_conflict" in app.rules.known,"two unknown patient numbers cannot connect a scar photo to a no-injury page")
 check(records3().config.fields.death_patient_number==null and records3().config.fields.fee_patient_number==null,"unknown death and fee identifiers stay unknown rather than borrowed from a living patient")
 app.hero_pos=records3().page_position(6);actor3("archivist","office",app.hero_pos+Vector2(0.35,0))
 check(read_page3("asylum_duty_roster"),"public duty roster remains a real readable page while archivist is physically present")
 check(records3().state().archivist.phase=="idle" and records3().state().stopped.is_empty() and records3().state().report.is_empty(),"public roster does not trigger restricted-file confiscation or a report")
 check(records3().state().read.size()==7 and app.rules.neurons==neurons,"seven independent existing pages complete without inventing the eighth report or income")
 await capture("01_seven_actual_office_pages")

 # End-to-end report origin: first acquire real knowledge, then visibly keep
 # reading the same unowned physical file after the archivist's real stop.
 record_fixture();app.hero_pos=records3().page_position(0)
 check(read_page3("asylum_archive_index"),"report case first earns its retained directory knowledge by actual reading")
 var key:String=str(app.rules.owners.key)
 actor3("archivist","office",app.hero_pos+Vector2(0.35,0))
 check(records3().begin_read(0,"asylum_archive_index"),"second actual restricted-file reading is visible to a nearby archivist")
 check(until3(func():return records3().state().archivist.phase=="stop",2),"archivist really sees, approaches and reaches a visible stop before confiscation")
 check(app.rules.owners.asylum_archive_index=="office:0" and not rec3("archive_report"),"stop dialogue alone does not yet confiscate a file or finish a report")
 check(until3(func():return app.rules.owners.asylum_archive_index=="asylum_archive_storage",4),"actual hand contact collects only the still-unowned physical file")
 check(reading3("asylum_archive_index") and app.rules.owners.key==key,"confiscation preserves already-read information and the progression key")
 check(until3(func():return records3().state().report.get("location","")=="office:10",15),"continued reading after real stop makes archivist walk, write and leave one actual report on desk II")
 check(rec3("archive_report") and not rec3("archive_report_received") and not app.asylum.present("guard"),"written report waits for an absent guard rather than summoning or remotely executing him")
 check(app.rules.hp==100 and app.rules.sp==100 and not app.rules.gripped,"being reported and paper collection create no invented bodily harm")
 app.hero_pos=records3().page_position(10)
 check(read_page3("asylum_current_report"),"only after actual writing can the eighth page be physically read from the desk")
 check(not rec3("kick:archivist") and not rec3("kick:guard"),"reading an institutional accusation does not manufacture a staff attack")
 check(roundtrip() and records3().state().report.location=="office:10" and reading3("asylum_current_report"),"waiting report location and actually-read allegation persist independently through JSON")
 await capture("02_real_report_waiting_on_desk")

 actor3("guard","office",app.hero_pos+Vector2(0.35,0))
 check(until3(func():return rec3("archive_report_received"),3),"guard physically reaches the actual desk report and completes its handoff")
 check(records3().state().report.phase=="accepted" and app.rules.owners.asylum_archive_report=="guard","report receipt changes the unique paper owner before any bodily outcome")
 check(until3(func():return records3().state().guard.phase=="reach",3),"accepted report leads to confirmed target, real approach and visible reach")
 check(app.rules.hp==100 and app.rules.sp==100 and not app.rules.gripped,"visible grab preparation is not already damage or an established holder")
 step3(0.3)
 check(app.rules.hp==100 and not app.rules.gripped,"unfinished half-second reach leaves an intervention window")
 check(roundtrip() and records3().state().guard.phase=="reach" and not app.rules.gripped,"mid-reach JSON does not skip directly to gripping")
 check(until3(func():return app.rules.gripped,3),"actual closing contact establishes the single guard holder")
 check(app.asylum.data.holder=="guard" and app.rules.hp==95 and app.rules.sp==90,"actual guard grip costs exactly five HP and ten SP once")
 check(not app.asylum.can_begin_grip(),"another physical holder cannot begin while the guard has established grip")
 give_skill("CONTROL");neurons=app.rules.neurons
 check(not cast("CONTROL").get("success",false) and app.rules.neurons==neurons,"complete control cannot bypass established grip or charge a rejected command")
 var grip_clock:float=app.rules.world_time
 check(until3(func():return not app.rules.gripped,6.1),"actual paired drag releases within original six-second ceiling")
 check(app.rules.world_time-grip_clock<=6.11 and records3().state().guard.done and app.asylum.data.holder=="","finished guard disposition clears the one holder and its finite event")
 check(app.room_id=="office" and app.hero_pos.distance_to(Map.doorway("office","lobby"))<0.07,"guard actually delivers to existing office doorway rather than a locked or invented room")
 step3(2)
 check(app.rules.hp==95 and app.rules.sp==90 and app.rules.owners.key==key,"extra frames do not repeat grip injury, confiscate a key or immediately regrab")
 check(roundtrip() and records3().state().guard.done and not app.rules.gripped,"completed disposition and prior one-time injury survive JSON without replay")
 await capture("03_actual_guard_doorway_release")

 record_fixture();app.hero_pos=Vector2(1.35,3.35);existing_report_fixture()
 actor3("guard","office",records3().page_position(10))
 check(until3(func():return records3().state().guard.phase=="reach",4),"alternate existing-sheet fixture still earns actual guard receipt and reach")
 give_skill("WITHDRAW")
 check(cast("WITHDRAW").get("success",false),"real paid withdrawal executes inside pre-contact guard window")
 check(until3(func():return bool(records3().state().guard.done),3) and app.rules.hp==100 and app.rules.sp==100 and not app.rules.gripped,"pre-grip withdrawal makes one actual miss without damage or dragging")
 step3(2)
 check(not rec3("guard_grip") and records3().state().guard.done,"missed attempt is consumed and cannot immediately retry")

 record_fixture();app.hero_pos=Map.doorway("office","lobby");existing_report_fixture()
 actor3("guard","office",records3().page_position(10))
 # This case exercises actual door movement, so release the deliberately
 # stationary API fixture boundary. Empty unrelated sampled searches only;
 # the existing key, paper, guard perception and door timing remain real.
 app.session.data.exploration_boundary=false;app.session.data.targets=[]
 app.route_to_door("lobby")
 check(until3(func():return app.room_id=="lobby",4),"upstairs avoidance case really opens original office door and reaches reception")
 app.route_to_door("stairs")
 check(until3(func():return app.room_id=="stairs",6),"protagonist really follows reception's existing stair route rather than a scene jump")
 check(until3(func():return bool(records3().state().guard.done),12),"guard closes the one report attempt after protagonist actually leaves the first floor")
 check(not rec3("guard_grip") and not app.rules.gripped and app.rules.hp==100 and app.rules.sp==100,"first-floor guard cannot grab upstairs or invent cross-floor damage")
 check(str(app.asylum.actor("guard").room) in ["office","lobby","ward","clinic","pharmacy"],"ordinary office disposition does not drag the guard through an unapproved upper-floor chase")
 await capture("04_actual_stair_escape_without_remote_grip")
 finish3()
