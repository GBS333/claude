-- Cria os RemoteEvents/RemoteFunctions usados para servidor <-> jogador.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = {}

local folder = ReplicatedStorage:FindFirstChild("Remotes")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "Remotes"
	folder.Parent = ReplicatedStorage
end

local function get(className, name)
	local remote = folder:FindFirstChild(name)
	if not remote then
		remote = Instance.new(className)
		remote.Name = name
		remote.Parent = folder
	end
	return remote
end

Remotes.ThrowBall = get("RemoteEvent", "ThrowBall") -- jogador -> servidor: posição do mouse
Remotes.DataUpdated = get("RemoteEvent", "DataUpdated") -- servidor -> jogador: dados atualizados
Remotes.Notify = get("RemoteEvent", "Notify") -- servidor -> jogador: mensagem na tela
Remotes.CatchResult = get("RemoteEvent", "CatchResult") -- servidor -> jogador: capturou ou não
Remotes.Action = get("RemoteFunction", "Action") -- jogador -> servidor: comprar, vender, colocar...

function Remotes.notify(player: Player, text: string, color: Color3?)
	Remotes.Notify:FireClient(player, text, color)
end

return Remotes
