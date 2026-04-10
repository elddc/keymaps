# Custom Keymaps
Custom keymaps for Windows, implemented with AutoHotKey. Designed for programmers who don't use full keyboards,
don't like moving their hands, and/or don't always have the privilege of working in a code editor
but still want nice keyboard shortcuts.

Key features:
* Momentary layers with symbols, navigation keys, and other functions accessible via `CapsLock` and `CapsLock + A`
* Quick navigation with inline search
* Programming shortcuts including sub-word deletion, paired bracket templates, quick semicolon line-ending, and more
* Remap `Copilot` key back to `Ctrl` or `PrintScreen`

## Overview

Choose between modern ijkl arrows or Vim-style hjkl arrows navigation.
<details open>
<summary>Modern Layout (ijkl)</summary>

<a href="https://www.keyboard-layout-editor.com/#/gists/db2921cd66d6b2ea9edfafbfa96ef98d">
<img width="1467" height="841" alt="image" src="https://github.com/user-attachments/assets/daa7bfbe-091f-4fc3-911a-45037f10b680" />
</a>

</details>

<details>
<summary>Vim-style Layout (hjkl)</summary>

<a href="https://www.keyboard-layout-editor.com/#/gists/cb2a720d6b2f191db82fe5f64aead164">
<img width="1464" height="841" alt="image" src="https://github.com/user-attachments/assets/53794342-9aa8-42ac-8dd2-773adfa6747e" />
</a>

</details>

## Configuration

Use the config variables at the top of `keymap.ahk` to configure the following options:
* Navigation Cluster: ijkl (default) or hjkl arrows
* Copilot Key: remap to `Ctrl` (default) or `PrintScreen`
* Preferred Terminal: command prompt (default), PowerShell, or any executable of choice
* Find First: open a new search (default) or repeated search as the base behavior
* Find Again: jump to next (default) or first occurence

## Caps Layer

This keymap gives the `CapsLock` key two functions:
* Tap to `Esc`
* Hold to enter the **Caps Layer**

While in the **Caps Layer**, holding `A` applies alternate behaviors to certain keys, highlighted above. For example:
* `CapsLock + \` sends `Home`
* `CapsLock + A + \` sends `Shift + Home`
  <br><br>
* `CapsLock + P` sends `Backspace`
* `CapsLock + A + P` sends `Delete`

`Win + CapsLock` applies the original `CapsLock` functionality.

## Templates
Keys marked in blue indicate templates, which wrap the cursor in an opening and closing pair.
For example, `( )` acts as `($END$)`.

Half-blue keys have split behavior: the white portion is the base behavior in the **Caps Layer**,
and holding `A` inserts the full template.

## Cased Backspace/Delete
Cased backspace and delete remove sub-words from camelCase, PascalCase, and snake_case words. For example, cased backspace
turns `fooBar` into `foo`, `FooBar` into `Foo`, and `foo_bar` into `foo`.

## Searching
Inline search allows for quick navigation within a line by jumping to the first, next, or previous occurence
of any search pattern.

**New searches** will display a small textbox to enter the search pattern. Use `Enter` to search or `Esc` to cancel.

By default, `Find First` opens a new search, but `Find Next` and `Find Prev` act as **repeated searches**,
which reuse the previous search pattern, line, and match position to jump between matches quickly.
`Find Again` reuses the search pattern, but re-scans the line to update the line contents and position.

## Vim Mode
This feature is under development! Come back soon for more details.

## Additional Notes & Clarifications
* Long press `Tab` to send four spaces.
* Long press `Esc` to send `` ` ``. Keep pressing to extend it to `` ``` ``.
* `Ctrl + ;` places a semicolon at the end of the line.
* `CapsLock + Z` opens a terminal. `CapsLock + A + Z` opens it with administrator access.
* `CapsLock + S` sends `Ctrl + A`. `CapsLock + A + S` sends `Ctrl + S`. The design is very human.
* `CapsLock + A + 3` places a `#` at the start of the current word. This is useful for when you copy a hex code
  and it doesn't come with the hash, but the program that you paste it in expects one and isn't smart enough
  to figure it out by itself, a personal pet peeve of mine. Due to competing standards, however, there may also
  be a need for a version that _removes_ the `#` from the start of a word. Like comment and subscribe if that's
  something you need in your workflow.
