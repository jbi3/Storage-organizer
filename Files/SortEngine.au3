#include-once
#include <Array.au3>

; ===============================================================================
; Sort Engine Module
; Core sorting algorithm for Xunlai storage
; ===============================================================================

; Configuration
Global Const $ITEM_MOVE_DELAY_MS = 150  ; Delay between item moves (100-300ms recommended)
Global Const $STORAGE_BAG_MIN = 8        ; First storage bag
Global Const $STORAGE_BAG_MAX = 21       ; Last storage bag
Global Const $MAX_STACK_SIZE = 250       ; Game rule: identical stackable items stack up to 250
Global Const $ITEM_MOVE_TIMEOUT_MS = 1500 ; Max wait for the game to confirm a restack move
Global Const $MATERIAL_DEPOSIT_TIMEOUT_MS = 3000 ; Max wait for the game to empty the inventory slots after a deposit

; State variables
Global $g_aItemList[0][6]         ; 2D Array: [pItem, category, currentBag, currentSlot, targetBag, targetSlot]
Global $g_iTotalItems = 0
Global $g_iProcessedItems = 0

; Array column indices for clarity
Global Enum $COL_POINTER = 0, $COL_CATEGORY, $COL_CURRENT_BAG, $COL_CURRENT_SLOT, $COL_TARGET_BAG, $COL_TARGET_SLOT

; ===============================================================================
; Main sorting function
; ===============================================================================
Func SortXunlaiStorage($bFreeSlotsAtStart = False, $bDepositMaterials = False)
	LogInfo("=== Storage Organizer ===")

	; Reset state
	$g_iProcessedItems = 0

	; Pre-sort validation
	If Not ValidateSortingConditions() Then
		LogError("Pre-sort validation failed")
		Return False
	EndIf

	Local $aInventoryBags[4] = [$GC_I_INVENTORY_BACKPACK, $GC_I_INVENTORY_BELT_POUCH, $GC_I_INVENTORY_BAG1, $GC_I_INVENTORY_BAG2]
	Local $aStorageBags[$STORAGE_BAG_MAX - $STORAGE_BAG_MIN + 1]
	For $i = 0 To UBound($aStorageBags) - 1
		$aStorageBags[$i] = $STORAGE_BAG_MIN + $i
	Next

	; Optional pre-pass: free space by sending the materials to the material storage
	If $bDepositMaterials Then
		LogInfo("Depositing materials to the material storage...")
		UpdateStatus("Depositing materials...")
		If Not DepositMaterials($aInventoryBags, $aStorageBags) Then
			LogError("Material deposit failed")
			Return False
		EndIf
		UpdateStatus("Sorting...")
	EndIf

	; Pre-pass: merge incomplete stacks, inventory and storage separately (items never cross between them)
	LogInfo("Restacking inventory and storage...")
	If Not RestackBags($aInventoryBags, "Inventory") Or Not RestackBags($aStorageBags, "Storage") Then
		LogError("Restack failed")
		Return False
	EndIf
	
	; Step 1: Scan all storage items
	LogInfo("Step 1: Scanning storage items...")
	If Not ScanStorageItems() Then
		LogError("Failed to scan storage items")
		Return False
	EndIf
	
	LogInfo("Found " & $g_iTotalItems & " items in storage")
	
	; Step 2: Categorize items
	LogInfo("Step 2: Categorizing items...")
	CategorizeItems()
	
	; Step 3: Sort items by category and priority
	LogInfo("Step 3: Sorting items by priority...")
	SortItemList()
	
	; Step 4: Calculate target positions
	LogInfo("Step 4: Calculating target positions...")
	CalculateTargetPositions($bFreeSlotsAtStart)
	
	; Step 5: Move items to target positions
	LogInfo("Step 5: Moving items to sorted positions...")
	If Not MoveItemsToTargets() Then
		LogError("Failed to complete item movement")
		Return False
	EndIf
	
	LogInfo("=== Sorting Complete ===")
	LogInfo("Total items processed: " & $g_iProcessedItems & "/" & $g_iTotalItems)
	Return True
