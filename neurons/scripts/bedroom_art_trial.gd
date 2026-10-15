extends "res://scripts/bedroom_sample.gd"
## Reversible scene only. Main bedroom scene and all rule code remain unchanged.
const TrialView=preload("res://scripts/world/room_art_trial_view.gd")
var evidence_dir:="res://../docs/validation/art_trial_20261015"

func create_world() -> void:
 super.create_world()
 # Keep viewport/camera/projection and the base interaction controller.
 view.set_script(TrialView)
 view.app=self
 view.layout=layout
 view.font=sample_font
 layout.furniture[1].height=30.0
 # Keep the approach on a valid existing 0.1 m navigation cell: 1.97 rounded
 # onto the neighboring chair's inflated cell even though the point was clear.
 layout.furniture[1].at=Vector2(1.0,1.9)

func _ready() -> void:
 super._ready()
 set_process(true)
 start_bedside_sample()
 scenario_label.text="局部试接入 / 未定稿"
 # Visible scope label; no art acceptance or story progression implied.
 label_at("试验：床头柜＋邻接床沿；墙地复用候选。角色、床面及其他家具仍为灰盒。",Vector2(365,77),11,Color("c0b499"))
 if "--art-trial-check" in OS.get_cmdline_user_args():
  demo_mode=true
  var driver:=Node.new()
  driver.set_script(load("res://tests/art_trial_check.gd"))
  add_child(driver)

func snapshot(tag:String) -> void:
 var folder:=ProjectSettings.globalize_path(evidence_dir)
 DirAccess.make_dir_recursive_absolute(folder)
 # The fixture can change pose after the frame's queued draw. Wait for the
 # following process/render pair so a label never describes the previous pose.
 await get_tree().process_frame
 view.queue_redraw()
 await RenderingServer.frame_post_draw
 var result:=get_viewport().get_texture().get_image().save_png(folder+"/"+tag+".png")
 print("ART_TRIAL_SCREENSHOT "+tag+" result="+str(result))
