local Nekotool = require(script.Parent.Parent.Nekotool)
local StylingService = game:GetService("StylingService")
local BASE_STYLE_SHEET = require(script.BaseStyleSheet)::StylesheetDoc

-- DO NOT CHANGE THIS NAME, OTHERWISE YOU'LL END UP WITH DUPLICATE FOLDERS
local NEKOTOOL_COMMON_FOLDER_NAME = "NekotoolStylesCommon"

type Rule = {
	Priority: number?,
	[string | number]: any,
}

type StylesheetDoc = {
	-- rule:
	Name: string?,
	DeriveFromBase: boolean?,
	Derive: { [StyleSheet]: number }?,
	-- if key starts with $, assume token
	-- otherwise, is a rule
	[string]: any,
}

local TOKEN_CHAR = "$"
local START_WITH_LETTER = "^(%a)"

local baseStyleSheet: StyleSheet

local function makeRule(selector: string, rule: Rule): StyleRule
	local setPropsTable = {}
	-- we need to find non-standard children before creating the main prop table
	-- these are any that start with a special char, or "Priority"

	local ruleObj = Instance.new("StyleRule")
	ruleObj.Name = selector
	ruleObj.Selector = selector
	ruleObj.Priority = rule.Priority or 0
	ruleObj.Archivable = false
	rule.Priority = nil

	for prop, def in rule do
		if string.match(prop, START_WITH_LETTER) then
			setPropsTable[prop] = def
		else
			makeRule(prop, def).Parent = ruleObj
		end
	end

	ruleObj:SetProperties(setPropsTable)
	return ruleObj
end

local function isToken(name: string): boolean
	return string.sub(name, 1, 1) == TOKEN_CHAR
end

local function getStyleSheetFromModule(m: ModuleScript | StyleSheet): StyleSheet
	if m:IsA("StyleSheet") then return m end

	local style = require(m)
	if typeof(style) ~= "Instance" or not style:IsA("StyleSheet") then
		error(`Module {m} does not return a StyleSheet`)
	end

	return style
end

local function makeStyleSheet(t: StylesheetDoc): StyleSheet
	local sheet = Instance.new("StyleSheet")
	sheet.Name = t.Name
	sheet.Archivable = false
	t.Name = nil

	if t.DeriveFromBase and baseStyleSheet then
		local derive = Instance.new("StyleDerive")
		derive.Archivable = false
		derive.StyleSheet = baseStyleSheet
		derive.Name = "BaseDerive"
		derive.Parent = sheet
	end
	t.DeriveFromBase = nil

	if t.Derive then
		for derive, priority in t.Derive do
			local styleDerive = Instance.new("StyleDerive")
			styleDerive.Archivable = false
			styleDerive.Name = `->{derive.Name}`
			styleDerive.Priority = priority
			styleDerive.StyleSheet = getStyleSheetFromModule(derive)
			styleDerive.Parent = sheet
		end
	end
	t.Derive = nil

	-- unlike descendent rules, which have a defined shape, because tokens exist, we need to handle these a bit differently
	for k, def in t do
		if isToken(k) then
			sheet:SetAttribute(string.sub(k, 2), def)
		else
			makeRule(k, def).Parent = sheet
		end
	end

	return sheet
end

return Nekotool.Service("MCGPluginServices", "StylingService", function(service, program)
	-- multiple Nekotool provides use the same folder to reduce clutter in StylingService
	local serviceFolder = StylingService:FindFirstChild(NEKOTOOL_COMMON_FOLDER_NAME)
	if not serviceFolder then
		serviceFolder = Instance.new("Folder")
		serviceFolder.Name = NEKOTOOL_COMMON_FOLDER_NAME
		serviceFolder.Parent = StylingService
	end
	
	-- this is the local folder for this plugin
	local localStorage = Instance.new("Folder")
	localStorage.Name = program.Name
	localStorage.Parent = serviceFolder
	
	if service.LocalConfig.EnableBaseStyleSheet then
		baseStyleSheet = makeStyleSheet(BASE_STYLE_SHEET)
		baseStyleSheet.Parent = localStorage
	end
	
	local StylingService = {}
	
	function StylingService.new(t: StylesheetDoc): StyleSheet
		local sheet = makeStyleSheet(t)
		sheet.Parent = localStorage
		return sheet
	end
	
	function StylingService.getStylesheetFromModule(style: ModuleScript | StyleSheet): StyleSheet
		return getStyleSheetFromModule(style)
	end
	
	program.Exports.Plugin.Unloading:Connect(function()
		localStorage:Destroy()
	end)
	
	return Nekotool.Result.Ok(StylingService)
end)