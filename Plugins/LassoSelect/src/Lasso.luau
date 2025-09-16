local Lasso = {}

type Point = {
	Position: Vector2,
	Delta: number
}

export type Polygon = {
	Points: {Point},
	IsPointInPolygon: (Polygon, Vector2) -> boolean
}

local ACTIVE_POLYGON_POINTS = {}
local ACTIVE_MOVE_EVENT, LAST_POINT

-- i stole this lol, refactored to work with Vector2 objects
local function Polygon(points: {Vector2}): Polygon
	-- Takes in a table with a sequence of ints for the (x, y) of each point of the polygon.
	-- Example: {x1, y1, x2, y2, x3, y3, ...}
	-- Note: no need to repeat the first point at the end of the table, the testing function
	-- already handles that.
	local polygon = {}
	local polygonPoints = {}
	local lastPoint = points[#points]

	for _, point in points do
		if lastPoint.Y ~= point.Y then
			table.insert(polygonPoints, {
				Position = point,
				Delta = (lastPoint.X - point.X) / (lastPoint.Y - point.Y)
			})
		end
		
		lastPoint = point
	end
	
	function polygon:IsPointInPolygon(vec: Vector2): boolean
		-- Takes in the x and y of the point in question, and a 'poly' table created by
		-- createPickablePolygon(). Returns true if the point is within the polygon, otherwise false.
		-- Note: the coordinates of the test point and the polygon points are all assumed to be in
		-- the same space.

		-- Original algorithm by W. Randolph Franklin (WRF):
		-- https://wrf.ecse.rpi.edu//Research/Short_Notes/pnpoly.html
		
		local points = self.Points
		local vecX, vecY = vec.X, vec.Y
		if #points < 2 then return false end
		
		local lastPoint = points[#points]
		local lastPos = lastPoint.Position
		local lastX, lastY = lastPos.X, lastPos.Y

		local inside = false

		for _, point: Point in points do
			local pos = point.Position
			local px, py = pos.X, pos.Y

			local deltaX_div_deltaY = point.Delta
			-- 'deltaX_div_deltaY' is a precomputed optimization. The original line is:
			-- if ((py > y) ~= (lastPY > y)) and (x < (y - py) * (lastX - px) / (lastY - py) + px) then        
			if ((py > vecY) ~= (lastY > vecY)) and (vecX < (vecY - py) * deltaX_div_deltaY + px) then
				inside = not inside
			end
			
			lastPos = pos
			lastX, lastY = px, py
		end
		
		return inside
	end
	
	polygon.Points = polygonPoints
	return polygon
end

function Lasso.start(Mouse: PluginMouse)
	ACTIVE_POLYGON_POINTS = {Vector2.new(Mouse.X, Mouse.Y)}
	
	-- possible memory leak by studio jank?
	if ACTIVE_MOVE_EVENT then ACTIVE_MOVE_EVENT:Disconnect() end
	
	ACTIVE_MOVE_EVENT = Mouse.Move:Connect(function()
		local x, y = Mouse.X, Mouse.Y
		local point = Vector2.new(x, y)
		if point ~= LAST_POINT then
			table.insert(ACTIVE_POLYGON_POINTS, point)
			LAST_POINT = point
			
			if Lasso.renderHook then
				local points = table.clone(ACTIVE_POLYGON_POINTS)
				Lasso.renderHook(points, Polygon(points))
			end
		end
	end)	
end

function Lasso.stop(Mouse: PluginMouse): Polygon
	if ACTIVE_MOVE_EVENT then
		ACTIVE_MOVE_EVENT = ACTIVE_MOVE_EVENT:Disconnect()
	end
	
	table.insert(ACTIVE_POLYGON_POINTS, Vector2.new(Mouse.X, Mouse.Y))
	
	if Lasso.renderHook then Lasso.renderHook() end
	-- build the polygon object from the points
	local poly = Polygon(table.clone(ACTIVE_POLYGON_POINTS))
	ACTIVE_POLYGON_POINTS = {}
	return poly
end

Lasso.renderHook = nil :: ((Last: {Vector2}?, poly: Polygon?) -> ())?
return Lasso