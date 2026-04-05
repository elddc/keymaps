#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
#Warn  ; Enable warnings to assist with detecting common errors.
#SingleInstance Force  ; Prevents multiple instances of the same script.
#MaxThreadsPerHotkey 3
SendMode Input  ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%  ; Ensures a consistent starting directory.
SetCapsLockState, AlwaysOff

; -- config ----------------------------------------
; whether to use ijkl (0) or hjkl (1) arrows
vimArrows := 0
; --------------------------------------------------

; global variables
caps := 0 ; whether capslock is on
vim := 0 ; whether vim mode is on
search := { pattern: "", source: "", pos: 0 }
repeat := 0 ; whether to repeat action
num := 1 ; number of times to repeat action
char := * ; temp variable for next/prev chars

; visual indicator
guiPos := A_ScreenHeight - 52
Gui, +AlwaysOnTop -Caption +ToolWindow +LastFound
Gui, Color, 000000
Gui, Font, cFFFFFF s10, Consolas
Gui, Add, Text, vDisplay x10 y2 Hidden, SEARCH
Gui, Add, Text, vMode x10 y2 Hidden, VIM
Gui, Margin, 12, 3
Gui, Show, x12 y%guiPos% NoActivate
Gui, Hide

/* todo
condense vim-related globals into objects
allow templates to wrap selected text
replace search Input with Edit GUI
allow find next/prev without find text first, using mod layer to refresh cache/input new pattern?
add some way to activate Ctrl + ↑ and Ctrl + ↓ for 60% support: maybe replace m? or . after search changes?
use tap hold arrows to allow Ctrl? also opens up u and y for vim-styled undo/redo
vim layer:
    search w/ gui
    delete
    macros
    repetition
*/

; --------------------------------------------------
; general keybinds
; --------------------------------------------------
; send Esc on CapsLock
CapsLock::Esc

; toggle CapsLock on Win + CapsLock
#CapsLock::
    caps := !caps
    if caps
        SetCapsLockState, AlwaysOn
    else
    	SetCapsLockState, AlwaysOff

