# Custom Keymaps
Custom keymaps for Windows, designed for programmers who don't use full keyboards,
don't like moving their hands, and/or don't always have the privilege of working in an code editor
but still want nice keyboard shortcuts.

Key features:
* Momentary layers with symbols, navigation keys, and other functions accessible via `CapsLock` and `CapsLock + A`
* Remap `Copilot` key back to `Ctrl` or `PrintScreen`
* Quick navigation with inline search
* Programming shortcuts including sub-word deletion, paired bracket templates, quick semicolon line-ending, and more
* Tap-hold behaviors to transform `Tab` to spaces and `Esc` to `` ` ``

## Overview

Choose between modern ijkl arrows or Vim-style hjkl arrows navigation.
<details open>
<summary>Modern Layout (ijkl)</summary>

<a href="https://www.keyboard-layout-editor.com/#/gists/db2921cd66d6b2ea9edfafbfa96ef98d">
<img alt="ijkl arrows" src="https://github.com/user-attachments/assets/249e7bda-5825-417c-8012-bf71d104bc2e"/>
</a>

</details>

<details>
<summary>Vim-style Layout (hjkl)</summary>

<a href="https://www.keyboard-layout-editor.com/#/gists/cb2a720d6b2f191db82fe5f64aead164">
<img width="1287" height="739" alt="hjkl arrows" src="https://github.com/user-attachments/assets/e8767920-592a-4a88-882f-9299368689b6" />
</a>

</details>

## Configuration

Use the config options at the top of `keymap.ahk` to change the following settings: 
* Navigation cluster: ijkl (default) or hjkl arrows
* Copilot key: remap to `Ctrl` (default) or `PrintScreen`
* Preferred terminal: command prompt (default), PowerShell, or any executable of choice

```

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
  <br><br>
* `CapsLock + N` selects the current word
* `CapsLock + A + N` selects the current line

`Win + CapsLock` applies the original `CapsLock` functionality.

## Templates
Keys marked in blue indicate templates, which wrap the cursor in an opening and closing pair.
For example, `( )` acts as `($END$)`.

Half-blue keys have split behavior: the white portion is the base behavior in the **Caps Layer**,
and adding `+ A` inserts the full template.

## Cased Backspace/Delete
Cased backspace and delete remove sub-words in camelCase, PascalCase, and snake_case. For example, cased backspace
turns `fooBar` into `foo`, `FooBar` into `Foo`, and `foo_bar` into `foo`.

## Searching
Inline search allows for quick navigation within a line by jumping to the first, next, or previous occurence
of any search pattern.

To speed up repeated searches, inline search caches the current line and match position. By default, `Find Text`
refreshes the cache, but `Find Next`, `Find Prev`, and `Find Again` use this cached result to jump between matches quickly.
If the line contents or the caret position have changed between searches, use `Find Again` to update the cache.

Search also displays a small textbox where you can type the search pattern.
Press `Enter` to search, `Esc` to cancel, or `/` to clear the current input.

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
