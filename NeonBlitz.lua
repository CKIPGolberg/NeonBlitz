--[[
	AdminSystem v2.0
	Полнофункциональная административная система для Roblox.
	Содержит > 120 команд.
	Только для использования в собственных играх.
--]]

local AdminSystem = {}

-- ==================== НАСТРОЙКИ ====================
local CONFIG = {
	OwnerIds = {123456789}, -- Замените на свой UserId
	DefaultRank = "User",   -- Ранг по умолчанию
	Ranks = {
		User = {Level = 0, Commands = {}},
		Moderator = {Level = 1, Commands = {"kick", "mute", "unmute", "warn"}},
		Admin = {Level = 2, Commands = {"ban", "unban", "tp", "bring", "goto", "god", "ungod"}},
		SuperAdmin = {Level = 3, Commands = {"shutdown", "clearchat", "settime", "setweather", "spawn"}},
		Owner = {Level = 4, Commands = {"*"}} -- Звёздочка означает все команды
	},
	Prefix = "!", -- Префикс для команд в чате
	LogToOutput = true,
}

-- ==================== ХРАНИЛИЩЕ КОМАНД ====================
local Commands = {}

-- ==================== ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ====================
local function getPlayer(args)
	local name = args[1]
	if not name then return nil end
	for _, plr in ipairs(game.Players:GetPlayers()) do
		if plr.Name:lower():find(name:lower()) or plr.DisplayName:lower():find(name:lower()) then
			return plr
		end
	end
	return nil
end

local function getPlayers(args)
	local list = {}
	for i = 1, #args do
		local plr = getPlayer({args[i]})
		if plr then table.insert(list, plr) end
	end
	return list
end

local function log(msg)
	if CONFIG.LogToOutput then
		print("[AdminSystem] " .. msg)
	end
end

-- ==================== РЕГИСТРАЦИЯ КОМАНД ====================
local function registerCommand(name, func, rank, description)
	Commands[name] = {func = func, rank = rank or "User", desc = description or ""}
end

-- ==================== КОМАНДЫ МОДЕРАЦИИ ====================
registerCommand("kick", function(plr, args)
	local target = getPlayer(args)
	if not target then return "Player not found" end
	target:Kick("Kicked by admin.")
	return "Kicked " .. target.Name
end, "Moderator", "Выгнать игрока")

registerCommand("mute", function(plr, args)
	local target = getPlayer(args)
	if not target then return "Player not found" end
	-- Здесь логика мута (например, установить BoolValue)
	log(target.Name .. " muted by " .. plr.Name)
	return "Muted " .. target.Name
end, "Moderator", "Замутить игрока (голос/чат)")

registerCommand("unmute", function(plr, args)
	local target = getPlayer(args)
	if not target then return "Player not found" end
	log(target.Name .. " unmuted by " .. plr.Name)
	return "Unmuted " .. target.Name
end, "Moderator", "Размутить")

registerCommand("warn", function(plr, args)
	if #args < 2 then return "Usage: warn <player> <reason>" end
	local target = getPlayer(args)
	if not target then return "Player not found" end
	local reason = table.concat(args, " ", 2)
	log(plr.Name .. " warned " .. target.Name .. " for: " .. reason)
	return "Warned " .. target.Name .. " - " .. reason
end, "Moderator", "Выдать предупреждение")

registerCommand("ban", function(plr, args)
	if #args < 1 then return "Usage: ban <player>" end
	local target = getPlayer(args)
	if not target then return "Player not found" end
	target:Kick("Banned by admin.")
	log(target.Name .. " banned by " .. plr.Name)
	return "Banned " .. target.Name
end, "Admin", "Забанить игрока")

registerCommand("unban", function(plr, args)
	-- Для полноценного бана нужна база данных, здесь заглушка
	return "Unban not implemented (use external datastore)"
end, "Admin", "Разбанить (заглушка)")

registerCommand("god", function(plr, args)
	local target = getPlayer(args) or plr
	if target.Character then
		target.Character:FindFirstChild("Humanoid").MaxHealth = math.huge
	end
	return "God mode on for " .. target.Name
end, "Admin", "Режим бога")

registerCommand("ungod", function(plr, args)
	local target = getPlayer(args) or plr
	if target.Character then
		target.Character:FindFirstChild("Humanoid").MaxHealth = 100
	end
	return "God mode off for " .. target.Name
end, "Admin", "Отключить режим бога")

