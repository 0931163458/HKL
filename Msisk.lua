local base = "https://github.com/PMLOLHUB/Ui-library/raw/refs/heads/main/"
local Library = loadstring(game:HttpGet(base .. "UI PMS"))()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local ConfigFolder = "ViolenceDistrictf8AqZ1RkP2nX0sM5YwE4U9D3bQGJ7mT6CLaVHxWcF0pBD4J2T7ZVKRBPLeEnNCM0sF"
local ConfigName = ConfigFolder .. "/Settings.json"

if isfolder and not isfolder(ConfigFolder) then
  makefolder(ConfigFolder)
end

local Config = {
  GeneratorESP = false,
  ExitESP = false,
  PlayerESP = false,
  WindowPalletESP = false,
  Crosshair = false,
  AutoSkillCheck = false,
  FlashlightAimbot = false,

  ESP_Line = true,
  ESP_CenterDist = true,
  ESP_KillerHighlight = true,
  ESP_SurvivorHighlight = true,
  ShiftLockEnabled = false,
  RotationSmoothness = 3,
  SkillCheckCooldown = 0,
  AimbotSmoothness = 5
}

local function SaveConfig()
  if writefile then
    pcall(function()
      writefile(ConfigName, HttpService:JSONEncode(Config))
    end)
  end
end

local function LoadConfig()
  if isfile and isfile(ConfigName) then
    local success, decoded = pcall(function()
      return HttpService:JSONDecode(readfile(ConfigName))
    end)
    if success and type(decoded) == "table" then
      for k, v in pairs(decoded) do
        Config[k] = v
      end
    end
  end
end

LoadConfig()

local GNV = {
  GeneratorESP = Config.GeneratorESP,
  ExitESP = Config.ExitESP,
  PlayerESP = Config.PlayerESP,
  WindowPalletESP = Config.WindowPalletESP,
  Crosshair = Config.Crosshair,
  AutoSkillCheck = Config.AutoSkillCheck,
  FlashlightAimbot = Config.FlashlightAimbot,
  ESP_Line = Config.ESP_Line,
  ESP_CenterDist = Config.ESP_CenterDist,
  ESP_KillerHighlight = Config.ESP_KillerHighlight,
  ESP_SurvivorHighlight = Config.ESP_SurvivorHighlight,
}

local isFlashlightAiming = false
local lastSkillCheckClick = 0

local CrosshairGui = Instance.new("ScreenGui")
CrosshairGui.Name = "CrosshairSystem"
CrosshairGui.IgnoreGuiInset = true
CrosshairGui.Enabled = GNV.Crosshair

if CoreGui:FindFirstChild("CrosshairSystem") then
  CoreGui.CrosshairSystem:Destroy()
end
CrosshairGui.Parent = CoreGui

local CROSS_COLOR = Color3.fromRGB(255, 0, 0)
local THICKNESS = 2
local LENGTH = 10
local OFFSET = 4
local center = UDim2.new(0.5, 0, 0.5, 0)

local function CreateLine(name, size, pos)
  local frame = Instance.new("Frame")
  frame.Name = name
  frame.Size = size
  frame.Position = pos
  frame.BackgroundColor3 = CROSS_COLOR
  frame.BorderSizePixel = 0
  frame.AnchorPoint = Vector2.new(0.5, 0.5)

  local stroke = Instance.new("UIStroke")
  stroke.Color = CROSS_COLOR
  stroke.Thickness = 1
  stroke.Transparency = 0.6
  stroke.Parent = frame

  frame.Parent = CrosshairGui
end

CreateLine("T", UDim2.new(0, THICKNESS, 0, LENGTH), center + UDim2.new(0, 0, 0, -(OFFSET + LENGTH/2)))
CreateLine("B", UDim2.new(0, THICKNESS, 0, LENGTH), center + UDim2.new(0, 0, 0, (OFFSET + LENGTH/2)))
CreateLine("L", UDim2.new(0, LENGTH, 0, THICKNESS), center + UDim2.new(0, -(OFFSET + LENGTH/2), 0, 0))
CreateLine("R", UDim2.new(0, LENGTH, 0, THICKNESS), center + UDim2.new(0, (OFFSET + LENGTH/2), 0, 0))

