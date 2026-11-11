-- Interface do jogador + arremesso da bola.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local mouse = player:GetMouse()

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local CatchMath = require(Shared:WaitForChild("CatchMath"))
local Stats = require(Shared:WaitForChild("Stats"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local ThrowBall = Remotes:WaitForChild("ThrowBall")
local DataUpdated = Remotes:WaitForChild("DataUpdated")
local Notify = Remotes:WaitForChild("Notify")
local CatchResult = Remotes:WaitForChild("CatchResult")
local CompanionEvent = Remotes:WaitForChild("CompanionEvent")
local Action = Remotes:WaitForChild("Action")

local fmt = CatchMath.formatNumber
local data = nil -- última cópia dos dados vinda do servidor

local GREEN = Color3.fromRGB(110, 230, 120)
local RED = Color3.fromRGB(255, 110, 110)
local DARK = Color3.fromRGB(28, 30, 40)
local DARK2 = Color3.fromRGB(45, 48, 62)

---------------------------------------------------------------------
-- Funções para criar interface
---------------------------------------------------------------------
local function new(className: string, props)
	local inst = Instance.new(className)
	local parent = props.Parent
	props.Parent = nil
	for k, v in pairs(props) do
		inst[k] = v
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

local function corner(parent, radius)
	return new("UICorner", { CornerRadius = UDim.new(0, radius or 10), Parent = parent })
end

local function stroke(parent, color, thickness)
	return new("UIStroke", {
		Color = color or Color3.new(0, 0, 0),
		Thickness = thickness or 2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = parent,
	})
end

local function label(props)
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.TextColor3 = props.TextColor3 or Color3.new(1, 1, 1)
	props.Font = props.Font or Enum.Font.GothamBold
	props.TextScaled = if props.TextScaled == nil then true else props.TextScaled
	return new("TextLabel", props)
end

local function button(props)
	props.BackgroundColor3 = props.BackgroundColor3 or Color3.fromRGB(70, 140, 255)
	props.TextColor3 = props.TextColor3 or Color3.new(1, 1, 1)
	props.Font = props.Font or Enum.Font.FredokaOne
	props.TextScaled = true
	props.AutoButtonColor = true
	local b = new("TextButton", props)
	corner(b, 8)
	new("UIPadding", {
		PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6),
		PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4), Parent = b,
	})
	return b
end

local gui = new("ScreenGui", {
	Name = "BrainrotUI",
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = player:WaitForChild("PlayerGui"),
})

---------------------------------------------------------------------
-- Notificações
---------------------------------------------------------------------
local toastList = new("Frame", {
	Name = "Toasts", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 70),
	Size = UDim2.new(0.6, 0, 0, 300), BackgroundTransparency = 1, Parent = gui,
})
new("UIListLayout", {
	HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 6),
	SortOrder = Enum.SortOrder.LayoutOrder, Parent = toastList,
})
new("UISizeConstraint", { MaxSize = Vector2.new(600, 300), Parent = toastList })

local toastOrder = 0
local function toast(text: string, color: Color3?)
	toastOrder += 1
	local frame = new("Frame", {
		Size = UDim2.new(1, 0, 0, 36), BackgroundColor3 = DARK, BackgroundTransparency = 0.15,
		LayoutOrder = toastOrder, Parent = toastList,
	})
	corner(frame, 8)
	local s = stroke(frame, color or Color3.new(1, 1, 1), 2)
	local l = label({
		Size = UDim2.new(1, -16, 1, -8), Position = UDim2.fromOffset(8, 4),
		Text = text, TextColor3 = color or Color3.new(1, 1, 1), Parent = frame,
	})
	-- no máximo 5 na tela
	local children = {}
	for _, child in ipairs(toastList:GetChildren()) do
		if child:IsA("Frame") then
			table.insert(children, child)
		end
	end
	if #children > 5 then
		table.sort(children, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		children[1]:Destroy()
	end
	task.delay(3.5, function()
		if frame.Parent then
			local info = TweenInfo.new(0.4)
			TweenService:Create(frame, info, { BackgroundTransparency = 1 }):Play()
			TweenService:Create(l, info, { TextTransparency = 1 }):Play()
			TweenService:Create(s, info, { Transparency = 1 }):Play()
			task.wait(0.45)
			frame:Destroy()
		end
	end)
end

local function act(name: string, ...)
	local ok, msg = Action:InvokeServer(name, ...)
	if type(msg) == "string" then
		toast(msg, if ok then GREEN else RED)
	end
	return ok, msg
end

---------------------------------------------------------------------
-- Dinheiro (canto superior esquerdo)
---------------------------------------------------------------------
local cashFrame = new("Frame", {
	Position = UDim2.fromOffset(12, 12), Size = UDim2.fromOffset(250, 100),
	BackgroundColor3 = DARK, BackgroundTransparency = 0.1, Parent = gui,
})
corner(cashFrame, 12)
stroke(cashFrame, Color3.fromRGB(90, 220, 110), 2)
local cashLabel = label({
	Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -20, 0, 38),
	Text = "💰 $0", TextColor3 = Color3.fromRGB(120, 255, 140), Font = Enum.Font.FredokaOne,
	TextXAlignment = Enum.TextXAlignment.Left, Parent = cashFrame,
})
local incomeLabel = label({
	Position = UDim2.fromOffset(10, 40), Size = UDim2.new(1, -20, 0, 20),
	Text = "Renda: +$0/s", TextColor3 = Color3.fromRGB(200, 255, 200),
	TextXAlignment = Enum.TextXAlignment.Left, Parent = cashFrame,
})
local levelLabel = label({
	Position = UDim2.fromOffset(10, 62), Size = UDim2.new(1, -20, 0, 16),
	Text = "⭐ Nível 1", TextColor3 = Color3.fromRGB(255, 230, 120),
	TextXAlignment = Enum.TextXAlignment.Left, Parent = cashFrame,
})
local playerXpBack = new("Frame", {
	Position = UDim2.fromOffset(10, 82), Size = UDim2.new(1, -20, 0, 10),
	BackgroundColor3 = Color3.fromRGB(50, 50, 60), BorderSizePixel = 0, Parent = cashFrame,
})
corner(playerXpBack, 5)
local playerXpFill = new("Frame", {
	Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.fromRGB(255, 210, 80), BorderSizePixel = 0, Parent = playerXpBack,
})
corner(playerXpFill, 5)

