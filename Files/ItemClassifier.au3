#include-once
#include <Array.au3>

; ===============================================================================
; Item Classifier Module
; Handles item categorization and priority determination
; Relies on GwAu3_Const_Item.au3 for item constants (auto-included via _GwAu3.au3)
; ===============================================================================

; High priority consumables (sorted first within consumables category)
Global $g_aHighPriorityConsumables[] = [ _
	$GC_I_MODELID_CUPCAKE, _
	$GC_I_MODELID_ARMOR_OF_SALVATION, _
	$GC_I_MODELID_ESSENCE_OF_CELERITY, _
	$GC_I_MODELID_GRAIL_OF_MIGHT _
]

; ===============================================================================
; Determine item category from item pointer
; ===============================================================================
Func GetItemCategory($pItem)
	If $pItem = 0 Then Return $CAT_UNKNOWN
	
	Local $iModelID = Item_GetItemInfoByPtr($pItem, "ModelID")
	Local $iType = Item_GetItemInfoByPtr($pItem, "ItemType")
	
	; Check materials first
	If IsMaterial($iModelID) Then Return $CAT_MATERIAL
	
	; Check tomes (MUST be before consumables - tomes are also TYPE_USABLE)
	If IsTome($iModelID) Then Return $CAT_TOME
	
	; Check consumables
	If IsConsumable($iModelID, $iType) Then Return $CAT_CONSUMABLE
	
	; Check trophies
	If IsTrophy($iType) Then Return $CAT_TROPHY
	
	; Check weapons
	If IsWeapon($iType) Then Return $CAT_WEAPON
	
	; Check armor
	If IsArmor($iType) Then Return $CAT_ARMOR
	
	; Everything else
	Return $CAT_OTHER
EndFunc

; ===============================================================================
; Check if item is a material
; ===============================================================================
Func IsMaterial($iModelID)
	Return _ArraySearch($GC_AI_ALL_MATERIALS, $iModelID) <> -1
EndFunc

; ===============================================================================
; Check if item is a consumable
; ===============================================================================
Func IsConsumable($iModelID, $iType)
	; Type check for consumables (USABLE type includes consumables)
	If $iType = $GC_I_TYPE_USABLE Then Return True
	
	; Also check specific model IDs for special consumables
	If _ArraySearch($GC_AI_CONSET, $iModelID) <> -1 Then Return True
	If _ArraySearch($GC_AI_PCONS, $iModelID) <> -1 Then Return True
	
	Return False
EndFunc

; ===============================================================================
; Check if item is a tome
; ===============================================================================
Func IsTome($iModelID)
	Return _ArraySearch($GC_AI_ALL_TOMES, $iModelID) <> -1
EndFunc

; ===============================================================================
; Check if item is a trophy
; ===============================================================================
Func IsTrophy($iType)
	Return $iType = $GC_I_TYPE_TROPHY Or $iType = $GC_I_TYPE_TROPHY_2
EndFunc

; ===============================================================================
; Check if item is a weapon
; ===============================================================================
Func IsWeapon($iType)
	Switch $iType
		Case $GC_I_TYPE_BOW, $GC_I_TYPE_AXE, $GC_I_TYPE_HAMMER, $GC_I_TYPE_WAND, _
			$GC_I_TYPE_STAFF, $GC_I_TYPE_SWORD, $GC_I_TYPE_DAGGERS, $GC_I_TYPE_SCYTHE, _
			$GC_I_TYPE_SPEAR, $GC_I_TYPE_OFFHAND, $GC_I_TYPE_SHIELD
			Return True
		Case Else
			Return False
	EndSwitch
EndFunc

; ===============================================================================
; Check if item is armor
; ===============================================================================
Func IsArmor($iType)
	Switch $iType
		Case $GC_I_TYPE_HEADPIECE, $GC_I_TYPE_CHESTPIECE, $GC_I_TYPE_LEGGINS, $GC_I_TYPE_BOOTS, _
			$GC_I_TYPE_GLOVES
			Return True
		Case Else
			Return False
	EndSwitch
