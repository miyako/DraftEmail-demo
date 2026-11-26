#!/usr/bin/env python3
"""Generate the two demo forms.

The .4DForm JSON is the deliverable; this script exists so the layout stays
readable and consistent (shared palette, shared helpers). Re-run it after any
layout change, then validate:

    tools/4dform/boon .agents/schemas/4dform/formsSchema.json \
        Project/Sources/Forms/DraftStudio/form.4DForm
    tools/4dform/fourdform Project/Sources/Forms/DraftStudio/form.4DForm \
        -o docs/draft-studio.png
"""
import json
import pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent / "Project/Sources/Forms"

ACCENT = "#0A84FF"


def text(name, left, top, width, height, value, cls=None, align=None):
    o = {"type": "text", "left": left, "top": top, "width": width,
         "height": height, "text": value}
    if cls:
        o["class"] = cls
    if align:
        o["textAlign"] = align
    return o


def button(name, left, top, width, height, label, cls="action"):
    return {"type": "button", "left": left, "top": top, "width": width,
            "height": height, "text": label, "style": "roundedBevel",
            "class": cls, "events": ["onClick"]}


def input_(name, left, top, width, height, source, cls=None,
           multiline=False, enterable=True, border=None, hint=None):
    o = {"type": "input", "left": left, "top": top, "width": width,
         "height": height, "dataSource": source}
    if hint:
        o["dataSourceTypeHint"] = hint
    if cls:
        o["class"] = cls
    if multiline:
        o["multiline"] = "yes"
        o["wordwrap"] = "normal"
        o["scrollbarVertical"] = "automatic"
        o["events"] = ["onDataChange"]
    if not enterable:
        o["enterable"] = False
        o["focusable"] = True
        o["hideFocusRing"] = True
    if border:
        o["borderStyle"] = border
    return o


def listbox(name, left, top, width, height, source, current, columns, cls="list"):
    return {
        "type": "listbox", "left": left, "top": top, "width": width,
        "height": height, "listboxType": "collection",
        "dataSource": source, "currentItemSource": current,
        "selectionMode": "single", "resizingMode": "legacy",
        "rowHeight": "26px", "headerHeight": "24px",
        "borderStyle": "solid", "class": cls,
        "scrollbarVertical": "automatic",
        "alternateFill": "automaticAlternate",
        "events": ["onClick"],
        "columns": columns,
    }


def col(name, source, width, align="left"):
    return {"name": name, "dataSource": source, "width": width,
            "truncateMode": "none", "textAlign": align,
            "verticalAlign": "middle"}


def form(width, height, title, events, objects):
    return {
        "$4d": {"version": "1", "kind": "form"},
        "windowSizingX": "fixed",
        "windowSizingY": "fixed",
        "windowMinWidth": width,
        "windowMinHeight": height,
        "windowMaxWidth": width,
        "windowMaxHeight": height,
        "width": width,
        "height": height,
        "events": events,
        "windowTitle": title,
        "destination": "detailScreen",
        "method": "method.4dm",
        "pages": [
            {"objects": {
                "canvas": {"type": "rectangle", "left": 0, "top": 0,
                           "width": width, "height": height,
                           "fill": "automatic", "stroke": "transparent"}}},
            {"objects": objects},
        ],
    }


