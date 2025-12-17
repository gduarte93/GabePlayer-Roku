sub init()
    m.top.setFocus(true)

    m.videoPlayer = m.top.findNode("videoPlayer")
    
    m.videoContent = CreateObject("roSGNode", "ContentNode")
    m.videoContent.url = "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_fmp4/master.m3u8"
    m.videoContent.streamformat = "hls"
    ' m.videoContent.url = "https://bitmovin-a.akamaihd.net/content/MI201109210084_1/mpds/f08e80da-bf1d-4e3d-8899-f0f6155f6efa.mpd"
    ' m.videoContent.streamformat = "dash"

    m.videoPlayer.content = m.videoContent
    m.videoPlayer.setFocus(true)
    m.videoPlayer.control = "play"

    ' For animating player size changes
    m.videoPlayer.scaleRotateCenter = [1920, 0]
    m.scaleAnim = CreateObject("roSGNode", "Animation")
    m.scaleAnim.duration = 0.5
    m.scaleAnim.easeFunction = "linear"
    m.interp = CreateObject("roSGNode", "Vector2DFieldInterpolator")
    m.interp.key = [0.0, 1.0]
    m.interp.keyValue = [[1.0, 1.0], [0.25, 0.25]]
    m.interp.fieldToInterp = "videoPlayer.scale"
    m.scaleAnim.appendChild(m.interp)

    m.videoPlayer.observeField("customPlayerEvent", "handleCustomPlayerEvent")
end sub

sub handleCustomPlayerEvent(event as Object)
    eventName = event.getData()?.event
    
    print eventName

    if eventName = "VIDEO_ENDING" then
        m.videoPlayer.translation = [-20, 20]
        m.scaleAnim.control = "stop"
        m.interp.reverse = false
        m.scaleAnim.control = "start"
    end if

    if eventName = "NEW_VIDEO_STARTING" then
        m.videoPlayer.translation = [0, 0]
        m.scaleAnim.control = "stop"
        m.interp.reverse = true
        m.scaleAnim.control = "start"
    end if
end sub
