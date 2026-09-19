local spawnedEntities = {}
local isHoldingSpeaker = false
local currentHeldSpeakerId = nil
local heldPropEntity = nil

local function GetModelConfig(modelHashOrName)
    local checkHash = type(modelHashOrName) == 'number' and modelHashOrName or joaat(modelHashOrName)
    for _, item in ipairs(Config.SpeakerModels) do
        if joaat(item.model) == checkHash then
            return item
        end
    end
    return Config.SpeakerModels[1]
end

local function GetClosestSpeaker(maxDist)
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local closestId = nil
    local closestDist = maxDist or (Config.InteractionDistance + 2.0)

    for id, speaker in pairs(ActiveSpeakers) do
        local coords = GetSpeakerCoords(speaker)
        if coords then
            local dist = #(playerCoords - coords)
            if dist < closestDist then
                closestDist = dist
                closestId = id
            end
        end
    end

    return closestId, closestDist
end

local function GetSpeakerIdFromEntity(entity)
    for id, spawnedEnt in pairs(spawnedEntities) do
        if spawnedEnt == entity then
            return id
        end
    end

    local entityCoords = GetEntityCoords(entity)
    local closestId = nil
    local minDistance = 2.0

    for id, speaker in pairs(ActiveSpeakers) do
        if speaker.coords then
            local sc = vector3(speaker.coords.x, speaker.coords.y, speaker.coords.z)
            local d = #(entityCoords - sc)
            if d < minDistance then
                minDistance = d
                closestId = id
            end
        end
    end

    return closestId
end

local function GetVehicleAttachedSpeaker(vehicle)
    if not DoesEntityExist(vehicle) then return nil end
    local netId = VehToNet(vehicle)
    for id, speaker in pairs(ActiveSpeakers) do
        if speaker.attachedVehicleNetId == netId then
            return id
        end
    end
    return nil
end

local function CleanUpCarriedProp()
    if heldPropEntity and DoesEntityExist(heldPropEntity) then
        DeleteEntity(heldPropEntity)
    end
    heldPropEntity = nil
    isHoldingSpeaker = false
    currentHeldSpeakerId = nil
    lib.hideTextUI()
    ClearPedTasks(PlayerPedId())
end

function StartHoldingSpeaker(speakerId)
    local speaker = ActiveSpeakers[speakerId]
    if not speaker then return end

    if isHoldingSpeaker then
        Config.Notify('You are already holding a speaker.', 'error')
        return
    end

    TriggerServerEvent('5Mspeakers:server:holdSpeaker', speakerId)
end

