sub init()
    m.SEEK_POSTER_WIDTH = 256
    m.SEEK_POSTER_HEIGHT = 144

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
    m.player.enableThumbnailTilesDuringLive = true ' enable trick/seek thumbnails for live
    ' m.player.enableTrickPlay = false ' necessary?
    m.player.observeField("content", "onContentChange")
    m.player.observeField("state", "onVideoPlayerStateChange")
    m.player.observeField("position", "onPositionChange")
    m.player.observeField("contentIndex", "onPlaylistIndexChange")
    m.player.observeField("thumbnailTiles", "onThumbnailTilesChange")

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
    initSeekThumbnails()
end sub

sub onThumbnailTilesChange(msg)
    print "msg:"
    print msg.getData()
    m.thumbnailData = msg.getData()
    selectedData = thumbnailEntryForTextureMapLimits(m.thumbnailData)
    if selectedData <> invalid
        m.selectedThumbnailData = selectedData
    else
        m.selectedThumbnailData = invalid
    end if
end sub

function thumbnailEntryForTextureMapLimits(thumbnailData as object) as object
    entry = invalid

    for each representation in thumbnailData
        thumbnailTiles = thumbnailData[representation]
        if entry = invalid AND thumbnailTiles[0].width < 2048 AND thumbnailTiles[0].htiles < 2048
            entry = thumbnailTiles
        else if thumbnailTiles[0].width < 2048 AND thumbnailTiles.htiles < 2048 AND thumbnailTiles[0].width * thumbnailTiles[0].htiles > entry.width * entry.htiles
            entry = thumbnailTiles
        end if
    end for

    return entry
end function

sub renderThumbnails(position)
    ' print "position: "; position

    if m.selectedThumbnailData <> invalid then
        discontinuityIndex = getDiscontinuityIndex(position)
        spriteIndex = getSpriteIndex(position, discontinuityIndex)

        ' print "discontinuityIndex: "; discontinuityIndex
        ' print "spriteIndex: "; spriteIndex

        if spriteIndex <> -1
            rowColumnIndexes = getRowColumnIndexes(position, discontinuityIndex, spriteIndex)
            rowIndex = rowColumnIndexes.rowIndex
            columnIndex = rowColumnIndexes.columnIndex

            posterWidth = m.SEEK_POSTER_WIDTH
            posterHeight = m.SEEK_POSTER_HEIGHT

            m.seekThumbGroup.clippingRect = { x: 0, y: 0, width: posterWidth, height: posterHeight }

            newTranslationX = -1 * (posterWidth * columnIndex)
            newTranslationY = -1 * (posterHeight * rowIndex)
            m.seekThumbImage.loadwidth = m.selectedThumbnailData[discontinuityIndex].width * m.selectedThumbnailData[discontinuityIndex].htiles
            m.seekThumbImage.loadheight = m.selectedThumbnailData[discontinuityIndex].height * m.selectedThumbnailData[discontinuityIndex].vtiles
            m.seekThumbImage.uri = m.selectedThumbnailData[discontinuityIndex].tiles[spriteIndex][0]
            m.seekThumbImage.width = posterWidth * m.selectedThumbnailData[discontinuityIndex].htiles
            m.seekThumbImage.height = posterHeight * m.selectedThumbnailData[discontinuityIndex].vtiles
            m.seekThumbImage.translation = [newTranslationX, newTranslationY]
        else
            m.seekThumbImage.uri = ""
        end if
    else
        m.seekThumbImage.uri = ""
    end if
end sub

function getSpriteIndex(position, discontinuityIndex as integer) as integer
    if position = invalid or position < 0 or position > m.player.duration then return -1

    for i = 0 to m.selectedThumbnailData[discontinuityIndex].tiles.count() - 1
        currentSpriteSheet = m.selectedThumbnailData[discontinuityIndex].tiles[i]
        nextSpriteSheet = invalid

        if (i + 1) < m.selectedThumbnailData[discontinuityIndex].tiles.count()
            nextSpriteSheet = m.selectedThumbnailData[discontinuityIndex].tiles[i + 1]
        end if

        currentSpriteSheetStartTime = currentSpriteSheet[1]
        if position >= currentSpriteSheetStartTime
            if nextSpriteSheet <> invalid
                nextSpriteSheetStartTime = nextSpriteSheet[1]
                if position < nextSpriteSheetStartTime
                    return i
                end if
            else
                return i
            end if
        else
            return i - 1
        end if
    end for
    
    return -1
