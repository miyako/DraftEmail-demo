// Opens the Contract Lab window in this process, like the studio.
#DECLARE($params : Object)

var $title : Text
var $window : Integer

$title:="DraftEmail — Contract Lab"
SET MENU BAR(1)
$window:=Open form window("ContractLab"; Plain form window; Horizontally centered; Vertically centered)
SET WINDOW TITLE($title; $window)
If (Count parameters=0)
	DIALOG("ContractLab"; New object; *)
Else
	DIALOG("ContractLab"; $params; *)
End if
