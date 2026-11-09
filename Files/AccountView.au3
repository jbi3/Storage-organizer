#include-once
#include <GUIConstantsEx.au3>
#include <StaticConstants.au3>

; ===============================================================================
; Account View Module
; Read-only window showing the content read by ReadAccountContent(), laid out
; like the game: storage panes 5x5, material storage 3 columns, bags 5 columns.
; Cells only show data: clicking them does nothing.
; ===============================================================================

Global $g_hViewGUI = 0
Global $g_aViewTabs[16] ; Tab item IDs: panes I-XIV, Materials, Inventory

Global Const $VIEW_WIDTH = 620
Global Const $VIEW_MARGIN = 15
Global Const $VIEW_TAB_TOP = 35   ; Room for the tab headers
Global Const $VIEW_COLS = 5
Global Const $VIEW_CELL = 44
Global Const $VIEW_GAP = 4
Global Const $VIEW_MAT_COLS = 3
Global Const $VIEW_MAT_CELL_W = 180
Global Const $VIEW_MAT_CELL_H = 32

Global Const $VIEW_COLOR_EMPTY = 0x3A3A3A
Global Const $VIEW_COLOR_UNREADABLE = 0x9A9A9A
Global Const $VIEW_COLOR_UNKNOWN_RARITY = 0xC8C8C8

; Material storage slots shown in game, in display order (slots 8, 29 and 39-42 are not shown)
Global Const $VIEW_MATERIAL_SLOTS[36] = [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, _
	22, 23, 24, 25, 26, 27, 28, 30, 31, 32, 33, 34, 35, 36, 37, 38]

Global Const $VIEW_PANE_LABELS[14] = ["I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X", "XI", "XII", "XIII", "XIV"]

; ===============================================================================
; Open (or replace) the view window with the content read
; $aBagSlots: slot count per bag, indexed like GetReadBags()
; ===============================================================================
Func ShowAccountView(ByRef $aContent, ByRef $aBagSlots, $hParent)
	CloseAccountView()

	Local $aIndex = _ViewBuildIndex($aContent)

	; Inventory bags stack in one 5-column grid, each bag starting a new row
	Local $iInventoryRows = 0
	For $b = 15 To 18
		$iInventoryRows += Ceiling($aBagSlots[$b] / $VIEW_COLS)
	Next

	Local $iGridHeight = $iInventoryRows * ($VIEW_CELL + $VIEW_GAP)
	Local $iMaterialHeight = Ceiling(UBound($VIEW_MATERIAL_SLOTS) / $VIEW_MAT_COLS) * ($VIEW_MAT_CELL_H + $VIEW_GAP)
	If $iMaterialHeight > $iGridHeight Then $iGridHeight = $iMaterialHeight
	If 5 * ($VIEW_CELL + $VIEW_GAP) > $iGridHeight Then $iGridHeight = 5 * ($VIEW_CELL + $VIEW_GAP)
	Local $iHeight = $VIEW_TAB_TOP + $iGridHeight + 2 * $VIEW_MARGIN

	$g_hViewGUI = GUICreate("Account view", $VIEW_WIDTH, $iHeight, -1, -1, -1, -1, $hParent)
	GUICtrlCreateTab(5, 5, $VIEW_WIDTH - 10, $iHeight - 10)

	; Storage panes I-XIV (bags 8-21)
	For $p = 0 To 13
		$g_aViewTabs[$p] = GUICtrlCreateTabItem($VIEW_PANE_LABELS[$p])
		If $aBagSlots[$p] = 0 Then
			GUICtrlCreateLabel("Pane not available", $VIEW_MARGIN, $VIEW_TAB_TOP + $VIEW_MARGIN, 200, 20)
		Else
			_ViewDrawBag($GC_I_INVENTORY_STORAGE1 + $p, $aBagSlots[$p], 0, $aContent, $aIndex)
		EndIf
	Next

	; Material storage: 3 columns of "quantity name", missing materials shown as 0
	$g_aViewTabs[14] = GUICtrlCreateTabItem("Materials")
	For $m = 0 To UBound($VIEW_MATERIAL_SLOTS) - 1
		Local $x = $VIEW_MARGIN + Mod($m, $VIEW_MAT_COLS) * ($VIEW_MAT_CELL_W + $VIEW_GAP)
		Local $y = $VIEW_TAB_TOP + $VIEW_MARGIN + Int($m / $VIEW_MAT_COLS) * ($VIEW_MAT_CELL_H + $VIEW_GAP)
		_ViewItemCell($x, $y, $VIEW_MAT_CELL_W, $VIEW_MAT_CELL_H, $GC_I_INVENTORY_MATERIAL_STORAGE, $VIEW_MATERIAL_SLOTS[$m], $aContent, $aIndex, True)
	Next

	; Inventory: backpack, belt pouch, bag 1, bag 2
	$g_aViewTabs[15] = GUICtrlCreateTabItem("Inventory")
	Local $iRow = 0
	Local $aInventoryBags[4] = [$GC_I_INVENTORY_BACKPACK, $GC_I_INVENTORY_BELT_POUCH, $GC_I_INVENTORY_BAG1, $GC_I_INVENTORY_BAG2]
	For $b = 0 To 3
		$iRow = _ViewDrawBag($aInventoryBags[$b], $aBagSlots[15 + $b], $iRow, $aContent, $aIndex)
	Next

	GUICtrlCreateTabItem("")
	GUISetState(@SW_SHOW, $g_hViewGUI)
	GUISwitch($hParent)
	Return $g_hViewGUI
