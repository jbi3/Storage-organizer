#include-once
#include <GUIConstantsEx.au3>
#include <ComboConstants.au3>
#include <EditConstants.au3>
#include <ProgressConstants.au3>
#include <StaticConstants.au3>
#include <WindowsConstants.au3>

; ===============================================================================
; GUI Module
; Handles all GUI creation and event management
; ===============================================================================

; GUI Controls
Global $g_hGUI = 0
Global $g_cmbCharacter = 0
Global $g_cmbPlacement = 0
Global $g_chkStorage = 0
Global $g_chkInventory = 0
Global $g_chkDepositMaterials = 0
Global $g_lblStatus = 0
Global $g_prgProgress = 0
Global $g_lblProgress = 0
Global $g_btnStart = 0
Global $g_btnRead = 0
Global $g_edtLog = 0

Global $g_bSortRunning = False

; Script info
Global Const $SCRIPT_NAME = "Storage Organizer"
Global Const $SCRIPT_VERSION = "1.0.0"
Global Const $SCRIPT_AUTHOR = "GwAu3 Community"
Global Const $SCRIPT_YEAR = "2026"

; Placement of the sorted items in the Xunlai storage
Global Const $PLACEMENT_FREE_AT_END = "Free slots at the end (items from the first slot)"
Global Const $PLACEMENT_FREE_AT_START = "Free slots at the start (items up to the last slot)"

; ===============================================================================
; Create and display the main GUI
; ===============================================================================
Func CreateGUI()
	; Main window
	$g_hGUI = GUICreate($SCRIPT_NAME, 480, 495, -1, -1, BitOR($WS_OVERLAPPED, $WS_CAPTION, $WS_SYSMENU, $WS_MINIMIZEBOX))
	
	; Character section
	GUICtrlCreateGroup("Character", 20, 10, 445, 50)
	$g_cmbCharacter = GUICtrlCreateCombo("", 30, 28, 295, 25, $CBS_DROPDOWNLIST)
	GUICtrlSetData($g_cmbCharacter, Scanner_GetLoggedCharNames())
	$g_btnRead = GUICtrlCreateButton("Read", 335, 26, 55, 28)
	$g_btnStart = GUICtrlCreateButton("Start", 400, 26, 55, 28)
	GUICtrlCreateGroup("", -99, -99, 1, 1)
	
	; Zones section - what to sort
	GUICtrlCreateGroup("Zones", 20, 70, 445, 50)
	$g_chkStorage = GUICtrlCreateCheckbox("Xunlai storage", 30, 90, 120, 20)
	GUICtrlSetState($g_chkStorage, $GUI_CHECKED)
	$g_chkInventory = GUICtrlCreateCheckbox("Inventory (backpack, belt pouch, bags 1-2)", 160, 90, 295, 20)
	GUICtrlCreateGroup("", -99, -99, 1, 1)
	
	; Placement section - where the free slots go after sorting
	GUICtrlCreateGroup("Placement", 20, 125, 445, 72)
	$g_cmbPlacement = GUICtrlCreateCombo("", 30, 143, 425, 25, $CBS_DROPDOWNLIST)
	GUICtrlSetData($g_cmbPlacement, $PLACEMENT_FREE_AT_END & "|" & $PLACEMENT_FREE_AT_START, $PLACEMENT_FREE_AT_END)
	$g_chkDepositMaterials = GUICtrlCreateCheckbox("Deposit common and rare materials to the material storage", 30, 171, 425, 20)
	GUICtrlCreateGroup("", -99, -99, 1, 1)
	
	; Status section - status text, progress bar, and percentage
	GUICtrlCreateGroup("Status", 20, 205, 445, 45)
	$g_lblStatus = GUICtrlCreateLabel("Ready to sort", 30, 225, 165, 20)
	$g_prgProgress = GUICtrlCreateProgress(205, 226, 150, 16)
	$g_lblProgress = GUICtrlCreateLabel("0% (0/0)", 358, 225, 97, 20, $SS_RIGHT)
	GUICtrlCreateGroup("", -99, -99, 1, 1)
	
	; Log section
	GUICtrlCreateGroup("Log", 20, 260, 445, 215)
	$g_edtLog = GUICtrlCreateEdit("", 30, 280, 425, 185, BitOR($ES_MULTILINE, $ES_READONLY, $ES_AUTOVSCROLL, $WS_VSCROLL))
	GUICtrlSetLimit($g_edtLog, 2000000) ; A full account dump exceeds the default edit limit
	GUICtrlCreateGroup("", -99, -99, 1, 1)
	
	; Show GUI
	GUISetState(@SW_SHOW, $g_hGUI)
	
	LogInfo("=== " & $SCRIPT_NAME & " v" & $SCRIPT_VERSION & " ===")
	
	Return $g_hGUI
