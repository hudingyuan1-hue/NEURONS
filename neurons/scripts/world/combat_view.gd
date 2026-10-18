extends RefCounted
## Code-drawn 2D trial; all figures remain explicit placeholders.
var canvas
var app
var battle
var font:Font

func draw(target,owner,catalog) -> void:
 canvas=target;app=owner;battle=app.active_battle();font=target.font
 var layout=app.layout;var deep:bool=battle.map.deep(app.room_id)
 canvas.draw_rect(Rect2(-1800,-1200,4500,3000),Color("263039") if deep else Color("211f2a"))
 var corners:Array=[]
 for p in [Vector2.ZERO,Vector2(layout.world_size().x,0),layout.world_size(),Vector2(0,layout.world_size().y)]:corners.append(layout.project(p))
 canvas.poly(corners,Color("b0b9ad") if deep else Color("645455"))
 for row in range(1,16):canvas.draw_line(layout.project(Vector2(0,row*.475)),layout.project(Vector2(11.2,row*.475)),Color(0.4,0.44,0.43,.17),1)
 if battle.chapter_id==6:draw_street_surfaces()
 canvas.draw_polyline(PackedVector2Array(corners+[corners[0]]),Color("b8beb1"),4)
 if layout.cold_zone.has_area():zone(layout.cold_zone,Color(.3,.63,.8,.26),"局部冷区 · 双方移速80%")
 if app.room_id=="brainstem":
  var phase:String=battle.pulse_phase()
  zone(layout.pulse_zone,{"warning":Color(.93,.73,.31,.27),"active":Color(.97,.86,.55,.65),"interval":Color(.5,.61,.65,.12)}[phase],{"warning":"脉冲预警 · 离开亮带","active":"脉冲冲击","interval":"脉冲间隔"}[phase])
 for f in layout.decor:
  if float(f.height)>5:continue
  var rect:Rect2=f.rect
  canvas.poly([layout.project(rect.position),layout.project(Vector2(rect.end.x,rect.position.y)),layout.project(rect.end),layout.project(Vector2(rect.position.x,rect.end.y))],Color("77696b") if not deep else Color("b0b8ad"))
 var ordered:Array=[]
 for f in layout.furniture+layout.decor:
  if f in layout.decor and float(f.height)<=5:continue
  ordered.append({"kind":"prop","data":f,"depth":layout.project((f.rect as Rect2).end).y})
 ordered.append({"kind":"hero","depth":layout.project(app.hero_pos).y})
 if battle.chapter_id==6:
  var bed:Dictionary=battle.data.get("lateral_bed",{})
  if not bed.is_empty() and bed.room==app.room_id and battle.data.actors.transporter_asylum.present:ordered.append({"kind":"lateral_bed","depth":layout.project(battle.vector(bed.center)).y})
  var box:Dictionary=battle.data.get("box",{})
  if not box.is_empty() and box.room==app.room_id and (battle.data.actors.labor.present or box.released):ordered.append({"kind":"box","depth":layout.project(battle.vector(box.pos)).y})
 for id in battle.data.get("actors",{}):
  var a:Dictionary=battle.data.actors[id]
  if a.present and a.room==app.room_id:ordered.append({"kind":"actor","id":id,"depth":layout.project(battle.position(id)).y})
 ordered.sort_custom(func(a,b):return a.depth<b.depth)
 for entry in ordered:
  if entry.kind=="prop":
   var f:Dictionary=entry.data
   if f.get("kind","")=="gate":draw_gate(f)
   elif f.get("kind","")=="rack":draw_rack(f)
   elif f.get("kind","")=="cleaner_cart":
    canvas.prism(f.rect,float(f.height),Color("757b78"))
    var cart_top:Vector2=layout.project(f.rect.get_center())-Vector2(0,float(f.height))
    canvas.draw_circle(cart_top,12,Color("414951"));canvas.draw_line(cart_top-Vector2(12,5),cart_top+Vector2(12,5),Color("9f9b89"),3)
   else:canvas.prism(f.rect,float(f.height),Color("a5afa8") if deep else Color("837172"))
   text(layout.project((f.rect as Rect2).get_center())-Vector2(0,float(f.height)+6),str(f.name),12)
  elif entry.kind=="lateral_bed":
   var bed:Dictionary=battle.data.lateral_bed
   draw_bed(battle.lateral_bed.anchor(battle.vector(bed.center),battle.vector(bed.axis)),battle.vector(bed.axis))
   var center:Vector2=layout.project(battle.vector(bed.center))
   var carrier:Dictionary=battle.data.actors.transporter_asylum
   if carrier.hp>0:
    for side in [-.12,.12]:
     var rail:Vector2=layout.project(battle.vector(bed.center)-battle.vector(bed.push)*.45+battle.vector(bed.axis)*side)-Vector2(0,48)
     canvas.draw_line(layout.project(battle.position("transporter_asylum"))-Vector2(0,74),rail,Color("b6b29d"),4)
   text(center-Vector2(0,61),"离院",13)
   if bed.phase in ["windup","attack"]:
    var goal:Vector2=layout.project(battle.vector(bed.center)+battle.vector(bed.push)*(1.0-float(bed.distance)))
    canvas.draw_line(center,goal,Color("d9b575"),5)
  elif entry.kind=="box":draw_box(battle.data.box)
  elif entry.kind=="hero":
   var at:Vector2=layout.project(app.hero_pos)
   var crouch:float=.56 if app.rules.reaction_skill=="GUT" and app.rules.reaction_left>.2 else 1.0
   var frame:Dictionary=catalog.actor_frame("hit" if app.hero_state=="tinnitus" else app.hero_state,app.hero_facing,app.world_visual_time)
   var scale_value:=Vector2(2.1,2.1*crouch)
   canvas.draw_circle(at,17,Color(0,0,0,.25))
   canvas.draw_texture_rect_region(frame.texture,Rect2(at-frame.foot*scale_value,frame.size*scale_value),frame.source)
   if app.hero_state=="tinnitus":
    canvas.draw_line(at+Vector2(12,-52),at+Vector2(22,-80),Color("a7b8b8"),5)
    canvas.draw_line(at+Vector2(22,-80),at+Vector2(9,-91),Color("c4bea8"),4)
    text(at-Vector2(0,112),"停步 · 侧头捂耳（姿态占位）",14)
  else:actor(str(entry.id))
 if battle.chapter_id==6:draw_main_ending()
 for id in app.visible_doors:
  var at:Vector2=layout.project(app.door_point(str(id)))
  canvas.draw_circle(at,13,Color("2f5055"));canvas.draw_arc(at,13,0,TAU,32,Color("d3d9bd"),2)
  text(at-Vector2(0,20),battle.map.title(str(id)),14)

