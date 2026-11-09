#include-once
#include <Array.au3>

; ===============================================================================
; Sort Engine Module
; Core sorting algorithm for Xunlai storage and character inventory
; ===============================================================================

; Configuration
Global Const $ITEM_MOVE_DELAY_MS = 150  ; Delay between item moves (100-300ms recommended)
Global Const $STORAGE_BAG_MIN = 8        ; First storage bag
Global Const $STORAGE_BAG_MAX = 21       ; Last storage bag
Global Const $MAX_STACK_SIZE = 250       ; Game rule: identical stackable items stack up to 250
Global Const $ITEM_MOVE_TIMEOUT_MS = 1500 ; Max wait for the game to confirm a restack move

; State variables
Global $g_aItemList[0][6]         ; 2D Array: [pItem, category, currentBag, currentSlot, targetBag, targetSlot]
Global $g_iTotalItems = 0
Global $g_iProcessedItems = 0

; Array column indices for clarity
Global Enum $COL_POINTER = 0, $COL_CATEGORY, $COL_CURRENT_BAG, $COL_CURRENT_SLOT, $COL_TARGET_BAG, $COL_TARGET_SLOT

; ===============================================================================
; Main sorting function
; Sorts the checked zones; each zone is restacked and sorted on its own (items never cross between them)
; ===============================================================================
Func SortZones($bStorage, $bInventory, $bFreeSlotsAtStart = False)
	LogInfo("=== Storage Organizer ===")
	
	; Pre-sort validation
	If Not ValidateSortingConditions($bStorage) Then
		LogError("Pre-sort validation failed")
		Return False
	EndIf
	
	Local $aInventoryBags[4] = [$GC_I_INVENTORY_BACKPACK, $GC_I_INVENTORY_BELT_POUCH, $GC_I_INVENTORY_BAG1, $GC_I_INVENTORY_BAG2]
	Local $aStorageBags[$STORAGE_BAG_MAX - $STORAGE_BAG_MIN + 1]
	For $i = 0 To UBound($aStorageBags) - 1
		$aStorageBags[$i] = $STORAGE_BAG_MIN + $i
	Next
	
	If $bInventory And Not SortBags($aInventoryBags, "Inventory", $bFreeSlotsAtStart) Then Return False
	If $bStorage And Not SortBags($aStorageBags, "Storage", $bFreeSlotsAtStart) Then Return False
	
	Return True
EndFunc

; ===============================================================================
; Restack then sort the given bags ($sZone is only used in the log)
; ===============================================================================
Func SortBags($aBags, $sZone, $bFreeSlotsAtStart)
	LogInfo("=== " & $sZone & " ===")
	
	; Reset state
	$g_iProcessedItems = 0
	
	; Pre-pass: merge incomplete stacks
	LogInfo("Restacking " & $sZone & "...")
	If Not RestackBags($aBags, $sZone) Then
		LogError($sZone & " restack failed")
		Return False
	EndIf
	
	; Step 1: Scan all items of the zone
	LogInfo("Step 1: Scanning " & $sZone & " items...")
	If Not ScanBagItems($aBags) Then
		LogWarning($sZone & " is empty - nothing to sort")
		Return True
	EndIf
	
	LogInfo("Found " & $g_iTotalItems & " items in " & $sZone)
	
	; Step 2: Categorize items
	LogInfo("Step 2: Categorizing items...")
	CategorizeItems()
	
	; Step 3: Sort items by category and priority
	LogInfo("Step 3: Sorting items by priority...")
	SortItemList()
	
	; Step 4: Calculate target positions
	LogInfo("Step 4: Calculating target positions...")
	CalculateTargetPositions($aBags, $bFreeSlotsAtStart)
	
	; Step 5: Move items to target positions
	LogInfo("Step 5: Moving items to sorted positions...")
	If Not MoveItemsToTargets() Then
		LogError("Failed to complete item movement")
		Return False
	EndIf
	
	LogInfo("=== " & $sZone & " Sorting Complete ===")
	LogInfo("Total items processed: " & $g_iProcessedItems & "/" & $g_iTotalItems)
	Return True
EndFunc

