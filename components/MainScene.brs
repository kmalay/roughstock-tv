' MainScene.brs - USB discovery, mode selection, slideshow, and video playback

sub init()
    m.modeList = m.top.findNode("modeList")
    m.homeList = m.top.findNode("homeList")
    m.messageLabel = m.top.findNode("messageLabel")
    m.settingsGroup = m.top.findNode("settingsGroup")
    m.settingsList = m.top.findNode("settingsList")
    m.playbackGroup = m.top.findNode("playbackGroup")
    m.slidePoster = m.top.findNode("slidePoster")
    m.playbackVideo = m.top.findNode("playbackVideo")
    m.slideTimer = m.top.findNode("slideTimer")
    m.fadeOutAnim = m.top.findNode("fadeOutAnim")
    m.fadeInAnim = m.top.findNode("fadeInAnim")
    m.zoomInAnim = m.top.findNode("zoomInAnim")
    m.slideInAnim = m.top.findNode("slideInAnim")
    m.timerGroup = m.top.findNode("timerGroup")
    m.timerSettingsGroup = m.top.findNode("timerSettingsGroup")
    m.timerSettingsList = m.top.findNode("timerSettingsList")
    m.timerCountdownLabel = m.top.findNode("timerCountdownLabel")
    m.timerPhaseLabel = m.top.findNode("timerPhaseLabel")
    m.timerRoundLabel = m.top.findNode("timerRoundLabel")
    m.timerNextRoundLabel = m.top.findNode("timerNextRoundLabel")
    m.timerClockLabel = m.top.findNode("timerClockLabel")
    m.timerSponsorGroup = m.top.findNode("timerSponsorGroup")
    m.timerAnnouncementsLabel = m.top.findNode("timerAnnouncementsLabel")
    m.timerTick = m.top.findNode("timerTick")

    m.photoPaths = []
    m.videoPaths = []
    m.slideIndex = 0
    m.videoIndex = 0
    m.mode = "" ' "photos" | "videos" | "both"
    m.bothPhotoCount = 5
    m.bothPhotoIndex = 0
    m.displayOrder = [] ' shuffled indices when playbackOrder=shuffle

    loadSettings()
    loadTimerSettings()
    discoverUSB()
    showHomeList()
end sub

sub setScreenSaverSuppressed(suppress as boolean)
    ' Toggle screensaver behavior through Video node controls.
    ' Some Roku runtimes throw on interface introspection, so avoid hasField checks.
    if m.playbackVideo <> invalid then
        m.playbackVideo.disableScreenSaver = suppress
        m.playbackVideo.enableScreenSaverWhilePlaying = not suppress
    end if
end sub

' Try ext1 and ext2 for photos/ and videos/; fill m.photoPaths and m.videoPaths
sub discoverUSB()
    m.photoPaths = []
    m.videoPaths = []
    photoExts = { ".jpg": true, ".jpeg": true, ".png": true, ".gif": true }
    videoExts = { ".mp4": true, ".mkv": true, ".mov": true }

    ' Use capital "Photos" and "Videos" so Poster can load from USB (lowercase path can fail)
    for each prefix in ["ext1:", "ext2:"]
        base = prefix + "/"
        listPhotos(base + "Photos/", photoExts)
        listVideos(base + "Videos/", videoExts)
    end for

    ' Sort so playback order is deterministic
    m.photoPaths.Sort()
    m.videoPaths.Sort()
end sub

' List image files from a directory into m.photoPaths (skip macOS ._ resource-fork files)
sub listPhotos(dirPath, allowedExts)
    list = listDirectory(dirPath)
    if list = invalid then return
    for each name in list
        if Left(name, 2) = "._" then continue for
        ext = LCase(right(name, 4))
        if len(name) >= 5 then
            ext5 = LCase(right(name, 5))
            if allowedExts[ext5] <> invalid then ext = ext5
        end if
        if allowedExts[ext] <> invalid then
            m.photoPaths.Push(dirPath + name)
        end if
    end for
end sub

' List video files from a directory into m.videoPaths (skip macOS ._ resource-fork files)
sub listVideos(dirPath, allowedExts)
    list = listDirectory(dirPath)
    if list = invalid then return
    for each name in list
        if Left(name, 2) = "._" then continue for
        ext = LCase(right(name, 4))
        if allowedExts[ext] <> invalid then
            m.videoPaths.Push(dirPath + name)
        end if
    end for
end sub