func text(at:Vector2,value:String,size_px:int) -> void:
 var width:float=font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,size_px).x
 canvas.draw_rect(Rect2(at-Vector2(width*.5+4,size_px),Vector2(width+8,size_px+5)),Color(.07,.1,.12,.84))
 canvas.draw_string(font,at-Vector2(width*.5,0),value,HORIZONTAL_ALIGNMENT_LEFT,-1,size_px,Color("e8e3cf"))

func zone(rect:Rect2,color:Color,label:String) -> void:
 var points:Array=[]
 for p in [rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)]:points.append(app.layout.project(p))
 canvas.poly(points,color);canvas.draw_polyline(PackedVector2Array(points+[points[0]]),Color(color,0.85),2)
 text(app.layout.project(rect.position)-Vector2(0,12),label,13)

func actor(id:String) -> void:
 var a:Dictionary=battle.data.actors[id];var s:Dictionary=battle.spec(id)
 var at:Vector2=app.layout.project(battle.position(id))
 if id=="assistant":draw_bed(battle.position(id),battle.vector(a.direction))
 var color:Color=Color("7dafa5") if s.relation=="friend" else Color("c08f82") if a.hostile else Color("a7a9c2")
 if battle.chapter_id==6 and id=="wheelchair":draw_chair(at)
 if int(a.hp)<=0:
  canvas.draw_line(at-Vector2(25,6),at+Vector2(25,6),color.darkened(.5),9);return
 var h:float=55 if id in ["cat","dog"] else 133
 var action_clock:float=float(a.elapsed)
 if id=="cat" and a.phase=="windup":h*=.55
 if id=="twitch" and a.phase=="windup":at.y-=absf(sin(action_clock/1.2*PI*2))*9
 if id=="reverse":
  var facing:Vector2=battle.vector(a.direction)
  canvas.draw_line(at-Vector2(0,65),app.layout.project(battle.position(id)-facing*.4)-Vector2(0,65),Color("c3b1a0"),5)
 canvas.draw_circle(at,17,Color(.03,.05,.07,.26))
 canvas.poly([at+Vector2(-18,-h*.7),at+Vector2(18,-h*.7),at+Vector2(24,-h*.2),at+Vector2(-24,-h*.2)],color)
 canvas.draw_circle(at+Vector2(0,-h*.88),h*.12,Color("c4bea8"))
 for side in [-1,1]:canvas.draw_line(at+Vector2(side*9,-h*.2),at+Vector2(side*12,0),color.darkened(.15),8)
 if id=="double_head":
  canvas.draw_circle(at+Vector2(-14,-h*.88),13,Color("b9b39f"))
  canvas.draw_circle(at+Vector2(14,-h*.88),13,Color("b9b39f"))
  if not a.hostile:canvas.draw_line(at+Vector2(-20,-h*.5),at+Vector2(10,-h*.74),color.darkened(.2),7);canvas.draw_line(at+Vector2(20,-h*.5),at+Vector2(-10,-h*.74),color.darkened(.2),7)
 if id=="double_face" and (a.get("face_turned",false) or float(a.get("face_turn_progress",0))>0):
  var progress:float=1.0 if a.get("face_turned",false) else float(a.face_turn_progress)
  canvas.draw_arc(at+Vector2(0,-h*.88),15,-PI*.5,-PI*.5+progress*TAU,24,Color("80566d"),4)
  if a.get("face_turned",false):
   for side in [-1,1]:canvas.draw_circle(at+Vector2(side*5,-h*.88),2,Color("3e3040"))
 if id=="corner" and a.phase=="point":canvas.draw_line(at-Vector2(0,65),app.layout.project(battle.position(id)+battle.vector(a.direction)*.8)-Vector2(0,65),color,6)
 if id=="twitch" and a.phase=="windup" and a.get("echo_knee",false):canvas.draw_line(at+Vector2(-10,-30),at+Vector2(-25,-15),Color("d3c2a0"),7)
 if id=="dog":canvas.draw_line(at+Vector2(-16,-36),at+Vector2(16,-36),Color("ae4e4b"),5)
 if battle.chapter_id==6:draw_material_pose(id,at,h);draw_display_pose(id,at,h)
 if a.phase in ["windup","attack","recover","grip"]:
  var direction:Vector2=battle.vector(a.direction)
  var attack:Dictionary=battle.config.attacks[str(s.attack)]
  var end:Vector2=app.layout.project(battle.position(id)+direction*float(attack.reach))
  var warning:Color=Color("edc37e") if a.phase=="windup" else Color("d18f7c")
  canvas.draw_line(at,end,Color(warning,.5),5)
  var reach:float=clampf(float(a.elapsed)/float(attack.windup),0,1) if a.phase=="windup" else 1.0 if a.phase in ["attack","grip"] else .25
  canvas.draw_line(at-Vector2(0,h*.55),at.lerp(end,reach)-Vector2(0,h*.55),warning,7)
 text(at-Vector2(0,h+12),str(s.get("display_name",s.name))+" · "+{"idle":"待机","windup":"起手","attack":"出手","recover":"收招","grip":"抓握","display":"展示","point":"指向目视危险" if id=="speaker" else "指路","bandage":"包扎","push":"推车","cloth":"展开黑布","mimic":"模仿","drug_hold":"扣头","box_prepare":"抬盒","bed_turn":"过门转向","bed_travel":"推床随行","bed_retreat":"退离门口","tear":"撕扯随身纸条","paper_hold":"攥住残片","box_flip":"翻起空盒","box_number":"查看编号","box_stow":"整理空盒","cart_park":"走向侧停清洁车","pick_label":"拾取地面标签","wipe":"擦拭接触区域","bag_label":"送入随车污物袋","bag_seal":"封口","walk":"走近痕迹","display_retreat":"受伤后退避","stamp":"盖章","number_show":"展示号码纸","paper_stow":"收回号码纸","number_front":"编号正面","number_turn":"转身","number_back":"另一面编号","chair_aside":"调椅让路","entry_point":"指向原入口","band_raise":"举起自身腕带","protect_photo":"护住照片","protect_body":"收臂护身","dressing_open":"掀开敷料","dressing_show":"露出注销标记","dressing_cover":"按回敷料","branch_point":"指向维护入口","clip_read":"查看转运夹","cloth_raise":"抬起黑布","cloth_close":"收拢黑布","mimic_write":"记录板书写"}.get(str(a.phase),str(a.phase)),14)