local dot = Instance.new("Frame")
dot.Name = "Dot"
dot.Size = UDim2.new(0, THICKNESS, 0, THICKNESS)
dot.Position = center
dot.BackgroundColor3 = CROSS_COLOR
dot.BorderSizePixel = 0
dot.AnchorPoint = Vector2.new(0.5, 0.5)
dot.Parent = CrosshairGui

local shiftLockEnabled = Config.ShiftLockEnabled
local moveStartTime = 0
local lerpSpeed = Config.RotationSmoothness / 10

local VALID_STATES = {
  [Enum.HumanoidStateType.Running] = true,
  [Enum.HumanoidStateType.RunningNoPhysics] = true
}

local Window = Library:CreateWindow("Violence District", {
  Logo = "rbxassetid://98985755793415",
  ThemeColor = "rainbow",
  BackgroundImage = "rbxassetid://",
  ImageTransparency = 0.4,
  ToggleConfig = {Text = ""}
})

local VisualTab = Window:CreateCategory("Visuals", "eye")
local AutoTab = Window:CreateCategory("Auto", "bot")
local MovementTap = Window:CreateCategory("Movement", "wind")
local SettingTap = Window:CreateCategory("Setting", "cog")
local severTab = Window:CreateCategory("Sever", "search")

VisualTab:CreateLabel("ESP Settings")
VisualTab:CreateToggle("Player ESP", Config.PlayerESP, function(v)
  GNV.PlayerESP = v; Config.PlayerESP = v; SaveConfig()
end)
VisualTab:CreateToggle("Generator ESP", Config.GeneratorESP, function(v)
  GNV.GeneratorESP = v; Config.GeneratorESP = v; SaveConfig()
end)
VisualTab:CreateToggle("Exit Lever ESP", Config.ExitESP, function(v)
  GNV.ExitESP = v; Config.ExitESP = v; SaveConfig()
end)
VisualTab:CreateToggle("Window & Pallet ESP", Config.WindowPalletESP, function(v)
  GNV.WindowPalletESP = v; Config.WindowPalletESP = v; SaveConfig()
end)
VisualTab:CreateToggle("Center Crosshair", Config.Crosshair, function(v)
  GNV.Crosshair = v; Config.Crosshair = v; CrosshairGui.Enabled = v; SaveConfig()
end)

AutoTab:CreateLabel("Auto Actions")
AutoTab:CreateToggle("Auto Skillcheck", Config.AutoSkillCheck, function(v)
  GNV.AutoSkillCheck = v; Config.AutoSkillCheck = v; SaveConfig()
end)
AutoTab:CreateSlider("Skillcheck Cooldown", 0, 10, Config.SkillCheckCooldown, function(v)
  Config.SkillCheckCooldown = v; SaveConfig()
end)
AutoTab:CreateToggle("Flashlight aimbot", Config.FlashlightAimbot, function(v)
  GNV.FlashlightAimbot = v; Config.FlashlightAimbot = v; if not v then isFlashlightAiming = false end; SaveConfig()
end)
AutoTab:CreateSlider("Aimbot Smoothness", 1, 10, Config.AimbotSmoothness, function(v)
  Config.AimbotSmoothness = v; SaveConfig()
end)

SettingTap:CreateLabel("ESP Player Settings")
SettingTap:CreateToggle("Show ESP Lines", Config.ESP_Line, function(v)
  GNV.ESP_Line = v; Config.ESP_Line = v; SaveConfig()
end)
SettingTap:CreateToggle("Show Center Distance", Config.ESP_CenterDist, function(v)
  GNV.ESP_CenterDist = v; Config.ESP_CenterDist = v; SaveConfig()
end)
SettingTap:CreateToggle("Killer Highlight", Config.ESP_KillerHighlight, function(v)
  GNV.ESP_KillerHighlight = v; Config.ESP_KillerHighlight = v; SaveConfig()
end)
SettingTap:CreateToggle("Survivor Highlight", Config.ESP_SurvivorHighlight, function(v)
  GNV.ESP_SurvivorHighlight = v; Config.ESP_SurvivorHighlight = v; SaveConfig()
end)