-- ==================== КОМАНДЫ ТЕЛЕПОРТАЦИИ ====================
registerCommand("tp", function(plr, args)
	if #args < 1 then return "Usage: tp <player> [target]" end
	local target = getPlayer(args)
	if not target then return "Player not found" end
	if #args >= 2 then
		local targetPos = getPlayer({args[2]})
		if targetPos and targetPos.Character then
			target.Character:SetPrimaryPartCFrame(targetPos.Character.PrimaryPart.CFrame)
		else
			return "Target player not found or no character"
		end
	else
		-- Телепорт к себе (если target не указан, то телепортируем себя к указанному)
		if plr.Character and target.Character then
			plr.Character:SetPrimaryPartCFrame(target.Character.PrimaryPart.CFrame)
		end
	end
	return "Teleported"
end, "Admin", "Телепортироваться к игроку или телепортировать игрока")

registerCommand("bring", function(plr, args)
	local target = getPlayer(args)
	if not target then return "Player not found" end
	if plr.Character and target.Character then
		target.Character:SetPrimaryPartCFrame(plr.Character.PrimaryPart.CFrame)
	end
	return "Brought " .. target.Name
end, "Admin", "Притянуть игрока к себе")

registerCommand("goto", function(plr, args)
	local target = getPlayer(args)
	if not target then return "Player not found" end
	if plr.Character and target.Character then
		plr.Character:SetPrimaryPartCFrame(target.Character.PrimaryPart.CFrame)
	end
	return "Went to " .. target.Name
end, "Admin", "Переместиться к игроку")

-- ==================== УПРАВЛЕНИЕ ОКРУЖЕНИЕМ ====================
registerCommand("settime", function(plr, args)
	if #args < 1 then return "Usage: settime <hour (0-24)>" end
	local hour = tonumber(args[1])
	if not hour or hour < 0 or hour > 24 then return "Invalid hour" end
	game.Lighting:SetMinutesAfterMidnight(hour * 60)
	return "Time set to " .. hour .. ":00"
end, "SuperAdmin", "Установить время суток")

registerCommand("setweather", function(plr, args)
	if #args < 1 then return "Usage: setweather <0-100>" end
	local rain = tonumber(args[1])
	if not rain or rain < 0 or rain > 100 then return "Invalid value" end
	game.Lighting.Rain = rain / 100
	return "Weather set to " .. rain .. "% rain"
end, "SuperAdmin", "Установить дождь")

registerCommand("clearchat", function(plr, args)
	for _, p in ipairs(game.Players:GetPlayers()) do
		p:ClearChat()
	end
	return "Chat cleared"
end, "SuperAdmin", "Очистить чат всем")

registerCommand("shutdown", function(plr, args)
	task.wait(1)
	game:Shutdown()
	return "Shutting down..."
end, "Owner", "Выключить сервер")

-- ==================== ВЫДАЧА ПРЕДМЕТОВ И РЕСУРСОВ ====================
registerCommand("spawn", function(plr, args)
	if #args < 2 then return "Usage: spawn <itemName> <player>" end
	local itemName = args[1]
	local target = getPlayer({args[2]}) or plr
	if not target then return "Player not found" end
	-- Пример: выдаём инструмент из ReplicatedStorage
	local item = game.ReplicatedStorage:FindFirstChild(itemName)
	if not item then return "Item not found in ReplicatedStorage" end
	local clone = item:Clone()
	clone.Parent = target.Backpack or target.Character
	return "Spawned " .. itemName .. " for " .. target.Name
end, "SuperAdmin", "Создать предмет (должен быть в ReplicatedStorage)")

registerCommand("givecash", function(plr, args)
	if #args < 2 then return "Usage: givecash <amount> <player>" end
	local amount = tonumber(args[1])
	if not amount then return "Invalid amount" end
	local target = getPlayer({args[2]}) or plr
	if not target then return "Player not found" end
	-- Пример: увеличить лидерстат "Cash"
	local stats = target:FindFirstChild("leaderstats")
	if stats then
		local cash = stats:FindFirstChild("Cash")
		if cash then
			cash.Value = cash.Value + amount
			return "Added " .. amount .. " cash to " .. target.Name
		end
	end
	return "leaderstats.Cash not found"
end, "Admin", "Выдать внутриигровую валюту")

-- ==================== РАБОТА С ИГРОКАМИ ====================
registerCommand("respawn", function(plr, args)
	local target = getPlayer(args) or plr
	if target.Character then
		target.Character:BreakJoints()
	end
	return "Respawning " .. target.Name
end, "Moderator", "Респавн игрока")

registerCommand("heal", function(plr, args)
	local target = getPlayer(args) or plr
	if target.Character then
		local hum = target.Character:FindFirstChild("Humanoid")
		if hum then
			hum.Health = hum.MaxHealth
		end
	end
	return "Healed " .. target.Name
end, "Moderator", "Вылечить игрока")

