-- EVENTOS: de tempos em tempos acontece um evento (Chuva Radioativa, Erupção de Magma,
-- Arco-Íris...). Durante o evento o céu muda de cor e os brainrots nascem com MUTAÇÕES,
-- que deixam eles mais fortes e dando muito mais dinheiro.

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local WildService = require(script.Parent.WildService)
local Remotes = require(script.Parent.Remotes)

local EventService = {}

local E = Config.Events
local rng = Random.new()
local token = 0
local saved = nil

local function notifyAll(text: string, color: Color3)
	for _, p in ipairs(Players:GetPlayers()) do
		Remotes.notify(p, text, color)
	end
end

local function setLighting(event)
	local cc = Lighting:FindFirstChild("BrainrotColorCorrectionEffect")
	local atmosphere = Lighting:FindFirstChild("BrainrotAtmosphere")
	if event then
		saved = saved or {
			tint = cc and cc.TintColor,
			atmosphere = atmosphere and atmosphere.Color,
		}
		if cc then
			cc.TintColor = event.tint
		end
		if atmosphere then
			atmosphere.Color = event.atmosphere
		end
	elseif saved then
		if cc and saved.tint then
			cc.TintColor = saved.tint
		end
		if atmosphere and saved.atmosphere then
			atmosphere.Color = saved.atmosphere
		end
		saved = nil
	end
end

function EventService.getCurrent()
	return WildService.currentEvent
end

function EventService.stopEvent()
	local event = WildService.currentEvent
	if not event then
		return
	end
	WildService.currentEvent = nil
	workspace:SetAttribute("EventId", nil)
	workspace:SetAttribute("EventEnds", nil)
	setLighting(nil)
	notifyAll("O evento " .. event.name .. " acabou.", Color3.fromRGB(200, 200, 220))
end

function EventService.startEvent(eventId: string?, duration: number?)
	local event = if eventId then Config.getEvent(eventId) else E.List[rng:NextInteger(1, #E.List)]
	if not event then
		return false
	end
	EventService.stopEvent()
	token += 1
	local myToken = token
	duration = duration or E.Duration

	WildService.currentEvent = event
	workspace:SetAttribute("EventId", event.id)
	workspace:SetAttribute("EventEnds", workspace:GetServerTimeNow() + duration)
	setLighting(event)
	notifyAll("⚠ EVENTO: " .. event.name .. "! " .. event.text, Config.getMutation(event.mutation).color)

	-- parte dos brainrots que já estão no mapa também muda
	WildService.forEachWild(function(state)
		if not state.mutation and rng:NextNumber() < event.chance * 0.6 then
			WildService.setMutation(state, event.mutation)
		end
	end)

	task.delay(duration, function()
		if token == myToken then
			EventService.stopEvent()
		end
	end)
	return true
end

function EventService.start()
	task.spawn(function()
		task.wait(E.FirstDelay)
		while true do
			EventService.startEvent(nil, E.Duration)
			task.wait(E.Duration + E.Interval)
		end
	end)
end

return EventService
