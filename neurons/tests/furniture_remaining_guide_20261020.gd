extends SceneTree
const Guide=preload("res://tests/furniture_geometry_guides_20261020.gd")
const Bedroom=preload("res://scripts/world/bedroom_layout.gd")
func _initialize() -> void:
 root.size=Vector2i(1536,1536);root.content_scale_size=Vector2i(1536,1536);root.transparent_bg=true
 call_deferred("run")
func run() -> void:
 var layout=Bedroom.new();var by_id:Dictionary={}
 for item:Dictionary in layout.furniture:by_id[str(item.id)]=item
 var entries:Array=[]
 var stool:Dictionary=by_id.stool.duplicate(true);stool.height=.44*78
 entries.append({"id":"stool","item":stool,"role":"body"})
 var parcel:Dictionary=stool.duplicate(true);parcel.id="stool_parcel";parcel.name="小包裹";parcel.kind="box";parcel.rect=(stool.rect as Rect2).grow(-.035);parcel.height=.3*78
 entries.append({"id":"stool_parcel","item":parcel,"role":"body"})
 for id in ["box_lower","box_upper"]:
  var item:Dictionary=by_id.box.duplicate(true);item.id=id;item.name="塑料储物箱" if id=="box_lower" else "纸箱";item.kind="box";item.height=.45*78;item.color=Color("7b9194") if id=="box_lower" else Color("b49b78")
  entries.append({"id":id,"item":item,"role":"body"})
 entries.append({"id":"storage","item":by_id.storage.duplicate(true),"role":"body"})
 var coat:Dictionary=by_id.rack.duplicate(true);coat.id="rack_coat";coat.height=1.4*78
 entries.append({"id":"rack_coat","item":coat,"role":"coat"})
 var book:Dictionary={"id":"bedside_book","name":"","kind":"box","rect":Rect2(0,0,.23,.17),"height":3.0,"color":Color("687d82")}
 entries.append({"id":"bedside_book","item":book,"role":"body"})
 var clock:Dictionary={"id":"bedside_clock","name":"","kind":"clock","rect":Rect2(0,0,.18,.1),"height":.22*78,"color":Color("bab99e")}
 entries.append({"id":"bedside_clock","item":clock,"role":"clock"})
 var paper:Dictionary={"id":"desk_paper","name":"","kind":"paper","rect":Rect2(0,0,.27,.18),"height":3.0,"color":Color("ccc8b3")}
 entries.append({"id":"desk_paper","item":paper,"role":"paper"})
 var panel=Guide.GuideCanvas.new();panel.layout=layout;panel.items=entries;root.add_child(panel)
 for frame in range(3):await process_frame
 await RenderingServer.frame_post_draw
 var folder:String=ProjectSettings.globalize_path("res://../docs/validation/asset_production_20261020/furniture")
 var image:Image=root.get_texture().get_image();image.save_png(folder.path_join("atlas_c_geometry_guide.png"))
 var file=FileAccess.open(folder.path_join("geometry_guide_c.json"),FileAccess.WRITE);file.store_string(JSON.stringify({"coordinate_canvas_px":[1536,1536],"actual_image_px":[image.get_width(),image.get_height()],"items":panel.records,"source":"Original remaining bedroom slots plus separately moving contents; no additional gameplay object IDs or placements."},"  "));file.close()
 print("FURNITURE_REMAINING_GUIDE 9 layers")
 quit(0)
