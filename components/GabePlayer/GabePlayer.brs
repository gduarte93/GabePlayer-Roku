sub init()
    m.THEMES = {
        hulu: {
            color: "0x1CE783"
        },
        espn: {
            color: "0xFF0000"
        },
        disney: {
            color: "0x55CCD4"
        }
    }
    m.VIDEO_FORMAT_REGEX = CreateObject("roRegex", "\.m3u8$|\.mpd$", "i")
    m.VIDEO_EXT_TO_STREAMFORMAT = {
        ".m3u8" : "hls",
        ".mpd"  : "dash"
    }

    m.ui_state = { open: true, skipKey: "" }
    m.amountToSeek = 0

    m.player = m.top
    m.player.enableUI = false ' disables default UI
    ' m.player.enableTrickPlay = false ' necessary?
    m.player.observeField("content", "onContentChange")
    m.player.observeField("state", "onVideoPlayerStateChange")
    m.player.observeField("position", "onPositionChange")
    m.player.observeField("contentIndex", "onPlaylistIndexChange")

    m.loadingIcon = m.player.findNode("loadingIcon")
    m.loadingIcon.visible = "false"

    ' For progress bar show/hide duration, after 5 seconds of inactivity hide the progress bar
    m.timer = CreateObject("roSGNode", "Timer")
    m.timer.duration = 5.0
    m.timer.repeat = true
    m.timer.observeField("fire", "onTimerFire")

    m.buttonPressTimer = CreateObject("roSGNode", "Timer")
    m.buttonPressTimer.duration = 1.5
    m.buttonPressTimer.repeat = true
    m.buttonPressTimer.observeField("fire", "onButtonPressTimerFire")

    m.fastforwardRewindTimer = CreateObject("roSGNode", "Timer")
    m.fastforwardRewindTimer.duration = 0.5
    m.fastforwardRewindTimer.repeat = true
    m.fastforwardRewindTimer.observeField("fire", "onFastforwardRewindTimerFire")

    initProgressBar()
end sub

' Sets streamformat dynamically based on url extension (e.g. m3u8 -> hls, mpd -> dash)
sub onContentChange()
    contentChildren = m.player.content.getChildren(-1, 0)

    for each video in contentChildren
        data = video.getFields()

        matches = m.VIDEO_FORMAT_REGEX.match(data.url)

        if matches <> invalid and matches.Count() > 0 then
            data.streamformat = m.VIDEO_EXT_TO_STREAMFORMAT[matches[0]]
        end if

        video.setFields(data)
    end for
end sub

sub onConfigChange()
    progressBarColor = "0xFF0000"

    theme = m.THEMES[m.player.config?.theme]

    if theme <> invalid
        progressBarColor = theme.color
    end if

    m.progressBackground.color = progressBarColor
    m.progressFill.color = progressBarColor
    m.progressLabel.color = progressBarColor
end sub

sub play()
    m.progressLabel.text = "||"
    if m.player.state = "paused" then
        m.player.control = "resume"
    else
        m.player.control = "play"
    end if
end sub

sub pause()
    m.progressLabel.text = ">"
    m.player.control = "pause"
end sub

sub onPositionChange()
    m.currentTime = m.player.position

    if (m.currentTime >= m.player.duration - 30) and m.player.customPlayerEvent?.event <> "VIDEO_ENDING" then
        m.player.customPlayerEvent = { "status": "success", "event": "VIDEO_ENDING" }
    end if

    updateProgressBar()
end sub

sub onPlaylistIndexChange()
    newIndex = m.player.contentIndex
    currentVideo = m.player.content.getChild(newIndex)

    if currentVideo <> invalid then
        print "PLAYING NEW VIDEO"
        m.player.customPlayerEvent = { "status": "success", "event": "NEW_VIDEO_STARTING" }
    else
        print "INVALID nextVideo"
    end if
end sub

sub onTimerFire()
    m.ui_state.open = false
end sub

sub onButtonPressTimerFire()
    m.buttonPressTimer.control = "stop"
    if m.amountToSeek = 0 return

    if m.currentTime <> invalid
        m.player.seek = m.currentTime + m.amountToSeek
    end if
    if m.player.seek < 0 then
        m.player.seek = 0
    end if

    m.amountToSeek = 0
end sub

' TODO: show UI marker on where skipping from
' TODO: show start and stop times, and also time to where amountToSeek will be
sub skip(amountToSkip = 10)
    pause()
    m.amountToSeek = m.amountToSeek + amountToSkip
    m.buttonPressTimer.control = "stop"

    if m.currentTime <> invalid then
        updateProgressBar(m.currentTime + m.amountToSeek)
    end if
end sub

