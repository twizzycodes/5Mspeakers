local Speakers = {}
local lastSongEndTimes = {}

local function GenerateId()
    return 'spk_' .. tostring(os.time()) .. '_' .. tostring(math.random(1000, 9999))
end

local function SaveSpeakerToDatabase(speaker)
    if not Config.UseOxMySQL then return end
    local query = [[
        INSERT INTO `speakers` (`id`, `name`, `model`, `coords`, `volume`, `range_dist`, `current_song`, `queue`)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE
        `name` = VALUES(`name`),
        `model` = VALUES(`model`),
        `coords` = VALUES(`coords`),
        `volume` = VALUES(`volume`),
        `range_dist` = VALUES(`range_dist`),
        `current_song` = VALUES(`current_song`),
        `queue` = VALUES(`queue`)
    ]]
    local currentSongJson = speaker.currentSong and json.encode(speaker.currentSong) or nil
    local queueJson = speaker.queue and json.encode(speaker.queue) or '[]'
    local coordsJson = json.encode(speaker.coords or { x = 0.0, y = 0.0, z = 0.0, h = 0.0 })

    MySQL.query(query, {
        speaker.id,
        speaker.name,
        speaker.model,
        coordsJson,
        speaker.volume or Config.DefaultVolume or 0.5,
        speaker.rangeDist or Config.DefaultRange or 25.0,
        currentSongJson,
        queueJson
    })
end

local function DeleteSpeakerFromDatabase(speakerId)
    if not Config.UseOxMySQL then return end
    MySQL.query('DELETE FROM `speakers` WHERE `id` = ?', { speakerId })
end

local function PrintStartupBanner(savedCount)
    local timeStr = os.date('%I:%M:%S %p')
    print(('[5MSPEAKERS:INFO] [%s] ======================================================='):format(timeStr))
    print(('[5MSPEAKERS:INFO] [%s]   5 M   S P E A K E R   S Y S T E M'):format(timeStr))
    print(('[5MSPEAKERS:INFO] [%s]   Developed by Twizzy Codes (https://twizzy.codes)'):format(timeStr))
    print(('[5MSPEAKERS:INFO] [%s] ======================================================='):format(timeStr))
    print(('[5MSPEAKERS:INFO] [%s] Loaded %s saved speakers from database.'):format(timeStr, savedCount or 0))
    print(('[5MSPEAKERS:INFO] [%s] FiveM Resource [5Mspeakers] started successfully.'):format(timeStr))
end