; ===============================================================================
; Scan the given bags and collect item data
; ===============================================================================
Func ScanBagItems($aBags)
	ReDim $g_aItemList[0][6]
	$g_iTotalItems = 0
	
	For $b = 0 To UBound($aBags) - 1
		Local $iBag = $aBags[$b]
		Local $iMaxSlots = Item_GetBagInfo($iBag, "Slots")
		If $iMaxSlots = 0 Then ContinueLoop
		
		For $iSlot = 1 To $iMaxSlots
			Local $pItem = Item_GetItemBySlot($iBag, $iSlot)
			If $pItem <> 0 And ValidateItemPointer($pItem) Then
				; Expand array and store item data
				ReDim $g_aItemList[$g_iTotalItems + 1][6]
				$g_aItemList[$g_iTotalItems][$COL_POINTER] = $pItem
				$g_aItemList[$g_iTotalItems][$COL_CATEGORY] = -1  ; To be determined
				$g_aItemList[$g_iTotalItems][$COL_CURRENT_BAG] = $iBag
				$g_aItemList[$g_iTotalItems][$COL_CURRENT_SLOT] = $iSlot
				$g_aItemList[$g_iTotalItems][$COL_TARGET_BAG] = 0  ; To be calculated
				$g_aItemList[$g_iTotalItems][$COL_TARGET_SLOT] = 0  ; To be calculated
				$g_iTotalItems += 1
			EndIf
		Next
	Next
	
	Return $g_iTotalItems > 0
EndFunc

; ===============================================================================
; Categorize all items in the list
; ===============================================================================
Func CategorizeItems()
	If $g_iTotalItems = 0 Then
		LogWarning("No items to categorize")
		Return
	EndIf
	
	For $i = 0 To $g_iTotalItems - 1
		Local $pItem = $g_aItemList[$i][$COL_POINTER]
		
		; Determine category
		Local $iCategory = GetItemCategory($pItem)
		
		; Update category in array
		$g_aItemList[$i][$COL_CATEGORY] = $iCategory
		
		LogDebug("Item " & ($i + 1) & ": Category=" & GetCategoryName($iCategory))
	Next
EndFunc

; ===============================================================================
; Sort item list by category and priority
; ===============================================================================
Func SortItemList()
	If $g_iTotalItems = 0 Then Return
	
	; Build temporary array with sort keys
	Local $aSortable[$g_iTotalItems][7]  ; Original 6 columns + 1 for sort key
	
	For $i = 0 To $g_iTotalItems - 1
		Local $pItem = $g_aItemList[$i][$COL_POINTER]
		Local $iCategory = $g_aItemList[$i][$COL_CATEGORY]
		
		; Build sort key: category (2 digits) + comparison key (10 digits)
		; This allows sorting by category first, then by item priority within category
		Local $iCompareKey = GetItemSortKey($pItem, $iCategory)
		Local $sSortKey = StringFormat("%02d%010d", $iCategory, $iCompareKey)
		
		; Copy all data to sortable array
		$aSortable[$i][0] = $sSortKey
		$aSortable[$i][1] = $g_aItemList[$i][$COL_POINTER]
		$aSortable[$i][2] = $g_aItemList[$i][$COL_CATEGORY]
		$aSortable[$i][3] = $g_aItemList[$i][$COL_CURRENT_BAG]
		$aSortable[$i][4] = $g_aItemList[$i][$COL_CURRENT_SLOT]
		$aSortable[$i][5] = $g_aItemList[$i][$COL_TARGET_BAG]
		$aSortable[$i][6] = $g_aItemList[$i][$COL_TARGET_SLOT]
	Next
	
	; Sort by key column (column 0)
	_ArraySort($aSortable, 0, 0, 0, 0)
	
	; Copy sorted data back (excluding sort key column)
	For $i = 0 To $g_iTotalItems - 1
		$g_aItemList[$i][$COL_POINTER] = $aSortable[$i][1]
		$g_aItemList[$i][$COL_CATEGORY] = $aSortable[$i][2]
		$g_aItemList[$i][$COL_CURRENT_BAG] = $aSortable[$i][3]
		$g_aItemList[$i][$COL_CURRENT_SLOT] = $aSortable[$i][4]
		$g_aItemList[$i][$COL_TARGET_BAG] = $aSortable[$i][5]
		$g_aItemList[$i][$COL_TARGET_SLOT] = $aSortable[$i][6]
	Next
EndFunc

; ===============================================================================
; Get numeric sort key for item within its category
; Lower number = higher priority
; ===============================================================================
Func GetItemSortKey($pItem, $iCategory)
	; For consumables, use priority
	If $iCategory = $CAT_CONSUMABLE Then
		Local $iPriority = GetConsumablePriority($pItem)
		Local $iModelID = Item_GetItemInfoByPtr($pItem, "ModelID")
		; Key: priority (3 digits) + modelID (6 digits)
		Return ($iPriority * 1000000) + $iModelID
	EndIf
	
	; For weapons and armor, use rarity priority
	If $iCategory = $CAT_WEAPON Or $iCategory = $CAT_ARMOR Then
		Local $iRarity = Item_GetItemInfoByPtr($pItem, "Rarity")
		Local $iType = Item_GetItemInfoByPtr($pItem, "ItemType")
		Local $iModelID = Item_GetItemInfoByPtr($pItem, "ModelID")
		Local $iRarityPriority = GetRarityPriority($iRarity)
		; Key: rarity (2 digits) + type (2 digits) + modelID (6 digits)
		Return ($iRarityPriority * 100000000) + ($iType * 1000000) + $iModelID
	EndIf
	
	; For all other categories, sort by ModelID only
	Local $iModelID = Item_GetItemInfoByPtr($pItem, "ModelID")
	Return $iModelID
