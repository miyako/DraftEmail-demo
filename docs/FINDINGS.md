# Findings

What was cheap, what fought back, and what is worth knowing before using `DraftEmail` 0.1.4 in a
real 4D application. Everything below was observed while building this demo on macOS with 4D 21.2
LTS (build 100694) and its bundled `tool4d`.

## 1. tool4d cannot resolve a Dependency manager dependency

`Project/Sources/dependencies.json` asks for `{"github":"miyako/DraftEmail","tag":"0.1.4"}`. The 4D
IDE resolves that on first open and reports nothing. `tool4d` does not:

```
PackageManager No component to fetch dependencies ()
PackageManager Dependency 'DraftEmail' cannot be found ()
```

Both 21.2 LTS `tool4d` and the 21 R5 `tool4d` show it, with an empty `()` where the component name
would be expected. The project then opens with no component, so any `cs.DraftEmail…` call fails and
the smoke method cannot run.

The cache layouts are parallel, so a copy fixes it — the IDE caches under `4D`, `tool4d` looks under
`tool4d`:

```sh
cp -R ~/Library/Caches/4D/Dependencies/.github/miyako/DraftEmail/0.1.4 \
      ~/Library/Caches/tool4d/Dependencies/.github/miyako/DraftEmail/0.1.4
cp    ~/Library/Caches/4D/Dependencies/.github/miyako/DraftEmail/0.1.4.json \
      ~/Library/Caches/tool4d/Dependencies/.github/miyako/DraftEmail/0.1.4.json
```

Do that after opening the project once in the IDE. Alternatively drop a copy into `Project/Components/`,
which outranks `dependencies.json` — but this repository does not commit one, so the cache is what a
headless checkout relies on. The metadata file is what makes the tag resolvable:

```json
{
  "github": "miyako/DraftEmail",
  "tag": "0.1.4",
  "htmlURL": "https://github.com/miyako/DraftEmail/releases/tag/0.1.4",
  "archiveURL": "https://github.com/miyako/DraftEmail/releases/download/0.1.4/DraftEmail.zip",
  "archiveSize": 330174,
  "dependencies": null
}
```

**Why it matters.** Any headless CI story built on `tool4d` has to pre-seed the cache, or the project
must be able to run with a locally installed component instead. Copying only the unpacked folder is
not enough; the `.json` beside it carries the tag identity.

## 2. `poll` rejects a job object that is not shared

`compose` returns `{ok, jobId, job}`, and only `job` can be polled. Passing a copy — for example a
job rebuilt from JSON stored in a listbox row, which is the obvious way to show a job in a list —

```
{"ok": false, "error": {"code": "invalid_argument", "message": "…"}}
```

The shared reference is the handle. In this demo the job lives on the scene object, which every form
method can reach; a design that serialises jobs into the form is broken by construction.

The demo keeps exactly one job, on the scene object, and polls it from `On Timer` until
`finished: true`.

## 3. The component's pre-check makes the CLI's `unknown_field` unreachable

The component owns a closed-field check before it launches anything, so an extra key such as
`attachmentsDir` is refused with `invalid_argument` **at the component layer**. The CLI documents its
own `unknown_field` code, but from 4D that code cannot be provoked: two layers enforce the same
closed protocol and the outer one always wins.

The Lab row for it therefore expects `invalid_argument` and names the `component` layer, rather than
pretending to demonstrate a CLI behaviour the host cannot reach. A demo that asserted
`unknown_field` would have been a permanently failing row — worth noticing, because the protocol
document lists that code and it reads as testable.

## 4. Limits are byte limits, and the host counts characters

`subject` is limited to 998 **bytes**. The component's own pre-check is a character test —
`If (($field="subject") & (Length($text)>998))` with the message "subject exceeds the request
character limit" — so 400 Japanese characters pass it, and the CLI then refuses:

```
{"protocol":1,"error":{"code":"limit_exceeded","message":"subject is 1200 bytes, limit is 998"}}
```

The request the operator typed is 400 characters; the request the CLI reads is 1200 bytes. Two limits
with the same number mean different things in the two layers, and a host-side counter must count
UTF-8 bytes rather than `Length($text)`.

## 5. `cleanup` refuses a well-formed token that was never issued

A cleanup token is `^[0-9a-f]{32}$`. A string that matches that pattern but came from nowhere is not
a silent no-op — it is a `native` layer refusal with `invalid_staging` and a non-zero exit code. Good
news for correctness, and it means "cleanup is idempotent" is wrong as a statement about the API: it
is only safe to call with a token the helper issued.

It also means staging cleanup is a decision, not a side effect. In the demo `Cleanup` is a button and
the panel says how many copies are retained, because an open compose window may still need them.

## 6. Window ownership makes a menu click deadlock a naive window manager

The canonical demo pattern (see `DisplayScale-demo`) opens the form through
`CALL WORKER(1; Current method name; …)` so the window belongs to a stable worker. That pattern
actively breaks a two-window demo:

* the studio is inside `DIALOG` in worker 1, so worker 1 is busy inside its own modal loop;
* a menu item clicked while that dialog is up runs **in that same process**;
* if the menu method then calls `CALL WORKER(1; …)` with its own name, the message is queued behind
  the dialog that is waiting for it, and the new window never appears.

