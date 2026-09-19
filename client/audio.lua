ActiveSpeakers = {}
local playingInNui = {}

RegisterNetEvent('5Mspeakers:client:syncAllSpeakers', function(speakers)
    ActiveSpeakers = speakers or {}
end)

RegisterNetEvent('5Mspeakers:client:syncSpeaker', function(speakerId, speakerData)
    ActiveSpeakers[speakerId] = speakerData
    if not speakerData or not speakerData.currentSong then
        if playingInNui[speakerId] then
            SendNUIMessage({
                action = 'stop',
                speakerId = speakerId
            })
            playingInNui[speakerId] = nil
        end
    end
end)

RegisterNetEvent('5Mspeakers:client:removeSpeaker', function(speakerId)
    ActiveSpeakers[speakerId] = nil
    if playingInNui[speakerId] then
        SendNUIMessage({
            action = 'stop',
            speakerId = speakerId
        })
        playingInNui[speakerId] = nil
    end
end)

RegisterNetEvent('5Mspeakers:client:audioPause', function(speakerId)
    SendNUIMessage({
        action = 'pause',
        speakerId = speakerId
    })
end)

RegisterNetEvent('5Mspeakers:client:audioResume', function(speakerId)
    SendNUIMessage({
        action = 'resume',
        speakerId = speakerId
    })
end)

RegisterNetEvent('5Mspeakers:client:audioSeek', function(speakerId, time)
    SendNUIMessage({
        action = 'seek',
        speakerId = speakerId,
        time = time
    })
end)

function GetSpeakerCoords(speaker)
    if not speaker then return nil end

    if speaker.heldBy then
        local player = GetPlayerFromServerId(speaker.heldBy)
        if player ~= -1 then
            local ped = GetPlayerPed(player)
            if DoesEntityExist(ped) then
                return GetEntityCoords(ped)
            end
        end
    end

    if speaker.attachedVehicleNetId then
        local veh = NetToVeh(speaker.attachedVehicleNetId)
        if DoesEntityExist(veh) then
            return GetEntityCoords(veh)
        end
    end

    if speaker.coords then
        return vector3(speaker.coords.x, speaker.coords.y, speaker.coords.z)
    end

    return nil
end

CreateThread(function()
    while true do
        Wait(Config.SoundUpdateInterval or 200)
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)

        for speakerId, speaker in pairs(ActiveSpeakers) do
            local speakerCoords = GetSpeakerCoords(speaker)
            if speakerCoords and speaker.currentSong and speaker.currentSong.videoId then
                local maxRange = speaker.rangeDist or Config.DefaultRange or 25.0
                local dist = #(playerCoords - speakerCoords)

                if dist <= maxRange then
                    local baseVolume = speaker.volume or Config.DefaultVolume or 0.5
                    local factor = 1.0 - (dist / maxRange)
                    if factor < 0.0 then factor = 0.0 end
                    local finalVolume = baseVolume * factor

                    if not playingInNui[speakerId] then
                        local elapsed = speaker.currentSong.elapsed or 0
                        if not speaker.isPaused and speaker.currentSong.timestamp then
                            local now = GetCloudTimeAsInt()
                            local diff = now - speaker.currentSong.timestamp
                            if diff > 0 then
                                elapsed = elapsed + diff
                            end
                        end

                        SendNUIMessage({
                            action = 'play',
                            speakerId = speakerId,
                            videoId = speaker.currentSong.videoId,
                            volume = finalVolume,
                            time = elapsed,
                            isPaused = speaker.isPaused or false
                        })
                        playingInNui[speakerId] = true
                    else
                        SendNUIMessage({
                            action = 'updateVolume',
                            speakerId = speakerId,
                            volume = finalVolume
                        })
                    end
                else
                    if playingInNui[speakerId] then
                        if dist > (maxRange + 15.0) then
                            SendNUIMessage({
                                action = 'stop',
                                speakerId = speakerId
                            })
                            playingInNui[speakerId] = nil
                        else
                            SendNUIMessage({
                                action = 'updateVolume',
                                speakerId = speakerId,
                                volume = 0.0
                            })
                        end
                    end
                end
            else
                if playingInNui[speakerId] then
                    SendNUIMessage({
                        action = 'stop',
                        speakerId = speakerId
                    })
                    playingInNui[speakerId] = nil
                end
            end
        end
    end
end)

RegisterNUICallback('songEnded', function(data, cb)
    if data and data.speakerId then
        TriggerServerEvent('5Mspeakers:server:songEnded', data.speakerId)
    end
    cb('ok')
end)

RegisterNUICallback('songError', function(data, cb)
    if data and data.speakerId then
        TriggerServerEvent('5Mspeakers:server:songEnded', data.speakerId)
    end
    cb('ok')
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    SendNUIMessage({ action = 'stopAll' })
end)

