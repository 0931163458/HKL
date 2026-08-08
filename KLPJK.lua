local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local CurrentRooms = Workspace:WaitForChild("CurrentRooms")

-- ==========================================
-- ⚙️ CONFIG & STATE VARIABLES
-- ==========================================
local Flags = {
	DoorESP = true,
	ItemESP = true,
	EntityESP = true,
	FigureESP = true,
	WardrobeESP = true, -- [ใหม่] เปิด/ปิด มองทะลุตู้เสื้อผ้า
	WarningText = true,
	SeekSpeed = true,
	WalkSpeed = 20
}

-- ==========================================
-- 🏃 PLAYER MOVEMENT & SEEK MODIFIER (Optimized)
-- ==========================================
local seekCache = setmetatable({}, {__mode = "k"})

local function setupPlayerMods(char)
	local hrp = char:WaitForChild("HumanoidRootPart", 5)
	local humanoid = char:WaitForChild("Humanoid", 5)
	if not hrp or not humanoid then return end
	
	local moveBv = hrp:FindFirstChild("MovementBV") or Instance.new("BodyVelocity")
	moveBv.Name = "MovementBV"
	moveBv.MaxForce = Vector3.new(0, 0, 0)
	moveBv.Velocity = Vector3.new(0, 0, 0)
	moveBv.Parent = hrp
	
	local connection
	connection = RunService.Heartbeat:Connect(function()
		if not char or not char.Parent or humanoid.Health <= 0 then
			connection:Disconnect()
			return
		end
		
		local currentSpeed = math.clamp(Flags.WalkSpeed, 15, 25)
		
		if humanoid.MoveDirection.Magnitude > 0 then
			moveBv.MaxForce = Vector3.new(100000, 0, 100000)
			moveBv.Velocity = humanoid.MoveDirection * currentSpeed
		else
			moveBv.MaxForce = Vector3.new(0, 0, 0)
			moveBv.Velocity = Vector3.new(0, 0, 0)
		end
		
		if Flags.SeekSpeed then
			local seekTargets = {
				Workspace:FindFirstChild("SeekMoving"),
				Workspace:FindFirstChild("SeekMovingNewClone")
			}
			
			for _, seekModel in ipairs(seekTargets) do
				if seekModel then
					if not seekCache[seekModel] then
						seekCache[seekModel] = { align = {}, hums = {} }
						for _, desc in ipairs(seekModel:GetDescendants()) do
							if desc:IsA("AlignPosition") then table.insert(seekCache[seekModel].align, desc)
							elseif desc:IsA("Humanoid") then table.insert(seekCache[seekModel].hums, desc)
							end
						end
					end
					
					for _, align in ipairs(seekCache[seekModel].align) do align.MaxVelocity = 15 end
					for _, hum in ipairs(seekCache[seekModel].hums) do hum.WalkSpeed = 15 end
					
					local root = seekModel.PrimaryPart or seekModel:FindFirstChild("HumanoidRootPart") or seekModel:FindFirstChildWhichIsA("BasePart")
					if root and root.AssemblyLinearVelocity.Magnitude > 15 then
						root.AssemblyLinearVelocity = root.AssemblyLinearVelocity.Unit * 15
					end
				end
			end
		end
	end)
end

if LocalPlayer.Character then setupPlayerMods(LocalPlayer.Character) end
LocalPlayer.CharacterAdded:Connect(setupPlayerMods)

-- ==========================================
-- 🎨 ESP & WARNING SYSTEM
-- ==========================================
local COLOR_YELLOW = Color3.fromRGB(255, 215, 0)
local COLOR_GREEN = Color3.fromRGB(50, 220, 100)
local COLOR_BLUE = Color3.fromRGB(0, 180, 255)
local COLOR_RED = Color3.fromRGB(255, 50, 70)
local COLOR_CYAN = Color3.fromRGB(0, 255, 255) -- [ใหม่] สีตู้เสื้อผ้า
local FONT_STYLE = 3
local FONT_SIZE = 14
local MAX_ESP_DISTANCE = 1500

