// DraftScene -- state and presentation for the DraftStudio form.
//
// cs.DraftEmail.Composer is the component; this class only keeps the studio's
// state and turns component envelopes into form text. It never sends mail and
// never sets `interactive` except in compose(), which the form calls from a
// button click. `validate`, `capabilities` and `cleanup` open no mail UI.
//
// Every method that inspects the request takes a $fields Object (the form, or a
// plain object with the same keys) so the whole flow also runs headlessly.

property composer : Object
property versionText : Text
property caps : Object
property lastResult : Object
property job : Object
property jobId : Text
property jobState : Text
property polls : Integer
property startedAt : Integer
property elapsedMs : Integer
property attachments : Collection
property selectedIndex : Integer
property stagingToken : Text
property stagingPaths : Collection
property timeline : Collection
property toast : Text

Class constructor()
	This.composer:=cs.DraftEmail.Composer.new(This.target())
	This.versionText:=""
	This.caps:=Null
	This.lastResult:=Null
	This.job:=Null
	This.jobId:=""
	This.jobState:="idle"
	This.polls:=0
	This.startedAt:=0
	This.elapsedMs:=0
	This.attachments:=New collection
	This.selectedIndex:=-1
	This.stagingToken:=""
	This.stagingPaths:=New collection
	This.timeline:=New collection
	This.toast:=""
	This.probe()

// Explicit native target, as the component requires on Windows.
Function target()->$target : Text
	$target:="macOS-universal"
	If (Is Windows)
		$target:="Windows-x64"
	End if
	return $target

Function client()->$client : Text
	$client:="apple-mail"
	If (Is Windows)
		$client:="simple-mapi"
	End if
	return $client

// Initial binding: starter values plus the first capability probe.
Function bind($form : Object)->$result : Object
	$form.inTo:="dana@example.com"
	$form.inCc:=""
	$form.inBcc:=""
	$form.inSubject:="Invoice 2026-114 — please review"
	$form.inBody:="Hello Dana,"+Char(13)+Char(10)+"The invoice for November is attached. I have not sent anything: this is a draft you can edit and send yourself."+Char(13)+Char(10)+Char(13)+Char(10)+"Thank you."
	$form.attachmentRows:=New collection
	$form.selectedAttachment:=Null
	$form.envelopeText:="{ }"
	$form.timelineText:=""
	$form.verdictText:=""
	$form.toast:=""
	This.refresh($form)
	$result:=$form