func draw_street_surfaces() -> void:
 for item in battle.data.get("materials",{}).get("surfaces",{}).values():
  if item.room!=app.room_id or not battle.materials.available(item):continue
  var at:Vector2=app.layout.project(battle.vector(item.pos));var alpha:float=1.0-float(item.progress)
  if item.kind=="label":
   canvas.draw_rect(Rect2(at-Vector2(9,4),Vector2(18,8)),Color("c5ba96"))
   canvas.draw_line(at-Vector2(6,0),at+Vector2(5,0),Color("6f6b67"),2)
  else:
   canvas.draw_line(at-Vector2(16,2),at+Vector2(16,3),Color(Color("754c52") if item.kind=="blood" else Color("8d8574"),alpha*.8),5)

func draw_material_pose(id:String,at:Vector2,h:float) -> void:
 var a:Dictionary=battle.data.actors[id];var all:Dictionary=battle.data.get("materials",{})
 if all.is_empty():return
 if id in ["speaker","stitched"]:
  var s:Dictionary=all.speaker if id=="speaker" else all.stitched
  var progress:float=clampf(float(s.tear)/float(battle.config.test_parameters.paper_tear_s),0,1)
  if id=="speaker":
   canvas.draw_polyline(PackedVector2Array([at-Vector2(15,h*.6),at-Vector2(25,h*.4),at-Vector2(17,h*.34)]),Color("484851"),3)
  var paper:Vector2=at+Vector2(22*progress,-h*(.72-.27*progress))
  canvas.draw_rect(Rect2(paper-Vector2(13,5),Vector2(26,10)),Color("cbbfa0"))
  canvas.draw_line(at+Vector2(14,-h*.5),paper,Color("ac9d88"),5)
  if progress<1:canvas.draw_line(paper-Vector2(8,0),paper+Vector2(8,0),Color("796a65"),2)
  if id=="speaker" and a.phase=="point":canvas.draw_line(at-Vector2(0,h*.5),app.layout.project(battle.position(id)+battle.vector(a.direction)*.9)-Vector2(0,h*.5),Color("91b5a1"),6)
 elif id=="treatment_pharmacist":
  for side in [-1,0,1]:canvas.draw_rect(Rect2(at+Vector2(side*11-4,-h*.5),Vector2(8,15)),Color("b6b7a0"))
  if a.phase in ["box_flip","box_number"]:
   var p:Vector2=at+Vector2(25,-h*.57)
   canvas.draw_rect(Rect2(p-Vector2(9,7),Vector2(18,14)),Color("c8c2a6"))
   canvas.draw_rect(Rect2(p-Vector2(6,4),Vector2(12,7)),Color("53575e"))
   canvas.draw_line(p-Vector2(7,-5),p+Vector2(6,5),Color("8e7e70"),2)
 elif id=="cleaner":
  if a.phase in ["wipe","pick_label"]:canvas.draw_line(at-Vector2(0,h*.45),at+Vector2(15,-7),Color("b7b4a0"),6)
  if a.phase=="bag_label":canvas.draw_rect(Rect2(at+Vector2(16,-h*.4),Vector2(16,8)),Color("c5ba96"))
  # Only the original already held by this same cleaner is displayed; never copy hero inventory.
  if str(app.rules.owners.get("asylum_corpse_wristband",""))=="asylum_cleaner_bucket":canvas.draw_arc(at+Vector2(20,-h*.3),7,0,TAU,16,Color("c2bca0"),3)

