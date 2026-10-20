extends RefCounted
## One display transform for every actual metre-space layout. No world mutation.
## Reference images define the camera/cutaway language, never furniture positions.
const X_BASIS:=Vector2(96.0,-6.0)
const DEPTH_BASIS:=Vector2(16.0,56.0)
const HEIGHT_PIXELS:float=78.0
const NEAR_CUT_HEIGHT_M:float=0.85
const WEST_REAR_FRACTION:float=0.20

static func window_display(side:String,width_m:float,sill_m:float,opening_m:float) -> Dictionary:
 # This changes drawing only. Full openings, cat exits and actor targets retain
 # their source data. A low near window belongs to the same cut wall surface.
 var near:bool=side in ["south","west"]
 var low:bool=near and sill_m<1.5
 var sill:float=minf(sill_m,.60) if low else sill_m
 var opening:float=minf(opening_m,minf(.55,width_m*.34)) if low else opening_m
 return {"sill_height_m":sill,"opening_height_m":opening,"wall_cap_height_m":sill+opening+.08,"mode":"low_near_window" if low else "functional_high_window" if near else "full_far_window"}

static func project(point:Vector2,origin:Vector2) -> Vector2:
 return origin+X_BASIS*point.x+DEPTH_BASIS*point.y

static func unproject(pixel:Vector2,origin:Vector2) -> Vector2:
 return Transform2D(X_BASIS,DEPTH_BASIS,origin).affine_inverse()*pixel

static func footprint_depth(layout,rect:Rect2) -> float:
 var value:float=-INF
 for point in [rect.position,rect.end,rect.position+Vector2(rect.size.x,0),rect.position+Vector2(0,rect.size.y)]:
  value=maxf(value,layout.project(point).y)
 return value

static func prism_bounds(layout,rect:Rect2,height:float,bottom:float=0.0) -> Rect2:
 var first:Vector2=layout.project(rect.position)-Vector2(0,bottom)
 var result:=Rect2(first,Vector2.ZERO)
 for point in [rect.position,rect.end,rect.position+Vector2(rect.size.x,0),rect.position+Vector2(0,rect.size.y)]:
  result=result.expand(layout.project(point)-Vector2(0,bottom))
  result=result.expand(layout.project(point)-Vector2(0,bottom+height))
 return result

static func wall_display_segments(side:String,length:float,full_height_m:float) -> Array:
 if side=="south":return [{"start":0.0,"end":length,"height_m":minf(full_height_m,NEAR_CUT_HEIGHT_M)}]
 if side=="west":
  var rear:float=length*WEST_REAR_FRACTION
  return [{"start":0.0,"end":rear,"height_m":full_height_m},{"start":rear,"end":length,"height_m":minf(full_height_m,NEAR_CUT_HEIGHT_M)}]
 return [{"start":0.0,"end":length,"height_m":full_height_m}]

static func metadata() -> Dictionary:
 return {"x_basis_px":[X_BASIS.x,X_BASIS.y],"depth_basis_px":[DEPTH_BASIS.x,DEPTH_BASIS.y],"height_px_per_m":HEIGHT_PIXELS,"near_cut_height_m":NEAR_CUT_HEIGHT_M,"west_rear_fraction":WEST_REAR_FRACTION,"wall_display":"Continuous opaque architectural surfaces. Shared internal block edges are hidden; only silhouette, real aperture reveals and cut edges remain. Physical walls and logical positions stay unchanged.","near_window_display":"Ordinary near windows: sill<=0.6m, clear height<=min(width*0.34,0.55m), integrated in the continuous cut wall. Functional high windows retain their source dimensions."}
