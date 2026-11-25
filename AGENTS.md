# AGENTS.md — DraftEmail-demo

An interactive 4D demo for the `DraftEmail` component. Read [`README.md`](README.md) and
[`docs/FINDINGS.md`](docs/FINDINGS.md) before changing behaviour; the findings explain the constraints
below rather than merely listing them.

## Hard rules

* **Never call `compose` in a verification run.** It opens the user's mail client and creates a
  draft. `version`, `capabilities`, `validate` and a bad-token `cleanup` are safe and are the whole
  basis of the automated checks.
* **`Project/Sources/dependencies.json` must exist before the first open** of this project. Without
  it 4D shows a modal component-import dialog that hangs every headless run.
* Keep the component pin in `dependencies.json` an exact tag (`0.1.4`), not a branch.
* `tool4d` cannot resolve that dependency from GitHub. Prime
  `~/Library/Caches/tool4d/Dependencies/.github/miyako/DraftEmail/<tag>/` from the IDE cache (folder
  **and** `<tag>.json`) before headless runs — see
  [`docs/FINDINGS.md`](docs/FINDINGS.md#1-tool4d-cannot-resolve-a-dependency-manager-dependency).

## Done gate

All four must pass before a commit that touches forms, classes or methods:

```sh
python3 scripts/make_forms.py                       # regenerates both .4DForm files, reports overlaps
tools/4dform/boon .agents/schemas/4dform/formsSchema.json \
  Project/Sources/Forms/DraftStudio/form.4DForm     # expect: ... ok
tools/4dform/boon .agents/schemas/4dform/formsSchema.json \
  Project/Sources/Forms/ContractLab/form.4DForm
tools/4dlsp/tool4d-lsp-stdio validate --workspace Project/ <absolute paths of every .4dm>
```

The LSP gate cannot be "zero diagnostics": a consumer project that depends on a compiled component
always reports `cs.DraftEmail is unknown` plus cascading `does not exist on type` warnings. Read the
diagnostics and fix everything else; leave those.

Behaviour gate:

```sh
tool4d --project Project/DraftEmail-demo.4DProject --dataless --skip-onstartup \
  --startup-method Demo_HeadlessSmoke --user-param '{"out":"/tmp/DraftEmail-demo-smoke.json"}'
```

`passed: true` and `"13 of 13 expectations matched"` are the expected values. A failing row is a
statement about the component or a wrong expectation in `DraftLab._catalogue` — decide which, then
update the catalogue note so it stays true.

## Layout rules

* Behaviour lives in `Project/Sources/Classes/DraftScene.4dm` and `DraftLab.4dm`, plus one form
  method per form. Never put logic in a form object's own method.
* `form.4DForm` files are **generated** by `scripts/make_forms.py`. Edit the generator, then
  regenerate; do not hand-edit the JSON.
* Form methods dispatch on `FORM Event.objectName`. A new control needs an entry in the generator, a
  branch in the method, and — if it shows state — a line in `DraftScene.refresh`.
* Class methods take `$form`/`$fields` explicitly instead of reading `Form`, so the flow keeps working
  in `Demo_HeadlessSmoke`. Keep that property; it is what makes the demo verifiable.
* UI writes stay inside `DraftScene.refresh` and its helpers, and those helpers return early when
  `Current form name=""`.

## CSS (`Project/Sources/styleSheets.css`)

`#RRGGBB` only, no alpha, no `rgb()`. A JSON value in `form.4DForm` beats the CSS rule, so a class is
useless on an object whose text/colour is also set in JSON. Buttons need an explicit `fontSize` and
`textAlign: center` in the `.button` rules. Keep the `@media (prefers-color-scheme: dark)` block in
step with the light palette.

## Text literals in 4D

Use `Char(13)` / `Char(10)` instead of `\r\n`. Do not write `$obj.key:$value` (it must be `:=`), close
`For` loops with `End for`, give a function's return variable a name distinct from its parameters, and
do not invent commands — check `tools/4dlang/4d-language-classic query "<description>"` first
(`OBJECT SET COLOR` does not exist; that mistake is recorded in the findings).
