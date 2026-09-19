function OpenSpeakerMenu(speakerId)
    local speaker = ActiveSpeakers[speakerId]
    if not speaker then return end

    local currentTitle = 'None'
    if speaker.currentSong and speaker.currentSong.title then
        currentTitle = speaker.currentSong.title
    end

    local pauseIcon = speaker.isPaused and 'play' or 'pause'
    local pauseLabel = speaker.isPaused and 'Resume music' or 'Pause music'

    lib.registerContext({
        id = 'speaker_interaction_' .. speakerId,
        title = speaker.name or 'Speaker interaction',
        options = {
            {
                title = 'Play music',
                description = 'Youtube videos and playlists supported.',
                icon = 'play',
                onSelect = function()
                    local input = lib.inputDialog('Play Music', {
                        {
                            type = 'input',
                            label = 'YouTube URL or Video ID',
                            placeholder = 'https://www.youtube.com/watch?v=...',
                            required = true
                        }
                    })
                    if input and input[1] and input[1] ~= '' then
                        TriggerServerEvent('5Mspeakers:server:playMusic', speakerId, input[1])
                    end
                end
            },
            {
                title = 'Queue music',
                description = 'Add a song to the queue.',
                icon = 'list-ol',
                onSelect = function()
                    local input = lib.inputDialog('Queue Music', {
                        {
                            type = 'input',
                            label = 'YouTube URL or Video ID',
                            placeholder = 'https://www.youtube.com/watch?v=...',
                            required = true
                        }
                    })
                    if input and input[1] and input[1] ~= '' then
                        TriggerServerEvent('5Mspeakers:server:queueMusic', speakerId, input[1])
                    end
                end
            },
            {
                title = 'Next song',
                description = 'Play the next song in the queue.',
                icon = 'forward',
                onSelect = function()
                    TriggerServerEvent('5Mspeakers:server:nextSong', speakerId)
                end
            },
            {
                title = 'Pause/resume music',
                description = 'Pause or resume the current song.',
                icon = pauseIcon,
                onSelect = function()
                    TriggerServerEvent('5Mspeakers:server:togglePause', speakerId)
                end
            },
            {
                title = 'Change volume/range',
                description = 'Adjust music volume or range.',
                icon = 'volume-high',
                onSelect = function()
                    local currentVol = math.floor((speaker.volume or Config.DefaultVolume or 0.5) * 100)
                    local currentRng = math.floor(speaker.rangeDist or Config.DefaultRange or 25.0)

                    local input = lib.inputDialog('Change Volume & Range', {
                        {
                            type = 'slider',
                            label = 'Volume (%)',
                            default = currentVol,
                            min = 0,
                            max = 100,
                            step = 1
                        },
                        {
                            type = 'slider',
                            label = 'Range (Meters)',
                            default = currentRng,
                            min = math.floor(Config.MinRange or 5.0),
                            max = math.floor(Config.MaxRange or 60.0),
                            step = 1
                        }
                    })
                    if input then
                        local newVol = (input[1] or currentVol) / 100.0
                        local newRng = (input[2] or currentRng) * 1.0
                        TriggerServerEvent('5Mspeakers:server:setVolumeRange', speakerId, newVol, newRng)
                    end
                end
            },
            {
                title = 'Hold speaker',
                description = 'Carry the speaker around.',
                icon = 'hand',
                onSelect = function()
                    StartHoldingSpeaker(speakerId)
                end
            },
            {
                title = 'Store speaker',
                description = 'Stash the speaker away.',
                icon = 'trash-can',
                onSelect = function()
                    local confirm = lib.alertDialog({
                        header = 'Store Speaker',
                        content = 'Are you sure you want to store ' .. (speaker.name or 'this speaker') .. '?',
                        centered = true,
                        cancel = true
                    })
                    if confirm == 'confirm' then
                        TriggerServerEvent('5Mspeakers:server:storeSpeaker', speakerId)
                    end
                end
            },
            {
                title = 'Other',
                description = 'Manage queue, connect, other.',
                icon = 'gear',
                menu = 'speaker_settings_' .. speakerId
            }
        }
    })

    RegisterSpeakerSettingsMenu(speakerId)
    lib.showContext('speaker_interaction_' .. speakerId)
end