func draw_box(box:Dictionary) -> void:
 var at:Vector2=battle.vector(box.pos);var height:float=float(box.height)*78;var bottom:Array=[];var top:Array=[]
 canvas.draw_circle(app.layout.project(at),13,Color(0,0,0,.2))
 for offset in [Vector2(-.16,-.14),Vector2(.16,-.14),Vector2(.16,.14),Vector2(-.16,.14)]:
  bottom.append(app.layout.project(at+offset)-Vector2(0,height));top.append(app.layout.project(at+offset)-Vector2(0,height+18))
 for i in range(4):canvas.poly([bottom[i],bottom[(i+1)%4],top[(i+1)%4],top[i]],Color("9c896d"))
 canvas.poly(top,Color("baaa86"));canvas.draw_line(top[0].lerp(top[1],.5),top[3].lerp(top[2],.5),Color("d6c6a3"),3)

func draw_bed(at:Vector2,direction:Vector2) -> void:
 var footprint:PackedVector2Array=battle.Bed.polygon(at,direction);var ground:Array=[];var top:Array=[]
 for p in footprint:ground.append(app.layout.project(p));top.append(app.layout.project(p)-Vector2(0,48))
 for i in range(4):
  var j:int=(i+1)%4
  canvas.poly([ground[i],ground[j],top[j],top[i]],Color("718982"))
 canvas.poly(top,Color("a9b9ab"));canvas.draw_polyline(PackedVector2Array(top+[top[0]]),Color("d0d6bd"),2)
 for t in [.3,.65]:canvas.draw_line(top[0].lerp(top[1],t),top[3].lerp(top[2],t),Color("675c62"),5)

