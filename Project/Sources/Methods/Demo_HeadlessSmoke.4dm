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
var $seedScenario : Object
var $seeded : Object
var $seedOk : Boolean
var $attachRow : Object
var $attachFields : Object
var $attachValidate : Object
var $attachOk : Boolean
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
$lab:=cs.DraftLab.new()

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

// The Contract Lab's "To Studio" path: a catalogue request must land in the
// studio's fields. This checks the prefill itself; the form-method wiring that
// delivers Form.seed cannot run without a window.
$seeded:=New object
$seedOk:=False
For each ($seedScenario; $lab.scenarios)
	If ($seedScenario.id="minimal")
		$scene.seed($seeded; $seedScenario.request)
		$seedOk:=(($seeded.inTo=$seedScenario.request.to[0]) & ($seeded.inSubject=$seedScenario.request.subject))
	End if
End for each
$report.studio.seed:=New object("to"; $seeded.inTo; "subject"; $seeded.inSubject; "bodyLength"; Length($seeded.inBody); "matches"; $seedOk)

// The attachment picker hands a system (platform) path; the request must carry
// an absolute POSIX path, and the component must accept it. Structure file is
// a plain system path to a regular, non-symlink file.
$attachFields:=New object
$scene.bind($attachFields)
$attachRow:=$scene.addAttachment(Structure file; True)
$attachValidate:=$scene.validate($attachFields)
$attachOk:=(($attachRow#Null) && (Position("/"; String($attachRow.path))=1) && ($scene.attachments.length=1) && (Bool($attachValidate.ok)))
$report.studio.attachment:=New object("path"; ($attachRow#Null) ? $attachRow.path : ""; "rows"; $scene.attachments.length; "validated"; Bool($attachValidate.ok); "matches"; $attachOk)

// Lab path: every scenario, compared against its declared expectation.
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
$report.passed:=($report.studio.validate.ok & $seedOk & $attachOk & ($failures=0))

$file:=File($config.out)
$file.parent.create()
$file.setText(JSON Stringify($report; *))
QUIT 4D