local currentDoorTarget = nil
local latestRoomNum = -1
local activeItems = {}
local trackedHelpfulLights = {}

local alertText = Drawing.new("Text")
alertText.Size = 28
alertText.Font = FONT_STYLE
alertText.Center = true
alertText.Outline = true
alertText.OutlineColor = Color3.fromRGB(0, 0, 0)
alertText.Color = COLOR_RED
alertText.Visible = false

local enemyAlertCooldowns = { ["Rush"] = 0, ["Ambush"] = 0, ["Screech"] = 0 }
local alertedEnemyInstances = setmetatable({}, {__mode = "k"})
local textCache = {}

local function getDrawingText(index)
	if not textCache[index] then
		local text = Drawing.new("Text")
		text.Size = FONT_SIZE
		text.Font = FONT_STYLE
		text.Center = true
		text.Outline = true
		text.OutlineColor = Color3.fromRGB(0, 0, 0)
		text.Transparency = 1
		textCache[index] = text
	end
	return textCache[index]
end

local function getPrimaryPartOrFallback(object)
	if not object then return nil end
	if object:IsA("BasePart") then return object end
	if object:IsA("Model") then
		return object.PrimaryPart or object:FindFirstChildWhichIsA("BasePart", true)
	end
	return object:FindFirstChildWhichIsA("BasePart", true)
end

local function findDoorPart(room)
	local doorObj = room:FindFirstChild("Door", true)
	if doorObj then
		return doorObj
	end
	return room:FindFirstChildWhichIsA("BasePart", true)
end

local function ensureHighlight(parentPart, hlName, color)
	if not parentPart then return end
	local hl = parentPart:FindFirstChild(hlName)
	if not hl then
		hl = Instance.new("Highlight")
		hl.Name = hlName
		hl.FillColor = color
		hl.FillTransparency = 0.4 
		hl.OutlineColor = Color3.fromRGB(255, 255, 255)
		hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		hl.Parent = parentPart
	else
		hl.FillColor = color
	end
end

local function removeHighlight(parentPart, hlName)
	if parentPart then
		local hl = parentPart:FindFirstChild(hlName)
		if hl then hl:Destroy() end
	end
end

-- ==========================================
-- 🛠️ SMOOTH DRAGGING SYSTEM (สำหรับมือถือ & คอม)
-- ==========================================
local function makeDraggable(triggerObject, targetFrame)
	local dragging = false
	local dragInput, dragStart, startPos

	triggerObject.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = targetFrame.Position

			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
				end
			end)
		end
	end)

	triggerObject.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			dragInput = input
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if input == dragInput and dragging then
			local delta = input.Position - dragStart
			targetFrame.Position = UDim2.new(
				startPos.X.Scale,
				startPos.X.Offset + delta.X,
				startPos.Y.Scale,
				startPos.Y.Offset + delta.Y
			)
		end
	end)
end

