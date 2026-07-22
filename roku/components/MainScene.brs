sub init()
    m.video = m.top.findNode("video")
    m.status = m.top.findNode("videoStatus")
    m.video.setFocus(true)
    m.isPaused = false
    loadPlaylist()
end sub

sub loadPlaylist()
    m.status.text = "Loading video rotation..."
    appInfo = CreateObject("roAppInfo")
    playlistUrl = appInfo.GetValue("playlist_url")

    if playlistUrl = invalid or playlistUrl = "" or Instr(1, playlistUrl, "YOUR_HOME_ASSISTANT_IP") > 0
        m.status.text = "Edit playlist_url in the Roku manifest first."
        return
    end if

    m.task = CreateObject("roSGNode", "PlaylistTask")
    m.task.url = playlistUrl
    m.task.observeField("result", "onPlaylistReady")
    m.task.observeField("errorMessage", "onPlaylistError")
    m.task.control = "run"
end sub

sub onPlaylistReady()
    data = m.task.result
    if data = invalid or data.videos = invalid or data.videos.Count() = 0
        m.status.text = "No videos are published. Add MP4 files and publish a rotation."
        return
    end if

    playlist = CreateObject("roSGNode", "ContentNode")
    for each item in data.videos
        child = playlist.CreateChild("ContentNode")
        child.title = item.title
        child.url = item.url
        if item.streamFormat <> invalid
            child.streamFormat = item.streamFormat
        else
            child.streamFormat = "mp4"
        end if
    end for

    m.video.control = "stop"
    m.video.content = playlist
    m.video.contentIsPlaylist = true
    m.video.loop = true
    m.video.control = "play"
    m.isPaused = false
    m.status.text = data.videos.Count().ToStr() + " videos loaded • rotation: " + data.mode
end sub

sub onPlaylistError()
    m.status.text = m.task.errorMessage
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if not press then return false

    if key = "OK"
        if m.isPaused
            m.video.control = "resume"
            m.isPaused = false
            m.status.text = "Playing"
        else
            m.video.control = "pause"
            m.isPaused = true
            m.status.text = "Paused"
        end if
        return true
    else if key = "right"
        m.video.control = "skipcontent"
        m.status.text = "Skipping to next video..."
        return true
    else if key = "options"
        loadPlaylist()
        return true
    end if

    return false
end function
