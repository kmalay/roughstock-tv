' Minimal timer row: only set Label text from itemContent.title. No scene reference, no extra logic.
sub init()
    m.rowLabel = m.top.findNode("rowLabel")
    m.top.observeField("itemContent", "onContentSet")
end sub

sub onContentSet()
    content = m.top.itemContent
    if content = invalid then return
    m.rowLabel.text = content.title
    ' Per-row font size: title 44, clock 52, phase 48, countdown 56, round 40
    desc = content.description
    if desc = "title" then m.rowLabel.font = "size:44"
    if desc = "clock" then m.rowLabel.font = "size:52"
    if desc = "phase" then m.rowLabel.font = "size:48"
    if desc = "countdown" then m.rowLabel.font = "size:56"
    if desc = "round" then m.rowLabel.font = "size:40"
    content.unobserveField("title")
    content.observeField("title", "onTitleChanged")
end sub

sub onTitleChanged()
    content = m.top.itemContent
    if content <> invalid then m.rowLabel.text = content.title
end sub
