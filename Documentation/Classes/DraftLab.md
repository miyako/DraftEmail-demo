# DraftLab

`cs.DraftLab` is the Contract Lab's catalogue and run loop. Each scenario is a request plus the layer
that is expected to refuse it and the exact code that layer returns. Nothing here composes mail: the
lab only calls `version`, `capabilities`, `validate` and a `cleanup` with a token that cannot exist.

```4d
var $lab : cs.DraftLab
$lab:=cs.DraftLab.new()
var $rows : Collection
$rows:=$lab.runAll()
$lab.summary($rows)   // "13 of 13 expectations matched"
```

## Layers

| Layer | Meaning | Evidence |
| --- | --- | --- |
| `component` | `cs.DraftEmail.Composer` refused before any process was launched | no CLI process, error comes from 4D code |
| `native` | the bundled `draft-email-cli` ran and exited with a JSON error envelope | envelope has `exitCode` and `error.code` |
| `prelaunch` | the component refused the target before launching the CLI | `unsupported_architecture`, no process |

The layer is **declared** in the catalogue, not inferred from the envelope, because an envelope alone
cannot tell you whether a process started.

## Properties

| Property | Type | Meaning |
| --- | --- | --- |
| `scenarios` | Collection | The catalogue, in display order |
| `log` | Collection | Last eight run lines, oldest first |

Each scenario object: `id`, `name`, `layer`, `expect`, `kind` (`validate`, `capabilities`, `target`,
`cleanup`), `note`, `request`.

## Methods

### `run($scenario : Object) -> $result : Object`

Builds a composer for the native target, dispatches on `$scenario.kind`, compares the resulting code
with `$scenario.expect` and sets `verdict` to `PASS` or `FAIL`. The full envelope is kept in
`$result.envelope` so the lab can show exactly what the component returned.

`kind: "target"` is the one case that deliberately does not use the native target: it asks for
`Windows-x64` on macOS to provoke the prelaunch refusal.

### `runAll() -> $results : Collection`

Runs every scenario in catalogue order. Thirteen short CLI invocations; no mail client, no draft.

### `target() -> $target : Text`

`macOS-universal` on macOS, `Windows-x64` on Windows.

### `code($result : Object) -> $code : Text`

The observable code of an envelope: `value.status` on success (`validated`, `ok`), `error.code` on
failure. `unknown` if neither is present — a shape the demo treats as a failure of the component
rather than as a pass.

### `row($result : Object) -> $row : Object`

The listbox row shape: `name`, `expect`, `actual`, `verdict`, `layer`, `note`, `envelope`.

### `expectText($scenario : Object) -> $text : Text`

"expect `<code>` from the `<layer>` layer." plus the scenario's prose note.

### `summary($rows : Collection) -> $text : Text`

`"N of M expectations matched"` — counts `PASS` verdicts, so a failing run is visible in one string.

### `logText() -> $text : Text`

The retained log lines joined with `Char(13)`, or `(nothing run yet)`.

## Catalogue

| id | kind | layer | expectation |
| --- | --- | --- | --- |
| `minimal` | validate | native | `validated` |
| `cc-on-macos` | validate | native | `unsupported_field` |
| `display-name` | validate | native | `invalid_request` |
| `missing-attachment` | validate | native | `invalid_attachment` |
| `relative-attachment` | validate | component | `invalid_argument` |
| `too-many-recipients` | validate | component | `invalid_argument` |
| `nul-in-subject` | validate | component | `invalid_argument` |
| `multibyte-subject` | validate | native | `limit_exceeded` |
| `unknown-field` | validate | component | `invalid_argument` |
| `protocol-2` | validate | component | `invalid_argument` |
| `windows-target` | target | prelaunch | `unsupported_architecture` |
| `stale-token` | cleanup | native | `invalid_staging` |
| `capabilities` | capabilities | native | `ok` |

Changing an expectation is a claim about the component: run `Demo_HeadlessSmoke` and read `passed`
before committing the new value.
