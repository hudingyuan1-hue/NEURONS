extends "res://tests/hospital_check.gd"
## Declared hospital cast/geometry fixtures; genuine carry handler and JSON history.
func prepare_bag(witnessed:bool=true) -> bool:
 hospital_fixture();spawn_actor("nurse");hospital_step()
 if not hospital_until(func():return app.hospital.data.nurse_checked,2):return false
 spawn_actor("porter",Vector2(3.05,1.3))
 if not hospital_until(func():return app.hospital.data.bag=="porter",6):return false
 if not witnessed:app.enter_room("clinic");app.session.data.exploration_boundary=true
 return true
func no_street() -> void:
 for a in app.street.data.actors.values():a.present=false
 app.street.data.displays.linen={"read":0.0,"seen":false,"matched":false};app.street.data.displays.spoken.erase("transporter_hospital")
func porter_here() -> Dictionary:
 no_street();app.enter_room("street_plaza");app.hero_pos=Vector2(3,5)
 app.layout.furniture.clear();app.layout.rebuild_grid()
 var a:Dictionary=app.street.data.actors.transporter_hospital
 a.present=true;a.room=app.room_id;a.hp=40;a.pos=[4,5];a.phase="idle";a.hurt=0;a.cooldown=3;a.direction=[1,0];a.route=[]
 return a
func redraw_capture(label:String) -> void:
 app.update_ui();app.keep_metric_actor_visible();app.view.queue_redraw();await capture(label)
