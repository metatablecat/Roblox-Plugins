return {
	Name = "BaseStyleSheet",
	DeriveFromBase = false,

	CanvasGroup = {
		Priority = 9,
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(100, 100),
	},

	Frame = {
		Priority = 0,
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(100, 100),
	},

	ImageButton = {
		Priority = 5,
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0,
		Image = "rbxasset://textures/ui/GuiImagePlaceholder.png",
		Size = UDim2.fromOffset(100, 100),
	},

	ImageLabel = {
		Priority = 5,
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0,
		Image = "rbxasset://textures/ui/GuiImagePlaceholder.png",
		Size = UDim2.fromOffset(100, 100),
	},

	ScrollingFrame = {
		Priority = 1,
		Active = true,
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0,
		ScrollBarImageColor3 = Color3.new(0, 0, 0),
		Size = UDim2.fromOffset(100, 100),
	},

	TextBox = {
		Priority = 4,
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0,
		FontFace = Font.fromEnum(Enum.Font.SourceSans),
		Size = UDim2.fromOffset(200, 50),
		TextColor3 = Color3.new(0, 0, 0),
		TextSize = 14,
	},

	TextButton = {
		Priority = 3,
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0,
		FontFace = Font.fromEnum(Enum.Font.SourceSans),
		Size = UDim2.fromOffset(200, 50),
		TextColor3 = Color3.new(0, 0, 0),
		TextSize = 14,
	},

	TextLabel = {
		Priority = 2,
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0,
		FontFace = Font.fromEnum(Enum.Font.SourceSans),
		Size = UDim2.fromOffset(200, 50),
		TextColor3 = Color3.new(0, 0, 0),
		TextSize = 14,
	},

	UIGridLayout = {
		Priority = 11,
		SortOrder = Enum.SortOrder.LayoutOrder,
	},

	UIListLayout = {
		Priority = 10,
		SortOrder = Enum.SortOrder.LayoutOrder,
	},

	UIPageLayout = {
		Priority = 12,
		SortOrder = Enum.SortOrder.LayoutOrder,
	},

	UITableLayout = {
		Priority = 13,
		SortOrder = Enum.SortOrder.LayoutOrder,
	},

	VideoFrame = {
		Priority = 8,
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(100, 100),
	},

	ViewportFrame = {
		Priority = 7,
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(100, 100),
	},
}