local function LoadSpeakersFromDatabase()
    if not Config.UseOxMySQL then
        PrintStartupBanner(0)
        return
    end
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `speakers` (
            `id` VARCHAR(64) NOT NULL,
            `name` VARCHAR(100) NOT NULL,
            `model` VARCHAR(100) NOT NULL,
            `coords` LONGTEXT NOT NULL,
            `volume` FLOAT NOT NULL DEFAULT 0.5,
            `range_dist` FLOAT NOT NULL DEFAULT 25.0,
            `current_song` LONGTEXT DEFAULT NULL,
            `queue` LONGTEXT DEFAULT NULL,
            `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]], {}, function()
        MySQL.query('SELECT * FROM `speakers`', {}, function(results)
            local loadedCount = 0
            if results and #results > 0 then
                loadedCount = #results
                for _, row in ipairs(results) do
                    local coords = json.decode(row.coords) or { x = 0.0, y = 0.0, z = 0.0, h = 0.0 }
                    local queue = row.queue and json.decode(row.queue) or {}
                    local currentSong = row.current_song and json.decode(row.current_song) or nil

                    local attachOffset = coords.attachOffset or nil
                    local attachRot = coords.attachRot or nil
                    local attachedVehicleNetId = coords.attachedVehicleNetId or nil

                    Speakers[row.id] = {
                        id = row.id,
                        name = row.name,
                        model = row.model,
                        coords = coords,
                        volume = tonumber(row.volume) or Config.DefaultVolume or 0.5,
                        rangeDist = tonumber(row.range_dist) or Config.DefaultRange or 25.0,
                        currentSong = currentSong,
                        queue = queue,
                        isPaused = false,
                        heldBy = nil,
                        attachedVehicleNetId = attachedVehicleNetId,
                        attachOffset = attachOffset,
                        attachRot = attachRot,
                        groupedWith = {}
                    }
                end
                TriggerClientEvent('5Mspeakers:client:syncAllSpeakers', -1, Speakers)
            end
            PrintStartupBanner(loadedCount)
        end)
    end)
end

AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    LoadSpeakersFromDatabase()
end)

RegisterNetEvent('5Mspeakers:server:requestSync', function()
    local src = source
    TriggerClientEvent('5Mspeakers:client:syncAllSpeakers', src, Speakers)
end)

AddEventHandler('playerJoining', function()
    local src = source
    TriggerClientEvent('5Mspeakers:client:syncAllSpeakers', src, Speakers)
end)

local function ExtractYoutubeVideoId(url)
    if not url or url == '' then return nil end
    local match = string.match(url, 'v=([a-zA-Z0-9_-]+)')
    if match then return match end
    match = string.match(url, 'youtu%.be/([a-zA-Z0-9_-]+)')
    if match then return match end
    match = string.match(url, 'embed/([a-zA-Z0-9_-]+)')
    if match then return match end
    if string.len(url) == 11 and not string.find(url, '/') then
        return url
    end
    return nil
end

local function ExtractYoutubePlaylistId(url)
    if not url or url == '' then return nil end
    local match = string.match(url, 'list=([a-zA-Z0-9_-]+)')
    return match
end

local function ScrapeYoutubePlaylistWeb(playlistId, callback)
    local endpoint = ('https://www.youtube.com/playlist?list=%s'):format(playlistId)
    local headers = {
        ['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
    }
    PerformHttpRequest(endpoint, function(statusCode, responseText, resHeaders)
        if statusCode == 200 and responseText then
            local songs = {}
            local seen = {}
            for vId, title in string.gmatch(responseText, '"videoId":"([a-zA-Z0-9_-]+)".-lockupMetadataViewModel":.-"title":{"content":"(.-)"}') do
                if not seen[vId] and string.len(vId) == 11 then
                    seen[vId] = true
                    local cleanTitle = string.gsub(title, '\\u0026', '&')
                    cleanTitle = string.gsub(cleanTitle, '\\"', '"')
                    table.insert(songs, {
                        videoId = vId,
                        title = cleanTitle
                    })
                end
            end

            if #songs == 0 then
                for vId in string.gmatch(responseText, '"videoId":"([a-zA-Z0-9_-]+)"') do
                    if not seen[vId] and string.len(vId) == 11 then
                        seen[vId] = true
                        table.insert(songs, {
                            videoId = vId,
                            title = 'Track #' .. (#songs + 1)
                        })
                    end
                end
            end

            if #songs > 0 then
                callback(true, songs)
                return
            end
        end
        callback(false, nil)
    end, 'GET', '', headers)
end

local function ScrapeYoutubeVideoWeb(videoId, callback)
    local endpoint = ('https://www.youtube.com/watch?v=%s'):format(videoId)
    local headers = {
        ['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
    }
    PerformHttpRequest(endpoint, function(statusCode, responseText, resHeaders)
        if statusCode == 200 and responseText then
            local titleMatch = string.match(responseText, '<title>(.-) %- YouTube</title>')
            if titleMatch and titleMatch ~= '' then
                local cleanTitle = string.gsub(titleMatch, '&amp;', '&')
                cleanTitle = string.gsub(cleanTitle, '&#39;', "'")
                cleanTitle = string.gsub(cleanTitle, '&quot;', '"')
                callback(false, { { videoId = videoId, title = cleanTitle } })
                return
            end
        end
        callback(false, { { videoId = videoId, title = 'YouTube Track (' .. videoId .. ')' } })
    end, 'GET', '', headers)
end

local function FetchYoutubeMetadata(url, callback)
    local playlistId = ExtractYoutubePlaylistId(url)
    local videoId = ExtractYoutubeVideoId(url)
    local apiKey = Config.YoutubeApiKey

    if playlistId then
        if apiKey and apiKey ~= '' then
            local endpoint = ('https://www.googleapis.com/youtube/v3/playlistItems?part=snippet&maxResults=50&playlistId=%s&key=%s'):format(playlistId, apiKey)
            PerformHttpRequest(endpoint, function(statusCode, responseText, headers)
                if statusCode == 200 and responseText then
                    local data = json.decode(responseText)
                    if data and data.items and #data.items > 0 then
                        local playlistSongs = {}
                        for _, item in ipairs(data.items) do
                            if item.snippet and item.snippet.resourceId and item.snippet.resourceId.videoId then
                                table.insert(playlistSongs, {
                                    videoId = item.snippet.resourceId.videoId,
                                    title = item.snippet.title or 'Unknown title'
                                })
                            end
                        end
                        if #playlistSongs > 0 then
                            callback(true, playlistSongs)
                            return
                        end
                    end
                end

                ScrapeYoutubePlaylistWeb(playlistId, function(success, scrapedSongs)
                    if success and scrapedSongs and #scrapedSongs > 0 then
                        callback(true, scrapedSongs)
                    elseif videoId then
                        ScrapeYoutubeVideoWeb(videoId, callback)
                    else
                        callback(false, nil)
                    end
                end)
            end, 'GET', '', {})
            return
        else
            ScrapeYoutubePlaylistWeb(playlistId, function(success, scrapedSongs)
                if success and scrapedSongs and #scrapedSongs > 0 then
                    callback(true, scrapedSongs)
                elseif videoId then
                    ScrapeYoutubeVideoWeb(videoId, callback)
                else
                    callback(false, nil)
                end
            end)
            return
        end
    end

    if videoId then
        if apiKey and apiKey ~= '' then
            local endpoint = ('https://www.googleapis.com/youtube/v3/videos?part=snippet&id=%s&key=%s'):format(videoId, apiKey)
            PerformHttpRequest(endpoint, function(statusCode, responseText, headers)
                if statusCode == 200 and responseText then
                    local data = json.decode(responseText)
                    if data and data.items and #data.items > 0 then
                        local title = data.items[1].snippet and data.items[1].snippet.title or ('YouTube Track (' .. videoId .. ')')
                        callback(false, { { videoId = videoId, title = title } })
                        return
                    end
                end
                ScrapeYoutubeVideoWeb(videoId, callback)
            end, 'GET', '', {})
        else
            ScrapeYoutubeVideoWeb(videoId, callback)
        end
    else
        callback(false, nil)
    end
end

local function SyncSpeakerAndSlaves(speakerId)
    local master = Speakers[speakerId]
    if not master then return end

    TriggerClientEvent('5Mspeakers:client:syncSpeaker', -1, speakerId, master)

    if master.groupedWith and #master.groupedWith > 0 then
        for _, slaveId in ipairs(master.groupedWith) do
            local slave = Speakers[slaveId]
            if slave then
                slave.currentSong = master.currentSong
                slave.isPaused = master.isPaused
                TriggerClientEvent('5Mspeakers:client:syncSpeaker', -1, slaveId, slave)
            end
        end
    end

    SaveSpeakerToDatabase(master)
end

RegisterNetEvent('5Mspeakers:server:createSpeaker', function(name, model, coords)
    local src = source
    local id = GenerateId()

    Speakers[id] = {
        id = id,
        name = name or 'Speaker',
        model = model or Config.SpeakerModels[1].model,
        coords = coords,
        volume = Config.DefaultVolume or 0.5,
        rangeDist = Config.DefaultRange or 25.0,
        currentSong = nil,
        queue = {},
        isPaused = false,
        heldBy = nil,
        attachedVehicleNetId = nil,
        groupedWith = {}
    }

    SyncSpeakerAndSlaves(id)
    TriggerClientEvent('ox_lib:notify', src, {
        title = 'Speaker System',
        description = ('Created %s successfully.'):format(Speakers[id].name),
        type = 'success'
    })
end)

RegisterNetEvent('5Mspeakers:server:deleteSpeaker', function(speakerId)
    local src = source
    local speaker = Speakers[speakerId]
    if not speaker then return end

    if speaker.masterSpeakerId then
        local master = Speakers[speaker.masterSpeakerId]
        if master and master.groupedWith then
            for idx, gid in ipairs(master.groupedWith) do
                if gid == speakerId then
                    table.remove(master.groupedWith, idx)
                    break
                end
            end
        end
    end

    if speaker.groupedWith then
        for _, slaveId in ipairs(speaker.groupedWith) do
            if Speakers[slaveId] then
                Speakers[slaveId].masterSpeakerId = nil
                Speakers[slaveId].currentSong = nil
                TriggerClientEvent('5Mspeakers:client:syncSpeaker', -1, slaveId, Speakers[slaveId])
            end
        end
    end

    Speakers[speakerId] = nil
    DeleteSpeakerFromDatabase(speakerId)
    TriggerClientEvent('5Mspeakers:client:removeSpeaker', -1, speakerId)

    TriggerClientEvent('ox_lib:notify', src, {
        title = 'Speaker System',
        description = 'Speaker was successfully deleted.',
        type = 'success'
    })
end)

RegisterNetEvent('5Mspeakers:server:storeSpeaker', function(speakerId)
    local src = source
    local speaker = Speakers[speakerId]
    if not speaker then return end

    Speakers[speakerId] = nil
    DeleteSpeakerFromDatabase(speakerId)
    TriggerClientEvent('5Mspeakers:client:removeSpeaker', -1, speakerId)

    TriggerClientEvent('ox_lib:notify', src, {
        title = 'Speaker System',
        description = 'Speaker stashed away.',
        type = 'success'
    })
end)

RegisterNetEvent('5Mspeakers:server:holdSpeaker', function(speakerId)
    local src = source
    local speaker = Speakers[speakerId]
    if not speaker then return end

    if speaker.heldBy and speaker.heldBy ~= src then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Speaker System',
            description = 'Another person is currently holding this speaker.',
            type = 'error'
        })
        return
    end

    speaker.heldBy = src
    speaker.attachedVehicleNetId = nil

    SyncSpeakerAndSlaves(speakerId)
    TriggerClientEvent('5Mspeakers:client:startHoldingSpeaker', src, speakerId)
end)

RegisterNetEvent('5Mspeakers:server:placeSpeaker', function(speakerId, coords)
    local src = source
    local speaker = Speakers[speakerId]
    if not speaker then return end

    speaker.heldBy = nil
    speaker.attachedVehicleNetId = nil
    speaker.coords = coords

    SyncSpeakerAndSlaves(speakerId)
    TriggerClientEvent('ox_lib:notify', src, {
        title = 'Speaker System',
        description = 'Speaker placed on the ground.',
        type = 'success'
    })
end)

RegisterNetEvent('5Mspeakers:server:attachSpeakerToVehicle', function(speakerId, netId, offset, rot)
    local src = source
    local speaker = Speakers[speakerId]
    if not speaker then return end

    speaker.heldBy = nil
    speaker.attachedVehicleNetId = netId
    speaker.attachOffset = offset or { x = 0.0, y = -1.8, z = 0.2 }
    speaker.attachRot = rot or { x = 0.0, y = 0.0, z = 0.0 }

    if not speaker.coords then
        speaker.coords = { x = 0.0, y = 0.0, z = 0.0, h = 0.0 }
    end
    speaker.coords.attachOffset = speaker.attachOffset
    speaker.coords.attachRot = speaker.attachRot
    speaker.coords.attachedVehicleNetId = netId

    SyncSpeakerAndSlaves(speakerId)
    TriggerClientEvent('ox_lib:notify', src, {
        title = 'Speaker System',
        description = 'Speaker attached to vehicle.',
        type = 'success'
    })
end)

RegisterNetEvent('5Mspeakers:server:detachSpeaker', function(speakerId)
    local src = source
    local speaker = Speakers[speakerId]
    if not speaker then return end

    speaker.attachedVehicleNetId = nil
    speaker.heldBy = src

    SyncSpeakerAndSlaves(speakerId)
    TriggerClientEvent('5Mspeakers:client:startHoldingSpeaker', src, speakerId)
end)

RegisterNetEvent('5Mspeakers:server:playMusic', function(speakerId, url)
    local src = source
    local speaker = Speakers[speakerId]
    if not speaker then return end

    FetchYoutubeMetadata(url, function(isPlaylist, songs)
        if not songs or #songs == 0 then
            TriggerClientEvent('ox_lib:notify', src, {
                title = 'Speaker System',
                description = 'Failed to retrieve audio from provided link.',
                type = 'error'
            })
            return
        end

        local first = songs[1]
        speaker.currentSong = {
            videoId = first.videoId,
            title = first.title,
            timestamp = os.time(),
            elapsed = 0
        }
        speaker.isPaused = false

        if isPlaylist and #songs > 1 then
            for i = 2, #songs do
                table.insert(speaker.queue, songs[i])
            end
            TriggerClientEvent('ox_lib:notify', src, {
                title = 'Speaker System',
                description = ('Loaded playlist with %s songs.'):format(#songs),
                type = 'success'
            })
        else
            TriggerClientEvent('ox_lib:notify', src, {
                title = 'Speaker System',
                description = ('Playing: %s'):format(first.title),
                type = 'success'
            })
        end

        SyncSpeakerAndSlaves(speakerId)
    end)
end)

RegisterNetEvent('5Mspeakers:server:queueMusic', function(speakerId, url)
    local src = source
    local speaker = Speakers[speakerId]
    if not speaker then return end

    FetchYoutubeMetadata(url, function(isPlaylist, songs)
        if not songs or #songs == 0 then
            TriggerClientEvent('ox_lib:notify', src, {
                title = 'Speaker System',
                description = 'Invalid YouTube link or video ID.',
                type = 'error'
            })
            return
        end

        if not speaker.currentSong then
            local first = songs[1]
            speaker.currentSong = {
                videoId = first.videoId,
                title = first.title,
                timestamp = os.time(),
                elapsed = 0
            }
            speaker.isPaused = false

            if isPlaylist and #songs > 1 then
                for i = 2, #songs do
                    table.insert(speaker.queue, songs[i])
                end
            end
            SyncSpeakerAndSlaves(speakerId)
            TriggerClientEvent('ox_lib:notify', src, {
                title = 'Speaker System',
                description = ('Playing: %s'):format(first.title),
                type = 'success'
            })
            return
        end

        for _, song in ipairs(songs) do
            table.insert(speaker.queue, song)
        end

        SyncSpeakerAndSlaves(speakerId)
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Speaker System',
            description = ('Added %s track(s) to queue.'):format(#songs),
            type = 'success'
        })
    end)
end)

RegisterNetEvent('5Mspeakers:server:nextSong', function(speakerId)
    local src = source
    local speaker = Speakers[speakerId]
    if not speaker then return end

    if speaker.queue and #speaker.queue > 0 then
        local nextTrack = table.remove(speaker.queue, 1)
        speaker.currentSong = {
            videoId = nextTrack.videoId,
            title = nextTrack.title,
            timestamp = os.time(),
            elapsed = 0
        }
        speaker.isPaused = false
        SyncSpeakerAndSlaves(speakerId)
        if src then
            TriggerClientEvent('ox_lib:notify', src, {
                title = 'Speaker System',
                description = ('Now playing: %s'):format(nextTrack.title),
                type = 'info'
            })
        end
    else
        speaker.currentSong = nil
        speaker.isPaused = false
        SyncSpeakerAndSlaves(speakerId)
        if src then
            TriggerClientEvent('ox_lib:notify', src, {
                title = 'Speaker System',
                description = 'Queue ended. Music stopped.',
                type = 'info'
            })
        end
    end
end)

RegisterNetEvent('5Mspeakers:server:songEnded', function(speakerId)
    local now = os.time()
    if lastSongEndTimes[speakerId] and (now - lastSongEndTimes[speakerId]) < 3 then
        return
    end
    lastSongEndTimes[speakerId] = now

    local speaker = Speakers[speakerId]
    if not speaker then return end

    if speaker.queue and #speaker.queue > 0 then
        local nextTrack = table.remove(speaker.queue, 1)
        speaker.currentSong = {
            videoId = nextTrack.videoId,
            title = nextTrack.title,
            timestamp = now,
            elapsed = 0
        }
        speaker.isPaused = false
        SyncSpeakerAndSlaves(speakerId)
    else
        speaker.currentSong = nil
        speaker.isPaused = false
        SyncSpeakerAndSlaves(speakerId)
    end
end)

RegisterNetEvent('5Mspeakers:server:togglePause', function(speakerId)
    local speaker = Speakers[speakerId]
    if not speaker or not speaker.currentSong then return end

    local now = os.time()
    if speaker.isPaused then
        speaker.isPaused = false
        speaker.currentSong.timestamp = now
        TriggerClientEvent('5Mspeakers:client:audioResume', -1, speakerId)
        if speaker.groupedWith then
            for _, slaveId in ipairs(speaker.groupedWith) do
                if Speakers[slaveId] then
                    Speakers[slaveId].isPaused = false
                    TriggerClientEvent('5Mspeakers:client:audioResume', -1, slaveId)
                end
            end
        end
    else
        speaker.isPaused = true
        if speaker.currentSong.timestamp then
            speaker.currentSong.elapsed = (speaker.currentSong.elapsed or 0) + (now - speaker.currentSong.timestamp)
        end
        speaker.currentSong.timestamp = nil
        TriggerClientEvent('5Mspeakers:client:audioPause', -1, speakerId)
        if speaker.groupedWith then
            for _, slaveId in ipairs(speaker.groupedWith) do
                if Speakers[slaveId] then
                    Speakers[slaveId].isPaused = true
                    TriggerClientEvent('5Mspeakers:client:audioPause', -1, slaveId)
                end
            end
        end
    end

    SyncSpeakerAndSlaves(speakerId)
end)

RegisterNetEvent('5Mspeakers:server:setVolumeRange', function(speakerId, volume, rangeDist)
    local src = source
    local speaker = Speakers[speakerId]
    if not speaker then return end

    speaker.volume = math.max(0.0, math.min(1.0, volume))
    speaker.rangeDist = math.max(Config.MinRange or 5.0, math.min(Config.MaxRange or 60.0, rangeDist))

    SyncSpeakerAndSlaves(speakerId)
    TriggerClientEvent('ox_lib:notify', src, {
        title = 'Speaker System',
        description = ('Settings updated. Volume: %s%%, Range: %sm'):format(math.floor(speaker.volume * 100), math.floor(speaker.rangeDist)),
        type = 'success'
    })
end)

RegisterNetEvent('5Mspeakers:server:renameSpeaker', function(speakerId, newName)
    local src = source
    local speaker = Speakers[speakerId]
    if not speaker then return end

    speaker.name = newName
    SyncSpeakerAndSlaves(speakerId)
    TriggerClientEvent('ox_lib:notify', src, {
        title = 'Speaker System',
        description = ('Renamed speaker to: %s'):format(newName),
        type = 'success'
    })
end)

RegisterNetEvent('5Mspeakers:server:setSpeakerGroup', function(masterId, selectedIds)
    local src = source
    local master = Speakers[masterId]
    if not master then return end

    if master.groupedWith then
        for _, oldSlaveId in ipairs(master.groupedWith) do
            local oldSlave = Speakers[oldSlaveId]
            if oldSlave and oldSlave.masterSpeakerId == masterId then
                oldSlave.masterSpeakerId = nil
                oldSlave.currentSong = nil
                TriggerClientEvent('5Mspeakers:client:syncSpeaker', -1, oldSlaveId, oldSlave)
            end
        end
    end

    master.groupedWith = {}

    for _, slaveId in ipairs(selectedIds) do
        local slave = Speakers[slaveId]
        if slave and slaveId ~= masterId then
            slave.masterSpeakerId = masterId
            slave.currentSong = master.currentSong
            slave.isPaused = master.isPaused
            table.insert(master.groupedWith, slaveId)
            TriggerClientEvent('5Mspeakers:client:syncSpeaker', -1, slaveId, slave)
        end
    end

    SyncSpeakerAndSlaves(masterId)
    TriggerClientEvent('ox_lib:notify', src, {
        title = 'Speaker System',
        description = ('Connected %s speaker(s) to this group.'):format(#master.groupedWith),
        type = 'success'
    })
end)

RegisterNetEvent('5Mspeakers:server:playQueueIndex', function(speakerId, index)
    local src = source
    local speaker = Speakers[speakerId]
    if not speaker or not speaker.queue or not speaker.queue[index] then return end

    local track = table.remove(speaker.queue, index)
    speaker.currentSong = {
        videoId = track.videoId,
        title = track.title,
        timestamp = os.time(),
        elapsed = 0
    }
    speaker.isPaused = false

    SyncSpeakerAndSlaves(speakerId)
    TriggerClientEvent('ox_lib:notify', src, {
        title = 'Speaker System',
        description = ('Now playing: %s'):format(track.title),
        type = 'success'
    })
end)

RegisterNetEvent('5Mspeakers:server:removeQueueIndex', function(speakerId, index)
    local src = source
    local speaker = Speakers[speakerId]
    if not speaker or not speaker.queue or not speaker.queue[index] then return end

    local removed = table.remove(speaker.queue, index)
    SyncSpeakerAndSlaves(speakerId)
    TriggerClientEvent('ox_lib:notify', src, {
        title = 'Speaker System',
        description = ('Removed: %s'):format(removed.title or 'track'),
        type = 'info'
    })
end)

RegisterNetEvent('5Mspeakers:server:clearQueue', function(speakerId)
    local src = source
    local speaker = Speakers[speakerId]
    if not speaker then return end

    speaker.queue = {}
    SyncSpeakerAndSlaves(speakerId)
    TriggerClientEvent('ox_lib:notify', src, {
        title = 'Speaker System',
        description = 'Queue has been cleared.',
        type = 'info'
    })
end)

AddEventHandler('playerDropped', function()
    local src = source
    for id, speaker in pairs(Speakers) do
        if speaker.heldBy == src then
            speaker.heldBy = nil
            SyncSpeakerAndSlaves(id)
        end
    end
end)

local createRestricted = false
local deleteRestricted = false
local speakerRestricted = false

if Config.RequireAcePermissions then
    if Config.RequireAcePermissions.create ~= nil then
        createRestricted = Config.RequireAcePermissions.create
    end
    if Config.RequireAcePermissions.delete ~= nil then
        deleteRestricted = Config.RequireAcePermissions.delete
    end
    if Config.RequireAcePermissions.speaker ~= nil then
        speakerRestricted = Config.RequireAcePermissions.speaker
    end
end

RegisterCommand(Config.Commands.create or 'create-speaker', function(source, args, rawCommand)
    if source == 0 then return end
    TriggerClientEvent('5Mspeakers:client:openCreateDialog', source)
end, createRestricted)

RegisterCommand(Config.Commands.delete or 'delete-speaker', function(source, args, rawCommand)
    if source == 0 then return end
    TriggerClientEvent('5Mspeakers:client:triggerDelete', source)
end, deleteRestricted)

RegisterCommand(Config.Commands.speaker or 'speaker', function(source, args, rawCommand)
    if source == 0 then return end
    TriggerClientEvent('5Mspeakers:client:openClosestSpeaker', source)
end, speakerRestricted)


