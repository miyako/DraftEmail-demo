// DraftStudio -- form method.
//
// The form method routes by object name; the behaviour lives in cs.DraftScene.
// On Timer exists only so a compose job dispatched to a worker can be polled
// without blocking this form's process.
#DECLARE($params : Object)

var $scene : Object
var $clicked : Text
var $path : Text

Case of
	: (FORM Event.code=On Load)
		$scene:=cs.DraftScene.new()
		Form.scene:=$scene
		$scene.bind(Form)
		If (Value type($params.seed)=Is object)
			$scene.seed(Form; $params.seed)
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
					$path:=Select document(""; "*"; "Choose a file to attach"; 0)
					If ($path#"")
						$scene.addAttachment($path)
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