---------------------------------------------------------------------
-- Dica de como jogar
---------------------------------------------------------------------
local hint = label({
	AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -175), Size = UDim2.new(0.7, 0, 0, 26),
	Text = "🏏 Bata com o Taco  •  ⚪ Bola quando estiverem com POUCA vida  •  ⚔ Escolha um PARCEIRO no 🎒 para lutar e evoluir  •  🏠 Pedestais dão $",
	TextColor3 = Color3.fromRGB(255, 240, 160), TextStrokeTransparency = 0.3, Parent = gui,
})
new("UISizeConstraint", { MaxSize = Vector2.new(900, 26), Parent = hint })
task.delay(40, function()
	TweenService:Create(hint, TweenInfo.new(1), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
end)

---------------------------------------------------------------------
-- Seletor de bolas (embaixo)
---------------------------------------------------------------------
local ballBar = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -100),
	Size = UDim2.fromOffset(#Config.Balls * 100, 58), BackgroundTransparency = 1, Parent = gui,
})
new("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center,
	Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = ballBar,
})

local ballButtons = {}
for i, ballDef in ipairs(Config.Balls) do
	local b = button({
		Size = UDim2.fromOffset(92, 56), LayoutOrder = i, BackgroundColor3 = ballDef.color,
		Text = ballDef.name .. "\nx0", Parent = ballBar,
	})
	local s = stroke(b, Color3.new(1, 1, 1), 0)
	ballButtons[ballDef.id] = { button = b, stroke = s }
	b.Activated:Connect(function()
		act("SelectBall", ballDef.id)
	end)
end

---------------------------------------------------------------------
-- Menu lateral + painéis
---------------------------------------------------------------------
local menu = new("Frame", {
	AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0),
	Size = UDim2.fromOffset(150, 8 * 46), BackgroundTransparency = 1, Parent = gui,
})
new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = menu })

local panel = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.9, 0.75),
	BackgroundColor3 = DARK, Visible = false, Parent = gui,
})
corner(panel, 14)
stroke(panel, Color3.fromRGB(255, 255, 255), 2)
new("UISizeConstraint", { MaxSize = Vector2.new(560, 460), Parent = panel })

local panelTitle = label({
	Position = UDim2.fromOffset(16, 8), Size = UDim2.new(1, -70, 0, 36), Font = Enum.Font.FredokaOne,
	TextXAlignment = Enum.TextXAlignment.Left, Text = "", Parent = panel,
})
local closeButton = button({
	AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 10), Size = UDim2.fromOffset(36, 36),
	Text = "X", BackgroundColor3 = Color3.fromRGB(220, 70, 70), Parent = panel,
})
local scroll = new("ScrollingFrame", {
	Position = UDim2.fromOffset(12, 54), Size = UDim2.new(1, -24, 1, -66), BackgroundTransparency = 1,
	BorderSizePixel = 0, ScrollBarThickness = 8, CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = panel,
})
new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = scroll })

local currentPanel = nil
local renderers = {}
local dataListeners = {}

local function clearScroll()
	for _, child in ipairs(scroll:GetChildren()) do
		if not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end
end

local function row(order: number, height: number?)
	local f = new("Frame", {
		Size = UDim2.new(1, -10, 0, height or 60), BackgroundColor3 = DARK2, LayoutOrder = order, Parent = scroll,
	})
	corner(f, 8)
	return f
end

local function header(order: number, text: string)
	label({
		Size = UDim2.new(1, -10, 0, 28), LayoutOrder = order, Text = text, Font = Enum.Font.FredokaOne,
		TextColor3 = Color3.fromRGB(255, 220, 120), TextXAlignment = Enum.TextXAlignment.Left, Parent = scroll,
	})
end

