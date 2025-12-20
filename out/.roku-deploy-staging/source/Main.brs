'*************************************************************
'** Hello World example 
'** Copyright (c) 2015 Roku, Inc.  All rights reserved.
'** Use of the Roku Platform is subject to the Roku SDK Licence Agreement:
'** https://docs.roku.com/doc/developersdk/en-us
'*************************************************************

sub Main()
    print "in showChannelSGScreen"
    'Indicate this is a Roku SceneGraph application'
    screen = CreateObject("roSGScreen")
    m.port = CreateObject("roMessagePort")
    screen.setMessagePort(m.port)

    m.global = screen.getGlobalNode()
    m.global.addField("version", "string", false)
    m.global.version = getOSVersion()

    scene = screen.CreateScene("MainScene")
    screen.show()

    while(true)
        msg = wait(0, m.port)
        msgType = type(msg)
        if msgType = "roSGScreenEvent"
            if msg.isScreenClosed() then return
        end if
    end while
end sub

function getOsVersion() as string
  version = createObject("roDeviceInfo").GetVersion()

  major = Mid(version, 3, 1)
  minor = Mid(version, 5, 2)
  'build = Mid(version, 8, 5)

  return major + minor
end function