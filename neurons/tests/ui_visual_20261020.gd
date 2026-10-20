extends Node
## Isolated real controls, native pointer input and GPU captures. No formal play acceptance.
var frontend
var app
var passes:Array=[]
var failures:Array=[]
var folder:String="res://../docs/validation/asset_production_20261020/ui"
func check(value:bool,label:String) -> void:
 (passes if value else failures).append(label)
 print(("PASS " if value else "FAIL ")+label)
func frames(n:int=3) -> void:
 for i in range(n):await get_tree().process_frame
func button(root:Node,text:String) -> Button:
 for child in root.get_children():
  if child is Button and not child is CheckBox and child.is_visible_in_tree() and child.text.begins_with(text):return child
  var found:Button=button(child,text)
  if found!=null:return found
 return null
func click_at(point:Vector2) -> void:
 var move:=InputEventMouseMotion.new();move.position=point;move.global_position=point
 Input.parse_input_event(move);await frames(2)
 var hovered:Control=get_viewport().gui_get_hovered_control()
 print("POINTER ",point," -> ",hovered.get_path() if hovered!=null else "none")
 for pressed in [true,false]:
  var e:=InputEventMouseButton.new();e.position=point;e.global_position=point;e.button_index=MOUSE_BUTTON_LEFT;e.pressed=pressed
  Input.parse_input_event(e);await frames(2)
func click(target:Button) -> void:
 if target==null:check(false,"missing actual control");return
 print("CLICK ",target.text," ",target.get_global_rect())
 await click_at(target.get_global_rect().get_center())
func capture(label:String) -> void:
 await frames(3);await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(folder).path_join(label+".png"))
func key(code:Key) -> void:
 for pressed in [true,false]:
  var event:=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=pressed
  Input.parse_input_event(event);await frames(2)
