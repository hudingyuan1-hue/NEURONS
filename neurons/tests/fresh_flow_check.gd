extends Node
## A normal new profile, unmodified production RNG and actors. Only tutorial
## skip and optional paid CRT input are submitted; dialogue advances itself.
var frontend
var app
var folder:String="res://../docs/validation/corrections_20261016/fresh"
var timeline:Array=[]
var failures:Array=[]
var passes:Array=[]
var interfere:bool=false
var submitted:bool=false
var started:int=0
var last:String=""

func frames(n:int=1) -> void:
 for i in range(n):await get_tree().process_frame

func button(root:Node,needle:String) -> Button:
 for child in root.get_children():
  if child is Button and child.is_visible_in_tree() and child.text.contains(needle):return child
  var found:Button=button(child,needle)
  if found!=null:return found
 return null

func click(b:Button) -> void:
 if b==null:failures.append("missing requested visible button");return
 var pos:Vector2=b.get_global_rect().get_center()
 for down in [true,false]:
  var e:=InputEventMouseButton.new();e.position=pos;e.global_position=pos;e.button_index=MOUSE_BUTTON_LEFT;e.pressed=down
  Input.parse_input_event(e);await frames(2)

func key(code:Key) -> void:
 for down in [true,false]:
  var e:=InputEventKey.new();e.keycode=code;e.physical_keycode=code;e.pressed=down
  Input.parse_input_event(e);await frames(2)

func write_json(name:String,value) -> void:
 var out:=FileAccess.open(ProjectSettings.globalize_path(folder).path_join(name),FileAccess.WRITE)
 out.store_string(JSON.stringify(value,"  "));out.close()

func capture(name:String) -> void:
 await frames(2)
 RenderingServer.force_draw(false)
 get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(folder).path_join(name+".png"))

func _ready() -> void:
 name="CampaignCheck"
 frontend=get_parent()
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--validation-root="):folder=arg.trim_prefix("--validation-root=")
 interfere="--observe-interference" in OS.get_cmdline_user_args()
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 await frames(3);await click(button(frontend,"建立档案"));await frames(3)
 frontend.name_field.text="自然流程观察"
 await click(button(frontend,"建立并开始"));await frames(5);app=frontend.active
 if app==null:frontend.request_exit(1);return
 if app.tutorial_ui!=null:await click(button(app.tutorial_ui,"跳过"))
 await frames(5);started=Engine.get_process_frames()
 write_json("initial_snapshot.json",app.snapshot_data());await capture("01_new_profile")
 var initial_time:float=app.rules.world_time
 var observed_attempts:Dictionary={}
 var had_dialogue:bool=false
 var had_search:bool=false
 for i in range(18000):
  if app==null:break
  var attempt:int=app.rules.actual_attempt
  if i%1800==0:print("FRESH_FLOW frame=%d attempt=%d world=%.2f"%[i,attempt,app.rules.world_time])
  var state:String=JSON.stringify([app.session.data.level,attempt,app.room_id,app.action_phase,app.hero_state,app.rules.search_count,app.session.data.key_owner,app.hidden_route.data.get("status","")])
  if state!=last:
   timeline.append({"frame":Engine.get_process_frames()-started,"world_time":app.rules.world_time,"level":app.session.data.level,"attempt":attempt,"room":app.room_id,"phase":app.action_phase,"pose":app.hero_state,"completed":app.rules.search_count,"owner":app.session.data.key_owner,"hp":app.rules.hp,"sp":app.rules.sp})
   last=state
  if not observed_attempts.has(str(attempt)):
   observed_attempts[str(attempt)]=true;await capture("attempt_%d"%attempt)
  had_search=had_search or app.rules.search_active
  if not app.dialogue_queue.is_empty():
   if not had_dialogue:await capture("02_automatic_dialogue")
   had_dialogue=true
   for line in app.dialogue_queue:
    if str(line.speaker).begins_with("玩家") and str(line.text)=="可算找着了。":failures.append("opposing-player correction missing")
  if interfere and not submitted and app.rules.search_active and app.rules.search_elapsed>0.8 and not app.world_paused():
   await key(KEY_TAB);await frames(8)
   if app.menu.visible:
    await click(app.menu.nodes.SKIN);submitted=true
    await capture("03_paid_CRT_input")
  if int(app.session.data.level)>1 or attempt>=3 or bool(app.hidden_route.data.get("ending",{}).get("complete",false)):break
  await frames()
 if not had_search:failures.append("no actual autonomous search observed")
 if not had_dialogue:failures.append("no automatically displayed dialogue observed")
 if app.rules.world_time<=initial_time:failures.append("world never resumed")
 if int(app.session.data.level)==1 and app.rules.actual_attempt<3 and not bool(app.hidden_route.data.get("ending",{}).get("complete",false)):failures.append("normal flow did not reach a bounded milestone within 600 simulated seconds")
 if interfere and not submitted:failures.append("no real paid CRT input opportunity completed")
 if failures.is_empty():passes=["normal new profile reaches real retry/exit/ending milestone","autonomous physical search and automatic readable dialogue observed","opposing-player correction remains active"]
 write_json("final_snapshot.json",app.snapshot_data());await capture("04_final_milestone")
 write_json("result.json",{"passes":passes,"failures":failures,"timeline":timeline,"frames":Engine.get_process_frames()-started,"interference_input":submitted,"fixtures":"No gameplay seed/actor/item/resource/route overrides. Test entry bypasses startup cinematic; normal profile creation and tutorial Skip are clicked. Default automatic dialogue; optional one actual paid CRT click. Fixed timestep accelerates real wall time; this is not human pacing or an audio audition.","milestone":{"level":app.session.data.level,"attempt":app.rules.actual_attempt,"ending":app.hidden_route.data.get("ending",{})},"rendered":true})
 print("FRESH_FLOW_CHECK %d passed %d failed"%[passes.size(),failures.size()]);frontend.request_exit(0 if failures.is_empty() else 1)