EndFunc

; ===============================================================================
; Main GUI event loop
; ===============================================================================
Func RunGUI()
	While True
		; Advanced mode: the account view is a second window with its own close button
		Local $aMsg = GUIGetMsg(1)

		Switch $aMsg[0]
			Case $GUI_EVENT_CLOSE
				If $aMsg[1] = $g_hViewGUI Then
					CloseAccountView()
				ElseIf $g_bSortRunning Then
					Local $iResponse = MsgBox(4 + 32, "Confirm Exit", "Sorting is in progress. Are you sure you want to exit?")
					If $iResponse = 6 Then ; Yes
						ExitLoop
					EndIf
				Else
					ExitLoop
				EndIf
				
			Case $g_btnStart
				OnStartClick()

			Case $g_btnRead
				OnReadClick()
		EndSwitch
		
		Sleep(10)
	WEnd
	
	GUIDelete($g_hGUI)
EndFunc

; ===============================================================================
; Event: Start button clicked
; ===============================================================================
Func OnStartClick()
	If GUICtrlRead($g_chkStorage) <> $GUI_CHECKED And GUICtrlRead($g_chkInventory) <> $GUI_CHECKED Then
		MsgBox(16, "Error", "Please check at least one zone to sort!")
		Return
	EndIf

	If Not ConnectToSelectedChar() Then Return

	UpdateStatus("Starting sort...")
	
	; Disable controls
	GUICtrlSetState($g_btnStart, $GUI_DISABLE)
	GUICtrlSetState($g_cmbCharacter, $GUI_DISABLE)
	GUICtrlSetState($g_cmbPlacement, $GUI_DISABLE)
	GUICtrlSetState($g_chkStorage, $GUI_DISABLE)
	GUICtrlSetState($g_chkInventory, $GUI_DISABLE)
	GUICtrlSetState($g_chkDepositMaterials, $GUI_DISABLE)
	
	$g_bSortRunning = True
	
	; Start sort in background using AdlibRegister
	AdlibRegister("DoSortStep", 100)
EndFunc

; ===============================================================================
; Connect GwAu3 to the selected character; shared by Start and Read
; ===============================================================================
Func ConnectToSelectedChar()
	Local $sSelectedChar = GUICtrlRead($g_cmbCharacter)

	If $sSelectedChar = "" Then
		MsgBox(16, "Error", "Please select a character first!")
		Return False
	EndIf

	LogInfo("Connecting to: " & $sSelectedChar)
	UpdateStatus("Connecting to " & $sSelectedChar & "...")

	; Initialize GwAu3 for selected character
	Local $hWnd = Core_Initialize($sSelectedChar)

	If $hWnd = 0 Then
		LogError("Failed to connect to " & $sSelectedChar)
		UpdateStatus("Connection failed")
		MsgBox(16, "Error", "Failed to connect to Guild Wars client for " & $sSelectedChar)
		Return False
	EndIf

	LogInfo("Connected successfully!")
	Return True
EndFunc