severTab:CreateLabel("Server Management")
severTab:CreateButton("Rejoin Server", function()
  TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
end)
severTab:CreateButton("Server Hop", function()
  local url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"
  local success, response = pcall(function() return game:HttpGet(url) end)
  if not success then return end
  local data = HttpService:JSONDecode(response)
  local bestServer = nil
  local bestScore = math.huge
  for _, server in ipairs(data.data) do
    if server.id ~= game.JobId and server.playing <= 3 then
      local ping = server.averagePing or 9999
      local players = server.playing or 99
      local totalScore = ping + (players * 10)
      if totalScore < bestScore then
        bestScore = totalScore
        bestServer = server.id
      end
    end
  end
  if bestServer then
    TeleportService:TeleportToPlaceInstance(game.PlaceId, bestServer, LocalPlayer)
  end
end)

MovementTap:CreateLabel("Movement Settings")
MovementTap:CreateToggle("Lock move", Config.ShiftLockEnabled, function(v)
  shiftLockEnabled = v
  Config.ShiftLockEnabled = v
  SaveConfig()

  if not v and LocalPlayer.Character then
    local humanoid = LocalPlayer.Character:FindFirstChild("Humanoid")
    if humanoid then humanoid.AutoRotate = true end
  end
  moveStartTime = 0
end)
MovementTap:CreateSlider("Rotation Smoothness", 1, 10, Config.RotationSmoothness, function(v)
  lerpSpeed = v / 10
  Config.RotationSmoothness = v
  SaveConfig()
end)

local function hasLineOfSight(from, to)
  local direction = (to - from)
  local raycastParams = RaycastParams.new()
  raycastParams.FilterType = Enum.RaycastFilterType.Exclude
  local ignoreList = {LocalPlayer.Character}
  while true do
    raycastParams.FilterDescendantsInstances = ignoreList
    local result = workspace:Raycast(from, direction, raycastParams)
    if not result then return true end
    local hit = result.Instance
    local model = hit:FindFirstAncestorOfClass("Model")
    if (model and Players:GetPlayerFromCharacter(model)) or (hit:IsA("BasePart") and hit.Transparency >= 0.9) then
      table.insert(ignoreList, hit)
      continue
    end
    return false
  end
end

local function isLookingAtMe(killerChar, myChar)
  if not killerChar or not myChar then return false end
  local head = killerChar:FindFirstChild("Head")
  local hrp = killerChar:FindFirstChild("HumanoidRootPart")
  local myHrp = myChar:FindFirstChild("HumanoidRootPart")
  if not myHrp or (not head and not hrp) then return false end
  local lookPart = head or hrp
  local dirToUs = (myHrp.Position - lookPart.Position).Unit
  local lookDir = lookPart.CFrame.LookVector
  return lookDir:Dot(dirToUs) > 0.5
end

local generatorDrawings = {}
local leverESP = {}
local espCache = {}
local windowPalletHighlights = {}

local blindSpotDrawing = Drawing.new("Text")
blindSpotDrawing.Size = 14; blindSpotDrawing.Center = true; blindSpotDrawing.Outline = true
blindSpotDrawing.Font = 2; blindSpotDrawing.Visible = false

local function isEnemy(plr)
  if plr == LocalPlayer or not plr.Team or not LocalPlayer.Team then return false end
  return plr.Team ~= LocalPlayer.Team and plr.Team.Name ~= "Spectator"
end

local function createESP(plr)
  local data = { Line = Drawing.new("Line"), Text = Drawing.new("Text"), Highlight = nil }
  data.Line.Thickness = 1.8; data.Line.Transparency = 1
  data.Text.Size = 14; data.Text.Center = true; data.Text.Outline = true; data.Text.Font = 2
  espCache[plr] = data
end

local function removeESP(plr)
  local data = espCache[plr]
  if data then
    data.Line:Remove(); data.Text:Remove()
    if data.Highlight then
      data.Highlight:Destroy()
    end
    espCache[plr] = nil
  end
end