EndFunc

Func CloseAccountView()
	If $g_hViewGUI <> 0 Then GUIDelete($g_hViewGUI)
	$g_hViewGUI = 0
EndFunc

; Remove the game colour tags, e.g. "<c=#00FF00>Green Rock Candy</c>"
Func CleanItemName($sName)
	Return StringStripWS(StringRegExpReplace($sName, "<[^>]*>", ""), 3)
EndFunc

Func GetRarityColor($iRarity)
	Switch $iRarity
		Case $GC_I_RARITY_WHITE
			Return 0xEDEDED
		Case $GC_I_RARITY_BLUE
			Return 0x9DC3FF
		Case $GC_I_RARITY_PURPLE
			Return 0xC9A0FF
		Case $GC_I_RARITY_GOLD
			Return 0xFFD966
		Case $GC_I_RARITY_GREEN
			Return 0x8FD694
	EndSwitch
	Return $VIEW_COLOR_UNKNOWN_RARITY
EndFunc

; ===============================================================================
; Internal helpers
; ===============================================================================

; [bag][slot] -> row of $aContent, -1 when the slot is empty
Func _ViewBuildIndex(ByRef $aContent)
	Local $aIndex[22][43]
	For $b = 0 To 21
		For $s = 0 To 42
			$aIndex[$b][$s] = -1
		Next
	Next
	For $i = 0 To UBound($aContent) - 1
		Local $iBag = $aContent[$i][$READ_COL_BAG]
		Local $iSlot = $aContent[$i][$READ_COL_SLOT]
		If $iBag >= 0 And $iBag <= 21 And $iSlot >= 0 And $iSlot <= 42 Then $aIndex[$iBag][$iSlot] = $i
	Next
	Return $aIndex
EndFunc

; Draw one bag as a 5-column grid starting at $iFirstRow; returns the next free row
Func _ViewDrawBag($iBag, $iSlots, $iFirstRow, ByRef $aContent, ByRef $aIndex)
	For $s = 1 To $iSlots
		Local $x = $VIEW_MARGIN + Mod($s - 1, $VIEW_COLS) * ($VIEW_CELL + $VIEW_GAP)
		Local $y = $VIEW_TAB_TOP + $VIEW_MARGIN + ($iFirstRow + Int(($s - 1) / $VIEW_COLS)) * ($VIEW_CELL + $VIEW_GAP)
		_ViewItemCell($x, $y, $VIEW_CELL, $VIEW_CELL, $iBag, $s, $aContent, $aIndex, False)
	Next
	Return $iFirstRow + Ceiling($iSlots / $VIEW_COLS)
EndFunc

Func _ViewItemCell($x, $y, $iW, $iH, $iBag, $iSlot, ByRef $aContent, ByRef $aIndex, $bMaterial)
	Local $i = $aIndex[$iBag][$iSlot]
	Local $idCell

	If $i < 0 Then
		Local $sEmpty = ""
		If $bMaterial Then $sEmpty = "0"
		$idCell = GUICtrlCreateLabel($sEmpty, $x, $y, $iW, $iH, $SS_NOTIFY)
		GUICtrlSetBkColor($idCell, $VIEW_COLOR_EMPTY)
		GUICtrlSetColor($idCell, 0xFFFFFF)
		Return
	EndIf

	Local $sName = CleanItemName($aContent[$i][$READ_COL_NAME])
	Local $iQuantity = $aContent[$i][$READ_COL_QUANTITY]

	If $sName = "" Or $sName = "Unknown" Then
		$idCell = GUICtrlCreateLabel("?", $x, $y, $iW, $iH, BitOR($SS_NOTIFY, $SS_CENTER, $SS_CENTERIMAGE))
		GUICtrlSetBkColor($idCell, $VIEW_COLOR_UNREADABLE)
		GUICtrlSetTip($idCell, "Unknown item (model " & $aContent[$i][$READ_COL_MODELID] & ") x" & $iQuantity)
		Return
	EndIf

	; Like the game: the quantity shows only on stacks; materials show "quantity name"
	Local $sText = ""
	If $bMaterial Then
		$sText = $iQuantity & "  " & $sName
	ElseIf $iQuantity > 1 Then
		$sText = $iQuantity
	EndIf

	$idCell = GUICtrlCreateLabel($sText, $x, $y, $iW, $iH, $SS_NOTIFY)
	GUICtrlSetFont($idCell, 8)
	GUICtrlSetBkColor($idCell, GetRarityColor($aContent[$i][$READ_COL_RARITY]))
	GUICtrlSetTip($idCell, $sName & " x" & $iQuantity)
EndFunc