func _ready() -> void:
 name="CampaignCheck";frontend=get_parent();folder="res://../docs/validation/street_reports_20261018/reunion"
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--validation-root="):folder=argument.trim_prefix("--validation-root=")
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 await frames();await frontend.show_profile();frontend.name_field.text="实际搬袋经历与重逢验证";frontend.overwrite_armed=true;frontend.new_game();await frames();app=frontend.active
 if app.tutorial_ui!=null:app.tutorial_ui.finish()
 app.set_process(false);clear_lines()
 check(prepare_bag(),"actual nurse order and real porter approach/lift prepare one held bag")
 check(not "hospital_bag_carry_seen" in app.rules.known,"seeing a lift alone is not yet seeing actual carry motion")
 hospital_step(.1)
 check("hospital_bag_carry_seen" in app.rules.known and receipt("bag_carry_seen"),"real held-bag movement within actual local sight creates one prior witness receipt")
 var facts:int=app.rules.facts.size();hospital_step(.1)
 check(app.rules.facts.size()==facts,"same carry does not duplicate witness receipts or rewards")
 check(roundtrip() and "hospital_bag_carry_seen" in app.rules.known,"actual JSON retains witnessed original carry history")
 await redraw_capture("01_actual_hospital_carry")
 app.unlock_combat();app.unlock_street();app.rules.end_control();clear_lines();var porter:Dictionary=porter_here()
 var display=app.street.displays;var initial_hp:int=app.rules.hp;var initial_sp:int=app.rules.sp;var initial_n:int=app.rules.neurons
 display.tick(.1)
 check(not app.street.materials.known("street_linen_porter_reunion"),"prior carry alone cannot recognize an unread current figure")
 porter.room="street_side";display.tick(.5);porter.room=app.room_id;display.tick(.1)
 check(not app.street.data.displays.linen.seen,"leaving current sight clears incomplete reading instead of combining fragments")
 app.rules.hurt_left=.2;display.tick(.5)
 check(not app.street.data.displays.linen.seen,"actual hurt prevents completing the current appearance read")
 app.rules.hurt_left=0;display.tick(.65)
 check(app.street.materials.known("street_linen_porter_reunion") and app.dialogue_queue.is_empty(),"actual current close reading plus prior witness matches person while hostility delays speech")
 check(app.rules.hp==initial_hp and app.rules.sp==initial_sp and app.rules.neurons==initial_n,"recognition itself changes no health, skill cost, search reward or evidence")
 var elapsed:float=app.street.data.displays.linen.read;await frames(10)
 check(is_equal_approx(elapsed,float(app.street.data.displays.linen.read)),"manual pause freezes current reading clock")
 check(roundtrip() and app.street.data.displays.linen.matched,"real cross-chapter JSON preserves actual current match")
 porter=app.street.data.actors.transporter_hospital;app.hero_pos=Vector2(12,5);display=app.street.displays;display.tick(.025)
 check(app.dialogue_queue.size()==1 and str(app.dialogue_queue[0].text)=="是那个搬袋子的人。","original source sentence waits until the existing hostile actor is no longer a visible threat")
 clear_lines();display.tick(.1)
 check(app.dialogue_queue.is_empty(),"original reunion sentence cannot replay after closing or restoration")
 app.hero_pos=Vector2(3,5);await redraw_capture("02_current_porter_recognized")
 check(prepare_bag(false),"second genuine bag trip begins without current-room witness")
 check(hospital_until(func():return app.hospital.data.bag=="removed",15) and receipt("bag_removed"),"remote real bag removal still completes its independent original task")
 check(not "hospital_bag_carry_seen" in app.rules.known,"remote removal and generated office stub cannot manufacture prior carry witness")
 app.hospital.observe("laundry_handoff_complete","declared already-read office-stub fixture; not a carry witness")
 app.unlock_combat();app.unlock_street();clear_lines();app.rules.end_control();porter=porter_here();display=app.street.displays;display.tick(.7)
 check(app.street.materials.known("street_linen_porter_seen") and not app.street.materials.known("street_linen_porter_reunion") and not app.street.data.displays.linen.matched,"read stub plus real current figure produces limited appearance only, no retrospective identity match")
 porter.hp=0;display.tick(.7)
 check(app.dialogue_queue.is_empty(),"dead current actor cannot trigger a new recognition speech")
 hospital_fixture();spawn_actor("porter",Vector2(3.05,1.3));app.hospital.data.bag="porter";app.hospital.data.transport={"kind":"bag","phase":"exit","elapsed":0.0,"witness":[]}
 app.hero_pos=Vector2(5,3);app.layout.furniture.append({"id":"fixture_wall","rect":Rect2(3.7,.3,.1,3),"height":90});app.layout.rebuild_grid();hospital_step(.05)
 check(not "hospital_bag_carry_seen" in app.rules.known,"declared held-bag state with blocked or distant view cannot backfill historical witness")
 hospital_fixture();app.session.data.institution_geometry_version=2;app.hospital.start_attempt();app.room_id="";app.enter_room("ward");clear_lines()
 for group in app.hospital.data.groups:app.hospital.data.groups[group].drawn=true
 var pickup:Vector2=app.hospital.source_anchor("ward","laundry_pickup",Vector2.ZERO)
 app.hero_pos=pickup+Vector2(.6,.5);spawn_actor("porter",pickup);app.hospital.data.bag_order=true;app.rules.owners.hospital_laundry_manifest="ward_tray"
 check(hospital_until(func():return app.hospital.data.bag=="porter",6) and app.hospital.source_geometry_version()==2,"separate current v2 room fixture uses actual configured pickup and original handoff")
 hospital_step(.1)
 check("hospital_bag_carry_seen" in app.rules.known,"actual visible bag movement is witnessed in current metric room as well as legacy save geometry")
 var file:=FileAccess.open(ProjectSettings.globalize_path(folder).path_join("result.json"),FileAccess.WRITE)
 file.store_string(JSON.stringify({"passes":passes,"failures":failures,"scope":"Finite actual hospital order/lift/carry and cross-chapter save/read/hostility/speech. Explicit cast and position fixtures; one negative already-read-stub and one held-bag/occlusion fixture. No prior carry knowledge filled, no natural all-chapter or formal-art acceptance."},"  "));file.close()
 print("STREET_REUNION_CHECK %d passed %d failed"%[passes.size(),failures.size()]);app.audio.reset_scene();frontend.request_exit(0 if failures.is_empty() else 1)
