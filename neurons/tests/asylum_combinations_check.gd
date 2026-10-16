extends "res://tests/asylum_isolation_check.gd"
## Finite cross-module cases, not a natural-RNG or human playthrough.
## Initial positions/random-arrival exclusions and pre-existing signed papers
## are declared inputs. No successful grip, completed read or pickup is seeded.
var combined_nurse_rooms:Array=[]
var retries:Array=[]

func capture(image_name:String) -> void:
 # Windows may stop presenting an occluded validation window. Render the
 # actual viewport explicitly rather than waiting forever for presentation.
 await frames(2)
 app.view.queue_redraw()
 RenderingServer.force_draw(false)
 get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(folder).path_join(image_name+".png"))
var shared_report_overlap:bool=false

func fresh3(room:String) -> void:
 app.asylum.data={};fixture3(room,true)
 app.session.data.exploration_boundary=true
 app.hero_route=PackedVector2Array();app.target_index=-1

func trace_combined():return app.asylum.trace_events
func record_combined():return app.asylum.records
func observe_combined():return app.asylum.observations
func ward_combined() -> Dictionary:return app.asylum.ward_events.state()
func duty_combined() -> Dictionary:return app.asylum.nurse_duty.state()

func acquire_bracelet() -> bool:
 app.hero_pos=Vector2(2.75,1.75)
 if not trace_combined().take_relic("asylum_corpse_wristband"):return false
 return until3(func():return app.rules.owners.get("asylum_corpse_wristband","")=="hero" and trace_combined().state().active.is_empty(),2)

func travel_hero_combined(to:String) -> bool:
 # No room assignment or teleport: each existing doorway uses the campaign's
 # normal path, opening stage and enter-room callback. The test selects only
 # the next legal door and holds random arrivals as the declared fixture.
 app.session.data.exploration_boundary=false
 var transitions:int=0
 while app.room_id!=to and transitions<8:
  var next:String=Map.next_room(app.room_id,to)
  if next.is_empty():break
  app.route_to_door(next)
  if not until3(func():return app.room_id==next,12):break
  transitions+=1
 app.session.data.exploration_boundary=true
 return app.room_id==to

func signed_combination_order(target:String,room:String,at:Vector2,suffix:String) -> String:
 # Explicit intermediate input AFTER an earlier ordinary delivery: the signed
 # physical paper is on the existing station. This suite does not claim that
 # the preceding witness/signature chain was newly played by this fixture.
 var station:Vector2=app.asylum.layout_for("corridor").furniture[0].at
 var id:String="combination-signed:%d:%s"%[app.rules.actual_attempt,suffix]
 ward_combined().reports.append({"id":id,"event":"explicit_signed_handoff_fixture","source":"explicit_test_input_after_ordinary_delivery","target":target,
  "attempt":app.rules.actual_attempt,"written":true,"received":true,"permit_given":false,"ordinary_taken":true,"ordinary_outcome":"delivered",
  "isolation_order":"isolate:"+id,"isolation_signed":true,"isolation_taken":false,"last_room":room,"last_pos":app.asylum.xy(at),
  "station_pos":app.asylum.xy(station),"patient_number":null,"head_nurse_witnessed":false,"testimony":""})
 actor3("isolation_orderly","corridor",Vector2(3.3,0.65))
 return id

func wait_combination(predicate:Callable,seconds:float=90.0) -> bool:
 for index in range(ceili(seconds/0.025)):
  if predicate.call():return true
  # Independent readers may finish before the door closes. Require a real
  # overlap on this exact source while both jobs execute, rather than making
  # the game's correct eight-second door window wait for a nurse animation.
  var nurse_job:Dictionary=duty_combined().job
  var order:Dictionary=iso3().state().order
  if not nurse_job.is_empty() and not order.is_empty() and str(nurse_job.get("source",{}).get("source_id",""))==str(order.get("id","")):
   shared_report_overlap=true
  if app.asylum.present("med_nurse"):
   var room:String=str(app.asylum.actor("med_nurse").room)
   if combined_nurse_rooms.is_empty() or combined_nurse_rooms[-1]!=room:combined_nurse_rooms.append(room)
  step3()
 return predicate.call()

func owned_bracelet_not_duplicated() -> bool:
 if app.rules.owners.get("asylum_corpse_wristband","")!="hero":return false
 for prop in trace_combined().render_state():
  if str(prop.get("id",""))=="asylum_corpse_wristband":return false
 return true

