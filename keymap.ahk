#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
#Warn  ; Enable warnings to assist with detecting common errors.
#SingleInstance Force  ; Prevents multiple instances of the same script.
#MaxThreadsPerHotkey 3
SendMode Input  ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%  ; Ensures a consistent starting directory.
SetCapsLockState, AlwaysOff

; global variables
caps := 0 ; whether capslock is on
vim := 0 ; whether vim mode is on
search := * ; search string
repeat := 0 ; whether to repeat action
num := 1 ; number of times to repeat action
char := * ; temp variable for next/prev chars

; visual indicator
guiPos := A_ScreenHeight - 35
Gui, +AlwaysOnTop -Caption +ToolWindow +LastFound
Gui, Color, 000000
Gui, Font, cFFFFFF s10, Consolas
Gui, Add, Text, x10 y2, VIM
;Gui, Add, Text, x10 y2, SEARCH
Gui, Margin, 12, 3
Gui, Show, x2 y%guiPos% NoActivate
Gui, Hide

/* todo
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

; select word on Ctrl+PrtSc
^Printscreen::
    Send ^{Left}
    Send ^+{Right}
    return

; send Ctrl+A on Shift+PrtSc
+Printscreen::Send ^{a}

; hold Tab sends 4 spaces
$Tab::
    Keywait Tab, T 0.2
    if !Errorlevel ; tapped
        Send {Tab}
    else { ; held
        Send {Space}
        Send {Space}
        Send {Space}
        Send {Space}
    }
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
    Send {Esc Up} ; pr event repeated triggers
    return

; --------------------------------------------------
; utility functions
; --------------------------------------------------
enterVim() {
    global vim, repeat, num
    vim := 1
    num := 1
    repeat := 0
    Gui, Show, NoActivate
    GuiControl, Show, VIM
    Send {Insert}
    return
}
exitVim() {
    global vim := 0
    Gui, Hide
    Send {Insert}
    return
}
searchLine(pattern, n:=1) {
    ; grab rest of line to clipboard
    Send {Home}
    tmp := ClipboardAll
    Clipboard := ""
    Send +{End}^c
    ClipWait, 1, 1
    Send {Left}
    if ErrorLevel {
        MsgBox, 48, Error, An error occurred while waiting for the clipboard.
        Return
    }

    ; search for text
    pos := InStr(Clipboard, pattern, , , n)
    if (pos) {
        Send % "{Right " pos - 1 "}"
    }

    ; restore old clipboard value
    Clipboard := tmp
}
reset() {
    global repeat, num, char
    char := ""
    repeat := 0
    num := 1
    return
}

; --------------------------------------------------
; caps layers
; --------------------------------------------------

; modifiers
CapsLock & a::Send {Control down}
CapsLock & a up::Send {Control up}
;CapsLock & s::Send {Shift down}
;CapsLock & s up::Send {Shift up}

; modes
CapsLock & Tab::Insert
CapsLock & Shift::
    if vim
        exitVim()
    else
        enterVim()
    return

#If GetKeyState("CapsLock", "P")
    ; navigation
    j::Left
    k::Down
    i::Up
    l::Right
    u::^Left
    o::^Right
    a & u::+Left
    a & o::+Right
    \::Home
    Enter::Send {End}

    ; deletion
    Backspace::Delete
    =::^Backspace
    p::Backspace
    y::Send ^{Backspace}
    h::Send ^{Delete}

    ; brackets and symbols
    f::Send {(}
    c::Send {)}
    d::Send {[}
    x::Send {]}
    g::Send {{}
    v::Send {}}
    [::Send {{}
    ]::Send {}}
    r::Send {&}
    t::Send {*}
    '::Send {"}
    1::Send {!}
    2::Send {@}
    3::Send {#}
    4::Send {$}
    5::Send {`%}
    6::Send {^}
    7::Send {&}
    8::Send {*}
    9::Send {(}
    0::Send {)}
    Space::_
    n::
        Send {(}
        Send {)}
        Send {Left}
        return
    m::
        Send {"}
        Send {"}
        Send {Left}
        return

    ; terminal
    z::Run cmd

    ; windows clipboard
    .::#v
        
    ; select all
    s::Send ^{a}

    ; fullscreen
    -::Send {F11}

    ; markdown/latex
    q::
        Send {``}
        Send {``}
        Send {Left}
        return
    w::
        Send {$}
        Send {$}
        Send {$}
        Send {$}
        Send {Left}
        Send {Left}
        return
    e::
        Send {$}
        Send {$}
        Send {Left}
        return
    b::
        Send {*}
        Send {*}
        Send {Left}
        return
    Esc::
        Send {``}
        Send {``}
        Send {``}
        return


    ; emmet-like HTML/JSX completion: <$WORD$END />
    ; .::
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
    ; ,::
    ;     Send {Tab}
    ;     Sleep, 50
    ;     Send {Enter}
    ;     Send {Home}
    ;     Send {Left}
    ;     Send {Left}
	; Send {Space}
    ;     return


    ; emmet (in IDE) expand and move cursor to <$WORD$ $END$ />
    ; .::
    ;     Send {/}
    ;     Send {Tab}
    ;     Sleep, 50
    ;     Send {Left}
    ;     Send {Left}
	; Send {Space}
	; Send {Space}
    ;     Send {Left}
    ;     return

    ; search in the current line for text with /
    /::
        ; read search string, using "Enter" to send and "/" to cancel
        Input, search, , {Enter}{/}
        if InStr(ErrorLevel, "Enter") {
            searchLine(search)
            num := 1
        }
        return
    ; find next with ; 
    `;::
        num += 1
        searchLine(search, num)
        return
    ; find prev with ,
    ,::
        num -= 1
        searchLine(search, num)
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
        Loop, %num% {
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
        Loop, %num% {
            Send ^{Right}^{Right}^{Left}
        }
        if (char == "d")
            Send {Shift up}{Backspace}
        reset()
        return
    +w::
        searchLine(" ", %num%)
        Send {Right}
        reset()
        return
    e::
        Send ^{Right %num%}
        reset()
        return
    +e::
        searchLine(" ", %num%)
        Send {Left}
        reset()
        return
    b::
        Send ^{Left %num%}
        reset()
        return

    ; search in line
    f::
        ; read search string, using "Enter" to send and "/" to cancel
        Input, search, , {Enter}{/}
        if InStr(ErrorLevel, "Enter") {
            searchLine(search)
            num := 1
        }
        return
    `;::
        num += 1
        searchLine(search, num)
        return
    ,::
        num -= 1
        searchLine(search, num)
        return

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
    if GetKeyState("Insert", "T")
        Send {Insert}
    Suspend
    return

; reload
!r::
    Suspend, Permit
    if GetKeyState("Insert", "T")
        Send {Insert}
    Reload
    return

