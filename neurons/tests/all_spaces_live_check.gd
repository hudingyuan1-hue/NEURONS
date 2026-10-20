extends "res://tests/opening_campaign_check.gd"
## Declared chapter/room inspection fixture. Real renderer and saved layout
## versions, not a natural playthrough or formal-art approval.
var entries:Array=[]

func inspect_room(chapter:int,id:String) -> void:
 app.enter_room(id);app.paused_manual=true
 await frames(2)
 var floor_layout=app.layout
 var at:Vector2=app.hero_pos
 check(floor_layout.walkable(at),"L%d:%s actual entry is walkable"%[chapter,id])
 check(floor_layout.unproject(floor_layout.project(at)).distance_to(at)<.00001,"L%d:%s camera projection round trip"%[chapter,id])
 check(floor_layout.geometry_version>=2,"L%d:%s uses metric geometry"%[chapter,id])
 check(app.world_viewport.get_parent().stretch_shrink==1,"L%d:%s full-size world viewport"%[chapter,id])
 await capture("L%d_%s"%[chapter,id])
 entries.append({"chapter":chapter,"room":id,"size":[floor_layout.world_size().x,floor_layout.world_size().y],"version":floor_layout.geometry_version,"spawn":[at.x,at.y]})

func _ready() -> void:
 name="CampaignCheck";frontend=get_parent();folder="res://../docs/validation/spatial_all_20261018/live"
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--validation-root="):folder=arg.trim_prefix("--validation-root=")
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 await frames();await frontend.show_profile();frontend.name_field.text="全场景空间巡检";frontend.overwrite_armed=true;frontend.new_game();await frames();app=frontend.active
 if app.tutorial_ui!=null:app.tutorial_ui.finish()
 app.dialogue_queue.clear();app.show_dialogue();app.closing_left=0;app.paused_manual=true
 await inspect_room(1,"bedroom")
 app.unlock_hospital();app.paused_manual=true
 for id in ["ward","lobby","clinic","pharmacy","office"]:await inspect_room(2,id)
 app.unlock_asylum();app.paused_manual=true
 for id in ["ward","lobby","clinic","pharmacy","office","stairs","corridor","activity","group_therapy","quiet","bathroom","double_ward","workshop"]:await inspect_room(3,id)
 app.unlock_cortex();app.paused_manual=true
 check(int(app.session.data.cortex_geometry_version)==2,"fresh L4 selects version2 without migrating an in-flight save")
 for id in app.CortexMap.ALL_ROOMS:await inspect_room(4,str(id))
 var current:Dictionary=app.snapshot_data()
 check(app.restore_snapshot(current),"metric L4 actual JSON snapshot restores")
 check(app.layout.geometry_version==2,"metric L4 snapshot preserves new version")
 var old:Dictionary=current.duplicate(true);old.session.erase("cortex_geometry_version")
 old.room_id="atrium";old.hero_pos=[.95,2.9];old.hero_route=[]
 check(app.restore_snapshot(old),"legacy L4 snapshot without version remains loadable")
 check(app.layout.geometry_version==1 and app.hero_pos.distance_to(Vector2(.95,2.9))<.0001,"legacy active action keeps its old metre geometry")
 app.restore_snapshot(current);app.paused_manual=true
 app.unlock_combat();app.paused_manual=true
 check(int(app.combat.data.geometry_version)==3,"fresh L5 selects per-room geometry version3")
 for id in app.CombatMap.rooms():await inspect_room(5,str(id))
 var battle_snapshot:Dictionary=app.snapshot_data()
 check(app.restore_snapshot(battle_snapshot) and app.layout.spatial_version==3,"new L5 layout round-trips actual snapshot")
 app.unlock_street();app.paused_manual=true
 for id in app.StreetMap.rooms():await inspect_room(6,str(id))
 # Independent hidden-route geometry/renderer fixture, not a claimed earned E1.
 app.session.data.level=1;app.hidden_route.start();app.paused_manual=true
 await inspect_room(0,"hidden_street")
 check(entries.size()==56,"all55 regular instances and independent hidden fragment rendered")
 var f=FileAccess.open(ProjectSettings.globalize_path(folder).path_join("result.json"),FileAccess.WRITE)
 f.store_string(JSON.stringify({"passes":passes,"failures":failures,"rooms":entries,"rendered":DisplayServer.get_name()!="headless","scope":"Declared chapter/room and legacy-save fixtures; real runtime renderer, portal entry, metric scale and actual snapshot handlers. Does not prove natural whole game, branch balance or formal art/audio approval."},"  "));f.close()
 print("ALL_SPACES_LIVE ",entries.size()," rooms; ",failures.size()," failures")
 app.audio.reset_scene();frontend.request_exit(0 if failures.is_empty() else 1)
