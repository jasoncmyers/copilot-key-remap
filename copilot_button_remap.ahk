#Requires AutoHotKey v2.0
; Code to intercept the stupid Copilot key and pseudo-remap back to right Ctrl
; The key emits Win + Shift + F23 on key down, then nothing while held or on key up, so it cannot be
; conventionally remapped.
; This uses a filter and timer to eat the initial key combo and then simulate a Ctrl modifier.
; If another non-modifier key is pressed before the timer expires, it emits Ctrl + <key>.  If the timer
; expires without another key press, nothing happens.


; -------------------
; Configuration
; -------------------

CtrlWaitTimeMs := 500	; length to wait for another key press before expiring Ctrl (in miliseconds)


; -------------------
; Helpers
; -------------------

; Check if a key press is a modifier key
IsModifier(keyName) {
	; TODO: remove comment
	k := StrLower(keyName)
	return (k = "lshift" || k = "rshift"
		||  k = "lalt"   || k = "ralt"   || k = "alt"
		||  k = "lwin"   || k = "rwin"   || k = "win"
		||  k = "lctrl"  || k = "rctrl"  || k = "ctrl")
}

; Handle any special case combinations we want separate logic for
HandleSpecialCases(keyName, mods) {
	; Case: Ctrl + Alt + Del is not allowed at user level, so simulate it by triggering TaskManager directly
	if (keyName = "Delete" || keyName = "Del") {
		modsClean := StrReplace(StrReplace(mods, "<"), ">")
		if (modsClean = "!") {
			run "taskmgr.exe"
			return true
		}
	}
	return false
}


; -------------------
; Main function
; -------------------

; Grab the combo emitted by Copilot button (`#+F23` means <win>,<shift>,<F23> keys together)
#+F23:: {
	global CtrlWaitTimeMs

	start := A_TickCount
	remain := CtrlWaitTimeMs

	; Loop until either a non-modifier key is captured or timer expires
	while remain > 0 {
		; Create an input hook to catch a single key (L1) or timer (T) ends
		ih := InputHook("L1 T" . (remain/1000.0))
		ih.KeyOpt("{All}", "E")  ; triggers "End" state on all keypresses
		ih.Start()
		got := ih.Wait()

		; if InputHook timed out or was otherwise cancelled, reset
		if got != "EndKey" {
			return
		}

		key := ih.EndKey
		if IsModifier(key) {
			; Ignore modifiers; continue waiting for another key until original timer runs out
			elapsed := A_TickCount - start
			remain := CtrlWaitTimeMs - elapsed
			Continue
		} else {
			; Non-modifier key pressed.  If it triggers any special cases, skip remaining logic
			if HandleSpecialCases(key, ih.EndMods) {
				return
			}
			; Construct a prefix of existing modifiers + Ctrl
			modPrefix := ih.EndMods . "^"
			; MsgBox "Key pressed with modifiers " . ih.EndMods
			if StrLen(key) = 1
				Send modPrefix . key
			else	; named keys need brackets when emitted
				Send modPrefix . "{" . key . "}"
			return
		}
	}

	; If it reaches here, the loop timer has elapsed, so exit
	return
}