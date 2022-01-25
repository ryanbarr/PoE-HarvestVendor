﻿#NoEnv
#SingleInstance Force
SetBatchLines -1
SetWorkingDir %A_ScriptDir% 
global version := "0.8.2 korean"
#include <class_iAutoComplete>
; === some global variables ===
global outArray := {}
global rescan := ""
global x_start := 0
global y_start := 0
global x_end := 0
global y_end := 0
global firstGuiOpen := True
global outString := ""
global outStyle := 1
global maxLengths := {}
global seenInstructions := 0
global sessionLoading := False
global MaxRowsCraftTable := 20
global CraftTable := []
global needToChangeModel := True
global isLoading := True
global PID := DllCall("Kernel32\GetCurrentProcessId")

EnvGet, dir, USERPROFILE
global RoamingDir := dir . "\AppData\Roaming\PoE-HarvestVendor"

if !FileExist(RoamingDir) {
    FileCreateDir, %RoamingDir%
}

global SettingsPath := RoamingDir . "\settings.ini"
global PricesPath := RoamingDir . "\prices.ini"
global LogPath := RoamingDir . "\log.csv"
global TempPath := RoamingDir . "\temp.txt"

FileEncoding, UTF-8
global Lang := "Korean" ;"English"
global LangDict := {}
langfile := A_ScriptDir . "\" . Lang . ".dict" 
;StringCaseSense, On
Loop, read, %langfile%
{
    obj := StrSplit(Trim(A_LoopReadLine), "=")
    key := obj[1]
    value := obj[2]
    LangDict[key] := value
}
global TessFile := A_ScriptDir . "\Capture2Text\tessdata\configs\poe_kor"
;whitelist := "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ-+%,."
blacklist := ".*:&}"
global Capture2TextExe := "Capture2Text\Capture2Text_CLI.exe"
global Capture2TextOptions := " -o " . TempPath 
    . " -l " . Lang
    ;. " --blacklist """ . blacklist . """"
    ;. " --tess-config-file """ . TessFile . """"
    ;. " --deskew"
    ;. " --whitelist """ . whitelist . """"
    ;. " -b"
    ;. " -d --debug-timestamp"
    ;. " --trim-capture" 
    . " --poe-harvest --level-pattern """ . translate("Level") . """"

global IAutoComplete_Crafts := []
craftListFile := A_ScriptDir . "\craftlist.txt"
global CraftList := []
Loop, read, %craftListFile%
{
    line := Trim(A_LoopReadLine)
    if (line != "") {
        CraftList.push(line)
    }
}
global CraftNames := ["Randomise", "Reforge"
    , "Reroll"
    , "Change", "Enchant"
    , "Attempt", "Set"
    , "Sacrifice", "Improves"
    , "Synthesise", "Remove"
    , "Add2"
    , "Augment", "Fracture"
    , "Corrupt", "Exchange"
    , "Upgrade", "Split"]
; global RegexpTemplateForCraft := "("
; for k, v in CraftNames {
    ; RegexpTemplateForCraft .= translate(v) . "|"
; }
; RegexpTemplateForCraft := RTrim(RegexpTemplateForCraft, "|") . ")"

; detecting mouse button swap
;swapped := DllCall("GetSystemMetrics", UInt, "23")

OnExit("ExitFunc")

tooltip, loading... Initializing Settings
sleep, 250
; == init settings ==
iniRead, MaxRowsCraftTable,  %SettingsPath%, Other, MaxRowsCraftTable
    if (MaxRowsCraftTable == "ERROR" or MaxRowsCraftTable == ""
        or MaxRowsCraftTable < 20 or MaxRowsCraftTable > 40) {
        IniWrite, 20, %SettingsPath%, Other, MaxRowsCraftTable
        IniRead, MaxRowsCraftTable, %SettingsPath%, Other, MaxRowsCraftTable
    }
loop, %MaxRowsCraftTable% {
    CraftTable.push({"count": 0, "craft": "", "price": ""
        , "lvl": "", "type": ""})
}

iniRead, seenInstructions,  %SettingsPath%, Other, seenInstructions
    if (seenInstructions == "ERROR" or seenInstructions == "") {
        IniWrite, 0, %SettingsPath%, Other, seenInstructions
        IniRead, seenInstructions, %SettingsPath%, Other, seenInstructions
    }

IniRead, GuiKey, %SettingsPath%, Other, GuiKey
    checkValidChars := RegExMatch(GuiKey, "[a-zA-Z0-9]") > 0
    if (GuiKey == "ERROR" or GuiKey == "" or !checkValidChars) {
        IniWrite, ^+g, %SettingsPath%, Other, GuiKey
        sleep, 250
        IniRead, GuiKey, %SettingsPath%, Other, GuiKey
        if (!checkValidChars) {
            msgBox, Open GUI hotkey was set to a non latin letter or number, it was reset to ctrl+shift+g
        }
    }
hotkey, %GuiKey%, OpenGui

IniRead, ScanKey, %SettingsPath%, Other, ScanKey
    checkValidChars := RegExMatch(ScanKey, "[a-zA-Z0-9]") > 0
    if (ScanKey == "ERROR" or ScanKey == "" or !checkValidChars) {
        IniWrite, ^g, %SettingsPath%, Other, ScanKey
        sleep, 250
        IniRead, ScanKey, %SettingsPath%, Other, ScanKey
        ;ScanKey == "^g"
        if (!checkValidChars) {
            msgBox, Scan hotkey was set to a non latin letter or number, it was reset to ctrl+g
        }
    }
hotkey, %ScanKey%, Scan

IniRead, outStyle, %SettingsPath%, Other, outStyle
    if (outStyle == "ERROR") {
        IniWrite, 1, %SettingsPath%, Other, outStyle
        outStyle := 1
    }

iniRead tempMon, %SettingsPath%, Other, mon
if (tempMon == "ERROR") { 
    tempMon := 1 
    iniWrite, %tempMon%, %SettingsPath%, Other, mon
}

iniRead, sc, %SettingsPath%, Other, scale
if (sc == "ERROR") {
    iniWrite, 1, %SettingsPath%, Other, scale
}

checkfiles()
winCheck()

tooltip, loading... Checking AHK version
sleep, 250
; == check for ahk version ==
if (A_AhkVersion < 1.1.27.00) {
    MsgBox, Please update your AHK `r`nYour version: %A_AhkVersion%`r`nRequired: 1.1.27.00 or more
}

tooltip, loading... Grabbing active leagues
getLeagues()

menu, Tray, Icon, resources\Vivid_Scalefruit_inventory_icon.png
;Menu, MySubmenu, Add, testLabel
;Menu, Tray, Add, Harvest Vendor, OpenGui
Menu, Tray, NoStandard
Menu, Tray, Add, Harvest Vendor, OpenGui
Menu, Tray, Default, Harvest Vendor
Menu, Tray, Standard

; == preload pictures that are used more than once, for performance
    count_pic := LoadPicture("resources\count.png")
    up_pic := LoadPicture("resources\up.png")
    dn_pic := LoadPicture("resources\dn.png")
    craft_pic := LoadPicture("resources\craft.png")
    lvl_pic := LoadPicture("resources\lvl.png")
    price_pic := LoadPicture("resources\price.png")
    del_pic := LoadPicture("resources\del.png")
; =================================================================

tooltip, loading... building GUI
sleep, 250
newGUI()
tooltip, ready
sleep, 500
Tooltip

if (seenInstructions == 0) {
    goto help
}
isLoading := False
return


ExitFunc(ExitReason, ExitCode) {
    for k, v in IAutoComplete_Crafts {
        v.Disable()
        IAutoComplete_Crafts[k] := ""
    }
    rememberSession()
    saveWindowPosition()
    return 0
}

WinGetPosPlus(winTitle, ByRef xPos, ByRef yPos) {
   hwnd := WinExist(winTitle)
   VarSetCapacity(WP, 44, 0), NumPut(44, WP, "UInt")
   DllCall("User32.dll\GetWindowPlacement", "Ptr", hwnd, "Ptr", &WP)
   xPos := NumGet(WP, 28, "Int") ; X coordinate of the upper-left corner of the window in its original restored state
   yPos := NumGet(WP, 32, "Int") ; Y coordinate of the upper-left corner of the window in its original restored state
}

saveWindowPosition() {
    if (firstGuiOpen) { ;wrong window pos(0,0) if dont show gui before
        return
    }
    winTitle := "PoE-HarvestVendor v" . version
    DetectHiddenWindows, On
    if WinExist(winTitle) {
        ;save window position
        WinGetPosPlus(winTitle, gui_x, gui_y)
        ;WinGetPos, gui_x, gui_y,,, %WinTitle%
        IniWrite, %gui_x%, %SettingsPath%, window position, gui_position_x
        IniWrite, %gui_y%, %SettingsPath%, window position, gui_position_y
    }
    DetectHiddenWindows, Off
}

showGUI() {
    if (firstGuiOpen) {
        firstGuiOpen := False
        IniRead, NewX, %SettingsPath%, window position, gui_position_x
        IniRead, NewY, %SettingsPath%, window position, gui_position_y
        if (NewX == "ERROR" or NewY == "ERROR")
            or (NewX == -32000 or NewY == -32000) {
             Gui, HarvestUI:Show
             return
        } else {
            DetectHiddenWindows, On
            Gui, HarvestUI:Show, Hide
            WinTitle := "PoE-HarvestVendor v" . version
            WinMove, %WinTitle%,, %NewX%, %NewY%
            DetectHiddenWindows, Off
        }
    } 
    Gui, HarvestUI:Show
}

OpenGui: ;ctrl+shift+g opens the gui, yo go from there
    if (isLoading) {
        MsgBox, Please wait until the program is fully loaded
        return
    }
    if (firstGuiOpen) {
        loadLastSession()
    }
    if (version != getVersion()) {
        guicontrol, HarvestUI:Show, versionText
        guicontrol, HarvestUI:Show, versionLink
    }
    showGUI()
    OnMessage(0x200, "WM_MOUSEMOVE")
    
Return

Scan: ;ctrl+g launches straight into the capture, opens gui afterwards
    if (isLoading) {
        MsgBox, Please wait until the program is fully loaded
        return
    }
    rescan := ""
    _wasVisible := IsGuiVisible("HarvestUI")
    if (processCrafts(TempPath)) {
        if (firstGuiOpen) {
            loadLastSession()
        }
        showGUI()
        OnMessage(0x200, "WM_MOUSEMOVE") ;activates tooltip function
        updateCraftTable(outArray)
    } else {
        ; If processCrafts failed (e.g. the user pressed Escape), we should show the
        ; HarvestUI only if it was visible to the user before they pressed Ctrl+G
        if (_wasVisible) {
            if (firstGuiOpen) {
                loadLastSession()
            }
            showGUI()
        }
    }
return

HarvestUIGuiEscape:
HarvestUIGuiClose:
    ;rememberSession()
    saveWindowPosition()
    Gui, HarvestUI:Hide
return

newGUI() {
    Global
    Gui, HarvestUI:New,, PoE-HarvestVendor v%version% 
    ;Gui -DPIScale      ;this will turn off scaling on big screens, which is nice for keeping layout but doesn't solve the font size, and fact that it would be tiny on big screens
    Gui, Color, 0x0d0d0d, 0x1A1B1B
    gui, Font, s11 cFFC555

    xColumn1 := 10
    xColumn2 := xColumn1 + 65
    xColumn3 := xColumn2 + 33 + 5
    xColumn4 := xColumn3 + 300 + 5
    xColumn5 := xColumn4 + 25 + 5
    xColumn6 := xColumn5 + 50 + 5
    xColumn7 := xColumn6 + 15 + 5
    xcolumn8 := xColumn7 + 111 + 5

    xColumnUpDn := xColumn2 + 23

    xEditOffset2 := xColumn2 + 1
    xEditOffset3 := xColumn3 + 3
    xEditOffset4 := xColumn4 + 1
    xEditOffset5 := xColumn5 + 1
    xEditOffset6 := xColumn6 + 1
    xEditOffset7 := xColumn7 + 1
    row := 90

; === Title and icon ===
    title_icon := getImgWidth(A_ScriptDir . "\resources\Vivid_Scalefruit_inventory_icon.png")
    gui add, picture, x10 y10 w%title_icon% h-1, resources\Vivid_Scalefruit_inventory_icon.png
    title := getImgWidth(A_ScriptDir . "\resources\title.png")
    gui add, picture, x%xColumn3% y10 w%title% h-1, resources\title.png
    gui add, text, x380 y15, v%version%
; ======================
; === Text stuff ===
gui, Font, s11 cA38D6D
        gui add, text, x%xColumn3% y40 w70 vValue +BackgroundTrans, You have: 
        gui, Font, s11 cFFC555
        gui add, text, xp+70 y40 w40 right +BackgroundTrans vsumEx, 0
        gui, Font, s11 cA38D6D
        gui add, text, xp+42 y40 w20 +BackgroundTrans, ex 
        gui, Font, s11 cFFC555
        gui add, text, xp+20 y40 w40 right +BackgroundTrans vsumChaos, 0
        gui, Font, s11 cA38D6D
        gui add, text, xp+42 y40 +BackgroundTrans, c 

        gui add, text, x412 y40 w80 vcrafts +BackgroundTrans, Total Crafts:     
        gui, Font, s11 cFFC555
        gui add, text, xp+80 y40 w30 vCraftsSum, 0
        gui, Font, s11 cA38D6D

        gui add, text, x%xColumn3% y64 w40 +BackgroundTrans, Augs:  
        gui, Font, s11 cFFC555
        gui add, text, xp+40 y64 w50 +BackgroundTrans vAcount,0
        gui, Font, s11 cA38D6D

        gui add, text, xp+50 y64 w45 +BackgroundTrans, Rems: 
        gui, Font, s11 cFFC555
        gui add, text, xp+45 y64 w50 +BackgroundTrans vRcount,0
        gui, Font, s11 cA38D6D
        gui add, text, xp+50 y64 w75 +BackgroundTrans, Rem/Adds: 
        gui, Font, s11 cFFC555
        gui add, text, xp+75 y64 w50 +BackgroundTrans vRAcount,0
        gui, Font, s11 cA38D6D
        gui add, text, xp+50 y64 w40 +BackgroundTrans, Other: 
        gui, Font, s11 cFFC555
        gui add, text, xp+40 y64 w50 +BackgroundTrans vOcount,0
        gui, Font, s11 cA38D6D
; ==================
    gui Font, s12
        gui add, text, x460 y10 cGreen vversionText, ! New Version Available !
    ;gui, Font, s11 cFFC555
        gui add, Link, x550 y30 vversionLink c0x0d0d0d, <a href="http://github.com/esge/PoE-HarvestVendor/releases/latest">Github Link</a>
        
    GuiControl, Hide, versionText
    GuiControl, Hide, versionLink
     gui Font, s11
; === Right side ===
   ;y math: row + (23*rowNum)
    
    gui add, checkbox, x%xColumn7% y90 valwaysOnTop gAlwaysOnTop, Always on top
        iniRead tempOnTop, %SettingsPath%, Other, alwaysOnTop
        if (tempOnTop == "ERROR") { 
            tempOnTop := 0 
        }
    guicontrol,,alwaysOnTop, %tempOnTop%
    setWindowState(tempOnTop)
    
    addCrafts := getImgWidth(A_ScriptDir . "\resources\addCrafts.png")
    gui add, picture, x%xColumn7% y114 w%addCrafts% h-1 gAdd_crafts vaddCrafts, resources\addCrafts.png
    lastArea := getImgWidth(A_ScriptDir . "\resources\lastArea.png")
    gui add, picture, x%xColumn7% y137 w%lastArea% h-1 gLast_Area vrescanButton, resources\lastArea.png
    clear := getImgWidth(A_ScriptDir . "\resources\clear.png")
    gui add, picture, x%xColumn7% y160 w%clear% h-1 gClear_All vclearAll, resources\clear.png
    settings := getImgWidth(A_ScriptDir . "\resources\settings.png")
    gui add, picture, x%xColumn7% y183 w%settings% h-1 gSettings vsettings, resources\settings.png
    help := getImgWidth(A_ScriptDir . "\resources\help.png")
    gui add, picture, x%xColumn7% y206 w%help% h-1 gHelp vhelp, resources\help.png

    ; === Post buttons ===
    createPost := getImgWidth(A_ScriptDir . "\resources\createPost.png")
    gui add, picture, x%xColumn7% y251 w%createPost% h-1 vpostAll gPost_all, resources\createPost.png

    ;gui add, picture, x%xColumn7% y251 gAug_post vaugPost, resources\postA.png
    ;gui add, picture, x%xColumn7% y274 gRem_post vremPost, resources\postR.png
    ;gui add, picture, x%xColumn7% y297 gRemAdd_post vremAddPost, resources\postRA.png
    ;gui add, picture, x%xColumn7% y320 gOther_post votherPost, resources\postO.png
    ;gui add, picture, x%xColumn7% y343 vpostAll gPost_all, resources\postAll.png
    ;    postAll_TT := "WARNING: Don't use this for Temporary SC league on TFT Discord"

    ; === League dropdown ===
    gui add, text, x%xColumn7% y370, League:
    gui add, dropdownList, x%xColumn7% y389 w115 -E0x200 +BackgroundTrans vleague gLeague_dropdown
        leagueList()

    ; === can stream ===
    iniRead tempStream, %SettingsPath%, Other, canStream
    if (tempStream == "ERROR") { 
        tempStream := 0 
    }
    gui add, checkbox, x%xColumn7% y419 vcanStream gCan_stream, Can stream
    guicontrol,,canStream, %tempStream%

    ; === IGN ===
    IniRead, name, %SettingsPath%, IGN, n
    if (name == "ERROR") {
        name := ""
    }
    gui add, text, x%xColumn7% y440, IGN: 
        ign := getImgWidth(A_ScriptDir . "\resources\ign.png")
        gui add, picture, x%xColumn7% y458 w%ign% h-1, resources\ign.png
        gui, Font, s11 cA38D6D
            Gui Add, Edit, x%xEditOffset7% y459 w113 h18 -E0x200 +BackgroundTrans vign gIGN, %name%
        gui, Font, s11 cFFC555

    ; === custom text checkbox ===
    iniRead tempCustomTextCB, %SettingsPath%, Other, customTextCB
    if (tempCustomTextCB == "ERROR") { 
        tempCustomTextCB := 0 
    }
    gui add, checkbox, x%xColumn7% y485 vcustomText_cb gCustom_text_cb, Custom Text: 
        guicontrol,,customText_cb, %tempCustomTextCB%
    ; ============================
    ; === custom text input ===
        text := getImgWidth(A_ScriptDir . "\resources\text.png")
        gui add, picture,  x%xColumn7% y504 w%text% h-1, resources\text.png
        iniRead tempCustomText, %SettingsPath%, Other, customText
        if (tempCustomText == "ERROR") { 
            tempCustomText := "" 
        }
        tempCustomText := StrReplace(tempCustomText, "||", "`n") ;support multilines in custom text
        gui, Font, s11 cA38D6D
            Gui Add, Edit, x%xEditOffset7% y505 w113 h65 -E0x200 +BackgroundTrans vcustomText gCustom_text -VScroll, %tempCustomText%
        gui, Font, s11 cFFC555
    ; ============================
    ;gui add, picture, x%xColumn7% y366, resources\leagueHeader.png
; ===============================================================================
    
; === table headers ===
    gui add, text, x%xColumn1% y%row% w60 +Right, Type
    count_beautyOffset := xColumn2 + 5
    gui add, text, x%count_beautyOffset% y%row%, #
    gui add, text, x%xColumn3% y%row%, Crafts
    gui add, text, x%xColumn4% y%row%, LvL
    gui add, text, x%xColumn5% y%row%, Price

; === table ===
    count_ := getImgWidth(A_ScriptDir . "\resources\count.png")
    craft_ := getImgWidth(A_ScriptDir . "\resources\craft.png")
    lvl_ := getImgWidth(A_ScriptDir . "\resources\lvl.png")  
    price_ := getImgWidth(A_ScriptDir . "\resources\price.png")
    del_ := getImgWidth(A_ScriptDir . "\resources\del.png")
    loop, %MaxRowsCraftTable% {
        row2 := row + 23 * A_Index
        row2p := row2 + 1
        row2dn := row2 + 10
        row2del := row2 + 5
        ;gui add, picture, x%xColumn1% y%row2%, resources\type.png
        gui, Font, s11 cA38D6D
            gui add, text, x%xColumn1% y%row2% vtype_%A_Index% gType w60 Right,
        gui, Font, s11 cFFC555
        
        gui add, picture, x%xColumn2% y%row2% w%count_% h-1 AltSubmit , % "HBITMAP:*" count_pic ;resources\count.png
            Gui Add, Edit, x%xEditOffset2% y%row2p% w35 h18 vcount_%A_Index% gCount -E0x200 +BackgroundTrans Center
                Gui Add, UpDown, Range0-20 vupDown_%A_Index%, 0
                guicontrol, hide, upDown_%A_Index%
            gui add, picture, x%xColumnUpDn% y%row2p% gUp vUp_%A_Index%, % "HBITMAP:*" up_pic
            gui add, picture, x%xColumnUpDn% y%row2dn% gDn vDn_%A_Index%, % "HBITMAP:*" dn_pic

        gui add, picture, x%xColumn3% y%row2% w%craft_% h-1 AltSubmit , % "HBITMAP:*" craft_pic ;resources\craft.png
            gui add, edit, x%xEditOffset3% y%row2p% w295 h18 -E0x200 +BackgroundTrans vcraft_%A_Index% gcraft HwndhCraft_%A_Index%
            ia_craft := IAutoComplete_Create(hCraft_%A_Index%, CraftList
                , ["WORD_FILTER", "AUTOSUGGEST"], True)
            IAutoComplete_Crafts.push(ia_craft)

        gui add, picture, x%xColumn4% y%row2% w%lvl_% h-1 AltSubmit , % "HBITMAP:*" lvl_pic ;resources\lvl.png
            gui add, edit, x%xEditOffset4% y%row2p% w23 h18 -E0x200 +BackgroundTrans Center vlvl_%A_Index% glvl

        gui add, picture, x%xColumn5% y%row2% w%price_% h-1 AltSubmit , % "HBITMAP:*" price_pic ; resources\price.png
            gui add, edit, x%xEditOffset5% y%row2p% w44 h18 -E0x200 +BackgroundTrans Center vprice_%A_Index% gPrice

        gui add, picture, x%xColumn6% y%row2del% w%del_% h-1 vdel_%A_Index% gclearRow AltSubmit , % "HBITMAP:*" del_pic ;resources\del.png 
    }
    gui, font    
    gui temp:hide
}


; === Button actions ===
Up:
    GuiControlGet, cntrl, name, %A_GuiControl%
    tempRow := getRow(cntrl)
    CraftTable[tempRow].count := CraftTable[tempRow].count + 1
    updateUIRow(tempRow, "count") ;GuiControl,, count_%tempRow%, %tempCount%
    sumTypes()
    sumPrices()
return

Dn:
    GuiControlGet, cntrl, name, %A_GuiControl%
    tempRow := getRow(cntrl)
    tempCount := CraftTable[tempRow].count
    if (tempCount > 0) {
        CraftTable[tempRow].count := tempCount - 1
        updateUIRow(tempRow, "count") ;GuiControl,, count_%tempRow%, %tempCount%
        sumTypes()
        sumPrices()
    }
return

Add_crafts: 
    buttonHold("addCrafts", "resources\addCrafts")
    GuiControlGet, rescan, name, %A_GuiControl% 
    if (processCrafts(TempPath)) {
        updateCraftTable(outArray)
    }
    showGUI()
return

Last_area:
    buttonHold("rescanButton", "resources\lastArea")
    goto Add_crafts
return

Clear_all:
    buttonHold("clearAll", "resources\clear")
    clearAll()
    sumTypes()
    sumPrices()
return

Count:
    oldCount := CraftTable[tempRow].count
    GuiControlGet, cntrl, name, %A_GuiControl%
    tempRow := getRow(cntrl)
    guiControlGet, newCount,, count_%tempRow%, value
    if (oldCount == newCount) {
        return
    }
    if (needToChangeModel) {
        CraftTable[tempRow].count := newCount
    }
    sumTypes()
    sumPrices()
return

craft:
    oldCraft := CraftTable[tempRow].craft
    GuiControlGet, cntrl, name, %A_GuiControl%
    tempRow := getRow(cntrl)
    guiControlGet, newCraft,, craft_%tempRow%, value
    if (oldCraft == newCraft) {
        return
    }
    if (needToChangeModel) {
        CraftTable[tempRow].craft := newCraft
        CraftTable[tempRow].Price := getPriceFor(newCraft)
        CraftTable[tempRow].type := getTypeFor(newCraft)
        updateUIRow(tempRow, "price")
        updateUIRow(tempRow, "type")
    }
    sumTypes()
return

lvl:
    if (!needToChangeModel) {
        return
    }
    GuiControlGet, cntrl, name, %A_GuiControl%
    tempRow := getRow(cntrl)
    guiControlGet, tempLvl,, lvl_%tempRow%, value
    CraftTable[tempRow].lvl := tempLvl
return

type:
    
return

Price:
    oldPrice := CraftTable[tempRow].price
    GuiControlGet, cntrl, name, %A_GuiControl%
    tempRow := getRow(cntrl)
    guiControlGet, newPrice,, price_%tempRow%, value
    if (oldPrice == newPrice) {
        return
    }
    if (needToChangeModel) {
        CraftTable[tempRow].price := newPrice
        craftName := CraftTable[tempRow].craft
        if (craftName != "") {
            iniWrite, %newPrice%, %PricesPath%, Prices, %craftName%
        }
    }
    sumPrices()
return

Can_stream:
    guiControlGet, strim,,canStream, value
    iniWrite, %strim%, %SettingsPath%, Other, canStream
return

IGN:
    guiControlGet, lastIGN,,IGN, value
    iniWrite,  %lastIGN%, %SettingsPath%, IGN, n
return

Custom_text:
    guiControlGet, cust,,customText, value
    cust := StrReplace(cust, "`n", "||") ;support multilines in custom text
    iniWrite, %cust%, %SettingsPath%, Other, customText
    guicontrol,, customText_cb, 1

    ;if (RegExMatch(cust, "not|remove|aug|add") > 0) {
    ;   gui, Font, cRed Bold
    ;   guiControl, font, customText
    ;   tooltip, This message might get blocked by the discord bot because it containts not|remove|aug|add
    ;} else {
    ;   gui, Font, s11 cA38D6D norm 
    ;   guicontrol, font, customText
    ;   tooltip
    ;}
return

Custom_text_cb:
    guiControlGet, custCB,,customText_cb, value
    iniWrite, %custCB%, %SettingsPath%, Other, CustomTextCB
return

ClearRow:
    GuiControlGet, cntrl, name, %A_GuiControl%
    tempRow := getRow(cntrl)

    IniRead selLeague, %SettingsPath%, selectedLeague, s

    if GetKeyState("Shift") {
        row := CraftTable[tempRow]
        IniRead, league, %SettingsPath%, selectedLeague, s
        fileLine := A_YYYY . "-" . A_MM . "-" . A_DD . ";" . A_Hour . ":" . A_Min . ";" . league . ";" . row.craft . ";" . row.price . "`r`n"

        FileAppend, %fileLine%, %LogPath%
        if (row.count > 1) {
            CraftTable[tempRow].count := row.count - 1
        } else {
            clearRowData(tempRow)
            ;sortCraftTable()
        }
    } else {
        clearRowData(tempRow)
        ;sortCraftTable()
    }
    updateUIRow(tempRow)
    sumTypes()
    sumPrices()
return

; Aug_Post:
    ; buttonHold("augPost", "resources\postA")
    ; createPost("Aug")
; return

; Rem_post:
    ; buttonHold("remPost", "resources\postR")
    ; createPost("Rem")
; return

; RemAdd_post:
    ; buttonHold("remAddPost", "resources\postRA")
    ; createPost("Rem/Add")
; return

; Other_post:
    ; buttonHold("otherPost", "resources\postO")
    ; createPost("Other")
; return

Post_all:
    ;buttonHold("postAll", "resources\postAll")
    buttonHold("postAll", "resources\createPost")

    ;guiControlGet, selectedLeague,, League, value
    ;if !(InStr(selectedLeague, "HC") > 0 or InStr(selectedLeague, "Hardcore") > 0 or InStr(selectedLeague, "Standard") > 0){
    ;   msgbox, You are posting All for Temporary SC league `r`nTFT has split channels based on craft types`r`nThis message will get you timed out
    ;}

    createPost("All")
return

League_dropdown:
    guiControlGet, selectedLeague,,League, value
    iniWrite, %selectedLeague%, %SettingsPath%, selectedLeague, s
    ;allowAll()
return

alwaysOnTop:
    guiControlGet, onTop,,alwaysOnTop, value
    iniWrite, %onTop%, %SettingsPath%, Other, alwaysOnTop
    setWindowState(onTop)
return

setWindowState(onTop) {
    mod := (onTop == 1) ? "+" : "-"
    Gui, HarvestUI:%mod%AlwaysOnTop
}
;====================================================
; === Settings UI ===================================
settings:
    iniRead tempMon, %SettingsPath%, Other, mon 
    buttonHold("settings", "resources\settings")
    hotkey, %GuiKey%, off
    hotkey, %ScanKey%, off
    gui Settings:new,, PoE-HarvestVendor - Settings
    gui, add, Groupbox, x5 y5 w400 h90, Message formatting
        Gui, add, text, x10 y25, Output message style:
        Gui, add, dropdownList, x120 y20 w30 voutStyle goutStyle, 1|2
        iniRead, tstyle, %SettingsPath%, Other, outStyle
        guicontrol, choose, outStyle, %tstyle%
        Gui, add, text, x20 y50, 1 - No Colors, No codeblock = Words are highlighted when using discord search
        Gui, add, text, x20 y70, 2 - Codeblock, Colors = Words aren't highlighetd when using discord search

    gui, add, Groupbox, x5 y110 w400 h100, Monitor Settings
        monitors := getMonCount()
        Gui add, text, x10 y130, Select monitor:
        Gui add, dropdownList, x85 y125 w30 vMonitors_v gMonitors, %monitors%
            global Monitors_v_TT := "For when you aren't running PoE on main monitor"
        guicontrol, choose, Monitors_v, %tempMon%

        gui, add, text, x10 y150, Scale 
        iniRead, tScale,  %SettingsPath%, Other, scale
        gui, add, edit, x85 y150 w30 vScale gScale, %tScale% 
        Gui, add, text, x20 y175, - use this when you are using Other than 100`% scale in windows display settings
        Gui, add, text, x20 y195, - 100`% = 1, 150`% = 1.5 and so on

    gui, add, groupbox, x5 y215 w400 h75, Hotkeys       
        Gui, add, text, x10 y235, Open Harvest vendor: 
        iniRead, GuiKey,  %SettingsPath%, Other, GuiKey
        gui,add, hotkey, x120 y230 vGuiKey_v gGuiKey_l, %GuiKey%
        
        Gui, add, text, x10 y260, Add crafts: 
        iniRead, ScanKey,  %SettingsPath%, Other, ScanKey
        gui, add, hotkey, x120 y255 vScanKey_v gScanKey_l, %ScanKey%

    
    gui, add, button, x10 y295 h30 w390 gOpenRoaming vSettingsFolder, Open Settings Folder
    gui, add, button, x10 y335 h30 w390 gSettingsOK, Save
    gui, Settings:Show, w410 h370
    
return

SettingsGuiClose:
    hotkey, %GuiKey%, on
    hotkey, %ScanKey%, on
    Gui, Settings:Destroy
    Gui, HarvestUI:Default
return

GuiKey_l:
return

ScanKey_l:
return

OpenRoaming:
    explorerpath := "explorer " RoamingDir
    Run, %explorerpath%
return

outStyle:
    guiControlGet, os,,outStyle, value
    iniWrite, %os%, %SettingsPath%, Other, outStyle
return

Monitors:
    guiControlGet, mon,,Monitors_v, value
    iniWrite, %mon%, %SettingsPath%, Other, mon
return

Scale:
    guiControlGet, sc,,Scale, value
    iniWrite, %sc%, %SettingsPath%, Other, scale
return

SettingsOK:
    iniRead, GuiKey,  %SettingsPath%, Other, GuiKey
    iniRead, ScanKey,  %SettingsPath%, Other, ScanKey

    guiControlGet, gk,, GuiKey_v, value
    guiControlGet, sk,, ScanKey_v, value

    if (GuiKey != gk and gk != "ERROR" and gk != "") {
        hotkey, %GuiKey%, off
        iniWrite, %gk%, %SettingsPath%, Other, GuiKey
        hotkey, %gk%, OpenGui
    } 
            
    if (ScanKey != sk and sk != "ERROR" and sk != "") {
        hotkey, %ScanKey%, off
        iniWrite, %sk%, %SettingsPath%, Other, ScanKey
        hotkey, %sk%, Scan
    } 

    if (gk != "ERROR" and gk != "") {
        hotkey, %gk%, on
    } else {
        hotkey, %GuiKey%, on
    }

    if (sk != "ERROR" and sk != "") {
        hotkey, %sk%, on
    } else {
        hotkey, %ScanKey%, on
    }

    Gui, Settings:Destroy
    Gui, HarvestUI:Default
return
;====================================================
; === Help UI =======================================
help:
    buttonHold("help", "resources\help")
    IniWrite, 1, %SettingsPath%, Other, seenInstructions 
    gui Help:new,, PoE-HarvestVendor Help

gui, font, s14
    Gui, add, text, x5 y5, Step 1
    gui, add, text, x5 y80, Step 2
    gui, add, text, x5 y380, Step 3
    Gui, add, text, x5 y450, Step 4
gui, font

gui, font, s10
;step 1
    gui, add, text, x15 y30, Default Hotkey to open the UI = Ctrl + Shift + G`r`nDefault Hotkey to start capture = Ctrl + G`r`nHotkeys can be changed in settings

;step 2 
    gui, add, text, x15 y110, Start the capture by either clicking Add Crafts button, `r`nor pressing the Capture hotkey.`r`nSelect the area with crafts:
    Gui, Add, ActiveX, x5 y120 w290 h240 vArea, Shell2.Explorer
    Area.document.body.style.overflow := "hidden"
    Edit := WebPic(Area, "https://github.com/esge/PoE-HarvestVendor/blob/master/examples/snapshotArea_s.png?raw=true", "w250 h233 cFFFFFF")
    gui, add, text, x15 y365, this can be done repeatedly to add crafts to the list

;step 3 
    gui, add, text, x15 y410, Fill in the prices (they will be remembered)`r`nand other info like: Can stream, IGN and so on if you wish to
    ;Gui, Add, ActiveX, x5 y430 w350 h100 vPricepic, Shell2.Explorer
    ;Pricepic.document.body.style.overflow := "hidden"
    ;Edit := WebPic(Pricepic, "https://github.com/esge/PoE-HarvestVendor/blob/master/examples/price.png?raw=true", "w298 h94 cFFFFFF")
    
;step 4
    gui, add, text, x15 y480 w390, click: Post Augments/Removes... for the set you want to post`r`nNow your message is in clipboard`r`nCareful about Post All on TFT discord, it has separate channels for different craft types.
    

    gui, add, text, x400 y10 h590 0x11  ;Vertical Line > Etched Gray

    gui, font, s14 cRed
    Gui, Add, text, x410 y10 w380, Important:
    
    gui, font, s10
    gui, add, text, x420 y30 w370, If you are using Big resolution (more than 1080p) and have scaling for display set in windows to more than 100`% (in Display settings)`r`nYou need to go into Settings in HarvestVendor and set Scale to match whats set in windows
    gui, font, s14 cBlack

    gui, add, text, x410 y110 w380, Hidden features
    gui, font, s10
    gui, add, text, x420 y130 w370, - Holding shift while clicking the X in a row will reduce the count by 1 and also write the craft and price into log.csv (you can find it through the Settings folder button in Settings)
    gui, font
    Gui, Help:Show, w800 h610
return

HelpGuiClose:
    Gui, Help:Destroy
    Gui, HarvestUI:Default
return

; === my functions ===
translate(keyword) {
    ;Lang
    if (LangDict.HasKey(keyword)) {
        return LangDict[keyword]
    }
    return keyword
}

TagExist(text, tag) {
    return InStr(text, tag) > 0
}

TemplateExist(text, template) {
    return RegExMatch(text, template) > 0
}

Handle_Augment(craftText, ByRef out) {
    mod := TemplateExist(craftText, translate("Lucky")) ? " Lucky" : ""
    if TemplateExist(craftText, translate("non-Influenced")) {
        augments := ["Caster"
            , "Physical"
            , "Fire"
            , "Attack"
            , "Life"
            , "Cold"
            , "Speed"
            , "Defence"
            , "Lightning"
            , "Chaos"
            , "Critical"
            , "a new modifier"]
        for k, v in augments {
            if TemplateExist(craftText, translate(v)) {
                out.push(["Augment non-influenced - " . v . mod
                        , getLVL(craftText)
                        , "Aug"])
                return
            }
        }
        return
    }
    out.push(["Augment Influence" . mod
        , getLVL(craftText)
        , "Aug"])
}

Handle_Remove(craftText, ByRef out) {
    if TemplateExist(craftText, translate("Influenced")) {
        if TemplateExist(craftText, translate("add")) {
            removes := ["Caster", "Physical", "Fire", "Attack", "Life", "Cold"
                , "Speed", "Defence", "Lightning", "Chaos", "Critical"]
            mod := TemplateExist(craftText, translate("non")) ? "non-" : ""
            for k, v in removes {
                if TemplateExist(craftText, translate(v)) {
                    out.push(["Remove " . mod . v . " add " . v
                        , getLVL(craftText)
                        , "Other"])
                    return
                }
            }
        } else {
            augments := ["Caster", "Physical", "Fire", "Attack", "Life", "Cold"
                , "Speed", "Defence", "Lightning", "Chaos", "Critical", "a new modifier"]
            for k, v in augments {
                if TemplateExist(craftText, translate(v)) {
                    out.push(["Remove " . v
                        , getLVL(craftText)
                        , "Rem"])
                    return
                }
            }
        }
        return
    }
    if TemplateExist(craftText, translate("add")) {
        mod := TemplateExist(craftText, translate("non")) ? "non-" : ""
        out.push(["Remove " . mod . "Influence add Influence"
            , getLVL(craftText)
            , "Rem"])
    } else {
        out.push(["Remove Influence"
            , getLVL(craftText)
            , "Rem"])
    }
}

Handle_Reforge(craftText, ByRef out) {
    ;prefixes
    if TemplateExist(craftText, translate("Prefix")) {
        mod := TemplateExist(craftText, translate("Lucky")) ? " Lucky" : ""
        out.push(["Reforge keep Prefixes" . mod
            , getLVL(craftText)
            , "Other"])
        return
    }
    ;suffixes
    if TemplateExist(craftText, translate("Suffix")) {
        mod := TemplateExist(craftText, translate("Lucky")) ? " Lucky" : ""
        out.push(["Reforge keep Suffixes" . mod
            , getLVL(craftText)
            , "Other"])
        return
    }
    ; reforge rares
    remAddsClean := ["Caster"
        , "Physical"
        , "Fire"
        , "Attack"
        , "Life"
        , "Cold"
        , "Speed"
        , "Defence"
        , "Lightning"
        , "Chaos"
        , "Critical"
        , "Influence"]
    if TemplateExist(craftText, translate("including")) { ; 'including' text appears only in reforge rares
        for k, v in remAddsClean {
            if TemplateExist(craftText, translate(v)) {
                mod := TemplateExist(craftText, translate("more")) ? " more common" : ""
                out.push(["Reforge Rare - " . v . mod
                        , getLVL(craftText)
                        , "Other"])
                return
            }
        }
        return
    } 
    ; reforge white/magic - removed in 3.16, was combined with reforge rare
    ;else if (InStr(craftText, "Normal or Magic") > 0) {
    ;   for k, v in remAddsClean {
    ;       if (InStr(craftText, v) > 0) {
    ;           out.push(["Reforge Norm/Magic - " . v
    ;               , getLVL(craftText)
    ;               , "Other"]
    ;           return
    ;       }
    ;   }
    ;} 
    ;reforge same mod
    if TemplateExist(craftText, translate("less likely")) {
        out.push(["Reforge Rare - Less Likely"
            , getLVL(craftText)
            , "Other"])
        return
    }
    if TemplateExist(craftText, translate("more likely")) {
        out.push(["Reforge Rare - More Likely"
            , getLVL(craftText)
            , "Other"])
        return
    }
    if TemplateExist(craftText, translate("10 times")) {
        ;Reforge the links between sockets/links on an item 10 times
        return
    }
    ;links
    if TemplateExist(craftText, translate("links")) {
        if TemplateExist(craftText, translate("six")) {
            out.push(["Six link (6-link)"
                , getLVL(craftText)
                , "Other"])
        } else if TemplateExist(craftText, translate("five")) {
            out.push(["Five link (5-link)"
                , getLVL(craftText)
                , "Other"])
        }
        return
    }
    ;colour
    if TemplateExist(craftText, translate("colour")) {
        if TemplateExist(craftText, translate("non")) {
            reforgeNonColor := ["Red", "Blue", "Green"]
            for k, v in reforgeNonColor {
                if TemplateExist(craftText, translate(v)) {
                    out.push(["Reforge Colour: non-" . v . " into " . v
                        , getLVL(craftText)
                        , "Other"])
                    return
                } 
            }
            return
        }
        if TemplateExist(craftText, translate("White")) {
            out.push(["Reforge Colour: into White"
                    , getLVL(craftText)
                    , "Other"])
            return
        }
        redVal := TemplateExist(craftText, translate("Red"))
        blueVal := TemplateExist(craftText, translate("Blue"))
        greenVal := TemplateExist(craftText, translate("Green"))
        if (redVal and blueVal and greenVal) {
            out.push(["Reforge Colour: into Red, Blue and Green"
                    , getLVL(craftText)
                    , "Other"])
            return
        }
        if (redVal and blueVal) {
            out.push(["Reforge Colour: into Red and Blue"
                    , getLVL(craftText)
                    , "Other"])
            return
        }
        if (redVal and greenVal) {
            out.push(["Reforge Colour: into Red and Green"
                    , getLVL(craftText)
                    , "Other"])
            return
        }
        if (blueVal and greenVal) {
            out.push(["Reforge Colour: into Blue and Green"
                    , getLVL(craftText)
                    , "Other"])
            return
        }
        return
    }
    if (TemplateExist(craftText, translate("Influence"))
        and TemplateExist(craftText, translate("more"))) {
        out.push(["Reforge with Influence mod more common"
            , getLVL(craftText)
            , "Other"])
        return
    }
}

Handle_Enchant(craftText, ByRef out) {
    ;weapon
    if TemplateExist(craftText, translate("Weapon")) {
        weapEnchants := ["Critical Strike Chance", "Accuracy", "Attack Speed"
            , "+1 Weapon Range", "Elemental Damage", "Area of Effect"]
        for k, enchant in weapEnchants {
            if TemplateExist(craftText, translate(enchant)) {
                ; OCR was failing to detect "Elemental Damage" properly, but "Elemental" is unique enough for detection, just gotta add "damage" for the output
                ;tempEnch := (enchant == "Elemental") ? "Elemental Damage" : enchant
                out.push(["Enchant Weapon: " . enchant
                    , getLVL(craftText)
                    , "Other"])
                return
            }
        }
        return
    }
    ;body armour
    if TemplateExist(craftText, translate("Armour")) { 
        bodyEnchants := ["Maximum Life", "Maximum Mana", "Strength", "Dexterity"
            , "Intelligence", "Fire Resistance", "Cold Resistance", "Lightning Resistance"]
        for k, bodyEnchant in bodyEnchants {
            if TemplateExist(craftText, translate(bodyEnchant)) {
                out.push(["Enchant Body: " . bodyEnchant
                    , getLVL(craftText)
                    , "Other"])
                return
            }
        }
        return
    }
    ;Map
    if TemplateExist(craftText, translate("Sextant")) {
        out.push(["Enchant Map: no Sextant use"
            , getLVL(craftText)
            , "Other"])
        return
    }
    ;flask
    if TemplateExist(craftText, translate("Flask")) {
        flaskEnchants := {"Duration": "inc", "Effect": "inc"
            , "Maximum Charges": "inc", "Charges used": "reduced"}
        for flaskEnchant, mod in flaskEnchants {
            if TemplateExist(craftText, translate(flaskEnchant)) {
                out.push(["Enchant Flask: " . mod . " " . flaskEnchant
                    , getLVL(craftText)
                    , "Other"])
                return
            }
        }
        return
    }
    if TemplateExist(craftText, translate("Tormented")) {
        out.push(["Enchant Map: surrounded by Tormented Spirits"
            , getLVL(craftText)
            , "Other"])
        return
    }
}

Handle_Attempt(craftText, ByRef out) {
    ;awaken
    if TemplateExist(craftText, translate("Awaken")) {
        out.push(["Attempt to Awaken a level 20 Support Gem"
            , getLVL(craftText)
            , "Other"])
        return
    }
    ;scarab upgrade
    if TemplateExist(craftText, translate("Scarab")) { 
        out.push(["Attempt to upgrade a Scarab"
            , getLVL(craftText)
            , "Other"])
        return
    }
}

Handle_Change(craftText, ByRef out) {
    ; res mods
    if TemplateExist(craftText, translate("Resistance")) {
        firePos := RegExMatch(craftText, translate("Fire"))
        coldPos := RegExMatch(craftText, translate("Cold"))
        lightPos := RegExMatch(craftText, translate("Lightning"))
        rightMostPos := max(firePos, coldPos, lightPos)
        if (rightMostPos == firePos) {
            if (coldPos > 0) {
                out.push(["Change Resist: Cold to Fire"
                    , getLVL(craftText)
                    , "Other"])
            } else if (lightPos > 0) {
                out.push(["Change Resist: Lightning to Fire"
                    , getLVL(craftText)
                    , "Other"])
            }
        } else if (rightMostPos == coldPos) {
            if (firePos > 0) {
                out.push(["Change Resist: Fire to Cold"
                    , getLVL(craftText)
                    , "Other"])
            } else if (lightPos > 0) {
                out.push(["Change Resist: Lightning to Cold"
                    , getLVL(craftText)
                    , "Other"])
            }
        } else if (rightMostPos == lightPos) {
            if (firePos > 0) {
                out.push(["Change Resist: Fire to Lightning"
                    , getLVL(craftText)
                    , "Other"])
            } else if (coldPos > 0) {
                out.push(["Change Resist: Cold to Lightning"
                    , getLVL(craftText)
                    , "Other"])
            }
        }
        return
    }
    if (TemplateExist(craftText, translate("Bestiary")) 
        or TemplateExist(craftText, translate("Lures"))) {
        out.push(["Change Unique Bestiary item or item with Aspect into Lures"
            , getLVL(craftText)
            , "Other"])
        return
    }
    if TemplateExist(craftText, translate("Delirium")) {
        out.push(["Change a stack of Delirium Orbs"
            , getLVL(craftText)
            , "Other"])
        return
    } 
    ; ignore others ?
}

Handle_Sacrifice(craftText, ByRef out) {
    ;gem for gcp/xp
    if TemplateExist(craftText, translate("Gem")) {
        gemPerc := ["20%", "30%", "40%", "50%"]
        for k, v in gemPerc {
            if TemplateExist(craftText, v) {
                if TemplateExist(craftText, translate("quality")) {
                    out.push(["Sacrifice gem, get " . v . " qual as GCP"
                        , getLVL(craftText)
                        , "Other"])
                } else if TemplateExist(craftText, translate("experience")) {
                    out.push(["Sacrifice gem, get " . v . " exp as Lens"
                        , getLVL(craftText)
                        , "Other"])
                }
                return
            }
        }
        return
    }
    ;div cards gambling
    if TemplateExist(craftText, translate("Divination")) { 
        if TemplateExist(craftText, translate("half a stack")) {
            out.push(["Sacrifice half stack for 0-2x return"
                , getLVL(craftText)
                , "Other"])
        }
        return
        ;skipping this:
        ;   Sacrifice a stack of Divination Cards for that many different Divination Cards
    }
    ;ignores the rest of sacrifice crafts:
        ;Sacrifice or Mortal Fragment into another random Fragment of that type
        ;Sacrificie Maps for same or lower tier stuff
        ;Sacrifice maps for missions
        ;Sacrifice maps for map device infusions
        ;Sacrifice maps for fragments
        ;Sacrifice maps for map currency
        ;Sacrifice maps for scarabs
        ;sacrifice t14+ map for elder/shaper/synth map
        ;sacrifice weap/ar to make similiar belt/ring/amulet/jewel
}

Handle_Improves(craftText, ByRef out) {
    if TemplateExist(craftText, translate("Flask")) {
        out.push(["Improves the Quality of a Flask"
            , getLVL(craftText)
            , "Other"])
        return
    }
    if TemplateExist(craftText, translate("Gem")) {
        out.push(["Improves the Quality of a Gem"
            , getLVL(craftText)
            , "Other"])
        return
    }
}

Handle_Fracture(craftText, ByRef out) {
    fracture := {"modifier": "1/5", "Suffix": "1/3", "Prefix": "1/3"}
    for k, v in fracture {
        if TemplateExist(craftText, translate(k)) {
            out.push(["Fracture " . v . " " . k
                , getLVL(craftText)
                , "Other"])
            return
        }
    }
}

Handle_Reroll(craftText, ByRef out) {
    prefVal := TemplateExist(craftText, translate("Prefix"))
    suffVal := TemplateExist(craftText, translate("Suffix"))
    ;if RegExMatch(craftText, translate("Implicit")) > 0 {
    if (prefVal and suffVal) {
        out.push(["Reroll All Lucky"
            , getLVL(craftText)
            , "Other"])
        return  
    }
    if (suffVal) {
        out.push(["Reroll Suffix Lucky"
            , getLVL(craftText)
            , "Other"])
        return
    }
    if (prefVal) {
        out.push(["Reroll Prefix Lucky"
            , getLVL(craftText)
            , "Other"])
        return
    }
}

Handle_Randomise(craftText, ByRef out) {
    if TemplateExist(craftText, translate("Influence")) { 
        addInfluence := ["Weapon", "Armour", "Jewellery"]
        for k, v in addInfluence {
            if TemplateExist(craftText, translate(v)) {
                out.push(["Randomise Influence - " . v
                    , getLVL(craftText)
                    , "Other"])
                return
            }
        }
        if TemplateExist(craftText, translate("numeric values")) {
            out.push(["Randomise the numeric values of the random Influence modifiers"
                , getLVL(craftText)
                , "Other"])
        }
        return
    }
    augments := ["Caster", "Physical", "Fire", "Attack", "Life", "Cold"
        , "Speed", "Defence", "Lightning", "Chaos", "Critical", "a new modifier"]
    for k, v in augments {
        if TemplateExist(craftText, translate(v)) {
            out.push(["Randomise values of " . v . " mods"
                , getLVL(craftText)
                , "Other"])
            return
        }
    }
}

Handle_Add(craftText, ByRef out) {
    addInfluence := ["Weapon", "Armour", "Jewellery"]
    for k, v in addInfluence {
        if TemplateExist(craftText, translate(v)) {
            out.push(["Add Influence to " . v
                , getLVL(craftText)
                , "Other"])
            return
        }
    }
}

Handle_Set(craftText, ByRef out) {
    if TemplateExist(craftText, translate("Prismatic")) {
        out.push(["Set Implicit Basic Jewel"
            , getLVL(craftText)
            , "Other"])
        return
    }
    if (TemplateExist(craftText, translate("Timeless")) 
        or TemplateExist(craftText, translate("Abyss"))) {
        out.push(["Set Implicit Abyss/Timeless Jewel"
            , getLVL(craftText)
            , "Other"])
        return
    }
    if TemplateExist(craftText, translate("Cluster")) {
        out.push(["Set Implicit Cluster Jewel"
            , getLVL(craftText)
            , "Other"])
        return
    }
}

Handle_Synthesise(craftText, ByRef out) {
    out.push(["Synthesise an item"
        , getLVL(craftText)
        , "Other"])
}

Handle_Corrupt(craftText, ByRef out) {
    ;Corrupt an item 10 times, or until getting a corrupted implicit modifier
}

Handle_Exchange(craftText, ByRef out) {
    ;skipping all exchange crafts assuming anybody would just use them for themselfs
}

Handle_Upgrade(craftText, ByRef out) {
    if TemplateExist(craftText, translate("Normal")) {
        if TemplateExist(craftText, translate("one random ")) {
            out.push(["Upgrade Normal to Magic adding 1 high-tier mod"
                , getLVL(craftText)
                , "Other"])
        } else if TemplateExist(craftText, translate("two random ")) {
            out.push(["Upgrade Normal to Magic adding 2 high-tier mods"
                , getLVL(craftText)
                , "Other"])
        }
        return
    }
    if TemplateExist(craftText, translate("Rare")) {
        mods := {"two random modifiers" : "Upgrade Magic to Rare adding 2 mods"
            , "two random high-tier modifiers": "Upgrade Magic to Rare adding 2 high-tier mods"
            , "three random modifiers" : "Upgrade Magic to Rare adding 3 mods"
            , "three random high-tier modifiers": "Upgrade Magic to Rare adding 3 high-tier mods"
            , "four random modifiers" : "Upgrade Magic to Rare adding 4 mods"
            , "four random high-tier modifiers": "Upgrade Magic to Rare adding 4 high-tier mods"}
        for k, v in mods {
            if TemplateExist(craftText, translate(k)) {
                out.push([v
                    , getLVL(craftText)
                    , "Other"])
                return
            }
        }
        return
    }
    ;skipping upgrade crafts
}

Handle_Split(craftText, ByRef out) {
    ;skipping Split scarab craft
}

getCraftLines(temp) {
    craftsText := Trim(RegExReplace(temp, " +", " "))
    arr := {}
    arr := StrSplit(craftsText, "||")
    ;MsgBox, % arr.Length()
    return arr
}

getCraftsPlus(craftsText, levelsText) {
    ;template := ;"Leve[l1]"
    tempLevels := RegExReplace(levelsText, translate("Level"), "#$1")
    tempLevels := SubStr(tempLevels, inStr(tempLevels, "#") + 1)
    ArrayedLevels := StrSplit(tempLevels, "#")
    
    ;craftsText := RegExReplace(craftsText, "[\.\,]+", " ") ;remove all "," and "."
    ;craftsText := RegExReplace(craftsText, " +?[^a1234567890] +?", " ") ;remove all single symbols except "a" and digits
    craftsText := Trim(RegExReplace(craftsText, " +", " ")) ;remove possible double spaces    
    ;NewLined := RegExReplace(craftsText, TemplateForCrafts, "#$1")
    ;NewLined := SubStr(NewLined, inStr(NewLined, "#") + 1) ; remove all before "#" and "#" too
    
    NewLined := SubStr(craftsText, InStr(craftsText, "||") + 1) ; remove first "||"
    
    arr := {}
    arr := StrSplit(NewLined, "||")
    for index in arr {
        level := ArrayedLevels.HasKey(index) ? " " . ArrayedLevels[index] : ""
        arr[index] := arr[index] . level
    }
    return arr
}

; === my functions ===
processCrafts(file) {
    ; the file parameter is just for the purpose of running a test script with different input files of crafts instead of doing scans
    Gui, HarvestUI:Hide    

    if ((rescan == "rescanButton" and x_start == 0) or rescan != "rescanButton" ) {
        coordTemp := SelectArea("cffc555 t50 ms")
        if (!coordTemp or coordTemp.Length() == 0)
            return false

        x_start := coordTemp[1]
        y_start := coordTemp[3]
        x_end := coordTemp[2]
        y_end := coordTemp[4]
    }
    WinActivate, Path of Exile
    sleep, 500
    Tooltip, Please Wait, x_end, y_end
    
    screen_rect := " -s """ . x_start . " " . y_start . " " 
        . x_end . " " . y_end . """"
    ; aspectRatioForLevel := 0.18
    ; areaWidthLevel := Floor(aspectRatioForLevel * (x_end - x_start)) ; area width "Level"
    ; x_areaLevelStart := x_end - areaWidthLevel ; starting X-position "Level"
    ; screen_rect_Craft := " -s """ . x_start . " " . y_start . " " 
        ; . x_areaLevelStart . " " . y_end . """" ; 82% of the area for "Craft"
    ; screen_rect_Level := " -s """ . x_areaLevelStart . " " . y_start . " " 
    ; . x_end . " " . y_end . """" ;  18% of the area for "Level"
    ;temp := {}
    ;mod := ""
    ;for k, v in [screen_rect_Level, screen_rect_Craft] {
        command := Capture2TextExe . screen_rect . Capture2TextOptions ;. mod
        RunWait, %command% ;,,Hide
        if !FileExist(TempPath) {
            MsgBox, - We were unable to create temp.txt to store text recognition results.`r`n- The tool most likely doesnt have permission to write where it is.`r`n- Moving it into a location that isnt write protected, or running as admin will fix this.
            return false
        }
        FileRead, curtemp, %file%
        ; if (k == 1) {
            ; tempLevels := RegExReplace(curtemp, translate("Level"), "#$1")
            ; tempLevels := SubStr(tempLevels, inStr(tempLevels, "#") + 1)
            ; ArrayedLevels := StrSplit(tempLevels, "#")
            ; mod := " --count-pieces " . ArrayedLevels.Length()
        ; }
        ; temp.push(curtemp)
    ;}
    WinActivate, ahk_pid %PID%
    Tooltip
    ;add craftsText and levelsText in temp.txt
    ;FileDelete, %file%
    ;FileAppend, % temp[2] . temp[1], %file%

    Arrayed := getCraftLines(curtemp) ;getCraftsPlus(temp[2], temp[1])
    outArray := {}
    ;outArrayCount := 0
    for index in Arrayed {  
        craftText := Trim(Arrayed[index])
        if (craftText == "") {
            continue ;skip empty fields
        }
        for k, v in CraftNames {
            newK := translate(v)
            if TemplateExist(craftText, newK) {
                if IsFunc("Handle_" . v) {
                    ;MsgBox, %v%, %newK%
                    Handle_%v%(craftText, outArray)
                }
                break
            }
        }
    }
    for iFinal, v in outArray {
        outArray[iFinal, 1] := Trim(RegExReplace(v[1] , " +", " ")) 
    }   
    ;this bit is for testing purposes, it should never trigger for normal user cos processCrafts is always run with temp.txt 
    if (file != TempPath) {
        for s in outArray {
            str .= outArray[s, 1] . "`r`n"
        }
        path := "results\out-" . file
        FileAppend, %str%, %path%
    }
    return true
}

updateCraftTable(ar) { 
    tempC := ""
    ;isNeedSort := False
    for k, v in ar {   
        tempC := v[1]
        tempLvl := v[2] 
        tempType := v[3]

        loop, %MaxRowsCraftTable% {
            craftInGui := CraftTable[A_Index].craft
            lvlInGui := CraftTable[A_Index].lvl
            if (craftInGui == tempC and lvlInGui == tempLvl) {
                CraftTable[A_Index].count := CraftTable[A_Index].count + 1
                updateUIRow(A_Index, "count")
                break
            }
            if (craftInGui == "") {
                insertIntoRow(A_Index, tempC, tempLvl, tempType)
                updateUIRow(A_Index)
                ;isNeedSort := True
                break
            }
        }
    }
    ;if (isNeedSort) {
    ;    sortCraftTable()
    ;}
    sumTypes()
    sumPrices()
}

sortCraftTable() {
    craftsArr := []
    loop, %MaxRowsCraftTable% {
        row := CraftTable[A_Index]
        if (row.craft != "") { ;not empty crafts
            craftsArr.push(row)
        }
    }
    craftsArr := sortBy(craftsArr, "craft")
    ;insert a new sorted crafts
    for k in CraftTable {
        if (craftsArr.HasKey(k)) {
            CraftTable[k] := craftsArr[k]
        } else {
            ;clear old crafts
            clearRowData(k)
        }
        updateUIRow(k)
    }
}

detectType(craft, row) {
    if (craft == "") {
        guicontrol,, type_%row%,
        return
    } 
    if (inStr(craft, "Augment") = 1 ) {
        guicontrol,, type_%row%, Aug
        return
    } 
    if (InStr(craft, "Remove") = 1 and instr(craft, "add") = 0) {
        guicontrol,, type_%row%, Rem
        return
    } 
    if (inStr(craft, "Remove") = 1 and instr(craft, "add") > 0 
        and instr(craft, "non") = 0) {
        guicontrol,, type_%row%, Rem/Add
        return
    }
    guicontrol,, type_%row%, Other
}

getTypeFor(craft) {
    if (craft == "") {
        return ""
    } 
    if (inStr(craft, "Augment") = 1 ) {
        return "Aug"
    } 
    if (InStr(craft, "Remove") = 1 and instr(craft, "add") = 0) {
        return "Rem"
    } 
    if (inStr(craft, "Remove") = 1 and instr(craft, "add") > 0 
        and instr(craft, "non") = 0) {
        return "Rem/Add"
    }
    return "Other"
}

insertIntoRow(rowCounter, craft, lvl, type) {    
    tempP := getPriceFor(craft)
    CraftTable[rowCounter] := {"count": 1, "craft": craft, "price": tempP
            , "lvl": lvl, "type": type}
}

updateUIRow(rowCounter, parameter:="All") {
    row := CraftTable[rowCounter]
    needToChangeModel := False
    if (parameter == "All") {
        GuiControl,HarvestUI:, craft_%rowCounter%, % row.craft
        GuiControl,HarvestUI:, count_%rowCounter%, % row.count
        GuiControl,HarvestUI:, lvl_%rowCounter%, % row.lvl
        GuiControl,HarvestUI:, type_%rowCounter%, % row.type
        GuiControl,HarvestUI:, price_%rowCounter%, % row.price
    } else {
        if (row.HasKey(parameter)) {
            GuiControl,HarvestUI:, %parameter%_%rowCounter%, % row[parameter]
        }
    }
    needToChangeModel := True
}

; === Discord message creation ===
; createPostRow(count, craft, price, group, lvl) {
    ; ;IniRead, outStyle, %SettingsPath%, Other, outStyle
    ; mySpaces := ""
    ; spacesCount := 0
    ; price := (price == "") ? " " : price

    ; spacesCount := MaxLen - StrLen(craft) + 1

    ; loop, %spacesCount% {
        ; mySpaces .= " "
    ; }

    ; if (outStyle == 1) { ; no colors, no codeblock, but highlighted
        ; outString .= "   ``" . count . "x ``**``" . craft . "``**``" . mySpaces . "[" . lvl . "]" 
        ; if (price == " ") {
            ; outString .= " <``**``" . price . "``**``>"
        ; }
        ; outString .= "```r`n"
    ; }

    ; if (outStyle == 2) { ; message style with colors, in codeblock but text isnt highlighted in discord search
        ; outString .= "  " . count . "x [" . craft . mySpaces . "]" . "[" . lvl . "]" 
        ; if (price != " ") {
            ; outString .= " < " . price . " >"
        ; }
        ; outString .= "`r`n"
    ; }
; }

;added by Stregon#3347
;=============================================================================
getPostRow(count, craft, price, group, lvl) {
    ;IniRead, outStyle, %SettingsPath%, Other, outStyle
    postRowString := ""
    mySpaces := ""
    spacesCount := 0
    price := (price == "") ? " " : price
    
    loop, % (maxLengths.count - StrLen(count) + 1) {
        spaces_count_craft .= " "
    }
    loop, % (maxLengths.craft - StrLen(craft) + 1) {
        spaces_craft_lvl .= " "
    }
    loop, % (maxLengths.lvl - StrLen(lvl) + 2) {
        spaces_lvl_price .= " "
    }

    if (outStyle == 1) { ; no colors, no codeblock, but highlighted
        postRowString .= "   ``" . count . "x" . spaces_count_craft . "``**``" . craft . "``**``" . spaces_craft_lvl . "[" . lvl . "]" 
        if (price != " ") {
            postRowString .= spaces_lvl_price . "<``**``" . price . "``**``>"
        }
        postRowString .= "```r`n"
    }

    if (outStyle == 2) { ; message style with colors, in codeblock but text isnt highlighted in discord search
        postRowString .= "  " . count . "x" . spaces_count_craft . "[" . craft . spaces_craft_lvl . "]" . "[" . lvl . "]" 
        if (price != " ") {
            postRowString .= spaces_lvl_price . "< " . price . " >"
        }
        postRowString .= "`r`n"
    }
    return postRowString
}

getSortedPosts(type) {
    posts := ""
    postsArr := []
    loop, %MaxRowsCraftTable% {
        row := CraftTable[A_Index]
        if ((row["count"] != "" and row["count"] > 0)
            and (row["type"] == type or type == "All")) {
            postsArr.push(row)
        }
    }
    postsArr := sortBy(postsArr, ["count", "craft"])
    for Index, row in postsArr {
        posts .= getPostRow(row["count"], row["craft"], row["price"]
            , row["type"], row["lvl"])
    }
    return posts
}

getPosts(type) {
    posts := ""
    loop, %MaxRowsCraftTable% {
        row := CraftTable[A_Index]
        if ((row["count"] != "" and row["count"] > 0)
            and (row["type"] == type or type == "All")) {
            posts .= getPostRow(row["count"], row["craft"], row["price"]
                , row["type"], row["lvl"])
        }
    }
    return posts
}

_clone(param_value) {
    if (isObject(param_value)) {
        return param_value.Clone()
    } else {
        return param_value
    }
}

_cloneDeep(param_array) {
    Objs := {}
    Obj := param_array.Clone()
    Objs[&param_array] := Obj ; Save this new array
    for key, value in Obj {
        if (isObject(value)) ; if it is a subarray
            Obj[key] := Objs[&value] ; if we already know of a refrence to this array
            ? Objs[&value] ; Then point it to the new array
            : _clone(value) ; Otherwise, clone this sub-array
    }
    return Obj
}

_internal_sort(param_collection, param_iteratees:="") {
    l_array := _cloneDeep(param_collection)

    ; associative arrays
    if (param_iteratees != "") {
        for Index, obj in l_array {
            value := obj[param_iteratees]
            if (!isNumber(value)) {
                value := StrReplace(value, "+", "#")
            }
            out .= value "+" Index "|" ; "+" allows for sort to work with just the value
            ; out will look like: value+index|value+index|
        }
        lastvalue := l_array[Index, param_iteratees]
    } else {
        ; regular arrays
        for Index, obj in l_array {
            value := obj
            if (!isNumber(obj)) {
                value := StrReplace(value, "+", "#")
            }
            out .= value "+" Index "|"
        }
        lastvalue := l_array[l_array.count()]
    }

    if (isNumber(lastvalue)) {
        sortType := "N"
    }
    stringTrimRight, out, out, 1 ; remove trailing |
    sort, out, % "D| " sortType
    arrStorage := []
    loop, parse, out, |
    {
        arrStorage.push(l_array[SubStr(A_LoopField, InStr(A_LoopField, "+") + 1)])
    }
    return arrStorage
}

sortBy(param_collection, param_iteratees:="__identity") {
    l_array := []

    ; create
    ; no param_iteratees
    if (param_iteratees == "__identity") {
        return _internal_sort(param_collection)
    }
    ; property
    if (isAlnum(param_iteratees)) {
        return _internal_sort(param_collection, param_iteratees)
    }
    ; own method or function
    ; if (isCallable(param_iteratees)) {
        ; for key, value in param_collection {
            ; l_array[A_Index] := {}
            ; l_array[A_Index].value := value
            ; l_array[A_Index].key := param_iteratees.call(value)
        ; }
        ; l_array := _internal_sort(l_array, "key")
        ; return this.map(l_array, "value")
    ; }
    ; shorthand/multiple keys
    if (isObject(param_iteratees)) {
        l_array := _cloneDeep(param_collection)
        ; sort the collection however many times is requested by the shorthand identity
        for key, value in param_iteratees {
            l_array := _internal_sort(l_array, value)
        }
        return l_array
    }
    return -1
}

isAlnum(param) {
    if (isObject(param)) {
        return false
    }
    if param is alnum
    {
        return true
    }
    return false
}

; isCallable(param) {
    ; fn := numGet(&(_ := Func("InStr").bind()), "Ptr")
    ; return (isFunc(param) || (isObject(param) && (numGet(&param, "Ptr") = fn)))
; }

isNumber(param) {
    if (isObject(param)) {
        return false
    }
    if param is number
    {
        return true
    }
    return false
}
;=============================================================================

codeblockWrap(text) {
    if (outStyle == 1) {
        return text
    }
    if (outStyle == 2) {
        return "``````md`r`n" . text . "``````"
    }
}

;puts together the whole message that ends up in clipboard
createPost(type) {
    IniRead, outStyle, %SettingsPath%, Other, outStyle
    tempName := ""
    GuiControlGet, tempLeague,, League, value
    GuiControlGet, tempName,, IGN, value
    GuiControlGet, tempStream,, canStream, value
    GuiControlGet, tempCustomText,, customText, value
    GuiControlGet, tempCustomTextCB,, customText_cb, value
    
    tempLeague := RegExReplace(tempLeague, "SC", "Softcore")
    tempLeague := RegExReplace(tempLeague, "HC", "Hardcore")
    outString := ""
    ;getMaxLenghts(type)
    
    ;added by Stregon#3347
    maxLengths := {}
    maxLengths.count := getMaxLenghtColunm("count")
    maxLengths.craft := getMaxLenghtColunm("craft")
    maxLengths.lvl := getMaxLenghtColunm("lvl")
    
    if (outStyle == 1) {
        outString .= "**WTS " . tempLeague . "**"
        if (tempName != "") {
            tempName := RegExReplace(tempName, "\\*?_", "\_") ;fix for discord
            outString .= " - IGN: **" . tempName . "**" 
        }
        outString .= " ``|  generated by HarvestVendor v" . version . "```r`n"
        if (tempCustomText != "" and tempCustomTextCB == 1) {
            outString .= "   " . tempCustomText . "`r`n"
        }
        if (tempStream == 1 ) {
            outString .= "   *Can stream if requested*`r`n"
        }
    }
    if (outStyle == 2) {
        outString .= "#WTS " . tempLeague
        if (tempName != "") {
            outString .= " - IGN: " . tempName
        }
        outString .= " |  generated by HarvestVendor v" . version . "`r`n"
        if (tempCustomText != "" and tempCustomTextCB == 1) {
            outString .= "  " . tempCustomText . "`r`n"
        }
        if (tempStream == 1 ) {
            outString .= "  Can stream if requested `r`n"
        }
    }
    outString .= getPosts(type) ;getSortedPosts(type)
    Clipboard := codeblockWrap(outString)
    readyTT()
}

readyTT() {
    ClipWait
    ToolTip, Paste Ready,,,1
    sleep, 2000
    Tooltip,,,,1
}

; getRowData(group, row) {
    ; GuiControlGet, tempType,, type_%row%, value
    ; GuiControlGet, tempCount,, count_%row%, value
    ; GuiControlGet, tempCraft,, craft_%row%, value
    ; GuiControlGet, tempPrice,, price_%row%, value
    ; GuiControlGet, tempLvl,, lvl_%row%, value
    ; tempCheck := 0
    ; if (tempCount > 0 and tempCraft != "") {
        ; tempCheck := 1
    ; }
    ; return [tempCount, tempCraft, tempPrice, tempCheck, tempType, tempLvl]
; }

getMaxLenghtColunm(column) {
    MaxLen_column := 0
    loop, %MaxRowsCraftTable% {
        tempCount := CraftTable[A_Index].count
        if (tempCount <= 0) {
            continue
        }
        columnValue := CraftTable[A_Index][column] 
        if (StrLen(columnValue) > MaxLen_column) {
            MaxLen_column := StrLen(columnValue)
        }
    }
    return MaxLen_column
}
;============================================================
getPriceFor(craft) {
    if (craft == "") {
        return ""
    }
    while (True) {
        iniRead, tempP, %PricesPath%, Prices, %craft%
        if (tempP == "ERROR") {
            return ""
        }
        if (tempP != "") {
            return tempP
        }
        ;Delete craft with blank price
        iniDelete, %PricesPath%, Prices, %craft%
    }
}

getRow(elementVariable) {
    temp := StrSplit(elementVariable, "_")
    return temp[temp.Length()]
}

getLVL(craft) {
    map_levels := {"S1": "81", "Sz": "82", "SQ": "80", "8i": "81"}
    template := "O)" . translate("Level") . " *(\d\d)" ;"Oi)L[BEeOo]V[BEeOo][lI1] *(\w\w)"
    lvlpos := RegExMatch(craft, template, matchObj) ; + 6    
    lv := matchObj[2] ;substr(craft, lvlpos, 2)
    if RegExMatch(lv, "\d\d") > 0 {
        if (lv < 37) { ;ppl wouldn't sell lv 30 crafts, but sometimes OCR mistakes 8 for a 3 this just bumps it up for the 76+ rule
            lv += 50
        }
        return lv > 86 ? "" : lv
    } else {
        for k, v in map_levels {
            if (k == lv) {
                return v
            }
        }
        return ""
    }
}

sumPrices() {
    tempSumChaos := 0
    tempSumEx := 0
    exaltTemplate := "Oi)^(\d*[\.,]{0,1}?\d+) *(ex|exa|exalt)$"
    chaosTemplate := "Oi)^(\d+) *(c|ch|chaos)$"
    loop, %MaxRowsCraftTable% {
        craftRow := CraftTable[A_Index]
        if (craftRow.craft == "" or craftRow.price == "") {
            continue
        }
        priceCraft := Trim(craftRow.price)
        countCraft := craftRow.count
        
        if (RegExMatch(priceCraft, chaosTemplate, matchObj) > 0) {
            priceCraft := strReplace(matchObj[1], ",", ".")
            tempSumChaos +=  priceCraft * countCraft
        }
        
        if (RegExMatch(priceCraft, exaltTemplate, matchObj) > 0) {
            priceCraft := strReplace(matchObj[1], ",", ".")
            tempSumEx += priceCraft * countCraft
        }
    }
    tempSumEx := round(tempSumEx, 1)
    GuiControl,,sumChaos, %tempSumChaos%
    GuiControl,,sumEx, %tempSumEx%
}

sumTypes() {
    Acounter := 0
    Rcounter := 0
    RAcounter := 0
    Ocounter := 0
    Allcounter := 0
    loop, %MaxRowsCraftTable% {
        tempAmount := CraftTable[A_Index].count
        if (tempAmount == "") {
            continue
        }
        tempType := CraftTable[A_Index].type
        if (tempType == "Aug") {
            Acounter += tempAmount
        }
        if (tempType == "Rem") {
            Rcounter += tempAmount
        }
        if (tempType == "Rem/Add") {
            RAcounter += tempAmount
        }
        if (tempType == "Other") {
            Ocounter += tempAmount
        }       
    }
    Allcounter := Acounter + Rcounter + RAcounter + Ocounter
    Guicontrol,, Acount, %Acounter%
    Guicontrol,, Rcount, %Rcounter%
    Guicontrol,, RAcount, %RAcounter%
    Guicontrol,, Ocount, %Ocounter%
    Guicontrol,, CraftsSum, %Allcounter%
    ;sleep, 50
    ;if (Acounter = 0) {
    ;    guicontrol,, augPost, resources/postA_d.png
    ;} else {
    ;    guicontrol,, augPost, resources/postA.png
    ;}
    ;if (Rcounter = 0) {
    ;    guicontrol,, remPost, resources/postR_d.png
    ;} else {
    ;    guicontrol,, remPost, resources/postR.png
    ;}
    ;if (RAcounter = 0) {
    ;    guicontrol,, remAddPost, resources/postRA_d.png
    ;} else {
    ;    guicontrol,, remAddPost, resources/postRA.png
    ;}
    ;if (Ocounter = 0) {
    ;    guicontrol,, otherPost, resources/postO_d.png
    ;} else {
    ;    guicontrol,, otherPost, resources/postO.png
    ;}
}

buttonHold(buttonV, picture) {
    while GetKeyState("LButton", "P") {
        guiControl,, %buttonV%, %picture%_i.png 
        sleep, 25
    }
    guiControl,, %buttonV%, %picture%.png
}

allowAll() {
    IniRead selLeague, %SettingsPath%, selectedLeague, s
    if (selLeague == "ERROR") {
        GuiControlGet, selLeague,, LeagueDropdown, value
    }
    if (InStr(selLeague, "Standard") = 0 and InStr(selLeague, "Hardcore") = 0 ) {
        guicontrol, Disable, postAll
    } else {
        guicontrol, Enable, postAll
    }
}

rememberCraft(row) {
    rowCraft := CraftTable[row]
    craftName := rowCraft.craft
    craftLvl := rowCraft.lvl
    crafCount := rowCraft.count
    craftType := rowCraft.type
    blank := ""
    if (craftName != "") {
        IniWrite, %craftName%|%craftLvl%|%crafCount%|%craftType%, %SettingsPath%, LastSession, craft_%row%
    } else {
        IniWrite, %blank%, %SettingsPath%, LastSession, craft_%row%
    }
}

rememberSession() { 
    if (!sessionLoading) { 
        loop, %MaxRowsCraftTable% { 
            rememberCraft(A_Index)
        }
    }
}

loadLastSessionCraft(row) { 
    IniRead, lastCraft, %SettingsPath%, LastSession, craft_%row% 
    if (lastCraft != "" and lastCraft != "ERROR") {
        split := StrSplit(lastCraft, "|")
        craft := split[1]
        lvl := split[2]
        ccount := split[3]
        type := split[4]

        tempP := getPriceFor(craft)
        if (type == "") {
            type := getTypeFor(craft)
        }
        CraftTable[row] := {"count": ccount, "craft": craft, "price": tempP
            , "lvl": lvl, "type": type}
    }
}

loadLastSession() {
    sessionLoading := True
    loop, %MaxRowsCraftTable% {
        loadLastSessionCraft(A_Index)
        updateUIRow(A_Index)
    }
    sessionLoading := False
    sumTypes()
    sumPrices()
}

clearRowData(rowIndex) {
    CraftTable[rowIndex] := {"count": 0, "craft": "", "price": ""
        , "lvl": "", "type": ""}
}

clearAll() {
    loop, %MaxRowsCraftTable% {
        clearRowData(A_Index)
        updateUIRow(A_Index)
    }
    outArray := {}
    ;outArrayCount := 0
    ;arr := []
}
; === technical stuff i guess ===
getLeagues() {
    leagueAPIurl := "http://api.pathofexile.com/leagues?type=main&compact=1" 
    
    if FileExist("curl.exe") {
        ; Hack for people with outdated certificates
        shell := ComObjCreate("WScript.Shell")
        exec := shell.Exec("curl.exe -k " . leagueAPIurl)
        response := exec.StdOut.ReadAll()       
    } else {
        oWhr := ComObjCreate("WinHttp.WinHttpRequest.5.1")
        oWhr.Open("GET", leagueAPIurl, false)
        oWhr.SetRequestHeader("Content-Type", "application/json")    
        oWhr.Send()
        response := oWhr.ResponseText
    }
    if (oWhr.Status == "200" or FileExist("curl.exe")) {
        if InStr(response, "Standard") > 0 {
            parsed := Jxon_load(response) 
            for k, v in parsed {
                if (k > 8) { ;take first 8
                    break
                }
                tempParse := v["id"]
                iniWrite, %tempParse%, %SettingsPath%, Leagues, %k%
            }
        } else {
            IniRead, lc, %SettingsPath%, Leagues, 1
            if (lc == "ERROR" or lc == "") {
                msgbox, Unable to get list of leagues from GGG API`r`nYou will need to copy [Leagues] and [selectedLeague] sections from the example settings.ini on github
            }
        }

        if !FileExist(SettingsPath) {
            MsgBox, Looks like AHK was unable to create settings.ini`r`nThis might be because the place you have the script is write protected by Windows`r`nYou will need to place this somewhere else
        }
    } else {
        Msgbox, Unable to get active leagues from GGG API, using placeholder names
        iniWrite, Temp, %SettingsPath%, Leagues, 1
        iniWrite, Hardcore Temp, %SettingsPath%, Leagues, 2
        iniWrite, Standard, %SettingsPath%, Leagues, 3
        iniWrite, Hardcore, %SettingsPath%, Leagues, 4
    }
}

leagueList() {
    leagueString := ""
    loop, 8 {
        IniRead, tempList, %SettingsPath%, Leagues, %A_Index%     
        if (templist != "") {      
            if InStr(tempList, "Hardcore") = 0 and InStr(tempList, "HC") = 0 {
                tempList .= " SC"
            } 
            if (tempList == "Hardcore") {
                tempList := "Standard HC"
            }
            if InStr(tempList,"SSF") = 0 {
                leagueString .= tempList . "|"
            }
            if (InStr(tempList, "Hardcore", true) = 0 and InStr(tempList,"SSF", true) = 0 
                and InStr(tempList,"Standard", true) = 0 and InStr(tempList,"HC", true) = 0) {
                defaultLeague := templist
            }
        }
    }

    iniRead, leagueCheck, %SettingsPath%, selectedLeague, s
    guicontrol,, League, %leagueString%
    if (leagueCheck == "ERROR") {
        guicontrol, choose, League, %defaultLeague%
        iniWrite, %defaultLeague%, %SettingsPath%, selectedLeague, s    
    } else {
        guicontrol, choose, League, %leagueCheck%   
    }
}

getVersion() {
    versionUrl :=  "https://raw.githubusercontent.com/Stregon/PoE-HarvestVendor/master/version.txt"
    if FileExist("curl.exe") {
        ; Hack for people with outdated certificates
        shell := ComObjCreate("WScript.Shell")
        exec := shell.Exec("curl.exe -k " . versionUrl)
        response := exec.StdOut.ReadAll()
    } else {
        ver := ComObjCreate("WinHttp.WinHttpRequest.5.1")
        ver.Open("GET", versionUrl, false)
        ver.SetRequestHeader("Content-Type", "application/json")
        ver.Send()
        response := ver.ResponseText
    }
    return StrReplace(StrReplace(response,"`r"),"`n")
}

IsGuiVisible(guiName) {
    Gui, %guiName%: +HwndguiHwnd
    return DllCall("User32\IsWindowVisible", "Ptr", guiHwnd)
}

checkFiles() {
    if !FileExist("Capture2Text") {
        if FileExist("Capture2Text.exe") {
            msgbox, Looks like you put PoE-HarvestVendor.ahk into the Capture2Text folder `r`nThis is wrong `r`nTake the file out of this folder
        } else {
            msgbox, I don't see the Capture2Text folder, did you download the tool ? `r`nLink is in the GitHub readme under Getting started section
        }
        ExitApp
    }   
    
    if !FileExist(SettingsPath) {
        msgbox, Looks like you put PoE-HarvestVendor in a write protected place on your PC.`r`nIt needs to be able to create and write into a few text files in its directory.
        ExitApp
    }
}

winCheck() {
    if (SubStr(A_OSVersion,1,2) != "10" and !FileExist("curl.exe")) {
         msgbox, Looks like you aren't running win10. There might be a problem with WinHttpRequest(outdated Certificates).`r`nYou need to download curl, and place the curl.exe (just this 1 file) into the same directory as Harvest Vendor.`r`nLink in the FAQ section in readme on github
    }
}

monitorInfo(num) {
   SysGet, Mon2, monitor, %num%
  
   x := Mon2Left
   y := Mon2Top
   height := abs(Mon2Top - Mon2Bottom)
   width := abs(Mon2Left - Mon2Right)

   return [x, y, height, width]
}

getMonCount() {
   monOut := ""
   sysGet, monCount, MonitorCount
   loop, %monCount% {
      monOut .= A_Index . "|"
   }
   return monOut
}

getImgWidth(img) {
    SplitPath, img, fn, dir
    objShell := ComObjCreate("Shell.Application")
    objFolder := objShell.NameSpace(dir)
    objFolderItem := objFolder.ParseName(fn)
    scale := StrSplit(RegExReplace(objFolder.GetDetailsOf(objFolderItem, 31), ".(.+).", "$1"), " x ")
    Return scale.1 ; {w: scale.1, h: scale.2}
}

; ========================================================================
; ======================== stuff i copied from internet ==================
; ========================================================================

global SelectAreaEscapePressed := false
SelectAreaEscape:
    SelectAreaEscapePressed := true
return

SelectArea(Options="") { ; by Learning one
/*
Returns selected area. Return example: 22|13|243|543
Options: (White space separated)
- c color. Default: Blue.
- t transparency. Default: 50.
- g GUI number. Default: 99.
- m CoordMode. Default: s. s = Screen, r = Relative
*/
;full screen overlay
;press Escape to cancel

    iniRead tempMon, %SettingsPath%, Other, mon
    iniRead, scale, %SettingsPath%, Other, scale
    cover := monitorInfo(tempMon)
    coverX := cover[1]
    coverY := cover[2]
    coverH := cover[3] / scale
    coverW := cover[4] / scale
    Gui, Select:New
    Gui, Color, 141414
    Gui, +LastFound +ToolWindow -Caption +AlwaysOnTop
    WinSet, Transparent, 120
    Gui, Select:Show, x%coverX% y%coverY% h%coverH% w%coverW%, "AutoHotkeySnapshotApp"


    isLButtonDown := false
    SelectAreaEscapePressed := false
    Hotkey, Escape, SelectAreaEscape, On
    while (!isLButtonDown and !SelectAreaEscapePressed) {
        ; Per documentation new hotkey threads can be launched while KeyWait-ing, so SelectAreaEscapePressed
        ; will eventually be set in the SelectAreaEscape hotkey thread above when the user presses ESC.

        KeyWait, LButton, D T0.1  ; 100ms timeout
        isLButtonDown := (ErrorLevel == 0)
    }

    areaRect := []
    if (!SelectAreaEscapePressed) {
        CoordMode, Mouse, Screen
        MouseGetPos, MX, MY
        CoordMode, Mouse, Relative
        MouseGetPos, rMX, rMY
        CoordMode, Mouse, Screen

        loop, parse, Options, %A_Space% 
        {
            Field := A_LoopField
            FirstChar := SubStr(Field, 1, 1)
            if (FirstChar contains c,t,g,m) {
                StringTrimLeft, Field, Field, 1
                %FirstChar% := Field
            }
        }
        c := (c = "") ? "Blue" : c
        t := (t = "") ? "50" : t
        g := (g = "") ? "99" : g
        m := (m = "") ? "s" : m

        Gui %g%: Destroy
        Gui %g%: +AlwaysOnTop -Caption +Border +ToolWindow +LastFound
        WinSet, Transparent, %t%
        Gui %g%: Color, %c%
        ;Hotkey := RegExReplace(A_ThisHotkey,"^(\w* & |\W*)")

        While (GetKeyState("LButton") and !SelectAreaEscapePressed)
        {
            Sleep, 10
            MouseGetPos, MXend, MYend        
            w := abs((MX / scale) - (MXend / scale)), h := abs((MY / scale) - (MYend / scale))
            X := (MX < MXend) ? MX : MXend
            Y := (MY < MYend) ? MY : MYend
            Gui %g%: Show, x%X% y%Y% w%w% h%h% NA
        }

        Gui %g%: Destroy

        if (!SelectAreaEscapePressed) {
            if (m == "s") { ; Screen
                MouseGetPos, MXend, MYend
                if (MX > MXend)
                    temp := MX, MX := MXend, MXend := temp ;* scale
                if (MY > MYend)
                    temp := MY, MY := MYend, MYend := temp ;* scale
                areaRect := [MX, MXend, MY, MYend]
            } else { ; Relative
                CoordMode, Mouse, Relative
                MouseGetPos, rMXend, rMYend
                if (rMX > rMXend)
                    temp := rMX, rMX := rMXend, rMXend := temp
                if (rMY > rMYend)
                    temp := rMY, rMY := rMYend, rMYend := temp
                areaRect := [rMX, rMXend, rMY, rMYend]
            }
        }
    }

    Hotkey, Escape, SelectAreaEscape, Off

    Gui, Select:Destroy
    Gui, HarvestUI:Default
    return areaRect
}

WM_MOUSEMOVE() {
    static CurrControl, PrevControl, _TT  ; _TT is kept blank for use by the ToolTip command below.
    CurrControl := A_GuiControl
    
    if (CurrControl != PrevControl and !InStr(CurrControl, " ")) {
        ToolTip,,,,2  ; Turn off any previous tooltip.
        SetTimer, DisplayToolTip, 500
        PrevControl := CurrControl
    }
    return

    DisplayToolTip:
    SetTimer, DisplayToolTip, Off
    ToolTip % %CurrControl%_TT,,,2  ; The leading percent sign tell it to use an expression.
    SetTimer, RemoveToolTip, 7000
    return

    RemoveToolTip:
    SetTimer, RemoveToolTip, Off
    ToolTip,,,,2
    return
}

;==== JSON PARSER FROM https://github.com/cocobelgica/AutoHotkey-JSON ====
Jxon_Load(ByRef src, args*) {
   
    static q := Chr(34)

    key := "", is_key := false
    stack := [ tree := [] ]
    is_arr := { (tree): 1 }
    next := q . "{[01234567890-tfn"
    pos := 0
    value := ""
    while ( (ch := SubStr(src, ++pos, 1)) != "" )
    {
        if InStr(" `t`n`r", ch)
            continue
        if !InStr(next, ch, true)
        {
            ln := ObjLength(StrSplit(SubStr(src, 1, pos), "`n"))
            col := pos - InStr(src, "`n",, -(StrLen(src) - pos + 1))

            msg := Format("{}: line {} col {} (char {})"
            ,   (next == "")      ? ["Extra data", ch := SubStr(src, pos)][1]
              : (next == "'")     ? "Unterminated string starting at"
              : (next == "\")     ? "Invalid \escape"
              : (next == ":")     ? "Expecting ':' delimiter"
              : (next == q)       ? "Expecting object key enclosed in double quotes"
              : (next == q . "}") ? "Expecting object key enclosed in double quotes or object closing '}'"
              : (next == ",}")    ? "Expecting ',' delimiter or object closing '}'"
              : (next == ",]")    ? "Expecting ',' delimiter or array closing ']'"
              : [ "Expecting JSON value(string, number, [true, false, null], object or array)"
                , ch := SubStr(src, pos, (SubStr(src, pos)~="[\]\},\s]|$") - 1) ][1]
            , ln, col, pos)

            throw Exception(msg, -1, ch)
        }

        is_array := is_arr[obj := stack[1]]

        if i := InStr("{[", ch)
        {
            val := (proto := args[i]) ? new proto : {}
            is_array? ObjPush(obj, val) : obj[key] := val
            ObjInsertAt(stack, 1, val)
            
            is_arr[val] := !(is_key := ch == "{")
            next := q . (is_key ? "}" : "{[]0123456789-tfn")
        }

        else if InStr("}]", ch)
        {
            ObjRemoveAt(stack, 1)
            next := stack[1] == tree ? "" : is_arr[stack[1]] ? ",]" : ",}"
        }

        else if InStr(",:", ch)
        {
            is_key := (!is_array && ch == ",")
            next := is_key ? q : q . "{[0123456789-tfn"
        }

        else ; string | number | true | false | null
        {
            if (ch == q) ; string
            {
                i := pos
                while i := InStr(src, q,, i + 1)
                {
                    val := StrReplace(SubStr(src, pos + 1, i - pos - 1), "\\", "\u005C")
                    static end := A_AhkVersion<"2" ? 0 : -1
                    if (SubStr(val, end) != "\")
                        break
                }
                if !i ? (pos--, next := "'") : 0
                    continue

                pos := i ; update pos

                  val := StrReplace(val,    "\/",  "/")
                , val := StrReplace(val, "\" . q,    q)
                , val := StrReplace(val,    "\b", "`b")
                , val := StrReplace(val,    "\f", "`f")
                , val := StrReplace(val,    "\n", "`n")
                , val := StrReplace(val,    "\r", "`r")
                , val := StrReplace(val,    "\t", "`t")

                i := 0
                while i := InStr(val, "\",, i + 1)
                {
                    if (SubStr(val, i + 1, 1) != "u") ? (pos -= StrLen(SubStr(val, i)), next := "\") : 0
                        continue 2

                    ; \uXXXX - JSON unicode escape sequence
                    xxxx := Abs("0x" . SubStr(val, i + 2, 4))
                    if (A_IsUnicode || xxxx < 0x100)
                        val := SubStr(val, 1, i - 1) . Chr(xxxx) . SubStr(val, i + 6)
                }

                if is_key
                {
                    key := val, next := ":"
                    continue
                }
            }

            else ; number | true | false | null
            {
                val := SubStr(src, pos, i := RegExMatch(src, "[\]\},\s]|$",, pos) - pos)
            
            ; For numerical values, numerify integers and keep floats as is.
            ; I'm not yet sure if I should numerify floats in v2.0-a ...
                static number := "number", integer := "integer"
                if val is %number%
                {
                    if val is %integer%
                        val += 0
                }
            ; in v1.1, true,false,A_PtrSize,A_IsUnicode,A_Index,A_EventInfo,
            ; SOMETIMES return strings due to certain optimizations. Since it
            ; is just 'SOMETIMES', numerify to be consistent w/ v2.0-a
                else if (val == "true" || val == "false")
                    val := %value% + 0
            ; AHK_H has built-in null, can't do 'val := %value%' where value == "null"
            ; as it would raise an exception in AHK_H(overriding built-in var)
                else if (val == "null")
                    val := ""
            ; any other values are invalid, continue to trigger error
                else if (pos--, next := "#")
                    continue
                
                pos += i-1
            }
            
            is_array? ObjPush(obj, val) : obj[key] := val
            next := (obj == tree) ? "" : is_array ? ",]" : ",}"
        }
    }

    return tree[1]
}

Jxon_Dump(obj, indent:="", lvl:=1) {
    static q := Chr(34)

    if (IsObject(obj)) {
        static Type := Func("Type")
        if Type ? (Type.Call(obj) != "Object") : (ObjGetCapacity(obj) == "")
            throw Exception("Object type not supported.", -1, Format("<Object at 0x{:p}>", &obj))

        is_array := 0
        for k in obj
            is_array := k == A_Index
        until !is_array

        static integer := "integer"
        if (indent is %integer%) {
            if (indent < 0)
                throw Exception("Indent parameter must be a postive integer.", -1, indent)
            spaces := indent, indent := ""
            Loop % spaces
                indent .= " "
        }
        indt := ""
        Loop, % indent ? lvl : 0
            indt .= indent

        lvl += 1, out := "" ; Make #Warn happy
        for k, v in obj {
            if IsObject(k) || (k == "")
                throw Exception("Invalid object key.", -1, k ? Format("<Object at 0x{:p}>", &obj) : "<blank>")
            
            if !is_array
                out .= ( ObjGetCapacity([k], 1) ? Jxon_Dump(k) : q . k . q ) ;// key
                    .  ( indent ? ": " : ":" ) ; token + padding
            out .= Jxon_Dump(v, indent, lvl) ; value
                .  ( indent ? ",`n" . indt : "," ) ; token + indent
        }

        if (out != "") {
            out := Trim(out, ",`n" . indent)
            if (indent != "")
                out := "`n" . indt . out . "`n" . SubStr(indt, StrLen(indent) + 1)
        }
        
        return is_array ? "[" . out . "]" : "{" . out . "}"
    }

    ; Number
    else if (ObjGetCapacity([obj], 1) == "")
        return obj

    ; String (null -> not supported by AHK)
    if (obj != "") {
          obj := StrReplace(obj,  "\",    "\\")
        , obj := StrReplace(obj,  "/",    "\/")
        , obj := StrReplace(obj,    q, "\" . q)
        , obj := StrReplace(obj, "`b",    "\b")
        , obj := StrReplace(obj, "`f",    "\f")
        , obj := StrReplace(obj, "`n",    "\n")
        , obj := StrReplace(obj, "`r",    "\r")
        , obj := StrReplace(obj, "`t",    "\t")

        static needle := (A_AhkVersion < "2" ? "O)" : "") . "[^\x20-\x7e]"
        while RegExMatch(obj, needle, m)
            obj := StrReplace(obj, m[0], Format("\u{:04X}", Ord(m[0])))
    }
    
    return q . obj . q
}

WebPic(WB, Website, Options := "") {
    RegExMatch(Options, "i)w\K\d+", W), (W = "") ? W := 50 :
    RegExMatch(Options, "i)h\K\d+", H), (H = "") ? H := 50 :
    RegExMatch(Options, "i)c\K\d+", C), (C = "") ? C := "EEEEEE" :
    WB.Silent := True
    HTML_Page :=
    (RTRIM
    "<!DOCTYPE html>
        <html>
            <head>
                <style>
                    body {
                        background-color: #" C ";
                    }
                    img {
                        top: 0px;
                        left: 0px;
                    }
                </style>
            </head>
            <body>
                <img src=""" Website """ alt=""Picture"" style=""width:" W "px;height:" H "px;"" />
            </body>
        </html>"
    )
    While (WB.Busy)
        Sleep 10
    WB.Navigate("about:" HTML_Page)
    Return HTML_Page
}

