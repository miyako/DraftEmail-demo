// Opens the Draft Studio window. Called by On Startup and by the Demo menu with
// no parameter, and by the Contract Lab with a seed request so the lab's chosen
// scenario lands in the editor. The form runs in this process, so a menu click
// during the studio's modal loop can open the lab as a nested dialog.
#DECLARE($params : Object)

var $title : Text
var $window : Integer

$title:="DraftEmail — Draft Studio"
SET MENU BAR(1)
$window:=Open form window("DraftStudio"; Plain form window; Horizontally centered; Vertically centered)
SET WINDOW TITLE($title; $window)
If (Count parameters=0)
	DIALOG("DraftStudio"; New object; *)
Else
	DIALOG("DraftStudio"; $params; *)
End if