' Return array of file/dir names in the given path, or invalid if not accessible or empty.
' Empty or missing Photos/Videos folders do not cause errors; listPhotos/listVideos just add nothing.
' Must stay render-thread safe in SceneGraph, so use MatchFiles only.
function listDirectory(path as string) as object
    ' Render-thread safe directory enumeration
    matched = MatchFiles(path, "*")
    if matched <> invalid and matched.Count() > 0 then
        result = []
        for each p in matched
            ' Strip path to get filename only
            name = p
            idx = Instr(1, name, "/")
            while idx > 0
                name = Mid(name, idx + 1)
                idx = Instr(1, name, "/")
            end while
            result.Push(name)
        end for
        return result
    end if
    return invalid
end function

sub showNoUSBMessage()
    m.homeList.visible = false
    m.modeList.visible = false
    m.messageLabel.visible = true
    m.messageLabel.text = "Insert a USB drive with 'Photos' and 'Videos' folders at the root, then restart the channel."
end sub

sub showHomeList()
    m.messageLabel.visible = false
    m.settingsGroup.visible = false
    m.modeList.visible = false
    m.playbackGroup.visible = false
    m.timerGroup.visible = false
    m.timerSettingsGroup.visible = false
    m.homeList.visible = true
    content = CreateObject("roSGNode", "ContentNode")
    content.AppendChild(createModeItem("Scrolling photos & videos", "media"))
    content.AppendChild(createModeItem("Round timer", "timer"))
    m.homeList.content = content
    m.homeList.unobserveField("itemSelected")
    m.homeList.observeField("itemSelected", "onHomeSelected")
    m.homeList.setFocus(true)
end sub

sub onHomeSelected()
    if m.homeList.itemSelected = invalid then return
    selectedIndex = m.homeList.itemSelected
    content = m.homeList.content
    if content = invalid or selectedIndex < 0 or selectedIndex >= content.getChildCount() then return
    item = content.getChild(selectedIndex)
    choice = item.id

    m.homeList.visible = false

    if choice = "media" then
        discoverUSB()
        if m.photoPaths.Count() = 0 and m.videoPaths.Count() = 0 then
            showNoUSBMessage()
        else
            showModeList()
        end if
    else if choice = "timer" then
        startTimerMode()
    end if
end sub

sub showModeList()
    m.messageLabel.visible = false
    m.settingsGroup.visible = false
    m.timerGroup.visible = false
    m.timerSettingsGroup.visible = false
    m.homeList.visible = false
    m.modeList.visible = true
    content = CreateObject("roSGNode", "ContentNode")
    content.AppendChild(createModeItem("Photos only", "photos"))
    content.AppendChild(createModeItem("Videos only", "videos"))
    content.AppendChild(createModeItem("Both (photos + videos)", "both"))
    content.AppendChild(createModeItem("Settings", "settings"))
    m.modeList.content = content
    m.modeList.observeField("itemSelected", "onModeSelected")
    m.modeList.setFocus(true)
end sub

function createModeItem(title as string, id as string) as object
    item = CreateObject("roSGNode", "ContentNode")
    item.title = title
    item.id = id
    return item
end function

sub onModeSelected()
    if m.modeList.itemSelected = invalid then return
    selectedIndex = m.modeList.itemSelected
    content = m.modeList.content
    if content = invalid or selectedIndex < 0 or selectedIndex >= content.getChildCount() then return
    item = content.getChild(selectedIndex)
    m.mode = item.id

    m.modeList.visible = false
    m.playbackGroup.visible = true

    if m.mode = "photos" then
        startPhotoPlayback()
    else if m.mode = "videos" then
        startVideoPlayback()
    else if m.mode = "both" then
        startBothMode()
    else if m.mode = "settings" then
        m.playbackGroup.visible = false
        m.modeList.visible = false
        showSettings()
    end if
end sub

