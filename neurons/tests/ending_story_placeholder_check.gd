extends SceneTree
## Independent presentation evidence. No campaign, ending or identity writes.
class StoryCanvas:
 extends Node2D
 const Story=preload("res://scripts/world/ending_story_placeholder.gd")
 var ending:Dictionary={}
 var title:String=""
 var typeface:Font=load("res://assets/fonts/NotoSansCJKsc-Regular.otf")
 func _draw() -> void:
  draw_rect(Rect2(0,0,1280,720),Color("15211f"))
  draw_string(typeface,Vector2(45,55),title,HORIZONTAL_ALIGNMENT_LEFT,-1,24,Color("c0c7b8"))
  Story.draw(self,ending,Vector2(640,360))
  draw_string(typeface,Vector2(380,540),"纯2D程序占位 / 不代表人物或星球正式造型",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("89998b"))

var folder:String="res://../docs/validation/full_campaign_spatial_20261019/ending_placeholder"
var passes:Array=[]
var failures:Array=[]
func _initialize() -> void:call_deferred("run")

func verify(ok:bool,label:String) -> void:
 (passes if ok else failures).append(label)
 print(("PASS " if ok else "FAIL ")+label)

func run() -> void:
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--validation-root="):folder=arg.trim_prefix("--validation-root=")
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 root.size=Vector2i(1280,720)
 var canvas=StoryCanvas.new();root.add_child(canvas)
 var cases:Array=[
  {"file":"01_E2_body_before_wake","title":"E2 / 现实病床 / 睁眼前","value":{"id":"E2","phase":"wake","elapsed":0.0}},
  {"file":"02_E2_body_awake_connection_break","title":"E2 / 身体睁眼 / 连接中断","value":{"id":"E2","phase":"wake","elapsed":2.8}},
  {"file":"03_E2_external_before_perception","title":"E2 / 来处星球 / 外部本体几何占位","value":{"id":"E2","phase":"planet","elapsed":0.0}},
  {"file":"04_E2_external_perception","title":"E2 / 外部本体恢复感知","value":{"id":"E2","phase":"planet","elapsed":1.9}},
  {"file":"05_E3_body_player_view","title":"E3 / 现实病床 / 玩家视点接续","value":{"id":"E3","phase":"wake","elapsed":2.8}}
 ]
 for sample:Dictionary in cases:
  canvas.ending=sample.value.duplicate(true);canvas.title=sample.title
  var original:String=JSON.stringify(canvas.ending)
  canvas.queue_redraw();await process_frame;await process_frame
  if DisplayServer.get_name()!="headless":
   RenderingServer.force_draw(false)
   root.get_texture().get_image().save_png(ProjectSettings.globalize_path(folder).path_join(str(sample.file)+".png"))
  verify(JSON.stringify(canvas.ending)==original and canvas.get_child_count()==0,str(sample.file)+": draw leaves source ending and scene ownership untouched")
 # An E3 source never receives an E2-only external-world tail.
 canvas.ending={"id":"E3","phase":"planet","elapsed":1.0};canvas.queue_redraw();await process_frame
 verify(canvas.get_child_count()==0,"unsupported E3 planet phase creates no new map/actor")
 var output=FileAccess.open(folder.path_join("result.json"),FileAccess.WRITE)
 output.store_string(JSON.stringify({"passes":passes,"failures":failures,"rendered":DisplayServer.get_name()!="headless","scope":"Independent pure2D drawing samples from declared ending phase/elapsed fixtures. Read-only helper, no campaign completion or new gameplay; unknown external-body appearance remains elementary geometry, not formal identity/species design."},"  "));output.close()
 print("ENDING_STORY_PLACEHOLDER_CHECK %d passed %d failed"%[passes.size(),failures.size()])
 quit(0 if failures.is_empty() else 1)