RegisterNetEvent('5Mspeakers:client:startHoldingSpeaker', function(speakerId)
    local speaker = ActiveSpeakers[speakerId]
    if not speaker then return end

    CleanUpCarriedProp()

    local playerPed = PlayerPedId()
    local modelConf = GetModelConfig(speaker.model)
    local modelHash = joaat(speaker.model)

    lib.requestModel(modelHash)
    lib.requestAnimDict(Config.Carry.animDict)

    isHoldingSpeaker = true
    currentHeldSpeakerId = speakerId

    local pCoords = GetEntityCoords(playerPed)
    heldPropEntity = CreateObject(modelHash, pCoords.x, pCoords.y, pCoords.z, true, true, false)
    SetEntityCollision(heldPropEntity, false, false)

    local boneIdx = GetPedBoneIndex(playerPed, Config.Carry.bone)
    local offset = modelConf.holdOffset or vector3(0.0, 0.35, 0.0)
    local rot = modelConf.holdRotation or vector3(0.0, 0.0, 0.0)

    AttachEntityToEntity(heldPropEntity, playerPed, boneIdx, offset.x, offset.y, offset.z, rot.x, rot.y, rot.z, true, true, false, true, 1, true)
    TaskPlayAnim(playerPed, Config.Carry.animDict, Config.Carry.animClip, 8.0, -8.0, -1, Config.Carry.animFlag, 0, false, false, false)

    lib.showTextUI('[E] Place on Ground  |  [Eye/Target] Vehicle to Attach  |  [X] Drop', { position = 'top-center' })

    CreateThread(function()
        while isHoldingSpeaker and currentHeldSpeakerId == speakerId do
            Wait(0)
            if not IsEntityPlayingAnim(playerPed, Config.Carry.animDict, Config.Carry.animClip, 3) then
                TaskPlayAnim(playerPed, Config.Carry.animDict, Config.Carry.animClip, 8.0, -8.0, -1, Config.Carry.animFlag, 0, false, false, false)
            end

            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 140, true)
            DisableControlAction(0, 141, true)
            DisableControlAction(0, 142, true)

            if IsControlJustPressed(0, 38) then
                local forwardVector = GetEntityForwardVector(playerPed)
                local pPos = GetEntityCoords(playerPed)
                local placeCoords = pPos + (forwardVector * 0.8)
                local foundGround, zPos = GetGroundZFor_3dCoord(placeCoords.x, placeCoords.y, placeCoords.z + 1.0, false)
                if foundGround then
                    placeCoords = vector3(placeCoords.x, placeCoords.y, zPos)
                end
                local heading = GetEntityHeading(playerPed)

                TriggerServerEvent('5Mspeakers:server:placeSpeaker', speakerId, {
                    x = placeCoords.x,
                    y = placeCoords.y,
                    z = placeCoords.z,
                    h = heading
                })
                CleanUpCarriedProp()
                break
            elseif IsControlJustPressed(0, 73) then
                local pPos = GetEntityCoords(playerPed)
                local heading = GetEntityHeading(playerPed)
                local foundGround, zPos = GetGroundZFor_3dCoord(pPos.x, pPos.y, pPos.z, false)
                if foundGround then
                    pPos = vector3(pPos.x, pPos.y, zPos)
                end
                TriggerServerEvent('5Mspeakers:server:placeSpeaker', speakerId, {
                    x = pPos.x,
                    y = pPos.y,
                    z = pPos.z,
                    h = heading
                })
                CleanUpCarriedProp()
                break
            end
        end
    end)
end)

local function StartVehiclePlacementMode(speakerId, targetVehicle)
    local speaker = ActiveSpeakers[speakerId]
    if not speaker or not DoesEntityExist(targetVehicle) then return end

    if heldPropEntity and DoesEntityExist(heldPropEntity) then
        DeleteEntity(heldPropEntity)
    end
    heldPropEntity = nil
    ClearPedTasks(PlayerPedId())

    local modelHash = joaat(speaker.model)
    lib.requestModel(modelHash)

    local ghostObj = CreateObject(modelHash, GetEntityCoords(targetVehicle), false, false, false)
    SetEntityCollision(ghostObj, false, false)
    SetEntityAlpha(ghostObj, 200, false)

    local relRotX, relRotY, relRotZ = 0.0, 0.0, 0.0
    lib.showTextUI('[E] Confirm Attachment  |  [Scroll/Arrows] Rotate  |  [X] Cancel', { position = 'top-center' })

    local placing = true
    while placing do
        Wait(0)
        local playerPed = PlayerPedId()
        local camPos = GetGameplayCamCoord()
        local camRot = GetGameplayCamRot(2)
        local forward = -vector3(
            math.sin(math.rad(camRot.z)) * math.abs(math.cos(math.rad(camRot.x))),
            math.cos(math.rad(camRot.z)) * math.abs(math.cos(math.rad(camRot.x))),
            -math.sin(math.rad(camRot.x))
        )
        local targetPos = camPos + (forward * 8.0)
        local ray = StartExpensiveSynchronousShapeTestLosProbe(camPos.x, camPos.y, camPos.z, targetPos.x, targetPos.y, targetPos.z, 2, playerPed, 0)
        local _, h, hitCoords, _, entityHit = GetShapeTestResult(ray)

        local worldPos = hitCoords
        if h == 0 or #(GetEntityCoords(playerPed) - worldPos) > 6.0 then
            local pPos = GetEntityCoords(playerPed)
            local fwd = GetEntityForwardVector(playerPed)
            worldPos = pPos + (fwd * 1.5)
        end

        local localOffset = GetOffsetFromEntityGivenWorldCoords(targetVehicle, worldPos.x, worldPos.y, worldPos.z)

        if IsControlPressed(0, 15) or IsControlPressed(0, 174) then
            relRotZ = (relRotZ + 2.0) % 360.0
        elseif IsControlPressed(0, 14) or IsControlPressed(0, 175) then
            relRotZ = (relRotZ - 2.0) % 360.0
        elseif IsControlPressed(0, 172) then
            relRotX = (relRotX + 2.0) % 360.0
        elseif IsControlPressed(0, 173) then
            relRotX = (relRotX - 2.0) % 360.0
        end

        AttachEntityToEntity(ghostObj, targetVehicle, 0, localOffset.x, localOffset.y, localOffset.z, relRotX, relRotY, relRotZ, false, false, false, false, 2, true)

        if IsControlJustPressed(0, 38) then
            placing = false
            lib.hideTextUI()
            DeleteEntity(ghostObj)
            TriggerServerEvent('5Mspeakers:server:attachSpeakerToVehicle', speakerId, VehToNet(targetVehicle), {
                x = localOffset.x,
                y = localOffset.y,
                z = localOffset.z
            }, {
                x = relRotX,
                y = relRotY,
                z = relRotZ
            })
            isHoldingSpeaker = false
            currentHeldSpeakerId = nil
            break
        elseif IsControlJustPressed(0, 73) then
            placing = false
            lib.hideTextUI()
            DeleteEntity(ghostObj)
            TriggerEvent('5Mspeakers:client:startHoldingSpeaker', speakerId)
            break
        end
    end
