extends "res://tests/street_laundry_live_check.gd"
## Two explicit scenes, actual paid CONTROL, ordinary world ticks and real keys.
func click_point(point:Vector2) -> void:
 for down in [true,false]:
  var event:=InputEventMouseButton.new();event.position=point;event.global_position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;Input.parse_input_event(event);await frames(2)
func tap_key(code:Key) -> void:
 for down in [true,false]:
  var event:=InputEventKey.new();event.keycode=code;event.pressed=down;Input.parse_input_event(event);await frames(2)
func splash_sounds() -> int:
 var count:int=0
 for start in app.audio.starts:
  if start.id=="SFX_SPLASH" and not start.provisional:count+=1
 return count
func _ready() -> void:
 name="CampaignCheck";frontend=get_parent();folder="res://../docs/validation/street_splash_20261018/live"
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--validation-root="):folder=argument.trim_prefix("--validation-root=")
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 await frames();await frontend.show_profile();frontend.name_field.text="实际局部药液与粘连碎瓶连续验证";frontend.overwrite_armed=true;frontend.new_game();await frames();app=frontend.active
 if app.tutorial_ui!=null:app.tutorial_ui.finish()
 app.set_process(false);clear_lines();app.paused_manual=true;app.home.enabled=false;app.family.enabled=false;app.unlock_combat();no_actors();app.unlock_street();app.enter_room("street_twisted");no_street()
 var a:Dictionary=place("pharmacist",Vector2(4,4));a.hp=60;a.portions=2;a.cooldown=0;a.direction=[1,0];app.street.data.erase("pharmacist_splash")
 app.rules.hp=100;app.rules.sp=80;app.rules.hurt_left=0;app.rules.stun_left=0;app.hero_pos=Vector2(5.75,4);app.hero_facing=Vector2.RIGHT
 check(takeover(),"first declared pharmacist/host/full cup fixture uses actual paid CONTROL, no injected liquid/hit state")
 app.input_lock_frames=0;app.paused_manual=false;app.set_process(true)
 check(await wait_until(func():return a.phase=="windup" and a.elapsed>=.3,1),"ordinary autonomous cup action produces visible original preparation")
 await click_point(Vector2(846,58));var clock:float=app.street.data.clock;var elapsed:float=a.elapsed;await frames(8)
 check(app.menu.visible and is_equal_approx(clock,float(app.street.data.clock)) and is_equal_approx(elapsed,float(a.elapsed)) and a.portions==2 and splash_sounds()==0,"actual header book button freezes the unfinished cup and cannot consume or sound a release")
 await capture("01_actual_menu_freezes_cup");await tap_key(KEY_ESCAPE)
 check(await wait_until(func():return not app.menu.visible and a.phase=="windup" and a.elapsed>=.7,2),"actual Escape closes book and original preparation resumes")
 await space_key();await capture("02_cup_direction_before_release");await space_key()
 check(await wait_until(func():return not app.street.splash.state().shots.is_empty(),1),"ordinary cup tip releases one visible local liquid packet")
 check(await wait_until(func():return not app.street.splash.state().shots.is_empty() and float(app.street.splash.state().shots[0].age)>=.1,.3),"actual liquid travels clear of the hand before the captured mid-flight pause")
 await space_key();var shot:Dictionary=app.street.splash.state().shots[0];var age:float=shot.age;await frames(10)
 check(app.paused_manual and is_equal_approx(age,float(shot.age)) and a.portions==1 and app.rules.sp==80,"real Space freezes airborne liquid before distant contact and preserves one consumed portion")
 check(splash_sounds()==1,"actual release starts one registered world-channel splash sound, not a provisional tone or looping ground effect")
 check(app.audio.world_frozen,"actual world pause also freezes the splash sound channel")
 var initial_zoom:int=app.zoom_index
 await capture("03_actual_local_liquid_paused");await space_key();await pointer_key(MOUSE_BUTTON_WHEEL_UP)
 check(app.zoom_index>initial_zoom,"actual running-time wheel uses an existing enlarged camera step")
 await space_key();await capture("04_actual_liquid_zoomed");await space_key()
 check(await wait_until(func():return app.rules.sp==70,1),"ordinary physical liquid contact commits one original ten-SP effect")
 check(app.rules.hp==100 and app.rules.stun_left==0 and not app.rules.gripped,"splash adds no HP damage, oral medicine pause or physical holder")
 await capture("05_actual_ground_drops_only");await pointer_key(MOUSE_BUTTON_WHEEL_DOWN)
 check(app.zoom_index==initial_zoom,"actual wheel restores the original view without changing liquid collision size")
 check(await wait_until(func():return app.street.splash.state().shots.is_empty(),2),"ordinary world clock fades harmless local drops without leaving a damage region")
 check(app.rules.sp==70 and a.portions==1 and splash_sounds()==1,"same settled liquid and its sound cannot replay after the ground fade")

 # Independent second scene: keep prior results, explicitly reset HP/SP and cast.
 app.set_process(false);app.paused_manual=true;clear_lines();app.enter_room("street_plaza");no_street()
 var father:Dictionary=place("father",Vector2(4,4));father.hp=80;father.cooldown=0;father.direction=[1,0];app.street.data.erase("father_bottle")
 var dog:Dictionary=place("dog",Vector2(4.5,4.1));dog.hp=60
 app.rules.hp=100;app.rules.sp=80;app.rules.hurt_left=0;app.rules.stun_left=0;app.hero_pos=Vector2(5,4);app.hero_facing=Vector2.RIGHT
 check(takeover(),"independent father/dog scene explicitly resets HP/SP and pays another real CONTROL, without filling death, gain or weapon-contact fields")
 app.input_lock_frames=0;app.paused_manual=false;app.set_process(true)
 check(await wait_until(func():return dog.hp<=0,2),"autonomous fixed-direction broken glass actually hits the guarding dog before source-specific fragmentation")
 await space_key();clock=app.street.data.clock;await frames(8)
 check(app.paused_manual and is_equal_approx(clock,float(app.street.data.clock)) and app.street.data.speed_stacks==1 and app.street.data.speed_deaths.dog.source=="father" and father.hits.has("dog"),"real pause preserves actual bottle contact, one qualified death and its original physical gain")
 await capture("06_actual_bottle_dog_contact_paused");await space_key()
 check(await wait_until(func():return father.phase=="recover",1),"same attached glass completes original local sweep then retracts")
 await capture("07_same_attached_glass_recovery")
 check(app.street.bottle.state().owner=="father" and app.street.data.speed_stacks==1,"one attached bottle and one real corpse cannot duplicate the existing layer")
 var file:=FileAccess.open(ProjectSettings.globalize_path(folder).path_join("result.json"),FileAccess.WRITE)
 file.store_string(JSON.stringify({"passes":passes,"failures":failures,"rendered":DisplayServer.get_name()!="headless","scope":"Two declared NPC/position scenes, second explicitly resets HP/SP, actual paid CONTROL each. Ordinary cup telegraph/local fluid/travel/SP-only hit/ground fade/one registered sound, real header book click/Escape/Space/running wheel; then actual fixed bottle/guarding dog contact/death/recovery. No packet/hit/death/gain/knowledge fields filled. Silent fixed30 capture, not audio listening, natural crowd, final art or manual full-game acceptance."},"  "));file.close()
 print("STREET_SPLASH_LIVE_CHECK %d passed %d failed"%[passes.size(),failures.size()]);app.audio.reset_scene();frontend.request_exit(0 if failures.is_empty() else 1)