-- ==========================================
-- 🖥️ MODERN BEAUTIFUL UI CREATION
-- ==========================================
local function createUI()
	local ScreenGui = Instance.new("ScreenGui")
	ScreenGui.Name = "DOORS_Helper_ModernUI"
	ScreenGui.ResetOnSpawn = false
	pcall(function() ScreenGui.Parent = CoreGui end)
	if not ScreenGui.Parent then ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

	local MainFrame = Instance.new("Frame")
	MainFrame.Name = "MainFrame"
	MainFrame.Size = UDim2.new(0, 250, 0, 320)
	MainFrame.Position = UDim2.new(0.05, 0, 0.25, 0)
	MainFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
	MainFrame.BorderSizePixel = 0
	MainFrame.Active = true
	MainFrame.Parent = ScreenGui
	Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 10)

	local MainStroke = Instance.new("UIStroke")
	MainStroke.Color = Color3.fromRGB(60, 60, 85)
	MainStroke.Thickness = 1.5
	MainStroke.Parent = MainFrame

	local MainGradient = Instance.new("UIGradient")
	MainGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(24, 24, 32)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(14, 14, 18))
	})
	MainGradient.Rotation = 45
	MainGradient.Parent = MainFrame

	local TitleBar = Instance.new("Frame")
	TitleBar.Name = "TitleBar"
	TitleBar.Size = UDim2.new(1, 0, 0, 40)
	TitleBar.BackgroundColor3 = Color3.fromRGB(28, 28, 38)
	TitleBar.BorderSizePixel = 0
	TitleBar.Parent = MainFrame
	Instance.new("UICorner", TitleBar).CornerRadius = UDim.new(0, 10)

	local TitleText = Instance.new("TextLabel")
	TitleText.Size = UDim2.new(1, -10, 1, 0)
	TitleText.Position = UDim2.new(0, 10, 0, 0)
	TitleText.BackgroundTransparency = 1
	TitleText.Text = "🚪 DOORS HELPER"
	TitleText.TextColor3 = Color3.fromRGB(255, 215, 0)
	TitleText.Font = Enum.Font.GothamBold
	TitleText.TextSize = 14
	TitleText.TextXAlignment = Enum.TextXAlignment.Left
	TitleText.Parent = TitleBar

	local SubText = Instance.new("TextLabel")
	SubText.Size = UDim2.new(1, -15, 1, 0)
	SubText.BackgroundTransparency = 1
	SubText.Text = "MOBILE VIP"
	SubText.TextColor3 = Color3.fromRGB(120, 120, 150)
	SubText.Font = Enum.Font.GothamBold
	SubText.TextSize = 10
	SubText.TextXAlignment = Enum.TextXAlignment.Right
	SubText.Parent = TitleBar

	makeDraggable(TitleBar, MainFrame)

	local Container = Instance.new("ScrollingFrame")
	Container.Size = UDim2.new(1, -16, 1, -50)
	Container.Position = UDim2.new(0, 8, 0, 45)
	Container.BackgroundTransparency = 1
	Container.ScrollBarThickness = 3
	Container.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 110)
	Container.CanvasSize = UDim2.new(0, 0, 0, 380) -- [ปรับปรุง] เพิ่มขนาดความสูงเพื่อรองรับปุ่มตู้เสื้อผ้า
	Container.Parent = MainFrame

	local UIList = Instance.new("UIListLayout")
	UIList.SortOrder = Enum.SortOrder.LayoutOrder
	UIList.Padding = UDim.new(0, 6)
	UIList.Parent = Container

	local UIPad = Instance.new("UIPadding")
	UIPad.PaddingRight = UDim.new(0, 4)
	UIPad.Parent = Container

	local function createToggle(name, labelText, flagKey, order)
		local BtnFrame = Instance.new("Frame")
		BtnFrame.Size = UDim2.new(1, 0, 0, 36)
		BtnFrame.LayoutOrder = order
		BtnFrame.BackgroundColor3 = Color3.fromRGB(28, 28, 36)
		BtnFrame.Parent = Container
		Instance.new("UICorner", BtnFrame).CornerRadius = UDim.new(0, 6)

		local Stroke = Instance.new("UIStroke")
		Stroke.Thickness = 1
		Stroke.Parent = BtnFrame

		local BtnText = Instance.new("TextLabel")
		BtnText.Size = UDim2.new(0.65, 0, 1, 0)
		BtnText.Position = UDim2.new(0, 10, 0, 0)
		BtnText.BackgroundTransparency = 1
		BtnText.Text = labelText
		BtnText.TextColor3 = Color3.fromRGB(220, 220, 230)
		BtnText.Font = Enum.Font.GothamMedium
		BtnText.TextSize = 12
		BtnText.TextXAlignment = Enum.TextXAlignment.Left
		BtnText.Parent = BtnFrame

		local StatusBadge = Instance.new("TextLabel")
		StatusBadge.Size = UDim2.new(0.3, -5, 0.7, 0)
		StatusBadge.Position = UDim2.new(0.7, 0, 0.15, 0)
		StatusBadge.Font = Enum.Font.GothamBold
		StatusBadge.TextSize = 11
		StatusBadge.Parent = BtnFrame
		Instance.new("UICorner", StatusBadge).CornerRadius = UDim.new(0, 4)

		local Clicker = Instance.new("TextButton")
		Clicker.Size = UDim2.new(1, 0, 1, 0)
		Clicker.BackgroundTransparency = 1
		Clicker.Text = ""
		Clicker.Parent = BtnFrame

		local function update()
			if Flags[flagKey] then
				StatusBadge.Text = "เปิด"
				StatusBadge.BackgroundColor3 = Color3.fromRGB(35, 140, 75)
				StatusBadge.TextColor3 = Color3.fromRGB(255, 255, 255)
				Stroke.Color = Color3.fromRGB(45, 120, 70)
			else
				StatusBadge.Text = "ปิด"
				StatusBadge.BackgroundColor3 = Color3.fromRGB(140, 45, 45)
				StatusBadge.TextColor3 = Color3.fromRGB(220, 220, 220)
				Stroke.Color = Color3.fromRGB(60, 60, 70)
			end
		end

		Clicker.MouseButton1Click:Connect(function()
			Flags[flagKey] = not Flags[flagKey]
			update()
			if flagKey == "DoorESP" and not Flags.DoorESP and currentDoorTarget then
				removeHighlight(currentDoorTarget, "Door_ESP_Highlight")
			end
		end)
		update()
	end

	-- เรียงลำดับเมนูให้สวยงาม
	createToggle("DoorBtn", "มองทะลุประตู", "DoorESP", 1)
	createToggle("ItemBtn", "มองทะลุไอเทม", "ItemESP", 2)
	createToggle("EntityBtn", "มอนสเตอร์ & กับดัก", "EntityESP", 3)
	createToggle("FigureBtn", "มองทะลุ FIGURE", "FigureESP", 4)
	createToggle("WardrobeBtn", "มองทะลุตู้เสื้อผ้า", "WardrobeESP", 5) -- [ใหม่] ปุ่มตู้เสื้อผ้า
	createToggle("WarningBtn", "ข้อความเตือนภัย", "WarningText", 6)
	createToggle("SeekBtn", "สโลว์ความเร็ว Seek", "SeekSpeed", 7)

	local SpeedFrame = Instance.new("Frame")
	SpeedFrame.Size = UDim2.new(1, 0, 0, 40)
	SpeedFrame.LayoutOrder = 8 -- เลื่อนลงมา
	SpeedFrame.BackgroundColor3 = Color3.fromRGB(28, 28, 36)
	SpeedFrame.Parent = Container
	Instance.new("UICorner", SpeedFrame).CornerRadius = UDim.new(0, 6)

	local SpeedStroke = Instance.new("UIStroke")
	SpeedStroke.Color = Color3.fromRGB(60, 60, 75)
	SpeedStroke.Thickness = 1
	SpeedStroke.Parent = SpeedFrame

	local SpeedLabel = Instance.new("TextLabel")
	SpeedLabel.Size = UDim2.new(0.5, 0, 1, 0)
	SpeedLabel.Position = UDim2.new(0, 10, 0, 0)
	SpeedLabel.BackgroundTransparency = 1
	SpeedLabel.Text = "ความเร็ว: " .. tostring(Flags.WalkSpeed)
	SpeedLabel.TextColor3 = Color3.fromRGB(220, 220, 230)
	SpeedLabel.Font = Enum.Font.GothamMedium
	SpeedLabel.TextSize = 12
	SpeedLabel.TextXAlignment = Enum.TextXAlignment.Left
	SpeedLabel.Parent = SpeedFrame

	local MinusBtn = Instance.new("TextButton")
	MinusBtn.Size = UDim2.new(0.2, 0, 0.7, 0)
	MinusBtn.Position = UDim2.new(0.52, 0, 0.15, 0)
	MinusBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
	MinusBtn.Text = "-"
	MinusBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	MinusBtn.Font = Enum.Font.GothamBold
	MinusBtn.TextSize = 16
	MinusBtn.Parent = SpeedFrame
	Instance.new("UICorner", MinusBtn).CornerRadius = UDim.new(0, 4)

	local PlusBtn = Instance.new("TextButton")
	PlusBtn.Size = UDim2.new(0.2, 0, 0.7, 0)
	PlusBtn.Position = UDim2.new(0.75, 0, 0.15, 0)
	PlusBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
	PlusBtn.Text = "+"
	PlusBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	PlusBtn.Font = Enum.Font.GothamBold
	PlusBtn.TextSize = 16
	PlusBtn.Parent = SpeedFrame
	Instance.new("UICorner", PlusBtn).CornerRadius = UDim.new(0, 4)

	MinusBtn.MouseButton1Click:Connect(function()
		Flags.WalkSpeed = math.clamp(Flags.WalkSpeed - 1, 15, 25)
		SpeedLabel.Text = "ความเร็ว: " .. tostring(Flags.WalkSpeed)
	end)
	PlusBtn.MouseButton1Click:Connect(function()
		Flags.WalkSpeed = math.clamp(Flags.WalkSpeed + 1, 15, 25)
		SpeedLabel.Text = "ความเร็ว: " .. tostring(Flags.WalkSpeed)
	end)

	local ToggleGuiBtn = Instance.new("TextButton")
	ToggleGuiBtn.Name = "ToggleGuiBtn"
	ToggleGuiBtn.Size = UDim2.new(0, 50, 0, 50)
	ToggleGuiBtn.Position = UDim2.new(0.02, 0, 0.45, 0)
	ToggleGuiBtn.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
	ToggleGuiBtn.Text = "MENU"
	ToggleGuiBtn.TextColor3 = Color3.fromRGB(255, 215, 0)
	ToggleGuiBtn.Font = Enum.Font.GothamBold
	ToggleGuiBtn.TextSize = 11
	ToggleGuiBtn.Active = true
	ToggleGuiBtn.Parent = ScreenGui
	Instance.new("UICorner", ToggleGuiBtn).CornerRadius = UDim.new(1, 0)

	local BtnStroke = Instance.new("UIStroke")
	BtnStroke.Color = Color3.fromRGB(255, 215, 0)
	BtnStroke.Thickness = 1.5
	BtnStroke.Parent = ToggleGuiBtn

	makeDraggable(ToggleGuiBtn, ToggleGuiBtn)

	ToggleGuiBtn.MouseButton1Click:Connect(function()
		MainFrame.Visible = not MainFrame.Visible
	end)
