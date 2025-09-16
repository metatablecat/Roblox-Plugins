--!nolint DeprecatedApi
local Lasso = require(script.Lasso)
local CoreGui = game:GetService("CoreGui")
local Selection = game:GetService("Selection")
local Camera = workspace.CurrentCamera

local ALT_KEY_IS_DOWN = false
local SHIFT_KEY_IS_DOWN = false
local ALT_CODE_CHAR = string.char(52)
local SHIFT_CODE_CHAR = string.char(48)

local LassoPointRendering = Instance.new("ScreenGui")
LassoPointRendering.Name = "LassoSelect"
LassoPointRendering.Parent = CoreGui

local mouse: PluginMouse = plugin:GetMouse()
local tbar = plugin:CreateToolbar("Lasso Select")
local btn = tbar:CreateButton("lasso-select", "Select parts and models as a lasso", "rbxassetid://12563964325", "Lasso Select")

local function renderLasso(points: {Vector2})
	local pointCount = #points
	if pointCount < 2 then return end
	LassoPointRendering:ClearAllChildren()
	
	local p1 = points[1]
	local pMax = points[#points]
	
	local function renderLine(PointA: Vector2, PointB: Vector2)
		local line = Instance.new("Frame")
		line.BorderSizePixel = 0
		line.BackgroundColor3 = Color3.fromRGB(178, 178, 178)
		
		local d = math.sqrt(math.pow(PointA.X-PointB.X, 2) + math.pow(PointA.Y-PointB.Y, 2))
		local c = Vector2.new((PointA.X + PointB.X)/2, (PointA.Y + PointB.Y)/2)	
		local r = math.atan2(PointA.Y - PointB.Y, PointA.X - PointB.X)
		local t = 1
		
		line.Size = UDim2.new(0, d, 0, t)
		line.AnchorPoint = Vector2.new(.5, .5)
		line.Position = UDim2.fromOffset(c.X, c.Y)
		line.Rotation = math.deg(r)
		line.Parent = LassoPointRendering
	end
	
	for i = 1, #points - 1 do
		local point = points[i]
		local nextpoint = points[i + 1]
		
		renderLine(point, nextpoint)
	end
	
	renderLine(pMax, p1)
end

local function append(t1, t2)
	for _, v in t2 do
		table.insert(t1, v)
	end
end

local function getTopLevelPartsAndModels(root)
	local output = {}
	local c = root:GetChildren()
	-- checks parts, models (and folder descendants) and assembles a selectable list
	
	for _, obj in c do
		if obj:IsA("Folder") then
			append(output, getTopLevelPartsAndModels(obj))
		elseif (obj:IsA("BasePart") and obj.ClassName ~= "Terrain" and not obj.Locked) or obj:IsA("Model") then
			table.insert(output, obj)
		end
	end
	
	return output
end

local function checkPartsInLasso(polygon: Lasso.Polygon)
	local parts: {Model|BasePart}
	
	if ALT_KEY_IS_DOWN then
		local p = {}
		local c = workspace:GetDescendants()
		
		for _, v in c do
			if v:IsA("BasePart") and v.ClassName ~= "Terrain" and not v.Locked then
				table.insert(p, v)
			end
		end
		
		parts = p
	else
		parts = getTopLevelPartsAndModels(workspace)
	end

	local s = if SHIFT_KEY_IS_DOWN then Selection:Get() else {}
	-- checks: if part is locked ignore it
	-- if part is not on screen, do not render it
	
	for _, part in parts do
		local objPos
		if part:IsA("Model") then
			-- checks as model
			objPos = part:GetBoundingBox().Position
		else
			objPos = part.Position
		end
		
		objPos = Camera:WorldToViewportPoint(objPos)
		if polygon:IsPointInPolygon(objPos) then
			table.insert(s, part)
		end
	end

	Selection:Set(s)
end

btn.Click:Connect(function()
	if plugin:IsActivated() then
		plugin:Deactivate()
		Lasso.stop(mouse)
		btn:SetActive(false)
	else
		plugin:Activate(true)
		btn:SetActive(true)
	end
end)

plugin.Deactivation:Connect(function()
	ALT_KEY_IS_DOWN = false
	SHIFT_KEY_IS_DOWN = false
	Lasso.stop(mouse)
	btn:SetActive(false)
end)

plugin.Unloading:Connect(function()
	LassoPointRendering:Destroy()
end)

mouse.Button1Down:Connect(function()
	Lasso.start(mouse)
end)

mouse.Button1Up:Connect(function()
	local poly = Lasso.stop(mouse)
	checkPartsInLasso(poly)
end)

mouse.KeyDown:Connect(function(k)
	if k == ALT_CODE_CHAR then
		ALT_KEY_IS_DOWN = true
	end
	
	if k == SHIFT_CODE_CHAR then
		SHIFT_KEY_IS_DOWN = true
	end
end)

mouse.KeyUp:Connect(function(k)
	if string.byte(k) == ALT_CODE_CHAR then
		ALT_KEY_IS_DOWN = false
	end
	
	if k == SHIFT_CODE_CHAR then
		SHIFT_KEY_IS_DOWN = false
	end
end)

Lasso.renderHook = function(points)
	if not points then
		LassoPointRendering:ClearAllChildren()
		return
	end
	
	renderLasso(points)
end