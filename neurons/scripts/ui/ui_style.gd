extends RefCounted
## Shared visual language. No input, saves, clocks or gameplay settlement.
const FONT_PATH="res://assets/fonts/NotoSansCJKsc-Regular.otf"
const PAPER:=Color("e9e2d2")
const PAPER_LIGHT:=Color("f3eedf")
const INK:=Color("293834")
const MUTED:=Color("68736a")
const RULE:=Color("bbb9a4")
const TEAL:=Color("46695f")
const OCHRE:=Color("a37848")
const OXIDE:=Color("975d4a")
const NIGHT:=Color("192b2b")
const TERMINAL_INK:=Color("d8dfca")
const TERMINAL_DIM:=Color("91a999")
static var _themes:Dictionary={}
static var _icons:Dictionary={}

static func surface(mode:String="paper",emphasis:bool=false) -> StyleBoxFlat:
 var s:=StyleBoxFlat.new()
 s.bg_color=NIGHT if mode=="terminal" else PAPER_LIGHT if mode=="light" else PAPER
 s.border_color=Color("6a8170") if mode=="terminal" else RULE
 s.set_border_width_all(1)
 s.border_width_top=3 if emphasis else 1
 s.set_corner_radius_all(0)
 s.set_content_margin_all(14)
 s.shadow_color=Color(0.05,0.08,0.07,0.16)
 s.shadow_size=4
 s.shadow_offset=Vector2(0,3)
 return s

static func button_box(mode:String,state:String) -> StyleBoxFlat:
 var dark:bool=mode=="terminal"
 var s:=StyleBoxFlat.new()
 s.set_corner_radius_all(0)
 s.content_margin_left=14;s.content_margin_right=14
 s.content_margin_top=8;s.content_margin_bottom=8
 s.bg_color=Color("243b34") if dark else Color("e5deca")
 s.border_color=Color("627d6a") if dark else Color("b6b39e")
 s.border_width_bottom=1
 if state=="hover":
  s.bg_color=Color("304d40") if dark else Color("d9dccb")
  s.border_color=Color("c8b27d") if dark else TEAL;s.border_width_left=3
 elif state=="pressed":
  s.bg_color=Color("172d26") if dark else Color("c6cfbc")
  s.border_color=OCHRE;s.border_width_left=3
 elif state=="disabled":
  s.bg_color=Color("22312d") if dark else Color("dfdccf")
  s.border_color=Color("3e574a") if dark else Color("c7c4b5")
 elif state=="focus":
  s.bg_color=Color.TRANSPARENT;s.border_color=Color("d0b77e") if dark else OCHRE
  s.set_border_width_all(2)
 return s

static func theme_for(mode:String="paper") -> Theme:
 if _themes.has(mode):return _themes[mode]
 var dark:bool=mode=="terminal"
 var t:=Theme.new();t.default_font=load(FONT_PATH);t.default_font_size=18
 var ink:Color=TERMINAL_INK if dark else INK
 var muted:Color=TERMINAL_DIM if dark else MUTED
 for type:String in ["Label","RichTextLabel","LineEdit","TextEdit","Button","CheckBox","CheckButton","OptionButton","PopupMenu"]:
  t.set_color("font_color",type,ink)
  t.set_font_size("font_size",type,18)
 for type:String in ["Button","CheckBox","CheckButton","OptionButton"]:
  for state:String in ["normal","hover","pressed","disabled","focus"]:t.set_stylebox(state,type,button_box(mode,state))
  t.set_color("font_hover_color",type,Color("f5ead1") if dark else TEAL)
  t.set_color("font_pressed_color",type,TERMINAL_INK if dark else INK)
  t.set_color("font_focus_color",type,TERMINAL_INK if dark else INK)
  t.set_color("font_disabled_color",type,Color("7b9081") if dark else Color("8e9485"))
  t.set_color("icon_disabled_color",type,Color("789080") if dark else Color("8e9485"))
  t.set_constant("h_separation",type,9)
 t.set_constant("line_spacing","Label",3)
 t.set_constant("separation","VBoxContainer",12)
 t.set_constant("separation","HBoxContainer",12)
 t.set_constant("h_separation","GridContainer",12);t.set_constant("v_separation","GridContainer",12)
 t.set_stylebox("panel","Panel",surface(mode));t.set_stylebox("panel","PanelContainer",surface(mode))
 for state:String in ["normal","read_only","focus"]:
  var field:=surface("terminal" if dark else "light")
  if state=="focus":field.border_color=OCHRE;field.border_width_bottom=2
  field.shadow_size=0;t.set_stylebox(state,"LineEdit",field)
 t.set_color("caret_color","LineEdit",OCHRE)
 t.set_color("font_placeholder_color","LineEdit",muted)
 t.set_color("selection_color","LineEdit",Color("8eac8c88"))
 var track:=StyleBoxFlat.new();track.bg_color=Color("486053") if dark else Color("c8c7b6");track.set_content_margin_all(3)
 var fill:=track.duplicate();fill.bg_color=TEAL
 t.set_stylebox("slider","HSlider",track);t.set_stylebox("grabber_area","HSlider",fill);t.set_stylebox("grabber_area_highlight","HSlider",fill)
 t.set_stylebox("background","ProgressBar",track);t.set_stylebox("fill","ProgressBar",fill)
 var scroll:=track.duplicate();scroll.bg_color=Color("c4c6b5") if not dark else Color("3d5749")
 t.set_stylebox("scroll","VScrollBar",track);t.set_stylebox("grabber","VScrollBar",scroll);t.set_stylebox("grabber_highlight","VScrollBar",fill)
 var tip:=surface("terminal");tip.set_content_margin_all(10)
 t.set_stylebox("panel","TooltipPanel",tip);t.set_color("font_color","TooltipLabel",TERMINAL_INK);t.set_font_size("font_size","TooltipLabel",15)
 _themes[mode]=t;return t