end

local function EnterPlacementMode(speakerName, speakerModel)
    local playerPed = PlayerPedId()
    local modelHash = joaat(speakerModel)
    lib.requestModel(modelHash)

    local ghostObj = CreateObject(modelHash, GetEntityCoords(playerPed), false, false, false)
    SetEntityCollision(ghostObj, false, false)
    SetEntityAlpha(ghostObj, 200, false)

    local currentHeading = GetEntityHeading(playerPed)

    lib.showTextUI('[E] Confirm  |  [Scroll/Arrows] Rotate  |  [X] Cancel', { position = 'top-center' })

    local placing = true
    while placing do
        Wait(0)
        local hit, hitCoords = false, vector3(0.0, 0.0, 0.0)
        local camPos = GetGameplayCamCoord()
        local camRot = GetGameplayCamRot(2)
        local forward = -vector3(
            math.sin(math.rad(camRot.z)) * math.abs(math.cos(math.rad(camRot.x))),
            math.cos(math.rad(camRot.z)) * math.abs(math.cos(math.rad(camRot.x))),
            -math.sin(math.rad(camRot.x))
        )
        local targetPos = camPos + (forward * 6.0)
        local ray = StartExpensiveSynchronousShapeTestLosProbe(camPos.x, camPos.y, camPos.z, targetPos.x, targetPos.y, targetPos.z, 1, playerPed, 0)
        local _, h, c, _, _ = GetShapeTestResult(ray)

        if h ~= 0 then
            hitCoords = c
        else
            local pPos = GetEntityCoords(playerPed)
            local fwd = GetEntityForwardVector(playerPed)
            hitCoords = pPos + (fwd * 1.5)
            local foundGround, zPos = GetGroundZFor_3dCoord(hitCoords.x, hitCoords.y, hitCoords.z + 1.0, false)
            if foundGround then
                hitCoords = vector3(hitCoords.x, hitCoords.y, zPos)
            end
        end

        if IsControlPressed(0, 15) or IsControlPressed(0, 174) then
            currentHeading = (currentHeading + 2.0) % 360.0
        elseif IsControlPressed(0, 14) or IsControlPressed(0, 175) then
            currentHeading = (currentHeading - 2.0) % 360.0
        end

        SetEntityCoords(ghostObj, hitCoords.x, hitCoords.y, hitCoords.z, false, false, false, false)
        SetEntityHeading(ghostObj, currentHeading)

        if IsControlJustPressed(0, 38) then
            placing = false
            lib.hideTextUI()
            DeleteEntity(ghostObj)
            TriggerServerEvent('5Mspeakers:server:createSpeaker', speakerName, speakerModel, {
                x = hitCoords.x,
                y = hitCoords.y,
                z = hitCoords.z,
                h = currentHeading
            })
            break
        elseif IsControlJustPressed(0, 73) then
            placing = false
            lib.hideTextUI()
            DeleteEntity(ghostObj)
            Config.Notify('Speaker creation canceled.', 'error')
            break
        end
    end
end