local function updateGenerators()
  for gen, text in pairs(generatorDrawings) do
    if not GNV.GeneratorESP then text.Visible = false continue end
    local hitbox = gen:FindFirstChild("HitBox")
    if hitbox and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
      local pos, visible = Camera:WorldToViewportPoint(hitbox.Position)
      if visible then
        local dist = math.floor((LocalPlayer.Character.HumanoidRootPart.Position - hitbox.Position).Magnitude)

        local repairProgress = gen:GetAttribute("RepairProgress")
        local progressStr = ""

        if repairProgress then
          local percentage = math.floor(repairProgress)
          progressStr = " | " .. percentage .. "%"
        end

        text.Visible = true
        text.Text = "[GEN " .. dist .. progressStr .. "]"
        text.Position = Vector2.new(pos.X, pos.Y - 20)

        local light = hitbox:FindFirstChildWhichIsA("PointLight", true)
        text.Color = light and light.Color or Color3.fromRGB(255,255,255)
      else text.Visible = false end
    else text.Visible = false end
  end
end

local function updatePlayers()
  local killerVisibleInScreen = false
  local offScreenKillers = {}

  for _, plr in ipairs(Players:GetPlayers()) do
    if not GNV.PlayerESP then
      if espCache[plr] then
        espCache[plr].Line.Visible = false
        espCache[plr].Text.Visible = false
        if espCache[plr].Highlight then
          espCache[plr].Highlight.Enabled = false
        end
      end
      continue
    end

    if isEnemy(plr) and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
      if not espCache[plr] then createESP(plr) end
      local data = espCache[plr]
      local hrp = plr.Character.HumanoidRootPart
      local myHrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
      if myHrp then
        local pos, visible = Camera:WorldToViewportPoint(hrp.Position)
        local dist = math.floor((myHrp.Position - hrp.Position).Magnitude)
        local teamColor = plr.TeamColor.Color
        local hasLOS = false
        local lookingAtMe = false
        local status = ""

        local isKiller = (plr.Team and plr.Team.Name == "Killer")
        local isSurvivor = not isKiller

        local shouldHighlight = (isKiller and GNV.ESP_KillerHighlight) or (isSurvivor and GNV.ESP_SurvivorHighlight)

        if shouldHighlight and plr.Character then
          if not data.Highlight or data.Highlight.Parent ~= plr.Character then
            if data.Highlight then data.Highlight:Destroy() end
            local hl = Instance.new("Highlight")
            hl.Name = "ESP_Player_Highlight"
            hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            hl.FillTransparency = 0.5
            hl.OutlineTransparency = 0
            hl.Parent = plr.Character
            data.Highlight = hl
          end
          data.Highlight.Enabled = true
          data.Highlight.FillColor = teamColor
          data.Highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
        else
          if data.Highlight then
            data.Highlight.Enabled = false
          end
        end

        if isKiller then
          hasLOS = hasLineOfSight(myHrp.Position, hrp.Position)
          lookingAtMe = isLookingAtMe(plr.Character, LocalPlayer.Character)
          status = hasLOS and (lookingAtMe and " [👁️]" or " [⚠️]") or ""
        end

        if visible then
          data.Line.Visible = GNV.ESP_Line
          data.Line.Color = teamColor
          data.Line.From = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y - 20)
          data.Line.To = Vector2.new(pos.X, pos.Y)
          data.Text.Visible = true; data.Text.Color = teamColor
          data.Text.Text = "["..plr.Name.." | "..dist..status.."]"
          data.Text.Position = Vector2.new(pos.X, pos.Y - 25)
          if isKiller then killerVisibleInScreen = true end
        else
          data.Line.Visible = false; data.Text.Visible = false
          if isKiller then
            table.insert(offScreenKillers, {
              dist = dist, los = hasLOS,
              color = teamColor, looking = lookingAtMe
            })
          end
        end
      end
    elseif espCache[plr] then
      removeESP(plr)
    end
  end

  local closestKiller = nil
  for _, kd in ipairs(offScreenKillers) do
    if closestKiller == nil or kd.dist < closestKiller.dist then
      closestKiller = kd
    end
  end

  local showKillerInfo = (not killerVisibleInScreen) and closestKiller ~= nil and GNV.PlayerESP

  if showKillerInfo and GNV.ESP_CenterDist then
    blindSpotDrawing.Visible = true
    blindSpotDrawing.Position = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
    if closestKiller.los and closestKiller.looking then
      blindSpotDrawing.Text = "[ " .. closestKiller.dist .. " : 👁️ ]"
      blindSpotDrawing.Color = Color3.fromRGB(255, 0, 0)
    elseif closestKiller.los then
      blindSpotDrawing.Text = "[ " .. closestKiller.dist .. " : ⚠️ ]"
      blindSpotDrawing.Color = Color3.fromRGB(255, 165, 0)
    else
      blindSpotDrawing.Text = "[ Killer : " .. closestKiller.dist .. " ]"
      blindSpotDrawing.Color = closestKiller.color
    end
  else
    blindSpotDrawing.Visible = false
  end
