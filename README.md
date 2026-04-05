# Custom Keymaps
Custom keymaps for Windows, implemented in AutoHotKey. Designed for programmers who don't use full keyboards, 
don't like moving their hands, and/or don't always have the privilege of working in an code editor
but still want nice keyboard shortcuts.
<br><br>
<a href="https://www.keyboard-layout-editor.com/#/gists/db2921cd66d6b2ea9edfafbfa96ef98d">
    <img width="1300" height="735" alt="image" 
src="https://github.com/user-attachments/assets/249e7bda-5825-417c-8012-bf71d104bc2e"/>
</a>

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
* `CapsLock + Z` opens the Command Prompt. `CapsLock + A + Z` opens it with administrator access.
* `CapsLock + S` sends `Ctrl + A`. `CapsLock + A + S` sends `Ctrl + S`. The design is very human.
* `CapsLock + A + 3` places a `#` at the start of the current word. This is useful for when you copy a hex code
  and it doesn't come with the hash, but the program that you paste it in expects one and isn't smart enough
  to figure it out by itself, a personal pet peeve of mine. Due to competing standards, however, there may also
  be a need for a version that _removes_ the `#` from the start of a word. Like comment and subscribe if that's
  something you need in your workflow.