func suppress_new_random_arrivals() -> void:
 # Later rest attempts use the same explicit no-random-arrival fixture. This
 # does not erase an acquired item, receipt, knowledge or a successful action.
 for group in app.asylum.data.groups:
  app.asylum.data.groups[group].drawn=true
  app.asylum.data.groups[group].pending=false

func disk_restore_combined(snapshot:Dictionary) -> bool:
 if not app.store.save_snapshot(snapshot).ok:return false
 var disk:Dictionary=app.store.load_snapshot()
 return disk.ok and app.restore_snapshot(disk.data)

func check_nurse_legacy_keys(source_id:String) -> void:
 var nurse=app.asylum.nurse_duty
 var original:Dictionary=app.snapshot_data()
 var real_entry:Dictionary={}
 for entry in duty_combined().entries:
  if str(entry.get("source_id",""))==source_id:real_entry=entry.duplicate(true);break
 if real_entry.is_empty():check(false,"legacy-key check requires a genuinely written public duty copy");return
 var canonical_key:String=nurse.source_key(real_entry)
 var legacy_key:String="%s:%s:%d.0"%[real_entry.source_kind,real_entry.source_id,int(real_entry.source_attempt)]
 var integer_source:Dictionary=real_entry.duplicate(true);integer_source.source_attempt=int(real_entry.source_attempt)
 var float_source:Dictionary=integer_source.duplicate(true);float_source.source_attempt=float(integer_source.source_attempt)
 var unknown_source:Dictionary=integer_source.duplicate(true);unknown_source.source_attempt=null
 var zero_source:Dictionary=integer_source.duplicate(true);zero_source.source_attempt=0
 var other_kind:Dictionary=integer_source.duplicate(true);other_kind.source_kind="different_explicit_source_type"
 var other_attempt:Dictionary=integer_source.duplicate(true);other_attempt.source_attempt=int(integer_source.source_attempt)+1
 check(nurse.source_key(integer_source)==nurse.source_key(float_source),"duty source key is identical for the same integer attempt before and after JSON numeric conversion")
 check(nurse.source_key(unknown_source)!=nurse.source_key(zero_source) and nurse.source_key(other_kind)!=canonical_key and nurse.source_key(other_attempt)!=canonical_key,"unknown attempt, supplied zero, different source type and different actual attempt never collapse into one paper source")
 # Compatibility fixture changes only the receipt-index spelling attached to
 # the actual copy earned above. It does not seed a new writing outcome.
 var legacy:Dictionary=original.duplicate(true)
 legacy.asylum_state.nurse_duty_state.completed.erase(canonical_key)
 legacy.asylum_state.nurse_duty_state.completed[legacy_key]=str(real_entry.id)
 check(disk_restore_combined(legacy),"old float-spelled completed-source index loads through actual checksummed disk save")
 var migrated:Dictionary=duty_combined()
 check(migrated.completed.get(canonical_key,"")==str(real_entry.id) and not migrated.completed.has(legacy_key) and migrated.entries.size()==1 and migrated.entries[0].id==real_entry.id,"legacy source index is rebuilt from the existing entry fields while retaining the original physical copy ID")
 var written_count:int=fact_count3("asylum_nurse_duty_clipped")
 step3(3)
 check(duty_combined().entries.size()==1 and fact_count3("asylum_nurse_duty_clipped")==written_count and duty_combined().job.is_empty(),"restored completed source cannot start a new copy, create another clipping receipt or await an unnecessary job")

 # Explicit historical compatibility input representing two already-written
 # old-version copies. These two input entries/records must stay visible; the
 # migration may identify their shared source but cannot erase their history.
 var historical:Dictionary=original.duplicate(true)
 var duplicate_entry:Dictionary=real_entry.duplicate(true)
 duplicate_entry.id=str(real_entry.id)+":historical_float_alias_copy"
 duplicate_entry.source_attempt=float(real_entry.source_attempt)
 historical.asylum_state.nurse_duty_state.entries.append(duplicate_entry)
 historical.asylum_state.nurse_duty_state.completed[legacy_key]=str(duplicate_entry.id)
 historical.asylum_state.nurse_duty_state.job={"phase":"clip","elapsed":0.1,"source":duplicate_entry.duplicate(true),"read_completed":true,"number_checked":true,"written":true,"clipped":false}
 for record in original.rules.institutional_records:
  if str(record.get("id",""))!=str(real_entry.id):continue
  var duplicate_record:Dictionary=record.duplicate(true);duplicate_record.id=str(duplicate_entry.id)
  historical.rules.institutional_records.append(duplicate_record);break
 var historical_record_count:int=historical.rules.institutional_records.size()
 check(disk_restore_combined(historical),"explicit two-written-copy historical input is accepted without pretending this fixture newly played two writes")
 var history:Dictionary=duty_combined()
 check(history.entries.size()==2 and history.entries[0].id==real_entry.id and history.entries[1].id==duplicate_entry.id and history.entries[1].get("duplicate_source",false) and history.entries[1].get("duplicate_of","")==real_entry.id,"historical duplicate remains a second physical entry marked with its first source copy rather than silently deleted")
 check(app.rules.institutional_records.size()==historical_record_count and history.completed.get(canonical_key,"")==real_entry.id and not history.completed.has(legacy_key),"historical institutional records are retained while the shared semantic source has one canonical completion index")
 check(history.job.is_empty() and not history.get("duplicate_jobs",[]).is_empty() and history.duplicate_jobs[-1].job.written and is_equal_approx(float(history.duplicate_jobs[-1].job.elapsed),0.1),"stale third-copy job is stopped while its already-written partial action remains explicit migration history")
 step3(3)
 check(duty_combined().entries.size()==2 and app.rules.institutional_records.size()==historical_record_count and duty_combined().job.is_empty(),"loading historical duplicate copies neither erases either old record nor manufactures a third copy")
 check(disk_restore_combined(original) and duty_combined().entries.size()==1,"genuine one-copy snapshot is restored after the declared historical migration fixtures")

