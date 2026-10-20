extends "res://tests/street_pacing_measure_20261019.gd"
## Real-input comparison against an untouched actual checkpoint. Fixed inputs:
## use existing SKIN north three times, attempt one early cooldown repeat.
## No direct cast/unlock/route/state writes; all fees and motion use the UI.
var input_run_started:bool=false
var input_recipe:String="skin"

func _ready() -> void:
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--pacing-input-recipe="):input_recipe=argument.trim_prefix("--pacing-input-recipe=")
 call_deferred("run_inputs")
 await super._ready()

func input_state() -> Dictionary:
 var value:Dictionary=state()
 value.menu_visible=app.menu.visible
 value.menu_page=app.menu.panel_mode
 value.menu_status=app.menu._status.text
 value.status_note=app.status_note
 value.cooldown_remaining_s=maxf(0,app.rules.cooldown_until-app.rules.world_time)
 value.skin_unlocked=app.rules.skill_states.SKIN.unlocked
 value.skin_power=app.rules.skill_states.SKIN.power
 value.skin_resistance=app.rules.skill_states.SKIN.resistance
 value.pending=app.rules.pending_neural.duplicate(true)
 return value

func log_input(label:String,details:Dictionary={}) -> void:
 var record:Dictionary={"label":label,"state":input_state(),"details":details}
 recorded_inputs.append(record);write_json("recorded_inputs.json",recorded_inputs)
 print("PACING_INPUT ",label," world=",app.rules.world_time," hp=",app.rules.hp," neurons=",app.rules.neurons)

func key_tap(code:Key) -> void:
 var event:=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=true
 Input.parse_input_event(event);await frames(2)
 event=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=false
 Input.parse_input_event(event);await frames(3)

func use_skin(label:String) -> bool:
 var before:Dictionary=input_state()
 log_input(label+":before_tab",{"actual_key":"Tab","direction":"north / up"})
 await key_tap(KEY_TAB)
 if not app.menu.visible:
  log_input(label+":menu_did_not_open");return false
 await click(app.menu.nodes.SKIN)
 if not app.menu.direction_panel.visible:
  log_input(label+":direction_did_not_open")
  await key_tap(KEY_ESCAPE);return false
 if label=="first":await capture("input_01_actual_direction_menu")
 await click(button(app.menu.direction_panel,"↑"))
 await frames(10)
 if app.menu.visible:
  log_input(label+":ui_denied",{"neurons_before":before.neurons,"neurons_after":app.rules.neurons,"displayed_reason":app.menu._status.text})
  await capture("input_"+label+"_denied")
  await key_tap(KEY_ESCAPE);await frames(8)
  return false
 await wait_for(func():return app.closing_left<=0 and app.rules.pending_neural.is_empty(),3.0)
 await frames(10)
 log_input(label+":after_actual_resolution",{"neurons_before":before.neurons,"neurons_after":app.rules.neurons,"pos_before_m":before.pos_m,"real_input":"Tab, mouse SKIN, mouse north direction"})
 await capture("input_"+label+"_resolved")
 return int(app.rules.neurons)<int(before.neurons)

func run_inputs() -> void:
 while not observing:await get_tree().process_frame
 if input_run_started:return
 input_run_started=true
 if input_recipe=="startle":await run_startle_inputs();return
 write_json("input_recipe.json",{"entry":"Unchanged checkpoint passed via --pacing-replay-snapshot", "initial_skill":"SKIN already unlocked in source save, no purchases", "planned_actions":["At Street exit x>=2m, Tab→existing SKIN→north", "Immediately try same input while on cooldown, retain actual refusal and no-fee result", "After legitimate cooldown, repeat north twice if body/HP/end state allows"],"reason":"Upper-row enemies are already visible in the scene. Test whether real paid directional interference changes exposure and escape time; do not force host death.","prohibited_writes":"No direct RNG, resources, skill, NPC, route, position, damage, completion or game ticking writes."})
 while observing and not (app.room_id=="street_end" and app.hero_pos.x>=2.0 and not app.world_paused()):
  await get_tree().process_frame
 if not observing:return
 log_input("input_schedule_started")
 await capture("input_00_before_intervention")
 var first:bool=await use_skin("first")
 if first and observing and app.rules.hp>0 and app.street.data.ending.is_empty():await use_skin("cooldown_repeat")
 for label:String in ["second","third"]:
  var waited:float=0.0
  while observing and app.rules.hp>0 and app.street.data.ending.is_empty():
   var context:Dictionary={"direction":[0.0,-1.0]}
   if not app.world_paused() and app.rules.availability("SKIN",context).is_empty():break
   await get_tree().process_frame;waited+=get_process_delta_time()
   if waited>15.0:break
  if not observing or app.rules.hp<=0 or not app.street.data.ending.is_empty():break
  await use_skin(label)
 log_input("input_schedule_finished")