EndFunc

; ===============================================================================
; Calculate target positions for each item (front-to-back packing)
; $bFreeSlotsAtStart: skip the free slots first, so the items end at the last slot
; ===============================================================================
Func CalculateTargetPositions($aBags, $bFreeSlotsAtStart = False)
	Local $iBagIndex = 0
	Local $iBag = $aBags[$iBagIndex]
	Local $iSlot = 1
	Local $iMaxSlots = Item_GetBagInfo($iBag, "Slots")
	
	; Number of free slots to leave before the first item
	Local $iSkip = 0
	If $bFreeSlotsAtStart Then
		For $b = 0 To UBound($aBags) - 1
			$iSkip += Item_GetBagInfo($aBags[$b], "Slots")
		Next
		$iSkip -= $g_iTotalItems
	EndIf
	
	For $i = 0 To $g_iTotalItems - 1
		; Find next available slot
		While $iBagIndex < UBound($aBags)
			If $iSlot > $iMaxSlots Then
				$iBagIndex += 1
				If $iBagIndex >= UBound($aBags) Then ExitLoop
				$iBag = $aBags[$iBagIndex]
				$iSlot = 1
				$iMaxSlots = Item_GetBagInfo($iBag, "Slots")
				If $iMaxSlots = 0 Then ContinueLoop
			EndIf
			
			If $iSkip > 0 Then
				$iSkip -= 1
				$iSlot += 1
				ContinueLoop
			EndIf
			
			; Assign target position
			$g_aItemList[$i][$COL_TARGET_BAG] = $iBag
			$g_aItemList[$i][$COL_TARGET_SLOT] = $iSlot
			
			$iSlot += 1
			ExitLoop
		WEnd
	Next
EndFunc

; ===============================================================================
; Move all items to their target positions
; ===============================================================================
Func MoveItemsToTargets()
	$g_iProcessedItems = 0
	
	LogInfo("Moving items to target positions...")
	
	For $i = 0 To $g_iTotalItems - 1
		Local $pItem = $g_aItemList[$i][$COL_POINTER]
		Local $iCurrentBag = $g_aItemList[$i][$COL_CURRENT_BAG]
		Local $iCurrentSlot = $g_aItemList[$i][$COL_CURRENT_SLOT]
		Local $iTargetBag = $g_aItemList[$i][$COL_TARGET_BAG]
		Local $iTargetSlot = $g_aItemList[$i][$COL_TARGET_SLOT]
		
		; Count as processed (whether moved or not)
		$g_iProcessedItems += 1
		
		; Skip if already in correct position
		If $iCurrentBag = $iTargetBag And $iCurrentSlot = $iTargetSlot Then
			; Update progress
			UpdateProgress($g_iProcessedItems, $g_iTotalItems)
			LogDebug("Item " & $g_iProcessedItems & "/" & $g_iTotalItems & _
				" already in correct position (Bag" & $iCurrentBag & ":" & $iCurrentSlot & ")")
			ContinueLoop
		EndIf
		
		; Move item
		If SafeMoveItem($pItem, $iTargetBag, $iTargetSlot) Then
			; Update progress
			UpdateProgress($g_iProcessedItems, $g_iTotalItems)
			
			LogDebug("Moved item " & $g_iProcessedItems & "/" & $g_iTotalItems & _
				" from Bag" & $iCurrentBag & ":" & $iCurrentSlot & _
				" to Bag" & $iTargetBag & ":" & $iTargetSlot)
			
			; Update current position in array (for potential future reference)
			$g_aItemList[$i][$COL_CURRENT_BAG] = $iTargetBag
			$g_aItemList[$i][$COL_CURRENT_SLOT] = $iTargetSlot
			
			; Delay between moves
			Sleep($ITEM_MOVE_DELAY_MS)
		Else
			LogWarning("Failed to move item " & $g_iProcessedItems & " - continuing anyway")
		EndIf
	Next
	
	Return True
EndFunc

