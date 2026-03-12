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
    m.mainTitleLabel = m.top.findNode("mainTitleLabel")
    m.mainBgRect = m.top.findNode("mainBgRect")
    m.mainBgLogo = m.top.findNode("mainBgLogo")
    m.timerScreenGroup = m.top.findNode("timerScreenGroup")
    m.timerTitleList = m.top.findNode("timerTitleList")
    m.timerClockList = m.top.findNode("timerClockList")
    m.timerCountdownList = m.top.findNode("timerCountdownList")
    m.timerBodyList = m.top.findNode("timerBodyList")
    m.timerSettingsGroup = m.top.findNode("timerSettingsGroup")
    m.settingsTitleLabel = m.top.findNode("settingsTitleLabel")
    m.timerSettingsTitleLabel = m.top.findNode("timerSettingsTitleLabel")
    m.timerSettingsList = m.top.findNode("timerSettingsList")
    m.timerSponsorGroup = m.top.findNode("timerSponsorGroup")
    m.timerAnnouncementsList = m.top.findNode("timerAnnouncementsList")
    m.timerTick = m.top.findNode("timerTick")
    m.timerBeep = m.top.findNode("timerBeep")
    m.timerBeepExtend = m.top.findNode("timerBeepExtend")
    m.announcementTimer = m.top.findNode("announcementTimer")
    m.announcementLines = []
    m.announcementIndex = 0
    if m.timerBeepExtend <> invalid then m.timerBeepExtend.observeField("fire", "onBeepExtendFire")

    m.photoPaths = []
    m.videoPaths = []
    m.slideIndex = 0
    m.videoIndex = 0
    m.mode = "" ' "photos" | "videos" | "both"
    m.bothPhotoCount = 5
    m.bothPhotoIndex = 0
    m.displayOrder = [] ' shuffled indices when playbackOrder=shuffle
    m.onTimerScreen = false

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
    setTimerScreenVisible(false)
    m.timerSettingsGroup.visible = false
    m.mainTitleLabel.visible = true
    m.mainTitleLabel.text = "Roughstock TV"
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
    setTimerScreenVisible(false)
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