end

createUI()

-- ==========================================
-- 🔍 SCANNER LOOP (Optimized for Mobile)
-- ==========================================
local function processEnemyForWarning(inst, name)
	if not inst then return end
	local currentTime = os.clock()
	if not alertedEnemyInstances[inst] then
		alertedEnemyInstances[inst] = true
		enemyAlertCooldowns[name] = currentTime + 3
	end
end

task.spawn(function()
	while true do
		local maxRoomNum = -1
		for _, room in ipairs(CurrentRooms:GetChildren()) do
			local num = tonumber(room.Name)
			if num and num > maxRoomNum then maxRoomNum = num end
		end
		latestRoomNum = maxRoomNum
		local targetRoom = CurrentRooms:FindFirstChild(tostring(maxRoomNum - 1)) or CurrentRooms:FindFirstChild(tostring(maxRoomNum))
		currentDoorTarget = targetRoom and findDoorPart(targetRoom)
		
		if Flags.DoorESP and currentDoorTarget then
			ensureHighlight(currentDoorTarget, "Door_ESP_Highlight", COLOR_YELLOW)
		end
		
		local itemsFound = {}
		
		if Flags.ItemESP then
			for lightPart, sphere in pairs(trackedHelpfulLights) do
				if not lightPart or not lightPart.Parent then
					if sphere and sphere.Parent then sphere:Destroy() end
					trackedHelpfulLights[lightPart] = nil
				end
			end
		else
			for lightPart, sphere in pairs(trackedHelpfulLights) do
				if sphere and sphere.Parent then sphere:Destroy() end
				trackedHelpfulLights[lightPart] = nil
			end
		end
		
		for _, room in ipairs(CurrentRooms:GetChildren()) do
			local num = tonumber(room.Name)
			if num and num >= (maxRoomNum - 2) then
				local nestHandler = room:FindFirstChild("_NestHandler")
				if nestHandler then
					local anchor = nestHandler:FindFirstChild("MinesAnchor")
					if anchor then
						if Flags.ItemESP then
							table.insert(itemsFound, {Part = anchor, Color = COLOR_BLUE, Label = " MINES ANCHOR "})
							ensureHighlight(anchor, "Anchor_ESP_Highlight", COLOR_BLUE)
						else removeHighlight(anchor, "Anchor_ESP_Highlight") end
					end
					local grumblesFolder = nestHandler:FindFirstChild("Grumbles")
					if grumblesFolder then
						for _, grumble in ipairs(grumblesFolder:GetChildren()) do
							local pPart = getPrimaryPartOrFallback(grumble)
							if pPart then
								if Flags.EntityESP then
									table.insert(itemsFound, {Part = pPart, Color = COLOR_RED, Label = " GRUMBLE "})
									ensureHighlight(grumble, "Grumble_ESP_Highlight", COLOR_RED)
								else removeHighlight(grumble, "Grumble_ESP_Highlight") end
							end
						end
					end
				end
				
				for _, desc in ipairs(room:GetDescendants()) do
					local validPart, label, color, hlName, category = nil, nil, nil, nil, nil
					
					if desc.Name == "KeyHitbox" and desc:IsA("BasePart") then
						validPart, label, color, hlName, category = desc, " KEY ", COLOR_GREEN, "Key_ESP_Highlight", "ItemESP"
					elseif desc.Name == "LeverForGate" then
						validPart, label, color, hlName, category = getPrimaryPartOrFallback(desc), " LEVER ", COLOR_GREEN, "Lever_ESP_Highlight", "ItemESP"
					elseif desc.Name == "FuseObtain" then
						validPart, label, color, hlName, category = getPrimaryPartOrFallback(desc), " FUSE ", COLOR_GREEN, "Fuse_ESP_Highlight", "ItemESP"
					elseif desc.Name == "MinesGenerator" then
						validPart, label, color, hlName, category = getPrimaryPartOrFallback(desc), " MINES GENERATOR ", COLOR_YELLOW, "MinesGen_ESP_Highlight", "ItemESP"
					elseif desc.Name == "LiveBreakerPolePickup" then
						validPart, label, color, hlName, category = getPrimaryPartOrFallback(desc), " BREAKER ", COLOR_GREEN, "Breaker_ESP_Highlight", "ItemESP"
					elseif desc.Name == "ElectricalKeyObtain" then
						validPart, label, color, hlName, category = getPrimaryPartOrFallback(desc), " ELECTRICAL KEY ", COLOR_GREEN, "ElecKey_ESP_Highlight", "ItemESP"
					elseif desc.Name == "LiveHintBook" or (desc.Name == "Base" and desc.Parent and desc.Parent.Name == "LiveHintBook") then
						local p = getPrimaryPartOrFallback(desc)
						if p and p:IsA("BasePart") then validPart, label, color, hlName, category = p, " BOOK ", COLOR_BLUE, "Book_ESP_Highlight", "ItemESP" end
					elseif desc.Name == "LibraryHintPaper" then
						validPart, label, color, hlName, category = getPrimaryPartOrFallback(desc), " HINT PAPER ", COLOR_BLUE, "Paper_ESP_Highlight", "ItemESP"
					
					elseif desc.Name == "GloomPile" then
						validPart, label, color, hlName, category = getPrimaryPartOrFallback(desc), " GLOOM ", COLOR_RED, "GloomRedHighlight", "EntityESP"
					elseif desc.Name == "GiggleCeiling" then
						validPart, label, color, hlName, category = getPrimaryPartOrFallback(desc), " GIGGLE ", COLOR_RED, "GiggleRedHighlight", "EntityESP"
					elseif desc.Name == "Snare" then
						validPart, label, color, hlName, category = desc, " SNARE ", COLOR_RED, "Snare_ESP_Highlight", "EntityESP"
					
					elseif desc.Name == "FigureRig" and desc:IsA("Model") then
						validPart, label, color, hlName, category = getPrimaryPartOrFallback(desc), " FIGURE ", COLOR_RED, "Figure_ESP_Highlight", "FigureESP"
					
					-- [ใหม่] ระบบหาตู้เสื้อผ้า Wardrobe 
					elseif desc.Name == "Wardrobe" then
						-- เราครอบให้ Highlight กางทั้งโมเดลตู้เสื้อผ้า
						validPart, label, color, hlName, category = desc, " WARDROBE ", COLOR_CYAN, "Wardrobe_ESP_Highlight", "WardrobeESP"

					elseif desc.Name == "HelpfulLight" then
						if Flags.ItemESP then
							local pPart = getPrimaryPartOrFallback(desc)
							if pPart then
								table.insert(itemsFound, {Part = pPart, Color = COLOR_BLUE, Label = " HELPFUL LIGHT "})
								if not trackedHelpfulLights[pPart] then
									local sphere = Instance.new("Part")
									sphere.Name = "LightTrackerSphere"
									sphere.Shape = Enum.PartType.Ball
									sphere.Size = Vector3.new(2, 2, 2)
									sphere.Color = COLOR_BLUE
									sphere.Material = Enum.Material.Neon
									sphere.CanCollide = false
									sphere.Massless = true
									sphere.Anchored = false
									sphere.CFrame = pPart.CFrame
									local weld = Instance.new("WeldConstraint")
									weld.Part0 = sphere
									weld.Part1 = pPart
									weld.Parent = sphere
									ensureHighlight(sphere, "SphereHighlight", sphere.Color)
									sphere.Parent = Workspace
									trackedHelpfulLights[pPart] = sphere
								end
							end
						end
					end
					
					if validPart and category then
						if Flags[category] then
							table.insert(itemsFound, {Part = validPart, Color = color, Label = label})
							if hlName then ensureHighlight(validPart, hlName, color) end
						else
							if hlName then removeHighlight(validPart, hlName) end
						end
					end
				end
				
				task.wait()
			end
		end
		
		local eyes = Workspace:FindFirstChild("Eyes")
		if eyes then
			if Flags.EntityESP then
				local pPart = getPrimaryPartOrFallback(eyes)
				if pPart then table.insert(itemsFound, {Part = pPart, Color = COLOR_RED, Label = "EYES"}); ensureHighlight(eyes, "EnemyESP_Highlight", COLOR_RED) end
			else removeHighlight(eyes, "EnemyESP_Highlight") end
		end
		
		local rush = Workspace:FindFirstChild("RushMoving")
		if rush then
			processEnemyForWarning(rush, "Rush")
			if Flags.EntityESP then
				local pPart = getPrimaryPartOrFallback(rush)
				if pPart then table.insert(itemsFound, {Part = pPart, Color = COLOR_RED, Label = "RUSH"}); ensureHighlight(rush, "EnemyESP_Highlight", COLOR_RED) end
			else removeHighlight(rush, "EnemyESP_Highlight") end
		end
		
		local ambush = Workspace:FindFirstChild("AmbushMoving")
		if ambush then
			processEnemyForWarning(ambush, "Ambush")
			if Flags.EntityESP then
				local pPart = getPrimaryPartOrFallback(ambush)
				if pPart then table.insert(itemsFound, {Part = pPart, Color = COLOR_RED, Label = "AMBUSH"}); ensureHighlight(ambush, "EnemyESP_Highlight", COLOR_RED) end
			else removeHighlight(ambush, "EnemyESP_Highlight") end
		end
		
		local screech = Camera:FindFirstChild("Screech") or Workspace:FindFirstChild("Screech")
		if screech then
			processEnemyForWarning(screech, "Screech")
			if Flags.EntityESP then
				local pPart = getPrimaryPartOrFallback(screech)
				if pPart then table.insert(itemsFound, {Part = pPart, Color = COLOR_RED, Label = "SCREECH"}); ensureHighlight(screech, "EnemyESP_Highlight", COLOR_RED) end
			else removeHighlight(screech, "EnemyESP_Highlight") end
		end
		
		activeItems = itemsFound
		task.wait(0.5)
	end
end)

