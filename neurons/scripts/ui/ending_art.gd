extends Control
## Read-only pictures follow actual E1/E2/E3 phases. No completion or clock writes.
const Art=preload("res://scripts/ui/narrative_art.gd")
var app
var current:Dictionary={}
func _ready() -> void:
 mouse_filter=Control.MOUSE_FILTER_IGNORE;size=Vector2(1280,720);z_index=-10
func _process(_delta:float) -> void:
 current={}
 if app==null or not is_instance_valid(app):return
 if app.hidden_route!=null and app.hidden_route.data.get("status","")=="ending":
  var frame:Dictionary=app.hidden_route.ending_frame()
  if frame.get("phase","")=="bed":current={"kind":"bed","progress":float(frame.get("wake",0)),"ending":"E1"}
 if current.is_empty() and app.street!=null:
  var ending:Dictionary=app.street.data.get("ending",{})
  var phase:String=str(ending.get("phase",""))
  if phase=="wake":current={"kind":"bed","progress":clampf(float(ending.get("elapsed",0))/3.0,0,1),"ending":str(ending.get("id",""))}
  elif phase=="planet" and ending.get("id","")=="E2":current={"kind":"planet","progress":clampf(float(ending.get("elapsed",0))/2.0,0,1),"ending":"E2"}
 visible=not current.is_empty();queue_redraw()
func _draw() -> void:
 if current.is_empty():return
 draw_rect(Rect2(0,0,1280,720),Color("101b20"))
 var picture:String="E2_ORIGIN_GROUND"
 if current.kind=="bed":
  picture="ENDING_HOSPITAL_RESTING" if current.progress<.38 else "ENDING_EYES_CLOSED" if current.progress<.60 else "ENDING_EYES_OPEN"
 Art.paint(self,Art.texture(picture),Rect2(0,0,1280,720),true)
