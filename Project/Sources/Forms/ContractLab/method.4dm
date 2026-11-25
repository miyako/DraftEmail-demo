// ContractLab -- form method.
//
// Routes clicks to cs.DraftLab. Every scenario is a real call into the
// component; none of them composes mail. A form method takes no parameters.

var $lab : Object
var $clicked : Text
var $scenario : Object
var $result : Object
var $results : Collection
var $row : Object

Case of
	: (FORM Event.code=On Load)
		$lab:=cs.DraftLab.new()
		Form.lab:=$lab
		Form.scenarioRows:=$lab.scenarios
		Form.resultRows:=New collection
		Form.selectedScenario:=Null
		Form.selectedResult:=Null
		Form.requestText:="{ }"
		Form.expectText:="Pick a scenario on the left. The request JSON and the expected refusal appear here before anything runs."
		Form.actualText:="{ }"
		Form.verdictText:="—"
		Form.verdictDetail:="Nothing has run yet."
		Form.labLogText:=$lab.logText()
		Form.badgeText:=String($lab.scenarios.length)+" scenarios · validate only"

	: (FORM Event.code=On Clicked)
		$lab:=Form.lab
		$clicked:=FORM Event.objectName
		Case of
			: ($clicked="scenarioList")
				$scenario:=Form.selectedScenario
				If ($scenario#Null)
					Form.requestText:=JSON Stringify($scenario.request; *)
					Form.expectText:=$lab.expectText($scenario)
				End if

			: ($clicked="btnRun")
				$scenario:=Form.selectedScenario
				If ($scenario=Null)
					Form.verdictDetail:="Select a scenario first."
				Else
					$result:=$lab.run($scenario)
					Form.resultRows.push($lab.row($result))
					Form.requestText:=JSON Stringify($scenario.request; *)
					Form.actualText:=JSON Stringify($result.envelope; *)
					Form.expectText:=$lab.expectText($scenario)
					Form.verdictText:=$result.actual+"  ·  "+$result.verdict
					Form.verdictDetail:=$scenario.note
					Form.labLogText:=$lab.logText()
				End if

			: ($clicked="btnRunAll")
				$results:=$lab.runAll()
				Form.resultRows:=New collection
				For each ($row; $results)
					Form.resultRows.push($lab.row($row))
				End for each
				Form.verdictText:=$lab.summary(Form.resultRows)
				Form.verdictDetail:="Every row is a real call into the component. Compose is never invoked, so no mail client opens."
				Form.labLogText:=$lab.logText()
				If ($results.length>0)
					Form.requestText:=JSON Stringify($results[0].request; *)
					Form.actualText:=JSON Stringify($results[0].envelope; *)
				End if

			: ($clicked="btnToStudio")
				$scenario:=Form.selectedScenario
				If ($scenario=Null)
					Form.verdictDetail:="Select a scenario first."
				Else
					If (Value type($scenario.request.protocol)=Is real)
						Demo_OpenStudio(New object("seed"; $scenario.request))
					Else
						Form.verdictDetail:="This scenario is a direct call, not a request document: there is nothing to edit in the studio."
					End if
				End if
		End case
End case