// Prefill from a Contract Lab scenario. Unreadable attachment paths are
// reported in the timeline, not silently turned into request entries.
Function seed($form : Object; $request : Object)->$bound : Object
	var $path : Text
	If (Value type($request)#Is object)
		$bound:=$form
		return $bound
	End if
	If (Value type($request.to)=Is collection)
		$form.inTo:=$request.to.join(", ")
	End if
	If (Value type($request.cc)=Is collection)
		$form.inCc:=$request.cc.join(", ")
	End if
	If (Value type($request.bcc)=Is collection)
		$form.inBcc:=$request.bcc.join(", ")
	End if
	If (Value type($request.subject)=Is text)
		$form.inSubject:=$request.subject
	End if
	If (Value type($request.body)=Is text)
		$form.inBody:=$request.body
	End if
	This.attachments:=New collection
	If (Value type($request.attachments)=Is collection)
		For each ($path; $request.attachments)
			If (Value type($path)=Is text)
				This.addAttachment(String($path))
			End if
		End for each
	End if
	$form.attachmentRows:=This.attachments
	This._log("seeded ← Contract Lab request")
	$bound:=$form
	return $bound

// Read-only capability probe. It is a support contract, not a permission.
Function probe()
	var $version : Object
	$version:=This.composer.version()
	If ($version.ok)
		This.versionText:=$version.value.version
	Else
		This.versionText:="unavailable"
	End if
	This.caps:=This.composer.capabilities()
	If (This.caps.ok)
		This._log("capabilities ← "+String(This.caps.value.backend)+" / "+String(This.caps.value.client))
	Else
		This._log("capabilities failed ← "+This._code(This.caps))
	End if

Function validate($fields : Object)->$result : Object
	var $request : Object
	$request:=This.buildRequest($fields; False)
	$result:=This.composer.validate($request)
	This.lastResult:=$result
	This._log("validate ← "+This._describe($result))
	This.toast:="Validation never opens Mail"
	This.refresh($fields)

// Dispatch only. The worker keeps the mail dialog off this form's process and
// the returned job handle is polled from On Timer.
Function compose($fields : Object)->$result : Object
	var $request : Object
	$request:=This.buildRequest($fields; True)
	$result:=This.composer.compose($request)
	If ($result.ok)
		This.job:=$result.job
		This.jobId:=$result.jobId
		This.jobState:="pending"
		This.polls:=0
		This.startedAt:=Milliseconds
		This._log("compose dispatched → job "+$result.jobId)
		SET TIMER(100)
	Else
		This.lastResult:=$result
		This.jobState:="rejected"
		This._log("compose rejected ← "+This._code($result))
	End if
	This.toast:="Handed off, not sent"
	This.refresh($fields)

Function poll($fields : Object)->$result : Object
	If (This.job=Null)
		SET TIMER(0)
		return This._invalid("no job")
	End if
	This.polls:=This.polls+1
	This.elapsedMs:=Milliseconds-This.startedAt
	$result:=This.composer.poll(This.job)
	If ($result.ok)
		This.jobState:=$result.state
		If ($result.finished)
			This.lastResult:=$result.result
			This.job:=Null
			This.jobId:=String($result.jobId)
			SET TIMER(0)
			This._absorbStaging($result.result)
			This._log("job finished ← "+This._describe($result.result))
		End if
	Else
		This.lastResult:=$result
		This.jobState:="poll failed"
		This.job:=Null
		SET TIMER(0)
		This._log("poll failed ← "+This._code($result))
	End if
	This.refresh($fields)

// Explicit deletion of the helper-owned staging batch. Deliberately not
// automatic: a copy may still be needed by an open compose window.
Function cleanup($fields : Object)->$result : Object
	If (This.stagingToken="")
		This.toast:="No staging batch to clean"
		This.refresh($fields)
		return This._invalid("no staging token")
	End if
	var $token : Text
	$token:=This.stagingToken
	$result:=This.composer.cleanup($token)
	If ($result.ok)
		This._log("cleanup ← removed batch "+Substring($token; 1; 8)+"…")
		This.stagingToken:=""
		This.stagingPaths:=New collection
		This.toast:="Private attachment copies deleted"
	Else
		This._log("cleanup failed ← "+This._code($result))
		This.toast:="Cleanup refused: "+This._code($result)
	End if
	This.refresh($fields)

// $platform is True for a system path (Select document's DOCUMENT variable),
// False for the POSIX paths found in a request document.
Function addAttachment($path : Text; $platform : Boolean)->$file : Object
	If ($path="")
		return Null
	End if
	var $candidate : 4D.File
	var $row : Object
	If ($platform)
		$candidate:=File($path; fk platform path)
	Else
		$candidate:=File($path)
	End if
	If (Not($candidate.exists))
		This.toast:="Not a readable file: "+$path
		return Null
	End if
	$row:=New object
	$row.path:=$candidate.platformPath
	$row.name:=$candidate.name
	$row.bytes:=$candidate.size
	$row.sizeLabel:=This._sizeLabel($candidate.size)
	This.attachments.push($row)
	This._log("attach ← "+$row.name+" ("+$row.sizeLabel+")")
	This.toast:="The original stays where it is"
	$file:=$row

Function removeAttachment()->$removed : Object
	If ((This.selectedIndex<0) | (This.selectedIndex>=This.attachments.length))
		This.toast:="Select an attachment row first"
		return Null
	End if
	$removed:=This.attachments[This.selectedIndex]
	This.attachments.remove(This.selectedIndex)
	This.selectedIndex:=-1
	$removed:=$removed

Function selectAttachment($row : Object)->$index : Integer
	var $i : Integer
	$index:=-1
	If ($row=Null)
		This.selectedIndex:=-1
		return -1
	End if
	For ($i; 1; This.attachments.length)
		If (This.attachments[$i-1].path=$row.path)
			This.selectedIndex:=$i-1
			$index:=This.selectedIndex
		End if
	End for

// The request snapshot. `interactive` is a deliberate argument, never a default:
// only compose() passes True, and only the form's button click reaches it.
Function buildRequest($fields : Object; $interactive : Boolean)->$request : Object
	var $row : Object
	$request:=New object
	$request.protocol:=1
	$request.client:=This.client()
	$request.to:=This._splitList(String($fields.inTo))
	$request.cc:=This._splitList(String($fields.inCc))
	$request.bcc:=This._splitList(String($fields.inBcc))
	$request.subject:=String($fields.inSubject)
	$request.body:=String($fields.inBody)
	$request.attachments:=New collection
	For each ($row; This.attachments)
		$request.attachments.push($row.path)
	End for each
	If ($interactive)
		$request.interactive:=True
	End if
	return $request

Function refresh($form : Object)
	var $value : Object
	$form.badgeText:=This.badgeText()
	$form.capNote:=""
	$form.jobStateText:=This.jobState
	$form.jobDetailText:=This.jobDetailText()
	$form.stagingText:=This.stagingText()
	$form.envelopeText:=This.envelopeText()
	$form.timelineText:=This.timelineText()
	$form.toast:=This.toast
	$form.attachmentRows:=This.attachments
	$form.attachCount:=(This.attachments.length=1) ? "1 file" : String(This.attachments.length)+" files"
	If (This.caps#Null)
		If (This.caps.ok)
			$value:=This.caps.value
			$form.capNote:=This._capNote($value)
			This._paintChips($form; $value.fields)
		End if
	End if

// Chips are painted from the real capability object: the same form shows
// "cc ✗" on macOS and "cc ✓" on Windows with no platform branch in the UI.
Function _paintChips($form : Object; $fields : Object)
	This._paintChip("capTo"; "to"; $fields.to)
	This._paintChip("capCc"; "cc"; $fields.cc)
	This._paintChip("capBcc"; "bcc"; $fields.bcc)
	This._paintChip("capSubject"; "subject"; $fields.subject)
	This._paintChip("capBody"; "body"; $fields.body)
	This._paintChip("capAttach"; "attachments"; $fields.attachments)

Function _paintChip($name : Text; $label : Text; $on : Boolean)
	If (Current form name="")
		// No form is displayed (headless smoke): there is nothing to paint.
		return
	End if
	If ($on)
		OBJECT SET TITLE(*; $name; $label+"  ✓")
	Else
		OBJECT SET TITLE(*; $name; $label+"  ✗")
	End if

Function badgeText()->$text : Text
	var $backend : Text
	$backend:="?"
	If (This.caps#Null)
		If (This.caps.ok)
			$backend:=String(This.caps.value.backend)
		End if
	End if
	$text:=$backend+" · cli "+This.versionText+" · "+This.target()

Function jobDetailText()->$text : Text
	If (This.jobId="")
		$text:="No job: validate never starts one"
		return $text
	End if
	$text:="job "+Substring(This.jobId; 1; 8)+"… · "+String(This.polls)+" polls · "+String(This.elapsedMs)+" ms in the form's worker"
	return $text

Function stagingText()->$text : Text
	If (This.stagingToken="")
		$text:="no batch — a compose with attachments returns a token here"
		return $text
	End if
	$text:="token "+This.stagingToken+" · "+String(This.stagingPaths.length)+" private cop"+((This.stagingPaths.length=1) ? "y" : "ies")+" · retained until you clean up"
	return $text

Function envelopeText()->$text : Text
	If (This.lastResult=Null)
		$text:="{ }"
		return $text
	End if
	$text:=JSON Stringify(This.lastResult; *)
	return $text

Function timelineText()->$text : Text
	var $i : Integer
	var $lines : Collection
	$lines:=New collection
	If (This.timeline.length=0)
		$text:="(no calls yet)"
		return $text
	End if
	$i:=This.timeline.length-8
	If ($i<1)
		$i:=1
	End if
	For ($i; $i; This.timeline.length)
		$lines.push(This.timeline[$i-1])
	End for
	$text:=$lines.join(Char(13))
	return $text

Function _capNote($value : Object)->$note : Text
	$note:="✓ supported · ✗ refused · interactiveRequired:"+String($value.interactiveRequired)+" · timeoutSeconds:"+String($value.timeoutSeconds)+" · deliveryConfirmed:"+String($value.deliveryConfirmed)+" · stagingCleanup:"+String($value.stagingCleanup)
	return $note

Function _absorbStaging($result : Object)
	If (Value type($result)#Is object)
		return
	End if
	If (Value type($result.staging)#Is object)
		If (Value type($result.staging.token)=Is text)
			This.stagingToken:=$result.staging.token
		End if
		If (Value type($result.staging.paths)#Is collection)
			This.stagingPaths:=$result.staging.paths
		End if
	End if

// "handed_off" is a handoff, not a delivery: the person still decides.
Function _describe($result : Object)->$text : Text
	If (Value type($result)#Is object)
		$text:="no envelope"
		return $text
	End if
	If ($result.ok)
		If (Value type($result.value.status)=Is text)
			$text:=String($result.value.status)+" (handoff only, never delivery)"
		Else
			$text:="ok"
		End if
		return $text
	End if
	$text:=This._code($result)
	return $text

// Which layer refused: component pre-check, the native CLI, or prelaunch.
Function _code($result : Object)->$code : Text
	$code:="unknown"
	If (Value type($result)#Is object)
		return $code
	End if
	If ($result.ok)
		$code:="ok"
		return $code
	End if
	If (Value type($result.error.code)=Is text)
		$code:=$result.error.code
	End if
	return $code

Function _invalid($message : Text)->$result : Object
	$result:=New object("ok"; False; "error"; New object("code"; "invalid_argument"; "message"; $message))
	return $result

Function _splitList($text : Text)->$list : Collection
	var $part; $value : Text
	$list:=New collection
	$text:=Replace string($text; ";"; ",")
	For each ($part; Split string($text; ","))
		$value:=Trim($part)
		If ($value#"")
			$list.push($value)
		End if
	End for each
	return $list

Function _sizeLabel($bytes : Integer)->$label : Text
	If ($bytes<1024)
		$label:=String($bytes)+" B"
	Else
		$label:=String($bytes/1024; "###0.0")+" KB"
	End if
	return $label

Function _log($line : Text)
	This.timeline.push(String(Current time; "HH:MM:SS")+"  "+$line)
	While (This.timeline.length>40)
		This.timeline.remove(0)
	End while
