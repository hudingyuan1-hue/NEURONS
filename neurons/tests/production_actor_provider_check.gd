extends SceneTree
## Isolated technical fixture: memory rectangles are not production character art.
const Provider=preload("res://scripts/presentation/production_actor_provider.gd")
const State=preload("res://scripts/presentation/hero_visual_state.gd")
const Rig=preload("res://scripts/presentation/cutout_actor_2d.gd")
var checks:int=0
var failures:Array[String]=[]
class TestRules extends RefCounted:
 var search_active:bool=false
 var search_elapsed:float=0.0
 var search_duration:float=1.0
 var reaction_left:float=0.0
 var hurt_left:float=0.0
 var owners:Dictionary={}
class TestLayout extends RefCounted:
 var furniture:Array=[]
 var config:Dictionary={"wall":{"thickness_m":.15}}
 func project(at:Vector2) -> Vector2:return Vector2(at.x*96-at.y*18,at.y*66-at.x*6)
 func world_size() -> Vector2:return Vector2(6,5)
class TestSession extends RefCounted:
 var data:Dictionary={"level":5}
class TestSearch extends RefCounted:
 var pose:String="mid"
class TestGroup extends RefCounted:
 var data:Dictionary={"actors":{},"body":{},"holder":"","observations_state":{},"records_state":{},"ward_window_state":{}}
class TestApp extends RefCounted:
 var campaign_ready:bool=true
 var runtime_generation:int=1
 var room_id:String="one"
 var world_visual_time:float=10.0
 var hero_pos:=Vector2(1,1)
 var hero_facing:=Vector2.RIGHT
 var hero_state:String="idle"
 var action_phase:String="autonomy"
 var action_left:float=0.0
 var target_index:int=-1
 var rules=TestRules.new()
 var layout=TestLayout.new()
 var session=TestSession.new()
 var search_actions=TestSearch.new()
 var family=null
 var hospital=TestGroup.new()
 var asylum=TestGroup.new()
 var paused:bool=false
 func world_paused() -> bool:return paused

func _initialize() -> void:call_deferred("run")
func check(value:bool,label:String) -> void:
 checks+=1
 if not value:failures.append(label);push_error(label)

func fixture() -> Dictionary:
 var points:Dictionary={"pelvis":[100,110],"spine":[100,90],"chest":[100,60],"neck":[100,35],"head":[100,20],"left_upper_arm":[75,60],"left_forearm":[60,85],"left_hand":[55,110],"right_upper_arm":[125,60],"right_forearm":[140,85],"right_hand":[145,110],"left_thigh":[88,110],"left_shin":[88,155],"left_foot":[88,200],"right_thigh":[112,110],"right_shin":[112,155],"right_foot":[112,200]}
 var bones:Dictionary={};var parts:Array=[];var n:int=0
 var source:=Image.create(64,64,false,Image.FORMAT_RGBA8);source.fill(Color.TRANSPARENT)
 for name:String in Rig.BONE_PARENTS:bones[name]={"parent":Rig.BONE_PARENTS[name],"rest_px":points[name]}
 for name:String in Rig.REQUIRED_PARTS:
  var x:int=(n%4)*16;var y:int=(n/4)*16
  source.fill_rect(Rect2i(x+2,y+2,12,12),Color.WHITE)
  parts.append({"id":name,"bone":"chest" if name=="torso" else name,"region_px":[x,y,16,16],"pivot_px":[8,8],"z_index":n});n+=1
 var view:Dictionary={"atlas_texture":ImageTexture.create_from_image(source),"bones":bones,"parts":parts}
 return {"enabled":true,"production_ready":true,"canvas_px":[200,240],"foot_anchor_px":[100,220],"body_height_px":200,"stride_m":.65,"stance_fraction":.6,"directions":{"D0":view,"D1":view,"D2":view,"D3":view}}