local function rowText(parent, title: string, titleColor: Color3, subtitle: string, rightSpace: number)
	label({
		Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -(rightSpace + 18), 0, 24), Text = title,
		TextColor3 = titleColor, Font = Enum.Font.FredokaOne, TextXAlignment = Enum.TextXAlignment.Left, Parent = parent,
	})
	label({
		Position = UDim2.fromOffset(12, 32), Size = UDim2.new(1, -(rightSpace + 18), 0, 20), Text = subtitle,
		TextColor3 = Color3.fromRGB(200, 200, 210), Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left,
		Parent = parent,
	})
end

local function openPanel(name: string?)
	if name == nil or currentPanel == name then
		currentPanel = nil
		panel.Visible = false
		return
	end
	currentPanel = name
	panel.Visible = true
	renderers[name]()
end

local function refreshPanel()
	if currentPanel then
		renderers[currentPanel]()
	end
end

closeButton.Activated:Connect(function()
	openPanel(nil)
end)

---------------------------------------------------------------------
-- Painel: BRAINROTS (inventário)
---------------------------------------------------------------------
renderers.Inventory = function()
	panelTitle.Text = "🎒 Seus Brainrots"
	clearScroll()
	if not data then
		return
	end

	-- desbloquear pedestais
	local unlockRow = row(0, 56)
	local nextIndex = data.unlockedSlots + 1
	local used = 0
	for _, item in ipairs(data.inventory) do
		if item.slot then
			used += 1
		end
	end
	local maxSlots = Stats.maxSlots(data.rebirths)
	rowText(unlockRow, "Pedestais: " .. used .. " usados / " .. data.unlockedSlots .. " desbloqueados",
		Color3.new(1, 1, 1), "Máximo agora: " .. maxSlots .. " (mais com ♻ Rebirth, até " .. Config.Tycoon.SlotCount .. ")", 150)
	if nextIndex <= maxSlots then
		local price = Config.Tycoon.SlotPrices[nextIndex] or 0
		local b = button({
			AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(140, 40),
			Text = "🔓 $" .. fmt(price), BackgroundColor3 = Color3.fromRGB(60, 170, 90), Parent = unlockRow,
		})
		b.Activated:Connect(function()
			act("Unlock")
		end)
	end

	if #data.inventory == 0 then
		local r = row(1, 60)
		rowText(r, "Nenhum brainrot ainda!", Color3.new(1, 1, 1), "Vá para a Zona de Caça e capture alguns.", 0)
		return
	end

	local items = table.clone(data.inventory)
	local function sortKey(item)
		if item.uid == data.companion then
			return 2
		elseif item.slot then
			return 1
		end
		return 0
	end
	table.sort(items, function(a, b)
		local ka, kb = sortKey(a), sortKey(b)
		if ka ~= kb then
			return ka > kb
		end
		local da, db = Config.getBrainrot(a.id), Config.getBrainrot(b.id)
		return Stats.income(da, a.level or 1, a.mutation) > Stats.income(db, b.level or 1, b.mutation)
	end)

	for i, item in ipairs(items) do
		local def = Config.getBrainrot(item.id)
		if def then
			local level = item.level or 1
			local rarity = Config.getRarity(def.rarity)
			local isCompanion = item.uid == data.companion
			local r = row(i, 60)
			if isCompanion then
				stroke(r, Color3.fromRGB(120, 220, 255), 2)
			end
			new("Frame", { Size = UDim2.new(0, 6, 1, 0), BackgroundColor3 = rarity.color, BorderSizePixel = 0, Parent = r })
			local where = if isCompanion then "⚔ Parceiro" elseif item.slot then "Pedestal " .. item.slot else "Guardado"
			local xpText = if level >= Config.Levels.MaxLevel then "MÁX"
				else "XP " .. math.floor(item.xp or 0) .. "/" .. Stats.xpToNext(level)
			local income = Stats.income(def, level, item.mutation) * Stats.rebirthIncomeMultiplier(data.rebirths)
			rowText(r, Stats.displayName(def, level, item.mutation) .. "  Lv." .. level, rarity.color,
				rarity.display .. " • +$" .. fmt(income) .. "/s • " .. xpText .. " • " .. where, 270)

			local companionButton = button({
				AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -180, 0.5, 0), Size = UDim2.fromOffset(80, 40),
				Text = if isCompanion then "Recolher" else "⚔ Lutar",
				BackgroundColor3 = if isCompanion then Color3.fromRGB(120, 120, 140) else Color3.fromRGB(200, 70, 90),
				Parent = r,
			})
			companionButton.Activated:Connect(function()
				if isCompanion then
					act("Dismiss")
				else
					act("Summon", item.uid)
				end
			end)

			local placeButton = button({
				AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -94, 0.5, 0), Size = UDim2.fromOffset(80, 40),
				Text = if item.slot then "Guardar" else "Colocar",
				BackgroundColor3 = if item.slot then Color3.fromRGB(120, 120, 140) else Color3.fromRGB(70, 140, 255),
				Parent = r,
			})
			placeButton.Activated:Connect(function()
				act(if item.slot then "Store" else "Place", item.uid)
			end)

			local price = Stats.sellPrice(def, level, item.mutation)
			local sellButton = button({
				AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(80, 40),
				Text = "Vender $" .. fmt(price), BackgroundColor3 = Color3.fromRGB(230, 150, 40), Parent = r,
			})
			local confirming = false
			sellButton.Activated:Connect(function()
				if not confirming then
					confirming = true
					sellButton.Text = "Certeza?"
					sellButton.BackgroundColor3 = Color3.fromRGB(220, 60, 60)
					task.delay(2.5, function()
						if sellButton.Parent then
							confirming = false
							sellButton.Text = "Vender $" .. fmt(price)
							sellButton.BackgroundColor3 = Color3.fromRGB(230, 150, 40)
						end
					end)
					return
				end
				act("Sell", item.uid)
			end)
		end
	end
