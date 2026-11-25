// DraftLab -- the Contract Lab catalogue.
//
// Each entry is a request the component is expected to refuse, plus the layer
// that refuses it and the exact code that layer returns. Nothing here composes
// mail: the lab only calls validate, capabilities, version and a cleanup with a
// token that cannot exist.
//
// Layers, in call order:
//   component  cs.DraftEmail.Composer rejects before any process is launched
//   native     the bundled draft-email-cli exits with a JSON error envelope
//   prelaunch  the component refuses the target before launching the CLI

property scenarios : Collection
property log : Collection

Class constructor()
	This.scenarios:=This._catalogue()
	This.log:=New collection

Function run($scenario : Object)->$result : Object
	var $target : Text
	var $composer : cs.DraftEmail.Composer
	var $envelope : Object
	$target:=This.target()
	Case of
		: ($scenario.kind="target")
			$envelope:=cs.DraftEmail.Composer.new("Windows-x64").version()
		: ($scenario.kind="cleanup")
			$envelope:=cs.DraftEmail.Composer.new($target).cleanup("0123456789abcdef0123456789abcdef")
		Else
			$composer:=cs.DraftEmail.Composer.new($target)
			Case of
				: ($scenario.kind="capabilities")
					$envelope:=$composer.capabilities()
				: ($scenario.kind="version")
					$envelope:=$composer.version()
				Else
					$envelope:=$composer.validate($scenario.request)
			End case
	End case
	$result:=New object
	$result.id:=$scenario.id
	$result.name:=$scenario.name
	$result.expect:=$scenario.expect
	$result.layer:=$scenario.layer
	$result.note:=$scenario.note
	$result.request:=$scenario.request
	$result.envelope:=$envelope
	$result.actual:=This.code($envelope)
	If ($result.actual=$scenario.expect)
		$result.verdict:="PASS"
	Else
		$result.verdict:="FAIL"
	End if
	This._log($scenario.id+" → "+$result.actual+" ("+$result.verdict+")")
	return $result

Function runAll()->$results : Collection
	var $scenario : Object
	var $result : Object
	$results:=New collection
	For each ($scenario; This.scenarios)
		$result:=This.run($scenario)
		$results.push($result)
	End for each
	return $results

Function target()->$target : Text
	$target:="macOS-universal"
	If (Is Windows)
		$target:="Windows-x64"
	End if
	return $target

