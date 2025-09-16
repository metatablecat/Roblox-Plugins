-- Some utility stuff for services to make it easier to batch load modules

local Types = require(script.Parent.Parent.Types)
local Result = require(script.Parent.Parent.Result)
local ModuleLoader = {}

-- require doesn't pass errors anoyingly so we just wrap the error into an Enum
-- todo: should LoadFromInstance be an Async method that waits

type ModuleAssertion = (any) -> Types.Result<any, string>

local function loadModulesAsync(
	modules: {ModuleScript},
	globAssert: ModuleAssertion?
): {[ModuleScript]: Types.Result<any, string>}
	local refCounter = #modules
	if refCounter == 0 then return {} end -- save time

	local collected = {}
	local co = coroutine.running()

	local function collectModuleParallel(moduleScript: ModuleScript)
		-- to save time, we'll just process the collection normally before wrapping it into a result
		local ok, e = pcall(require, moduleScript)
		local res

		if ok then
			res = if globAssert then globAssert(e) else Result.Ok(e)
		else
			res = Result.Err(e)
		end

		collected[moduleScript] = res
		refCounter -= 1

		if refCounter <= 0 and co then
			task.defer(co)
			co = nil -- stop extra ref calls from hitting this by accident (should never happen)
		end
	end

	for _, module in modules do
		-- spawn collectors, then wait for refCounter to release

		-- sometimes, non modules could sneak in, this is a utility path to make that
		-- silently easier to work with
		if not module:IsA("ModuleScript") then
			refCounter -= 1
			continue
		end

		task.defer(collectModuleParallel, module)
	end
	
	if refCounter > 0 then coroutine.yield() end
	return collected
end

local function recurseSearchForModules(
	instances: {Instance},
	collected: {ModuleScript}
)
	for _, v in instances do
		if v:IsA("ModuleScript") then
			table.insert(collected, v)
			continue
		else
			local children = v:GetChildren()
			if #children > 0 then recurseSearchForModules(children, collected) end
		end
	end
end

local function search(
	rootInstances: {Instance},
	includeBaseInstanceInSearch: boolean,
	mode: Types.ModuleLoaderDependencySearchType?
): {ModuleScript}
	local collected = {}

	for _, rootInstance in rootInstances do
		if includeBaseInstanceInSearch and rootInstance:IsA("ModuleScript") then
			table.insert(collected, rootInstance)
		end

		local children = rootInstance:GetChildren()
		if #children == 0 then continue end

		if not mode or mode == "Children" then
			for _, v in children do
				if v:IsA("ModuleScript") then table.insert(collected, v) end
			end
		elseif mode == "AllDescendents" then
			for _, v in children do
				if v:IsA("ModuleScript") then table.insert(collected, v) end
			end
		elseif mode == "SurfaceDescendents" then
			-- this is a little more involved because we need to recursively search for children
			-- unless the node is a ModuleScript
			recurseSearchForModules(children, collected)
		end
	end

	return collected
end

function ModuleLoader.loadFromInstance(
	instances: Instance | {Instance},
	includeBaseInstances: boolean?,
	searchMode: Types.ModuleLoaderDependencySearchType?,
	assertion: ModuleAssertion?
)
	if typeof(instances) == "Instance" then
		instances = {instances}
	end

	return loadModulesAsync(search(
		instances::{Instance},
		if includeBaseInstances ~= nil then includeBaseInstances else false,
		searchMode
	), assertion)
end

function ModuleLoader.loadFromObjects(
	objects: {ModuleScript},
	assertion: ModuleAssertion?
)
	return loadModulesAsync(objects, assertion)
end

return ModuleLoader