EndFunc

; ===============================================================================
; Scan all storage bags and collect item data
; ===============================================================================
Func ScanStorageItems()
	ReDim $g_aItemList[0][6]
	$g_iTotalItems = 0
	
	For $iBag = $STORAGE_BAG_MIN To $STORAGE_BAG_MAX
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
Func CalculateTargetPositions($bFreeSlotsAtStart = False)
	Local $iBag = $STORAGE_BAG_MIN
	Local $iSlot = 1
	Local $iMaxSlots = Item_GetBagInfo($iBag, "Slots")
	
	; Number of free slots to leave before the first item
	Local $iSkip = 0
	If $bFreeSlotsAtStart Then
		For $iCountBag = $STORAGE_BAG_MIN To $STORAGE_BAG_MAX
			$iSkip += Item_GetBagInfo($iCountBag, "Slots")
		Next
		$iSkip -= $g_iTotalItems
	EndIf
	
	For $i = 0 To $g_iTotalItems - 1
		; Find next available slot
		While $iBag <= $STORAGE_BAG_MAX
			If $iSlot > $iMaxSlots Then
				$iBag += 1
				If $iBag > $STORAGE_BAG_MAX Then ExitLoop
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
; Material deposit
; Sends the common and rare materials of the inventory and of the Xunlai storage to the material storage
; The game's own "deposit all materials" only reads the inventory: storage materials transit through
; the free inventory slots, then the game places them in the right material slot
; A stack that does not fit (material storage full for it) goes back to its storage slot
; Returns True on success, False if the game did not confirm a move
; ===============================================================================
Func DepositMaterials($aInventoryBags, $aStorageBags)
	; Inventory materials: the game deposits them directly, leftovers stay in the inventory
	Local $aInvStacks = FindMaterialStacks($aInventoryBags, "|")
	If UBound($aInvStacks) > 0 Then
		If Not Item_DepositAllMaterials() Then LogWarning("Game refused the material deposit (error " & @error & ")")
		Local $iKept = WaitForSlotsEmpty($aInvStacks)
		LogInfo("Inventory: " & (UBound($aInvStacks) - $iKept) & " material stack(s) deposited")
		If $iKept > 0 Then LogWarning("Inventory: " & $iKept & " material stack(s) kept, material storage full")
	EndIf

	; Storage materials: transit through the free inventory slots, then deposit
	Local $sFullModels = "|" ; ModelIDs that no longer fit in the material storage
	Local $iDeposited = 0
	Local $iReturned = 0
	While True
		Local $aStacks = FindMaterialStacks($aStorageBags, $sFullModels)
		If UBound($aStacks) = 0 Then ExitLoop

		Local $aFree = FindFreeSlots($aInventoryBags)
		If UBound($aFree) = 0 Then
			LogWarning("Storage: no free inventory slot, " & UBound($aStacks) & " material stack(s) left in storage")
			ExitLoop
		EndIf

		; As many stacks as free inventory slots go to the inventory
		Local $iCount = UBound($aStacks)
		If UBound($aFree) < $iCount Then $iCount = UBound($aFree)
		For $i = 0 To $iCount - 1
			Item_MoveItem(Item_GetItemBySlot($aStacks[$i][0], $aStacks[$i][1]), $aFree[$i][0], $aFree[$i][1])
			If Not WaitForSlotInfo($aFree[$i][0], $aFree[$i][1], "ModelID", $aStacks[$i][2]) Then
				LogWarning("Material deposit stopped, move to inventory not confirmed (ModelID: " & $aStacks[$i][2] & ")")
				Return False
			EndIf
			Sleep($ITEM_MOVE_DELAY_MS)
		Next

		If Not Item_DepositAllMaterials() Then LogWarning("Game refused the material deposit (error " & @error & ")")
		WaitForSlotsEmpty($aFree, $iCount)

		; Stacks still in the inventory did not fit, fully or partly: back to their storage slot
		For $i = 0 To $iCount - 1
			Local $pLeft = Item_GetItemBySlot($aFree[$i][0], $aFree[$i][1])
			If $pLeft = 0 Then
				$iDeposited += 1
				ContinueLoop
			EndIf

			$sFullModels &= $aStacks[$i][2] & "|"
			Item_MoveItem($pLeft, $aStacks[$i][0], $aStacks[$i][1])
			If Not WaitForSlotInfo($aStacks[$i][0], $aStacks[$i][1], "ModelID", $aStacks[$i][2]) Then
				LogWarning("Material deposit stopped, move back to storage not confirmed (ModelID: " & $aStacks[$i][2] & ")")
				Return False
			EndIf
			$iReturned += 1
			Sleep($ITEM_MOVE_DELAY_MS)
		Next
	WEnd

	LogInfo("Storage: " & $iDeposited & " material stack(s) deposited")
	If $iReturned > 0 Then LogWarning("Storage: " & $iReturned & " material stack(s) kept, material storage full")
	Return True