func draw_rack(prop:Dictionary) -> void:
 var center:Vector2=app.layout.project(prop.rect.get_center());var swing:float=float(battle.data.get("rack_sound",{}).get("swing",0))
 var sway:float=sin(swing*26.0)*swing*9
 canvas.draw_line(center+Vector2(-20,0),center+Vector2(20,0),Color("6c7770"),5)
 canvas.draw_line(center,center-Vector2(0,130),Color("6c7770"),4)
 canvas.draw_line(center+Vector2(-24,-125),center+Vector2(24,-125),Color("abb6ac"),4)
 canvas.poly([center+Vector2(-22+sway,-119),center+Vector2(22+sway,-119),center+Vector2(28+sway,-35),center+Vector2(-25+sway,-35)],Color("c3c7bb"))

func draw_main_ending() -> void:
 var e:Dictionary=battle.data.get("ending",{})
 if e.is_empty():return
 var at:Vector2=app.layout.project(app.hero_pos)
 canvas.draw_rect(Rect2(at-Vector2(1800,1000),Vector2(3600,2000)),Color(.07,.12,.12,.9))
 var label:String={"registration":"机构登记：自行离院","dialogue":"终点门内 · 原出口对白","wake":"现实病床 · 身体睁眼（演出占位）","planet":"来处星球 · 玩家恢复感知（演出占位）","complete":"本次流程结束"}.get(str(e.phase),"")
 text(at-Vector2(0,150),label,24)
 if e.phase=="wake":text(at-Vector2(0,90),"角色接续身体" if e.id=="E2" else "玩家接续身体",20)

