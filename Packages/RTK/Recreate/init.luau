--!strict

--[[
	metatablecatgames 2025
]]

--[=[
	@class Recreate

	The base library returned from requiring the module
]=]
--

local Common = require(script.Common)
local CreateLib = require(script.Create)
local SpecialKey = require(script.SpecialKey)
local Types = require(script.Types)

export type Node = Types.Node
export type SenderParams = Types.SenderParams
export type ComponentFactory<T> = Types.ComponentFactory<T>
export type SpecialKey<T = any> = Types.SpecialKey<T>
export type Watchable = Types.Watchable

export type SPEvent<T...> = (SenderParams, T...) -> ()

local ReCreate = {}
ReCreate.__VERSION = "0.1.0"

--[=[
	@function Change
	@within Recreate

	Creates a metakey declaring a Change event

	@param propName string
	@return SpecialKey<"RBXChanged">
]=]
--
ReCreate.Change = SpecialKey("RBXChanged") :: (string) -> Types.SpecialKey<"RBXChanged">

--[=[
	@function WriteState
	@within Recreate

	Creates a two-way prop/State relationship to a node
	This is useful for properties that can be influenced outside a state engine,
	such as text.

	This assumes the Watchable is the initial source of truth, and overwrites
	the property, use ControlState for the other way around
	
	@param propName string
	@return SpecialKey<"WithState">
]=]
--
ReCreate.WriteState = SpecialKey("WriteState") :: (string) -> Types.SpecialKey<"WriteState">

--[=[
	@function ControlState
	@within Recreate

	Creates a two-way prop/State relationship to a node
	This is useful for properties that can be influenced outside a state engine,
	such as text.

	This assumes the Instance is the initial source of truth, and overwrites
	the Watchable, use WriteState for the other way around
	
	@param propName string
	@return SpecialKey<"WithState">
]=]
--
ReCreate.ControlState = SpecialKey("ControlState") :: (string) -> Types.SpecialKey<"ControlState">

ReCreate.Create = CreateLib.create
ReCreate.FromTemplate = CreateLib.fromTemplate
ReCreate.FromExisting = CreateLib.fromExisting
ReCreate.Component = require(script.Component)

--[=[
	@function GetNodeByID
	@within Recreate
	@tag Plugin

	Returns a node for the given ID in the given Recreate state.

	@param id string -- The ID of the Node that you want to get
	@return Node -- The node representing the given ID
]=]
--
function ReCreate:GetNodeByID(id: string): Types.Node
	return Common.RuntimeContext.Nodes[id]
end

--[=[
	@function GetNodes
	@within Recreate
	@tag Plugin

	Returns all nodes in the given Recreate state.

	@return {[string]: Types.Node}
]=]
--
function ReCreate:GetNodes(): { [string]: Types.Node }
	return table.clone(Common.RuntimeContext.Nodes)
end

--[=[
	@function SetSupression
	@within Recreate
	@tag Plugin

	Stops `__RCImplementor` obects from propegating state changes, and stops
	events from being connected.

	@param supressed boolean?
]=]
--
function ReCreate:SetSupression(supressed: boolean?)
	Common.PluginSupressRuntime = if supressed == nil then true else supressed
end

setmetatable(ReCreate, {
	__tostring = function()
		return "ReCreate"
	end,
})
table.freeze(ReCreate)
return ReCreate
