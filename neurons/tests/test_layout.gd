extends SceneTree
## Geometry checks only; this is not visual or navigation-feel acceptance.

const Layout = preload("res://scripts/world/room_layout.gd")
var checks: int = 0
var failed: int = 0
var diagnostics: Array[String] = []


func _init() -> void:
	var layout = Layout.new()
	check(layout.furniture.size() == 11, "expected 11 approach points")
	check(layout.walkable(Layout.BED_STOP), "bed starting point must fit protagonist radius")
	check(layout.walkable(Layout.DOOR), "door approach must fit protagonist radius")
	for fixture: Dictionary in layout.furniture:
		var approach: Vector2 = fixture["at"]
		var name: String = str(fixture["id"])
		if not layout.walkable(approach):
			diagnostics.append("BLOCKED %s at=%s, overlaps=%s" % [name, approach, blockers(layout, approach)])
		check(layout.walkable(approach), "%s approach is walkable" % name)
		verify_route(layout, Layout.BED_STOP, approach, "bed_to_" + name)
	verify_route(layout, Layout.BED_STOP, Layout.DOOR, "bed_to_door")
	var aisle: Array[Vector2] = [Vector2(2.9, 0.85), Vector2(3.0, 2.0),
		Vector2(4.25, 2.1), Vector2(4.4, 0.4), Vector2(3.0, 2.72)]
	for index: int in range(aisle.size()):
		check(layout.walkable(aisle[index]), "aisle %d walkable" % index)
		verify_route(layout, Layout.BED_STOP, aisle[index], "bed_to_aisle_%d" % index)
	verify_projection(layout)
	for entry: String in diagnostics:
		print(entry)
	print("NEURONS room layout: %d checks, %d failures" % [checks, failed])
	quit(1 if failed > 0 else 0)


func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failed += 1
		diagnostics.append("FAIL " + label)


func blockers(layout: RefCounted, point: Vector2) -> String:
	var names: Array[String] = []
	for fixture: Dictionary in layout.furniture:
		var footprint: Rect2 = fixture["rect"]
		if footprint.grow(Layout.RADIUS).has_point(point):
			names.append("%s footprint=%s inflated=%s" % [fixture["id"], footprint,
				footprint.grow(Layout.RADIUS)])
	return "; ".join(names)


func verify_route(layout: RefCounted, start: Vector2, finish: Vector2, name: String) -> void:
	# Avoid invoking AStar on a known solid destination; report its exact reason.
	if not layout.walkable(start) or not layout.walkable(finish):
		check(false, name + " cannot route to a blocked endpoint")
		return
	var route: PackedVector2Array = layout.path(start, finish)
	check(not route.is_empty(), name + " has a path")
	if route.is_empty():
		diagnostics.append("UNREACHABLE %s from=%s to=%s" % [name, start, finish])
		return
	check(route[0].is_equal_approx(start) and route[-1].is_equal_approx(finish), name + " exact endpoints")
	var samples_valid: bool = true
	var previous: Vector2 = start
	for waypoint: Vector2 in route:
		var steps: int = maxi(1, ceili(previous.distance_to(waypoint) / 0.005))
		for index: int in range(steps + 1):
			var sample: Vector2 = previous.lerp(waypoint, float(index) / float(steps))
			if not layout.walkable(sample):
				samples_valid = false
				diagnostics.append("PATH COLLISION %s at=%s with=%s" % [name, sample, blockers(layout, sample)])
				break
		if not samples_valid:
			break
		previous = waypoint
	check(samples_valid, name + " continuous path clears inflated footprints")
	var position: Vector2 = start
	var remaining: PackedVector2Array = route.duplicate()
	var movement_safe: bool = true
	var stalled: bool = false
	# 0.0137m steps are intentionally not aligned to 0.1m navigation cells.
	for step_index: int in range(10000):
		if remaining.is_empty():
			break
		var before: Vector2 = position
		var movement: Dictionary = layout.move_path(position, remaining, 0.0137)
		position = movement["position"]
		remaining = movement["route"]
		if not layout.walkable(position):
			movement_safe = false
			diagnostics.append("MOVEMENT COLLISION %s at=%s with=%s" % [name, position, blockers(layout, position)])
			break
		if position.is_equal_approx(before) and not remaining.is_empty():
			stalled = true
			diagnostics.append("STALLED %s at=%s next=%s" % [name, position, remaining[0]])
			break
	check(movement_safe, name + " incremental movement never enters a footprint")
	check(not stalled and remaining.is_empty() and position.distance_to(finish) < 0.0001,
		name + " incremental movement reaches endpoint")
	var native_length: float = route_length(route)
	for zoom: float in [0.8, 1.0, 1.3]:
		var offset: Vector2 = Vector2(17.0, -9.0)
		var projected_start: Vector2 = layout.project(start) * zoom + offset
		var projected_finish: Vector2 = layout.project(finish) * zoom + offset
		var recovered_start: Vector2 = layout.unproject((projected_start - offset) / zoom)
		var recovered_finish: Vector2 = layout.unproject((projected_finish - offset) / zoom)
		var inverse_route: PackedVector2Array = layout.path(recovered_start, recovered_finish)
		if absf(route_length(inverse_route) - native_length) >= 0.0001:
			diagnostics.append("GRID ROUNDING %s zoom=%.1f native=%.8f recovered=%.8f end=%s inverse=%s" %
				[name, zoom, native_length, route_length(inverse_route), finish, recovered_finish])
		check(absf(route_length(inverse_route) - native_length) < 0.0001,
			"%s logical path length invariant at zoom %.1f" % [name, zoom])


func route_length(route: PackedVector2Array) -> float:
	var total: float = 0.0
	for index: int in range(1, route.size()):
		total += route[index - 1].distance_to(route[index])
	return total


func verify_projection(layout: RefCounted) -> void:
	var largest_error: float = 0.0
	for y: int in range(39):
		for x: int in range(57):
			var point: Vector2 = Vector2(x, y) * Layout.CELL
			largest_error = maxf(largest_error, point.distance_to(layout.unproject(layout.project(point))))
	check(largest_error < 0.00001, "project/unproject inverse on full 57x39 logical grid")
	# Projection is deliberately anisotropic; movement distance must be measured
	# in logical coordinates rather than pixels.
	var logical_x: Vector2 = Vector2(1, 0)
	var logical_y: Vector2 = Vector2(0, 1)
	var origin: Vector2 = layout.project(Vector2.ZERO)
	check(is_equal_approx(logical_x.length(), logical_y.length()), "logical metre isotropic")
	check(not is_equal_approx(layout.project(logical_x).distance_to(origin),
		layout.project(logical_y).distance_to(origin)), "screen projection cannot substitute for logical distance")
