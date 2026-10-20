extends "res://tests/all_spaces_live_check.gd"
## Three declared spatial fixtures after the shared affine projection's
## visible-face correction. Not another natural or all-branch acceptance run.
const Metric=preload("res://scripts/world/metric_bedroom_view.gd")

func _ready() -> void:
 name="CampaignCheck";frontend=get_parent();folder="res://../docs/validation/spatial_institution_20261018/visible_faces_final"
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--validation-root="):folder=arg.trim_prefix("--validation-root=")
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 await frames();await frontend.show_profile();frontend.name_field.text="空间可见面校准";frontend.overwrite_armed=true;frontend.new_game();await frames();app=frontend.active
 if app.tutorial_ui!=null:app.tutorial_ui.finish()
 app.dialogue_queue.clear();app.show_dialogue();app.closing_left=0;app.paused_manual=true
 await inspect_room(1,"bedroom")
 var rect:=Rect2(1,1,1,1)
 var faces:Array=Metric._prism_faces(app.layout,rect,78.0)
 # k=(-depth.x/x_scale,1,depth.y/height_scale) points toward the viewer.
 # West and south normals face k; this is derived from projection, not art.
 var k:=Vector3(-app.layout.projection_depth.x/app.layout.projection_x,1,app.layout.projection_depth.y/app.layout.height_pixels_per_m)
 check(Vector3.LEFT.dot(k)>0 and Vector3.RIGHT.dot(k)<0,"projection kernel selects west over east")
 check(faces[1][0]==app.layout.project(rect.position) and faces[1][1]==app.layout.project(rect.position+Vector2(0,1)),"actual prism and visible-face hit geometry use west boundary")
 check(app.layout.config.wall.display.near_sides==["west","south"],"complete-wall visibility follows the same projection kernel")
 app.unlock_hospital();app.paused_manual=true
 await inspect_room(2,"ward");await inspect_room(2,"clinic")
 var f=FileAccess.open(folder.path_join("result.json"),FileAccess.WRITE)
 f.store_string(JSON.stringify({"passes":passes,"failures":failures,"rooms":entries,"rendered":DisplayServer.get_name()!="headless","scope":"Three declared new-layout fixtures, actual GPU rendering and visible-face geometry derived from projection kernel. No layout/rule changes, natural route or aesthetic approval."},"  "));f.close()
 print("INSTITUTION_VISIBLE_FACES ",passes.size()," passed ",failures.size()," failed")
 app.audio.reset_scene();frontend.request_exit(0 if failures.is_empty() else 1)