func finish3() -> void:
 var result:Dictionary={"passes":passes,"failures":failures,"rendered":true,
  "scope":"B3 finite cross-module combinations: physical relic pickup and real doorway travel; public observation interrupted by actual isolation grip while retaining the item; paid skill cancels a saved office read without late knowledge; one nurse physically crosses floors and copies the same signed report while the original NPC undergoes isolation; explicit legacy attempt-alias disk migration merges by maximum without rewards; three real low-SP return/rest attempts retain unique materials and identities. Not human normal-speed play, all probability permutations, formal art, subjective audio or full B3 acceptance.",
  "fixtures":"Walkable initial contact/actor positions, all random arrival groups held drawn; explicit already-written/current-attempt signed handoff after ordinary delivery, never seeded received isolation order, grip, closure, read or pickup outcomes in gameplay checks. Separate historical migration fixtures alter the completed-source key spelling or explicitly supply two pre-existing written copies and a third partly written old job; these are compatibility inputs, not claimed gameplay outcomes, and the genuine earned one-copy snapshot is restored afterward. Initial SP=40 only requests the real low-SP return/rest path. Fixed 0.025-second campaign advance drives finite checks; screenshots are actual rendered viewports, not manual play evidence.",
  "methods":{"normal_campaign_update":true,"world_step_seconds":0.025,"actual_checksummed_json":true,"human_playthrough":false,"audio_listened":false},
  "nurse_rooms":combined_nurse_rooms,"shared_report_overlap_observed":shared_report_overlap,"real_rest_attempts":retries,
  "untested":"All simultaneous claimant orderings, natural RNG/long indefinite sessions, user-operated entire playthrough, every observation combination, approved visible number/name/date art, formal audio and target-platform export."}
 var f:=FileAccess.open(ProjectSettings.globalize_path(folder).path_join("result.json"),FileAccess.WRITE)
 f.store_string(JSON.stringify(result,"  "));f.close()
 print("ASYLUM_COMBINATIONS_CHECK %d passed %d failed"%[passes.size(),failures.size()])
 frontend.request_exit(0 if failures.is_empty() else 1)

