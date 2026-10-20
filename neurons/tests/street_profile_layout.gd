extends "res://scripts/world/street_layout.gd"
## Test-only method timing; geometry and path algorithms remain inherited.
var calls:Array=[]
func _init(room:String="street_twisted") -> void:super(room)
func path(a:Vector2,b:Vector2) -> PackedVector2Array:
 var start:int=Time.get_ticks_usec();var result:PackedVector2Array=super.path(a,b)
 calls.append({"method":"path","seconds":float(Time.get_ticks_usec()-start)/1000000.0,"a":[a.x,a.y],"b":[b.x,b.y],"points":result.size()})
 return result
func path_around_bodies(a:Vector2,b:Vector2,bodies:Array) -> PackedVector2Array:
 var start:int=Time.get_ticks_usec();var result:PackedVector2Array=super.path_around_bodies(a,b,bodies)
 calls.append({"method":"path_around_bodies","seconds":float(Time.get_ticks_usec()-start)/1000000.0,"a":[a.x,a.y],"b":[b.x,b.y],"bodies":bodies.size(),"points":result.size()})
 return result
func rebuild_grid() -> void:
 var start:int=Time.get_ticks_usec();super.rebuild_grid()
 calls.append({"method":"rebuild_grid","seconds":float(Time.get_ticks_usec()-start)/1000000.0})