' --- Settings (registry) ---
sub loadSettings()
    sec = CreateObject("roRegistrySection", "RoughstockSettings")
    if sec.Exists("displayMode") then m.displayMode = sec.Read("displayMode") else m.displayMode = "slideshow"
    if sec.Exists("slideSeconds") then m.slideSeconds = Val(sec.Read("slideSeconds"), 10) else m.slideSeconds = 10
    if sec.Exists("playbackOrder") then m.playbackOrder = sec.Read("playbackOrder") else m.playbackOrder = "loop"
    if sec.Exists("transitionStyle") then m.transitionStyle = sec.Read("transitionStyle") else m.transitionStyle = "none"
    if m.displayMode <> "single" and m.displayMode <> "slideshow" then m.displayMode = "slideshow"
    if m.slideSeconds < 3 or m.slideSeconds > 120 then m.slideSeconds = 10
    if m.playbackOrder <> "loop" and m.playbackOrder <> "shuffle" then m.playbackOrder = "loop"
    if m.transitionStyle <> "none" and m.transitionStyle <> "fade" and m.transitionStyle <> "zoomin" and m.transitionStyle <> "slide" and m.transitionStyle <> "random" then m.transitionStyle = "none"
end sub

sub saveSettings()
    sec = CreateObject("roRegistrySection", "RoughstockSettings")
    sec.Write("displayMode", m.displayMode)
    sec.Write("slideSeconds", Str(m.slideSeconds))
    sec.Write("playbackOrder", m.playbackOrder)
    sec.Write("transitionStyle", m.transitionStyle)
    sec.Flush()
end sub

sub showSettings()
    m.settingsGroup.visible = true
    m.settingsList.unobserveField("itemSelected")
    displayLabel = "Display: " + iif(m.displayMode = "single", "One at a time (arrows)", "Slideshow")
    secondsLabel = "Seconds per slide: " + Str(m.slideSeconds)
    orderLabel = "Order: " + iif(m.playbackOrder = "loop", "Loop", "Shuffle")
    transLabel = "Transition: " + transitionLabel(m.transitionStyle)
    content = CreateObject("roSGNode", "ContentNode")
    content.AppendChild(createModeItem(displayLabel, "cycle_display"))
    content.AppendChild(createModeItem(secondsLabel, "cycle_seconds"))
    content.AppendChild(createModeItem(orderLabel, "cycle_order"))
    content.AppendChild(createModeItem(transLabel, "cycle_transition"))
    content.AppendChild(createModeItem("Save and Back", "save_back"))
    m.settingsList.content = content
    m.settingsList.observeField("itemSelected", "onSettingSelected")
    m.settingsList.setFocus(true)
end sub

function iif(cond, a, b) as dynamic
    if cond then return a
    return b
end function

function transitionLabel(style as string) as string
    if style = "none" then return "None"
    if style = "fade" then return "Fade"
    if style = "zoomin" then return "Zoom in"
    if style = "slide" then return "Slide"
    if style = "random" then return "Random"
    return "None"
end function

sub onSettingSelected()
    if m.settingsList.itemSelected = invalid then return
    idx = m.settingsList.itemSelected
    content = m.settingsList.content
    if content = invalid then return
    if idx = 0 then
        if m.displayMode = "single" then m.displayMode = "slideshow" else m.displayMode = "single"
        content.getChild(0).title = "Display: " + iif(m.displayMode = "single", "One at a time (arrows)", "Slideshow")
    else if idx = 1 then
        arr = [5, 10, 15, 20, 30, 45, 60]
        for i = 0 to arr.Count() - 1
            if arr[i] = m.slideSeconds then
                m.slideSeconds = arr[(i + 1) mod arr.Count()]
                exit for
            end if
        end for
        content.getChild(1).title = "Seconds per slide: " + Str(m.slideSeconds)
    else if idx = 2 then
        if m.playbackOrder = "loop" then m.playbackOrder = "shuffle" else m.playbackOrder = "loop"
        content.getChild(2).title = "Order: " + iif(m.playbackOrder = "loop", "Loop", "Shuffle")
    else if idx = 3 then
        arr = ["none", "fade", "zoomin", "slide", "random"]
        for i = 0 to arr.Count() - 1
            if arr[i] = m.transitionStyle then
                m.transitionStyle = arr[(i + 1) mod arr.Count()]
                exit for
            end if
        end for
        content.getChild(3).title = "Transition: " + transitionLabel(m.transitionStyle)
    else if idx = 4 then
        saveSettings()
        m.settingsGroup.visible = false
        m.modeList.visible = true
        m.modeList.setFocus(true)
        m.settingsList.unobserveField("itemSelected")
        return
    end if
end sub

