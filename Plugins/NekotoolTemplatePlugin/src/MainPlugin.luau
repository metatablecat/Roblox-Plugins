local Nekotool = require(script.Parent.Parent.NekotoolCommon.Nekotool)

return Nekotool.extend(function(Program)
	Program.Init(function()
		print("Hello Nekotool!")
	end)
end)