' Pad title with leading spaces so it appears roughly centered when drawn left-aligned (LabelList has no horizAlign).
' nudgeLeft: subtract from padLeft (positive = shift text left). Pass 0 if not used.
function centerPad(title as string, widthInChars as integer, nudgeLeft as integer) as string
    if widthInChars <= 0 then return title
    lenTitle = Len(title)
    if lenTitle >= widthInChars then return title
    padLeft = (widthInChars - lenTitle) \ 2 - nudgeLeft
    if padLeft < 0 then padLeft = 0
    padRight = widthInChars - lenTitle - padLeft
    leftStr = ""
    for i = 1 to padLeft
        leftStr = leftStr + " "
    end for
    rightStr = ""
    for i = 1 to padRight
        rightStr = rightStr + " "
    end for
    return leftStr + title + rightStr
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
    m.settingsTitleLabel.text = "Roughstock TV"
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
    setTimerScreenVisible(false)
    m.onTimerScreen = false
    m.timerSettingsGroup.visible = false
    m.mainTitleLabel.visible = true
    m.mainBgRect.visible = true
    m.mainBgLogo.visible = true
    m.homeList.visible = true
    m.homeList.setFocus(true)
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if not press then return false
    if key = "back" and m.onTimerScreen and not m.timerSettingsGroup.visible then
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
    if m.onTimerScreen and not m.timerSettingsGroup.visible then
        if key = "options" or key = "*" then
            showTimerSettings()
            return true
        end if
        if key = "play" then
            m.timerPaused = not m.timerPaused
            if m.timerPaused then
                m.timerTick.control = "stop"
            else
                m.timerTick.control = "start"
            end if
            updateTimerDisplay()
            return true
        end if
        if key = "right" then
            timerJumpNext()
            return true
        end if
        if key = "left" then
            timerJumpPrev()
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
    if sec.Exists("timer_showCurrentTime") then m.timer_showCurrentTime = (sec.Read("timer_showCurrentTime") = "true") else m.timer_showCurrentTime = true
    if sec.Exists("timer_preset") then m.timer_preset = sec.Read("timer_preset") else m.timer_preset = "1_10"
    if sec.Exists("timer_roundMinutes") then m.timer_roundMinutes = Val(sec.Read("timer_roundMinutes"), 1) else m.timer_roundMinutes = 1
    if sec.Exists("timer_restSeconds") then m.timer_restSeconds = Val(sec.Read("timer_restSeconds"), 10) else m.timer_restSeconds = 10
    if sec.Exists("timer_fontSize") then m.timer_fontSize = sec.Read("timer_fontSize") else m.timer_fontSize = "medium"
    if sec.Exists("timer_color_title") then m.timer_color_title = sec.Read("timer_color_title") else m.timer_color_title = "white"
    if sec.Exists("timer_color_clock") then m.timer_color_clock = sec.Read("timer_color_clock") else m.timer_color_clock = "white"
    if sec.Exists("timer_color_countdown") then m.timer_color_countdown = sec.Read("timer_color_countdown") else m.timer_color_countdown = "white"
    if sec.Exists("timer_color_body") then m.timer_color_body = sec.Read("timer_color_body") else m.timer_color_body = "white"
    if sec.Exists("timer_color_announcements") then m.timer_color_announcements = sec.Read("timer_color_announcements") else m.timer_color_announcements = "white"
    if m.timer_preset = "1_10" then m.timer_roundMinutes = 1 : m.timer_restSeconds = 10
    if m.timer_preset = "2_10" then m.timer_roundMinutes = 2 : m.timer_restSeconds = 10
    if m.timer_preset = "3_10" then m.timer_roundMinutes = 3 : m.timer_restSeconds = 10
    if m.timer_roundMinutes <> 1 and m.timer_roundMinutes <> 2 and m.timer_roundMinutes <> 3 and m.timer_roundMinutes <> 5 then m.timer_roundMinutes = 3
    if m.timer_restSeconds <> 10 and m.timer_restSeconds <> 30 and m.timer_restSeconds <> 60 and m.timer_restSeconds <> 90 then m.timer_restSeconds = 10
    if m.timer_fontSize <> "small" and m.timer_fontSize <> "medium" and m.timer_fontSize <> "large" then m.timer_fontSize = "medium"
end sub

sub saveTimerSettings()
    sec = CreateObject("roRegistrySection", "RoughstockSettings")
    sec.Write("timer_showSponsors", iif(m.timer_showSponsors, "true", "false"))
    sec.Write("timer_showCurrentTime", iif(m.timer_showCurrentTime, "true", "false"))
    sec.Write("timer_preset", m.timer_preset)
    sec.Write("timer_roundMinutes", Str(m.timer_roundMinutes))
    sec.Write("timer_restSeconds", Str(m.timer_restSeconds))
    sec.Write("timer_fontSize", m.timer_fontSize)
    sec.Write("timer_color_title", m.timer_color_title)
    sec.Write("timer_color_clock", m.timer_color_clock)
    sec.Write("timer_color_countdown", m.timer_color_countdown)
    sec.Write("timer_color_body", m.timer_color_body)
    sec.Write("timer_color_announcements", m.timer_color_announcements)
    sec.Flush()
end sub