end

local function updateLevers()
  for lever, text in pairs(leverESP) do
    if not GNV.ExitESP then text.Visible = false continue end
    if lever and lever.Parent then
      local highlight = lever:FindFirstChildWhichIsA("Highlight", true)
      if highlight then
        local part = lever:IsA("BasePart") and lever or lever:FindFirstChildWhichIsA("BasePart")
        if part and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
          local pos, visible = Camera:WorldToViewportPoint(part.Position)
          if visible then
            local distance = math.floor((LocalPlayer.Character.HumanoidRootPart.Position - part.Position).Magnitude)
            text.Visible = true
            text.Text = "[EXIT "..distance.."]"
            text.Position = Vector2.new(pos.X, pos.Y - 20)
            local bulb3 = lever:FindFirstChild("Bulb3")
            local pointLight = bulb3 and bulb3:FindFirstChildWhichIsA("PointLight")
            if pointLight and pointLight.Enabled then
              text.Color = Color3.fromRGB(0, 255, 0)
            else
              text.Color = highlight.FillColor
            end
          else
            text.Visible = false
          end
        else
          text.Visible = false
        end
      else
        text.Visible = false
      end
    else
      text.Visible = false
    end
  end
end

local function removeWPHighlight(obj)
  local data = windowPalletHighlights[obj]
  if data then
    if type(data) == "table" then
      if data.Part then data.Part:Destroy() end
      if data.Visual then data.Visual:Destroy() end
    else
      data:Destroy()
    end
    windowPalletHighlights[obj] = nil
  end
end

local function checkWPObject(obj)
  if not obj then return end

  if obj.Name == "Palletwrong" or obj.Name == "Pallet" then
    if windowPalletHighlights[obj] then return end

    local hl = Instance.new("Highlight")
    hl.FillColor = Color3.fromRGB(255,205,0)
    hl.OutlineColor = Color3.fromRGB(255,205,0)
    hl.FillTransparency = 0.5
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Adornee = obj
    hl.Enabled = false
    hl.Parent = obj

    windowPalletHighlights[obj] = hl

    obj.AncestryChanged:Connect(function(_, parent)
      if not parent then removeWPHighlight(obj) end
    end)
    return
  end

  if obj.Name == "VaultTrigger" then
    local target = obj.Parent or obj
    if windowPalletHighlights[target] then return end

    local espPart = Instance.new("Part")
    espPart.Name = "WindowFakePart_ESP"
    espPart.Size = Vector3.new(3.5, 4.5, 0.5)
    espPart.Anchored = true
    espPart.CanCollide = false
    espPart.CanTouch = false
    espPart.CanQuery = false
    espPart.Transparency = 1
    espPart.Color = Color3.fromRGB(255, 205, 0)
    espPart.Material = Enum.Material.Neon

    if target:IsA("Model") then
      if target.PrimaryPart then
        espPart.CFrame = target.PrimaryPart.CFrame
      else
        espPart.CFrame = target:GetPivot()
      end
    elseif target:IsA("BasePart") then
      espPart.CFrame = target.CFrame
    else
      espPart.CFrame = obj.CFrame
    end
    espPart.Parent = workspace

    local hl = Instance.new("Highlight")
    hl.FillColor = Color3.fromRGB(255, 205, 0)
    hl.OutlineColor = Color3.fromRGB(255, 255, 255)
    hl.FillTransparency = 0.5
    hl.OutlineTransparency = 0
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Adornee = espPart
    hl.Enabled = false
    hl.Parent = espPart

    windowPalletHighlights[target] = { Part = espPart, Visual = hl }

    target.AncestryChanged:Connect(function(_, parent)
      if not parent then removeWPHighlight(target) end
    end)
    return
  end
