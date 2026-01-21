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
Global $g_lblStatus = 0
Global $g_prgProgress = 0
Global $g_lblProgress = 0
Global $g_btnStart = 0
Global $g_edtLog = 0

Global $g_bSortRunning = False

; Script info
Global Const $SCRIPT_NAME = "Storage Organizer"
Global Const $SCRIPT_VERSION = "1.0.0"
Global Const $SCRIPT_AUTHOR = "GwAu3 Community"
Global Const $SCRIPT_YEAR = "2026"

; ===============================================================================
; Create and display the main GUI
; ===============================================================================
Func CreateGUI()
	; Main window
	$g_hGUI = GUICreate($SCRIPT_NAME, 480, 360, -1, -1, BitOR($WS_OVERLAPPED, $WS_CAPTION, $WS_SYSMENU, $WS_MINIMIZEBOX))
	
	; Character section
	GUICtrlCreateGroup("Character", 20, 10, 445, 50)
	$g_cmbCharacter = GUICtrlCreateCombo("", 30, 28, 360, 25, $CBS_DROPDOWNLIST)
	GUICtrlSetData($g_cmbCharacter, Scanner_GetLoggedCharNames())
	$g_btnStart = GUICtrlCreateButton("Start", 400, 26, 55, 28)
	GUICtrlCreateGroup("", -99, -99, 1, 1)
	
	; Status section - status text, progress bar, and percentage
	GUICtrlCreateGroup("Status", 20, 70, 445, 45)
	$g_lblStatus = GUICtrlCreateLabel("Ready to sort", 30, 90, 165, 20)
	$g_prgProgress = GUICtrlCreateProgress(205, 91, 150, 16)
	$g_lblProgress = GUICtrlCreateLabel("0% (0/0)", 358, 90, 97, 20, $SS_RIGHT)
	GUICtrlCreateGroup("", -99, -99, 1, 1)
	
	; Log section
	GUICtrlCreateGroup("Log", 20, 125, 445, 215)
	$g_edtLog = GUICtrlCreateEdit("", 30, 145, 425, 185, BitOR($ES_MULTILINE, $ES_READONLY, $ES_AUTOVSCROLL, $WS_VSCROLL))
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
		Local $iMsg = GUIGetMsg()
		
		Switch $iMsg
			Case $GUI_EVENT_CLOSE
				If $g_bSortRunning Then
					Local $iResponse = MsgBox(4 + 32, "Confirm Exit", "Sorting is in progress. Are you sure you want to exit?")
					If $iResponse = 6 Then ; Yes
						ExitLoop
					EndIf
				Else
					ExitLoop
				EndIf
				
			Case $g_btnStart
				OnStartClick()
		EndSwitch
		
		Sleep(10)
	WEnd
	
	GUIDelete($g_hGUI)
EndFunc

; ===============================================================================
; Event: Start button clicked
; ===============================================================================
Func OnStartClick()
	Local $sSelectedChar = GUICtrlRead($g_cmbCharacter)
	
	If $sSelectedChar = "" Then
		MsgBox(16, "Error", "Please select a character first!")
		Return
	EndIf
	
	LogInfo("Connecting to: " & $sSelectedChar)
	UpdateStatus("Connecting to " & $sSelectedChar & "...")
	
	; Initialize GwAu3 for selected character
	Local $hWnd = Core_Initialize($sSelectedChar)
	
	If $hWnd = 0 Then
		LogError("Failed to connect to " & $sSelectedChar)
		UpdateStatus("Connection failed")
		MsgBox(16, "Error", "Failed to connect to Guild Wars client for " & $sSelectedChar)
		Return
	EndIf
	
	LogInfo("Connected successfully!")
	UpdateStatus("Starting sort...")
	
	; Disable controls
	GUICtrlSetState($g_btnStart, $GUI_DISABLE)
	GUICtrlSetState($g_cmbCharacter, $GUI_DISABLE)
	
	$g_bSortRunning = True
	
	; Start sort in background using AdlibRegister
	AdlibRegister("DoSortStep", 100)
EndFunc

; ===============================================================================
; Background sort execution (called by AdlibRegister)
; ===============================================================================
Func DoSortStep()
	AdlibUnRegister("DoSortStep")
	
	; Execute the sort
	Local $bSuccess = SortXunlaiStorage()
	
	If $bSuccess Then
		UpdateStatus("Sorting complete!")
		LogInfo("✓ Storage organized successfully!")
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