static func mode_for(node:Node) -> String:
 var cursor:Node=node
 while cursor!=null:
  if cursor.has_meta("ui_mode"):return str(cursor.get_meta("ui_mode"))
  cursor=cursor.get_parent()
 return "paper"

static func style_button(b:Button,mode:String="paper") -> void:
 b.theme=theme_for(mode)
 for state:String in ["normal","hover","pressed","disabled","focus"]:b.add_theme_stylebox_override(state,button_box(mode,state))
 for key:String in ["font_color","font_hover_color","font_pressed_color","font_disabled_color"]:b.remove_theme_color_override(key)
 b.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND

static func skill_icon(id:String,mode:String="terminal") -> Texture2D:
 var key:String=id+mode
 if _icons.has(key):return _icons[key]
 var paths:Dictionary={
  "SKIN":"<path d='M8 25V13q0-4 3-4t3 4v5-12q0-4 3-4t3 4v12-9q0-3 3-3t3 3v14q0 7-8 7q-6 0-10-5z'/>",
  "GUT":"<path d='M9 4v8q0 6 8 5q10-2 10 5q0 7-10 7q-10 0-10-7q0-7 10-6q8 1 8-5V4'/>",
  "PORES":"<path d='M4 25q12-9 25 0'/><circle cx='9' cy='13' r='2'/><circle cx='17' cy='8' r='2'/><circle cx='25' cy='13' r='2'/>",
  "TEMP":"<path d='M14 7a3 3 0 016 0v13a6 6 0 11-6 0zM17 10v15M25 9h4M25 15h4'/>",
  "TINNITUS":"<path d='M8 12q0-9 9-9t9 9q0 5-6 9q-2 2-2 6q-1 4-5 3M12 12q0-5 5-5t5 5l-6 5M4 7l-2 6l2 6'/>",
  "DRYMOUTH":"<path d='M5 12q12 9 24 0M5 16q12 10 24 0M16 2q-5 7 0 7t0-7z'/>",
  "KNEE":"<path d='M10 3l3 12l8 7l-2 8M15 3l3 10l9 7l-2 10'/><circle cx='16' cy='16' r='3'/>",
  "WITHDRAW":"<path d='M29 10H12l5-6M12 10l5 6M7 28l13-7l8 6M4 23l12-7l8 3'/>",
  "STARTLE":"<path d='M16 3v8M16 23v8M3 16h8M23 16h8M6 6l6 6M22 22l6 6M6 28l6-6M22 12l6-6'/><circle cx='16' cy='16' r='4'/>",
  "FEAR":"<path d='M2 17q14-17 28 0q-14 17-28 0z'/><circle cx='16' cy='17' r='5'/><path d='M12 3l4 3l4-3'/>",
  "JOY":"<circle cx='16' cy='16' r='12'/><path d='M9 19q7 9 14 0M10 11h2M20 11h2'/>",
  "CONTROL":"<path d='M16 2v28M2 16h28M10 7l6-5l6 5M10 25l6 5l6-5M7 10l-5 6l5 6M25 10l5 6l-5 6'/>",
 }
 var color:String=TERMINAL_INK.to_html(false) if mode=="terminal" else INK.to_html(false)
 var svg:String="<svg xmlns='http://www.w3.org/2000/svg' width='32' height='32' viewBox='0 0 34 34'><g stroke='#"+color+"' stroke-width='1.7' fill='none' stroke-linecap='round' stroke-linejoin='round'>"+str(paths.get(id,paths.SKIN))+"</g></svg>"
 var image:=Image.new();image.load_svg_from_string(svg,1.5)
 var tex:=ImageTexture.create_from_image(image);_icons[key]=tex;return tex