func _ready() -> void:
 name="CampaignCheck";frontend=get_parent()
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 await frames(8)
 check(button(frontend,"建立档案")!=null,"title exposes actual profile control")
 await capture("01_title")
 await click(button(frontend,"建立档案"));await frames()
 frontend.name_field.text=""
 await click(button(frontend,"建立并开始"))
 check(frontend.active==null and frontend.message.text.contains("请输入"),"empty player name remains rejected")
 frontend.name_field.text="纸张界面隔离验证"
 await capture("02_profile")
 await click(button(frontend,"返回"));await frames()
 await click(button(frontend,"设置"));await frames()
 var volume:float=frontend.volume_slider.value
 await click_at(frontend.volume_slider.get_global_rect().position+Vector2(125,frontend.volume_slider.size.y*.5))
 check(frontend.volume_slider.value!=volume,"title volume is a real editable slider")
 await capture("03_title_settings")
 await click(button(frontend,"返回"));await frames()
 frontend.launch({"name":"纸张界面隔离验证","invader_id":8401,"opening_completed":true,"tutorial_completed":true},{})
 app=frontend.active;await frames(5)
 await capture("03b_dialogue")
 while not app.dialogue_queue.is_empty():await click(button(app.dialogue_panel,"继续"))
 app.paused_manual=true;await frames(5)
 var presentation=app.get_node("UIPresentation")
 var clock:float=app.rules.world_time
 var neurons:int=app.rules.neurons
 check(presentation.pause_veil.visible,"manual pause presents a real pause modal")
 await capture("04_pause")
 await click_at(Vector2(180,340));await frames(3)
 check(app.rules.world_time==clock and app.rules.neurons==neurons,"pause backdrop rejects world clicks without settlement")
 await click(button(presentation.pause_veil,"声音与界面"));await frames(4)
 check(app.audio_panel.visible and presentation.settings_veil.visible,"settings has full input shield")
 await capture("05_campaign_settings")
 await click(button(app.audio_panel,"关闭"));await frames(3)
 check(not app.audio_panel.visible and presentation.pause_veil.visible,"close settings restores interrupted pause")
 app.paused_manual=false
 for page:String in ["cast","tree","book","inventory"]:
  var wait_frames:int=0
  while app.closing_left>0 and wait_frames<60:
   await frames(1);wait_frames+=1
  app.open_system_page(page);await frames(5)
  var page_clock:float=app.rules.world_time
  await capture("06_"+page)
  if page=="cast":
   var seen:Dictionary={}
   for id in app.menu.nodes:seen[app.menu.nodes[id].icon.get_rid().get_id()]=true
   check(seen.size()==12,"twelve skill nodes have distinct native pictograms")
   var selected:String=app.menu.selected_id
   var point:Vector2=app.menu.nodes.GUT.get_global_rect().get_center()
   var hover:=InputEventMouseMotion.new();hover.position=point;Input.parse_input_event(hover);await frames(5)
   check(app.menu.selected_id==selected and app.rules.neurons==neurons,"hover preview does not select or spend")
  elif page=="tree":
   var angle:int=app.menu.body_angle
   await click(button(app.menu,"人体 ↷"))
   check(app.menu.body_angle!=angle and app.rules.neurons==neurons,"body rotation is real UI only")
   await click(app.menu.tree_nodes.GUT);await frames(12)
   check(app.menu.inspect_panel.visible,"tree node opens actual inspect actions")
   await capture("07_tree_inspect")
  elif page=="book":
   await click(button(app.menu,"人物"))
   check(app.menu.book_category=="人物","book category switches actual source-backed records")
  elif page=="inventory":
   var contents:Dictionary=app.inventory_contents()
   check(app.menu.inventory_buttons.chocolate.disabled==(not contents.chocolate.available),"food use state follows actual inventory and bodily ability")
  check(app.rules.world_time==page_clock and app.rules.neurons==neurons,"menu UI clock never advances world or settles spending: "+page)
  await click(button(app.menu,"关闭"));await frames(3)
  check(not app.menu.visible and app.rules.world_time-page_clock<.2,"system close works without hidden menu-time advancement: "+page)
 app.open_tutorial(true);await frames(5)
 var guide_clock:float=app.rules.world_time
 await capture("07b_guide")
 await click(button(app.tutorial_ui,"跳过练习"));await frames(4)
 check(app.tutorial_ui==null and app.rules.world_time-guide_clock<.2,"read-only guide closes without advancing practice/game resources")
 app.paused_manual=true;await frames(3)
 var Opening=load("res://scripts/ui/opening_flow.gd")
 var opening=Opening.new();opening.z_index=60;app.add_child(opening);opening.start("startup")
 opening.index=mini(1,opening.cards().size()-1);opening.typed=opening.current_text().length();opening.card_clock=1.0;opening.refresh()
 await capture("07c_opening_controls")
 await click(button(opening,"暂停演出"));var typed:float=opening.typed;await frames(5)
 check(opening.paused and opening.typed==typed,"opening pause freezes the actual caption clock")
 await click(button(opening,"跳过"));check(opening.finished,"opening skip remains actual functional control")
 opening.queue_free();await frames(3)
 var Ending=load("res://scripts/ui/ending_panel.gd")
 var ending=Ending.new();ending.z_index=60;app.add_child(ending);ending.show();await frames(3)
 await capture("07d_ending_E1")
 await click(button(ending,"查看本次记录"));check(ending.showing_records,"ending records remains a real scroll/read state")
 await capture("07e_ending_records_empty")
 for id:String in ["E2","E3"]:
  ending.app={"street":{"data":{"ending":{"id":id,"complete":true}}}}
  ending.show_ending();await capture("07f_ending_"+id)
 check(ending.heading.text=="玩家胜利","E3 heading follows provided ending result; preview fixture only")
 ending.queue_free();await frames(3)
 var valid_root:String=app.store.root
 var blocker:String=valid_root.path_join("blocked_save_directory")
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(valid_root))
 var block:=FileAccess.open(blocker,FileAccess.WRITE);block.store_string("Isolated unwritable-directory fixture");block.close()
 app.store.root=blocker;var failure_clock:float=app.rules.world_time
 await click(button(presentation.pause_veil,"保存并返回标题"));await frames(5)
 check(frontend.active==app and app.paused_manual and app.rules.world_time==failure_clock,"failed pause save preserves active frozen game")
 check(presentation.pause_notice.text.contains("保存失败"),"pause shows real save failure inside its readable modal")
 await capture("07g_save_failure")
 app.store.root=valid_root
 await click(button(presentation.pause_veil,"保存进度"));await frames(5)
 check(app.store.load_snapshot().ok,"real pause save writes valid isolated snapshot")
 await click(button(presentation.pause_veil,"保存并返回标题"));await frames(5)
 check(frontend.active==null,"real pause save and title returns successfully")
 await capture("08_saved_title")
 await click(button(frontend,"继续游戏"));await frames(6);app=frontend.active
 check(app!=null and app.paused_manual,"continue restores actual saved pause state")
 await capture("09_continued_pause")
 var result:=FileAccess.open(ProjectSettings.globalize_path(folder).path_join("result.json"),FileAccess.WRITE)
 result.store_string(JSON.stringify({"passes":passes,"failures":failures,"rendered":true,"scope":"native UI pointer controls, isolated fixture, no formal campaign/art acceptance"},"  "));result.close()
 print("UI_VISUAL_CHECK %d passed %d failed"%[passes.size(),failures.size()])
 frontend.request_exit(0 if failures.is_empty() else 1)