end

local function updateWindowPalletESP()
  local character = LocalPlayer.Character
  local root = character and character:FindFirstChild("HumanoidRootPart")

  for obj, data in pairs(windowPalletHighlights) do
    local isTable = (type(data) == "table")

    if not GNV.WindowPalletESP or not root or not obj or not obj.Parent then
      if isTable then
        data.Visual.Enabled = false
        data.Part.Transparency = 1
      else
        if data:IsA("Highlight") then data.Enabled = false end
      end
      continue
    end

    local pos
    if obj:IsA("Model") then
      pos = obj:GetPivot().Position
    elseif obj:IsA("BasePart") then
      pos = obj.Position
    end

    if pos then
      local inRange = (root.Position - pos).Magnitude <= 120

      if isTable then
        data.Visual.Enabled = inRange
        data.Part.Transparency = inRange and 0 or 1
      else
        if data:IsA("Highlight") then
          data.Enabled = inRange
        end
      end
    else
      if isTable then
        data.Visual.Enabled = true
        data.Part.Transparency = 0
      else
        if data:IsA("Highlight") then data.Enabled = true end
      end
    end
  end
end

local function updateShiftLock()
  if not shiftLockEnabled then return end

  if GNV.FlashlightAimbot and isFlashlightAiming then
    if LocalPlayer.Character then
      local humanoid = LocalPlayer.Character:FindFirstChild("Humanoid")
      if humanoid then humanoid.AutoRotate = true end
    end
    moveStartTime = 0
    return
  end

  local character = LocalPlayer.Character
  if not character then return end

  local humanoid = character:FindFirstChild("Humanoid")
  local hrp = character:FindFirstChild("HumanoidRootPart")
  local head = character:FindFirstChild("Head")
  if not humanoid or not hrp or not head then return end

  local distance = (Camera.CFrame.Position - head.Position).Magnitude
  if distance < 1 then
    humanoid.AutoRotate = true
    moveStartTime = 0
    return
  end

  if humanoid.FloorMaterial == Enum.Material.Air then
    humanoid.AutoRotate = true
    moveStartTime = 0
    return
  end

  local state = humanoid:GetState()
  if not VALID_STATES[state] then
    humanoid.AutoRotate = true
    moveStartTime = 0
    return
  end

  local moveDir = humanoid.MoveDirection
  if moveDir.Magnitude <= 0.01 then
    humanoid.AutoRotate = true
    moveStartTime = 0
    return
  end

  if moveStartTime == 0 then
    moveStartTime = tick()
  end

  if tick() - moveStartTime < 0.5 then
    humanoid.AutoRotate = true
    return
  end

  humanoid.AutoRotate = false

  local direction = Vector3.new(moveDir.X, 0, moveDir.Z)
  if direction.Magnitude > 0 then
    local targetCFrame = CFrame.lookAt(hrp.Position, hrp.Position + direction)
    local currentCF = hrp.CFrame

    local _, targetY, _ = targetCFrame:ToEulerAnglesYXZ()
    local newCF = CFrame.new(currentCF.Position) * CFrame.Angles(0, targetY, 0)

    hrp.CFrame = currentCF:Lerp(newCF, lerpSpeed)
  end
end

local oldNamecall
oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
  local method = getnamecallmethod()
  local args = {...}

  if method == "FireServer" and self.Name == "Activate" and self.Parent and self.Parent.Name == "Flashlight" then
    if GNV.FlashlightAimbot then
      if args[2] == true then
        isFlashlightAiming = true
      elseif args[2] == false then
        isFlashlightAiming = false
      end
    end
  end
  return oldNamecall(self, ...)