sub startPhotoPlayback()
    if m.photoPaths.Count() = 0 then
        showNoContentAndReturn("photos")
        return
    end if
    m.slidePoster.visible = true
    m.playbackVideo.visible = false
    setScreenSaverSuppressed(true)
    m.slidePoster.opacity = 1.0
    m.slidePoster.scale = [1.0, 1.0]
    m.slidePoster.translation = [0.0, 0.0]
    buildPhotoDisplayOrder()
    m.slideIndex = 0
    showCurrentSlide()
    m.playbackGroup.setFocus(true)
    if m.displayMode = "slideshow" then
        m.slideTimer.duration = m.slideSeconds
        m.slideTimer.repeat = (m.playbackOrder = "loop" or m.playbackOrder = "shuffle")
        m.slideTimer.observeField("fire", "onSlideTimerFire")
        m.slideTimer.control = "start"
    else
        m.slideTimer.control = "stop"
    end if
end sub

sub buildPhotoDisplayOrder()
    n = m.photoPaths.Count()
    m.displayOrder = []
    for i = 0 to n - 1
        m.displayOrder.Push(i)
    end for
    if m.playbackOrder = "shuffle" then
        for i = n - 1 to 1 step -1
            j = Rnd(i + 1) - 1
            t = m.displayOrder[i]
            m.displayOrder[i] = m.displayOrder[j]
            m.displayOrder[j] = t
        end for
    end if
end sub

function getCurrentPhotoIndex() as integer
    if m.displayOrder.Count() = 0 then return m.slideIndex
    return m.displayOrder[m.slideIndex]
end function

sub showCurrentSlide()
    if m.photoPaths.Count() = 0 then return
    idx = getCurrentPhotoIndex()
    path = m.photoPaths[idx]
    ' Roku Poster may need file:// prefix for USB paths to load reliably
    if Left(path, 4) = "ext1" or Left(path, 4) = "ext2" then
        path = "file://" + path
    end if
    m.slidePoster.uri = path
end sub

function pickTransitionStyle() as string
    if m.transitionStyle <> "random" then return m.transitionStyle
    styles = ["fade", "zoomin", "slide"]
    return styles[Rnd(3) - 1]
end function

sub runTransitionOrShowSlide()
    style = pickTransitionStyle()
    if style = "none" then
        showCurrentSlide()
        return
    end if
    if style = "fade" then
        m.fadeOutAnim.observeField("state", "onFadeOutDone")
        m.fadeOutAnim.control = "start"
        return
    end if
    if style = "zoomin" then
        m.slidePoster.scale = [1.2, 1.2]
        showCurrentSlide()
        m.zoomInAnim.observeField("state", "onZoomInDone")
        m.zoomInAnim.control = "start"
        return
    end if
    if style = "slide" then
        m.slidePoster.translation = [1280.0, 0.0]
        showCurrentSlide()
        m.slideInAnim.observeField("state", "onSlideInDone")
        m.slideInAnim.control = "start"
        return
    end if
    showCurrentSlide()
end sub

sub onFadeOutDone()
    if m.fadeOutAnim.state <> "stopped" then return
    m.fadeOutAnim.unobserveField("state")
    m.fadeOutAnim.control = "stop"
    showCurrentSlide()
    m.slidePoster.opacity = 0.0
    m.fadeInAnim.observeField("state", "onFadeInDone")
    m.fadeInAnim.control = "start"
end sub

sub onFadeInDone()
    if m.fadeInAnim.state <> "stopped" then return
    m.fadeInAnim.unobserveField("state")
    m.fadeInAnim.control = "stop"
    m.slidePoster.opacity = 1.0
end sub

sub onZoomInDone()
    if m.zoomInAnim.state <> "stopped" then return
    m.zoomInAnim.unobserveField("state")
    m.zoomInAnim.control = "stop"
    m.slidePoster.scale = [1.0, 1.0]
end sub

sub onSlideInDone()
    if m.slideInAnim.state <> "stopped" then return
    m.slideInAnim.unobserveField("state")
    m.slideInAnim.control = "stop"
    m.slidePoster.translation = [0.0, 0.0]
end sub

sub onSlideTimerFire()
    m.slideIndex = m.slideIndex + 1
    if m.slideIndex >= m.photoPaths.Count() then
        if m.playbackOrder = "loop" or m.playbackOrder = "shuffle" then
            m.slideIndex = 0
            if m.playbackOrder = "shuffle" then buildPhotoDisplayOrder()
        else
            m.slideIndex = m.photoPaths.Count() - 1
            m.slideTimer.control = "stop"
        end if
    end if
    runTransitionOrShowSlide()
end sub

