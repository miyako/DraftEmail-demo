//%attributes = {"invisible":true}
// Demo_HeadlessSmoke -- headless acceptance for this demo.
//
// Drives the real classes against the real component without a form and writes
// one JSON report. It never calls compose, so no mail client opens.
//
//   tool4d --project Project/DraftEmail-demo.4DProject --dataless \
//     --skip-onstartup --startup-method Demo_HeadlessSmoke \
//     --user-param '{"out":"/tmp/DraftEmail-demo-smoke.json"}'
//
// The process exits 0; read "passed" in the report.
#DECLARE()

var $text : Text
var $config : Object
var $report : Object
var $scene : cs.DraftScene
var $lab : cs.DraftLab
var $fields : Object
var $results : Collection
var $row : Object
var $file : 4D.File
var $failures : Integer

$config:=New object("out"; "/tmp/DraftEmail-demo-smoke.json")
If (Get database parameter(User param value; $text)=0)
	var $parsed : Object
	$parsed:=JSON Parse($text)
	If (Value type($parsed)=Is object)
		If (Value type($parsed.out)=Is text)
			$config:=$parsed
		End if
	End if
End if

$report:=New object("compiled"; Is compiled mode)

// Studio path: defaults, one validate, one deliberate rejection.
$scene:=cs.DraftScene.new()
$fields:=New object
$scene.bind($fields)
$report.studio:=New object
$report.studio.validate:=$scene.validate($fields)
$fields.inCc:="ops@example.com"
$report.studio.ccRejected:=$scene.validate($fields)
$report.studio.request:=$scene.buildRequest($fields; False)
$report.studio.badge:=$fields.badgeText
$report.studio.capabilities:=$scene.caps

// Lab path: every scenario, compared against its declared expectation.
$lab:=cs.DraftLab.new()
$results:=$lab.runAll()
$report.scenarios:=New collection
$failures:=0
For each ($row; $results)
	$report.scenarios.push(New object("id"; $row.id; "layer"; $row.layer; "expect"; $row.expect; "actual"; $row.actual; "verdict"; $row.verdict))
	If ($row.verdict#"PASS")
		$failures:=$failures+1
	End if
End for each
$report.summary:=$lab.summary($results)
$report.failureCount:=$failures
$report.passed:=($report.studio.validate.ok & ($failures=0))

$file:=File($config.out)
$file.parent.create()
$file.setText(JSON Stringify($report; *))
QUIT 4D
