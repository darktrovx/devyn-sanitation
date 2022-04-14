local QBCore = exports["qb-core"]:GetCoreObject()
local Jobs = {}

RegisterServerEvent("garbage:createGroupJob", function(groupID)
    local src = source
    if FindJobById(groupID) == 0 then 
        Jobs[#Jobs+1] = {groupID = groupID, truckID = 0, routes=10, currentRoute=0, bags=0, pickupAmount=0, totalCollected=0}

        local jobID = #Jobs

        local TruckSpawn = Config.TruckSpawns[math.random(#Config.TruckSpawns)]

        local car = CreateVehicle("trash", TruckSpawn.x, TruckSpawn.y, TruckSpawn.z, TruckSpawn.w, true, true)
        while not DoesEntityExist(car) do
            Wait(25)
        end
        if DoesEntityExist(car) then
            SetVehicleNumberPlateText(car, "GARB"..tostring(math.random(1000, 9999)))
            SetVehicleDoorsLocked(car, 2)
            Wait(500) -- Gotta wait here so the plate can be grabbed correctly? Not sure why it takes the server so long to register it.

            Jobs[jobID]["truckID"] = car
            Jobs[jobID]["route"] = PickRandomRoute()
            Jobs[jobID]["pickupAmount"] = math.random(4, 6)
            local plate = GetVehicleNumberPlateText(car)
            local members = exports["ps-playergroups"]:getGroupMembers(groupID)
            for i=1, #members do 
                TriggerClientEvent('vehiclekeys:client:SetOwner', members[i], plate)
                TriggerClientEvent("garbage:updatePickup", members[i], Routes.Locations[Jobs[jobID]["route"]]["coords"])
                Wait(100)
                TriggerClientEvent("garbage:startRoute", members[i], NetworkGetNetworkIdFromEntity(car))
            end
            exports["ps-playergroups"]:setJobStatus(groupID, "GARBAGE RUN")
        end

        exports["ps-playergroups"]:CreateBlipForGroup(groupID, "garbagePickup", {
            label = "Pickup", 
            coords = Routes.Locations[Jobs[jobID]["route"]]["coords"], 
            sprite = 162, 
            color = 11, 
            scale = 1.0, 
            route = true,
            routeColor = 2,
        })
    else 
        print("no group id found in jobs")
    end
end)

RegisterServerEvent("garbage:stopGroupJob", function(groupID)
    local src = source
    local jobID = FindJobById(groupID)
    local truckCoords = GetEntityCoords(Jobs[jobID]["truckID"])

    if #(truckCoords - Config.Blip) < 30 then
        DeleteEntity(Jobs[jobID]["truckID"])

        exports["ps-playergroups"]:RemoveBlipForGroup(groupID, "garbagePickup")
        local members = exports["ps-playergroups"]:getGroupMembers(groupID)
        local payout = math.floor((Jobs[jobID]["totalCollected"] * 50) / exports["ps-playergroups"]:getGroupSize(groupID) + 0.5)

        for i=1, #members do
            TriggerClientEvent("garbage:endRoute", members[i])
            if payout > 0 then
                local m = QBCore.Functions.GetPlayer(members[i])
                m.Functions.AddMoney("bank", payout, "Garbage Runs")
                TriggerClientEvent("QBCore:Notify", members[i], "You got $"..payout.." for your garbage run", "success")
            end
        end

        Jobs[jobID] = nil
        exports["ps-playergroups"]:setJobStatus(groupID, "WAITING")
    else 
        TriggerClientEvent("QBCore:Notify", src "Your truck is not inside the facility", "error")
    end
end)

RegisterServerEvent("garbage:updateBags", function(groupID)
    local src = source
    local jobID = FindJobById(groupID)
    Jobs[jobID]["bags"] = Jobs[jobID]["bags"] + 1
    Jobs[jobID]["totalCollected"] = Jobs[jobID]["totalCollected"] + 1
    if Jobs[jobID]["bags"] >= Jobs[jobID]["pickupAmount"] then
        Jobs[jobID]["bags"] = 0
        Jobs[jobID]["pickupAmount"] = math.random(4, 6)
        local newRoute = PickRandomRoute()
        while newRoute == Jobs[jobID]["currentRoute"] do
            newRoute = PickRandomRoute()
            Wait(100)
        end
        local members = exports["ps-playergroups"]:getGroupMembers(groupID)
        for i=1, #members do
            TriggerClientEvent("QBCore:Notify", members[i], "All bags collected for this dumpster", "primary")
            TriggerClientEvent('garage:pickupClean', members[i])
            TriggerClientEvent('garbage:updatePickup', members[i], Routes.Locations[newRoute]["coords"])
            if math.random(1, 100) > 70 then
                local itemIndex = math.random(1, #Config.Rewards)
                local amount = math.random(Config.Rewards[itemIndex]["min"], Config.Rewards[itemIndex]["max"])
                local m = QBCore.Functions.GetPlayer(members[i])
                m.Functions.AddItem(Config.Rewards[itemIndex]["item"], amount)
                TriggerClientEvent('inventory:client:ItemBox', members[i], QBCore.Shared.Items[Config.Rewards[itemIndex]["item"]], 'add', amount)
            end
        end
        Jobs[jobID]["currentRoute"] = newRoute
        exports["ps-playergroups"]:RemoveBlipForGroup(groupID, "garbagePickup")
        exports["ps-playergroups"]:CreateBlipForGroup(groupID, "garbagePickup", {
            label = "Pickup", 
            coords = Routes.Locations[newRoute]["coords"], 
            sprite = 162, 
            color = 11, 
            scale = 1.0, 
            route = true,
            routeColor = 2,
        })
    end
end)


function FindJobById(id)
    for i=1, #Jobs do
        if Jobs[i]["groupID"] == id then
            return i
        end
    end
    return 0
end

function PickRandomRoute()
    return math.random(1, #Routes.Locations)
end