Opening the second window directly in the calling process — nested `DIALOG` — works and is what this
demo does. The `CALL WORKER` indirection is only needed when the form must survive a
`New process`/menu-model switch, not merely to have "a worker".

Consequence for `Contract Lab ▸ To Studio`: the seed request is passed as a parameter
(`Demo_OpenStudio({seed: …})`) instead of through `Storage`, so no cross-process state is involved.

## 7. No runtime screenshots from tool4d

`tool4d` refuses the window commands outright:

```
tool4d.HDLS (Open form window)
tool4d.HDLS (DIALOG)
```

so `FORM SCREENSHOT` from a headless run is not available, and `WRITE PICTURE FILE` never gets a
picture. The same run under the full IDE in a non-interactive session produced no file and exited
silently.

The form images in this repository are therefore static renders produced by `tools/4dform/fourdform`
from the `form.4DForm` files. They show layout and text, not runtime state: the capability chips, the
envelope panel and the timeline are empty in a render because they are painted by the form method.

A useful consequence: **do not put "looks right" behind a screenshot gate you cannot execute.**
The gates that did run are the JSON-schema validation, a generator that reports object overlaps, and
the headless behaviour smoke.

## 8. The analyzer cannot see the component's classes

`tool4d-lsp-stdio validate` on this project reports, for every class that names it:

```
error: The class cs.DraftEmail is unknown.
error: The class cs.DraftEmail.Composer is unknown.
warning: The function or property validate does not exist on type cs.DraftEmail.Composer. (550.2)
```

That is expected for a *source* project that depends on a compiled component: the analyzer opens the
project, not the resolved 4DZ, so the namespace is unknown to it. It is noise, not a defect — but it
means the LSP gate cannot be "zero diagnostics" in a consumer project. The gate that works is:
zero diagnostics *other than* the `cs.<namespace>` unknowns, which requires reading the diagnostics
rather than counting them.

Two real diagnostics that did surface this way were worth fixing, and both are recorded in §10.

## 9. Design the demo so the flow runs without a form

Passing the form explicitly (`bind($form)`, `validate($fields)`, `refresh($form)`) instead of reading
`Form` inside the class made the entire flow runnable from `tool4d` with a plain object that has the
same keys. That is what `Demo_HeadlessSmoke` does, and it is why the thirteen Lab expectations are
checked by an actual run rather than by a person clicking.

Only the presentation step has to know about a window, and it guards itself:

```4d
Function _paintChip($name : Text; $label : Text; $on : Boolean)
	If (Current form name="")
		// No form is displayed (headless smoke): there is nothing to paint.
		return
	End if
```

Without that guard the headless run aborted silently partway through `refresh`, leaving a report that
looked complete but had missing fields. Silent partial failure inside a UI-refresh method is the
failure mode to watch for in any headless-capable 4D code.

## 10. 4D traps hit while writing this demo

Recorded because each one cost a run:

| Symptom | Cause | Fix |
| --- | --- | --- |
| `Syntax error` on a colour call | `OBJECT SET COLOR` is not a 4D command; it was invented from memory | Set the title text instead; colour is a CSS class concern |
| `Impossible to cast Integer to Array<Variant>` | `Max(a; b)` resolved to the array overload because an argument was Variant-typed | Compare and assign explicitly |
| `Syntax error` / `Missing trailer` | `For (…)` closed with `End for each` | `End for` |
| `A ":=" was expected` with no line number | A statement was written `$obj.prop:$value` | `:=` |
| A returned object silently missing keys | Empty and Null-valued keys are dropped from `New object(...)`, so a `Null` chip title disappeared from the report | Read the key with `Value type` before trusting presence |
| A parameter and a return variable with the same name | `Function seed($form …)->$form` | Distinct name for the return variable |
| A `$params.seed` handoff that silently did nothing | A form method declared `#DECLARE($params : Object)` | Read `Form.seed`: `DIALOG`'s data becomes `Form`, and a form method is never called with a parameter |

The `$params` case deserves its own sentence, because it is the one here that
compiled, ran, and failed silently. `Demo_OpenStudio` passes the chosen lab
scenario to the form as `DIALOG("DraftStudio"; New object("seed"; …); *)`, which
makes it `Form.seed`; copying the start method's `#DECLARE($params : Object)`
into the form method instead leaves `$params` `Null` on every event, so the
editor never prefilled and no error was raised anywhere. Headless coverage of
`seed` itself would not have caught it — the wiring only exists with a window —
so the guard is the rule in [`AGENTS.md`](../AGENTS.md): form methods read
`Form`, never parameters.

## 11. What the component gets right

Worth stating, because it shaped the demo:

* `capabilities` answers with a field contract the UI can be built from, including
  `deliveryConfirmed: false` and `interactiveRequired: true`. The demo reads it instead of hard-coding
  `cc`/`bcc` as unsupported, so the same form is honest on Windows.
* Refusals are structured, layered and specific. Every scenario in the Lab has a distinct code, and
  the message says what was wrong ("subject is 1200 bytes, limit is 998").
* `compose` dispatches to a worker. The calling process is free, which is why the studio can animate a
  poll counter while the mail dialog is up.
* Nothing in `validate`, `capabilities` or a bad-token `cleanup` opens a mail client, so a demo can be
  run and verified without side effects. That is what made this repository testable at all.