func purchase(id:String) -> bool:
 var before:int=app.rules.plexus
 await click(app.menu.tree_nodes[id]);await frames(8)
 await click(button(app.menu.inspect_panel,"确认解锁"));await frames(10)
 log_input("purchase:"+id,{"clusters_before":before,"clusters_after":app.rules.plexus,"real_input":"star cabinet node, confirm unlock"})
 return bool(app.rules.skill_states[id].unlocked)

func use_startle(label:String) -> bool:
 var ready_wait:float=0.0
 while observing and (app.input_lock_frames>0 or app.world_paused()) and ready_wait<3.0:
  await get_tree().process_frame;ready_wait+=get_process_delta_time()
 var before:Dictionary=input_state()
 await key_tap(KEY_TAB)
 if not app.menu.visible:log_input(label+":menu_did_not_open");return false
 await click(app.menu.nodes.STARTLE);await frames(10)
 if app.menu.visible:
  log_input(label+":ui_denied",{"displayed_reason":app.menu._status.text})
  await key_tap(KEY_ESCAPE);await frames(8);return false
 await wait_for(func():return app.closing_left<=0 and app.rules.pending_neural.is_empty(),3.0)
 await frames(13)
 log_input(label+":after_actual_resolution",{"neurons_before":before.neurons,"neurons_after":app.rules.neurons,"pos_before_m":before.pos_m,"real_input":"Tab, existing unlocked STARTLE node"})
 await capture("input_"+label+"_resolved")
 return int(app.rules.neurons)<int(before.neurons)

func run_startle_inputs() -> void:
 write_json("input_recipe.json",{"entry":"Unchanged actual exit baseline checkpoint", "purchases":"Actual star-cabinet mouse node and confirm: TEMP1 cluster then STARTLE2 clusters; no free unlocks or resources", "planned_actions":["At x>=2m, real star-cabinet purchases", "Close normally, allow existing automatic growth dialogue", "Real Tab/STARTLE twice separated by original cooldown"],"reason":"Bounded existing backward intervention, not a new mechanic or forced death.","prohibited_writes":"No direct RNG, resources, skill, NPC, route, position, damage, completion or game ticking writes."})
 while observing and not (app.room_id=="street_end" and app.hero_pos.x>=2.0 and not app.world_paused()):await get_tree().process_frame
 if not observing:return
 log_input("startle_purchase_begin")
 await click(button(app,"星仓"))
 if not app.menu.visible or app.menu.panel_mode!="tree":log_input("star_cabinet_did_not_open");return
 if not await purchase("TEMP"):await key_tap(KEY_ESCAPE);return
 if not await purchase("STARTLE"):await key_tap(KEY_ESCAPE);return
 await capture("input_00_real_paid_unlocks")
 await key_tap(KEY_ESCAPE)
 var waited:float=0.0
 while observing and app.world_paused() and waited<20:
  await get_tree().process_frame;waited+=get_process_delta_time()
 log_input("purchases_closed_and_original_dialogue_completed")
 for label:String in ["startle_first","startle_second"]:
  waited=0.0
  while observing and app.rules.hp>0 and app.street.data.ending.is_empty():
   if not app.world_paused() and app.rules.availability("STARTLE",{}).is_empty():break
   await get_tree().process_frame;waited+=get_process_delta_time()
   if waited>15:break
  if not observing or app.rules.hp<=0 or not app.street.data.ending.is_empty():break
  await use_startle(label)
 log_input("input_schedule_finished")