' Layout: title + clock at top (clock smaller), countdown centered H/V, Round N at bottom. Center each row when scaling.
sub applyTimerFontSizes()
    cx = 640.0
    halfW = 520.0
    screenH = 720.0
    ' Title "Roughstock TV": at top, nudge left. scale 1.9
    titleScale = 1.9
    titleRowH = 48.0
    titleBaseY = 20.0
    nudgeLeft = 24.0
    if m.timerTitleList <> invalid then
        m.timerTitleList.scale = [titleScale, titleScale]
        m.timerTitleList.translation = [cx - halfW * titleScale - nudgeLeft, titleBaseY + (titleRowH / 2.0) * (1.0 - titleScale)]
    end if
    ' Clock (time + day/date): below title, smaller, nudge left. scale 1.4
    clockScale = 1.4
    clockRowH = 56.0
    clockBaseY = 88.0
    if m.timerClockList <> invalid then
        m.timerClockList.scale = [clockScale, clockScale]
        m.timerClockList.translation = [cx - halfW * clockScale - nudgeLeft, clockBaseY + (clockRowH / 2.0) * (1.0 - clockScale)]
    end if
    ' Countdown (timer 1:00): centered H/V, nudge right. User size; medium/large even bigger.
    s = 4.0
    if m.timer_fontSize = "small" then s = 1.9
    if m.timer_fontSize = "large" then s = 5.0
    countdownRowH = 56.0
    centerY = screenH / 2.0
    nudgeRight = 44.0
    if m.timerCountdownList <> invalid then
        m.timerCountdownList.scale = [s, s]
        m.timerCountdownList.translation = [cx - halfW * s + nudgeRight, centerY + (countdownRowH / 2.0) * (1.0 - s)]
    end if
    ' Body "Round N": just below countdown, centered. scale 1.9
    bodyScale = 1.9
    bodyRowH = 64.0
    gapBelowCountdown = 20.0
    bodyVisualCenterY = centerY + (countdownRowH * s) / 2.0 + gapBelowCountdown + (bodyRowH * bodyScale) / 2.0
    bodyBaseY = bodyVisualCenterY - bodyRowH / 2.0
    if m.timerBodyList <> invalid then
        m.timerBodyList.scale = [bodyScale, bodyScale]
        m.timerBodyList.translation = [cx - halfW * bodyScale, bodyBaseY + (bodyRowH / 2.0) * (1.0 - bodyScale)]
    end if
    ' Announcements: position at bottom (where Round N was)
    applyTimerAnnouncementsLayout()
end sub

sub applyTimerAnnouncementsLayout()
    cx = 640.0
    halfW = 520.0
    screenH = 720.0
    bottomMargin = 50.0
    annRowH = 48.0
    annScale = 1.4
    annBaseY = screenH - bottomMargin - annRowH
    if m.timerAnnouncementsList <> invalid then
        m.timerAnnouncementsList.scale = [annScale, annScale]
        m.timerAnnouncementsList.translation = [cx - halfW * annScale, annBaseY + (annRowH / 2.0) * (1.0 - annScale)]
    end if
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
    m.timerPaused = false
    readAnnouncements()
    m.onTimerScreen = true
    m.mainTitleLabel.visible = false
    m.mainBgRect.visible = false
    m.mainBgLogo.visible = false
    m.homeList.visible = false
    setTimerScreenVisible(true)
    ' Title (1), clock = current time + day/date (1), countdown (1), body = Round N only (1).
    m.timerTitleContent = CreateObject("roSGNode", "ContentNode")
    m.timerTitleContent.AppendChild(CreateObject("roSGNode", "ContentNode"))
    m.timerClockContent = CreateObject("roSGNode", "ContentNode")
    m.timerClockContent.AppendChild(CreateObject("roSGNode", "ContentNode"))
    m.timerCountdownContent = CreateObject("roSGNode", "ContentNode")
    m.timerCountdownContent.AppendChild(CreateObject("roSGNode", "ContentNode"))
    m.timerTitleList.content = m.timerTitleContent
    m.timerClockList.content = m.timerClockContent
    if m.timerCountdownList <> invalid then m.timerCountdownList.content = m.timerCountdownContent
    applyTimerFontSizes()
    applyTimerColors()
    initTimerBeep()
    applyTimerSettingsToUI()
    m.timerTickCount = 0
    m.timerTick.repeat = true
    m.timerTick.duration = 1
    m.timerTick.unobserveField("fire")
    m.timerTick.observeField("fire", "onTimerTick")
    m.timerTick.control = "start"
    updateTimerDisplay()
    m.top.setFocus(true)
end sub

