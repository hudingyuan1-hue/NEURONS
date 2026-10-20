extends Control
const UIStyle=preload("res://scripts/ui/ui_style.gd")
## Presentation only. Reads settled actions; never submits or delays gameplay.
var app
var remaining:float=0.0
var headline:Label
var detail:Label
var activity:Label
var progress:ProgressBar
var receipt_panel:Panel
var receipts:Array=[]
var tint:=Color("d8b17a")

func _ready() -> void:
 mouse_filter=Control.MOUSE_FILTER_IGNORE
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 theme=UIStyle.theme_for()
 activity=make_label(Rect2(26,153,590,29),16)
 progress=ProgressBar.new();progress.position=Vector2(26,183);progress.size=Vector2(280,5)
 progress.show_percentage=false;progress.mouse_filter=Control.MOUSE_FILTER_IGNORE
 add_child(progress)
 receipt_panel=Panel.new();receipt_panel.position=Vector2(815,153);receipt_panel.size=Vector2(414,120)
 receipt_panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
 var style:=UIStyle.surface("paper",true)
 receipt_panel.add_theme_stylebox_override("panel",style);add_child(receipt_panel)
 headline=make_label(Rect2(830,164,385,30),19)
 detail=make_label(Rect2(830,198,382,67),15);detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 receipt_panel.hide();headline.hide();detail.hide()

func make_label(bounds:Rect2,points:int) -> Label:
 var label:=Label.new();label.position=bounds.position;label.size=bounds.size
 label.mouse_filter=Control.MOUSE_FILTER_IGNORE
 label.add_theme_font_size_override("font_size",points);label.add_theme_color_override("font_color",UIStyle.INK)
 add_child(label);return label

func present(result:Dictionary,target:String) -> void:
 var id:String=str(result.get("id",""))
 var name:String=str(app.rules.spec(id).get("name",id))
 var cost:int=int(app.rules.spec(id).get("cost",0))
 var success:bool=bool(result.get("success",false))
 var cancelled:bool=bool(result.get("search_cancelled",false))
 tint=UIStyle.TEAL if success else UIStyle.OXIDE
 headline.text=name+" · "+("搜寻已中断" if cancelled else "已生效" if success else "施放被中断" if result.get("reason","")=="interrupted" else "被抵抗")
 var effect:String="原行动继续；本次扣费不退还。"
 if cancelled:effect="此次搜寻机会已占用，无完成收入；重试将重新计时。"
 elif success:
  effect={"TEMP":"当前行动减速；搜寻进度仍会增长。","TINNITUS":"暂时停止行动；保留当前搜寻进度。","FEAR":"精神下降，当前目标暂缓。","CONTROL":"自主行动暂交玩家；结束后宿主自行重判。","JOY":"精神恢复；不取消已成立的行动。"}.get(id,"身体反应已发生；结束后宿主继续自主行动。")
  if app.rules.mode=="combat":effect={"TEMP":"短暂提高移动速度；没有无敌效果。","TINNITUS":"短暂停步后重判路线；敌人追踪仍保留。","FEAR":"精神下降；短暂远离已感知威胁。","GUT":"降低上身；仍按实际攻击轨迹判断命中。","SKIN":"向选定方向侧挪；不穿过实体障碍。","WITHDRAW":"撤回手臂；不能解除已经成立的抓握。"}.get(id,effect)
 detail.text="消耗 %d 神经元 · 施放后余额 %d\n%s"%[cost,app.rules.neurons,effect]
 headline.add_theme_color_override("font_color",tint)
 remaining=4.5
 receipt_panel.show();headline.show();detail.show()
 var trace:Dictionary={"event":result.get("event_id",""),"skill":id,"target":target,"success":success,"reason":result.get("reason",""),"cancelled":cancelled,"search_id":app.rules._search_id,"attempts":app.rules.search_attempts,"completed":app.rules.search_count,"neurons":app.rules.neurons,"power":result.get("power",0),"resistance":result.get("resistance",0),"key_owner":app.session.data.key_owner}
 receipts.append(trace)
 if receipts.size()>24:receipts.pop_front()
 print("INTERVENTION "+JSON.stringify(trace))
 queue_redraw()

func _process(delta:float) -> void:
 if app==null or not app.campaign_ready:return
 var active:bool=app.rules.search_active
 progress.visible=active and not app.menu.visible and app.tutorial_ui==null and app.opening_ui==null
 activity.visible=progress.visible
 if active:
  var name:String="当前目标"
  if app.target_index>=0:name=str(app.layout.furniture[app.target_index].name)
  var ratio:float=clampf(app.rules.search_elapsed/maxf(0.01,app.rules.search_duration),0,1)
  progress.value=ratio*100.0
  activity.text="自主搜寻 · %s  %d%%  |  已用机会 %d/%d"%[name,int(ratio*100),app.rules.search_attempts,app.rules.search_limit]
  if app.rules.control_left>0:activity.text=activity.text.replace("自主搜寻","掌控搜寻")
 if not app.world_paused():remaining=maxf(0,remaining-delta)
 var show_receipt:bool=remaining>0 and not app.menu.visible and app.tutorial_ui==null and app.opening_ui==null
 var top:float=153
 if app.father_prompt!=null and app.father_prompt.visible:top=minf(450,app.father_prompt.position.y+app.father_prompt.size.y+12)
 receipt_panel.position.y=top;headline.position.y=top+11;detail.position.y=top+45
 receipt_panel.visible=show_receipt;headline.visible=show_receipt;detail.visible=show_receipt
 queue_redraw()

func _draw() -> void:
 if app==null or remaining<=3.6 or app.menu.visible or app.world_paused():return
 var center:Vector2=app.world_viewport.get_canvas_transform()*app.layout.project(app.hero_pos)
 center*=Vector2(1280,720)/Vector2(app.world_viewport.size)
 var alpha:float=clampf((remaining-3.6)/0.9,0,1)*0.65
 draw_arc(center,21,0,TAU,40,Color(tint,alpha),2,true)
