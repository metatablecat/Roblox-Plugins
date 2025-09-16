local Nekotool = require(script.Parent.Parent.Packages.Nekotool)

return Nekotool.extend(function(Program)
	Program.Init(function()
		print("Hello Nekotool!")
	end)
end)