sub init()
    m.ui_state = { open: true, skipKey: "" }
    m.amountToSeek = 0

    m.player = m.top
    m.player.enableUI = false ' disables default UI
    ' m.player.enableTrickPlay = false ' necessary?
    m.player.observeField("state", "onVideoPlayerStateChange")
    m.player.observeField("position", "onPositionChange")

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

sub onPositionChange()
    m.currentTime = m.player.position

    updateProgressBar()
end sub

sub onTimerFire()
    m.ui_state.open = false
end sub

sub onButtonPressTimerFire()
    m.buttonPressTimer.control = "stop"
    if m.amountToSeek = 0 return

    m.player.seek = m.currentTime + m.amountToSeek
    if m.player.seek < 0 then
        m.player.seek = 0
    end if

    m.amountToSeek = 0
end sub

' TODO: show UI marker on where skipping from
' TODO: show start and stop times, and also time to where amountToSeek will be
sub skip(amountToSkip = 10)
    m.player.control = "pause"
    m.amountToSeek = m.amountToSeek + amountToSkip
    m.buttonPressTimer.control = "stop"

    updateProgressBar(m.currentTime + m.amountToSeek)
end sub

sub onFastforwardRewindTimerFire()
    if m.ui_state.skipKey = "fastforward" then
        skip()
    else if m.ui_state.skipKey = "rewind" then
        skip(-10)
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
            m.ui_state.skipKey = "fastforward"
        end if

        if key = "rewind" then
            m.fastforwardRewindTimer.control = "start"
            m.ui_state.skipKey = "rewind"
        end if

        if key = "OK" or key = "play" then
            if m.fastforwardRewindTimer.control = "start" then
                m.fastforwardRewindTimer.control = "stop"
                m.ui_state.skipKey = ""
            end if

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
                if m.top.customPlayerEvent?.event = "VIDEO_ENDING" then
                    m.top.customPlayerEvent = { "status": "success", "event": "NEW_VIDEO_STARTING" }
                else
                    m.top.customPlayerEvent = { "status": "success", "event": "VIDEO_ENDING" }
                end if
            ' end if
            handled = true
        end if
    end if

    return handled
end function

sub onVideoPlayerStateChange(event)
    if type(event) = "roSGNodeEvent" AND event.getField() = "state"
        if m.player.state = "error" then
            print "VIDEO: error"
        ' else if m.videoPlayer.state = "playing"
        else if m.player.state = "finished" then
            print "VIDEO: DONE!"
        else
            print m.player.state
        end if
        m.timer.control = "start"
    end if
end sub

sub initProgressBar()
    m.progress = m.player.findNode("progress")
    m.progressBackground = m.player.findNode("progressBackground")
    m.progressFill = m.player.findNode("progressFill")

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

    if (m.ui_state.open) then
        m.progress.translation = [0, 1060]
        m.progressBackground.height = 20
        m.progressFill.height = 20
    else
        m.progress.translation = [0, 1075]
        m.progressBackground.height = 5
        m.progressFill.height = 5
    end if
end sub