sub stopTimerMode()
    if m.timerTick <> invalid then
        m.timerTick.unobserveField("fire")
        m.timerTick.control = "stop"
    end if
    if m.announcementTimer <> invalid then
        m.announcementTimer.unobserveField("fire")
        m.announcementTimer.control = "stop"
    end if
end sub

' Preload beep content when timer screen is shown so full 3s file is buffered before first play.
sub initTimerBeep()
    if m.timerBeep = invalid then return
    content = CreateObject("roSGNode", "ContentNode")
    content.url = "pkg:/sounds/beep.m4a"
    m.timerBeep.content = content
end sub

' Play beep: work around Roku playing only ~1s by restarting at 1s and 2s so we get 3 seconds of sound.
' Skip if we started a beep within last 3 ticks so a short rest doesn't cut off the previous beep.
sub playTimerBeep()
    if m.timerBeep = invalid then return
    if m.lastBeepTick <> invalid and (m.timerTickCount - m.lastBeepTick) < 3 then return
    m.lastBeepTick = m.timerTickCount
    m.beepExtendCount = 0
    m.timerBeep.control = "stop"
    m.timerBeep.control = "play"
    if m.timerBeepExtend <> invalid then
        m.timerBeepExtend.control = "stop"
        m.timerBeepExtend.control = "start"
    end if
end sub

' Fire at 1s and 2s: restart beep each time so we get 3 x 1s = 3 seconds. After 2nd restart, stop timer.
sub onBeepExtendFire()
    if m.timerBeep = invalid or m.timerBeepExtend = invalid then return
    m.beepExtendCount = m.beepExtendCount + 1
    m.timerBeep.control = "stop"
    m.timerBeep.control = "play"
    if m.beepExtendCount >= 2 then m.timerBeepExtend.control = "stop"
end sub

sub setTimerScreenVisible(visible as boolean)
    if m.timerScreenGroup <> invalid then m.timerScreenGroup.visible = visible
    if visible and m.timerSponsorGroup <> invalid then m.timerSponsorGroup.visible = m.timer_showSponsors
end sub

sub applyTimerSettingsToUI()
    if m.timerSponsorGroup <> invalid then m.timerSponsorGroup.visible = m.timer_showSponsors
end sub

' Reads USB announcements.txt at drive root (alongside Photos/Videos) if present.
' Uses listDirectory so we never call ReadAsciiFile on invalid paths (which would throw when no USB is connected).
sub readAnnouncements()
    text = ""
    for each prefix in ["ext1:", "ext2:"]
        rootPath = prefix + "/"
        list = listDirectory(rootPath)
        if list <> invalid then
            for each name in list
                if name = "announcements.txt" then
                    content = ReadAsciiFile(rootPath + name)
                    if content <> invalid and content <> "" then
                        text = content
                        exit for
                    end if
                end if
            end for
            if text <> "" then exit for
        end if
    end for
    if text = invalid then text = ""
    m.announcementLines = []
    m.announcementIndex = 0
    if text <> "" then
        lines = text.Split(chr(10))
        for each line in lines
            trimmed = line.Trim()
            if Len(trimmed) > 0 then m.announcementLines.Push(trimmed)
        end for
    end if
    if m.announcementLines.Count() > 0 then
        showAnnouncementLine(0)
        if m.timerAnnouncementsList <> invalid then m.timerAnnouncementsList.visible = true
        if m.announcementTimer <> invalid then
            m.announcementTimer.unobserveField("fire")
            m.announcementTimer.observeField("fire", "onAnnouncementTimerFire")
            m.announcementTimer.control = "start"
        end if
    else
        if m.timerAnnouncementsList <> invalid then m.timerAnnouncementsList.visible = false
        if m.announcementTimer <> invalid then
            m.announcementTimer.control = "stop"
        end if
    end if
end sub

sub showAnnouncementLine(idx as integer)
    if m.timerAnnouncementsList = invalid then return
    rowWidthPx = 1040
    TIMER_PX_PER_CHAR = 6
    w = rowWidthPx \ TIMER_PX_PER_CHAR
    annNudge = 18
    annContent = CreateObject("roSGNode", "ContentNode")
    lineNode = CreateObject("roSGNode", "ContentNode")
    lineNode.title = centerPad(m.announcementLines[idx], w, annNudge)
    annContent.AppendChild(lineNode)
    m.timerAnnouncementsList.content = annContent
