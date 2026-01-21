#include-once

; ===============================================================================
; Safety Validator Module
; Performs pre-sort validation and safety checks
; ===============================================================================

; ===============================================================================
; Validate all sorting conditions before starting
; Returns: True if safe to proceed, False otherwise
; ===============================================================================
Func ValidateSortingConditions()
	LogInfo("=== Starting Pre-Sort Validation ===")
	
	; Check if in game
	If Not Core_GetStatusInGame() Then
		LogError("Validation failed: Character must be logged in")
		Return False
	EndIf
	LogInfo("✓ Character is in game")
	
	; Check if in outpost
	If Not Map_GetInstanceInfo("IsOutpost") Then
		LogError("Validation failed: Character must be in an outpost to sort storage")
		Return False
	EndIf
	LogInfo("✓ Character is in outpost")
	
	; Verify storage bags are accessible
	Local $iStorageBagCount = 0
	For $iBag = $STORAGE_BAG_MIN To $STORAGE_BAG_MAX
		Local $iSlots = Item_GetBagInfo($iBag, "Slots")
		If $iSlots > 0 Then
			$iStorageBagCount += 1
		EndIf
	Next
	
	If $iStorageBagCount = 0 Then
		LogError("Validation failed: No storage bags accessible")
		Return False
	EndIf
	LogInfo("✓ Found " & $iStorageBagCount & " accessible storage bags")
	
	; Count total items in storage
	Local $iTotalItems = 0
	For $iBag = $STORAGE_BAG_MIN To $STORAGE_BAG_MAX
		Local $iItemCount = Item_GetBagInfo($iBag, "ItemCount")
		If $iItemCount > 0 Then
			$iTotalItems += $iItemCount
		EndIf
	Next
	
	LogInfo("✓ Total items in storage: " & $iTotalItems)
	
	If $iTotalItems = 0 Then
		LogWarning("Storage is empty - nothing to sort")
		Return False
	EndIf
	
	LogInfo("=== Validation Complete: All checks passed ===")
	Return True
EndFunc

; ===============================================================================
; Verify item pointer is valid
; ===============================================================================
Func ValidateItemPointer($pItem)
	If $pItem = 0 Then Return False
	
	; Try to read basic item data
	Local $iModelID = Item_GetItemInfoByPtr($pItem, "ModelID")
	If $iModelID = 0 Then Return False
	
	Return True
EndFunc

; ===============================================================================
; Check if storage bag is valid
; ===============================================================================
Func IsValidStorageBag($iBag)
	Return $iBag >= $STORAGE_BAG_MIN And $iBag <= $STORAGE_BAG_MAX
EndFunc

; ===============================================================================
; Check if slot is valid for given bag
; ===============================================================================
Func IsValidSlot($iBag, $iSlot)
	If Not IsValidStorageBag($iBag) Then Return False
	
	Local $iMaxSlots = Item_GetBagInfo($iBag, "Slots")
	Return $iSlot >= 1 And $iSlot <= $iMaxSlots
EndFunc

; ===============================================================================
; Validate move operation before executing
; ===============================================================================
Func ValidateMoveOperation($pItem, $iTargetBag, $iTargetSlot)
	; Validate item
	If Not ValidateItemPointer($pItem) Then
		LogError("Invalid item pointer")
		Return False
	EndIf
	
	; Validate target bag
	If Not IsValidStorageBag($iTargetBag) Then
		LogError("Invalid target bag: " & $iTargetBag)
		Return False
	EndIf
	
	; Validate target slot
	If Not IsValidSlot($iTargetBag, $iTargetSlot) Then
		LogError("Invalid target slot: Bag=" & $iTargetBag & " Slot=" & $iTargetSlot)
		Return False
	EndIf
	
	Return True
EndFunc