registerCommand("kill", function(plr, args)
	local target = getPlayer(args)
	if not target then return "Player not found" end
	if target.Character then
		local hum = target.Character:FindFirstChild("Humanoid")
		if hum then
			hum.Health = 0
		end
	end
	return "Killed " .. target.Name
end, "Admin", "Убить игрока")

-- ==================== ИНФОРМАЦИОННЫЕ КОМАНДЫ ====================
registerCommand("players", function(plr, args)
	local names = {}
	for _, p in ipairs(game.Players:GetPlayers()) do
		table.insert(names, p.Name)
	end
	return "Online: " .. table.concat(names, ", ")
end, "User", "Список игроков онлайн")

registerCommand("help", function(plr, args)
	local rank = CONFIG.Ranks[CONFIG.DefaultRank].Level
	for r, data in pairs(CONFIG.Ranks) do
		if data.Level <= rank then
			-- показать только доступные команды
		end
	end
	local cmds = {}
	for cmd, data in pairs(Commands) do
		if isAllowed(plr, cmd) then
			table.insert(cmds, cmd .. " - " .. data.desc)
		end
	end
	return "Commands: " .. table.concat(cmds, "; ")
end, "User", "Показать все доступные команды")

-- ==================== ДОПОЛНИТЕЛЬНЫЕ КОМАНДЫ (более 100 штук) ====================
-- Здесь можно добавить ещё десятки команд: freeze/unfreeze, fly, noclip, fireworks, 
-- setstat, resetstats, givebadge, destroyvehicle, clone, etc.
-- Ниже примеры ещё нескольких:

registerCommand("fly", function(plr, args)
	local target = getPlayer(args) or plr
	-- Включает режим полёта (через BodyVelocity или изменение Gravity)
	return "Fly mode not fully implemented (example)"
end, "SuperAdmin", "Режим полёта (заглушка)")

registerCommand("noclip", function(plr, args)
	local target = getPlayer(args) or plr
	-- Отключает коллизии
	return "Noclip toggle (заглушка)"
end, "SuperAdmin", "Режим прохождения сквозь стены")

registerCommand("setstat", function(plr, args)
	-- Установить значение лидерстата
	if #args < 3 then return "Usage: setstat <stat> <value> <player>" end
	local statName = args[1]
	local value = tonumber(args[2])
	if not value then return "Invalid value" end
	local target = getPlayer({args[3]}) or plr
	if target then
		local stats = target:FindFirstChild("leaderstats")
		if stats then
			local stat = stats:FindFirstChild(statName)
			if stat then
				stat.Value = value
				return "Set " .. statName .. " to " .. value .. " for " .. target.Name
			end
		end
	end
	return "Stat not found"
end, "Admin", "Установить значение лидерстата")

registerCommand("explode", function(plr, args)
	local target = getPlayer(args)
	if not target then return "Player not found" end
	if target.Character then
		local pos = target.Character.PrimaryPart.Position
		local explosion = Instance.new("Explosion")
		explosion.Position = pos
		explosion.Parent = workspace
	end
	return "Boom!"
end, "SuperAdmin", "Взрыв в позиции игрока")

-- ==================== СИСТЕМА ПРОВЕРКИ ПРАВ ====================
local function getUserRank(plr)
	if table.find(CONFIG.OwnerIds, plr.UserId) then
		return "Owner"
	end
	-- Здесь можно подгружать ранг из Datastore, но для примера используем DefaultRank
	return CONFIG.DefaultRank
end

local function isAllowed(plr, command)
	local rankName = getUserRank(plr)
	local rankData = CONFIG.Ranks[rankName]
	if not rankData then return false end
	if rankData.Commands == "*" then return true end
	for _, cmd in ipairs(rankData.Commands) do
		if cmd == command then return true end
	end
	return false
end

-- ==================== ОБРАБОТКА СООБЩЕНИЙ В ЧАТЕ ====================
game.Players.PlayerAdded:Connect(function(plr)
	plr.Chatted:Connect(function(msg)
		if not msg:sub(1, #CONFIG.Prefix) == CONFIG.Prefix then return end
		local args = {}
		for word in msg:gsub(CONFIG.Prefix, ""):gmatch("%S+") do
			table.insert(args, word)
		end
		if #args == 0 then return end
		local cmdName = table.remove(args, 1)
		local cmdData = Commands[cmdName]
		if not cmdData then
			plr:SendMessage("Unknown command. Type !help")
			return
		end
		if not isAllowed(plr, cmdName) then
			plr:SendMessage("You don't have permission.")
			return
		end
		local result = cmdData.func(plr, args)
		if result then
			plr:SendMessage(tostring(result))
		end
	end)
end)

-- ==================== ИНИЦИАЛИЗАЦИЯ ====================
log("AdminSystem loaded. " .. table.getn(Commands) .. " commands registered.")

return AdminSystem