sub moveSlide(delta as integer)
    if m.photoPaths.Count() = 0 then return
    n = m.photoPaths.Count()
    m.slideIndex = m.slideIndex + delta
    if m.slideIndex < 0 then m.slideIndex = 0
    if m.slideIndex >= n then m.slideIndex = n - 1
    m.slidePoster.opacity = 1.0
    m.slidePoster.scale = [1.0, 1.0]
    m.slidePoster.translation = [0.0, 0.0]
    showCurrentSlide()
end sub

sub startVideoPlayback()
    if m.videoPaths.Count() = 0 then
        showNoContentAndReturn("videos")
        return
    end if
    m.slidePoster.visible = false
    m.playbackVideo.visible = true
    setScreenSaverSuppressed(true)
    m.videoIndex = 0
    playCurrentVideo()
    m.playbackVideo.observeField("state", "onVideoStateChange")
    m.playbackGroup.setFocus(true)
end sub

sub playCurrentVideo()
    if m.videoPaths.Count() = 0 then return
    path = m.videoPaths[m.videoIndex]
    content = CreateObject("roSGNode", "ContentNode")
    content.url = path
    content.streamFormat = "mp4"
    m.playbackVideo.content = content
    m.playbackVideo.control = "play"
end sub

sub onVideoStateChange()
    state = m.playbackVideo.state
    if state = "finished" or state = "stopped" then
        m.videoIndex = m.videoIndex + 1
        if m.videoIndex >= m.videoPaths.Count() then
            m.videoIndex = 0
        end if
        playCurrentVideo()
    end if
end sub

sub startBothMode()
    if m.photoPaths.Count() = 0 and m.videoPaths.Count() = 0 then
        showNoContentAndReturn("both")
        return
    end if
    setScreenSaverSuppressed(true)
    m.bothPhotoIndex = 0
    m.playbackGroup.setFocus(true)
    runBothModeStep()
end sub

sub runBothModeStep()
    ' Show N photos, then one video, repeat. If only one type exists, just loop that.
    if m.bothPhotoIndex < m.bothPhotoCount and m.photoPaths.Count() > 0 then
        m.slidePoster.visible = true
        m.playbackVideo.visible = false
        showCurrentSlide()
        m.bothPhotoIndex = m.bothPhotoIndex + 1
        m.slideIndex = (m.slideIndex + 1) mod m.photoPaths.Count()
        m.slideTimer.duration = m.slideSeconds
        m.slideTimer.repeat = false
        m.slideTimer.observeField("fire", "onBothModeSlideTimer")
        m.slideTimer.control = "start"
    else if m.videoPaths.Count() > 0 then
        m.bothPhotoIndex = 0
        m.slidePoster.visible = false
        m.playbackVideo.visible = true
        playCurrentVideo()
        m.playbackVideo.observeField("state", "onBothModeVideoState")
    else if m.photoPaths.Count() > 0 then
        ' Only photos: show current slide and keep cycling
        m.bothPhotoIndex = 0
        m.slidePoster.visible = true
        m.playbackVideo.visible = false
        showCurrentSlide()
        m.slideIndex = (m.slideIndex + 1) mod m.photoPaths.Count()
        m.slideTimer.duration = m.slideSeconds
        m.slideTimer.repeat = false
        m.slideTimer.observeField("fire", "onBothModeSlideTimer")
        m.slideTimer.control = "start"
    end if
end sub

sub onBothModeSlideTimer()
    m.slideTimer.unobserveField("fire")
    runBothModeStep()
end sub

sub onBothModeVideoState()
    state = m.playbackVideo.state
    if state = "finished" or state = "stopped" then
        m.videoIndex = (m.videoIndex + 1) mod m.videoPaths.Count()
        m.playbackVideo.unobserveField("state")
        runBothModeStep()
    end if
end sub

' contentType: "photos" | "videos" | "both" — shows a user-friendly message and returns to mode list
sub showNoContentAndReturn(contentType as string)
    m.playbackGroup.visible = false
    m.messageLabel.visible = true
    if contentType = "photos" then
        m.messageLabel.text = "No photos found. Add images (.jpg, .png, .gif) to the 'Photos' folder on your USB drive."
    else if contentType = "videos" then
        m.messageLabel.text = "No videos found. Add videos (.mp4, .mkv, .mov) to the 'Videos' folder on your USB drive."
    else
        m.messageLabel.text = "No content found. Add images to the 'Photos' folder and videos to the 'Videos' folder on your USB drive."
    end if
    m.modeList.visible = true
    m.modeList.setFocus(true)
