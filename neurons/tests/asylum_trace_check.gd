extends "res://tests/asylum_events_check.gd"
## Explicit actor/position fixtures, then real trace APIs, clock and JSON.
## No final state is assigned to manufacture collection or NPC delivery.

func trace3():return app.asylum.trace_events
func trace_fixture(room:String="bathroom") -> void:
 fixture3(room,true);app.session.data.exploration_boundary=true
 app.hero_route=PackedVector2Array();app.target_index=-1
func trace_receipt(id:String) -> bool:return rec3("trace_line:"+id)
func trace_read(id:String,seconds:float=3.0) -> bool:
 # Shown state and the source show-note line occur at one contact node. End
 # the normal formal dialogue before requesting another world interaction.
 step3()
 if not trace3().begin_read(id):return false
 return until3(func():return trace3().state().active.is_empty(),seconds) and trace3().state().read.has(id)
func stable_trace_read(id:String) -> bool:
 return trace3().state().read.has(id) and id in app.rules.known

func finish3() -> void:
 var f:=FileAccess.open(ProjectSettings.globalize_path(folder).path_join("result.json"),FileAccess.WRITE)
 f.store_string(JSON.stringify({"passes":passes,"failures":failures,"rendered":true,
  "scope":"B3 finite trace API cases with explicitly placed walkable actors/protagonist, fixed world ticks and real schema2 JSON. Real cleaner/contact/ownership, real original guard patient delivery, actual orderly doorway travel. No natural-RNG playthrough, all combinations, subjective audio or formal-art acceptance.",
  "fixtures":"Random arrivals held drawn; development boundary holds independent protagonist navigation. Fixtures place initial actors/observer positions only. Tests never set corpse exit, collected ownership, washed regions, delivered patient/corner or completed reading to a successful final state.",
  "untested":"Every cleaner blockage permutation; all ordinary-orderly/report/isolation interleavings; user-operated mouse routes; non-null approved date/vehicle/number art; formal corpse art and audio."},"  "));f.close()
 print("ASYLUM_TRACE_CHECK %d passed %d failed"%[passes.size(),failures.size()])
 frontend.request_exit(0 if failures.is_empty() else 1)