func draw_gate(prop:Dictionary) -> void:
 var center:Vector2=prop.rect.get_center();var h:float=float(prop.height)
 var a:Vector2=center+Vector2(0,-.85);var b:Vector2=center+Vector2(0,.85)
 for at in [a,b]:canvas.prism(Rect2(at-Vector2(.1,.1),Vector2(.2,.2)),h,Color("adaca0"))
 canvas.draw_line(app.layout.project(a)-Vector2(0,h),app.layout.project(b)-Vector2(0,h),Color("c8c6af"),12)

func draw_chair(at:Vector2) -> void:
 var footprint:Rect2=battle.displays.chair_rect(battle.position("wheelchair"));var points:Array=[]
 for p in [footprint.position,Vector2(footprint.end.x,footprint.position.y),footprint.end,Vector2(footprint.position.x,footprint.end.y)]:points.append(app.layout.project(p))
 canvas.poly(points,Color("4e555e"))
 for side in [-1,1]:
  canvas.draw_arc(at+Vector2(side*24,-17),19,0,TAU,24,Color("b0b1a4"),4)
  canvas.draw_line(at+Vector2(side*18,-54),at+Vector2(side*23,-16),Color("858f8f"),5)
 canvas.draw_line(at+Vector2(-19,-23),at+Vector2(19,-23),Color("9fa49a"),5)