end sub

sub returnToHome()
    stopTimerMode()
    m.timerGroup.visible = false
    m.timerSettingsGroup.visible = false
    m.homeList.visible = true
    m.homeList.setFocus(true)
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if not press then return false
    if key = "back" and m.timerGroup.visible and not m.timerSettingsGroup.visible then
        returnToHome()
        return true
    end if
    if key = "back" and m.timerSettingsGroup.visible then
        closeTimerSettings()
        return true
    end if
    if key = "back" and m.modeList.visible then
        showHomeList()
        return true
    end if
    if key = "back" and m.messageLabel.visible then
        showHomeList()
        return true
    end if
    if key = "back" and m.playbackGroup.visible then
        returnToMainScreen()
        return true
    end if
    if m.timerGroup.visible and not m.timerSettingsGroup.visible then
        if key = "options" or key = "*" then
            showTimerSettings()
            return true
        end if
    end if
    if m.mode = "photos" and m.playbackGroup.visible and m.photoPaths.Count() > 0 then
        if key = "right" then
            moveSlide(1)
            if m.displayMode = "slideshow" then restartSlideTimer()
            return true
        else if key = "left" then
            moveSlide(-1)
            if m.displayMode = "slideshow" then restartSlideTimer()
            return true
        end if
    end if
    return false
end function

sub returnToMainScreen()
    m.slideTimer.control = "stop"
    m.playbackVideo.control = "stop"
    setScreenSaverSuppressed(false)
    m.playbackGroup.visible = false
    m.modeList.visible = true
    m.modeList.setFocus(true)
end sub

' --- Timer (round/rest countdown) ---
sub loadTimerSettings()
    sec = CreateObject("roRegistrySection", "RoughstockSettings")
    if sec.Exists("timer_showSponsors") then m.timer_showSponsors = (sec.Read("timer_showSponsors") = "true") else m.timer_showSponsors = false
    if sec.Exists("timer_fontSize") then m.timer_fontSize = sec.Read("timer_fontSize") else m.timer_fontSize = "medium"
    if sec.Exists("timer_showCurrentTime") then m.timer_showCurrentTime = (sec.Read("timer_showCurrentTime") = "true") else m.timer_showCurrentTime = false
    if sec.Exists("timer_fontColor") then m.timer_fontColor = sec.Read("timer_fontColor") else m.timer_fontColor = "0xFFFFFF"
    if sec.Exists("timer_roundMinutes") then m.timer_roundMinutes = Val(sec.Read("timer_roundMinutes"), 5) else m.timer_roundMinutes = 5
    if sec.Exists("timer_restSeconds") then m.timer_restSeconds = Val(sec.Read("timer_restSeconds"), 30) else m.timer_restSeconds = 30
    if m.timer_roundMinutes <> 1 and m.timer_roundMinutes <> 3 and m.timer_roundMinutes <> 5 then m.timer_roundMinutes = 5
    if m.timer_restSeconds <> 30 and m.timer_restSeconds <> 60 and m.timer_restSeconds <> 90 then m.timer_restSeconds = 30
end sub

sub saveTimerSettings()
    sec = CreateObject("roRegistrySection", "RoughstockSettings")
    sec.Write("timer_showSponsors", iif(m.timer_showSponsors, "true", "false"))
    sec.Write("timer_fontSize", m.timer_fontSize)
    sec.Write("timer_showCurrentTime", iif(m.timer_showCurrentTime, "true", "false"))
    sec.Write("timer_fontColor", m.timer_fontColor)
    sec.Write("timer_roundMinutes", Str(m.timer_roundMinutes))
    sec.Write("timer_restSeconds", Str(m.timer_restSeconds))
    sec.Flush()
end sub

sub startTimerMode()
    loadTimerSettings()
    applyTimerSettingsToUI()
    m.timerPhase = "round" ' "round" | "rest"
    m.timerRoundSeconds = m.timer_roundMinutes * 60
    m.timerRestSeconds = m.timer_restSeconds
    m.timerRemaining = m.timerRoundSeconds
    m.timerRoundNumber = 1
    m.timerRestRemaining = 0
    readAnnouncements()
    m.timerGroup.visible = true
    m.timerTick.repeat = true
    m.timerTick.duration = 1
    m.timerTick.unobserveField("fire")
    m.timerTick.observeField("fire", "onTimerTick")
    m.timerTick.control = "start"
    updateTimerDisplay()
    m.timerGroup.setFocus(true)
