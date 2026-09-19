<div align="center">

# 🔊 5Mspeakers

### A modern, immersive speaker system for FiveM

**Standalone • QBCore • QBox • ESX**

[![FiveM](https://img.shields.io/badge/FiveM-Resource-red?style=for-the-badge&logo=rockstar-games)](#)
[![Lua](https://img.shields.io/badge/Lua-5.4-blue?style=for-the-badge&logo=lua)](#)
[![ox_lib](https://img.shields.io/badge/ox__lib-required-orange?style=for-the-badge)](#requirements)
[![oxmysql](https://img.shields.io/badge/oxmysql-optional-green?style=for-the-badge)](#configuration)

<br>

<img src="https://img.shields.io/badge/Framework-Standalone%20%7C%20QBCore%20%7C%20QBox%20%7C%20ESX-5865F2?style=flat-square">

<br><br>

**Place • Play • Carry • Group • Mount**

<br>

[Features](#-features) •
[Installation](#-installation) •
[Configuration](#-configuration) •
[Commands](#-commands) •
[Dependencies](#-dependencies) •
[Support](#-support)

<br><br>

<video width="800" controls>
  <source src="https://cdn.discordapp.com/attachments/1546328045076488313/1550962469239787701/videospeakers.mp4?ex=6ab03ddc&is=6aaeec5c&hm=94ece797f86ce806a3bef2f2352c0fa344f8c66ba160d5da154f541a97f9ff21&" type="video/mp4">
  Your browser does not support the video tag.
</video>

</div>

---

## 📖 About

**5Mspeakers** is a fully configurable speaker system built for FiveM.

Place physical speakers around your server, play YouTube audio, adjust the hearing distance, group multiple speakers together, carry speakers around, mount them to vehicle trunks, and control them through `ox_target` or the `/speaker` command.

The resource is designed to work across multiple frameworks while keeping the majority of the system framework-independent.

---

## ✨ Features

<table>
<tr>
<td width="50%">

### 🎵 Audio

* YouTube URL playback
* YouTube video IDs
* Spatial audio
* Custom volume
* Custom hearing range
* Shared playback

</td>
<td width="50%">

### 🔊 Speakers

* Multiple speaker models
* Custom speaker names
* Physical world objects
* Pick up speakers
* Carry speakers
* Vehicle trunk attachment

</td>
</tr>

<tr>
<td>

### 🔗 Speaker Groups

* Group nearby speakers
* Up to 5 speakers by default
* Synchronized speaker systems
* Configurable group limits

</td>
<td>

### 🎯 Interaction

* `ox_target` support
* `/speaker` command
* `ox_lib` menus
* Configurable interaction distances
* Admin-controlled creation/deletion

</td>
</tr>
</table>

---

## 📦 Dependencies

### Required

* **[ox_lib](https://github.com/overextended/ox_lib)**

### Optional

* **[oxmysql](https://github.com/overextended/oxmysql)** — required only when persistent speaker storage is enabled.
* **[ox_target](https://github.com/overextended/ox_target)** — used for third-eye speaker interactions.

### Framework Support

| Framework           | Support |
| ------------------- | :-----: |
| Standalone          |    ✅    |
| QBCore              |    ✅    |
| QBox                |    ✅    |
| ESX                 |    ✅    |
| Automatic Detection |    ✅    |

---

# 🚀 Installation

## 1. Download

Place the resource inside your server's resources folder:

```text
resources/
└── 5Mspeakers/
```

## 2. Install Dependencies

Make sure `ox_lib` is installed and started before 5Mspeakers.

If using persistent speakers, also install `oxmysql`.

If using third-eye interactions, install `ox_target`.

## 3. Start the Resources

Add the following to your `server.cfg`:

```cfg
ensure ox_lib
ensure oxmysql
ensure ox_target
ensure 5Mspeakers
```

If you aren't using `oxmysql`:

```cfg
ensure ox_lib
ensure ox_target
ensure 5Mspeakers
```

## 4. Configure

Open:

```text
5Mspeakers/config.lua
```

and customize the resource to your server.

## 5. Restart

Restart your server or resource:

```cfg
restart 5Mspeakers
```

---

# ⚙️ Configuration

Almost everything you need to customize is located inside:

```text
config.lua
```

The configuration is intentionally kept in one place so server owners can easily modify the resource without editing the main scripts.

---

## 🧩 Framework

```lua
Config.Framework = 'auto'
```

Available options:

```text
auto
esx
qbcore
standalone
```

### `auto`

Automatically detects the framework being used.

### `esx`

For ESX servers.

### `qbcore`

For QBCore and compatible setups.

### `standalone`

For servers that do not use a framework.

---

## 💾 Database

```lua
Config.UseOxMySQL = true
```

Controls whether speakers are saved using `oxmysql`.

### Enabled

```lua
Config.UseOxMySQL = true
```

Placed speakers can persist between restarts.

### Disabled

```lua
Config.UseOxMySQL = false
```

Database persistence is disabled.

> `oxmysql` is only needed when this feature is enabled.

---

## 🎵 YouTube API

```lua
Config.YoutubeApiKey = ''
```

**A YouTube API key is not required for normal playback.**

You can leave this blank:

```lua
Config.YoutubeApiKey = ''
```

YouTube playback can still use supported URLs and video IDs.

The API key is optional and can be used for additional YouTube information such as metadata and playlist functionality.

---

# 🎛️ Commands

Commands can be renamed from the configuration.

```lua
Config.Commands = {
    create = 'create-speaker',
    delete = 'delete-speaker',
    speaker = 'speaker'
}
```

### `/create-speaker`

Opens the speaker creation interface.

You can select the speaker type, give it a name, and place it in the world.

### `/delete-speaker`

Deletes the closest speaker within the configured interaction distance.

### `/speaker`

Opens the interaction menu for the closest speaker.

This provides an alternative to using `ox_target`.

---

# 🔐 ACE Permissions

Command permissions can be controlled with:

```lua
Config.RequireAcePermissions = {
    create = true,
    delete = true,
    speaker = false
}
```

### Default

| Command           | ACE Required |
| ----------------- | :----------: |
| `/create-speaker` |       ✅      |
| `/delete-speaker` |       ✅      |
| `/speaker`        |       ❌      |

For example:

```cfg
add_ace group.admin command.create-speaker allow
add_ace group.admin command.delete-speaker allow
```

Allow everyone to use `/speaker`:

```cfg
add_ace builtin.everyone command.speaker allow
```

---

# 🔊 Audio Configuration

## Default Volume

```lua
Config.DefaultVolume = 0.5
```

Controls the default speaker volume.

Range:

```text
0.0 → 1.0
```

---

## Default Range

```lua
Config.DefaultRange = 15.0
```

Controls how far away players can hear the speaker by default.

---

## Range Limits

```lua
Config.MinRange = 3.0
Config.MaxRange = 35.0
```

These prevent players from setting the speaker range outside your configured limits.

For example:

```lua
Config.MinRange = 5.0
Config.MaxRange = 50.0
```

---

## Audio Update Rate

```lua
Config.SoundUpdateInterval = 200
```

Controls how frequently spatial audio updates.

The value is in milliseconds.

```text
100 = more frequent updates
200 = default
300 = less frequent updates
```

---

# 🔗 Speaker Groups

```lua
Config.MaxGroupCount = 5
```

Controls the maximum number of speakers that can be connected to a group.

Default:

```text
5 speakers
```

For example:

```lua
Config.MaxGroupCount = 10
```

would allow groups of up to 10 speakers.

---

# 📏 Interaction Distances

### Speaker Interaction

```lua
Config.InteractionDistance = 3.0
```

Maximum distance for interacting with a speaker.

### Vehicle Trunk

```lua
Config.TrunkAttachDistance = 3.0
```

Maximum distance required to attach a carried speaker to a vehicle trunk.

### Speaker Search

```lua
Config.NearbySearchRange = 50.0
```

Maximum distance used when searching for nearby speakers, such as when creating groups.

---

# 🔊 Speaker Models

Speakers are configured through:

```lua
Config.SpeakerModels
```

The default models are:

| Model                               | Name                |
| ----------------------------------- | ------------------- |
| `prop_speaker_05`                   | Wood Speaker 1      |
| `prop_speaker_03`                   | Wood Speaker 2      |
| `h4_prop_battle_club_speaker_array` | Small Floor Speaker |
| `h4_prop_battle_club_speaker_med`   | Medium Speaker      |
| `sf_prop_sf_speaker_stand_01a`      | Standing Speaker    |

---

## ➕ Adding a Speaker

You can add your own speaker models directly to the configuration:

```lua
{
    model = 'my_custom_speaker',
    label = 'Custom Speaker',

    holdOffset = vector3(0.0, 0.35, 0.0),
    holdRotation = vector3(0.0, 0.0, 0.0),

    trunkOffset = vector3(0.0, -0.15, 0.1),
    trunkRotation = vector3(0.0, 0.0, 0.0)
}
```

Each speaker has its own:

```text
model
label
holdOffset
holdRotation
trunkOffset
trunkRotation
```

This allows different models to have completely different carrying and vehicle positions.

---

# 🧳 Carry System

The carrying system is configured with:

```lua
Config.Carry = {
    animDict = 'anim@heists@box_carry@',
    animClip = 'idle',
    animFlag = 49,
    bone = 60309
}
```

This controls the animation and bone used when carrying a speaker.

---

# 🔔 Notifications

Notifications use `ox_lib` by default:

```lua
Config.Notify = function(message, notifyType)
    lib.notify({
        title = 'Speaker System',
        description = message,
        type = notifyType or 'info'
    })
end
```

You can replace this function with your own notification system if your server uses something different.

---

# 🎯 Interactions

Speakers can be controlled using either:

### `ox_target`

Third-eye a speaker to access its interaction menu.

### `/speaker`

Use:

```text
/speaker
```

to interact with the closest speaker.

The player must be within:

```lua
Config.InteractionDistance
```

---

# 🚗 Vehicle Speakers

One of the main features of 5Mspeakers is the ability to turn speakers into mobile audio systems.

A player can:

```text
Pick Up Speaker
       ↓
Carry Speaker
       ↓
Walk to Vehicle
       ↓
Attach to Trunk
       ↓
Continue Playback
```

Each speaker model has configurable trunk positioning:

```lua
trunkOffset = vector3(0.0, -0.15, 0.1)
trunkRotation = vector3(0.0, 0.0, 0.0)
```

---

# 🗂️ Resource Structure

```text
5Mspeakers/
│
├── client/
├── server/
├── html/
│
├── config.lua
├── fxmanifest.lua
├── video.mp4
└── README.md
```

> Your resource structure may differ depending on the version you're using.

---

# 🛠️ Troubleshooting

### Speaker doesn't play audio

Check:

* The YouTube URL/video ID is valid.
* Your FiveM client has audio enabled.
* You are within the configured speaker range.
* The speaker volume is above `0`.
* `ox_lib` is running correctly.

### `/create-speaker` doesn't work

Check your ACE permissions:

```cfg
add_ace group.admin command.create-speaker allow
```

and:

```lua
Config.RequireAcePermissions.create = true
```

### Speakers disappear after restart

If persistence is enabled:

```lua
Config.UseOxMySQL = true
```

make sure `oxmysql` is running before 5Mspeakers.

### Speaker positioning is incorrect

Adjust:

```lua
holdOffset
holdRotation
trunkOffset
trunkRotation
```

for the affected speaker model.

---

# 📄 License

Please refer to the license included with the resource for usage and redistribution terms.

---

# 💬 Support

If you encounter an issue, please provide:

```text
FiveM Artifact:
Framework:
5Mspeakers Version:
ox_lib Version:
oxmysql Version:
ox_target Version:
Server Console Error:
F8 Error:
Description:
```

This makes troubleshooting significantly easier.

---

<div align="center">

# 🔊 5Mspeakers

**A better way to bring music into your FiveM world.**

[⬆ Back to Top](#-5mspeakers)

</div>