-- ==========================================
-- 🖼️ RENDER LOOP (Optimized for Mobile)
-- ==========================================
RunService.RenderStepped:Connect(function()
	for _, textObj in pairs(textCache) do textObj.Visible = false end
	alertText.Visible = false
	
	local char = LocalPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	
	local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
	local currentTime = os.clock()
	
	if Flags.WarningText then
		if currentTime < (enemyAlertCooldowns["Rush"] or 0) then
			alertText.Position = Vector2.new(screenCenter.X, screenCenter.Y - 100)
			alertText.Text = "⚠️ WARNING: RUSH IS COMING! ⚠️"
			alertText.Visible = true
		elseif currentTime < (enemyAlertCooldowns["Ambush"] or 0) then
			alertText.Position = Vector2.new(screenCenter.X, screenCenter.Y - 100)
			alertText.Text = "⚠️ WARNING: AMBUSH IS COMING! ⚠️"
			alertText.Visible = true
		elseif currentTime < (enemyAlertCooldowns["Screech"] or 0) then
			alertText.Position = Vector2.new(screenCenter.X, screenCenter.Y - 100)
			alertText.Text = "⚠️ SCREECH! LOOK AROUND! ⚠️"
			alertText.Visible = true
		end
	end
	
	local drawIdx = 1
	
	if Flags.DoorESP and currentDoorTarget and currentDoorTarget.Parent then
		local targetPos = currentDoorTarget:IsA("Model") and currentDoorTarget:GetPivot().Position or currentDoorTarget.Position
		local dist = math.round((hrp.Position - targetPos).Magnitude)
		
		if dist <= MAX_ESP_DISTANCE then
			local vector, onScreen = Camera:WorldToViewportPoint(targetPos)
			if onScreen then
				local txt = getDrawingText(drawIdx)
				txt.Position = Vector2.new(vector.X, vector.Y - 25)
				txt.Text = string.format("[ DOOR %d ]\n%d studs", latestRoomNum, dist)
				txt.Color = COLOR_YELLOW
				txt.Visible = true
				drawIdx = drawIdx + 1
			end
		end
	end
	
	for _, item in ipairs(activeItems) do
		if item.Part and item.Part.Parent then
			local targetPos = item.Part:IsA("Model") and item.Part:GetPivot().Position or item.Part.Position
			local dist = math.round((hrp.Position - targetPos).Magnitude)
			
			if dist <= MAX_ESP_DISTANCE then
				local vector, onScreen = Camera:WorldToViewportPoint(targetPos)
				if onScreen then
					local txt = getDrawingText(drawIdx)
					txt.Position = Vector2.new(vector.X, vector.Y - 25)
					txt.Text = string.format("[%s]\n%d studs", item.Label, dist)
					txt.Color = item.Color
					txt.Visible = true
					drawIdx = drawIdx + 1
				end
			end
		end
	end
end)
