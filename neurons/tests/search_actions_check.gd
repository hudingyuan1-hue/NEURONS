extends Node
const Neural=preload("res://scripts/core/neural_rules.gd")
var frontend
var app
var passes:Array=[]
var failures:Array=[]
var folder:String="res://../docs/validation/b1_20261015/search_actions"

func check(value:bool,label:String) -> void:
 (passes if value else failures).append(label)
 print(("PASS " if value else "FAIL ")+label)

func frames(count:int=3) -> void:
 for i in range(count):await get_tree().process_frame

func step(delta:float=0.025) -> void:
 if not app.dialogue_queue.is_empty():app.advance_dialogue();return
 app.advance_world(delta)

func until(predicate:Callable,steps:int=1000) -> bool:
 for i in range(steps):
  if predicate.call():return true
  step()
 return predicate.call()

func fixture(index:int) -> void:
 app.rules=Neural.new();app.menu.rules=app.rules
 app.rules.owners.key="bedroom:9";app.session.data.level=1
 app.session.new_attempt(1,app.rng)
 app.session.data.targets=[]
 for i in range(11):
  if i!=(10 if index!=10 else 9):app.session.data.targets.append("bedroom:%d"%i)
 app.session.data.key_target="bedroom:9" if index!=9 else "bedroom:0"
 app.session.data.key_owner=app.session.data.key_target;app.rules.owners.key=app.session.data.key_owner
 app.home.enabled=false;app.family.enabled=false
 app.completed.clear();app.search_actions.states.clear();app.search_actions.receipts.clear()
 app.deferred_targets.clear();app.motion.clear();app.enter_room("bedroom")
 app.hero_pos=app.layout.furniture[index].at
 app.paused_manual=true;app.dialogue_queue.clear();app.show_dialogue()
 app.first_damage_pending=false;app.menu.close_menu();app.closing_left=0

func capture(name:String) -> void:
 await frames();await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(folder).path_join(name+".png"))

func _ready() -> void:
 name="CampaignCheck";frontend=get_parent()
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 await frames();frontend.show_profile();await frames()
 frontend.name_field.text="11点动作验证";frontend.overwrite_armed=true;frontend.new_game();await frames();app=frontend.active
 if app.tutorial_ui!=null:app.tutorial_ui.finish() # Exercises skip; full practice has its own suite.
 for index in range(11):
  fixture(index)
  check(until(func():return app.rules.search_active and app.target_index==index),"actual legal search begins: "+str(index))
  var id:String=app.layout.furniture[index].id
  check(until(func():return app.rules.search_elapsed>=app.rules.search_duration*0.81),"staged contact reaches late action: "+id)
  await capture("point_%02d_%s"%[index,id])
  check(until(func():return app.rules.search_count==1),"point completes one real search: "+id)
  check(app.rules.neurons==6 and app.rules.search_attempts==1,"all sub-actions share one opportunity and one reward: "+id)
  var count:int=0
  for receipt in app.search_actions.receipts:
   if str(receipt).begins_with(app.rules._search_id+":"):count+=1
  check(count==app.search_actions.point(id).steps.size(),"each physical sub-action recorded once: "+id)
 fixture(2)
 until(func():return app.search_actions.state("chair").has("shift"))
 check(app.layout.furniture[2].rect.position!=Vector2(0.98,2.14),"moved chair uses actual changed footprint")
 check(app.layout.walkable(app.hero_pos),"chair movement does not move collider into contact actor")
 var before:Dictionary=app.snapshot_data()
 var chair_rect:Rect2=app.layout.furniture[2].rect
 app.rules.submit_skin();app.apply_cast()
 check(app.layout.furniture[2].rect==chair_rect and app.rules.neurons==4,"interruption retains moved chair and gives no search reward")
 check(app.restore_snapshot(before) and app.layout.furniture[2].rect==chair_rect,"load restores actual moved footprint instead of visual-only offset")
 fixture(5)
 until(func():return app.search_actions.state("box").has("upper_shift"))
 check(app.layout.movable_blockers.size()==1,"upper box has separate real collision after placement")
 for f in app.layout.furniture:
  check(app.layout.walkable(f.at) and not app.layout.path(app.layout.BED_STOP,f.at).is_empty(),"after box placement every original contact point remains reachable: "+f.id)
 await capture("moved_box_foreground")
 fixture(1)
 until(func():return app.search_actions.state("bedside").has("clock_shift"))
 app.rules.submit_skin();app.apply_cast()
 check(app.search_actions.state("bedside").has("book_shift") and app.search_actions.state("bedside").has("clock_shift") and app.rules.search_count==0,"pre-drawer interruption retains independent book/clock displacement without reward")
 fixture(6)
 until(func():return app.action_phase=="observe_cuff")
 check("coat_seen" in app.rules.known and not "cuff_seam" in app.rules.known,"pocket search does not automatically reveal cuff seam")
 app.rules.submit_skin();app.apply_cast()
 check(app.action_phase!="observe_cuff" and not "cuff_seam" in app.rules.known,"cancelled sleeve observation cannot issue knowledge afterwards")
 fixture(6)
 until(func():return "cuff_seam" in app.rules.known)
 check("cuff_seam" in app.rules.known and app.rules.search_attempts==1 and app.rules.neurons==6,"completed subsidiary cuff observation gives knowledge, not extra search income")
 fixture(9)
 until(func():return "uniform_blood" in app.rules.known)
 check(not "uniform_damaged_label" in app.rules.known,"seeing bloody corner does not imply reading label")
 until(func():return "uniform_damaged_label" in app.rules.known)
 check(not "uniform_label_fragment" in app.rules.known,"missing source label art never invents readable digits")
 var f:=FileAccess.open(ProjectSettings.globalize_path(folder).path_join("result.json"),FileAccess.WRITE)
 f.store_string(JSON.stringify({"passes":passes,"failures":failures,"rendered":true,"scope":"11-point action/collision/knowledge fixtures in formal entry; graybox poses; exact uniform label still missing"},"  "))
 print("SEARCH_ACTIONS_CHECK %d passed %d failed"%[passes.size(),failures.size()])
 get_tree().quit(0 if failures.is_empty() else 1)