end sub

sub stopTimerMode()
    if m.timerTick <> invalid then
        m.timerTick.unobserveField("fire")
        m.timerTick.control = "stop"
    end if
end sub

sub applyTimerSettingsToUI()
    m.timerSponsorGroup.visible = m.timer_showSponsors
    m.timerClockLabel.visible = m.timer_showCurrentTime
    colorHex = { "0xFFFFFF": &hFFFFFF, "0xFFFF00": &hFFFF00, "0xFF0000": &hFF0000, "0x00FF00": &h00FF00 }
    c = colorHex[m.timer_fontColor]
    if c = invalid then c = &hFFFFFF
    m.timerCountdownLabel.color = c
    m.timerPhaseLabel.color = c
    m.timerRoundLabel.color = c
    m.timerNextRoundLabel.color = c
    m.timerClockLabel.color = c
    sizeMap = { "small": 48, "medium": 72, "large": 96 }
    sz = sizeMap[m.timer_fontSize]
    if sz = invalid then sz = 72
    m.timerCountdownLabel.font = "size:" + Str(sz)
    if m.timer_showCurrentTime then m.timerClockLabel.font = "size:24"
end sub

' Reads USB Roughstock/announcements.txt if present; missing file or path is OK (no crash).
sub readAnnouncements()
    text = ""
    for each prefix in ["ext1:", "ext2:"]
        path = prefix + "/Roughstock/announcements.txt"
        content = ReadAsciiFile(path)
        if content <> invalid and content <> "" then
            text = content
            exit for
        end if
    end for
    if text = invalid then text = ""
    if m.timerAnnouncementsLabel <> invalid then
        m.timerAnnouncementsLabel.text = text
    end if
end sub

sub onTimerTick()
    dt = CreateObject("roDateTime")
    if m.timer_showCurrentTime then
        h = dt.GetHours()
        m = dt.GetMinutes()
        am = "AM"
        if h >= 12 then am = "PM"
        if h > 12 then h = h - 12
        if h = 0 then h = 12
        m.timerClockLabel.text = Str(h).Trim() + ":" + zeroPad(m) + " " + am
    end if
    if m.timerPhase = "rest" then
        m.timerNextRoundLabel.visible = true
        m.timerNextRoundLabel.text = "Next round in: " + formatTimerSeconds(m.timerRestRemaining)
        m.timerRestRemaining = m.timerRestRemaining - 1
        if m.timerRestRemaining < 0 then
            m.timerRoundNumber = m.timerRoundNumber + 1
            m.timerPhase = "round"
            m.timerRemaining = m.timerRoundSeconds
            m.timerNextRoundLabel.visible = false
        end if
    else
        m.timerRemaining = m.timerRemaining - 1
        if m.timerRemaining < 0 then
            m.timerPhase = "rest"
            m.timerRestRemaining = m.timer_restSeconds
            m.timerNextRoundLabel.visible = true
            m.timerNextRoundLabel.text = "Next round in: " + formatTimerSeconds(m.timerRestRemaining)
        end if
    end if
    updateTimerDisplay()
end sub

function formatTimerSeconds(sec as integer) as string
    m = sec \ 60
    s = sec mod 60
    return Str(m).Trim() + ":" + zeroPad(s)
end function

function zeroPad(n as integer) as string
    if n < 10 then return "0" + Str(n).Trim()
    return Str(n).Trim()
end function

sub updateTimerDisplay()
    m.timerPhaseLabel.text = iif(m.timerPhase = "round", "ROUND", "REST")
    m.timerRoundLabel.text = "Round " + Str(m.timerRoundNumber).Trim()
    if m.timerPhase = "round" then
        m.timerCountdownLabel.text = formatTimerSeconds(m.timerRemaining)
        m.timerNextRoundLabel.visible = false
    else
        m.timerCountdownLabel.text = formatTimerSeconds(m.timerRestRemaining)
        m.timerNextRoundLabel.visible = true
        m.timerNextRoundLabel.text = "Next round in: " + formatTimerSeconds(m.timerRestRemaining)
    end if
end sub