func draw_display_pose(id:String,at:Vector2,h:float) -> void:
 if id in ["informant","head_nurse"] and battle.data.actors[id].phase=="point":
  var a:Dictionary=battle.data.actors[id]
  canvas.draw_rect(Rect2(at+Vector2(-17,-h*.6),Vector2(22,26)),Color("c2b99b"))
  canvas.draw_line(at+Vector2(13,-h*.55),app.layout.project(battle.position(id)+battle.vector(a.direction)*.85)-Vector2(0,h*.55),Color("b9af97"),6)
 if id not in battle.displays.IDS:return
 var a:Dictionary=battle.data.actors[id];var s:Dictionary=battle.displays.state(id)
 var paper:Color=Color("cdc2a1");var ink:Color=Color("5e5960");var skin:Color=Color("b9af97")
 if id=="register_nurse":
  var sheet:Vector2=at+Vector2(27,-h*(.58 if a.phase=="number_show" else .32))
  canvas.draw_rect(Rect2(sheet-Vector2(13,10),Vector2(26,20)),paper)
  canvas.draw_line(at+Vector2(13,-h*.5),sheet,skin,5)
  if a.phase=="stamp":canvas.draw_rect(Rect2(sheet+Vector2(-5,-18),Vector2(9,12)),Color("864e53"))
  if a.phase=="number_show":text(sheet+Vector2(0,4),"编号待核",9)
 elif id=="back":
  var top:Vector2=at-Vector2(0,h*.57)
  canvas.draw_rect(Rect2(top-Vector2(13,7),Vector2(26,14)),paper)
  text(top+Vector2(0,4),"面B" if s.turned else "面A",10)
  if a.phase=="number_turn":canvas.draw_arc(at-Vector2(0,h*.85),16,0,float(s.elapsed)/float(battle.config.test_parameters.face_turn_s)*TAU,20,ink,3)
 elif id in ["wheelchair","transport_patient"]:
  var protect:bool=a.phase in ["protect_photo","protect_body"]
  var hand:Vector2=at+Vector2(3 if protect else 27,-h*(.55 if protect else .47))
  canvas.draw_line(at+Vector2(12,-h*.53),hand,skin,6)
  if id=="wheelchair":
   canvas.draw_rect(Rect2(hand-Vector2(10,9),Vector2(20,18)),paper)
   canvas.draw_circle(hand+Vector2(0,-2),4,ink)
   if protect:canvas.draw_line(at+Vector2(-12,-h*.5),hand+Vector2(7,4),skin,6)
  else:
   canvas.draw_line(at+Vector2(-16,-h*.25),at+Vector2(14,-h*.18),paper,5)
   canvas.draw_arc(hand,7,0,TAU,16,paper,3)
  if a.phase=="entry_point":canvas.draw_line(hand,app.layout.project(battle.position(id)+battle.vector(a.direction)*.65)-Vector2(0,h*.5),skin,5)
 elif id=="postop":
  var mark:Vector2=at+Vector2(9,-h*.52)
  canvas.draw_rect(Rect2(mark-Vector2(12,10),Vector2(24,20)),Color("705d63") if a.phase=="dressing_show" else paper)
  canvas.draw_line(at+Vector2(-13,-h*.55),mark+Vector2(-9,-12 if a.phase=="dressing_show" else 0),skin,5)
  if a.phase=="dressing_show":text(mark+Vector2(0,4),"注销",11)
 elif id=="triage":
  canvas.draw_line(at+Vector2(-13,-h*.88),at+Vector2(13,-h*.88),Color("96525b"),4)
  canvas.draw_rect(Rect2(at+Vector2(-12,-h*.59),Vector2(24,25)),paper)
  if a.phase=="clip_read":text(at-Vector2(0,h*.4),"批次栏",10)
  elif a.phase=="branch_point":canvas.draw_line(at-Vector2(0,h*.5),app.layout.project(battle.position(id)+battle.vector(a.direction)*.8)-Vector2(0,h*.5),skin,6)
 elif id=="blind":
  canvas.draw_line(at+Vector2(-12,-h*.88),at+Vector2(12,-h*.88),Color("2a2a36"),6)
  if a.phase in ["cloth","cloth_raise","cloth_close"]:
   var left:Vector2=app.layout.project(battle.position(id)+Vector2(-.6,.2));var right:Vector2=app.layout.project(battle.position(id)+Vector2(.6,1.2))
   var raised:float=1.0 if a.phase=="cloth" else clampf(float(s.elapsed)/.3,0,1) if a.phase=="cloth_raise" else 1.0-clampf(float(s.elapsed)/.3,0,1)
   canvas.poly([left-Vector2(0,12+90*raised),right-Vector2(0,12+90*raised),right-Vector2(0,12),left-Vector2(0,12)],Color("292a37"))
   canvas.draw_line(at-Vector2(0,h*.55),left-Vector2(0,12+90*raised),skin,5)
 elif id=="mimic":
  var board:Vector2=at-Vector2(0,h*.43)
  canvas.draw_rect(Rect2(board-Vector2(19,14),Vector2(38,28)),paper)
  if a.phase=="mimic":
   var offset:Vector2=Vector2(22,-h*.85) if a.get("mimic","") in ["tinnitus","give","scratch"] else Vector2(29,-h*.4)
   canvas.draw_line(at+Vector2(12,-h*.58),at+offset,skin,6)
  elif a.phase=="mimic_write":
   var t:float=clampf(float(s.elapsed)/float(battle.config.test_parameters.mimic_write_s),0,1)
   canvas.draw_line(board-Vector2(12,0),board+Vector2(-12+24*t,0),ink,2)
   canvas.draw_line(at+Vector2(15,-h*.6),board+Vector2(-12+24*t,0),skin,5)
  elif s.get("last_written",false):text(board+Vector2(0,4),"自主行为",10)
