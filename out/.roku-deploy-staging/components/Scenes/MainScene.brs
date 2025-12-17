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
end sub