end

---------------------------------------------------------------------
-- Painel: LOJA
---------------------------------------------------------------------
renderers.Shop = function()
	panelTitle.Text = "🛒 Loja"
	clearScroll()
	if not data then
		return
	end
	local rebirths = data.rebirths or 0
	local LOCKED = Color3.fromRGB(90, 90, 100)

	header(0, "⚪ Bolas de Captura")
	for i, ballDef in ipairs(Config.Balls) do
		local r = row(i, 60)
		new("Frame", { Size = UDim2.new(0, 6, 1, 0), BackgroundColor3 = ballDef.color, BorderSizePixel = 0, Parent = r })
		local locked = (ballDef.rebirth or 0) > rebirths
		rowText(r, ballDef.name .. "  (você tem " .. (data.balls[ballDef.id] or 0) .. ")", ballDef.color,
			"Chance x" .. ballDef.multiplier .. " • $" .. fmt(ballDef.price) .. " cada"
				.. (if locked then " • 🔒 ♻ Rebirth " .. ballDef.rebirth else ""), 210)
		for j, amount in ipairs({ 1, 5, 10 }) do
			local b = button({
				AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8 - (3 - j) * 70, 0.5, 0),
				Size = UDim2.fromOffset(64, 40), Text = if locked then "🔒" else "x" .. amount,
				BackgroundColor3 = if locked then LOCKED else Color3.fromRGB(60, 170, 90), Parent = r,
			})
			b.Activated:Connect(function()
				act("BuyBall", ballDef.id, amount)
			end)
		end
	end

	header(100, "🏏 Objetos de Bater (acertam brainrots e jogadores)")
	for i, batDef in ipairs(Config.Bats) do
		local r = row(100 + i, 60)
		new("Frame", { Size = UDim2.new(0, 6, 1, 0), BackgroundColor3 = batDef.color, BorderSizePixel = 0, Parent = r })
		local owned = data.ownedBats[batDef.id]
		local equipped = data.bat == batDef.id
		local locked = not owned and (batDef.rebirth or 0) > rebirths
		rowText(r, batDef.name, batDef.color,
			"Dano " .. batDef.damage .. " • PvP " .. batDef.pvpDamage .. " • Empurrão " .. batDef.knockback
				.. (if owned then "" else " • $" .. fmt(batDef.price))
				.. (if locked then " • 🔒 ♻ " .. batDef.rebirth else ""), 130)
		local b = button({
			AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(120, 40),
			Text = if equipped then "Equipado" elseif owned then "Equipar" elseif locked then "🔒 Rebirth" else "Comprar",
			BackgroundColor3 = if equipped then Color3.fromRGB(100, 100, 110) elseif owned then Color3.fromRGB(70, 140, 255)
				elseif locked then LOCKED else Color3.fromRGB(60, 170, 90),
			Parent = r,
		})
		b.Activated:Connect(function()
			if not equipped then
				act("BuyBat", batDef.id)
			end
		end)
	end

	header(200, "🎽 Equipamentos")
	for i, gear in ipairs(Config.Gear) do
		local r = row(200 + i, 60)
		new("Frame", { Size = UDim2.new(0, 6, 1, 0), BackgroundColor3 = gear.color, BorderSizePixel = 0, Parent = r })
		local owned = data.ownedGear and data.ownedGear[gear.id]
		local locked = not owned and (gear.rebirth or 0) > rebirths
		rowText(r, gear.name, gear.color, gear.description .. (if owned then "" else " • $" .. fmt(gear.price)), 130)
		local b = button({
			AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(120, 40),
			Text = if owned then "✔ Seu" elseif locked then "🔒 Rebirth" else "Comprar",
			BackgroundColor3 = if owned then Color3.fromRGB(100, 100, 110) elseif locked then LOCKED else Color3.fromRGB(60, 170, 90),
			Parent = r,
		})
		b.Activated:Connect(function()
			if not owned then
				act("BuyGear", gear.id)
			end
		end)
	end

	local tip = row(300, 56)
	rowText(tip, "💡 Dica", Color3.fromRGB(255, 220, 120),
		"Arma forte demais nocauteia o brainrot! Martelo e frigideira empurram muito os jogadores.", 0)
end

