#include-once

; ===============================================================================
; Snapshot Module
; Saves the last successful read of each character to Snapshots\<name>.ini, next
; to the script, so the view can be opened while the game is closed.
; One file per character; it also holds the Xunlai storage as read that day.
; The folder is local data: it is ignored by git.
; ===============================================================================

Global Const $SNAPSHOT_DIR = @ScriptDir & "\Snapshots"
Global Const $SNAPSHOT_VERSION = "1"

; Date of the last snapshot loaded by LoadSnapshot()
Global $g_sSnapshotDate = ""

Func _SnapshotPath($sChar)
	Return $SNAPSHOT_DIR & "\" & StringRegExpReplace($sChar, '[<>:"/\\|?*]', "_") & ".ini"
EndFunc

; ===============================================================================
; Write the content read for $sChar; returns False if the file cannot be written
; ===============================================================================
Func SaveSnapshot($sChar, ByRef $aContent, ByRef $aBagSlots)
	If Not FileExists($SNAPSHOT_DIR) Then DirCreate($SNAPSHOT_DIR)

	Local $sText = "[meta]" & @CRLF & _
		"version=" & $SNAPSHOT_VERSION & @CRLF & _
		"character=" & $sChar & @CRLF & _
		"date=" & @YEAR & "-" & @MON & "-" & @MDAY & " " & @HOUR & ":" & @MIN & @CRLF & _
		"count=" & UBound($aContent) & @CRLF & _
		"[slots]" & @CRLF
	For $b = 0 To UBound($aBagSlots) - 1
		$sText &= "b" & $b & "=" & $aBagSlots[$b] & @CRLF
	Next

	; One line per item: bag|slot|model|extra|quantity|rarity|stackable|name (name last, it may hold any text)
	$sText &= "[items]" & @CRLF
	For $i = 0 To UBound($aContent) - 1
		Local $iStackable = 0
		If $aContent[$i][$READ_COL_STACKABLE] Then $iStackable = 1
		$sText &= "i" & $i & "=" & $aContent[$i][$READ_COL_BAG] & "|" & $aContent[$i][$READ_COL_SLOT] & "|" & _
			$aContent[$i][$READ_COL_MODELID] & "|" & $aContent[$i][$READ_COL_EXTRAID] & "|" & _
			$aContent[$i][$READ_COL_QUANTITY] & "|" & $aContent[$i][$READ_COL_RARITY] & "|" & _
			$iStackable & "|" & $aContent[$i][$READ_COL_NAME] & @CRLF
	Next

	; Written in one go (an IniWrite per item would rewrite the file each time);
	; UTF-16 LE so that IniRead reads any item name
	Local $hFile = FileOpen(_SnapshotPath($sChar), 2 + 32)
	If $hFile = -1 Then Return SetError(1, 0, False)
	FileWrite($hFile, $sText)
	FileClose($hFile)
	Return True
EndFunc

; ===============================================================================
; Load the last snapshot of $sChar; fills $aBagSlots (19 entries, like GetReadBags())
; and $g_sSnapshotDate. @error = 1 if there is no file or it cannot be read:
; an unreadable file is treated as absent.
; ===============================================================================
Func LoadSnapshot($sChar, ByRef $aBagSlots)
	Local $aContent[0][$READ_COL_COUNT]
	Local $sPath = _SnapshotPath($sChar)
	If Not FileExists($sPath) Then Return SetError(1, 0, $aContent)
	If IniRead($sPath, "meta", "version", "") <> $SNAPSHOT_VERSION Then Return SetError(1, 0, $aContent)

	Local $iCount = Number(IniRead($sPath, "meta", "count", "-1"))
	If $iCount < 0 Then Return SetError(1, 0, $aContent)

	For $b = 0 To UBound($aBagSlots) - 1
		$aBagSlots[$b] = Number(IniRead($sPath, "slots", "b" & $b, "0"))
	Next

	ReDim $aContent[$iCount][$READ_COL_COUNT]
	For $i = 0 To $iCount - 1
		Local $aFields = StringSplit(IniRead($sPath, "items", "i" & $i, ""), "|")
		If $aFields[0] < 8 Then Return SetError(1, 0, $aContent)

		; The name is the rest of the line, even if it contains "|"
		Local $sName = $aFields[8]
		For $f = 9 To $aFields[0]
			$sName &= "|" & $aFields[$f]
		Next

		$aContent[$i][$READ_COL_BAG] = Number($aFields[1])
		$aContent[$i][$READ_COL_SLOT] = Number($aFields[2])
		$aContent[$i][$READ_COL_MODELID] = Number($aFields[3])
		$aContent[$i][$READ_COL_EXTRAID] = Number($aFields[4])
		$aContent[$i][$READ_COL_QUANTITY] = Number($aFields[5])
		$aContent[$i][$READ_COL_RARITY] = Number($aFields[6])
		$aContent[$i][$READ_COL_STACKABLE] = ($aFields[7] = "1")
		$aContent[$i][$READ_COL_NAME] = $sName
	Next

	$g_sSnapshotDate = IniRead($sPath, "meta", "date", "?")
	Return $aContent
EndFunc

; ===============================================================================
; Names of the characters that have a snapshot, "|"-separated (combo format)
; ===============================================================================
Func GetSnapshotCharNames()
	Local $sNames = ""
	Local $hSearch = FileFindFirstFile($SNAPSHOT_DIR & "\*.ini")
	If $hSearch = -1 Then Return ""
	While True
		Local $sFile = FileFindNextFile($hSearch)
		If @error Then ExitLoop
		Local $sChar = IniRead($SNAPSHOT_DIR & "\" & $sFile, "meta", "character", "")
		If $sChar = "" Then ContinueLoop
		If $sNames <> "" Then $sNames &= "|"
		$sNames &= $sChar
	WEnd
	FileClose($hSearch)
	Return $sNames
EndFunc
