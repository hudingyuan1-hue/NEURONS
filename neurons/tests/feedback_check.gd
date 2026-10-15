extends "res://tests/family_check.gd"
## Fixed household states for rules; the live prompt/CRT segment uses viewport
## mouse input and ordinary world processing. No formal-art/audio claim.

func food(kind:String) -> String:
 var id:String=app.family.ensure_food(kind,"hero")
 app.family.data.inventory.append(id)
 return id

func click(target:BaseButton) -> void:
 var point:Vector2=target.get_global_rect().get_center()
 var move:=InputEventMouseMotion.new();move.position=point;move.global_position=point;Input.parse_input_event(move)
 await frames(2)
 for down in [true,false]:
  var event:=InputEventMouseButton.new();event.position=point;event.global_position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down
  Input.parse_input_event(event);await frames(2)

func _ready() -> void:
 folder="res://../docs/validation/feedback_20261015"
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--validation-root="):folder=argument.trim_prefix("--validation-root=")
 name="CampaignCheck";frontend=get_parent()
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 await frames();frontend.show_profile();await frames();frontend.name_field.text="食用与救援反馈验证"
 frontend.overwrite_armed=true;frontend.new_game();await frames();app=frontend.active
 if app.tutorial_ui!=null:app.tutorial_ui.finish()

 fixture();app.rules.sp=60
 var item:String=food("candy")
 check(app.family.request_food("candy"),"owned candy starts real timed eating")
 step(0.2)
 check(app.hero_state=="eat" and app.view.eating_pose().stage=="准备","visible preparation is tied to saved eating elapsed time")
 step(0.6)
 check(app.view.eating_pose().stage=="入口" and app.rules.owners[item]=="hero" and app.rules.sp==60,"mouth contact is visible without consuming early or healing")
 await capture("01_eating_contact")
 var saved:Dictionary=app.snapshot_data()
 check(app.store.save_snapshot(saved).ok,"mid-eating writes actual JSON save")
 var disk:Dictionary=app.store.load_snapshot()
 check(disk.ok and app.restore_snapshot(disk.data) and is_equal_approx(float(app.family.data.eating.elapsed),0.8),"JSON reload resumes mouth-contact phase without replay or restart")
 var world:float=app.rules.world_time
 var elapsed:float=app.family.data.eating.elapsed
 await frames(20)
 check(app.rules.world_time==world and app.family.data.eating.elapsed==elapsed,"manual pause freezes eating, gesture and completion")
 step(0.69)
 check(app.rules.sp==60 and app.family.data.food_feedback.is_empty() if app.family.data.has("food_feedback") else app.rules.sp==60,"no taste/completion result before full 1.5 seconds")
 step(0.01)
 check(app.rules.sp==80 and app.rules.neurons==10 and app.rules.owners[item]=="consumed","full 1.5 seconds consumes candy and grants exact original reward")
 check(app.dialogue_queue.size()==1 and app.dialogue_queue[0].text in ["...","?","嘶..."],"only a surviving real completion queues an original taste alternative")
 var rng_before:int=app.rng.state
 check(not app.family.request_food("candy") and app.rng.state==rng_before,"consumed food cannot reward, reroll or replay feedback")
 await capture("02_taste_after_consumption")

 fixture();app.rules.sp=60;item=food("candy");give_skill("DRYMOUTH");cast("DRYMOUTH")
 clear_lines();var neurons:int=app.rules.neurons
 check(app.family.request_food("candy"),"DRYMOUTH does not invent an eating prohibition")
 app.family.advance_eating(1.499)
 check(app.rules.owners[item]=="hero" and app.rules.neurons==neurons,"DRYMOUTH still cannot consume before original 1.5 seconds")
 app.family.advance_eating(0.001)
 check(app.rules.sp==80 and app.rules.neurons==neurons+5 and app.rules.owners[item]=="consumed","DRYMOUTH does not extend eating or change its resource effect")

 fixture(false,true);app.family.spawn("father")
 check(until(func():return app.family.data.father.phase=="think"),"father actually holds cat before thought guidance")
 check(app.family.data.system_prompts.has("FATHER_THINK") and not app.family.data.system_prompts.has("FATHER_LOW_SP"),"first two original hints occur in thought; low-SP hint is absent early")
 var count:int=app.dialogue_queue.size();rng_before=app.rng.state
 app.family.system_prompt("FATHER_THINK")
 check(app.dialogue_queue.size()==count and app.rng.state==rng_before,"same thought prompt cannot replay or consume RNG")
 saved=app.snapshot_data();app.store.save_snapshot(saved);disk=app.store.load_snapshot();app.restore_snapshot(disk.data)
 count=app.dialogue_queue.size();app.family.system_prompt("FATHER_THINK")
 check(app.dialogue_queue.size()==count,"JSON load preserves already-queued thought prompt receipt")
 clear_lines();app.family.data.erase("system_prompts")
 saved=app.snapshot_data();app.store.save_snapshot(saved);disk=app.store.load_snapshot();app.restore_snapshot(disk.data)
 var pressure:float=app.family.data.pressure
 app.advance_world(0.025)
 check(app.family.data.system_prompts.has("FATHER_THINK") and app.dialogue_queue.size()==1 and app.family.data.pressure==pressure,"old in-progress thought save receives missing hint before renewed pressure")
 count=app.dialogue_queue.size();app.family.system_prompt("FATHER_THINK")
 check(app.dialogue_queue.size()==count,"migrated hint receipt prevents a second presentation")
 clear_lines();app.rules.sp=80;app.family.data.pressure=0
 item=food("candy");app.family.request_food("candy")
 step(1.0)
 check(app.rules.sp==79 and is_equal_approx(float(app.family.data.eating.elapsed),1.0),"father pressure advances concurrently during actual eating")
 step(0.5)
 check(app.rules.sp==99 and app.rules.owners[item]=="consumed" and app.family.data.father.phase=="think","eating completion preserves pressure already lost instead of granting a free pause")

 fixture();app.hero_pos=Vector2(2.9,2.3);app.family.spawn("father")
 until(func():return app.family.data.father.phase=="grab")
 clear_lines();app.family.data.father.elapsed=0.3;item=food("candy")
 neurons=app.rules.neurons;var hp:int=app.rules.hp
 check(app.family.request_food("candy"),"eating is legal during uncompleted grab windup")
 step(0.4);step(0.4)
 check(app.rules.gripped and app.family.data.eating.is_empty(),"father continues actual grab and interrupts swallowing")
 check(app.rules.owners[item]=="hero" and app.rules.neurons==neurons and app.rules.hp==hp and not app.family.data.has("food_feedback"),"grab interruption retains item and grants neither healing, income nor taste feedback")
 await capture("03_grab_interrupts_eating")

 fixture(false,true);app.family.spawn("father");until(func():return app.family.data.father.phase=="think")
 clear_lines();app.rules.sp=60;app.family.data.pressure=0
 step(0.99)
 check(app.family.data.father.phase=="think" and not app.family.data.system_prompts.has("FATHER_LOW_SP"),"exactly sixty SP does not prematurely show forced-follow hint")
 step(0.01)
 check(app.rules.sp==59 and app.family.data.father.phase=="approach" and app.family.data.father.forced_low_sp and app.family.data.system_prompts.has("FATHER_LOW_SP"),"actual threshold crossing commits forced-follow branch and third original hint")
 clear_lines();item=food("candy");app.family.request_food("candy")
 step(1.0);step(0.5)
 check(app.rules.sp>60 and app.family.data.father.phase!="think","food recovery cannot roll back already-entered abduction")
 check(not "当角色精神值低于60时会强制跟随父亲”出门”~哟~" in app.family.prompt_info().lines,"live low-SP warning disappears when its current numeric condition no longer holds")

 fixture();app.hero_pos=Vector2(2.9,2.3);app.family.spawn("father")
 until(func():return app.rules.gripped);clear_lines();give_skill("KNEE");give_skill("STARTLE")
 app.rules.neurons=0;app.paused_manual=false;get_window().grab_focus();await frames(3)
 check(app.father_prompt.visible and app.father_prompt.buttons.KNEE.disabled and app.father_prompt.buttons.STARTLE.disabled,"live rescue card never lights unaffordable skills")
 check(not app.father_prompt.buttons.JOY.visible,"rescue hint does not gift a locked node")
 app.rules.neurons=50;app.rules.skill_states.KNEE.resistance=int(app.rules.skill_states.KNEE.power)
 await frames(2)
 check(not app.father_prompt.buttons.KNEE.disabled,"eligible paid attempt remains available even when resistance may defeat it")
 await capture("04_live_rescue_card")
 neurons=app.rules.neurons
 await click(app.father_prompt.buttons.KNEE)
 check(app.menu.visible and app.menu.selected_id=="KNEE" and app.rules.neurons==neurons,"hint button focuses existing CRT without submitting or charging")
 await click(app.menu.nodes.KNEE)
 for i in range(60):
  if app.rules.neurons<neurons and app.rules.pending_neural.is_empty() and app.closing_left<=0:break
  await frames(1)
 app.paused_manual=true
 check(app.rules.neurons==neurons-int(app.rules.spec("KNEE").cost) and app.rules.gripped,"real CRT resisted rescue pays once and cannot free the established grip")
 check(float(app.rules.skill_states.KNEE.until)>app.rules.world_time,"resisted rescue keeps its configured cooldown")
 await capture("05_resisted_rescue")

 # Bounded UI-only key demonstration on a read-only status fixture.
 app.vitality_panel.restore({"manual":true,"hint_acknowledged":false})
 app.vitality_panel.hint_demo_seen=false;app.reduced_effects=false
 world=app.rules.world_time;neurons=app.rules.neurons
 await frames(17)
 check(app.vitality_panel.hint_demo_running and app.vitality_panel.keycap.position.y>1,"X keycap visibly presses while the world is paused")
 await capture("06_keycap_press")
 await frames(105)
 check(not app.vitality_panel.hint_demo_running and app.vitality_panel.keycap.position==Vector2(1,1),"X demo stops after its bounded three cycles")
 check(app.rules.world_time==world and app.rules.neurons==neurons,"UI hint animation changes neither world clock nor resources")
 saved=app.snapshot_data();app.store.save_snapshot(saved);disk=app.store.load_snapshot();app.restore_snapshot(disk.data)
 await frames(3)
 check(app.vitality_panel.hint_demo_seen and not app.vitality_panel.hint_demo_running,"JSON load does not repeat the already-demonstrated first-injury key animation")
 app.reduced_effects=true;app.vitality_panel.hint_demo_seen=false
 await frames(20)
 check(not app.vitality_panel.hint_demo_running and app.vitality_panel.keycap.position==Vector2(1,1),"reduced feedback shows a static keyboard guide")

 var output:=FileAccess.open(ProjectSettings.globalize_path(folder).path_join("result.json"),FileAccess.WRITE)
 output.store_string(JSON.stringify({"passes":passes,"failures":failures,"rendered":true,"scope":"fixed household/timing fixtures; actual food/pressure/grab/threshold handlers, JSON restore, live prompt/CRT mouse input and bounded UI demo; not full B1 or subjective audio acceptance"},"  "));output.close()
 print("FEEDBACK_CHECK %d passed %d failed"%[passes.size(),failures.size()])
 frontend.request_exit(0 if failures.is_empty() else 1)