---------------------------------------------------------------------
-- Painel: BRAINROTDEX
---------------------------------------------------------------------
renderers.Dex = function()
	panelTitle.Text = "📖 Brainrotdex"
	clearScroll()
	if not data then
		return
	end
	local found = 0
	for _, def in ipairs(Config.Brainrots) do
		if data.dex[def.id] then
			found += 1
		end
	end
	header(0, "Descobertos: " .. found .. " / " .. #Config.Brainrots .. "   •   Total capturados: " .. data.totalCaught)
	local mutationNames = {}
	for _, id in ipairs(Config.MutationOrder) do
		local m = Config.Mutations[id]
		table.insert(mutationNames, m.icon .. m.name .. " x" .. m.income)
	end
	local mrow = row(0.5, 56)
	rowText(mrow, "🧬 Mutações (renda)", Color3.fromRGB(255, 220, 120), table.concat(mutationNames, "  "), 0)

	for i, def in ipairs(Config.Brainrots) do
		local rarity = Config.getRarity(def.rarity)
		local r = row(i, 60)
		new("Frame", { Size = UDim2.new(0, 6, 1, 0), BackgroundColor3 = rarity.color, BorderSizePixel = 0, Parent = r })
		local times = data.dex[def.id]
		local biome = Config.getBiome(def.biome)
		local where = if biome then biome.icon .. " " .. biome.name else "?"
		if times then
			local evoText = if def.evolutions then " • Evolui: " .. table.concat(def.evolutions, " → ") else ""
			rowText(r, def.name .. "  (x" .. times .. ")", rarity.color,
				rarity.display .. " • " .. where .. " • Captura " .. math.floor(def.catchRate * 1000) / 10 .. "%" .. evoText, 0)
		else
			rowText(r, "???", Color3.fromRGB(150, 150, 160), rarity.display .. " • Vive em: " .. where, 0)
		end
	end
end

---------------------------------------------------------------------
-- Botões do menu
---------------------------------------------------------------------
local menuItems = {
	{ text = "🎒 Brainrots", color = Color3.fromRGB(70, 140, 255), click = function() openPanel("Inventory") end },
	{ text = "🛒 Loja", color = Color3.fromRGB(60, 170, 90), click = function() openPanel("Shop") end },
	{ text = "🗺 Áreas", color = Color3.fromRGB(40, 170, 160), click = function() openPanel("Areas") end },
	{ text = "♻ Rebirth", color = Color3.fromRGB(230, 90, 160), click = function() openPanel("Rebirth") end },
	{ text = "👥 Jogadores", color = Color3.fromRGB(110, 110, 230), click = function() openPanel("Players") end },
	{ text = "📖 Dex", color = Color3.fromRGB(175, 85, 255), click = function() openPanel("Dex") end },
	{ text = "🏠 Base", color = Color3.fromRGB(230, 150, 40), click = function() act("Home") end },
	{ text = "🔒 Trancar", color = Color3.fromRGB(200, 70, 70), click = function() act("Lock") end },
}
for i, info in ipairs(menuItems) do
	local b = button({
		Size = UDim2.new(1, 0, 0, 40), LayoutOrder = i, Text = info.text, BackgroundColor3 = info.color, Parent = menu,
	})
	stroke(b, Color3.new(0, 0, 0), 2)
	b.Activated:Connect(info.click)
end

---------------------------------------------------------------------
-- Atualizar com os dados do servidor
---------------------------------------------------------------------
local function applyData(newData)
	if type(newData) ~= "table" then
		return
	end
	data = newData
	cashLabel.Text = "💰 $" .. fmt(data.cash)

	local income = 0
	for _, item in ipairs(data.inventory) do
		local def = Config.getBrainrot(item.id)
		if item.slot and def then
			income += Stats.income(def, item.level or 1, item.mutation)
		end
	end
	income *= Stats.rebirthIncomeMultiplier(data.rebirths)
	incomeLabel.Text = "Renda: +$" .. fmt(income) .. "/s"

	local level = data.playerLevel or 1
	levelLabel.Text = "⭐ Nível " .. level .. "   ♻ Rebirth " .. (data.rebirths or 0)
	if level >= Config.PlayerLevels.Max then
		playerXpFill.Size = UDim2.fromScale(1, 1)
	else
		playerXpFill.Size = UDim2.fromScale(math.clamp((data.playerXp or 0) / Stats.playerXpToNext(level), 0, 1), 1)
	end

	for _, ballDef in ipairs(Config.Balls) do
		local entry = ballButtons[ballDef.id]
		local locked = (ballDef.rebirth or 0) > (data.rebirths or 0) and (data.balls[ballDef.id] or 0) == 0
		entry.button.Text = if locked then ballDef.name .. "\n🔒 ♻" .. ballDef.rebirth
			else ballDef.name .. "\nx" .. (data.balls[ballDef.id] or 0)
		local selected = data.selectedBall == ballDef.id
		entry.stroke.Thickness = if selected then 4 else 0
		entry.button.BackgroundTransparency = if selected then 0 else 0.35
	end

	refreshPanel()
	for _, listener in ipairs(dataListeners) do
		task.spawn(listener, data)
	end
end

DataUpdated.OnClientEvent:Connect(applyData)
Notify.OnClientEvent:Connect(function(text, color)
	toast(text, color)
end)

task.spawn(function()
	local ok, snapshot = Action:InvokeServer("GetData")
	if ok then
		applyData(snapshot)
	end
end)

---------------------------------------------------------------------
-- Resultado da captura (texto grande no meio da tela)
---------------------------------------------------------------------
local bigText = label({
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.3), Size = UDim2.new(0.8, 0, 0, 90),
	Text = "", Font = Enum.Font.FredokaOne, TextStrokeTransparency = 0, Visible = false, Parent = gui,
})
new("UISizeConstraint", { MaxSize = Vector2.new(700, 90), Parent = bigText })
local bigToken = 0