# --------------------------------------------------------------- Draft Studio
W, H = 1180, 768
studio = {
    "title": text("title", 24, 16, 340, 34, "DraftEmail", "appTitle"),
    "subtitle": text("subtitle", 24, 54, 680, 20,
                     "Compose a plain-text draft, then hand it to Apple Mail "
                     "— the component never sends", "appSubtitle"),
    "badge": text("badge", 740, 24, 416, 22, "resolving…", "badge", "right"),
    "rule": {"type": "rectangle", "left": 24, "top": 86, "width": 1132,
             "height": 1, "stroke": "transparent", "class": "rule"},

    "s1": text("s1", 24, 100, 380, 18, "1 · THE REQUEST", "section"),
    "lblTo": text("lblTo", 24, 126, 72, 20, "To", "label"),
    "inTo": input_("inTo", 100, 124, 304, 26, "Form.inTo",
                   cls="field", hint="text"),
    "lblCc": text("lblCc", 24, 158, 72, 20, "Cc", "label"),
    "inCc": input_("inCc", 100, 156, 304, 26, "Form.inCc",
                   cls="field", hint="text"),
    "lblBcc": text("lblBcc", 24, 190, 72, 20, "Bcc", "label"),
    "inBcc": input_("inBcc", 100, 188, 304, 26, "Form.inBcc",
                    cls="field", hint="text"),
    "hintCcbcc": text("hintCcbcc", 24, 218, 380, 18,
                      "cc/bcc are unsupported by Apple Mail's sharing service",
                      "hint"),
    "lblSubject": text("lblSubject", 24, 246, 72, 20, "Subject", "label"),
    "inSubject": input_("inSubject", 100, 244, 304, 26, "Form.inSubject",
                        cls="field", hint="text"),
    "lblBody": text("lblBody", 24, 280, 72, 20, "Body", "label"),
    "inBody": input_("inBody", 24, 302, 380, 116, "Form.inBody",
                     cls="field", multiline=True),

    "s2": text("s2", 24, 434, 260, 18, "ATTACHMENTS", "section"),
    "attachCount": text("attachCount", 284, 434, 120, 18, "0 files",
                        "hint", "right"),
    "attachmentList": listbox(
        "attachmentList", 24, 456, 380, 90,
        "Form.attachmentRows", "Form.selectedAttachment",
        [col("File", "This.name", 280), col("Size", "This.sizeLabel", 80, "right")]),
    "btnAdd": button("btnAdd", 24, 554, 110, 28, "Add file…", "secondary"),
    "btnRemove": button("btnRemove", 142, 554, 110, 28, "Remove", "secondary"),
    "hintAttach": text("hintAttach", 24, 590, 380, 18,
                       "Originals are never moved, changed or deleted", "hint"),

    "btnValidate": button("btnValidate", 24, 620, 178, 34, "Validate (no UI)",
                          "secondary"),
    "btnCompose": button("btnCompose", 210, 620, 194, 34, "Open draft in Mail",
                         "primary"),
    "noteA": text("noteA", 24, 664, 380, 16,
                  "Compose runs in a worker, so the mail dialog cannot", "hint"),
    "noteB": text("noteB", 24, 682, 380, 16,
                  "freeze this form. Only a person can press Send.", "hint"),
    "toast": text("toast", 24, 712, 380, 18, "", "toast"),

    "s3": text("s3", 428, 100, 728, 18,
               "2 · CAPABILITIES — A SUPPORTED CONTRACT, NOT A PERMISSION GRANT",
               "section"),
    "capTo": text("capTo", 428, 124, 112, 24, "to", "chip", "center"),
    "capCc": text("capCc", 548, 124, 112, 24, "cc", "chip", "center"),
    "capBcc": text("capBcc", 668, 124, 112, 24, "bcc", "chip", "center"),
    "capSubject": text("capSubject", 788, 124, 112, 24, "subject", "chip", "center"),
    "capBody": text("capBody", 908, 124, 112, 24, "body", "chip", "center"),
    "capAttach": text("capAttach", 1028, 124, 128, 24, "attachments", "chip",
                      "center"),
    "capNote": text("capNote", 428, 156, 728, 18, "", "hint"),

    "s4": text("s4", 428, 186, 728, 18, "3 · LIVE JOB", "section"),
    "jobStateText": text("jobStateText", 428, 208, 132, 24, "idle", "verdict"),
    "jobDetailText": text("jobDetailText", 568, 210, 588, 20, "", "hint"),

    "s5": text("s5", 428, 242, 600, 18,
               "4 · RETAINED ATTACHMENT COPIES (STAGING)", "section"),
    "stagingText": text("stagingText", 428, 264, 596, 20, "no batch", "hint"),
    "btnCleanup": button("btnCleanup", 1034, 262, 122, 26, "Clean up",
                         "secondary"),

    "s6": text("s6", 428, 296, 728, 18, "5 · LAST ENVELOPE", "section"),
    "envelopeView": input_("envelopeView", 428, 318, 728, 176,
                           "Form.envelopeText", cls="console",
                           multiline=True, enterable=False, border="none"),

    "s7": text("s7", 428, 506, 728, 18, "6 · TIMELINE", "section"),
    "timelineView": input_("timelineView", 428, 528, 728, 176,
                           "Form.timelineText", cls="console",
                           multiline=True, enterable=False, border="none"),
}

