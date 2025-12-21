sub init()
    m.top.setFocus(true)

    m.videoPlayer = m.top.findNode("videoPlayer")
    ' m.videoPlayer.config = { theme: "hulu" }
    m.videoPlayer.config = { theme: "espn" }
    ' m.videoPlayer.config = { theme: "disney" }
    
    m.videoContent = CreateObject("roSGNode", "ContentNode")

    videoList = [
        {
            url   : "https://dash.akamaized.net/akamai/bbb_30fps/bbb_with_multiple_tiled_thumbnails.mpd",
            title : "DASH Video 1"
            description : "This video has thumbnail data in the mpd to allow trick play seeking with images"
        },
        {
            url   : "https://raw.githubusercontent.com/rokudev/samples/master/media/TrickPlayThumbnailsHLS/master_withthumbs.m3u8",
            title : "HLS Video 1"
            description : "This video does not have thumbnail data in the m3u8, so no images while seeking"
        },
        {
            url   : "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_fmp4/master.m3u8",
            title : "HLS Video 2"
            description : "Has closed caption data"
        },
        {
            url   : "https://bitmovin-a.akamaihd.net/content/MI201109210084_1/mpds/f08e80da-bf1d-4e3d-8899-f0f6155f6efa.mpd",
            title : "DASH Video 2"
            description : "A second DASH video"
        }
    ]

    for each video in videoList
        child = CreateObject("roSGNode", "ContentNode")
        child.setFields(video)
        m.videoContent.appendChild(child)
    end for

    ' m.videoContent.url = "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_fmp4/master.m3u8"
    ' m.videoContent.streamformat = "hls"
    ' m.videoContent.url = "https://bitmovin-a.akamaihd.net/content/MI201109210084_1/mpds/f08e80da-bf1d-4e3d-8899-f0f6155f6efa.mpd"
    ' m.videoContent.streamformat = "dash"

    m.videoPlayer.content = m.videoContent
    m.videoPlayer.contentIsPlaylist = true
    m.videoPlayer.setFocus(true)
    m.videoPlayer.callFunc("play")

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

    if eventName = "VIDEO_ENDING" or eventName = "VIDEO_MINIMIZE" then
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