func run() -> void:
 var app=TestApp.new();var provider=Provider.new();root.add_child(provider);provider.setup(app);provider.set_process(false)
 check(not provider.available() and provider.frame().is_empty(),"Unapproved assembly stays behind explicit production gate")
 provider.rig.configure(fixture());provider._production_ready=true;provider._fit_view()
 var original:Dictionary={"owners":app.rules.owners.duplicate(true),"session":app.session.data.duplicate(true),"furniture":app.layout.furniture.duplicate(true)}
 provider.update_visual(app,1.0/60)
 check(provider.available(),"Complete four-way diagnostic rig can exercise the real adapter")
 check(provider.viewport.disable_3d and provider.viewport.transparent_bg,"Runtime render is transparent pure 2D")
 check(provider.frame().body_height==300.0,"Source body ruler has one uniform render scale")
 app.hero_state="walk";app.hero_pos+=Vector2(.012,0);app.world_visual_time+=.01
 provider.update_visual(app,.01)
 check(absf(provider.diagnostics.travel_m-.012)<.000001,"Gait advances by actual accepted world travel")
 check(provider.diagnostics.locomotion_weight>0 and provider.diagnostics.locomotion_weight<1,"Short start blends into gait without resetting phase")
 var phase:float=provider.diagnostics.travel_m
 app.hero_pos+=Vector2(3,0);provider.update_visual(app,.01)
 check(is_equal_approx(provider.diagnostics.travel_m,phase),"Teleport does not synthesize walking distance")
 app.room_id="two";app.hero_pos=Vector2(2,2);provider.update_visual(app,.01)
 check(is_equal_approx(provider.diagnostics.travel_m,phase),"Room transition does not synthesize walking distance")
 app.runtime_generation+=1;app.hero_pos=Vector2(1,1);provider.update_visual(app,.01)
 check(is_equal_approx(provider.diagnostics.travel_m,phase),"Restore generation does not synthesize walking distance")
 app.hero_state="idle";provider.update_visual(app,.1)
 var frozen:Dictionary=provider.rig.pose_snapshot()
 app.paused=true;app.world_visual_time+=100;app.hero_facing=Vector2.DOWN;provider.update_visual(app,100)
 check(provider.rig.pose_snapshot()==frozen,"Menu/dialogue pause freezes pose and direction")
 check(provider.viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED,"Paused rig reuses cached texture")
 app.paused=false;provider.update_visual(app,.01)
 check(provider.rig.direction==3,"Resume samples the real facing direction")
 check(app.rules.owners==original.owners and app.session.data==original.session and app.layout.furniture==original.furniture,"Adapter does not mutate rules ownership, progression or furniture")
 app.session.data.level=2;app.hero_pos=Vector2(1.1,1.4)
 app.layout.furniture=[{"id":"drawer","rect":Rect2(1.6,1,.5,.6),"height_m":.7}]
 app.target_index=0;app.rules.search_active=true;app.rules.search_elapsed=.3;app.rules.search_duration=1.7
 var observation:Dictionary=State.sample(app,provider.catalog)
 var expected:Vector2=app.layout.project(Vector2(1.6,1.4))-Vector2(0,.7*78)
 check(observation.hands.right_hand.distance_to(expected)<.00001,"Institution hand uses the actual furniture contact surface")
 check(observation.elapsed==.3 and observation.duration==1.7,"Search consumes the existing action clock without retiming")
 app.search_actions.pose="low";observation=State.sample(app,provider.catalog)
 check(observation.state=="search_low" and observation.pose=="low","Low search selects a knee bend rather than squashing the whole sprite")
 app.rules.search_active=false;app.rules.owners.hospital_cup="hero";app.hospital.data.body={"kind":"raise_cup"}
 observation=State.sample(app,provider.catalog)
 check(observation.item_hands.cup.distance_to(app.layout.project(app.hero_pos)+Vector2(29,-136.5*.84))<.00001,"Raised cup prop and rig share the real holding hand")
 app.action_phase="resting";observation=State.sample(app,provider.catalog)
 check(observation.resting and observation.state=="idle","Rest pose is a presentation of the existing resting action")
 provider.queue_free();await process_frame;await process_frame
 var folder:String="res://../docs/validation/asset_production_20261020/characters"
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 var file=FileAccess.open(folder+"/provider_check.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":checks,"failures":failures,"scope":"Memory fixture checks bridge invariants only; no production visual approval."},"  "));file.close()
 print("PRODUCTION_ACTOR_PROVIDER ",checks,"/",failures.size());quit(0 if failures.is_empty() else 1)