EndFunc

; ===============================================================================
; Get consumable priority (lower = higher priority)
; ===============================================================================
Func GetConsumablePriority($pItem)
	Local $iModelID = Item_GetItemInfoByPtr($pItem, "ModelID")
	
	; Priority 1: Birthday cupcakes and consets
	If _ArraySearch($g_aHighPriorityConsumables, $iModelID) <> -1 Then
		Return 1
	EndIf
	
	; Priority 2: Other party consumables
	If _ArraySearch($GC_AI_PCONS, $iModelID) <> -1 Then
		Return 2
	EndIf
	
	; Priority 3: All other consumables
	Return 3
EndFunc

; ===============================================================================
; Compare two items for sorting within same category
; Returns: -1 if item1 < item2, 0 if equal, 1 if item1 > item2
; ===============================================================================
Func CompareItems($pItem1, $pItem2, $iCategory)
	; Special handling for consumables (sort by priority)
	If $iCategory = $CAT_CONSUMABLE Then
		Local $iPriority1 = GetConsumablePriority($pItem1)
		Local $iPriority2 = GetConsumablePriority($pItem2)
		
		If $iPriority1 < $iPriority2 Then Return -1
		If $iPriority1 > $iPriority2 Then Return 1
		
		; Same priority, sort by ModelID
		Local $iModel1 = Item_GetItemInfoByPtr($pItem1, "ModelID")
		Local $iModel2 = Item_GetItemInfoByPtr($pItem2, "ModelID")
		
		If $iModel1 < $iModel2 Then Return -1
		If $iModel1 > $iModel2 Then Return 1
		Return 0
	EndIf
	
	; For weapons and armor, sort by rarity (Gold > Purple > Blue > White)
	If $iCategory = $CAT_WEAPON Or $iCategory = $CAT_ARMOR Then
		Local $iRarity1 = Item_GetItemInfoByPtr($pItem1, "Rarity")
		Local $iRarity2 = Item_GetItemInfoByPtr($pItem2, "Rarity")
		
		Local $iPriority1 = GetRarityPriority($iRarity1)
		Local $iPriority2 = GetRarityPriority($iRarity2)
		
		If $iPriority1 < $iPriority2 Then Return -1
		If $iPriority1 > $iPriority2 Then Return 1
		
		; Same rarity, sort by type then ModelID
		Local $iType1 = Item_GetItemInfoByPtr($pItem1, "ItemType")
		Local $iType2 = Item_GetItemInfoByPtr($pItem2, "ItemType")
		
		If $iType1 < $iType2 Then Return -1
		If $iType1 > $iType2 Then Return 1
		
		Local $iModel1 = Item_GetItemInfoByPtr($pItem1, "ModelID")
		Local $iModel2 = Item_GetItemInfoByPtr($pItem2, "ModelID")
		
		If $iModel1 < $iModel2 Then Return -1
		If $iModel1 > $iModel2 Then Return 1
		Return 0
	EndIf
	
	; For all other categories, sort by ModelID
	Local $iModel1 = Item_GetItemInfoByPtr($pItem1, "ModelID")
	Local $iModel2 = Item_GetItemInfoByPtr($pItem2, "ModelID")
	
	If $iModel1 < $iModel2 Then Return -1
	If $iModel1 > $iModel2 Then Return 1
	Return 0
EndFunc

; ===============================================================================
; Get rarity sorting priority (lower = higher priority)
; ===============================================================================
Func GetRarityPriority($iRarity)
	Switch $iRarity
		Case $GC_I_RARITY_GREEN
			Return 1
		Case $GC_I_RARITY_GOLD
			Return 2
		Case $GC_I_RARITY_PURPLE
			Return 3
		Case $GC_I_RARITY_BLUE
			Return 4
		Case $GC_I_RARITY_WHITE
			Return 5
		Case Else
			Return 99
	EndSwitch
EndFunc
