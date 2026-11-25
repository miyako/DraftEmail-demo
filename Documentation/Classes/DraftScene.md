# DraftScene

`cs.DraftScene` holds the Draft Studio's state and turns `DraftEmail` envelopes into form text. It
never sends mail. `compose` is the only method that sets `interactive: True`, and only a button click
reaches it.

Every method that inspects the request takes a `$fields` Object — the form, or a plain object with the
same keys — so the whole flow also runs without a window (see `Demo_HeadlessSmoke`).

```4d
var $scene : cs.DraftScene
$scene:=cs.DraftScene.new()
$scene.bind(Form)                    // starter values + first capability probe
$scene.validate(Form)                // no mail client involved
```

## Constructor

`cs.DraftScene.new()` probes the component once: `version()` and `capabilities()`, then resolves the
native target (`macOS-universal` on macOS, `Windows-x64` on Windows). The client name comes from the
capability reply, not from a local `If`.

## Properties

| Property | Type | Meaning |
| --- | --- | --- |
| `caps` | Object | Last raw `capabilities()` envelope |
| `versionText` | Text | CLI version, or `unavailable` |
| `clientName` | Text | `apple-mail` / `simple-mapi` as reported |
| `targetName` | Text | Native target passed to every call |
| `attachments` | Collection | `{name, size, path}` rows shown in the listbox |
| `jobId` | Text | Id of the current job, empty when none |
| `job` | Object | The **shared** job handle returned by `compose` |
| `polls` / `elapsedMs` | Integer | Polling counter shown in the studio |
| `lastResult` | Object | Last envelope, rendered verbatim in the panel |
| `stagingToken` | Text | 32-hex token of the helper-owned batch, empty when none |
| `stagingPaths` | Collection | Paths accounted for by that batch |
| `timeline` | Collection | Most recent calls, oldest first |
| `toast` | Text | One-line status under the buttons |

## Methods

### `bind($form : Object) -> $result : Object`

Sets the studio's starter values and copies presentation state onto `$form`, then calls `refresh`.

### `seed($form : Object; $request : Object) -> $bound : Object`

Prefills the studio from a Contract Lab scenario. Attachment paths that cannot be read are reported in
the timeline rather than turned into request entries, so a lab scenario about a missing file does not
silently become a request about no file.

### `probe()`

Re-runs `version()` and `capabilities()`. Read-only: it opens no mail UI.

### `validate($fields : Object) -> $result : Object`

Calls `composer.validate` with the request snapshot. This is the only place the studio asks the
component to check a request, and it never starts a process beyond the CLI's own `validate` verb.

### `compose($fields : Object) -> $result : Object`

Builds the request with `interactive: True`, calls `compose`, stores the returned shared job handle and
starts the poll clock. **This opens the user's mail client.** The demo only calls it from the
`Compose` button.

### `poll($fields : Object) -> $result : Object`

Calls `compose`'s counterpart `poll($job)` on the stored handle, increments the poll counter and
absorbs a staging token when the finished result carries one. The form calls this from `On Timer`.

### `cleanup($fields : Object) -> $result : Object`

Calls `cleanup` with the stored token and clears the staging state on success. A token that was never
issued is refused by the helper with `invalid_staging`, which is reported as-is.

### `addAttachment($path : Text) -> $file : Object` / `removeAttachment()` / `selectAttachment($row : Object)`

Attachment list management. `addAttachment` records name, size and path; a path that cannot be read is
refused with a message rather than added.

### `buildRequest($fields : Object; $interactive : Boolean) -> $request : Object`

The request snapshot shown in the studio's JSON panel. `$interactive` is an explicit argument, never a
default.

### `refresh($form : Object)`

Copies state onto the form, paints the capability chips and the panels. It is the only method that
touches the UI, and it returns early when no form is displayed.

### Presentation helpers

`badgeText`, `jobDetailText`, `stagingText`, `envelopeText`, `timelineText` return Text for the
corresponding form objects. `_capNote` builds the capability footnote, `_describe` names a result in
words ("handed off (handoff only, never delivery)" for a successful handoff), and `_code` returns the
first error code of an envelope. Deciding *which layer* refused is `DraftLab`'s job, since only it
knows what it sent.