local function showBig(text: string, color: Color3, duration: number?)
	bigToken += 1
	local token = bigToken
	bigText.Visible = true
	bigText.Text = text
	bigText.TextColor3 = color
	bigText.TextTransparency = 0
	bigText.TextStrokeTransparency = 0
	bigText.Size = UDim2.new(0.6, 0, 0, 60)
	TweenService:Create(bigText, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Size = UDim2.new(0.8, 0, 0, 90) }):Play()
	task.delay(duration or 2.5, function()
		if token == bigToken then
			TweenService:Create(bigText, TweenInfo.new(0.5), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end
	end)
end

CatchResult.OnClientEvent:Connect(function(success, brainrotId, chance, level, mutation)
	local def = Config.getBrainrot(brainrotId)
	if not def then
		return
	end
	local rarity = Config.getRarity(def.rarity)
	if success then
		showBig("✨ CAPTUROU! ✨\n" .. Stats.displayName(def, 1, mutation) .. " Lv." .. (level or 1) .. " (" .. rarity.display .. ")", rarity.color)
		toast("Ele está na sua barra de itens! Segure ele e clique perto de um pedestal da sua base 🏠", GREEN)
	else
		showBig("💨 Escapou! 💨\nChance era " .. math.floor(chance * 100) .. "% — bata mais nele!", RED)
	end
end)

local EVO_COLOR = Color3.fromRGB(255, 220, 80)
local pendingEvolution = false
CompanionEvent.OnClientEvent:Connect(function(kind, a, b)
	if kind == "evolve" then
		pendingEvolution = true
		showBig("🌟 EVOLUIU! 🌟\n" .. a .. " → " .. b, EVO_COLOR, 4)
		task.delay(4, function()
			pendingEvolution = false
		end)
	elseif kind == "levelup" then
		if not pendingEvolution then
			showBig("⬆ SUBIU DE NÍVEL! ⬆\n" .. a .. " agora é Lv." .. b, Color3.fromRGB(120, 230, 255))
		end
		toast("⬆ " .. a .. " Lv." .. b .. ": mais vida, força e renda!", Color3.fromRGB(120, 230, 255))
	elseif kind == "learn" then
		toast("📘 Aprendeu um ataque novo: " .. a .. (if b then " (tecla " .. b .. ")" else ""), EVO_COLOR)
	elseif kind == "faint" then
		toast("😵 " .. a .. " desmaiou! Volta em " .. b .. "s.", RED)
	elseif kind == "revive" then
		toast("💪 " .. a .. " voltou para a luta!", GREEN)
	elseif kind == "playerlevel" then
		showBig("⭐ VOCÊ SUBIU PARA O NÍVEL " .. a .. "! ⭐", Color3.fromRGB(255, 220, 90))
	elseif kind == "rebirth" then
		showBig("♻ REBIRTH " .. a .. "! ♻\nMais renda, pedestais e itens novos!", Color3.fromRGB(255, 120, 200), 4)
	elseif kind == "boss" then
		showBig("👑 CHEFÃO DERROTADO! 👑\n" .. a .. "  +$" .. fmt(b), Color3.fromRGB(255, 200, 60), 4)
	end
end)

---------------------------------------------------------------------
-- Info do brainrot embaixo do mouse (vida + chance de captura)
---------------------------------------------------------------------
local targetInfo = new("Frame", {
	Size = UDim2.fromOffset(210, 52), BackgroundColor3 = DARK, BackgroundTransparency = 0.15, Visible = false, Parent = gui,
})
corner(targetInfo, 8)
local targetStroke = stroke(targetInfo, Color3.new(1, 1, 1), 2)
local targetName = label({
	Position = UDim2.fromOffset(8, 4), Size = UDim2.new(1, -16, 0, 22), Font = Enum.Font.FredokaOne, Parent = targetInfo,
})
local targetChance = label({
	Position = UDim2.fromOffset(8, 26), Size = UDim2.new(1, -16, 0, 20), Parent = targetInfo,
})

local wildFolder = workspace:WaitForChild("WildBrainrots")

local function getHoveredBrainrot()
	local target = mouse.Target
	while target and target.Parent ~= wildFolder do
		target = target.Parent
	end
	return target
end

local hoveredWildRef = { model = nil }

RunService.RenderStepped:Connect(function()
	local model = getHoveredBrainrot()
	hoveredWildRef.model = model
	local id = model and model:GetAttribute("BrainrotId")
	local def = id and Config.getBrainrot(id)
	if not def or (model:GetAttribute("Health") or 0) <= 0 then
		targetInfo.Visible = false
		return
	end
	local health = model:GetAttribute("Health")
	local maxHealth = model:GetAttribute("MaxHealth") or def.maxHealth
	local rarity = Config.getRarity(def.rarity)
	targetStroke.Color = rarity.color
	if model:GetAttribute("IsBoss") then
		targetName.Text = "👑 CHEFÃO"
		targetName.TextColor3 = RED
		targetChance.Text = "❤ " .. fmt(math.ceil(health)) .. "/" .. fmt(maxHealth) .. "   não dá para capturar"
		targetChance.TextColor3 = RED
	else
		local ballDef = Config.getBall(data and data.selectedBall or "Basica") or Config.Balls[1]
		local chance = CatchMath.getChance(def.catchRate, health, maxHealth, ballDef.multiplier)
		targetName.Text = Stats.displayName(def, 1, model:GetAttribute("Mutation")) .. "  Lv." .. (model:GetAttribute("Level") or 1)
		targetName.TextColor3 = rarity.color
		targetChance.Text = "❤ " .. math.ceil(health) .. "/" .. maxHealth .. "   🎯 Chance: " .. math.floor(chance * 1000) / 10 .. "%"
		targetChance.TextColor3 = if chance >= 0.5 then GREEN elseif chance >= 0.2 then Color3.fromRGB(255, 210, 80) else RED
	end
	targetInfo.Position = UDim2.fromOffset(mouse.X + 18, mouse.Y + 18)
	targetInfo.Visible = true
end)


---------------------------------------------------------------------
-- PARCEIRO: vida, XP, ataques (Z X C V) e modo automático
---------------------------------------------------------------------
local companionsFolder = workspace:WaitForChild("Companions")

local hudFrame = new("Frame", {
	Position = UDim2.fromOffset(12, 120), Size = UDim2.fromOffset(268, 158),
	BackgroundColor3 = DARK, BackgroundTransparency = 0.1, Parent = gui,
})
corner(hudFrame, 12)
stroke(hudFrame, Color3.fromRGB(120, 220, 255), 2)

local hudName = label({
	Position = UDim2.fromOffset(10, 6), Size = UDim2.new(1, -20, 0, 22), Font = Enum.Font.FredokaOne,
	TextXAlignment = Enum.TextXAlignment.Left, Text = "⚔ Sem parceiro", Parent = hudFrame,
})
local hudEmpty = label({
	Position = UDim2.fromOffset(10, 32), Size = UDim2.new(1, -20, 0, 36), TextWrapped = true,
	Text = "Abra 🎒 Brainrots e aperte ⚔ Lutar em um brainrot.", TextColor3 = Color3.fromRGB(200, 200, 210),
	Font = Enum.Font.Gotham, Parent = hudFrame,
})

local function bar(y: number, height: number, color: Color3)
	local back = new("Frame", {
		Position = UDim2.fromOffset(10, y), Size = UDim2.new(1, -20, 0, height),
		BackgroundColor3 = Color3.fromRGB(50, 50, 60), BorderSizePixel = 0, Parent = hudFrame,
	})
	corner(back, 6)
	local fill = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = color, BorderSizePixel = 0, Parent = back })
	corner(fill, 6)
	local text = label({ Size = UDim2.fromScale(1, 1), ZIndex = 2, TextStrokeTransparency = 0.3, Parent = back })
	return back, fill, text