// The code the layer returned: the error code, or the success status.
Function code($result : Object)->$code : Text
	$code:="unknown"
	If (Value type($result)#Is object)
		return $code
	End if
	If ($result.ok)
		If (Value type($result.value.status)=Is text)
			$code:=String($result.value.status)
		Else
			$code:="ok"
		End if
		return $code
	End if
	If (Value type($result.error.code)=Is text)
		$code:=$result.error.code
	End if
	return $code

// One listbox row for a completed run.
Function row($result : Object)->$row : Object
	$row:=New object
	$row.name:=$result.name
	$row.expect:=$result.expect
	$row.actual:=$result.actual
	$row.verdict:=$result.verdict
	$row.layer:=$result.layer
	$row.note:=$result.note
	$row.envelope:=$result.envelope
	return $row

// The expectation prose shown beside the selected scenario.
Function expectText($scenario : Object)->$text : Text
	$text:="expect "+$scenario.expect+" from the "+$scenario.layer+" layer."
	$text:=$text+Char(13)+Char(10)+$scenario.note
	return $text

Function summary($rows : Collection)->$text : Text
	var $pass : Integer
	var $row : Object
	For each ($row; $rows)
		If ($row.verdict="PASS")
			$pass:=$pass+1
		End if
	End for each
	$text:=String($pass)+" of "+String($rows.length)+" expectations matched"
	return $text

Function logText()->$text : Text
	$text:="(nothing run yet)"
	If (This.log.length>0)
		$text:=This.log.join(Char(13))
	End if
	return $text

Function _log($line : Text)
	This.log.push($line)
	While (This.log.length>8)
		This.log.remove(0)
	End while

// ---------------------------------------------------------------- catalogue

Function _catalogue()->$rows : Collection
	var $to; $cc; $subject : Collection
	$rows:=New collection

	$rows.push(New object("id"; "minimal"; "name"; "Minimal valid draft"; "layer"; "native"; "expect"; "validated"; "kind"; "validate"; "note"; "The baseline every other scenario is compared against. Syntactic success; no mail client is involved."; "request"; This._request("dana@example.com"; ""; "Quarterly review"; "Plain text body.")))

	$rows.push(New object("id"; "cc-on-macos"; "name"; "Cc on macOS"; "layer"; "native"; "expect"; "unsupported_field"; "kind"; "validate"; "note"; "Apple Mail's sharing service exposes no cc or bcc. A non-empty list is rejected, never silently dropped."; "request"; This._request("dana@example.com"; "ops@example.com"; "Quarterly review"; "Plain text body.")))

	$rows.push(New object("id"; "display-name"; "name"; "Mailbox with a display name"; "layer"; "native"; "expect"; "invalid_request"; "kind"; "validate"; "note"; "\"Dana Reed <dana@example.com>\" is not a mailbox address. The component does not parse or repair it."; "request"; This._request("Dana Reed <dana@example.com>"; ""; "Quarterly review"; "Plain text body.")))

	$rows.push(New object("id"; "missing-attachment"; "name"; "Attachment that does not exist"; "layer"; "native"; "expect"; "invalid_attachment"; "kind"; "validate"; "note"; "Absolute path syntax is right; the CLI still refuses because nothing is readable there."; "request"; This._attachmentRequest("/nonexistent/invoice-2026-114.pdf")))

	$rows.push(New object("id"; "relative-attachment"; "name"; "Relative attachment path"; "layer"; "component"; "expect"; "invalid_argument"; "kind"; "validate"; "note"; "The component refuses a relative path before launching the CLI: the working directory is never guessed."; "request"; This._attachmentRequest("invoices/invoice-2026-114.pdf")))

	$rows.push(New object("id"; "too-many-recipients"; "name"; "101 recipients"; "layer"; "component"; "expect"; "invalid_argument"; "kind"; "validate"; "note"; "Protocol 1 carries at most 100 recipients per list. The refusal is a count, not a truncation."; "request"; This._manyRecipientRequest()))

	$rows.push(New object("id"; "nul-in-subject"; "name"; "NUL inside the subject"; "layer"; "component"; "expect"; "invalid_argument"; "kind"; "validate"; "note"; "An embedded NUL cannot survive a JSON round trip intact, so the component rejects it instead of truncating silently."; "request"; This._nulRequest()))

	$rows.push(New object("id"; "multibyte-subject"; "name"; "Subject over 998 bytes"; "layer"; "native"; "expect"; "limit_exceeded"; "kind"; "validate"; "note"; "400 Japanese characters: the component counts characters (400), the CLI counts UTF-8 bytes (1200). Limits are byte limits."; "request"; This._multibyteRequest()))

	$rows.push(New object("id"; "unknown-field"; "name"; "Unknown request field"; "layer"; "component"; "expect"; "invalid_argument"; "kind"; "validate"; "note"; "Protocol 1 is closed and the component owns that check, so an extra field such as attachmentsDir never reaches the CLI. The CLI's own unknown_field code is therefore unreachable from 4D."; "request"; This._unknownFieldRequest()))

	$rows.push(New object("id"; "protocol-2"; "name"; "Protocol 2"; "layer"; "component"; "expect"; "invalid_argument"; "kind"; "validate"; "note"; "The component speaks protocol 1 only and says so before any process starts."; "request"; This._protocolRequest()))

	$rows.push(New object("id"; "windows-target"; "name"; "Windows target on macOS"; "layer"; "prelaunch"; "expect"; "unsupported_architecture"; "kind"; "target"; "note"; "The name \"Windows-x64\" is valid; the binary for it is not present here. Refused before launch, so no process starts."; "request"; This._request("dana@example.com"; ""; "Quarterly review"; "Plain text body.")))

	$rows.push(New object("id"; "stale-token"; "name"; "Cleanup with a stale token"; "layer"; "native"; "expect"; "invalid_staging"; "kind"; "cleanup"; "note"; "Cleanup only accepts a token the helper actually issued. A well-formed 32-hex string is still refused."; "request"; New object("token"; "0123456789abcdef0123456789abcdef")))

	$rows.push(New object("id"; "capabilities"; "name"; "Capability report"; "layer"; "native"; "expect"; "ok"; "kind"; "capabilities"; "note"; "The field contract this lab is derived from: to/subject/body/attachments true, cc/bcc false, deliveryConfirmed false."; "request"; New object))

	return $rows

Function _request($to : Text; $cc : Text; $subject : Text; $body : Text)->$request : Object
	$request:=New object
	$request.protocol:=1
	$request.client:="apple-mail"
	If (Is Windows)
		$request.client:="simple-mapi"
	End if
	$request.to:=New collection
	If ($to#"")
		$request.to.push($to)
	End if
	$request.cc:=New collection
	If ($cc#"")
		$request.cc.push($cc)
	End if
	$request.bcc:=New collection
	$request.subject:=$subject
	$request.body:=$body
	$request.attachments:=New collection
	$request.interactive:=True
	return $request

Function _attachmentRequest($path : Text)->$request : Object
	$request:=This._request("dana@example.com"; ""; "Invoice 2026-114"; "Please review the attached invoice.")
	$request.attachments.push($path)
	return $request

Function _manyRecipientRequest()->$request : Object
	var $i : Integer
	$request:=This._request(""; ""; "Quarterly review"; "Plain text body.")
	For ($i; 1; 101)
		$request.to.push("person"+String($i)+"@example.com")
	End for
	return $request

Function _nulRequest()->$request : Object
	$request:=This._request("dana@example.com"; ""; "Quarterly"+Char(0)+"review"; "Plain text body.")
	return $request

Function _multibyteRequest()->$request : Object
	var $i : Integer
	var $subject : Text
	$subject:=""
	For ($i; 1; 400)
		$subject:=$subject+"あ"
	End for
	$request:=This._request("dana@example.com"; ""; $subject; "Plain text body.")
	return $request

Function _unknownFieldRequest()->$request : Object
	$request:=This._request("dana@example.com"; ""; "Quarterly review"; "Plain text body.")
	$request.attachmentsDir:="/tmp"
	return $request

Function _protocolRequest()->$request : Object
	$request:=This._request("dana@example.com"; ""; "Quarterly review"; "Plain text body.")
	$request.protocol:=2
	return $request