end)

local function scanGenerators()
  for _, v in ipairs(workspace:GetDescendants()) do
    if v.Name == "Generator" and v:FindFirstChild("HitBox") then
      local text = Drawing.new("Text")
      text.Size = 14; text.Center = true; text.Outline = true; text.Font = 2; text.Transparency = 1
      generatorDrawings[v] = text
    end
  end
end

scanGenerators()
workspace.DescendantAdded:Connect(function(v)
  task.wait()
  if v.Name == "Generator" and v:FindFirstChild("HitBox") then
    local text = Drawing.new("Text")
    text.Size = 14; text.Center = true; text.Outline = true; text.Font = 2; text.Transparency = 1
    generatorDrawings[v] = text
  end
end)

local function createLeverESP(lever)
  if leverESP[lever] then return end
  local text = Drawing.new("Text")
  text.Size = 14; text.Center = true; text.Outline = true; text.Font = 2; text.Transparency = 1
  leverESP[lever] = text
end

local function scanLevers()
  for _, v in ipairs(workspace:GetDescendants()) do
    if v.Name == "ExitLever" then createLeverESP(v) end
  end
end

scanLevers()
workspace.DescendantAdded:Connect(function(v)
  task.wait()
  if v.Name == "ExitLever" then createLeverESP(v) end
end)

task.spawn(function()
  for _, obj in ipairs(workspace:GetDescendants()) do
    checkWPObject(obj)
  end
  workspace.DescendantAdded:Connect(checkWPObject)
end)

local function setupCharacter(character)
  local humanoid = character:WaitForChild("Humanoid")
  humanoid.AutoRotate = true
end

if LocalPlayer.Character then setupCharacter(LocalPlayer.Character) end
LocalPlayer.CharacterAdded:Connect(function(character)
  setupCharacter(character)
  moveStartTime = 0
end)

RunService.RenderStepped:Connect(function()
  updateGenerators()
  updateLevers()
  updatePlayers()
  updateShiftLock()
  updateWindowPalletESP()

  if GNV.FlashlightAimbot and isFlashlightAiming then
    local killerTarget = nil
    for _, plr in ipairs(Players:GetPlayers()) do
      if plr.Team and plr.Team.Name == "Killer" and plr.Character and plr.Character:FindFirstChild("Head") then
        killerTarget = plr.Character
        break
      end
    end

    if killerTarget then
      local targetCFrame = CFrame.lookAt(Camera.CFrame.Position, killerTarget.Head.Position)
      local aimSmoothSpeed = Config.AimbotSmoothness / 10
      Camera.CFrame = Camera.CFrame:Lerp(targetCFrame, aimSmoothSpeed)
    end
  end

  if GNV.AutoSkillCheck then
    local skillCheckGui = PlayerGui:FindFirstChild("SkillCheckPromptGui")
    local checkFrame = skillCheckGui and skillCheckGui:FindFirstChild("Check")

    if checkFrame and checkFrame.Visible then
      local line = checkFrame:FindFirstChild("Line")
      local goal = checkFrame:FindFirstChild("Goal")
      local survivorMob = PlayerGui:FindFirstChild("Survivor-mob")
      local controls = survivorMob and survivorMob:FindFirstChild("Controls")
      local btn = controls and controls:FindFirstChild("action")

      if line and goal and btn then
        local currentRotation = line.Rotation
        local perfectMin = 102 + goal.Rotation
        local perfectMax = 116 + goal.Rotation
        local fallbackMax = 135 + goal.Rotation

        if currentRotation >= perfectMin and currentRotation <= fallbackMax then
          if tick() - lastSkillCheckClick >= (Config.SkillCheckCooldown / 10) then
            lastSkillCheckClick = tick()
            if firesignal then
              firesignal(btn.MouseButton1Down)
              firesignal(btn.MouseButton1Click)
              firesignal(btn.MouseButton1Up)
              firesignal(btn.Activated)
            else
              btn:SimulateClick()
            end
          end
        end
      end
    end
  end
end)

Players.PlayerRemoving:Connect(removeESP)