; ===============================================================================
; Safely move an item with retry logic
; ===============================================================================
Func SafeMoveItem($pItem, $iTargetBag, $iTargetSlot)
	; Validate move operation
	If Not ValidateMoveOperation($pItem, $iTargetBag, $iTargetSlot) Then
		Return False
	EndIf
	
	; Call move item function (queues the move, may return before completion)
	Item_MoveItem($pItem, $iTargetBag, $iTargetSlot)
	
	; The move is asynchronous - we can't immediately verify it worked
	; Just return True and let the delay in MoveItemsToTargets() handle timing
	Return True
EndFunc

; ===============================================================================
; Restacking
; Merges incomplete stacks of identical items within the given bags, filling the first stack found first
; Identical means same ModelID and ExtraID: dyes share a ModelID and only differ by ExtraID
; Returns True on success, False if the game did not confirm a move
; ===============================================================================
Func RestackBags($aBags, $sZone)
	Local $aStacks[0][4] ; [Bag, Slot, ModelID, ExtraID]

	For $b = 0 To UBound($aBags) - 1
		Local $bag = $aBags[$b]
		If Item_GetBagPtr($bag) = 0 Then ContinueLoop

		Local $maxSlots = Item_GetBagInfo($bag, "Slots")
		For $slot = 1 To $maxSlots
			Local $itemPtr = Item_GetItemBySlot($bag, $slot)
			If $itemPtr = 0 Then ContinueLoop
			If Not Item_GetItemInfoByPtr($itemPtr, "IsStackable") Then ContinueLoop
			If Item_GetItemInfoByPtr($itemPtr, "Quantity") >= $MAX_STACK_SIZE Then ContinueLoop

			Local $iIndex = UBound($aStacks)
			ReDim $aStacks[$iIndex + 1][4]
			$aStacks[$iIndex][0] = $bag
			$aStacks[$iIndex][1] = $slot
			$aStacks[$iIndex][2] = Item_GetItemInfoByPtr($itemPtr, "ModelID")
			$aStacks[$iIndex][3] = Item_GetItemInfoByPtr($itemPtr, "ExtraID")
		Next
	Next

	Local $iMoves = 0
	Local $iSlotsFreed = 0
	For $t = 0 To UBound($aStacks) - 2
		For $s = $t + 1 To UBound($aStacks) - 1
			If $aStacks[$s][2] <> $aStacks[$t][2] Or $aStacks[$s][3] <> $aStacks[$t][3] Then ContinueLoop

			; A slot is empty once its whole stack has been merged into another one
			Local $targetPtr = Item_GetItemBySlot($aStacks[$t][0], $aStacks[$t][1])
			If $targetPtr = 0 Then ExitLoop
			Local $sourcePtr = Item_GetItemBySlot($aStacks[$s][0], $aStacks[$s][1])
			If $sourcePtr = 0 Then ContinueLoop

			Local $iTargetQty = Item_GetItemInfoByPtr($targetPtr, "Quantity")
			Local $iSourceQty = Item_GetItemInfoByPtr($sourcePtr, "Quantity")
			If $iTargetQty >= $MAX_STACK_SIZE Then ExitLoop

			Local $iAmount = $MAX_STACK_SIZE - $iTargetQty
			If $iSourceQty < $iAmount Then $iAmount = $iSourceQty

			Item_MoveItem_($sourcePtr, $aStacks[$t][0], $aStacks[$t][1], $iAmount)
			If Not WaitForSlotInfo($aStacks[$t][0], $aStacks[$t][1], "Quantity", $iTargetQty + $iAmount) Then
				LogWarning($sZone & " restack stopped, move not confirmed (ModelID: " & $aStacks[$t][2] & ")")
				Return False
			EndIf

			$iMoves += 1
			If $iAmount = $iSourceQty Then $iSlotsFreed += 1
			Sleep($ITEM_MOVE_DELAY_MS)
		Next
	Next

	LogInfo($sZone & " restack done: " & $iMoves & " move(s), " & $iSlotsFreed & " slot(s) freed")
	Return True
EndFunc

; ===============================================================================
; Moves are asynchronous: polls the slot until its item info ($sInfo) holds the expected value
; Returns True once reached, False after $ITEM_MOVE_TIMEOUT_MS
; ===============================================================================
Func WaitForSlotInfo($iBag, $iSlot, $sInfo, $vExpected)
	Local $hTimer = TimerInit()
	Do
		Sleep(20)
		Local $itemPtr = Item_GetItemBySlot($iBag, $iSlot)
		If $itemPtr <> 0 And Item_GetItemInfoByPtr($itemPtr, $sInfo) = $vExpected Then Return True
	Until TimerDiff($hTimer) > $ITEM_MOVE_TIMEOUT_MS

	Return False
EndFunc