EndFunc

; ===============================================================================
; Lists the common and rare material stacks of the given bags: [Bag, Slot, ModelID]
; $sExcludedModels: "|"-separated ModelIDs to skip, e.g. "|929|948|"
; ===============================================================================
Func FindMaterialStacks($aBags, $sExcludedModels)
	Local $aStacks[0][3]
	For $b = 0 To UBound($aBags) - 1
		If Item_GetBagPtr($aBags[$b]) = 0 Then ContinueLoop
		For $slot = 1 To Item_GetBagInfo($aBags[$b], "Slots")
			Local $itemPtr = Item_GetItemBySlot($aBags[$b], $slot)
			If $itemPtr = 0 Then ContinueLoop
			Local $iModelID = Item_GetItemInfoByPtr($itemPtr, "ModelID")
			If Not IsMaterial($iModelID) Then ContinueLoop
			If StringInStr($sExcludedModels, "|" & $iModelID & "|") Then ContinueLoop

			Local $iIndex = UBound($aStacks)
			ReDim $aStacks[$iIndex + 1][3]
			$aStacks[$iIndex][0] = $aBags[$b]
			$aStacks[$iIndex][1] = $slot
			$aStacks[$iIndex][2] = $iModelID
		Next
	Next
	Return $aStacks
EndFunc

; ===============================================================================
; Lists the empty slots of the given bags: [Bag, Slot]
; ===============================================================================
Func FindFreeSlots($aBags)
	Local $aFree[0][2]
	For $b = 0 To UBound($aBags) - 1
		If Item_GetBagPtr($aBags[$b]) = 0 Then ContinueLoop
		For $slot = 1 To Item_GetBagInfo($aBags[$b], "Slots")
			If Item_GetItemBySlot($aBags[$b], $slot) <> 0 Then ContinueLoop
			Local $iIndex = UBound($aFree)
			ReDim $aFree[$iIndex + 1][2]
			$aFree[$iIndex][0] = $aBags[$b]
			$aFree[$iIndex][1] = $slot
		Next
	Next
	Return $aFree
EndFunc

; ===============================================================================
; Deposits are asynchronous: polls the first $iCount slots of $aSlots ([Bag, Slot, ...]) until they are empty
; Returns the number of slots still holding an item after $MATERIAL_DEPOSIT_TIMEOUT_MS
; ===============================================================================
Func WaitForSlotsEmpty($aSlots, $iCount = -1)
	If $iCount < 0 Then $iCount = UBound($aSlots)
	Local $hTimer = TimerInit()
	Local $iLeft
	Do
		Sleep(50)
		$iLeft = 0
		For $i = 0 To $iCount - 1
			If Item_GetItemBySlot($aSlots[$i][0], $aSlots[$i][1]) <> 0 Then $iLeft += 1
		Next
	Until $iLeft = 0 Or TimerDiff($hTimer) > $MATERIAL_DEPOSIT_TIMEOUT_MS
	Return $iLeft
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