end sub

sub onAnnouncementTimerFire()
    if m.announcementLines.Count() = 0 then return
    m.announcementIndex = (m.announcementIndex + 1) mod m.announcementLines.Count()
    showAnnouncementLine(m.announcementIndex)
end sub

sub onTimerTick()
    if m.timerPaused = true then return
    m.timerTickCount = m.timerTickCount + 1
    if m.timerPhase = "rest" then
        m.timerRestRemaining = m.timerRestRemaining - 1
        if m.timerRestRemaining = 0 then playTimerBeep()
        if m.timerRestRemaining < 0 then
            m.timerRoundNumber = m.timerRoundNumber + 1
            m.timerPhase = "round"
            m.timerRemaining = m.timerRoundSeconds
        end if
    else
        m.timerRemaining = m.timerRemaining - 1
        if m.timerRemaining = 0 then playTimerBeep()
        if m.timerRemaining < 0 then
            m.timerPhase = "rest"
            m.timerRestRemaining = m.timer_restSeconds
        end if
    end if
    updateTimerDisplay()
end sub

function formatTimerSeconds(sec as integer) as string
    minVal = sec \ 60
    s = sec mod 60
    return Str(minVal).Trim() + ":" + zeroPad(s)
end function

function zeroPad(n as integer) as string
    if n < 10 then return "0" + Str(n).Trim()
    return Str(n).Trim()
end function

sub timerJumpNext()
    if m.timerPhase = "round" then
        m.timerPhase = "rest"
        m.timerRestRemaining = m.timer_restSeconds
    else
        m.timerRoundNumber = m.timerRoundNumber + 1
        m.timerPhase = "round"
        m.timerRemaining = m.timerRoundSeconds
    end if
    updateTimerDisplay()
end sub

sub timerJumpPrev()
    if m.timerPhase = "rest" then
        m.timerPhase = "round"
        m.timerRemaining = m.timerRoundSeconds
    else
        if m.timerRoundNumber > 1 then
            m.timerRoundNumber = m.timerRoundNumber - 1
            m.timerPhase = "rest"
            m.timerRestRemaining = m.timer_restSeconds
        else
            m.timerPhase = "round"
            m.timerRemaining = m.timerRoundSeconds
        end if
    end if
    updateTimerDisplay()
end sub

sub updateTimerDisplay()
    if m.timerTitleContent = invalid or m.timerClockContent = invalid or m.timerBodyList = invalid then return
    if m.timerCountdownList = invalid or m.timerCountdownContent = invalid then return
    rowWidthPx = 1040
    if m.timerBodyList.itemSize <> invalid then
        arr = m.timerBodyList.itemSize
        if type(arr) = "roArray" and arr.Count() >= 1 then rowWidthPx = arr[0]
    end if
    if rowWidthPx <= 0 then
        scene = m.top.getScene()
        if scene <> invalid and scene.currentDesignResolution <> invalid then
            res = scene.currentDesignResolution
            if type(res) = "roArray" and res.Count() >= 1 then rowWidthPx = res[0] - 240
        end if
    end if
    if rowWidthPx <= 0 then rowWidthPx = 1040
    TIMER_PX_PER_CHAR = 6
    w = rowWidthPx \ TIMER_PX_PER_CHAR
    if w <= 0 then w = 173
    nudge = 5
    ' Title: Roughstock TV
    m.timerTitleContent.getChild(0).title = centerPad("Roughstock TV", w, nudge)
    ' Clock line: current time + day/date (e.g. "Tue, Mar 10 • 2:30 PM")
    if m.timer_showCurrentTime then
        m.timerClockList.visible = true
        m.timerClockContent.getChild(0).title = centerPad(formatClockWithDate(), w, nudge)
    else
        m.timerClockList.visible = false
    end if
    ' Timer (countdown): 1:00 — user font size, slight nudge right
    if m.timerCountdownList <> invalid then m.timerCountdownList.visible = true
    countdownNudge = 2
    m.timerCountdownContent.getChild(0).title = centerPad(formatTimerSeconds(iif(m.timerPhase = "round", m.timerRemaining, m.timerRestRemaining)), w, nudge - countdownNudge)
    ' Body: Round N only (no ROUND/REST/PAUSED line)
    bodyContent = CreateObject("roSGNode", "ContentNode")
    bodyContent.AppendChild(createBodyLine(centerPad("Round " + Str(m.timerRoundNumber).Trim(), w, nudge)))
    m.timerBodyList.content = bodyContent