CreateThread(function()
    while true do
        Wait(1000)
        local playerCoords = GetEntityCoords(PlayerPedId())

        for id, speaker in pairs(ActiveSpeakers) do
            local shouldExist = false
            local targetCoords = nil

            if speaker.heldBy then
                shouldExist = false
            elseif speaker.attachedVehicleNetId then
                shouldExist = true
            elseif speaker.coords then
                targetCoords = vector3(speaker.coords.x, speaker.coords.y, speaker.coords.z)
                if #(playerCoords - targetCoords) < 80.0 then
                    shouldExist = true
                end
            end

            if shouldExist then
                if not spawnedEntities[id] or not DoesEntityExist(spawnedEntities[id]) then
                    local modelHash = joaat(speaker.model)
                    lib.requestModel(modelHash)

                    if speaker.attachedVehicleNetId then
                        local veh = NetToVeh(speaker.attachedVehicleNetId)
                        if DoesEntityExist(veh) then
                            local obj = CreateObject(modelHash, GetEntityCoords(veh), false, false, false)
                            local modelConf = GetModelConfig(speaker.model)
                            local offset = speaker.attachOffset and vector3(speaker.attachOffset.x, speaker.attachOffset.y, speaker.attachOffset.z) or (modelConf.trunkOffset or vector3(0.0, -0.2, 0.0))
                            local rot = speaker.attachRot and vector3(speaker.attachRot.x, speaker.attachRot.y, speaker.attachRot.z) or (modelConf.trunkRotation or vector3(0.0, 0.0, 0.0))

                            AttachEntityToEntity(obj, veh, 0, offset.x, offset.y, offset.z, rot.x, rot.y, rot.z, false, false, false, false, 2, true)
                            SetEntityCollision(obj, false, false)
                            spawnedEntities[id] = obj
                        end
                    elseif speaker.coords then
                        local obj = CreateObject(modelHash, speaker.coords.x, speaker.coords.y, speaker.coords.z, false, false, false)
                        SetEntityHeading(obj, speaker.coords.h or 0.0)
                        FreezeEntityPosition(obj, true)
                        PlaceObjectOnGroundProperly(obj)
                        spawnedEntities[id] = obj
                    end
                end
            else
                if spawnedEntities[id] and DoesEntityExist(spawnedEntities[id]) then
                    DeleteEntity(spawnedEntities[id])
                    spawnedEntities[id] = nil
                end
            end
        end

        for id, ent in pairs(spawnedEntities) do
            if not ActiveSpeakers[id] then
                if DoesEntityExist(ent) then
                    DeleteEntity(ent)
                end
                spawnedEntities[id] = nil
            end
        end
    end
end)

local function OpenCreateSpeakerDialog()
    local modelOptions = {}
    for _, item in ipairs(Config.SpeakerModels) do
        table.insert(modelOptions, {
            value = item.model,
            label = item.label
        })
    end

    local input = lib.inputDialog('Create Speaker', {
        {
            type = 'input',
            label = 'Speaker Name',
            placeholder = 'e.g. Stage Left, Beach Boombox',
            required = true
        },
        {
            type = 'select',
            label = 'Speaker Model',
            options = modelOptions,
            default = modelOptions[1].value,
            required = true
        }
    })

    if input and input[1] and input[2] then
        EnterPlacementMode(input[1], input[2])
    end
end

local function TriggerDeleteClosestSpeaker()
    local closestId, dist = GetClosestSpeaker(Config.InteractionDistance + 2.0)
    if closestId then
        local speaker = ActiveSpeakers[closestId]
        local confirm = lib.alertDialog({
            header = 'Delete Speaker',
            content = 'Are you sure you want to permanently delete ' .. (speaker and speaker.name or 'this speaker') .. '?',
            centered = true,
            cancel = true
        })
        if confirm == 'confirm' then
            TriggerServerEvent('5Mspeakers:server:deleteSpeaker', closestId)
        end
    else
        Config.Notify('No speaker close enough to delete.', 'error')
    end
end

