-- ServerScript (в Workspace или ServerScriptService)
local admins = {123456789, 987654321} -- ваши UserId

game.Players.PlayerAdded:Connect(function(player)
    for _, id in ipairs(admins) do
        if player.UserId == id then
            player:SetRank(255) -- или ваша система прав
            break
        end
    end
end)