end sub

' Current time with day/date e.g. "Tue, Mar 10 • 2:30 PM"
function formatClockWithDate() as string
    dt = CreateObject("roDateTime")
    dt.ToLocalTime()
    dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    monthNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    dow = dt.GetDayOfWeek()
    if dow < 0 or dow > 6 then dow = 0
    mon = dt.GetMonth() - 1
    if mon < 0 or mon > 11 then mon = 0
    dayNum = dt.GetDayOfMonth()
    h = dt.GetHours()
    clockMin = dt.GetMinutes()
    am = "AM"
    if h >= 12 then am = "PM"
    if h > 12 then h = h - 12
    if h = 0 then h = 12
    dateStr = dayNames[dow] + ", " + monthNames[mon] + " " + Str(dayNum).Trim()
    timeStr = Str(h).Trim() + ":" + zeroPad(clockMin) + " " + am
    return dateStr + " • " + timeStr
end function

function createBodyLine(title as string) as object
    node = CreateObject("roSGNode", "ContentNode")
    node.title = title
    return node
end function

function getTimerPresetLabel() as string
    if m.timer_preset = "1_10" then return "Preset: 1 min round / 10 s rest"
    if m.timer_preset = "2_10" then return "Preset: 2 min round / 10 s rest"
    if m.timer_preset = "3_10" then return "Preset: 3 min round / 10 s rest"
    return "Preset: Custom"
end function

function getTimerFontSizeLabel() as string
    if m.timer_fontSize = "small" then return "Small"
    if m.timer_fontSize = "large" then return "Large"
    return "Medium"
end function

' Timer line colors: key -> color string. Roku expects "0xRRGGBBAA" (alpha low byte); use "FF" for opaque.
function getTimerColorHex(key as string) as string
    colors = {
        "white": "E8E8E8",
        "yellow": "FFFF00",
        "red": "FF0000",
        "green": "00FF00",
        "blue": "0080FF",
        "orange": "FFA500",
        "cyan": "00FFFF",
        "magenta": "FF00FF",
        "lime": "32CD32",
        "gold": "FFD700",
        "coral": "FF7F50",
        "skyblue": "87CEEB",
        "purple": "800080",
        "pink": "FF69B4",
        "lightgray": "D3D3D3",
        "warmwhite": "FFFAF0",
        "aqua": "00CED1",
        "salmon": "FA8072",
        "springgreen": "00FF7F",
        "orchid": "DA70D6"
    }
    hex = "E8E8E8"
    if colors[key] <> invalid then hex = colors[key]
    return "0x" + hex + "FF"
end function

function getTimerColorLabel(key as string) as string
    labels = {
        "white": "White",
        "yellow": "Yellow",
        "red": "Red",
        "green": "Green",
        "blue": "Blue",
        "orange": "Orange",
        "cyan": "Cyan",
        "magenta": "Magenta",
        "lime": "Lime",
        "gold": "Gold",
        "coral": "Coral",
        "skyblue": "Sky blue",
        "purple": "Purple",
        "pink": "Pink",
        "lightgray": "Light gray",
        "warmwhite": "Warm white",
        "aqua": "Aqua",
        "salmon": "Salmon",
        "springgreen": "Spring green",
        "orchid": "Orchid"
    }
    if labels[key] <> invalid then return labels[key]
    return "White"
end function

