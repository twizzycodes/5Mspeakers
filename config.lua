Config = {}

-- Framework Detection: 'auto', 'esx', 'qbcore', or 'standalone'
Config.Framework = 'auto'

-- Enable oxmysql to save placed speakers permanently across server restarts
Config.UseOxMySQL = true

-- YouTube Data API v3 Key (Optional, used to automatically fetch video titles, durations, and load full YouTube playlists)
-- If left blank, YouTube playback still works by parsing direct URLs and video IDs
Config.YoutubeApiKey = ''

-- Server Commands
Config.Commands = {
    create = 'create-speaker',
    delete = 'delete-speaker',
    speaker = 'speaker'
}

-- Command Permissions & ACE Restrictions
-- If set to true, only players/groups with the matching ACE permission can use the command
-- Add to your permissions.cfg or server.cfg:
--   add_ace group.admin command.create-speaker allow
--   add_ace group.admin command.delete-speaker allow
--   add_ace builtin.everyone command.speaker allow
Config.RequireAcePermissions = {
    create = true,   -- Restrict /create-speaker to admins (command.create-speaker)
    delete = true,   -- Restrict /delete-speaker to admins (command.delete-speaker)
    speaker = false  -- Set to false to allow everyone to use /speaker, or true for admins only
}

-- Default Audio Settings
Config.DefaultVolume = 0.5    -- Default volume (0.0 to 1.0)
Config.DefaultRange = 15.0    -- Default hearing distance in meters
Config.MinRange = 3.0         -- Minimum allowed hearing distance
Config.MaxRange = 35.0        -- Maximum allowed hearing distance
Config.SoundUpdateInterval = 200 -- Spatial audio update rate in milliseconds

-- Maximum number of nearby speakers that can be linked to a single master group
Config.MaxGroupCount = 5

-- Distance check limits
Config.InteractionDistance = 3.0   -- Max distance to interact with or target a speaker
Config.TrunkAttachDistance = 3.0   -- Max distance from a vehicle boot/trunk to attach a carried speaker
Config.NearbySearchRange = 50.0    -- Max distance when scanning nearby speakers for grouping

-- Available Speaker Models and Labels
Config.SpeakerModels = {
    {
        model = 'prop_speaker_05',
        label = 'Wood Speaker 1',
        holdOffset = vector3(0.0, 0.35, 0.0),
        holdRotation = vector3(0.0, 0.0, 0.0),
        trunkOffset = vector3(0.0, -0.15, 0.1),
        trunkRotation = vector3(0.0, 0.0, 0.0)
    },
    {
        model = 'prop_speaker_03',
        label = 'Wood speaker 2',
        holdOffset = vector3(0.0, 0.35, 0.0),
        holdRotation = vector3(0.0, 0.0, 0.0),
        trunkOffset = vector3(0.0, -0.15, 0.1),
        trunkRotation = vector3(0.0, 0.0, 0.0)
    },
    {
        model = 'h4_prop_battle_club_speaker_array',
        label = 'Small Floor Speaker',
        holdOffset = vector3(0.0, 0.35, -0.1),
        holdRotation = vector3(0.0, 0.0, 0.0),
        trunkOffset = vector3(0.0, -0.15, 0.05),
        trunkRotation = vector3(0.0, 0.0, 0.0)
    },
    {
        model = 'h4_prop_battle_club_speaker_med',
        label = 'Medium Speaker',
        holdOffset = vector3(0.0, 0.38, -0.2),
        holdRotation = vector3(0.0, 0.0, 0.0),
        trunkOffset = vector3(0.0, -0.2, 0.05),
        trunkRotation = vector3(0.0, 0.0, 0.0)
    },
    {
        model = 'sf_prop_sf_speaker_stand_01a',
        label = 'Standing Speaker',
        holdOffset = vector3(0.0, 0.35, -0.7),
        holdRotation = vector3(0.0, 0.0, 0.0),
        trunkOffset = vector3(0.0, -0.2, -0.2),
        trunkRotation = vector3(0.0, 0.0, 0.0)
    }
}

-- Carrying Animation & Attachment settings
Config.Carry = {
    animDict = 'anim@heists@box_carry@',
    animClip = 'idle',
    animFlag = 49,
    bone = 60309 -- Ped right hand bone
}

-- Notification & Notification Types
Config.Notify = function(message, notifyType)
    lib.notify({
        title = 'Speaker System',
        description = message,
        type = notifyType or 'info'
    })
end