# ---------------------------------------------------------------- Contract Lab
LW, LH = 1080, 760
lab = {
    "title": text("title", 24, 16, 340, 34, "Contract Lab", "appTitle"),
    "subtitle": text("subtitle", 24, 54, 700, 20,
                     "The refusals are the feature: every field is validated "
                     "before anything is handed to Mail", "appSubtitle"),
    "badge": text("badge", 760, 24, 296, 22, "", "badge", "right"),
    "rule": {"type": "rectangle", "left": 24, "top": 86, "width": 1032,
             "height": 1, "stroke": "transparent", "class": "rule"},

    "s1": text("s1", 24, 100, 360, 18, "SCENARIOS", "section"),
    "scenarioList": listbox(
        "scenarioList", 24, 124, 360, 286,
        "Form.scenarioRows", "Form.selectedScenario",
        [col("Scenario", "This.name", 240), col("Layer", "This.layer", 96)]),
    "btnRun": button("btnRun", 24, 420, 112, 30, "Run", "secondary"),
    "btnRunAll": button("btnRunAll", 144, 420, 112, 30, "Run all",
                        "secondary"),
    "btnToStudio": button("btnToStudio", 264, 420, 120, 30, "To Studio",
                          "secondary"),

    "verdictBig": text("verdictBig", 24, 460, 360, 30, "—", "verdictBig"),
    "verdictDetail": input_("verdictDetail", 24, 494, 360, 34,
                            "Form.verdictDetail", cls="hint",
                            multiline=True, enterable=False, border="none"),

    "s2": text("s2", 24, 538, 360, 18, "REQUEST JSON", "section"),
    "requestView": input_("requestView", 24, 560, 360, 160,
                          "Form.requestText", cls="console",
                          multiline=True, enterable=False, border="none"),

    "s3": text("s3", 428, 100, 628, 18, "EXPECTATION", "section"),
    "expectView": input_("expectView", 428, 122, 628, 64, "Form.expectText",
                         cls="hint", multiline=True, enterable=False,
                         border="none"),

    "s4": text("s4", 428, 194, 628, 18, "ACTUAL ENVELOPE", "section"),
    "actualView": input_("actualView", 428, 216, 628, 150, "Form.actualText",
                         cls="console", multiline=True, enterable=False,
                         border="none"),

    "s5": text("s5", 428, 374, 628, 18, "RUN", "section"),
    "resultList": listbox(
        "resultList", 428, 396, 628, 190,
        "Form.resultRows", "Form.selectedResult",
        [col("Scenario", "This.name", 236),
         col("Expected", "This.expect", 130),
         col("Actual", "This.actual", 150),
         col("Verdict", "This.verdict", 94, "center")]),

    "s6": text("s6", 428, 594, 628, 18, "NOTES", "section"),
    "labLog": input_("labLog", 428, 616, 628, 104, "Form.labLogText",
                     cls="console", multiline=True, enterable=False,
                     border="none"),
}

FORMS = {
    "DraftStudio": form(W, H, "DraftEmail — Draft Studio",
                        ["onLoad", "onClick", "onTimer", "onUnload"], studio),
    "ContractLab": form(LW, LH, "DraftEmail — Contract Lab",
                        ["onLoad", "onClick", "onUnload"], lab),
}


def check_overlap(name, objects):
    """Report pairs of positioned objects that intersect (not a 4D check)."""
    boxes = []
    for key, o in objects.items():
        if "left" not in o or o.get("type") == "rectangle":
            continue
        boxes.append((key, o["left"], o["top"],
                      o["left"] + o["width"], o["top"] + o["height"]))
    hits = []
    for i, a in enumerate(boxes):
        for b in boxes[i + 1:]:
            if a[1] < b[3] and b[1] < a[3] and a[2] < b[4] and b[2] < a[4]:
                hits.append((a[0], b[0]))
    return hits


def main():
    for name, data in FORMS.items():
        target = ROOT / name / "form.4DForm"
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(json.dumps(data, indent="\t", ensure_ascii=False) + "\n",
                          encoding="utf-8")
        hits = check_overlap(name, data["pages"][1]["objects"])
        print(f"wrote {target.relative_to(ROOT.parent.parent)} "
              f"({len(data['pages'][1]['objects'])} objects) "
              f"overlaps={hits if hits else 'none'}")


if __name__ == "__main__":
    main()
