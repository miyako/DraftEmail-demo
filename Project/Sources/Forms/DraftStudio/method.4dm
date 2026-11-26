// DraftStudio -- form method.
//
// The form method routes by object name; the behaviour lives in cs.DraftScene.
// On Timer exists only so a compose job dispatched to a worker can be polled
// without blocking this form's process.
//
// A form method receives no parameters: the object given to DIALOG becomes
// Form, so a seed passed by Demo_OpenStudio arrives as Form.seed.

var $scene : Object
var $clicked : Text
var $name : Text

Case of
	: (FORM Event.code=On Load)
		$scene:=cs.DraftScene.new()
		Form.scene:=$scene
		$scene.bind(Form)
		If (Value type(Form.seed)=Is object)
			$scene.seed(Form; Form.seed)
			$scene.refresh(Form)
		End if

	: (FORM Event.code=On Timer)
		$scene:=Form.scene
		If ($scene#Null)
			$scene.poll(Form)
		Else
			SET TIMER(0)
		End if

	: (FORM Event.code=On Unload)
		SET TIMER(0)

	: (FORM Event.code=On Clicked)
		$scene:=Form.scene
		If ($scene#Null)
			$clicked:=FORM Event.objectName
			Case of
				: ($clicked="btnValidate")
					$scene.validate(Form)
				: ($clicked="btnCompose")
					$scene.compose(Form)
				: ($clicked="btnCleanup")
					$scene.cleanup(Form)
				: ($clicked="btnAdd")
					// A native picker: the demo never guesses an attachment path.
					// Select document returns the file NAME only; the full system
					// (not POSIX) path is in the DOCUMENT system variable.
					$name:=Select document(""; "*"; "Choose a file to attach"; 0)
					If ((OK=1) & ($name#""))
						$scene.addAttachment(DOCUMENT; True)
						$scene.refresh(Form)
					End if
				: ($clicked="btnRemove")
					$scene.removeAttachment()
					$scene.refresh(Form)
				: ($clicked="attachmentList")
					$scene.selectAttachment(Form.selectedAttachment)
			End case
		End if
End case