end
local hpBack, hpFill, hpText = bar(32, 16, Color3.fromRGB(80, 220, 100))
local xpBack, xpFill, xpText = bar(52, 12, Color3.fromRGB(110, 200, 255))

local moveRow = new("Frame", {
	Position = UDim2.fromOffset(10, 70), Size = UDim2.new(1, -20, 0, 50), BackgroundTransparency = 1, Parent = hudFrame,
})
new("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder,
	Parent = moveRow,
})

local cooldownEnds = {}
local moveButtons = {}

local function useMove(move)
	if not data or not data.companion then
		toast("Escolha um parceiro no menu 🎒 primeiro!", RED)
		return
	end
	if cooldownEnds[move.id] and os.clock() < cooldownEnds[move.id] then
		return
	end
	local ok = act("UseMove", move.id, hoveredWildRef.model)
	if ok then
		cooldownEnds[move.id] = os.clock() + move.cooldown
	end
end

local specialMoves = {}
for _, move in ipairs(Config.Moves) do
	if not move.auto then
		table.insert(specialMoves, move)
	end
end

for i, move in ipairs(specialMoves) do
	local b = button({
		Size = UDim2.fromOffset(55, 50), LayoutOrder = i, Text = "", BackgroundColor3 = Color3.fromRGB(200, 70, 90),
		Parent = moveRow,
	})
	local key = label({
		Position = UDim2.fromOffset(0, 0), Size = UDim2.new(1, 0, 0, 16), Text = move.key or "",
		TextColor3 = Color3.fromRGB(255, 240, 160), Font = Enum.Font.FredokaOne, Parent = b,
	})
	local name = label({
		Position = UDim2.fromOffset(0, 16), Size = UDim2.new(1, 0, 1, -16), Text = move.name, TextWrapped = true,
		Font = Enum.Font.GothamBold, Parent = b,
	})
	local shade = new("Frame", {
		AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, 0),
		BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, BorderSizePixel = 0, ZIndex = 3, Parent = b,
	})
	corner(shade, 8)
	moveButtons[move.id] = { button = b, key = key, name = name, shade = shade, move = move }
	b.Activated:Connect(function()
		useMove(move)
	end)
