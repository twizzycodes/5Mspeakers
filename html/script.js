let isApiReady = false;
const players = {};
const pendingPlays = {};

window.onYouTubeIframeAPIReady = function() {
    isApiReady = true;
    for (const speakerId in pendingPlays) {
        if (pendingPlays[speakerId]) {
            createOrUpdatePlayer(speakerId, pendingPlays[speakerId]);
            delete pendingPlays[speakerId];
        }
    }
};

function createOrUpdatePlayer(speakerId, data) {
    const videoId = data.videoId;
    const initialVolume = Math.round((data.volume || 0.5) * 100);
    const startTime = data.time || 0;
    const isPaused = data.isPaused || false;

    if (players[speakerId]) {
        const player = players[speakerId];
        try {
            if (player.getVideoData && player.getVideoData().video_id === videoId) {
                if (data.volume !== undefined) {
                    player.setVolume(initialVolume);
                }
                if (isPaused) {
                    player.pauseVideo();
                } else {
                    player.playVideo();
                }
            } else {
                player.loadVideoById({
                    videoId: videoId,
                    startSeconds: startTime
                });
                player.setVolume(initialVolume);
                if (isPaused) {
                    player.pauseVideo();
                }
            }
        } catch (e) {
            destroyPlayer(speakerId);
            createPlayerInstance(speakerId, data);
        }
    } else {
        createPlayerInstance(speakerId, data);
    }
}

function createPlayerInstance(speakerId, data) {
    const container = document.getElementById('audio-container');
    const playerDiv = document.createElement('div');
    playerDiv.id = 'player_' + speakerId;
    playerDiv.className = 'yt-player-frame';
    container.appendChild(playerDiv);

    const initialVolume = Math.round((data.volume || 0.5) * 100);
    const startTime = data.time || 0;
    const isPaused = data.isPaused || false;

    players[speakerId] = new YT.Player('player_' + speakerId, {
        height: '200',
        width: '200',
        videoId: data.videoId,
        playerVars: {
            autoplay: isPaused ? 0 : 1,
            controls: 0,
            disablekb: 1,
            enablejsapi: 1,
            fs: 0,
            origin: window.location.origin,
            rel: 0,
            start: Math.floor(startTime)
        },
        events: {
            onReady: function(event) {
                event.target.setVolume(initialVolume);
                if (!isPaused) {
                    event.target.playVideo();
                }
            },
            onStateChange: function(event) {
                if (event.data === YT.PlayerState.ENDED) {
                    fetch(`https://${GetParentResourceName()}/songEnded`, {
                        method: 'POST',
                        headers: {
                            'Content-Type': 'application/json'
                        },
                        body: JSON.stringify({ speakerId: speakerId })
                    }).catch(() => {});
                }
            },
            onError: function(event) {
                fetch(`https://${GetParentResourceName()}/songError`, {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json'
                    },
                    body: JSON.stringify({ speakerId: speakerId, errorCode: event.data })
                }).catch(() => {});
            }
        }
    });
}

function destroyPlayer(speakerId) {
    if (players[speakerId]) {
        try {
            players[speakerId].stopVideo();
            players[speakerId].destroy();
        } catch (e) {}
        delete players[speakerId];
    }
    const elem = document.getElementById('player_' + speakerId);
    if (elem) {
        elem.remove();
    }
}

window.addEventListener('message', function(event) {
    const action = event.data.action;
    const speakerId = event.data.speakerId;

    if (action === 'play') {
        if (!isApiReady) {
            pendingPlays[speakerId] = event.data;
            return;
        }
        createOrUpdatePlayer(speakerId, event.data);
    } else if (action === 'updateVolume') {
        if (players[speakerId]) {
            try {
                const vol = Math.max(0, Math.min(100, Math.round(event.data.volume * 100)));
                players[speakerId].setVolume(vol);
            } catch (e) {}
        }
    } else if (action === 'pause') {
        if (players[speakerId]) {
            try {
                players[speakerId].pauseVideo();
            } catch (e) {}
        }
    } else if (action === 'resume') {
        if (players[speakerId]) {
            try {
                players[speakerId].playVideo();
            } catch (e) {}
        }
    } else if (action === 'seek') {
        if (players[speakerId]) {
            try {
                players[speakerId].seekTo(event.data.time || 0, true);
            } catch (e) {}
        }
    } else if (action === 'stop') {
        destroyPlayer(speakerId);
    } else if (action === 'stopAll') {
        for (const id in players) {
            destroyPlayer(id);
        }
    }
});