function getTimerColorKeys() as object
    return ["white", "yellow", "red", "green", "blue", "orange", "cyan", "magenta", "lime", "gold", "coral", "skyblue", "purple", "pink", "lightgray", "warmwhite", "aqua", "salmon", "springgreen", "orchid"]
end function

function getNextTimerColorKey(currentKey as string) as string
    keys = getTimerColorKeys()
    for i = 0 to keys.Count() - 1
        if keys[i] = currentKey then
            return keys[(i + 1) mod keys.Count()]
        end if
    end for
    return "white"
end function

sub applyTimerColors()
    if m.timerTitleList <> invalid then m.timerTitleList.color = getTimerColorHex(m.timer_color_title)
    if m.timerClockList <> invalid then m.timerClockList.color = getTimerColorHex(m.timer_color_clock)
    if m.timerCountdownList <> invalid then m.timerCountdownList.color = getTimerColorHex(m.timer_color_countdown)
    if m.timerBodyList <> invalid then m.timerBodyList.color = getTimerColorHex(m.timer_color_body)
    if m.timerAnnouncementsList <> invalid then m.timerAnnouncementsList.color = getTimerColorHex(m.timer_color_announcements)
end sub

sub showTimerSettings()
    m.timerSettingsGroup.visible = true
    m.timerSettingsList.unobserveField("itemSelected")
    m.timerSettingsTitleLabel.text = "Roughstock TV"
    content = CreateObject("roSGNode", "ContentNode")
    content.AppendChild(createModeItem(getTimerPresetLabel(), "cycle_preset"))
    content.AppendChild(createModeItem("Sponsors: " + iif(m.timer_showSponsors, "Yes", "No"), "cycle_sponsors"))
    content.AppendChild(createModeItem("Show current time: " + iif(m.timer_showCurrentTime, "Yes", "No"), "cycle_clock"))
    content.AppendChild(createModeItem("Timer font size: " + getTimerFontSizeLabel(), "cycle_fontsize"))
    content.AppendChild(createModeItem("Title color: " + getTimerColorLabel(m.timer_color_title), "cycle_color_title"))
    content.AppendChild(createModeItem("Clock color: " + getTimerColorLabel(m.timer_color_clock), "cycle_color_clock"))
    content.AppendChild(createModeItem("Timer color: " + getTimerColorLabel(m.timer_color_countdown), "cycle_color_countdown"))
    content.AppendChild(createModeItem("Round line color: " + getTimerColorLabel(m.timer_color_body), "cycle_color_body"))
    content.AppendChild(createModeItem("Announcements color: " + getTimerColorLabel(m.timer_color_announcements), "cycle_color_announcements"))
    content.AppendChild(createModeItem("Round duration: " + Str(m.timer_roundMinutes).Trim() + " min", "cycle_round"))
    content.AppendChild(createModeItem("Rest between rounds: " + Str(m.timer_restSeconds).Trim() + " sec", "cycle_rest"))
    content.AppendChild(createModeItem("Save and Back", "timer_save_back"))
    m.timerSettingsList.content = content
    m.timerSettingsList.observeField("itemSelected", "onTimerSettingSelected")
    m.timerSettingsList.setFocus(true)
end sub

sub closeTimerSettings()
    m.timerSettingsGroup.visible = false
    m.timerSettingsList.unobserveField("itemSelected")
    applyTimerFontSizes()
    applyTimerColors()
    updateTimerDisplay()
    m.top.setFocus(true)
end sub

