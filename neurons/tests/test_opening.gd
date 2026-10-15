extends SceneTree
## Independent presentation unit check; host/world integration is a separate suite.
const Opening=preload("res://scripts/ui/opening_flow.gd")
var passes:Array=[]
var failures:Array=[]
var folder:String="res://../docs/validation/b2_opening_20261016"
var flow

func _init() -> void:
 call_deferred("run")

func check(condition:bool,label:String) -> void:
 (passes if condition else failures).append(label)
 print(("PASS " if condition else "FAIL ")+label)

func frames(count:int=2) -> void:
 for i in range(count):await process_frame

func make_flow():
 var node=Opening.new();root.add_child(node);node.set_process(false);return node

func capture(label:String) -> void:
 if DisplayServer.get_name()=="headless":return
 await frames();await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(ProjectSettings.globalize_path(folder).path_join(label+".png"))

func run() -> void:
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--validation-root="):folder=argument.trim_prefix("--validation-root=")
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 root.content_scale_size=Vector2i(1280,720);root.size=Vector2i(1280,720)
 flow=make_flow();await frames()
 var completions:Array=[]
 flow.completed.connect(func(sequence,skipped):completions.append({"sequence":sequence,"skipped":skipped}))
 check(not flow.start("missing"),"unknown sequence rejected without opening empty modal")
 check(flow.start("parasite",{"name":"测试名字","invader_id":4321}),"profile introduction starts with existing name and invader number")
 check(flow.cards().size()==9 and flow.current_text()=="我叫测试名字 \n...","intro uses original first line with only name substitution")
 flow._process(0.1)
 check(flow.typed>0 and int(flow.typed)<flow.current_text().length(),"actual UI clock progressively types subtitle")
 flow.toggle_pause();var frozen:Dictionary=flow.snapshot()
 flow._process(10);flow.advance()
 check(flow.snapshot()==frozen,"manual pause freezes typing, hold, fade and advance")
 var partial:Dictionary=JSON.parse_string(JSON.stringify(frozen))
 var clone=make_flow()
 check(clone.start("parasite",{},partial) and clone.paused and is_equal_approx(clone.typed,flow.typed),"real JSON roundtrip resumes partial typed subtitle and paused flag")
 check(clone.current_text()=="我叫测试名字 \n...","restored context retains original named identity rather than rerolling")
 root.remove_child(clone);clone.queue_free()
 flow.toggle_pause();flow.advance()
 check(int(flow.typed)==flow.current_text().length() and flow.index==0,"first click reveals current line without skipping its card")
 flow.advance();flow._process(0.1)
 check(flow.fade_out>0 and flow.index==0 and flow.completed_ids==["intro_name"],"second click begins fade-out and marks current card read once")
 var half_fade:Dictionary=JSON.parse_string(JSON.stringify(flow.snapshot()))
 clone=make_flow();check(clone.start("parasite",{},half_fade),"half-faded card accepts schema-one JSON snapshot")
 clone._process(0.2)
 check(clone.index==1 and clone.completed_ids==["intro_name"],"restored fade commits next card once, without duplicating read receipt")
 check(clone.current_text()=="据资料\n我是这里的第4321名入侵生物　","second card preserves source claim and invader number")
 root.remove_child(clone);clone.queue_free()
 flow._process(0.2);flow._process(0.4);flow.advance()
 await capture("01_intro_id")
 var saved_count:int=flow.completed_ids.size()
 flow.advance();flow.advance();flow.advance()
 check(flow.completed_ids.size()==saved_count+1,"repeat clicks during fade cannot mark later cards read")
 flow._process(0.3)
 var order:Array=[]
 for c in flow.cards():order.append(c.id)
 check(order==["intro_name","intro_id","intro_denial","intro_turn","intro_parasite","intro_sleep","intro_motive","intro_wake","intro_black"],"paired original text-box columns preserve exact intro ordering")
 for attempt in range(40):
  if flow.finished:break
  flow._process(0.4)
  flow.advance();flow.advance();flow._process(0.3)
 check(flow.finished and not flow.visible and completions.size()==1 and not completions[0].skipped,"full introduction completes exactly once into tutorial route")
 check(flow.completed_ids.size()==9,"full manual run accounts for each original intro card once")
 var complete:Dictionary=JSON.parse_string(JSON.stringify(flow.snapshot()))
 flow.skip();flow.advance();flow._process(20)
 check(completions.size()==1,"finish/skip/repeated input cannot duplicate completion")
 clone=make_flow();var resumed_signals:Array=[]
 clone.completed.connect(func(_sequence,_skipped):resumed_signals.append(true))
 check(clone.start("parasite",{},complete) and clone.finished and not clone.visible,"completed intro restore remains closed")
 clone.advance();clone.skip();clone._process(20)
 check(resumed_signals.is_empty(),"loading completed intro never re-emits completion or tutorial transition")
 root.remove_child(clone);clone.queue_free()
 flow.start("parasite",{"name":"新档","invader_id":9876});flow._process(1)
 flow.start("parasite",{"name":"名字{invader_id}","invader_id":9876})
 check(flow.current_text().contains("名字{invader_id}"),"legal player name is inserted literally without recursively substituting its braces")
 var bad:Dictionary=flow.snapshot();bad.schema=77
 check(not flow.restore(bad),"unsupported opening schema is rejected")
 bad=flow.snapshot();bad.index=999
 check(not flow.restore(bad),"missing card index is rejected")
 flow.toggle_pause();flow.skip();flow.skip()
 check(completions.size()==2 and completions[1].skipped and flow.finished,"explicit skip while paused closes intro once")
 flow.start("startup")
 check(flow.auto_play and flow.cards().size()==8,"application startup uses auto slideshow with eight original crisis/bedroom cards")
 flow._process(0.4);flow.advance()
 await capture("02_startup_crisis")
 for attempt in range(160):
  if flow.finished:break
  flow._process(0.25)
 check(flow.finished and completions.size()==3 and completions[2].sequence=="startup","automatic startup reaches title completion exactly once")
 var no_disclosure:bool=true
 for seq in flow.data.sequences.values():
  for c in seq.cards:
   if c.visual in ["planet","spaceship"]:no_disclosure=false
 check(no_disclosure,"R1 epilogue-only planet/spaceship art is absent from opening")
 flow.reduced_effects=true;flow.start("parasite",{"name":"演出占位","invader_id":1357});flow.advance();flow.advance()
 check(flow.index==1 and flow.fade_out==0 and flow.opacity()==1,"reduced feedback uses immediate static slide transitions")
 var protected:Dictionary={"neurons":5,"plexus":3,"control_ms":0,"facts":{},"knowledge":{}}
 var before:String=JSON.stringify(protected)
 flow.start("parasite",protected);flow._process(0.3);flow.skip()
 check(JSON.stringify(protected)==before and flow.context.keys().size()==2,"opening presentation never changes host gameplay or fact dictionaries")
 var f:=FileAccess.open(ProjectSettings.globalize_path(folder).path_join("result.json"),FileAccess.WRITE)
 f.store_string(JSON.stringify({"passes":passes,"failures":failures,"rendered":DisplayServer.get_name()!="headless","scope":"independent opening module; JSON typing/fade/pause/once-only completion; no host world/save integration or voice/art acceptance"},"  "));f.close()
 print("OPENING_CHECK %d passed %d failed"%[passes.size(),failures.size()])
 root.remove_child(flow);flow.queue_free();await frames(4)
 quit(0 if failures.is_empty() else 1)
