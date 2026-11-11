-- Animação de ANDAR dos brainrots que têm articulações (modelos da Toolbox com
-- pernas e braços ligados por Motor6D). Roda no computador de cada jogador:
-- quando o brainrot anda, as pernas vão pra frente e pra trás e os braços balançam.
-- Modelos de uma peça só não têm articulações; eles só fazem o "gingado" do servidor.

local RunService = game:GetService("RunService")

local Animate = {}

local MAX_DISTANCE = 160 -- não anima brainrot longe da câmera (economiza)

local cache = setmetatable({}, { __mode = "k" }) -- [Model] = { motors, lastPos, phase, amount }

local function classify(name: string)
	local lower = string.lower(name)
	local kind
	if string.find(lower, "leg") or string.find(lower, "foot") or string.find(lower, "perna") then
		kind = "leg"
	elseif string.find(lower, "arm") or string.find(lower, "hand") or string.find(lower, "braco") or string.find(lower, "braço") then
		kind = "arm"
	end
	if not kind then
		return nil
	end
	local side
	if string.find(lower, "left") or string.find(lower, "esq") or string.find(lower, "^l") then
		side = 1
	elseif string.find(lower, "right") or string.find(lower, "dir") or string.find(lower, "^r") then
		side = -1
	else
		return nil
	end
	-- parte de baixo (canela/pé/mão) mexe menos
	local lowerPart = string.find(lower, "lower") or string.find(lower, "foot") or string.find(lower, "hand")
	return kind, side, if lowerPart then 0.4 else 1
end

local function scan(model: Model)
	local motors = {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("Motor6D") and d.Part1 then
			local kind, side, weight = classify(d.Part1.Name)
			if kind then
				table.insert(motors, { motor = d, kind = kind, side = side, weight = weight })
			end
		end
	end
	return { motors = motors, lastPos = model:GetPivot().Position, phase = 0, amount = 0 }
end

local function animate(model: Instance, dt: number, cameraPos: Vector3)
	if not model:IsA("Model") or not model:GetAttribute("Rigged") then
		return
	end
	local entry = cache[model]
	if not entry then
		entry = scan(model)
		cache[model] = entry
	end
	if #entry.motors == 0 then
		return
	end
	local pos = model:GetPivot().Position
	if (pos - cameraPos).Magnitude > MAX_DISTANCE then
		entry.lastPos = pos
		return
	end
	local moved = Vector3.new(pos.X - entry.lastPos.X, 0, pos.Z - entry.lastPos.Z).Magnitude
	entry.lastPos = pos
	local speed = if dt > 0 then moved / dt else 0
	-- suaviza o começo e o fim do andar
	local target = math.clamp(speed / 6, 0, 1)
	entry.amount += (target - entry.amount) * math.min(1, dt * 8)
	entry.phase += dt * (5 + math.min(speed, 25) * 0.35)

	local swing = math.sin(entry.phase)
	for _, m in ipairs(entry.motors) do
		local angle = swing * m.side * m.weight * entry.amount
		if m.kind == "leg" then
			angle *= 0.7
		else
			angle *= -0.5 -- braços balançam ao contrário das pernas
		end
		m.motor.Transform = CFrame.Angles(angle, 0, 0)
	end
end

function Animate.start()
	local folders = {}
	for _, name in ipairs({ "WildBrainrots", "Companions" }) do
		task.spawn(function()
			table.insert(folders, workspace:WaitForChild(name))
		end)
	end

	RunService.RenderStepped:Connect(function(dt)
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local cameraPos = camera.CFrame.Position
		for _, folder in ipairs(folders) do
			for _, model in ipairs(folder:GetChildren()) do
				local ok, err = pcall(animate, model, dt, cameraPos)
				if not ok then
					cache[model] = { motors = {}, lastPos = Vector3.zero, phase = 0, amount = 0 }
					warn("[Animate] " .. tostring(err))
				end
			end
		end
	end)
end

return Animate
