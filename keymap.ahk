#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
#Warn  ; Enable warnings to assist with detecting common errors.
#SingleInstance Force  ; Prevents multiple instances of the same script.
#MaxThreadsPerHotkey 3
SendMode Input  ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%  ; Ensures a consistent starting directory.
SetCapsLockState, AlwaysOff

; -- config ----------------------------------------
; navigation cluster: navigate with ijkl (0) or hjkl (1) arrows
vimArrows := 0

; copilot key: remap to Ctrl (0) or PrintScreen (1)
copAsPrtSc := 0

; terminal: command prompt ("cmd"), powershell ("powershell.exe"), or any executable of choice
terminal := "cmd"

; find first: new search on caps layer (0) or mod layer (1)
flipFindFirst := 1

; find again: jump to the next (0) or first (1) occurence
findAgainAsFirst := 0
; --------------------------------------------------

; global variables
caps := 0 ; whether capslock is on
vim := 0 ; whether vim mode is on
search := {}
    search.pattern := " " ; pattern to search for
    search.source := "" ; cached line to search in
    search.pos := 0 ; position in cached line (1-indexed); 0 indicates invalid cache
    search.partial := 0 ; whether cache is complete line (0), start of line (-1), or end of line (1)
    search.state := 0 ; search for nothing (0), next (1), prev (-1), or first (2) occurence
    search.after := 0 ; how far right to move after search
repeat := 0 ; whether to repeat action
num := 1 ; number of times to repeat action
char := * ; temp variable for next/prev chars
inserted := 0 ; whether insert is on

; visual indicator
guiPos := A_ScreenHeight - 40
Gui, +AlwaysOnTop -Caption +ToolWindow +LastFound
Gui, Color, 000000, 000000
Gui, Font, cFFFFFF s10, Consolas
Gui, Add, Text, vMode x10 y5 Hidden, VIM
Gui, Add, Text, vDisplay x10 y5 w64 Hidden, SEARCH
Gui, Add, Edit, vSearchInput gOnSearchChange x74 y5 w64 -E0x200 -Border -Wrap -HScroll -VScroll Hidden
Gui, Add, Button, gOnSearchSubmit x0 y0 w0 h0 Default, Submit
Gui, Margin, 12, 2
Gui, Show, x12 y%guiPos% NoActivate
Gui, Hide

