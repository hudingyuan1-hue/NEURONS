extends Control
## Quiet code-native title painting; never a screenshot of interactive controls.
const Style=preload("res://scripts/ui/ui_style.gd")
const Art=preload("res://scripts/ui/narrative_art.gd")
var variant:String="title"
func _ready() -> void:
 mouse_filter=Control.MOUSE_FILTER_IGNORE
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 queue_redraw()
func _draw() -> void:
 draw_rect(Rect2(0,0,1280,720),Style.PAPER)
 var portrait:bool=variant=="profile"
 var art:Texture2D=Art.texture("PLAYER_PROFILE" if portrait else "TITLE_DOOR")
 if art!=null:
  draw_rect(Rect2(632,0,648,720),Color("b8b2ab") if portrait else Style.NIGHT)
  Art.paint(self,art,Rect2(700,80,500,570) if portrait else Rect2(632,0,648,720),not portrait)
  draw_line(Vector2(64,78),Vector2(584,78),Style.RULE,1,true)
  draw_line(Vector2(64,644),Vector2(584,644),Style.RULE,1,true)
  draw_line(Vector2(616,80),Vector2(616,644),Color("d1cfbb"),1,true)
  return
 if variant!="title":return
 # Large deliberate painted planes, a cool recess and one warm aperture.
 draw_colored_polygon(PackedVector2Array([Vector2(655,0),Vector2(1280,0),Vector2(1280,720),Vector2(878,720),Vector2(632,463)]),Color("51685f"))
 draw_colored_polygon(PackedVector2Array([Vector2(785,93),Vector2(1220,56),Vector2(1220,483),Vector2(785,537)]),Color("829184"))
 draw_colored_polygon(PackedVector2Array([Vector2(785,93),Vector2(825,134),Vector2(825,521),Vector2(785,537)]),Color("3c5752"))
 draw_colored_polygon(PackedVector2Array([Vector2(825,134),Vector2(1220,95),Vector2(1220,483),Vector2(825,521)]),Color("304f4b"))
 draw_colored_polygon(PackedVector2Array([Vector2(935,175),Vector2(1070,164),Vector2(1070,414),Vector2(935,431)]),Color("c0ae80"))
 draw_colored_polygon(PackedVector2Array([Vector2(958,193),Vector2(1052,185),Vector2(1052,410),Vector2(958,422)]),Color("ddd0a5"))
 draw_colored_polygon(PackedVector2Array([Vector2(935,431),Vector2(1070,414),Vector2(1226,665),Vector2(1118,720),Vector2(850,720)]),Color("8d9275"))
 # A handful of broad, irregular painterly edge accents rather than noise.
 for values in [[845,112,1202,83],[840,527,1194,489],[781,70,809,71]]:
  draw_line(Vector2(values[0],values[1]),Vector2(values[2],values[3]),Color("a4ac96"),3,true)
 draw_line(Vector2(64,78),Vector2(584,78),Style.RULE,1,true)
 draw_line(Vector2(64,644),Vector2(584,644),Style.RULE,1,true)
 draw_line(Vector2(616,80),Vector2(616,644),Color("d1cfbb"),1,true)
