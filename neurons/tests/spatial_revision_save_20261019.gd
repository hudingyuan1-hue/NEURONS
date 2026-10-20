extends SceneTree
## Real snapshot restore keeps in-flight metric positions in original layouts.
const Campaign=preload("res://scripts/campaign.gd")
const Revision=preload("res://scripts/world/spatial_revision.gd")
const Bedroom=preload("res://scripts/world/bedroom_layout.gd")
const Institution=preload("res://scripts/world/institution_layout.gd")
const Cortex=preload("res://scripts/world/cortex_layout.gd")
const Combat=preload("res://scripts/world/combat_layout.gd")
const Street=preload("res://scripts/world/street_layout.gd")
const Hidden=preload("res://scripts/world/hidden_layout.gd")
var checks:int=0
var failures:Array=[]
var app
func _initialize() -> void:call_deferred("run")
func verify(value:bool,label:String) -> void:
 checks+=1
 if not value:failures.append(label);push_error(label)
func run() -> void:
 var old_neural:Dictionary=Revision.document("neural_spaces.json",1)
 var new_neural:Dictionary=Revision.document("neural_spaces.json",2)
 verify(old_neural.rooms["L4:atrium"].size_m!=new_neural.rooms["L4:atrium"].size_m,"original and rebuilt metric revisions stay distinct")
 for layout in [Bedroom.new(1),Institution.new("lobby",2,1),Cortex.new("atrium",2,1),Combat.new("thalamus",true,3,1),Street.new("street_plaza",1),Hidden.new(1)]:
  verify(layout.spatial_revision==1,"constructor retains original revision "+str(layout.get_script().resource_path))
 for room:String in old_neural.rooms:
  var raw:Dictionary=old_neural.rooms[room]
  var layout=Cortex.new(str(raw.room_id),2,1) if int(raw.chapter)==4 else Combat.new(str(raw.room_id),true,3,1)
  var actual:Dictionary=layout.space_spec()
  for field:String in ["size_m","furniture","portals","partitions","spawn_m"]:
   verify(actual[field]==raw[field],room+" original "+field+" unchanged")
 app=Campaign.new()
 app.store.root=ProjectSettings.globalize_path("res://../tmp/spatial_rebuild_20261019/revision_save_fixture")
 DirAccess.make_dir_recursive_absolute(app.store.root)
 app.profile={"name":"空间旧档隔离检验","invader_id":1,"opening_completed":true,"tutorial_completed":true}
 root.add_child(app);app.set_process(false);app.paused_manual=true
 var base:Dictionary=app.snapshot_data()
 for chapter:int in [1,2,3,4,5,6]:
  app.restore_snapshot(base)
  app.session.data.level=chapter;app.session.data.spatial_revision=2
  app.session.data.room_geometry_version=2;app.session.data.institution_geometry_version=2;app.session.data.cortex_geometry_version=2
  var room:String="bedroom" if chapter==1 else "lobby" if chapter in [2,3] else "atrium" if chapter==4 else "thalamus" if chapter==5 else "street_plaza"
  if chapter==5:app.combat.start()
  if chapter==6:app.street.start()
  app.room_id="";app.enter_room(room)
  var saved:Dictionary=app.snapshot_data()
  saved.session.erase("spatial_revision")
  if chapter==5:saved.combat_state.erase("spatial_revision")
  if chapter==6:saved.street_state.erase("spatial_revision")
  var old_layout=Bedroom.new(1) if chapter==1 else Institution.new("lobby",chapter,1) if chapter in [2,3] else Cortex.new("atrium",2,1) if chapter==4 else Combat.new("thalamus",true,3,1) if chapter==5 else Street.new("street_plaza",1)
  var point:=Vector2(.5,.5)
  if not old_layout.walkable(point):point=old_layout.furniture[0].at
  var original_route:Array=[[point.x,point.y],[point.x+.15,point.y]]
  saved.hero_pos=[point.x,point.y];saved.route=original_route
  saved.action_left=.375;saved.action_phase="walking";saved.destination=""
  saved.rules.search_elapsed=1.25
  var ledger:Dictionary=saved.rules.owners.duplicate(true)
  verify(app.restore_snapshot(saved),"L%d actual old metric snapshot restores"%chapter)
  verify(app.layout.spatial_revision==1,"L%d old snapshot selects history"%chapter)
  verify(app.hero_pos==point and app.hero_route==PackedVector2Array([point,point+Vector2(.15,0)]),"L%d in-flight position and route unchanged"%chapter)
  verify(is_equal_approx(app.action_left,.375) and is_equal_approx(app.rules.search_elapsed,1.25),"L%d in-flight clocks unchanged"%chapter)
  verify(app.rules.owners==ledger,"L%d ownership unchanged"%chapter)
  verify(app.layout.walkable(point),"L%d old coordinates still legal"%chapter)
  verify(app.restore_snapshot(app.snapshot_data()) and app.layout.spatial_revision==1,"L%d subsequent save keeps same revision"%chapter)
 app.restore_snapshot(base)
 app.session.data.spatial_revision=1
 app.session.new_attempt(4,app.rng);app.cortex_layouts.clear();app.room_id="";app.enter_room("atrium")
 verify(app.session.data.spatial_revision==2 and app.layout.spatial_revision==2,"new real attempt adopts rebuilt revision")
 for chapter:int in [2,3]:
  app.session.data.level=chapter;app.session.data.spatial_revision=1
  app.session.new_attempt(chapter,app.rng)
  verify(app.session.data.spatial_revision==1,"L%d same-chapter rest preserves persistent actor floor revision"%chapter)
 app.session.data.level=2;app.session.data.spatial_revision=1
 app.session.new_attempt(3,app.rng)
 verify(app.session.data.spatial_revision==2,"new chapter adopts source reconstruction")
 app.audio.reset_scene();app.queue_free()
 await process_frame
 app=null
 await process_frame
 var file:=FileAccess.open("res://../tmp/spatial_rebuild_20261019/spatial_revision_save_result.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":checks,"failures":failures,"scope":"Original metric JSON identity, all six layout families and actual Campaign.restore_snapshot of six chapter fixtures; in-flight position, route, elapsed clocks and ownership preserved. No gameplay receipt replay or teleport migration."},"  "));file.close()
 print("SPATIAL_REVISION_SAVE ",checks," checks / ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