local function OpenClosestSpeakerMenu()
    local playerPed = PlayerPedId()
    local pCoords = GetEntityCoords(playerPed)

    local veh = lib.getClosestVehicle(pCoords, Config.TrunkAttachDistance or 3.0, false)
    if veh and DoesEntityExist(veh) then
        local attachedId = GetVehicleAttachedSpeaker(veh)
        if attachedId then
            OpenSpeakerMenu(attachedId)
            return
        end
    end

    local closestId, dist = GetClosestSpeaker(Config.InteractionDistance + 2.0)
    if closestId then
        OpenSpeakerMenu(closestId)
    else
        Config.Notify('No speaker close enough to interact with.', 'error')
    end
end

RegisterNetEvent('5Mspeakers:client:openCreateDialog', OpenCreateSpeakerDialog)
RegisterNetEvent('5Mspeakers:client:triggerDelete', TriggerDeleteClosestSpeaker)
RegisterNetEvent('5Mspeakers:client:openClosestSpeaker', OpenClosestSpeakerMenu)

CreateThread(function()
    TriggerEvent('chat:addSuggestion', '/' .. (Config.Commands.create or 'create-speaker'), 'Create and place a new speaker in the world')
    TriggerEvent('chat:addSuggestion', '/' .. (Config.Commands.delete or 'delete-speaker'), 'Delete the speaker closest to you')
    TriggerEvent('chat:addSuggestion', '/' .. (Config.Commands.speaker or 'speaker'), 'Open interaction menu for closest speaker')
end)

CreateThread(function()
    local targetModels = {}
    for _, item in ipairs(Config.SpeakerModels) do
        table.insert(targetModels, item.model)
    end

    exports.ox_target:addModel(targetModels, {
        {
            name = 'speaker_open_menu',
            icon = 'fa-solid fa-music',
            label = 'Open Speaker',
            distance = Config.InteractionDistance or 3.0,
            canInteract = function(entity, distance, coords, name, bone)
                return not isHoldingSpeaker
            end,
            onSelect = function(data)
                local speakerId = GetSpeakerIdFromEntity(data.entity)
                if speakerId then
                    OpenSpeakerMenu(speakerId)
                else
                    Config.Notify('Could not identify this speaker.', 'error')
                end
            end
        },
        {
            name = 'speaker_carry',
            icon = 'fa-solid fa-hand',
            label = 'Hold speaker',
            distance = Config.InteractionDistance or 3.0,
            canInteract = function(entity, distance, coords, name, bone)
                return not isHoldingSpeaker
            end,
            onSelect = function(data)
                local speakerId = GetSpeakerIdFromEntity(data.entity)
                if speakerId then
                    StartHoldingSpeaker(speakerId)
                end
            end
        }
    })

    exports.ox_target:addGlobalVehicle({
        {
            name = 'vehicle_attach_held_speaker',
            icon = 'fa-solid fa-volume-high',
            label = 'Attach Speaker',
            distance = 4.0,
            canInteract = function(entity, distance, coords, name, bone)
                return isHoldingSpeaker and currentHeldSpeakerId ~= nil
            end,
            onSelect = function(data)
                if isHoldingSpeaker and currentHeldSpeakerId then
                    StartVehiclePlacementMode(currentHeldSpeakerId, data.entity)
                end
            end
        },
        {
            name = 'vehicle_attached_speaker_menu',
            icon = 'fa-solid fa-music',
            label = 'Speaker Controls',
            distance = 4.0,
            canInteract = function(entity, distance, coords, name, bone)
                local id = GetVehicleAttachedSpeaker(entity)
                return id ~= nil
            end,
            onSelect = function(data)
                local id = GetVehicleAttachedSpeaker(data.entity)
                if id then
                    OpenSpeakerMenu(id)
                end
            end
        },
        {
            name = 'vehicle_attached_speaker_detach',
            icon = 'fa-solid fa-hand',
            label = 'Detach Speaker',
            distance = 4.0,
            canInteract = function(entity, distance, coords, name, bone)
                local id = GetVehicleAttachedSpeaker(entity)
                return id ~= nil and not isHoldingSpeaker
            end,
            onSelect = function(data)
                local id = GetVehicleAttachedSpeaker(data.entity)
                if id then
                    TriggerServerEvent('5Mspeakers:server:detachSpeaker', id)
                end
            end
        }
    })
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    CleanUpCarriedProp()
    for _, ent in pairs(spawnedEntities) do
        if DoesEntityExist(ent) then
            DeleteEntity(ent)
        end
    end
end)

