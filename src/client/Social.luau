-- Interface de: Áreas (teleporte), Rebirth, Jogadores (troca e duelo), janela de troca,
-- pedidos (aceitar/recusar), duelo, resgate, banner de evento, empurrão, barreiras das
-- áreas trancadas e os botões "Roubar"/"Guardar" certos em cada base.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Stats = require(Shared:WaitForChild("Stats"))
local CatchMath = require(Shared:WaitForChild("CatchMath"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local SocialEvent = Remotes:WaitForChild("Social")
local Knockback = Remotes:WaitForChild("Knockback")

local player = Players.LocalPlayer
local fmt = CatchMath.formatNumber

local Social = {}

function Social.init(ctx)
	local new, label, button, corner, stroke = ctx.new, ctx.label, ctx.button, ctx.corner, ctx.stroke
	local toast, act, showBig = ctx.toast, ctx.act, ctx.showBig
	local row, header, rowText = ctx.row, ctx.header, ctx.rowText
	local GREEN, RED, DARK, DARK2 = ctx.colors.GREEN, ctx.colors.RED, ctx.colors.DARK, ctx.colors.DARK2
	local GOLD = Color3.fromRGB(255, 220, 90)
	local GREY = Color3.fromRGB(110, 110, 125)
	local gui = ctx.gui

	local function progress()
		local data = ctx.getData()
		return {
			level = data and data.playerLevel or 1,
			bosses = data and data.bosses or {},
			rebirths = data and data.rebirths or 0,
		}
	end

	---------------------------------------------------------------------
	-- Painel: ÁREAS
	---------------------------------------------------------------------
	ctx.renderers.Areas = function()
		ctx.setTitle("🗺 Áreas")
		ctx.clearScroll()
		local p = progress()
		header(0, "Viaje para os biomas (cada um tem brainrots diferentes)")
		for i, biome in ipairs(Config.Biomes) do
			local r = row(i, 60)
			local ok, why = Stats.canEnter(p, biome)
			local names = {}
			for _, def in ipairs(Config.Brainrots) do
				if def.biome == biome.id then
					table.insert(names, def.name)
				end
			end
			rowText(r, biome.icon .. " " .. biome.name, if ok then GREEN else RED,
				if ok then table.concat(names, ", ") else "🔒 " .. (why or ""), 110)
			local b = button({
				AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(96, 40),
				Text = if ok then "Ir ➜" else "🔒", BackgroundColor3 = if ok then Color3.fromRGB(40, 170, 160) else GREY, Parent = r,
			})
			b.Activated:Connect(function()
				act("Teleport", biome.id)
			end)
		end
		header(50, "👑 Chefões")
		for i, boss in ipairs(Config.Bosses) do
			local r = row(50 + i, 56)
			local biome = Config.getBiome(boss.biome)
			local done = p.bosses[boss.id]
			rowText(r, (if done then "✔ " else "") .. boss.name, if done then GREEN else GOLD,
				(if biome then biome.icon .. " " .. biome.name else "") .. " • Vida " .. fmt(boss.maxHealth)
					.. " • Prêmio $" .. fmt(boss.reward), 0)
		end
	end

	---------------------------------------------------------------------
	-- Painel: REBIRTH
	---------------------------------------------------------------------
	local confirmRebirth = false
	ctx.renderers.Rebirth = function()
		ctx.setTitle("♻ Rebirth")
		ctx.clearScroll()
		local data = ctx.getData()
		if not data then
			return
		end
		local R = Config.Rebirth
		local current = data.rebirths or 0
		local info = row(0, 60)
		rowText(info, "Rebirths: " .. current .. " / " .. R.Max, Color3.fromRGB(255, 150, 210),
			"Renda atual: x" .. Stats.rebirthIncomeMultiplier(current) .. " • Pedestais máx: " .. Stats.maxSlots(current), 0)

		local nextIndex = current + 1
		if nextIndex > R.Max then
			local r = row(1, 56)
			rowText(r, "Você chegou no máximo! 🏆", GOLD, "Parabéns!", 0)
			return
		end
		local cost, level = R.Costs[nextIndex], R.Levels[nextIndex]
		header(1, "Rebirth " .. nextIndex .. ": volta o dinheiro para $" .. Config.StartingCash .. " e você ganha:")
		local rewards = {
			"+" .. math.floor(R.IncomeBonus * 100) .. "% de renda em todos os pedestais (fica x" .. Stats.rebirthIncomeMultiplier(nextIndex) .. ")",
			"Pedestais máximos: " .. Stats.maxSlots(current) .. " ➜ " .. Stats.maxSlots(nextIndex),
		}
		for _, ball in ipairs(Config.Balls) do
			if ball.rebirth == nextIndex then
				table.insert(rewards, "Libera a " .. ball.name .. " na loja")
			end
		end
		for _, bat in ipairs(Config.Bats) do
			if bat.rebirth == nextIndex then
				table.insert(rewards, "Libera o " .. bat.name .. " na loja")
			end
		end
		for _, biome in ipairs(Config.Biomes) do
			if biome.unlock and biome.unlock.rebirths == nextIndex then
				table.insert(rewards, "Ajuda a liberar " .. biome.icon .. " " .. biome.name)
			end
		end
		for i, text in ipairs(rewards) do
			local r = row(1 + i, 44)
			rowText(r, "✨ " .. text, Color3.new(1, 1, 1), "", 0)
		end
		local okLevel = (data.playerLevel or 1) >= level
		local okCash = data.cash >= cost
		local req = row(50, 60)
		rowText(req, "Precisa de:", GOLD,
			(if okLevel then "✔" else "❌") .. " Nível " .. level .. "     " .. (if okCash then "✔" else "❌") .. " $" .. fmt(cost), 190)
		local b = button({
			AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(180, 44),
			Text = if confirmRebirth then "Tem certeza? ♻" else "♻ FAZER REBIRTH",
			BackgroundColor3 = if okLevel and okCash then Color3.fromRGB(230, 90, 160) else GREY, Parent = req,
		})
		b.Activated:Connect(function()
			if not confirmRebirth then
				confirmRebirth = true
				b.Text = "Tem certeza? ♻"
				task.delay(3, function()
					confirmRebirth = false
				end)
				return
			end
			confirmRebirth = false
			act("Rebirth")
		end)
	end

	---------------------------------------------------------------------
	-- Painel: JOGADORES
	---------------------------------------------------------------------
	ctx.renderers.Players = function()
		ctx.setTitle("👥 Jogadores")
		ctx.clearScroll()
		local others = {}
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= player then
				table.insert(others, p)
			end
		end
		if #others == 0 then
			local r = row(1, 60)
			rowText(r, "Ninguém mais no servidor", Color3.new(1, 1, 1), "Chame amigos! (no Studio: Test ➜ 2 jogadores)", 0)
			return
		end
		header(0, "🤝 Trocar brainrots  •  ⚔ Duelo: quem perde pode perder um brainrot!")
		for i, p in ipairs(others) do
			local r = row(i, 60)
			local stats = p:FindFirstChild("leaderstats")
			local level = stats and stats:FindFirstChild("Nível")
			local rebirths = stats and stats:FindFirstChild("Rebirths")
			rowText(r, p.DisplayName, Color3.new(1, 1, 1),
				"⭐ Nível " .. (if level then level.Value else "?") .. " • ♻ " .. (if rebirths then rebirths.Value else 0), 200)
			local trade = button({
				AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -104, 0.5, 0), Size = UDim2.fromOffset(90, 40),
				Text = "🤝 Trocar", BackgroundColor3 = Color3.fromRGB(70, 140, 255), Parent = r,
			})
			trade.Activated:Connect(function()
				act("TradeRequest", p.UserId)
			end)
			local duel = button({
				AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(90, 40),
				Text = "⚔ Duelo", BackgroundColor3 = Color3.fromRGB(220, 70, 70), Parent = r,
			})
			duel.Activated:Connect(function()
				act("DuelRequest", p.UserId)
			end)
		end
	end

	---------------------------------------------------------------------
	-- Pedidos (janelinha com botões)
	---------------------------------------------------------------------
	local popupHolder = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 140), Size = UDim2.new(0.9, 0, 0, 400),
		BackgroundTransparency = 1, Parent = gui,
	})
	new("UISizeConstraint", { MaxSize = Vector2.new(440, 400), Parent = popupHolder })
	new("UIListLayout", { Padding = UDim.new(0, 8), HorizontalAlignment = Enum.HorizontalAlignment.Center, Parent = popupHolder })

	local function popup(title: string, text: string, buttons, timeout: number?)
		local frame = new("Frame", { Size = UDim2.new(1, 0, 0, 130), BackgroundColor3 = DARK, Parent = popupHolder })
		corner(frame, 12)
		stroke(frame, GOLD, 2)
		label({ Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -24, 0, 26), Text = title, Font = Enum.Font.FredokaOne,
			TextColor3 = GOLD, Parent = frame })
		label({ Position = UDim2.fromOffset(12, 34), Size = UDim2.new(1, -24, 0, 40), Text = text, TextWrapped = true,
			Font = Enum.Font.Gotham, Parent = frame })
		local closed = false
		local function close()
			if not closed then
				closed = true
				frame:Destroy()
			end
		end
		local width = 1 / #buttons
		for i, info in ipairs(buttons) do
			local b = button({
				Position = UDim2.new(width * (i - 1), 10, 1, -48), Size = UDim2.new(width, -20, 0, 38),
				Text = info.text, BackgroundColor3 = info.color, Parent = frame,
			})
			b.Activated:Connect(function()
				close()
				info.callback()
			end)
		end
		if timeout then
			task.delay(timeout, close)
		end
		return close
	end

	---------------------------------------------------------------------
	-- Janela de TROCA
	---------------------------------------------------------------------
	local tradeFrame = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.95, 0.8),
		BackgroundColor3 = DARK, Visible = false, Parent = gui,
	})
	corner(tradeFrame, 14)
	stroke(tradeFrame, Color3.fromRGB(110, 160, 255), 2)
	new("UISizeConstraint", { MaxSize = Vector2.new(680, 460), Parent = tradeFrame })
	local tradeTitle = label({ Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -28, 0, 32), Font = Enum.Font.FredokaOne,
		Text = "🤝 Troca", Parent = tradeFrame })

	local function column(x: number, title: string)
		label({ Position = UDim2.new(x, 10, 0, 44), Size = UDim2.new(0.5, -20, 0, 22), Text = title, TextColor3 = GOLD,
			Font = Enum.Font.FredokaOne, Parent = tradeFrame })
		local list = new("ScrollingFrame", {
			Position = UDim2.new(x, 10, 0, 70), Size = UDim2.new(0.5, -20, 1, -186), BackgroundColor3 = DARK2,
			BorderSizePixel = 0, ScrollBarThickness = 6, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
			Parent = tradeFrame,
		})
		corner(list, 8)
		new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })
		new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4), Parent = list })
		return list
	end
	local myList = column(0, "Seus brainrots (clique para oferecer)")
	local theirList = column(0.5, "Oferta do outro")

	local cashBox = new("TextBox", {
		Position = UDim2.new(0, 10, 1, -108), Size = UDim2.new(0.5, -20, 0, 36), BackgroundColor3 = DARK2,
		Text = "", PlaceholderText = "💰 Dinheiro que você oferece", TextColor3 = Color3.new(1, 1, 1),
		Font = Enum.Font.GothamBold, TextScaled = true, ClearTextOnFocus = false, Parent = tradeFrame,
	})
	corner(cashBox, 8)
	local theirCash = label({ Position = UDim2.new(0.5, 10, 1, -108), Size = UDim2.new(0.5, -20, 0, 36), Text = "💰 $0",
		TextColor3 = GREEN, Font = Enum.Font.FredokaOne, Parent = tradeFrame })
	local readyButton = button({ Position = UDim2.new(0, 10, 1, -62), Size = UDim2.new(0.5, -20, 0, 50), Text = "✔ Pronto",
		BackgroundColor3 = Color3.fromRGB(60, 170, 90), Parent = tradeFrame })
	local cancelButton = button({ Position = UDim2.new(0.5, 10, 1, -62), Size = UDim2.new(0.5, -20, 0, 50), Text = "✖ Cancelar",
		BackgroundColor3 = Color3.fromRGB(220, 70, 70), Parent = tradeFrame })

	local tradeState = nil
	local selected = {}

	local function sendOffer()
		local list = {}
		for uid in pairs(selected) do
			table.insert(list, uid)
		end
		act("TradeSetOffer", list, tonumber(cashBox.Text) or 0)
	end

	local function itemRow(parent, info, order: number, isSelected: boolean?, onClick)
		local def = Config.getBrainrot(info.id)
		local rarity = def and Config.getRarity(def.rarity)
		local b = button({
			Size = UDim2.new(1, -4, 0, 34), LayoutOrder = order,
			Text = (if isSelected then "✔ " else "") .. info.name .. " Lv." .. (info.level or 1),
			BackgroundColor3 = if isSelected then Color3.fromRGB(60, 140, 90) else Color3.fromRGB(60, 62, 80),
			TextColor3 = if rarity then rarity.color else Color3.new(1, 1, 1), Parent = parent,
		})
		if onClick then
			b.Activated:Connect(onClick)
		end
		return b
	end

	local function clearList(list)
		for _, c in ipairs(list:GetChildren()) do
			if c:IsA("GuiButton") or c:IsA("TextLabel") then
				c:Destroy()
			end
		end
	end

	local function renderTrade()
		if not tradeState then
			tradeFrame.Visible = false
			return
		end
		tradeFrame.Visible = true
		tradeTitle.Text = "🤝 Troca com " .. tradeState.partner
		selected = {}
		for _, info in ipairs(tradeState.mine.items) do
			selected[info.uid] = true
		end
		clearList(myList)
		local data = ctx.getData()
		if data then
			for i, item in ipairs(data.inventory) do
				local def = Config.getBrainrot(item.id)
				if def then
					local info = { uid = item.uid, id = item.id, level = item.level, name = Stats.displayName(def, item.level or 1, item.mutation) }
					itemRow(myList, info, i, selected[item.uid], function()
						selected[item.uid] = not selected[item.uid] or nil
						sendOffer()
					end)
				end
			end
		end
		clearList(theirList)
		for i, info in ipairs(tradeState.theirs.items) do
			itemRow(theirList, info, i, false, nil)
		end
		if #tradeState.theirs.items == 0 then
			label({ Size = UDim2.new(1, -4, 0, 30), Text = "(nada ainda)", TextColor3 = GREY, Parent = theirList })
		end
		if not cashBox:IsFocused() then
			cashBox.Text = if tradeState.mine.cash > 0 then tostring(tradeState.mine.cash) else ""
		end
		theirCash.Text = "💰 $" .. fmt(tradeState.theirs.cash) .. (if tradeState.theirReady then "   ✔ PRONTO" else "")
		readyButton.Text = if tradeState.myReady then "⏳ Esperando o outro..." else "✔ Pronto"
		readyButton.BackgroundColor3 = if tradeState.myReady then GREY else Color3.fromRGB(60, 170, 90)
	end

	cashBox.FocusLost:Connect(function()
		if tradeState then
			sendOffer()
		end
	end)
	readyButton.Activated:Connect(function()
		if tradeState then
			act("TradeReady", not tradeState.myReady)
		end
	end)
	cancelButton.Activated:Connect(function()
		act("TradeCancel")
	end)
	ctx.onData(function()
		if tradeState then
			renderTrade()
		end
	end)

	---------------------------------------------------------------------
	-- Janela de escolher brainrot do duelo
	---------------------------------------------------------------------
	local pickFrame = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.9, 0.75),
		BackgroundColor3 = DARK, Visible = false, Parent = gui,
	})
	corner(pickFrame, 14)
	stroke(pickFrame, GOLD, 2)
	new("UISizeConstraint", { MaxSize = Vector2.new(480, 440), Parent = pickFrame })
	local pickTitle = label({ Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -28, 0, 32), Font = Enum.Font.FredokaOne,
		TextColor3 = GOLD, Parent = pickFrame })
	local pickList = new("ScrollingFrame", {
		Position = UDim2.fromOffset(10, 48), Size = UDim2.new(1, -20, 1, -58), BackgroundTransparency = 1, BorderSizePixel = 0,
		ScrollBarThickness = 6, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = pickFrame,
	})
	new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = pickList })

	---------------------------------------------------------------------
	-- Eventos do servidor
	---------------------------------------------------------------------
	local countdownToken = 0
	SocialEvent.OnClientEvent:Connect(function(kind, payload)
		if kind == "tradeRequest" then
			popup("🤝 Pedido de troca", payload.fromName .. " quer trocar brainrots com você!", {
				{ text = "Aceitar", color = Color3.fromRGB(60, 170, 90), callback = function() act("TradeRespond", true) end },
				{ text = "Recusar", color = Color3.fromRGB(220, 70, 70), callback = function() act("TradeRespond", false) end },
			}, 20)
		elseif kind == "tradeUpdate" then
			tradeState = payload
			renderTrade()
		elseif kind == "tradeClosed" then
			tradeState = nil
			renderTrade()
		elseif kind == "duelRequest" then
			popup("⚔ Desafio de duelo!", payload.fromName .. " te desafiou! Quem perder pode perder um brainrot.", {
				{ text = "Aceitar ⚔", color = Color3.fromRGB(220, 70, 70), callback = function() act("DuelRespond", true) end },
				{ text = "Fugir 🐔", color = GREY, callback = function() act("DuelRespond", false) end },
			}, 20)
		elseif kind == "duelCountdown" then
			countdownToken += 1
			local token = countdownToken
			task.spawn(function()
				for i = payload.seconds, 1, -1 do
					if token ~= countdownToken then
						return
					end
					showBig("⚔ DUELO contra " .. payload.opponent .. " ⚔\n" .. i, GOLD, 0.9)
					task.wait(1)
				end
			end)
		elseif kind == "duelFight" then
			showBig("⚔ LUTE! ⚔", RED, 1.2)
		elseif kind == "duelEnded" then
			countdownToken += 1
			if payload.draw then
				showBig("🤝 EMPATE", GOLD, 2.5)
			elseif payload.won then
				showBig("🏆 VITÓRIA! 🏆", GREEN, 2.5)
			else
				showBig("💀 DERROTA 💀", RED, 2.5)
			end
		elseif kind == "duelPick" then
			pickTitle.Text = "🏆 Escolha um brainrot de " .. payload.loserName .. " (" .. payload.time .. "s)"
			for _, c in ipairs(pickList:GetChildren()) do
				if c:IsA("GuiButton") then
					c:Destroy()
				end
			end
			for i, info in ipairs(payload.items) do
				local b = itemRow(pickList, info, i, false, nil)
				b.Text = info.name .. " Lv." .. info.level .. "  ($" .. fmt(info.value) .. ")"
				b.Activated:Connect(function()
					pickFrame.Visible = false
					act("DuelPick", info.uid)
				end)
			end
			pickFrame.Visible = true
			task.delay(payload.time, function()
				pickFrame.Visible = false
			end)
		elseif kind == "duelRansom" then
			popup("💸 Resgate!", payload.winnerName .. " quer levar seu " .. payload.itemName .. ". Pagar $" .. fmt(payload.price)
				.. " para salvar ele?", {
				{ text = "Pagar $" .. fmt(payload.price), color = Color3.fromRGB(60, 170, 90), callback = function() act("DuelRansom", true) end },
				{ text = "Deixar levar", color = Color3.fromRGB(220, 70, 70), callback = function() act("DuelRansom", false) end },
			}, payload.time)
		elseif kind == "areaUnlocked" then
			showBig("🔓 NOVA ÁREA LIBERADA! 🔓\n" .. tostring(payload), GOLD, 3.5)
		end
	end)

	---------------------------------------------------------------------
	-- Empurrão (o servidor manda, o seu computador aplica)
	---------------------------------------------------------------------
	Knockback.OnClientEvent:Connect(function(velocity)
		local character = player.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if typeof(velocity) ~= "Vector3" or not hrp or not humanoid then
			return
		end
		humanoid:ChangeState(Enum.HumanoidStateType.FallingDown)
		hrp.AssemblyLinearVelocity = velocity
	end)

	---------------------------------------------------------------------
	-- Banner de evento
	---------------------------------------------------------------------
	local eventBanner = label({
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 8), Size = UDim2.new(0.6, 0, 0, 30),
		Text = "", Font = Enum.Font.FredokaOne, TextStrokeTransparency = 0, Visible = false, Parent = gui,
	})
	new("UISizeConstraint", { MaxSize = Vector2.new(560, 30), Parent = eventBanner })
	task.spawn(function()
		while true do
			local event = Config.getEvent(workspace:GetAttribute("EventId"))
			local ends = workspace:GetAttribute("EventEnds")
			if event and ends then
				local left = math.max(0, math.floor(ends - workspace:GetServerTimeNow()))
				eventBanner.Visible = true
				eventBanner.Text = event.name .. "  •  " .. string.format("%d:%02d", left // 60, left % 60)
				local m = Config.getMutation(event.mutation)
				eventBanner.TextColor3 = if m then m.color else GOLD
			else
				eventBanner.Visible = false
			end
			task.wait(0.5)
		end
	end)

	---------------------------------------------------------------------
	-- Botões das bases: "Guardar/Colocar" só para o dono, "Roubar" só para os outros
	---------------------------------------------------------------------
	local plotsFolder = workspace:WaitForChild("Plots")
	local function plotOf(prompt: Instance)
		local node = prompt
		while node and node.Parent ~= plotsFolder do
			node = node.Parent
		end
		return node
	end
	local function filterPrompt(prompt: ProximityPrompt)
		local role = prompt:GetAttribute("PromptRole")
		local plot = plotOf(prompt)
		if not role or not plot then
			return
		end
		local owner = plot:GetAttribute("OwnerUserId")
		local allowed = if role == "owner" then owner == player.UserId else (owner ~= nil and owner ~= player.UserId)
		if not allowed and prompt.Enabled then
			prompt.Enabled = false
		end
	end
	local function watchPrompt(prompt: Instance)
		if prompt:IsA("ProximityPrompt") then
			filterPrompt(prompt)
			prompt:GetPropertyChangedSignal("Enabled"):Connect(function()
				filterPrompt(prompt)
			end)
		end
	end
	for _, d in ipairs(plotsFolder:GetDescendants()) do
		watchPrompt(d)
	end
	plotsFolder.DescendantAdded:Connect(watchPrompt)

	---------------------------------------------------------------------
	-- Barreiras das áreas trancadas (só você vê e só você bate nelas)
	---------------------------------------------------------------------
	local barrierFolder = Instance.new("Folder")
	barrierFolder.Name = "AreaBarriers"
	barrierFolder.Parent = workspace
	local lastKey = nil
	local function rebuildBarriers()
		local p = progress()
		local lockedIds = {}
		for _, biome in ipairs(Config.Biomes) do
			if biome.id ~= "Ceu" and not Stats.canEnter(p, biome) then
				table.insert(lockedIds, biome.id)
			end
		end
		local key = table.concat(lockedIds, ",")
		if key == lastKey then
			return
		end
		lastKey = key
		barrierFolder:ClearAllChildren()
		for _, id in ipairs(lockedIds) do
			local biome = Config.getBiome(id)
			local c, hx, hz = biome.center, biome.size.X / 2, biome.size.Y / 2
			local walls = {
				{ Vector3.new(biome.size.X, 40, 1), Vector3.new(0, 20, hz) },
				{ Vector3.new(biome.size.X, 40, 1), Vector3.new(0, 20, -hz) },
				{ Vector3.new(1, 40, biome.size.Y), Vector3.new(hx, 20, 0) },
				{ Vector3.new(1, 40, biome.size.Y), Vector3.new(-hx, 20, 0) },
			}
			for _, w in ipairs(walls) do
				local wall = Instance.new("Part")
				wall.Anchored = true
				wall.CanCollide = true
				wall.CanQuery = false
				wall.CastShadow = false
				wall.Material = Enum.Material.ForceField
				wall.Color = Color3.fromRGB(255, 80, 80)
				wall.Transparency = 0.3
				wall.Size = w[1]
				wall.CFrame = CFrame.new(c + w[2])
				wall.Parent = barrierFolder
			end
		end
	end
	ctx.onData(rebuildBarriers)
end

return Social
