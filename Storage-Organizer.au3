#cs =============================================================================================================================
	Storage Organizer version 1.0
	Author: Arca
	Status: Public
    Purpose: Effortlessly organize Xunlai Storage.

    Automatically sorts storage items by category:
		1. Materials
		2. Consumables (priority: cupcakes, consets, other pcons)
		3. Tomes
		4. Trophies
		5. Weapons (by rarity: Green > Gold > Purple > Blue > White)
		6. Armor (by rarity)
		7. Other items
#ce =============================================================================================================================

#RequireAdmin

#Region Includes
; #INCLUDES# ====================================================================================================================
#include "..\..\API\_GwAu3.au3"
#include "Files\GUI.au3"
#include "Files\SafetyValidator.au3"
#include "Files\ItemClassifier.au3"
#include "Files\SortEngine.au3"
; ===============================================================================================================================
#EndRegion Includes

; ===============================================================================
; Categories - Item categories and their sorting order
; ===============================================================================

; Category constants (sorted in desired order)
Global Enum $CAT_MATERIAL = 0, _
	$CAT_CONSUMABLE, _
	$CAT_TOME, _
	$CAT_TROPHY, _
	$CAT_WEAPON, _
	$CAT_ARMOR, _
	$CAT_OTHER, _
	$CAT_UNKNOWN

; Category names for display
Global $g_aCategoryNames[] = [ _
	"Materials", _
	"Consumables", _
	"Tomes", _
	"Trophies", _
	"Weapons", _
	"Armor", _
	"Other", _
	"Unknown" _
]

Func GetCategoryPriority($iCategory)
	Return $iCategory
EndFunc

Func GetCategoryName($iCategory)
	If $iCategory >= 0 And $iCategory < UBound($g_aCategoryNames) Then
		Return $g_aCategoryNames[$iCategory]
	EndIf
	Return "Unknown"
EndFunc

Func GetCategoryCount()
	Return UBound($g_aCategoryNames)
EndFunc

; ===============================================================================
; Main entry point
; ===============================================================================

; Create and show GUI
CreateGUI()

; Run main event loop
RunGUI()

; Exit
Exit