/* todo
fix visual bug when pasting into search input
condense vim-related globals into objects
allow templates to wrap selected text
allow find next/prev without find text first, using mod layer to refresh cache/input new pattern?
add some way to activate Ctrl + ↑ and Ctrl + ↓ for 60% support: maybe replace m? or . after search changes?
allow multi-cursor search? might not be possible
use tap hold arrows to allow Ctrl? also opens up u and y for vim-styled undo/redo
allow config to be changed through GUI
multi-line jumps: paragraphs, brackets, etc
    Scan chunks (e.g. {Up 20}, searching for matching open/close
vim layer:
    search w/ gui
    delete
    macros
    repetition
    put (e.g. change dd to ctrl + x, then put is just ctrl + v)
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

; add semicolon to end of line on Ctrl + ;
^`;::
    Send {End}
    Send {;}
    return

; remap copilot key
; note that this will not work with hotkeys that combine with Win or Shift
*+#f23::
    if copAsPrtSc
        Send {Blind}{LWin Up}{LShift Up}{PrintScreen}
    else
        Send {Blind}{LWin Up}{LShift Up}{RCtrl Down}
        KeyWait f23
        Send {RCtrl Up}
    return

; Windows clipboard on Ctrl + PrtSc
^Printscreen::Send {Ctrl Up}#v

; send Ctrl + A on Alt + PrtSc
!Printscreen::Send ^{a}

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

Insert::
    Send {Insert}
    inserted := !inserted
    return

; --------------------------------------------------
; utility functions
; --------------------------------------------------
enterVim() {
    global vim, repeat, num, inserted
    vim := 1
    num := 1
    repeat := 0
    inserted := 1
    GuiControl, Show, Mode
    Gui, Show, NoActivate AutoSize
    Send {Insert}
    return
}
exitVim() {
    global vim, inserted
    vim := 0
    inserted := 0
    GuiControl, Hide, Mode
    Gui, Hide
    Send {Insert}
    return
}
reset() {
    global repeat, num, char, search
    char := ""
    repeat := 0
    num := 1
    search := { pattern: "", source: "", pos: 0, partial: 0, state: 0, after: 0 }
    return
}

getClip() {
    clip := ClipboardAll
    Clipboard := ""
    Send ^c
    ClipWait, 1, 1
    if ErrorLevel {
        MsgBox, 48, Error, An error occurred while waiting for the clipboard.
        return
    }
    out := Clipboard
    Clipboard := clip
    return out
}

; --------------------------------------------------
; cased operations
;
; operate on camelCase, PascalCase, and snake_case sub-words
; --------------------------------------------------
bkspCase() {
    ; grab rest of word to clipboard
    tmp := ClipboardAll
    Clipboard := ""
    Send ^+{Left}
    Send ^c
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
    Send ^+{Right}
    Send ^c
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

; --------------------------------------------------
; inline search
;
; jump to first, next, or prev occurence in current line
; hold A to enter search pattern
; --------------------------------------------------
OnSearchChange:
    ; update width
    GuiControlGet, pattern, , SearchInput
    width := 24 + StrLen(pattern) * 7
    GuiControl, Move, SearchInput, w%width%
    width += 74 ; display width + 10
    Gui, Show, w%width%

    ; vim inline search only allows 1 char
    if (vim && pattern)
        gosub OnSearchSubmit
    return

OnSearchSubmit:
    ; update global search object
    GuiControlGet, pattern, , SearchInput
    search.pattern := pattern

    ; cleanup gui
    GuiControl, Move, SearchInput, w64
    GuiControl, Hide, SearchInput
    GuiControl, Hide, Display
    Gui, Hide

    ; display vim indicator
    if vim
        Gui, Show, Autosize NoActivate

    ; search
    inlineSearch()
    return

GuiEscape:
    ; cleanup
    search.state := 0
    GuiControl, Move, SearchInput, w64
    GuiControl, Hide, SearchInput
    GuiControl, Hide, Display
    Gui, Hide
    reset()

    ; display vim indicator
    if vim
        Gui, Show, Autosize NoActivate

    return

#If search.state
    ; support Ctrl + Backspace
    ^Backspace::Send ^+{Left}{Backspace}
#If

showSearchInput() {
    ; display search input
    GuiControl, , Display, SEARCH
    GuiControl, Show, Display
    GuiControl, , SearchInput
    GuiControl, Show, SearchInput
    Gui, Show, Autosize
    GuiControl, Focus, SearchInput
}

; updateState: new (non-zero) search state, as next (1), prev (-1), or first (2) occurence
; clearCache: whether to invalidate cache and re-scan current line
inlineSearch(updateState := 0, clearCache := 0) {
    global search

    if (search.pattern == "") {
        search.state := 0
        num := 0
        return
    }

    ; update search values
    if updateState
        search.state := updateState
    if clearCache
        search.pos := 0

    ; undo previous after-effects
    if search.after < 0
        Send % "{Right " -1 * search.after "}"
    else if search.after > 0
        Send % "{Left " search.after "}"

    if (search.state == 2) {
        ; find first occurence
        Send {Home}

        if search.partial {
            ; clear cache
            search.pos := 0
        }
        if !search.pos {
            ; cache full line
            Send +{End}
            search.source := getClip()
            Send {Left}
        }

        ; search for text
        search.pos := InStr(search.source, search.pattern, , 1, num)
        Send % "{Right " search.pos - 1 "}"
    } else if (search.state == 1) {
        ; find next occurence
        Send {Right}

        if !search.pos {
            ; cache end of line
            Send +{End}
            search.source := getClip()
            Send {Left}

            search.partial := 1
        } else if (search.partial == -1) {
            ; cache only contains start of line; update cache to include rest of line
            Send +{End}
            search.source := Substr(search.source, 1, search.pos) getClip()
            Send {Left}

            search.partial := 0
        }

        ; search for text
        i := InStr(search.source, search.pattern, , search.pos + 1, num)
        Send % "{Right " i - search.pos - 1 "}"
        search.pos := i
    } else if (search.state == -1) {
        ; find prev occurence
        if !search.pos {
            ; cache start of line
            Send +{Home}
            search.source := getClip()
            Send {Right}

            search.partial := -1
            search.pos := StrLen(search.source) + 1
        } else if (search.partial == 1) {
            ; cache only contains end of line; update cache to include start of line
            Send +{Home}
            tmp := getClip()
            Send {Right}

            search.source := tmp Substr(search.source, search.pos)
            search.partial := 0
            search.pos := StrLen(tmp) + 1
        }

        ; search for text
        i := InStr(search.source, search.pattern, , -(StrLen(search.source) - search.pos + 1), num)
        Send % "{Left " search.pos - i "}"
        search.pos := i
    }

    ; after-effects
    if search.after > 0
        Send % "{Right " search.after "}"
    else if search.after < 0
        Send % "{Left " -1 * search.after "}"

    ; cleanup
    search.state := 0
    num := 1
}

; --------------------------------------------------
; caps layers
; --------------------------------------------------
CapsLock & Tab::gosub, Insert
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
    y::
        if search.state
            Send ^+{Left}{Backspace}
        else
            Send ^{Backspace}
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
    u::^Left
    a & u::^+Left
    i::^Right
    a & i::^+Right

    ; deletion
    o::
        if search.state
            Send ^+{Left}{Backspace}
        else
            Send ^{Backspace}
        return
    a & o::^Delete
    y::bkspCase()
    a & y::delCase()
#If
#If GetKeyState("CapsLock", "P") && flipFindFirst
    ; find first
    /::
        global search := { pattern: "", source: "", pos: 0, partial: 0, state: 2, after: 0 }
        global num := 1
        showSearchInput()
        return
    a & /::inlineSearch(2)
#If
#If GetKeyState("CapsLock", "P") && !flipFindFirst
    ; find first
    a & /::
        global search := { pattern: "", source: "", pos: 0, partial: 0, state: 2, after: 0 }
        global num := 1
        showSearchInput()
        return
    /::inlineSearch(2)
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
    =::
        if search.state
            Send ^+{Left}{Backspace}
        else
            Send ^{Backspace}
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
    z::Run % terminal
    a & z::Run *RunAs %terminal% ; run as admin

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
    `::
        Send {`` 3}
        return

    ; inline search
    .::inlineSearch(findAgainAsFirst + 1, 1)
    `;::inlineSearch(1)
    a & `;::
        global search := { pattern: "", source: "", pos: 0, partial: 1, state: 1, after: 0 }
        showSearchInput()
        return
    ,::inlineSearch(-1)
    a & ,::
        global search := { pattern: "", source: "", pos: 0, partial: 1, state: -1, after: 0 }
        showSearchInput()
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
#If
; --------------------------------------------------
; vim layer
; --------------------------------------------------

#If vim && !search.state
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
    +6::
        Send {End}+{Home}
        line := getClip()
        Send {Left}

        p := RegExMatch(line, "\S")
        Send % "{Right " p - 1 "}"
    ; todo g_ goes to last non-whitespace char in line
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
        global search := { pattern: " ", source: "", pos: 0, partial: 1, state: 1, after: 1 }
        inlineSearch()
        reset()
        return
    e::
        Send ^{Right %num%}
        reset()
        return
    +e::
        global search := { pattern: " ", source: "", pos: 0, partial: 1, state: 1, after: -1 }
        inlineSearch()
        reset()
        return
    b::
        Send ^{Left %num%}
        reset()
        return

    ; inline search
    f::
        global search := { pattern: "", source: "", pos: 0, partial: 1, state: 1, after: 0 }
        showSearchInput()
        return
    +f::
        global search := { pattern: "", source: "", pos: 0, partial: 1, state: -1, after: 0 }
        showSearchInput()
        return
    t::
        global search := { pattern: "", source: "", pos: 0, partial: 1, state: 1, after: -1 }
        showSearchInput()
        return
    +t::
        global search := { pattern: "", source: "", pos: 0, partial: 1, state: -1, after: -1 }
        showSearchInput()
        return
    `;::inlineSearch(1)
    ,::inlineSearch(-1)

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
; pause
!x::
    Suspend, Permit
    if inserted
        Send {Insert}
    Suspend
    return

; reload
!r::
    Suspend, Permit
    if inserted
        Send {Insert}
    Reload
    return
