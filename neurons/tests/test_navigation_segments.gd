extends SceneTree
## Regression for continuous geometry and safe chapter-version selection.
const Room=preload("res://scripts/world/room_layout.gd")
const Institution=preload("res://scripts/world/institution_layout.gd")
const Session=preload("res://scripts/core/campaign_session.gd")
var results:Array=[]
var failed:int=0

func check(ok:bool,label:String) -> void:
 results.append({"label":label,"ok":ok})
 if not ok:failed+=1;printerr(label)

func _init() -> void:
 var room=Room.new();room.geometry_version=2
 var rect:=Rect2(1,1,1,1)
 check(room.segment_hits_rect(Vector2(0,1.5),Vector2(3,1.5),rect),"full crossing")
 check(room.segment_hits_rect(Vector2(0,1),Vector2(3,1),rect),"collinear edge contact is blocked")
 check(room.segment_hits_rect(Vector2(0,2),Vector2(3,2),rect),"far edge uses the same closed boundary")
 check(room.segment_hits_rect(Vector2(0,2),Vector2(2,0),rect),"single corner touch is blocked")
 check(not room.segment_hits_rect(Vector2(0,2.01),Vector2(3,2.01),rect),"parallel clear line stays clear")
 check(room.segment_hits_rect(Vector2(1.5,1.5),Vector2(1.5,1.5),rect),"stationary point inside")
 check(not room.segment_hits_rect(Vector2(0,0),Vector2(0,0),rect),"stationary point outside")
 check(room.segment_hits_rect(Vector2(0.9999,1.0002),Vector2(1.0002,0.9999),rect),"sub-sample corner crossing cannot be skipped")
 check(room.footprint_contains(rect,Vector2(2,1.5)),"v2 point boundary agrees with continuous collision")
 room.geometry_version=1
 check(not room.footprint_contains(rect,Vector2(2,1.5)),"v1 retains original Rect2 boundary semantics")
 var rng:=RandomNumberGenerator.new();rng.seed=326
 var session=Session.new();session.new_attempt(2,rng)
 check(session.data.institution_geometry_version==2,"fresh chapter adopts metric geometry")
 session.data.institution_geometry_version=1;session.data.attempts["2"]=2
 session.new_attempt(2,rng)
 check(session.data.institution_geometry_version==1,"old hospital rest retains original chapter geometry")
 session.new_attempt(3,rng)
 check(session.data.institution_geometry_version==2,"new asylum chapter can adopt metric geometry independently")
 session.data.institution_geometry_version=1;session.new_attempt(3,rng)
 check(session.data.institution_geometry_version==1,"old asylum rest also retains its chapter geometry")
 var institution=Institution.new("lobby",2)
 check(institution.segment_hits_rect(Vector2(0,1),Vector2(3,1),rect),"institution uses the shared continuous intersection")
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--result="):
   var output:String=ProjectSettings.globalize_path(arg.trim_prefix("--result="))
   DirAccess.make_dir_recursive_absolute(output.get_base_dir())
   var file:=FileAccess.open(output,FileAccess.WRITE)
   file.store_string(JSON.stringify({"checks":results.size(),"failed":failed,"results":results,"scope":"headless segment collision and geometry version selection; no normal-play claim"},"  "))
 print("NAVIGATION_SEGMENTS %d checks %d failed"%[results.size(),failed]);quit(1 if failed else 0)
