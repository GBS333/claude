-- Cada brainrot capturado (que não está no pedestal e não é o parceiro) vira um ITEM
-- na barra de itens do jogador. Segure ele e clique perto de um pedestal vazio da sua
-- base para colocar (ou use o "Colocar Brainrot" do pedestal segurando ele).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Stats = require(ReplicatedStorage.Shared.Stats)
local DataService = require(script.Parent.DataService)
local TycoonService = require(script.Parent.TycoonService)
local BrainrotModels = require(script.Parent.BrainrotModels)
local Remotes = require(script.Parent.Remotes)

local InventoryService = {}

local UID_ATTRIBUTE = "BrainrotUid"
local HOLD_HEIGHT = 2.6 -- altura do brainrot na mão
local PLACE_DISTANCE = 16

local function createTool(player: Player, item)
	local def = Config.getBrainrot(item.id)
	if not def then
		return nil
	end
	local level = item.level or 1
	local name = Stats.displayName(def, level)

	local tool = Instance.new("Tool")
	tool.Name = name .. " Lv." .. level
	tool.ToolTip = "Clique perto de um pedestal vazio da sua base para colocar"
	tool.CanBeDropped = false
	tool:SetAttribute(UID_ATTRIBUTE, item.uid)
	tool:SetAttribute("Level", level)

	-- miniatura do brainrot soldada na "Handle"
	local model = BrainrotModels.build(def, HOLD_HEIGHT / math.max(def.size.Y, 0.5), Stats.stage(level))
	local root = model.PrimaryPart
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("Humanoid") then
			d:Destroy() -- modelos da Toolbox: Humanoid dentro de ferramenta dá problema
		elseif d:IsA("BasePart") then
			d.Anchored = false
			d.Massless = true
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = false
			if d ~= root then
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = root
				weld.Part1 = d
				weld.Parent = root
			end
		end
	end
	root.Name = "Handle"
	for _, child in ipairs(model:GetChildren()) do
		child.Parent = tool
	end
	model:Destroy()

	-- segura com o brainrot em cima da mão, um pouco para a frente
	tool.Grip = CFrame.new(0, -root.Size.Y / 2, 0.6)

	tool.Activated:Connect(function()
		InventoryService.placeHeld(player, tool)
	end)
	return tool
end

function InventoryService.placeHeld(player: Player, tool: Tool)
	local uid = tool:GetAttribute(UID_ATTRIBUTE)
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not uid or not hrp or tool.Parent ~= character then
		return
	end
	local slotIndex = TycoonService.findFreeSlotNear(player, hrp.Position, PLACE_DISTANCE)
	if not slotIndex then
		Remotes.notify(player, "Chegue perto de um pedestal VAZIO da sua base 🏠 (ou desbloqueie mais pedestais).",
			Color3.fromRGB(255, 200, 90))
		return
	end
	local ok, msg = TycoonService.place(player, uid, slotIndex)
	if msg then
		Remotes.notify(player, msg, if ok then Color3.fromRGB(120, 255, 140) else Color3.fromRGB(255, 120, 120))
	end
end

-- Deixa os itens iguais ao inventário. reorder = true coloca os brainrots depois do Taco e da Bola.
function InventoryService.sync(player: Player, reorder: boolean?)
	local data = DataService.get(player)
	local backpack = player:FindFirstChild("Backpack")
	if not data or not backpack then
		return
	end

	local wanted = {}
	for _, item in ipairs(data.inventory) do
		if not item.slot and item.uid ~= data.companion then
			wanted[item.uid] = item
		end
	end

	local existing = {}
	for _, container in ipairs({ backpack, player.Character }) do
		if container then
			for _, tool in ipairs(container:GetChildren()) do
				local uid = tool:IsA("Tool") and tool:GetAttribute(UID_ATTRIBUTE)
				if uid then
					local item = wanted[uid]
					if not item or existing[uid] or tool:GetAttribute("Level") ~= (item.level or 1) then
						tool:Destroy() -- foi colocado/vendido, é repetido ou subiu de nível
					else
						existing[uid] = tool
					end
				end
			end
		end
	end

	if reorder then
		for _, tool in pairs(existing) do
			if tool.Parent == backpack then
				tool.Parent = nil
				tool.Parent = backpack
			end
		end
	end

	-- cria os que faltam, na ordem do inventário
	for _, item in ipairs(data.inventory) do
		if wanted[item.uid] and not existing[item.uid] then
			local tool = createTool(player, item)
			if tool then
				tool.Parent = backpack
			end
		end
	end
end

function InventoryService.start()
	DataService.onUpdate(function(player)
		InventoryService.sync(player)
	end)
end

return InventoryService