sub onFastforwardRewindTimerFire()
    if m.ui_state.skipKey = "fastforward" then
        skip()
    else if m.ui_state.skipKey = "fastforward2" then
        skip(20)
    else if m.ui_state.skipKey = "fastforward3" then
        skip(40)
    else if m.ui_state.skipKey = "rewind" then
        skip(-10)
    else if m.ui_state.skipKey = "rewind2" then
        skip(-20)
    else if m.ui_state.skipKey = "rewind3" then
        skip(-40)
    end if
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    handled = false

    ' Commenting out since will just use OK/play buttons to resume playback from skipping
    ' m.buttonPressTimer.control = "start" 

    if press then

        if m.ui_state.skipKey = "" then
            if key = "right" then
                skip()
            end if

            if key = "left" then
                skip(-10)
            end if
        end if

        if key = "fastforward" then
            m.fastforwardRewindTimer.control = "start"

            if m.ui_state.skipKey = "fastforward" then
                m.ui_state.skipKey = "fastforward2"
            else if m.ui_state.skipKey = "fastforward2" or m.ui_state.skipKey = "fastforward3" then
                m.ui_state.skipKey = "fastforward3"
            else
                m.ui_state.skipKey = "fastforward"
            end if
        end if

        if key = "rewind" then
            m.fastforwardRewindTimer.control = "start"

            if m.ui_state.skipKey = "rewind" then
                m.ui_state.skipKey = "rewind2"
            else if m.ui_state.skipKey = "rewind2" or m.ui_state.skipKey = "rewind3" then
                m.ui_state.skipKey = "rewind3"
            else
                m.ui_state.skipKey = "rewind"
            end if
        end if

        if key = "OK" or key = "play" then
            m.ui_state.skipKey = ""

            if m.fastforwardRewindTimer.control = "start" then
                m.fastforwardRewindTimer.control = "stop"
            end if

            if m.player.state = "playing" then pause()
            if m.player.state = "paused" then play()

            m.ui_state.open = true

            updateProgressBar()
            onButtonPressTimerFire()
        end if

        if key = "back" then
            if m.amountToSeek <> 0 then
                m.fastforwardRewindTimer.control = "stop"
                m.ui_state.skipKey = ""
                m.amountToSeek = 0
                m.player.seek = m.currentTime
            end if
        end if

        if key = "right" or key = "left" or key = "OK" or key = "up" or key = "replay" or key = "play" or key = "rewind" or key = "fastforward" then
            m.ui_state.open = true

            ' reset timer while pressing keys
            m.timer.control = "stop"
            m.timer.control = "start"
            handled = true
        end if

        if m.ui_state.open and (key = "back" or key = "down") then
            m.ui_state.open = false

            m.timer.control = "stop"
            m.timer.control = "start"
            handled = true
        end if

        ' Testing player scale/size change
        if key = "down" then
            ' if m.top.customPlayerEvent <> invalid then
                ' if m.player.customPlayerEvent?.event = "VIDEO_ENDING" then
                '     m.player.customPlayerEvent = { "status": "success", "event": "NEW_VIDEO_STARTING" }
                ' else
                '     m.player.customPlayerEvent = { "status": "success", "event": "VIDEO_ENDING" }
                ' end if
            ' end if
            ' handled = true
        end if
    end if

    return handled
end function

sub onVideoPlayerStateChange(event)
    if type(event) = "roSGNodeEvent" AND event.getField() = "state"
        print "m.player.state:"; m.player.state
        if m.player.state = "error" then
            ' TODO: display error label
        else if m.player.state = "finished" then
            m.player.visible = "false"
        else if m.player.state = "buffering" then
            m.loadingIcon.visible = "true"
        else
            m.loadingIcon.visible = "false"
        end if
        m.timer.control = "start"
    end if
end sub

sub initProgressBar()
    m.progress = m.player.findNode("progress")
    m.progressBackground = m.player.findNode("progressBackground")
    m.progressFill = m.player.findNode("progressFill")
    m.progressLabel = m.player.findNode("progressLabel")

    m.progressWidth = m.progressBackground.width
end sub

sub updateProgressBar(newValue = invalid)
    if newValue <> invalid then
        if newValue > m.player.duration then newValue = m.player.duration
        if newValue < 0 then newValue = 0

        m.progressFill.width = newValue * (m.progressWidth / m.player.duration)
    else
        m.progressFill.width = m.currentTime * (m.progressWidth / m.player.duration)
    end if

    if m.amountToSeek <> 0 then
        
        if m.amountToSeek > 0 then
            m.progressLabel.text = "+" + stri(m.amountToSeek)
        else
            m.progressLabel.text = stri(m.amountToSeek)
        end if
    end if

    if (m.ui_state.open) then
        m.progress.translation = [0, 1060]
        m.progressBackground.height = 20
        m.progressFill.height = 20
        m.progressLabel.visible = true
    else
        m.progress.translation = [0, 1075]
        m.progressBackground.height = 5
        m.progressFill.height = 5
        m.progressLabel.visible = false
    end if
end sub