func _ready() -> void:
 folder="res://../docs/validation/b3_20261016/combinations"
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--validation-root="):folder=argument.trim_prefix("--validation-root=")
 name="CampaignCheck";frontend=get_parent();DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 await frames();frontend.show_profile();await frames();frontend.name_field.text="精神病院跨模块组合验证"
 frontend.overwrite_armed=true;frontend.new_game();await frames();app=frontend.active
 if app.tutorial_ui!=null:app.tutorial_ui.finish()
 if app.asylum.isolation==null or app.asylum.nurse_duty==null or app.asylum.observations==null:
  check(false,"required B3 modules are attached to the normal campaign owner");finish3();return

 # Pickup is earned before the same live hero crosses the real bathroom,
 # corridor and quiet-room doors. Only the final document contact stand is
 # an explicit placement fixture; no room crossing is assigned directly.
 fresh3("bathroom")
 check(acquire_bracelet(),"original drain bracelet is physically taken before the combined hold/read case")
 check(travel_hero_combined("quiet"),"same item holder traverses real bathroom-corridor-quiet door actions")
 app.hero_pos=app.layout.furniture[0].at;app.hero_route=PackedVector2Array()
 var id:String=signed_combination_order("hero","quiet",app.hero_pos,"read-held")
 check(until3(func():return iso3().state().phase=="reach",25),"signed order is actually received and isolation staff physically reach the existing protagonist")
 clear_lines()
 check(observe_combined().begin("asylum_prefilled_isolation_record",false),"holding an acquired relic still permits actual public-paper read during the pre-grip intervention window")
 step3(0.2)
 check(not observe_combined().state().active.is_empty() and not "asylum_prefilled_isolation_record" in app.rules.known,"pre-grip reading has visible preparation without premature paper knowledge")
 check(until3(func():return app.asylum.data.holder=="isolation_orderly",1),"actual hand contact establishes the sole isolation holder while the paper read is unfinished")
 check(observe_combined().state().active.is_empty() and app.rules.public_action.get("target","")!="asylum_prefilled_isolation_record","actual grip cancels its in-flight public reading and clears only that action")
 check(not "asylum_prefilled_isolation_record" in app.rules.known and owned_bracelet_not_duplicated(),"grip grants no unread paper content and neither drops nor duplicates the separately owned bracelet")
 check(roundtrip() and app.asylum.data.holder=="isolation_orderly" and owned_bracelet_not_duplicated(),"checksummed mid-grip JSON retains the one holder and independent item ownership")
 check(wait_for_closed(20),"same actual held target is delivered and the existing quiet-room door really closes")
 check(not "asylum_prefilled_isolation_record" in app.rules.known and owned_bracelet_not_duplicated(),"finishing isolation cannot retroactively finish the cancelled paper action")
 check(fact_count3("asylum_isolation_grip")==1 and app.rules.hp==100 and app.rules.sp==100,"read/grip/item interleaving creates one grip and no invented bodily cost")
 await capture("01_item_retained_after_real_read_interruption")
 check(until3(func():return iso3().state().handled.has(id),12),"full observation and actual opening end the same signed isolation once")
 check(roundtrip() and owned_bracelet_not_duplicated() and not "asylum_prefilled_isolation_record" in app.rules.known,"post-opening reload cannot invent a late read or second relic")

 fresh3("office");app.hero_pos=record_combined().page_position(0)
 check(record_combined().begin_read(0,"asylum_archive_index"),"office page begins from its actual contact stand")
 step3(0.35)
 check(roundtrip() and not record_combined().state().reading.is_empty(),"unfinished office read survives ordinary disk JSON before intervention")
 give_skill("SKIN");var before:int=app.rules.neurons
 check(cast("SKIN").get("success",false),"real paid SKIN applies to the already-restored reading action")
 check(app.rules.neurons<before and record_combined().state().reading.is_empty(),"successful intervention pays its original cost and cancels the read")
 check(roundtrip(),"cancelled-action snapshot is written and accepted by the existing loader")
 step3(2)
 check(not "asylum_archive_index" in app.rules.known and not record_combined().state().read.has("asylum_archive_index"),"world time after interrupted-action load cannot award the unread archive page")
 check(not rec3("document:asylum_archive_index") and app.rules.public_action.get("target","")!="asylum_archive_index","interruption creates neither a completed document receipt nor a stale public action")
 check(record_combined().begin_read(0,"asylum_archive_index"),"fresh complete read remains legal after the real reaction ends")
 check(until3(func():return "asylum_archive_index" in app.rules.known,2),"only a newly completed physical read creates the knowledge")
 check(roundtrip() and app.rules.known.count("asylum_archive_index")==1,"completed reread/load leaves exactly one knowledge entry")
 await capture("02_skill_cancel_load_then_real_reread")

 fresh3("activity");app.hero_pos=Vector2(4.1,2.35)
 actor3("postop_patient","quiet",Vector2(2.8,1.6))
 id=signed_combination_order("postop_patient","quiet",Vector2(2.8,1.6),"nurse-and-target")
 actor3("med_nurse","pharmacy",Vector2(3.5,1.0));combined_nurse_rooms.clear();shared_report_overlap=false
 check(wait_combination(func():return iso3().state().door_closed,60),"original NPC is physically isolated through the real signed-paper/contact/door chain")
 check(shared_report_overlap,"one nurse and the isolation worker have genuinely overlapping independent jobs bound to this exact signed source")
 check(app.asylum.actor("postop_patient").room=="quiet" and not app.rules.gripped and app.asylum.data.holder=="","NPC isolation keeps the real target indoors without assigning a protagonist holder")
 check(roundtrip(),"overlapping nurse job and NPC door observation both survive one real JSON snapshot")
 check(wait_combination(func():return not duty_combined().entries.is_empty() and iso3().state().handled.has(id),90),"nurse finishes physical read/check/cross-floor write/clip and isolation independently ends")
 var matching:Array=[]
 for entry in duty_combined().entries:
  if str(entry.get("source_id",""))==id:matching.append(entry)
 check(matching.size()==1,"the shared signed source creates exactly one public duty copy")
 if matching.size()==1:
  var entry:Dictionary=matching[0]
  check(entry.subject_identity=="postop_patient" and entry.number==null and entry.number_match==null,"copy retains the original isolated subject without inventing visible number matches")
  check(not entry.own_swallow_witness and not entry.original_owner_changed and entry.clipped,"report copying creates neither a medication eyewitness nor a paper-owner transfer")
 check(combined_nurse_rooms.has("pharmacy") and combined_nurse_rooms.has("lobby") and combined_nurse_rooms.has("stairs") and combined_nurse_rooms.has("corridor"),"same nurse really traverses pharmacy/lobby/stairs/corridor while processing this report")
 check(app.asylum.data.actors.size()==21 and fact_count3("asylum_isolation_grip")==1 and fact_count3("asylum_isolation_started")==1,"simultaneous report users retain twenty-one unique identities and one actual target grip/closure")
 step3(3)
 check(app.rules.hp==100 and app.rules.sp==100 and not app.rules.gripped and app.asylum.data.holder=="","independent NPC handling/paperwork adds no protagonist harm or lingering grip")
 check_nurse_legacy_keys(id)
 await capture("03_same_nurse_report_and_original_isolated_patient")

 fresh3("bathroom")
 check(acquire_bracelet() and travel_hero_combined("workshop"),"repeat-attempt case first takes one real relic then uses existing doors to the workshop")
 app.hero_pos=app.layout.furniture[7].at
 check(app.asylum.ward_events.take_material("paper"),"actual rack contact transfers the existing finite paper to the protagonist")
 check(ward_combined().work.paper=="hero" and app.rules.owners.asylum_work_paper=="hero","workshop logical material and unique owner agree before any rest")
 # Three genuinely paid reactions earn one pending skill growth; cooldowns
 # advance on the same world clock, never by editing their configured values.
 give_skill("SKIN")
 for reaction in range(3):
  check(cast("SKIN").get("success",false),"real reaction %d of three is accepted before rest"%(reaction+1))
  var wait_seconds:float=maxf(0.75,float(app.rules.skill_states.SKIN.until)-app.rules.world_time+0.025)
  step3(wait_seconds)
 var old_resistance:int=int(app.rules.skill_states.SKIN.resistance)
 check(app.rules.skill_states.SKIN.growth,"three paid successful reactions earn one actual pending resistance increment")
 # Explicit old-save compatibility input, not a real extra attempt. Two
 # legacy spellings identify one counter and must never be added together.
 # Restore the genuine pre-migration snapshot before the three actual rests.
 var original_snapshot:Dictionary=app.snapshot_data()
 var legacy_snapshot:Dictionary=original_snapshot.duplicate(true)
 var canonical_attempt:int=int(legacy_snapshot.session.attempts["3"])
 legacy_snapshot.session.level=3.0
 legacy_snapshot.session.cycle=float(legacy_snapshot.session.cycle)
 legacy_snapshot.session.attempts["3.0"]=canonical_attempt+1
 check(app.store.save_snapshot(legacy_snapshot).ok,"explicit legacy alias fixture is written through the checksummed save store")
 var migrated_load:Dictionary=app.store.load_snapshot()
 check(migrated_load.ok and app.restore_snapshot(migrated_load.data),"real disk loading accepts the legacy 3/3.0 attempt aliases")
 check(app.session.data.level is int and app.session.data.cycle is int and not app.session.data.attempts.has("3.0") and int(app.session.data.attempts["3"])==canonical_attempt+1,"legacy attempt spellings merge to the highest counter and never their sum")
 check(app.rules.actual_attempt==int(original_snapshot.rules.actual_attempt) and app.rules.neurons==int(original_snapshot.rules.neurons) and app.rules.plexus==int(original_snapshot.rules.plexus) and app.rules.search_attempts==int(original_snapshot.rules.search_attempts),"alias normalization itself creates no actual retry, search settlement, neuron or cluster reward")
 check(app.session.data.targets==original_snapshot.session.targets and app.rules.facts.size()==original_snapshot.rules.facts.size() and owned_bracelet_not_duplicated() and app.rules.owners.asylum_work_paper=="hero" and app.rules.skill_states.SKIN.growth,"alias migration preserves the existing sample, facts, unique material and still-uncommitted earned growth")
 check(app.store.save_snapshot(original_snapshot).ok,"genuine original snapshot is independently saved back after the migration fixture")
 var original_load:Dictionary=app.store.load_snapshot()
 check(original_load.ok and app.restore_snapshot(original_load.data) and app.session.data.attempts["3"]==canonical_attempt,"genuine original attempt is restored before all three unchanged physical return/rest checks")
 var base_attempt:int=app.rules.actual_attempt;var base_cycle:int=app.session.data.cycle
 var invader:int=app.invader_id;var initial_relic_facts:int=fact_count3("asylum_relic_taken")
 for retry in range(3):
  app.session.data.exploration_boundary=false;app.rules.sp=40
  var expected:int=base_attempt+retry+1
  var visited:Array=[]
  for tick in range(9000):
   if app.rules.actual_attempt>=expected:break
   if visited.is_empty() or visited[-1]!=app.room_id:visited.append(app.room_id)
   step3()
  suppress_new_random_arrivals();app.session.data.exploration_boundary=true
  retries.append({"attempt":app.rules.actual_attempt,"cycle":app.session.data.cycle,"rooms":visited.duplicate(),"bracelet_owner":app.rules.owners.get("asylum_corpse_wristband",""),"paper_owner":app.rules.owners.get("asylum_work_paper","")})
  check(app.rules.actual_attempt==expected and app.session.data.cycle==base_cycle+retry+1,"real return/rest %d advances exactly one attempt and one cycle"%(retry+1))
  check(app.room_id=="ward" and app.rules.hp==100 and app.rules.sp==100 and app.invader_id==invader,"normal rest %d restores at the designated bed without a revival identity increment"%(retry+1))
  check(owned_bracelet_not_duplicated() and ward_combined().work.paper=="hero" and app.rules.owners.asylum_work_paper=="hero","rest %d preserves the same held relic and finite paper without rack respawn"%(retry+1))
  check(app.asylum.data.actors.size()==21 and app.session.data.targets.size()==14 and app.rules.search_attempts==0,"rest %d rebuilds the original identity slots and fourteen-point sample without duplicated search settlement"%(retry+1))
  check(int(app.rules.skill_states.SKIN.resistance)==old_resistance+1 and not app.rules.skill_states.SKIN.growth,"rest %d commits earned growth once and cannot commit it again"%(retry+1))
  check(roundtrip() and owned_bracelet_not_duplicated() and app.rules.owners.asylum_work_paper=="hero","rest %d disk reload preserves unique item/material ownership"%(retry+1))
  if retry<2:check(travel_hero_combined("workshop"),"next retry again physically crosses the two floors to the original workshop")
 check(fact_count3("asylum_relic_taken")==initial_relic_facts,"three rests and reloads cannot replay the original relic pickup receipt")
 check(retries[0].rooms.has("corridor") and retries[0].rooms.has("stairs") and retries[0].rooms.has("lobby"),"first real low-SP return crosses both floors and original reception rather than teleporting to bed")
 check(travel_hero_combined("workshop"),"post-rest material verification returns through the actual established doors")
 actor3("labor_patient","workshop",app.layout.furniture[7].at);step3(2)
 check(ward_combined().work.phase=="waiting_materials" and ward_combined().work.products==0,"original worker still waits for the held-away finite paper after repeated rest instead of generating a replacement")
 check(not app.asylum.ward_events.take_material("paper") and owned_bracelet_not_duplicated(),"repeated interaction cannot retake either already-owned original material or create a floor relic")
 await capture("04_three_actual_rests_unique_items_and_pending_growth")
 finish3()