end function

function getDiscontinuityIndex(position) as integer
    if position <> invalid then
        for i = 0 to m.selectedThumbnailData.count() - 1
            thumbnailData = m.selectedThumbnailData[i]
            if position >= thumbnailData.tiles[0][1] and position < thumbnailData.final_time
                return i
            end if
        end for
    end if

    return -1
end function

function getRowColumnIndexes(position as double, discontinuityIndex as integer, spriteIndex as integer) as object
    tileDuration = m.selectedThumbnailData[discontinuityIndex].duration / (m.selectedThumbnailData[discontinuityIndex].vtiles * m.selectedThumbnailData[discontinuityIndex].htiles)
    currentSpriteSheetStartTime = m.selectedThumbnailData[discontinuityIndex].tiles[spriteIndex][1]
    nextSpriteSheetStartTime = invalid

    rowIndex = 0
    columnIndex = 0
    exitForLoop = false

    for i = 0 to m.selectedThumbnailData[discontinuityIndex].vtiles - 1
        for j = 0 to m.selectedThumbnailData[discontinuityIndex].htiles - 1
            if position >= (currentSpriteSheetStartTime + (((i * m.selectedThumbnailData[discontinuityIndex].htiles) + j) * tileDuration))
                if position < (currentSpriteSheetStartTime + (((i * m.selectedThumbnailData[discontinuityIndex].htiles) + j + 1) * tileDuration))
                    rowIndex = i
                    columnIndex = j
                    exitForLoop = true
                    exit for
                end if
            end if
        end for

        if exitForLoop
            exit for
        end if
    end for

    return {
        rowIndex: rowIndex
        columnIndex: columnIndex
    }
end function

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
    m.loadingIcon.visible = "false"
    m.currentTime = m.player.position

    if (m.currentTime >= m.player.duration - 11) and m.player.customPlayerEvent?.event <> "VIDEO_ENDING" then
        m.player.customPlayerEvent = { "status": "success", "event": "VIDEO_ENDING" }
    end if

    updateProgressBar()
end sub

sub onPlaylistIndexChange()
    newIndex = m.player.contentIndex
    currentVideo = m.player.content.getChild(newIndex)

    if currentVideo <> invalid then
        print "PLAYING NEW VIDEO"
        m.player.thumbnailTiles = {}
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
        if m.player.state = "playing" then
            
        else if m.player.state = "error" then
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

sub initSeekThumbnails()
    m.seekThumbImage = m.player.findNode("seekThumbImage")
    m.seekThumbGroup = m.player.findNode("seekThumbGroup")
    m.seekThumbGroup.visible = false ' TODO: set to false once working

    m.trickPosition = 0
    m.trickOffset = 0
    m.trickInterval = 10 ' Interval in manifest will overwrite
end sub

sub showThumbnails(position, translation)
    if m.selectedThumbnailData = invalid then
        m.seekThumbGroup.visible = false
    else
        renderThumbnails(position)
        m.seekThumbGroup.visible = true
        m.seekThumbGroup.translation = translation
    end if
end sub

sub hideThumbnails()
    m.seekThumbGroup.visible = false
end sub

sub updateProgressBar(newValue = invalid)
    if newValue <> invalid then
        if newValue > m.player.duration then newValue = m.player.duration
        if newValue < 0 then newValue = 0

        m.progressFill.width = newValue * (m.progressWidth / m.player.duration)
        showThumbnails(newValue, [m.progressFill.width - 128, 860])
    else
        m.progressFill.width = m.currentTime * (m.progressWidth / m.player.duration)
    end if

    if m.amountToSeek <> 0 then
        
        if m.amountToSeek > 0 then
            m.progressLabel.text = "+" + stri(m.amountToSeek)
        else
            m.progressLabel.text = stri(m.amountToSeek)
        end if

        if m.seekThumbGroup.visible = false then
            m.progressLabel.translation = [m.progressFill.width - 80, -60]
        else
            m.progressLabel.translation = [m.progressFill.width - 80, -210]
        end if
        
    else
        m.progressLabel.translation = [860, -60]
        hideThumbnails()
    end if

    if (m.ui_state.open) then
        m.progress.translation = [0, 1020]
        m.progressBackground.height = 60
        m.progressFill.height = 60
        m.progressLabel.visible = true
    else
        m.progress.translation = [0, 1060]
        m.progressBackground.height = 20
        m.progressFill.height = 20
        m.progressLabel.visible = false
        hideThumbnails()
    end if
end sub