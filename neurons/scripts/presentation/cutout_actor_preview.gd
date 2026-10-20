extends Node2D
## Independent diagnostic scene. Not an alternate campaign or a formal asset.
const Actor=preload("res://scripts/presentation/cutout_actor_2d.gd")
@export var config_path:String="res://data/character_rig.json"
var actor
var label:Label
var moving:bool=true
var paused:bool=false
var elapsed:float=0.0
var travel:float=0.0
var state:String="walk"
func _ready() -> void:
 actor=Actor.new();add_child(actor);actor.position=Vector2(570,640);actor.scale=Vector2.ONE*.43
 actor.load_config(config_path);actor.debug_bones=true
 label=Label.new();label.position=Vector2(20,15);add_child(label)
func _process(delta:float) -> void:
 if not paused:
  elapsed+=delta
  if moving:travel+=delta*.75
 actor.sample_pose({"state":state if moving else "idle","direction":actor.direction,"action_uid":"independent-preview","elapsed":elapsed,"duration":1.0,"travel_m":travel,"moving":moving,"paused":paused,"ground_px_per_m":480.0})
 label.text="独立骨骼技术预览 · 非游戏验收\n1–4方向 / Space暂停 / W行走或站定 / B骨架\n%s · %s · %.2fm\n%s"%["正式贴图可用" if actor.is_available() else "缺少已确认atlas：只显示诊断骨架，正式入口应回退",state,travel,"" if actor.is_available() else "当前示例关节不能作为正式人物标点"]
func _unhandled_key_input(event:InputEvent) -> void:
 if not event is InputEventKey or not event.pressed or event.echo:return
 if event.keycode>=KEY_1 and event.keycode<=KEY_4:actor.set_direction(int(event.keycode-KEY_1))
 elif event.keycode==KEY_SPACE:paused=not paused
 elif event.keycode==KEY_W:moving=not moving
 elif event.keycode==KEY_B:actor.debug_bones=not actor.debug_bones