; ===============================================================================
; Event: Read button clicked - read-only dump of storage, materials and bags
; ===============================================================================
Func OnReadClick()
	; A failed read must not leave the previous view on screen as if it were current
	CloseAccountView()
	If Not ConnectToSelectedChar() Then Return

	GUICtrlSetState($g_btnRead, $GUI_DISABLE)
	GUICtrlSetState($g_btnStart, $GUI_DISABLE)
	UpdateStatus("Reading account content...")

	Local $aContent = ReadAccountContent()
	If @error Then
		LogWarning("No bag readable: " & UBound($aContent) & " items read in " & $g_iReadDurationMs & " ms")
		UpdateStatus("Nothing readable - see log")
		MsgBox(48, "Nothing readable", "No bag could be read for this character." & @CRLF & _
			"Wait until the character is fully loaded in game, then click Read again.")
	Else
		DumpAccountContent($aContent)
		ShowAccountView($aContent, $g_aReadBagSlots, $g_hGUI)
		UpdateStatus("Read complete")
	EndIf

	GUICtrlSetState($g_btnRead, $GUI_ENABLE)
	GUICtrlSetState($g_btnStart, $GUI_ENABLE)
EndFunc

; ===============================================================================
; Background sort execution (called by AdlibRegister)
; ===============================================================================
Func DoSortStep()
	AdlibUnRegister("DoSortStep")
	
	; Execute the sort
	Local $bSuccess = SortZones(GUICtrlRead($g_chkStorage) = $GUI_CHECKED, GUICtrlRead($g_chkInventory) = $GUI_CHECKED, _
		GUICtrlRead($g_cmbPlacement) = $PLACEMENT_FREE_AT_START, GUICtrlRead($g_chkDepositMaterials) = $GUI_CHECKED)

	If $bSuccess Then
		UpdateStatus("Sorting complete!")
		LogInfo("✓ Items organized successfully!")
	Else
		UpdateStatus("Sort failed - see log for details")
		LogError("Sort operation failed")
	EndIf
	
	FinishSort()
EndFunc

; ===============================================================================
; Clean up after sort finishes
; ===============================================================================
Func FinishSort()
	$g_bSortRunning = False
	
	; Re-enable controls
	GUICtrlSetState($g_btnStart, $GUI_ENABLE)
	GUICtrlSetState($g_cmbCharacter, $GUI_ENABLE)
	GUICtrlSetState($g_cmbPlacement, $GUI_ENABLE)
	GUICtrlSetState($g_chkStorage, $GUI_ENABLE)
	GUICtrlSetState($g_chkInventory, $GUI_ENABLE)
	GUICtrlSetState($g_chkDepositMaterials, $GUI_ENABLE)
EndFunc

; ===============================================================================
; Update status label
; ===============================================================================
Func UpdateStatus($sStatus)
	GUICtrlSetData($g_lblStatus, $sStatus)
EndFunc

; ===============================================================================
; Update progress bar and label
; ===============================================================================
Func UpdateProgress($iCurrent, $iTotal)
	If $iTotal = 0 Then
		GUICtrlSetData($g_prgProgress, 0)
		GUICtrlSetData($g_lblProgress, "0% (0/0)")
	Else
		Local $iPercent = Round(($iCurrent / $iTotal) * 100)
		GUICtrlSetData($g_prgProgress, $iPercent)
		GUICtrlSetData($g_lblProgress, $iPercent & "% (" & $iCurrent & "/" & $iTotal & ")")
	EndIf
EndFunc

; ===============================================================================
; Logging Functions
; ===============================================================================
Func LogInfo($sMessage)
	_LogMessage($sMessage)
EndFunc

Func LogWarning($sMessage)
	_LogMessage("⚠ " & $sMessage)
EndFunc

Func LogError($sMessage)
	_LogMessage("❌ " & $sMessage)
EndFunc

Func LogDebug($sMessage)
	_LogMessage($sMessage)
EndFunc

Func _LogMessage($sMessage)
	Local $sTimestamp = "[" & StringFormat("%02d:%02d:%02d", @HOUR, @MIN, @SEC) & "]"
	Local $sLogLine = $sTimestamp & " " & $sMessage
	
	; Output to console
	ConsoleWrite($sLogLine & @CRLF)
	
	; Output to GUI log control
	If $g_edtLog <> 0 Then
		Local $sCurrentText = GUICtrlRead($g_edtLog)
		GUICtrlSetData($g_edtLog, $sCurrentText & $sLogLine & @CRLF)
		_GUICtrlEdit_Scroll($g_edtLog, $SB_SCROLLCARET)
	EndIf
EndFunc

