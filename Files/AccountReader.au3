#include-once

; ===============================================================================
; Account Reader Module
; Read-only snapshot of Xunlai storage, material storage and inventory bags.
; Never moves an item and does not require an outpost.
; ===============================================================================

; Column indices of the content array returned by ReadAccountContent()
Global Enum $READ_COL_BAG = 0, $READ_COL_SLOT, $READ_COL_MODELID, $READ_COL_EXTRAID, _
	$READ_COL_NAME, $READ_COL_QUANTITY, $READ_COL_RARITY, $READ_COL_STACKABLE, $READ_COL_COUNT

; Slot count of each bag from the last read, indexed like GetReadBags()
Global $g_aReadBagSlots[0]

; Duration of the last read, in milliseconds
Global $g_iReadDurationMs = 0

; ===============================================================================
; Bags in display order: storage panes 1-14, material storage, then the 4 inventory bags
; ===============================================================================
Func GetReadBags()
	Local $aBags[19]
	For $i = 0 To 13
		$aBags[$i] = $GC_I_INVENTORY_STORAGE1 + $i
	Next
	$aBags[14] = $GC_I_INVENTORY_MATERIAL_STORAGE
	$aBags[15] = $GC_I_INVENTORY_BACKPACK
	$aBags[16] = $GC_I_INVENTORY_BELT_POUCH
	$aBags[17] = $GC_I_INVENTORY_BAG1
	$aBags[18] = $GC_I_INVENTORY_BAG2
	Return $aBags
EndFunc

Func GetReadBagLabel($iBag)
	Switch $iBag
		Case $GC_I_INVENTORY_STORAGE1 To $GC_I_INVENTORY_STORAGE14
			Return "Storage " & ($iBag - $GC_I_INVENTORY_STORAGE1 + 1)
		Case $GC_I_INVENTORY_MATERIAL_STORAGE
			Return "Materials"
		Case $GC_I_INVENTORY_BACKPACK
			Return "Backpack"
		Case $GC_I_INVENTORY_BELT_POUCH
			Return "Belt pouch"
		Case $GC_I_INVENTORY_BAG1
			Return "Bag 1"
		Case $GC_I_INVENTORY_BAG2
			Return "Bag 2"
	EndSwitch
	Return "Bag " & $iBag
EndFunc

; ===============================================================================
; Read every filled slot of the account bags
; Returns a 2D array [n][$READ_COL_COUNT]; @error = 1 if no bag is readable
; ===============================================================================
Func ReadAccountContent()
	Local $hTimer = TimerInit()
	Local $aBags = GetReadBags()
	Local $aContent[0][$READ_COL_COUNT]
	Local $iCount = 0
	Local $iReadableBags = 0
	ReDim $g_aReadBagSlots[UBound($aBags)]

	For $b = 0 To UBound($aBags) - 1
		Local $iBag = $aBags[$b]
		Local $iSlots = Item_GetBagInfo($iBag, "Slots")
		$g_aReadBagSlots[$b] = $iSlots
		If $iSlots = 0 Then ContinueLoop
		$iReadableBags += 1

		For $iSlot = 1 To $iSlots
			Local $pItem = Item_GetItemBySlot($iBag, $iSlot)
			If $pItem = 0 Then ContinueLoop

			ReDim $aContent[$iCount + 1][$READ_COL_COUNT]
			$aContent[$iCount][$READ_COL_BAG] = $iBag
			$aContent[$iCount][$READ_COL_SLOT] = $iSlot
			$aContent[$iCount][$READ_COL_MODELID] = Item_GetItemInfoByPtr($pItem, "ModelID")
			$aContent[$iCount][$READ_COL_EXTRAID] = Item_GetItemInfoByPtr($pItem, "ExtraID")
			$aContent[$iCount][$READ_COL_NAME] = Item_GetItemInfoByPtr($pItem, "Name")
			$aContent[$iCount][$READ_COL_QUANTITY] = Item_GetItemInfoByPtr($pItem, "Quantity")
			$aContent[$iCount][$READ_COL_RARITY] = Item_GetItemInfoByPtr($pItem, "Rarity")
			$aContent[$iCount][$READ_COL_STACKABLE] = Item_GetItemInfoByPtr($pItem, "IsStackable")
			$iCount += 1
		Next
	Next

	$g_iReadDurationMs = Round(TimerDiff($hTimer))
	If $iReadableBags = 0 Then Return SetError(1, 0, $aContent)
	Return $aContent
EndFunc

; ===============================================================================
; Write the content read to the log, bag by bag, with slot counts and read duration
; ===============================================================================
Func DumpAccountContent(ByRef $aContent)
	Local $aBags = GetReadBags()
	LogInfo("=== Account content ===")

	For $b = 0 To UBound($aBags) - 1
		Local $iBag = $aBags[$b]
		Local $iFilled = 0
		For $i = 0 To UBound($aContent) - 1
			If $aContent[$i][$READ_COL_BAG] = $iBag Then $iFilled += 1
		Next
		LogInfo("--- " & GetReadBagLabel($iBag) & " (bag " & $iBag & "): " & $iFilled & "/" & $g_aReadBagSlots[$b] & " slots filled")

		For $i = 0 To UBound($aContent) - 1
			If $aContent[$i][$READ_COL_BAG] <> $iBag Then ContinueLoop
			Local $sName = $aContent[$i][$READ_COL_NAME]
			If $sName = "" Then $sName = "?"
			LogInfo("  slot " & $aContent[$i][$READ_COL_SLOT] & ": " & $sName & _
				" x" & $aContent[$i][$READ_COL_QUANTITY] & _
				" | model " & $aContent[$i][$READ_COL_MODELID] & _
				" extra " & $aContent[$i][$READ_COL_EXTRAID] & _
				" rarity " & $aContent[$i][$READ_COL_RARITY])
		Next
	Next

	LogInfo("Items read: " & UBound($aContent) & " in " & $g_iReadDurationMs & " ms")
EndFunc
