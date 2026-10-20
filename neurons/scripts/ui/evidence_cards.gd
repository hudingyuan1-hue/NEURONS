extends RefCounted
## Text comes from an actual recorded observation. The UI never certifies a claim.
const Style=preload("res://scripts/ui/ui_style.gd")
static func add(parent:VBoxContainer,kind:String,text:String,source:String="",portrait:Texture2D=null,photo:Texture2D=null) -> PanelContainer:
 var card:=PanelContainer.new();card.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 card.set_meta("record_kind",kind);card.set_meta("record_source",source)
 var surface:StyleBoxFlat=Style.surface("light")
 surface.border_width_left=3;surface.shadow_size=0
 surface.border_color=Style.OCHRE if kind.contains("机构") else Style.TEAL if kind.contains("亲历") else Style.RULE
 card.add_theme_stylebox_override("panel",surface);parent.add_child(card)
 var row:=HBoxContainer.new();row.add_theme_constant_override("separation",20);card.add_child(row)
 if portrait!=null:
  var image:=TextureRect.new();image.texture=portrait;image.custom_minimum_size=Vector2(102,134)
  image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
  image.mouse_filter=Control.MOUSE_FILTER_IGNORE;row.add_child(image)
 var column:=VBoxContainer.new();column.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 column.add_theme_constant_override("separation",8);row.add_child(column)
 var badge:=Label.new();badge.text=kind;badge.add_theme_font_size_override("font_size",14)
 badge.add_theme_color_override("font_color",surface.border_color);column.add_child(badge)
 var body:=Label.new();body.text=text;body.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 body.custom_minimum_size.x=850 if portrait!=null else 970
 body.add_theme_font_size_override("font_size",20);body.add_theme_color_override("font_color",Style.INK);column.add_child(body)
 if not source.is_empty():
  var origin:=Label.new();origin.text="来源 / "+source;origin.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
  origin.custom_minimum_size.x=850 if portrait!=null else 970
  origin.add_theme_font_size_override("font_size",14);origin.add_theme_color_override("font_color",Style.MUTED);column.add_child(origin)
 if photo!=null:
  var image:=TextureRect.new();image.texture=photo;image.custom_minimum_size=Vector2(320,240)
  image.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN;image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
  image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;image.mouse_filter=Control.MOUSE_FILTER_IGNORE;column.add_child(image)
 return card
