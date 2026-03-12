' TimerRow.brs - one row: title from itemContent.title, font from description, color from scene.timerFontColor
sub init()
    m.rowLabel = m.top.findNode("rowLabel")
    m.top.observeField("itemContent", "onContentSet")
    scene = m.top.getScene()
    if scene <> invalid then scene.observeField("timerFontColor", "onSceneColorChanged")
end sub

sub onSceneColorChanged()
    applyColor()
end sub

sub applyColor()
    content = m.top.itemContent
    if content = invalid then return
    ' Only timer rows (clock, round) use scene font color; title and menu use default
    if content.description = "clock" or content.description = "round" then
        scene = m.top.getScene()
        if scene <> invalid and scene.timerFontColor <> invalid then
            m.rowLabel.color = scene.timerFontColor
        end if
    else
        m.rowLabel.color = &hE8E8E8
    end if
end sub

sub onContentSet()
    content = m.top.itemContent
    if content = invalid then return
    m.rowLabel.text = content.title
    ' description: "clock"=56, "round"=52, "title"=42, "menu"=36, else 40
    sz = 40
    if content.description = "clock" then sz = 56
    if content.description = "round" then sz = 52
    if content.description = "title" then sz = 42
    if content.description = "menu" then sz = 36
    m.rowLabel.font = "size:" + Str(sz).Trim()
    applyColor()
end sub