func _ready() -> void:
 folder="res://../docs/validation/b3_20261016/traces"
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--validation-root="):folder=argument.trim_prefix("--validation-root=")
 name="CampaignCheck";frontend=get_parent();DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 await frames();frontend.show_profile();await frames();frontend.name_field.text="遗物与双人病房验证"
 frontend.overwrite_armed=true;frontend.new_game();await frames();app=frontend.active
 if app.tutorial_ui!=null:app.tutorial_ui.finish()
 if app.asylum.trace_events==null:
  check(false,"asylum trace module is connected to normal campaign ownership and clock");finish3();return

 trace_fixture();app.hero_pos=Vector2(2.75,1.75)
 check(app.layout.walkable(app.hero_pos),"drain observer fixture stands on an actual walkable tile")
 check(trace3().begin_read("asylum_corpse_wristband"),"actual visible drain bracelet starts a timed reading without taking it")
 step3(0.35);var elapsed:float=float(trace3().state().active.get("elapsed",-1.0))
 check(elapsed>0.3 and elapsed<0.5 and not stable_trace_read("asylum_corpse_wristband"),"unfinished reading gives no early knowledge")
 check(roundtrip() and is_equal_approx(float(trace3().state().active.get("elapsed",-2.0)),elapsed),"half-reading JSON preserves actual elapsed time and original location")
 check(until3(func():return trace3().state().active.is_empty(),2) and stable_trace_read("asylum_corpse_wristband"),"same resumed read really reaches its completion node")
 check(app.rules.owners.asylum_corpse_wristband=="bathroom:drain","reading a bracelet leaves the single physical bracelet on the floor")
 check(trace3().take_relic("asylum_corpse_wristband"),"actual take begins a separate contact action")
 step3(0.2);give_skill("SKIN")
 check(cast("SKIN").get("success",false),"paid neural skin reaction really interrupts unfinished take")
 step3(0.7)
 check(app.rules.owners.asylum_corpse_wristband=="bathroom:drain" and trace3().state().active.is_empty(),"interrupted contact cannot grant the item later")
 check(trace3().take_relic("asylum_corpse_wristband") and until3(func():return app.rules.owners.asylum_corpse_wristband=="hero",2),"new completed physical pickup changes the one existing item's owner")
 check(not trace3().take_relic("asylum_corpse_wristband"),"already-owned bracelet cannot be duplicated by another take request")
 app.hero_pos=Vector2(4.2,1.1)
 check(trace_read("corpse_tag"),"uncovered corpse ankle tag can be actually read at its physical position")
 check(not "asylum_deceased_relic_match" in app.rules.known and not trace_receipt("RELIC_MATCH"),"two null numbers cannot form a deceased-identity comparison")
 await capture("01_real_read_and_owned_bracelet")

 # A new finite fixture starts before any cleaner work. Read and acquire the
 # actual bracelet first, then leave the cart's path clear and let work run.
 trace_fixture();app.hero_pos=Vector2(2.75,1.75)
 check(trace_read("asylum_corpse_wristband"),"cleaner case first gains bracelet knowledge through real reading")
 check(trace3().take_relic("asylum_corpse_wristband") and until3(func():return app.rules.owners.asylum_corpse_wristband=="hero",2),"cleaner case takes original bracelet before any collection")
 app.hero_pos=Vector2(1.6,0.6);actor3("cleaner","bathroom",Vector2(2.0,0.6))
 check(app.layout.walkable(app.asylum.position("cleaner")),"cleaner fixture begins on a real reachable tile")
 var key_owner:String=str(app.rules.owners.key)
 check(until3(func():return trace3().state().cleaner.phase=="cover",15),"cleaner actually approaches and closes only the corresponding shower screen")
 check(trace3().state().screen_closed and not trace3().state().corpse.on_board,"closing a screen does not already move or load a corpse")
 give_skill("GUT");check(cast("GUT").get("success",false),"unrelated protagonist gut reaction really executes")
 step3(0.6)
 check(trace3().state().cleaner.phase!="cover" or float(trace3().state().cleaner.elapsed)>0.5,"unrelated bodily reaction does not pause the cleaner's independent work")
 check(roundtrip(),"partial cover or board-loading work survives real checksummed JSON")
 check(until3(func():return bool(trace3().state().corpse.moved_out),30),"covered corpse and its board physically reach and cross the actual bathroom door")
 check(trace3().state().corpse.room=="corridor" and trace3().state().corpse.identity=="independent_deceased","moved corpse remains one independent deceased in the corridor")
 var corpses:int=0
 for prop in trace3().render_state():
  if prop.get("kind","")=="corpse":corpses+=1
 check(corpses==1,"render state contains one corpse rather than a bathroom copy plus transported copy")
 check(until3(func():return trace3().state().cleaner.phase=="wash" and float(trace3().state().cleaner.elapsed)>0.25,45),"cleaner parks board, returns through real door, picks remaining relic and begins a particular wash region")
 check(app.rules.owners.asylum_corpse_wristband=="hero" and app.rules.owners.asylum_meal_list=="asylum_cleaner_bucket","cleaner preserves acquired bracelet and actually collects only the remaining relic")
 var partial:Dictionary=trace3().state().cleaner.duplicate(true)
 var washed:Array=trace3().state().washed.duplicate()
 check(partial.phase=="wash" and float(partial.elapsed)>0.25 and roundtrip() and trace3().state().cleaner.phase==partial.phase and is_equal_approx(float(trace3().state().cleaner.elapsed),float(partial.elapsed)) and trace3().state().washed==washed,"half-cleaned region, prior cleaned regions, remaining relics and board location persist independently")
 check(until3(func():return trace3().state().cleaner.phase=="done",30),"resumed cleaner physically finishes the remaining finite regions")
 check(trace3().state().washed.size()==3 and stable_trace_read("asylum_corpse_wristband"),"cleaning removes only three processed local traces and cannot erase already-read information")
 check(app.rules.owners.key==key_owner and app.rules.owners.asylum_corpse_wristband=="hero","cleaning neither removes the real progression key nor duplicates an already-taken relic")
 check(roundtrip() and trace3().state().cleaner.phase=="done" and trace3().state().corpse.room=="corridor","completed cleanup and one corpse location survive reload without replay")
 await capture("02_cleaned_bathroom_actual_state")

 trace_fixture("double_ward");app.hero_pos=Vector2(4.0,1.3)
 actor3("corner_patient","double_ward",Vector2(4.45,1.55))
 check(not app.asylum.present("patient"),"cross-level patient is absent upstairs before any real guard delivery")
 check(until3(func():return trace3().state().conversation.shown.get("asylum_corner_transfer_note",false),3),"alone corner patient really prepares and exposes only his own old note")
 check(not trace3().state().conversation.shown.has("asylum_patient_transfer_note") and not "asylum_same_car_statement" in app.rules.known,"an absent patient cannot manufacture his note or speak the two-person car statement")
 check(trace_read("asylum_corner_transfer_note"),"one exposed note is really read at contact")
 check(int(trace3().state().conversation.get("read_count",0))==1 and trace_receipt("ONE_NOTE") and not trace_receipt("BOTH_NOTES"),"one-note branch asks for the other rather than claiming a two-note match")
 actor3("med_nurse","corridor",Map.doorway("corridor","double_ward")+Vector2(0,0.5))
 for i in range(50):
  app.asylum.travel("med_nurse","double_ward",0.025);step3()
  if trace3().state().conversation.shown.is_empty():break
 check(trace3().state().conversation.shown.is_empty() and trace3().state().conversation.stopped,"actual medical arrival at the real doorway stops private note display")
 check(stable_trace_read("asylum_corner_transfer_note") and not trace3().begin_read("asylum_patient_transfer_note"),"interruption retains known note but cannot grant an absent or hidden second note")
 await capture("03_private_one_note_interrupted")

 # The second case earns the upstairs patient from real original guard logic.
 trace_fixture("office");app.hero_pos=Vector2(2.8,2.6)
 actor3("patient","office",Vector2(3.0,1.4));actor3("guard","office",Vector2(2.5,1.4))
 check(app.asylum.layout_for("office").walkable(app.asylum.position("patient")) and app.asylum.layout_for("office").walkable(app.asylum.position("guard")),"patient-delivery fixtures use real walkable initial office positions")
 var route:Array=["office"]
 for i in range(6000):
  if app.asylum.records.state().patient_delivered:break
  step3()
  var room:String=str(app.asylum.actor("patient").room)
  if route[-1]!=room:route.append(room)
 check(app.asylum.records.state().patient_delivered and rec3("patient_delivered"),"guard really grips and delivers original patient before any two-person upstairs conversation")
 check(route.has("lobby") and route.has("stairs") and route.has("corridor") and route.has("double_ward"),"the same patient physically crosses reception, original stairs and corridor")
 check(until3(func():return app.asylum.actor("guard").room=="office" and app.asylum.records.state().guard.phase=="idle",100),"guard physically leaves the delivered patient and returns downstairs before private talk")
 app.enter_room("double_ward");app.hero_pos=Vector2(2.8,1.3);app.session.data.exploration_boundary=true
 actor3("corner_patient","double_ward",Vector2(3.2,1.35))
 check(until3(func():return trace3().state().conversation.shown.get("asylum_patient_transfer_note",false) and trace3().state().conversation.shown.get("asylum_corner_transfer_note",false),4),"only the actual delivered patient plus actual corner patient expose two individually owned notes")
 check("asylum_same_car_statement" in app.rules.known,"source same-car line is retained as an actual statement rather than fabricated numerical proof")
 app.hero_pos=Vector2(2.75,2.0)
 check(trace_read("asylum_patient_transfer_note"),"delivered patient's own note is physically read")
 check(roundtrip() and int(trace3().state().conversation.get("read_count",0))==1,"one of two exposed notes survives JSON without marking the other as read")
 app.hero_pos=Vector2(2.8,1.3)
 check(trace_read("asylum_corner_transfer_note"),"second owner's separate note is physically read")
 check(int(trace3().state().conversation.get("read_count",0))==2 and not "asylum_same_vehicle_verified" in app.rules.known and not trace_receipt("BOTH_NOTES"),"two read notes stay distinct while unknown dates, vehicle and personal numbers cannot compare as equal")
 check(app.rules.owners.asylum_patient_transfer_note=="patient" and app.rules.owners.asylum_corner_transfer_note=="corner_patient","showing and reading two notes never transfers either owner's document")
 await capture("04_two_actual_read_notes_unknown_fields")

 trace_fixture("double_ward");app.hero_pos=Vector2(2.3,1.0)
 actor3("corner_patient","double_ward",Vector2(3.2,1.35))
 check(until3(func():return trace3().state().conversation.shown.get("asylum_corner_transfer_note",false),3),"corner-removal case first has a genuinely exposed old note")
 actor3("ordinary_orderly","corridor",Vector2(0.55,0.6));step3(0.3)
 check(trace3().state().corner.phase=="idle" and not rec3("corner_grip"),"remote orderly cannot see a room's note or start a grab through walls")
 var entered:bool=false
 for i in range(500):
  if app.asylum.actor("ordinary_orderly").room=="double_ward":entered=true;break
  if trace3().state().corner.phase=="idle":app.asylum.travel("ordinary_orderly","double_ward",0.025)
  step3()
 check(entered or app.asylum.actor("ordinary_orderly").room=="double_ward","ordinary orderly actually enters via the existing corridor door rather than appearing beside corner patient")
 check(until3(func():return rec3("corner_grip"),12),"actual visible old note leads to a finite reach and real corner-patient grip")
 check(not app.rules.gripped and str(app.asylum.data.holder).is_empty(),"NPC-to-NPC grip does not freeze or grip the protagonist")
 check(until3(func():return bool(trace3().state().corner.done),30),"paired original actors physically reach and leave the existing bedroom door then release at corridor waiting place")
 check(trace3().state().corner.get("delivered",false) and app.asylum.actor("corner_patient").room=="corridor","corner completion is recorded only at the real corridor destination")
 check(not app.asylum.data.staff_targets.has("ordinary_orderly") and app.rules.owners.asylum_corner_transfer_note=="corner_patient","release clears single staff task while the unhanded note stays with its original owner")
 check(roundtrip() and trace3().state().corner.done,"completed corner removal persists without respawning the bedroom conversation")
 await capture("05_actual_corner_pair_released")
 finish3()