sub showTimerSettings()
    m.timerSettingsGroup.visible = true
    m.timerSettingsList.unobserveField("itemSelected")
    sponsorsLabel = "Sponsors: " + iif(m.timer_showSponsors, "Yes", "No")
    sizeLabel = "Font size: " + ucase(left(m.timer_fontSize, 1)) + mid(m.timer_fontSize, 2)
    clockLabel = "Show current time: " + iif(m.timer_showCurrentTime, "Yes", "No")
    colorNames = { "0xFFFFFF": "White", "0xFFFF00": "Yellow", "0xFF0000": "Red", "0x00FF00": "Green" }
    cn = colorNames[m.timer_fontColor]
    if cn <> invalid then colorLabel = "Font color: " + cn else colorLabel = "Font color: White"
    roundLabel = "Round duration: " + Str(m.timer_roundMinutes).Trim() + " min"
    restLabel = "Rest between rounds: " + Str(m.timer_restSeconds).Trim() + " sec"
    content = CreateObject("roSGNode", "ContentNode")
    content.AppendChild(createModeItem(sponsorsLabel, "cycle_sponsors"))
    content.AppendChild(createModeItem(sizeLabel, "cycle_size"))
    content.AppendChild(createModeItem(clockLabel, "cycle_clock"))
    content.AppendChild(createModeItem(colorLabel, "cycle_color"))
    content.AppendChild(createModeItem(roundLabel, "cycle_round"))
    content.AppendChild(createModeItem(restLabel, "cycle_rest"))
    content.AppendChild(createModeItem("Save and Back", "timer_save_back"))
    m.timerSettingsList.content = content
    m.timerSettingsList.observeField("itemSelected", "onTimerSettingSelected")
    m.timerSettingsList.setFocus(true)
end sub

sub closeTimerSettings()
    m.timerSettingsGroup.visible = false
    m.timerSettingsList.unobserveField("itemSelected")
    m.timerGroup.setFocus(true)
end sub

sub onTimerSettingSelected()
    if m.timerSettingsList.itemSelected = invalid then return
    idx = m.timerSettingsList.itemSelected
    content = m.timerSettingsList.content
    if content = invalid then return
    if idx = 0 then
        m.timer_showSponsors = not m.timer_showSponsors
        content.getChild(0).title = "Sponsors: " + iif(m.timer_showSponsors, "Yes", "No")
    else if idx = 1 then
        arr = ["small", "medium", "large"]
        for i = 0 to arr.Count() - 1
            if arr[i] = m.timer_fontSize then
                m.timer_fontSize = arr[(i + 1) mod arr.Count()]
                exit for
            end if
        end for
        content.getChild(1).title = "Font size: " + ucase(left(m.timer_fontSize, 1)) + mid(m.timer_fontSize, 2)
    else if idx = 2 then
        m.timer_showCurrentTime = not m.timer_showCurrentTime
        content.getChild(2).title = "Show current time: " + iif(m.timer_showCurrentTime, "Yes", "No")
    else if idx = 3 then
        colors = ["0xFFFFFF", "0xFFFF00", "0xFF0000", "0x00FF00"]
        colorNames = { "0xFFFFFF": "White", "0xFFFF00": "Yellow", "0xFF0000": "Red", "0x00FF00": "Green" }
        for i = 0 to colors.Count() - 1
            if colors[i] = m.timer_fontColor then
                m.timer_fontColor = colors[(i + 1) mod colors.Count()]
                exit for
            end if
        end for
        content.getChild(3).title = "Font color: " + colorNames[m.timer_fontColor]
    else if idx = 4 then
        arr = [1, 3, 5]
        for i = 0 to arr.Count() - 1
            if arr[i] = m.timer_roundMinutes then
                m.timer_roundMinutes = arr[(i + 1) mod arr.Count()]
                exit for
            end if
        end for
        content.getChild(4).title = "Round duration: " + Str(m.timer_roundMinutes).Trim() + " min"
    else if idx = 5 then
        arr = [30, 60, 90]
        for i = 0 to arr.Count() - 1
            if arr[i] = m.timer_restSeconds then
                m.timer_restSeconds = arr[(i + 1) mod arr.Count()]
                exit for
            end if
        end for
        content.getChild(5).title = "Rest between rounds: " + Str(m.timer_restSeconds).Trim() + " sec"
    else if idx = 6 then
        saveTimerSettings()
        applyTimerSettingsToUI()
        closeTimerSettings()
        return
    end if
end sub

sub restartSlideTimer()
    if m.slideTimer.repeat then
        m.slideTimer.control = "stop"
        m.slideTimer.control = "start"
    end if
end sub