function RegisterSpeakerSettingsMenu(speakerId)
    local speaker = ActiveSpeakers[speakerId]
    if not speaker then return end

    local queueCount = (speaker.queue and #speaker.queue) or 0

    lib.registerContext({
        id = 'speaker_settings_' .. speakerId,
        title = 'Speaker settings',
        menu = 'speaker_interaction_' .. speakerId,
        options = {
            {
                title = 'Manage queue',
                description = 'Queue size: ' .. queueCount .. ' song(s). Play now, remove, etc.',
                icon = 'list-ol',
                arrow = true,
                onSelect = function()
                    OpenQueueManagementMenu(speakerId)
                end
            },
            {
                title = 'Connect',
                description = 'Connect speaker to a group.',
                icon = 'link',
                arrow = true,
                onSelect = function()
                    OpenConnectGroupingMenu(speakerId)
                end
            },
            {
                title = 'Rename speaker',
                description = 'Current name: ' .. (speaker.name or 'Unknown'),
                icon = 'tag',
                arrow = true,
                onSelect = function()
                    local input = lib.inputDialog('Rename Speaker', {
                        {
                            type = 'input',
                            label = 'New Speaker Name',
                            default = speaker.name or '',
                            required = true
                        }
                    })
                    if input and input[1] and input[1] ~= '' then
                        TriggerServerEvent('5Mspeakers:server:renameSpeaker', speakerId, input[1])
                    end
                end
            }
        }
    })
end

function OpenQueueManagementMenu(speakerId)
    local speaker = ActiveSpeakers[speakerId]
    if not speaker then return end

    local queue = speaker.queue or {}
    local options = {}

    if #queue == 0 then
        table.insert(options, {
            title = 'Queue is empty',
            description = 'No songs currently waiting in the queue.',
            disabled = true
        })
    else
        table.insert(options, {
            title = 'Clear queue (' .. #queue .. ' songs)',
            description = 'Remove all queued songs from this speaker.',
            icon = 'trash-can',
            onSelect = function()
                local confirm = lib.alertDialog({
                    header = 'Clear Queue',
                    content = 'Are you sure you want to clear all ' .. #queue .. ' tracks from the queue?',
                    centered = true,
                    cancel = true
                })
                if confirm == 'confirm' then
                    TriggerServerEvent('5Mspeakers:server:clearQueue', speakerId)
                end
            end
        })

        for index, item in ipairs(queue) do
            table.insert(options, {
                title = index .. '. ' .. (item.title or 'Unknown track'),
                description = 'Click to manage this track',
                arrow = true,
                onSelect = function()
                    lib.registerContext({
                        id = 'speaker_queue_item_' .. speakerId .. '_' .. index,
                        title = 'Track #' .. index,
                        menu = 'speaker_queue_' .. speakerId,
                        options = {
                            {
                                title = 'Play now',
                                description = 'Skip directly to this song.',
                                icon = 'play',
                                onSelect = function()
                                    TriggerServerEvent('5Mspeakers:server:playQueueIndex', speakerId, index)
                                end
                            },
                            {
                                title = 'Remove from queue',
                                description = 'Delete this song from the queue.',
                                icon = 'trash',
                                onSelect = function()
                                    TriggerServerEvent('5Mspeakers:server:removeQueueIndex', speakerId, index)
                                end
                            }
                        }
                    })
                    lib.showContext('speaker_queue_item_' .. speakerId .. '_' .. index)
                end
            })
        end
    end

    lib.registerContext({
        id = 'speaker_queue_' .. speakerId,
        title = 'Manage queue (' .. #queue .. ')',
        menu = 'speaker_settings_' .. speakerId,
        options = options
    })
    lib.showContext('speaker_queue_' .. speakerId)
end

function OpenConnectGroupingMenu(speakerId)
    local speaker = ActiveSpeakers[speakerId]
    if not speaker then return end

    local currentCoords = GetSpeakerCoords(speaker)
    if not currentCoords then return end

    local nearbySpeakers = {}
    local maxSearchDist = Config.NearbySearchRange or 50.0

    for otherId, otherSpeaker in pairs(ActiveSpeakers) do
        if otherId ~= speakerId then
            local otherCoords = GetSpeakerCoords(otherSpeaker)
            if otherCoords then
                local dist = #(currentCoords - otherCoords)
                if dist <= maxSearchDist then
                    table.insert(nearbySpeakers, {
                        id = otherId,
                        name = otherSpeaker.name or ('Speaker #' .. otherId),
                        dist = math.floor(dist)
                    })
                end
            end
        end
    end

    if #nearbySpeakers == 0 then
        Config.Notify('No nearby speakers found within range.', 'error')
        return
    end

    local currentGroup = speaker.groupedWith or {}
    local groupMap = {}
    for _, gid in ipairs(currentGroup) do
        groupMap[gid] = true
    end

    local selectOptions = {}
    for _, item in ipairs(nearbySpeakers) do
        table.insert(selectOptions, {
            value = item.id,
            label = item.name .. ' (' .. item.dist .. 'm)'
        })
    end

    local inputFields = {}
    local maxCount = math.min(#nearbySpeakers, Config.MaxGroupCount or 5)

    for i = 1, maxCount do
        local defaultVal = currentGroup[i] or nil
        table.insert(inputFields, {
            type = 'select',
            label = 'Linked Speaker ' .. i,
            options = selectOptions,
            default = defaultVal,
            clearable = true
        })
    end

    local result = lib.inputDialog('Connect Speakers (Up to ' .. (Config.MaxGroupCount or 5) .. ')', inputFields)
    if result then
        local selectedIds = {}
        local chosenMap = {}
        for _, selectedId in ipairs(result) do
            if selectedId and selectedId ~= '' and not chosenMap[selectedId] then
                chosenMap[selectedId] = true
                table.insert(selectedIds, selectedId)
            end
        end
        TriggerServerEvent('5Mspeakers:server:setSpeakerGroup', speakerId, selectedIds)
    end
end

