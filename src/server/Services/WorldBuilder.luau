-- Constrói o mapa básico: chão, zona de caça (com árvores) e o ponto de spawn.
-- As bases (tycoons) são construídas pelo TycoonService.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")

local Config = require(ReplicatedStorage.Shared.Config)

local WorldBuilder = {}

local function part(parent, props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do
		p[k] = v
	end
	p.Parent = parent
	return p
end

local function sign(parent, cf: CFrame, text: string, color: Color3)
	local board = part(parent, {
		Name = "Sign", Size = Vector3.new(30, 7, 1), CFrame = cf,
		Color = Color3.fromRGB(60, 40, 25), Material = Enum.Material.Wood,
	})
	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.CanvasSize = Vector2.new(600, 140)
		gui.LightInfluence = 0
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Text = text
		label.TextColor3 = color
		label.TextScaled = true
		label.Font = Enum.Font.FredokaOne
		label.Parent = gui
		gui.Parent = board
	end
	for _, side in ipairs({ -1, 1 }) do
		part(parent, {
			Name = "SignPost", Size = Vector3.new(1, cf.Position.Y + 3.5, 1),
			CFrame = CFrame.new((cf * CFrame.new(side * 13, 0, 0)).Position * Vector3.new(1, 0, 1) + Vector3.new(0, (cf.Position.Y + 3.5) / 2, 0)),
			Color = Color3.fromRGB(60, 40, 25), Material = Enum.Material.Wood,
		})
	end
	return board
end

local function tree(parent, pos: Vector3)
	local height = math.random(8, 14)
	part(parent, {
		Name = "Trunk", Shape = Enum.PartType.Cylinder, Size = Vector3.new(height, 2, 2),
		CFrame = CFrame.new(pos + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(105, 70, 40), Material = Enum.Material.Wood,
	})
	local leafSize = math.random(7, 10)
	part(parent, {
		Name = "Leaves", Shape = Enum.PartType.Ball, Size = Vector3.one * leafSize,
		CFrame = CFrame.new(pos + Vector3.new(0, height + leafSize / 3, 0)),
		Color = Color3.fromRGB(math.random(40, 70), math.random(140, 180), math.random(40, 70)),
		Material = Enum.Material.Grass,
	})
end

function WorldBuilder.build()
	if not Config.BuildMap then
		return
	end
	if workspace:FindFirstChild("Map") then
		workspace.Map:Destroy()
	end

	local map = Instance.new("Folder")
	map.Name = "Map"
	map.Parent = workspace

	-- remove a Baseplate padrão, se existir
	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate then
		baseplate:Destroy()
	end

	-- CHÃO
	part(map, {
		Name = "Ground", Size = Vector3.new(620, 4, 620), CFrame = CFrame.new(0, -2, 0),
		Color = Color3.fromRGB(110, 170, 90), Material = Enum.Material.Grass,
	})

	-- ZONA DE CAÇA
	local zone = Config.Wild
	local center = zone.ZoneCenter
	part(map, {
		Name = "HuntZone", Size = Vector3.new(zone.ZoneSize.X, 1, zone.ZoneSize.Y),
		CFrame = CFrame.new(center.X, zone.GroundY - 0.45, center.Z),
		Color = Color3.fromRGB(70, 140, 60), Material = Enum.Material.Grass,
	})

	-- cerquinha (postes) em volta da zona
	local halfX, halfZ = zone.ZoneSize.X / 2, zone.ZoneSize.Y / 2
	local step = 10
	for x = -halfX, halfX, step do
		for _, z in ipairs({ -halfZ, halfZ }) do
			if math.abs(x) > 12 then -- deixa uma entrada no meio
				part(map, {
					Name = "Post", Size = Vector3.new(1, 3, 1), CFrame = CFrame.new(center.X + x, 1.5, center.Z + z),
					Color = Color3.fromRGB(150, 110, 70), Material = Enum.Material.Wood,
				})
			end
		end
	end
	for z = -halfZ + step, halfZ - step, step do
		for _, x in ipairs({ -halfX, halfX }) do
			if math.abs(z) > 12 then
				part(map, {
					Name = "Post", Size = Vector3.new(1, 3, 1), CFrame = CFrame.new(center.X + x, 1.5, center.Z + z),
					Color = Color3.fromRGB(150, 110, 70), Material = Enum.Material.Wood,
				})
			end
		end
	end

	-- árvores dentro da zona
	local rng = Random.new(42)
	for _ = 1, 18 do
		local pos = Vector3.new(
			center.X + rng:NextNumber(-halfX + 10, halfX - 10),
			zone.GroundY,
			center.Z + rng:NextNumber(-halfZ + 10, halfZ - 10)
		)
		if pos.Magnitude > 20 then
			tree(map, pos)
		end
	end

	-- placas
	sign(map, CFrame.new(center.X, 8, center.Z + halfZ + 4), "🏏 ZONA DE CAÇA 🏏", Color3.fromRGB(255, 230, 80))
	sign(map, CFrame.new(center.X, 8, center.Z - halfZ - 4) * CFrame.Angles(0, math.rad(180), 0), "🏏 ZONA DE CAÇA 🏏", Color3.fromRGB(255, 230, 80))

	-- SPAWN
	local spawnLocation = workspace:FindFirstChildOfClass("SpawnLocation")
	if not spawnLocation then
		spawnLocation = Instance.new("SpawnLocation")
		spawnLocation.Parent = map
	end
	spawnLocation.Anchored = true
	spawnLocation.Size = Vector3.new(12, 1, 12)
	spawnLocation.CFrame = CFrame.new(-250, 0.5, 0)
	spawnLocation.Neutral = true
	spawnLocation.Duration = 3

	-- iluminação mais bonita
	Lighting.ClockTime = 14
	Lighting.Brightness = 2.5
	Lighting.OutdoorAmbient = Color3.fromRGB(140, 140, 150)
end

return WorldBuilder