sub onTimerSettingSelected()
    if m.timerSettingsList.itemSelected = invalid then return
    idx = m.timerSettingsList.itemSelected
    content = m.timerSettingsList.content
    if content = invalid then return
    item = content.getChild(idx)
    if item = invalid then return
    id = item.id
    if id = "cycle_preset" then
        presets = ["custom", "1_10", "2_10", "3_10"]
        for i = 0 to presets.Count() - 1
            if presets[i] = m.timer_preset then
                m.timer_preset = presets[(i + 1) mod presets.Count()]
                exit for
            end if
        end for
        if m.timer_preset = "1_10" then m.timer_roundMinutes = 1 : m.timer_restSeconds = 10
        if m.timer_preset = "2_10" then m.timer_roundMinutes = 2 : m.timer_restSeconds = 10
        if m.timer_preset = "3_10" then m.timer_roundMinutes = 3 : m.timer_restSeconds = 10
        content.getChild(0).title = getTimerPresetLabel()
        content.getChild(9).title = "Round duration: " + Str(m.timer_roundMinutes).Trim() + " min"
        content.getChild(10).title = "Rest between rounds: " + Str(m.timer_restSeconds).Trim() + " sec"
    else if id = "cycle_sponsors" then
        m.timer_showSponsors = not m.timer_showSponsors
        content.getChild(1).title = "Sponsors: " + iif(m.timer_showSponsors, "Yes", "No")
    else if id = "cycle_clock" then
        m.timer_showCurrentTime = not m.timer_showCurrentTime
        content.getChild(2).title = "Show current time: " + iif(m.timer_showCurrentTime, "Yes", "No")
    else if id = "cycle_fontsize" then
        if m.timer_fontSize = "small" then
            m.timer_fontSize = "medium"
        elseif m.timer_fontSize = "medium" then
            m.timer_fontSize = "large"
        else
            m.timer_fontSize = "small"
        end if
        content.getChild(3).title = "Timer font size: " + getTimerFontSizeLabel()
        applyTimerFontSizes()
    else if id = "cycle_color_title" then
        m.timer_color_title = getNextTimerColorKey(m.timer_color_title)
        content.getChild(4).title = "Title color: " + getTimerColorLabel(m.timer_color_title)
        applyTimerColors()
    else if id = "cycle_color_clock" then
        m.timer_color_clock = getNextTimerColorKey(m.timer_color_clock)
        content.getChild(5).title = "Clock color: " + getTimerColorLabel(m.timer_color_clock)
        applyTimerColors()
    else if id = "cycle_color_countdown" then
        m.timer_color_countdown = getNextTimerColorKey(m.timer_color_countdown)
        content.getChild(6).title = "Timer color: " + getTimerColorLabel(m.timer_color_countdown)
        applyTimerColors()
    else if id = "cycle_color_body" then
        m.timer_color_body = getNextTimerColorKey(m.timer_color_body)
        content.getChild(7).title = "Round line color: " + getTimerColorLabel(m.timer_color_body)
        applyTimerColors()
    else if id = "cycle_color_announcements" then
        m.timer_color_announcements = getNextTimerColorKey(m.timer_color_announcements)
        content.getChild(8).title = "Announcements color: " + getTimerColorLabel(m.timer_color_announcements)
        applyTimerColors()
    else if id = "cycle_round" then
        m.timer_preset = "custom"
        arr = [1, 2, 3, 5]
        for i = 0 to arr.Count() - 1
            if arr[i] = m.timer_roundMinutes then
                m.timer_roundMinutes = arr[(i + 1) mod arr.Count()]
                exit for
            end if
        end for
        content.getChild(0).title = getTimerPresetLabel()
        content.getChild(9).title = "Round duration: " + Str(m.timer_roundMinutes).Trim() + " min"
    else if id = "cycle_rest" then
        m.timer_preset = "custom"
        arr = [10, 30, 60, 90]
        for i = 0 to arr.Count() - 1
            if arr[i] = m.timer_restSeconds then
                m.timer_restSeconds = arr[(i + 1) mod arr.Count()]
                exit for
            end if
        end for
        content.getChild(0).title = getTimerPresetLabel()
        content.getChild(10).title = "Rest between rounds: " + Str(m.timer_restSeconds).Trim() + " sec"
    else if id = "timer_save_back" then
        saveTimerSettings()
        applyTimerSettingsToUI()
        closeTimerSettings()
        return
    end if
    applyTimerSettingsToUI()
end sub

sub restartSlideTimer()
    if m.slideTimer.repeat then
        m.slideTimer.control = "stop"
        m.slideTimer.control = "start"
    end if
end sub
