sub Main()
    print "[Roughstock] Main() start"
    screen = CreateObject("roSGScreen")
    m.port = CreateObject("roMessagePort")
    screen.setMessagePort(m.port)

    ' Scene name must match component file (MainScene.xml -> "MainScene")
    print "[Roughstock] Creating MainScene"
    scene = screen.CreateScene("MainScene")
    screen.show()
    print "[Roughstock] Screen shown"

    while true
        msg = wait(0, m.port)
        msgType = type(msg)
        if msgType = "roSGScreenEvent" then
            if msg.isScreenClosed() then
                return
            end if
        end if
    end while
end sub