; add semicolon to end of line on Ctrl+;
^`;::
    Send {End}
    Send {;}
    return

; Windows clipboard on Ctrl+PrtSc
^Printscreen::#v

; send Ctrl+A on Shift+PrtSc
+Printscreen::Send ^{a}

; hold Tab sends 4 spaces
$Tab::
    Keywait Tab, T 0.2
    if !Errorlevel ; tapped
        Send {Tab}
    else ; held
        Send {Space 4}
    Keywait Tab
    Send {Tab up} ; prevent repeated triggers
    return

; hold Esc: short hold sends `, longer hold sends ```
$Esc::
    Keywait Esc, T 0.15
    if !Errorlevel ; tapped
        Send {Esc}
    else { ; held
        Send {``}
        Keywait Esc, T 0.3
        if Errorlevel ; held for longer
            Send {``}{``}
    }
    Keywait Esc
    Send {Esc Up} ; prevent repeated triggers
    return

; --------------------------------------------------
; utility functions
; --------------------------------------------------
enterVim() {
    global vim, repeat, num
    vim := 1
    num := 1
    repeat := 0
    GuiControl, Show, Mode
    Gui, Show, NoActivate AutoSize
    Send {Insert}
    return
}
exitVim() {
    global vim := 0
    GuiControl, Hide, Mode
    Gui, Hide
    Send {Insert}
    return
}
reset() {
    global repeat, num, char
    char := ""
    repeat := 0
    num := 1
    return
}

; backspace/delete camelCase, PascalCase, and snake_case words
bkspCase() {
    ; grab rest of word to clipboard
    tmp := ClipboardAll
    Clipboard := ""
    Send ^+{Left}^c
    ClipWait, 1, 1
    if ErrorLevel {
        MsgBox, 48, Error, An error occurred while waiting for the clipboard.
        return
    }

    ; delete last word
    Clipboard := RegExReplace(Clipboard, "m)_?([A-Z]+(?=[A-Z][a-z])|[A-Z]?[a-z]+|[A-Z]+|\d+)$|[^a-zA-Z0-9]+$")
    if (Clipboard != "") {
        Send ^v
        Sleep, 20 ; add small paste delay
    } else {
        Send {Backspace}
    }

    ; restore old clipboard value
    Clipboard := tmp
    return
}
delCase() {
    ; add space for cursor re-positioning later
    Send {Space}

    ; grab rest of word to clipboard
    tmp := ClipboardAll
    Clipboard := ""
    Send ^+{Right}^c
    ClipWait, 1, 1
    if ErrorLevel {
        MsgBox, 48, Error, An error occurred while waiting for the clipboard.
        return
    }

    ; delete first word
    Clipboard := RegExReplace(Clipboard, "m)^[^a-zA-Z0-9]+|^([A-Z]+(?=[A-Z][a-z])|[A-Z]?[a-z]+|[A-Z]+|\d+)_?")

    if (Clipboard != "") {
        Send ^v
        Sleep, 20 ; add small paste delay
        Send ^{Left}
    } else {
        Send {Delete}
    }

    ; remove added space
    Send {Backspace}

    ; restore old clipboard value
    Clipboard := tmp
    return
}

; move to the next/prev occurence of the pattern in the current line, using global search object
searchWithInput() {
    global search := { pattern: "", source: "", pos: 0 }
    GuiControl, Show, Display
    Gui, Show, NoActivate Autosize

    ; temporarily disable hold Esc hotkey to allow Esc cancel
    Hotkey, $Esc, Off

    ; read search string, using "Enter" to send and "/" or "Esc" to cancel
    pattern := ""
    loop {
        Input, key, L1, {Enter}{Backspace}{/}{Esc}
        if InStr(ErrorLevel, "Enter") {
            ; search for pattern
            break
        } else if InStr(ErrorLevel, "Backspace") {
            if GetKeyState("Control", "P") {
                ; ctrl + backspace
                RegExMatch(pattern, ".*\W", match) ; matches everything up to the last non-word character
                if (match)
                    pattern := match
                else
                    pattern := ""
            } else {
                ; backspace
                StringTrimRight, pattern, pattern, 1
            }
        } else if InStr(ErrorLevel, "EndKey:") {
            ; cancel
            pattern := ""
            break
        }

        ; concat
        pattern .= key

        ; display search pattern
        width := 24 + StrLen(pattern) * 7
        GuiControl, , Display, %pattern%
        GuiControl, Move, Display, w%width%
        Gui, Show, w%width%
    }
    search.pattern := pattern

    ; cleanup
    Hotkey, $Esc, On
    GuiControl, , Display, SEARCH
    GuiControl, Move, Display, w64
    GuiControl, Hide, Display
    Gui, Hide

    ; search for pattern
    if StrLen(search.pattern) {
        searchLine()
    }
}
searchLine(forward := 1) {
    global search

    if !search.pos {
        ; grab rest of line to clipboard
        Send {Home}
        tmp := ClipboardAll
        Clipboard := ""
        Send +{End}^c
        ClipWait, 1, 1
        Send {Left}
        if ErrorLevel {
            MsgBox, 48, Error, An error occurred while waiting for the clipboard.
            return
        }

        ; cache line for future scans
        search.source := Clipboard

        ; restore old clipboard value
        Clipboard := tmp
    }

    ; test string sss

    ; set current position & search direction
    pos := forward ? (search.pos + 1) : -(StrLen(search.source) - search.pos + 1)

    ; search for text
    i := InStr(search.source, search.pattern, , pos, 1)
    if i {
        if forward
            Send % "{Right " (i - pos) + (search.pos ? 1 : 0) "}"
        else
            Send % "{Left " search.pos - i "}"
    }
    search.pos := i
    return
}
; move to the next occurence of the pattern in the current line, not using global search object
findNext(pattern, n:=1) {
    ; grab rest of line to clipboard
    tmp := ClipboardAll
    Clipboard := ""
    Send +{End}^c
    ClipWait, 1, 1
    Send {Left}
    if ErrorLevel {
        MsgBox, 48, Error, An error occurred while waiting for the clipboard.
        return
    }

    ; search for text
    pos := InStr(Clipboard, pattern, , , n)
    if pos {
        Send % "{Right " pos - 1 "}"
    }

    ; restore old clipboard value
    Clipboard := tmp
}

; --------------------------------------------------
; caps layers
; --------------------------------------------------
CapsLock & Tab::Insert
CapsLock & Shift::
    if vim
        exitVim()
    else
        enterVim()
    return

; config-dependent keys
#If GetKeyState("CapsLock", "P") && !vimArrows
    ; navigation
    i::Up
    a & i::+Up
    j::Left
    a & j::+Left
    k::Down
    a & k::+Down
    l::Right
    a & l::+Right
    u::^Left
    a & u::^+Left
    o::^Right
    a & o::^+Right

    ; deletion
    y::^Backspace
    a & y::^Delete
    h::bkspCase()
    a & h::delCase()
#If
#If GetKeyState("CapsLock", "P") && vimArrows
    ; navigation
    h::Left
    a & h::+Left
    j::Down
    a & j::+Down
    k::Up
    a & k::+Up
    l::Right
    a & l::+Right
    y::^Left
    a & y::^+Left
    u::^Right
    a & u::^+Right

    ; deletion
    o::^Backspace
    a & o::^Delete
    i::bkspCase()
    a & i::delCase()
#If

; config-independent keys
#If GetKeyState("CapsLock", "P")
    ; block a; enables a to be used as modifier key
    a::return

    ; navigation
    \::Send {Home}
    a & \::Send +{Home}
    Enter::Send {End}
    a & Enter::Send +{End}
    m:: Send {Home}
    a & m:: Send {End}

    ; I also often use this key as a quick macro for templates that change often
    ; m::
        ; Send <span class="purple"></span>
        ; Send {Left 7}
        ; return

    ; deletion
    Backspace::Delete
    a & Backspace::^Delete
    =::^Backspace
    p::Backspace
    a & p::Delete

    ; brackets and symbols
    f::Send {(}
    a & f::
        Send {(}
        Send {)}
        Send {Left}
        return
    c::Send {)}
    d::Send {[}
    a & d::
        Send {[}
        Send {]}
        Send {Left}
        return
    x::Send {]}
    g::Send {{}
    a & g::
        Send {{}
        Send {}}
        Send {Left}
        return
    v::Send {}}
    [::Send {{}
    a & [::
        Send {[}
        Send {]}
        Send {Left}
        return
    ]::Send {}}
    r::Send {&}
    t::Send {*}
    '::Send {"}
    a & '::
        Send {" 2}
        Send {Left}
        return
    1::Send {!}
    2::Send {@}
    3::Send {#}
    a & 3:: ; useful for hex codes
        Send ^{Left}
        Send {#}
        Send ^{Right}
        return
    4::Send {$}
    a & 4::
        Send {$ 2}
        Send {Left}
        return
    5::Send {`%}
    a & 5::
        Send {`% 2}
        Send {Left}
        return
    6::Send {^}
    7::Send {&}
    8::Send {*}
    9::Send {(}
    0::Send {)}
    Space::_
    Up::Send {U+2191}    ; ↑
    Down::Send {U+2193}  ; ↓
    Left::Send {U+2190}  ; ←
    Right::Send {U+2192} ; →
    n::
        Send {Right}
        Send ^{Left}
        Send ^+{Right}
        return
    a & n::
        Send {Home}
        Send +{End}
        return

    ; terminal
    z::Run cmd
    a & z::Run *RunAs cmd ; run as admin
    ; a & z::Run powershell.exe

    ; select all
    s::Send ^{a}

    ; save
    a & s::Send ^{s}

    ; fullscreen
    -::Send {F11}

    ; markdown/latex
    q::
        Send {`` 2}
        Send {Left}
        return
    w::
        Send {$ 4}
        Send {Left 2}
        return
    e::
        Send {$ 2}
        Send {Left}
        return
    b::
        Send {* 2}
        Send {Left}
        return
    Esc::
        Send {``}
        return


    ; emmet-like HTML/JSX completion: <$WORD$END />
    ; n::
    ;    Send ^{Left}
    ;    Send {<}
    ;    Send {Right}
    ;    Send ^{Right}
	; Send {Space}
   	; Send {/}
    ;    Send {>}
    ;    Send {Left}
    ;    Send {Left}
    ;    Send {Left}
    ;    return

    ; emmet (in IDE) expand and move cursor to <$WORD$ $END$>\n</$WORD$>
    ; n::
    ;     Send {Tab}
    ;     Sleep, 50
    ;     Send {Enter}
    ;     Send {Home}
    ;     Send {Left}
    ;     Send {Left}
	; Send {Space}
    ;     return


    ; emmet (in IDE) expand and move cursor to <$WORD$ $END$ />
    ; m::
    ;     Send {/}
    ;     Send {Tab}
    ;     Sleep, 50
    ;     Send {Left}
    ;     Send {Left}
	; Send {Space}
	; Send {Space}
    ;     Send {Left}
    ;     return

    ; find pattern in the current line for text with /
    /::searchWithInput()
    ; find next with ;
    `;::searchLine()
    ; find prev with ,
    ,::searchLine(0)
    ; repeat search with same pattern, in unseen line
    .::
        global search := { pattern: search.pattern, source: "", pos: 0 }
        searchLine()
        return
#If

; --------------------------------------------------
; vim layer
; --------------------------------------------------

#If vim
    ; exit operations
    i::exitVim()
    a::
        exitVim()
        Send {right %num%}
        return
    +a::
        exitVim()
        Send {end}
        return
    o::
        exitVim()
        Send {End}
        Send {Enter %num%}
        return
    +o::
        exitVim()
        Send {Home}
        loop, %num% {
            Send {Enter}
            Send {Up}
        }
        return

    ; navigation
    h::
        Send {Left %num%}
        reset()
        return
    j::
        Send {Down %num%}
        reset()
        return
    k::
        Send {Up %num%}
        reset()
        return
    l::
        Send {Right %num%}
        reset()
        return
    0::
        Send {Home %num%}
        reset()
        return
    +4::
        Send {End %num%}
        reset()
        return
    w::
        if (char == "d")
            Send {Shift down}
        loop, %num% {
            Send ^{Right}^{Right}^{Left}
        }
        if (char == "d")
            Send {Shift up}{Backspace}
        reset()
        return
    +w::
        global num
        findNext(" ", num)
        Send {Right}
        reset()
        return
    e::
        Send ^{Right %num%}
        reset()
        return
    +e::
        global num
        findNext(" ", num)
        Send {Left}
        reset()
        return
    b::
        Send ^{Left %num%}
        reset()
        return

    ; search in line
    f::searchWithInput()
    ; find next with ;
    `;::searchLine()
    ; find prev with ,
    ,::searchLine(0)

    ; repeat actions
    1::num := (repeat ? (num * 10) : 0) + 1
    2::num := (repeat ? (num * 10) : 0) + 2
    3::num := (repeat ? (num * 10) : 0) + 3
    4::num := (repeat ? (num * 10) : 0) + 4
    5::num := (repeat ? (num * 10) : 0) + 5
    6::num := (repeat ? (num * 10) : 0) + 6
    7::num := (repeat ? (num * 10) : 0) + 7
    8::num := (repeat ? (num * 10) : 0) + 8
    9::num := (repeat ? (num * 10) : 0) + 9

    ; delete
    d::
        global char
        if (char == "d") {
            Send {End}{Right}{Up}+{Down %num%}{Backspace}
            reset()
        } else {
            char := "d"
        }
        return
    x::Delete

    ; undo/redo
    u::^z
    y::^y

#If


; --------------------------------------------------
; script state controls
; --------------------------------------------------
; reload
!x::
    Suspend, Permit
    if vim
        Send {Insert}
    Suspend
    return

; reload
!r::
    Suspend, Permit
    if vim
        Send {Insert}
    Reload
    return