end

local autoButton = button({
	Position = UDim2.fromOffset(10, 126), Size = UDim2.new(1, -20, 0, 26), Text = "⚔ Auto: LIGADO",
	BackgroundColor3 = Color3.fromRGB(60, 170, 90), Parent = hudFrame,
})
autoButton.Activated:Connect(function()
	act("ToggleAuto")
end)

local keyToMove = {}
for _, move in ipairs(specialMoves) do
	if move.key then
		keyToMove[Enum.KeyCode[move.key]] = move
	end
end
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	local move = keyToMove[input.KeyCode]
	if move then
		useMove(move)
	end
end)

local function findMyCompanion()
	for _, model in ipairs(companionsFolder:GetChildren()) do
		if model:GetAttribute("OwnerUserId") == player.UserId then
			return model
		end
	end
	return nil
end

RunService.RenderStepped:Connect(function()
	local item
	if data and data.companion then
		for _, it in ipairs(data.inventory) do
			if it.uid == data.companion then
				item = it
				break
			end
		end
	end
	local def = item and Config.getBrainrot(item.id)

	autoButton.Text = if data and data.autoBattle == false then "⚔ Auto: DESLIGADO" else "⚔ Auto: LIGADO"
	autoButton.BackgroundColor3 = if data and data.autoBattle == false then Color3.fromRGB(120, 120, 140)
		else Color3.fromRGB(60, 170, 90)

	if not def then
		hudName.Text = "⚔ Sem parceiro"
		hudName.TextColor3 = Color3.new(1, 1, 1)
		hudEmpty.Visible = true
		hpBack.Visible, xpBack.Visible, moveRow.Visible = false, false, false
		return
	end
	hudEmpty.Visible = false
	hpBack.Visible, xpBack.Visible, moveRow.Visible = true, true, true

	local level = item.level or 1
	hudName.Text = "⚔ " .. Stats.displayName(def, level, item.mutation) .. "  Lv." .. level
	hudName.TextColor3 = Config.getRarity(def.rarity).color

	local model = findMyCompanion()
	local maxHealth = (model and model:GetAttribute("MaxHealth")) or Stats.companionMaxHealth(def, level, item.mutation)
	local health = (model and model:GetAttribute("Health")) or maxHealth
	hpFill.Size = UDim2.fromScale(math.clamp(health / maxHealth, 0, 1), 1)
	hpText.Text = if health <= 0 then "😵 Desmaiado" else "❤ " .. math.ceil(health) .. " / " .. maxHealth

	if level >= Config.Levels.MaxLevel then
		xpFill.Size = UDim2.fromScale(1, 1)
		xpText.Text = "NÍVEL MÁXIMO"
	else
		local need = Stats.xpToNext(level)
		xpFill.Size = UDim2.fromScale(math.clamp((item.xp or 0) / need, 0, 1), 1)
		xpText.Text = "XP " .. math.floor(item.xp or 0) .. " / " .. need
	end

	local now = os.clock()
	for _, entry in pairs(moveButtons) do
		local move = entry.move
		local locked = level < move.level
		entry.name.Text = if locked then "Lv." .. move.level else Stats.moveName(move, def)
		entry.button.BackgroundColor3 = if locked then Color3.fromRGB(70, 70, 80) else Color3.fromRGB(200, 70, 90)
		local remaining = (cooldownEnds[move.id] or 0) - now
		entry.shade.Size = UDim2.fromScale(1, if remaining > 0 then math.clamp(remaining / move.cooldown, 0, 1) else 0)
	end
end)

---------------------------------------------------------------------
-- Arremessar a bola
---------------------------------------------------------------------
local hooked = setmetatable({}, { __mode = "k" })

local function hookTool(tool: Instance)
	if not tool:IsA("Tool") or tool.Name ~= "Bola" or hooked[tool] then
		return
	end
	hooked[tool] = true
	tool.Activated:Connect(function()
		ThrowBall:FireServer(mouse.Hit.Position)
	end)
end

local function onCharacter(character: Model)
	for _, child in ipairs(character:GetChildren()) do
		hookTool(child)
	end
	character.ChildAdded:Connect(hookTool)
end

player.CharacterAdded:Connect(onCharacter)
if player.Character then
	onCharacter(player.Character)
end

---------------------------------------------------------------------
-- Social, áreas, rebirth, eventos, roubo, troca e duelo (outro módulo)
---------------------------------------------------------------------
require(script.Parent:WaitForChild("Social")).init({
	gui = gui,
	new = new,
	corner = corner,
	stroke = stroke,
	label = label,
	button = button,
	toast = toast,
	act = act,
	showBig = showBig,
	renderers = renderers,
	openPanel = openPanel,
	setTitle = function(text)
		panelTitle.Text = text
	end,
	clearScroll = clearScroll,
	row = row,
	header = header,
	rowText = rowText,
	getData = function()
		return data
	end,
	onData = function(listener)
		table.insert(dataListeners, listener)
	end,
	colors = { GREEN = GREEN, RED = RED, DARK = DARK, DARK2 = DARK2 },
})
