# Agentic PBI Development

Workspace for building Power BI projects (PBIP format, PBIR reports, TMDL semantic models) with Claude Code.

## Layout

```
.claude/settings.json   # power-bi-agentic-development plugins (shared)
.mcp.json               # powerbi-modeling-mcp server (shared)
shared/themes/          # master copies of report themes
projects/<Name>/        # one folder per project
    <Name>.pbip
    <Name>.Report/
    <Name>.SemanticModel/
```

## Conventions

- Create every new project in its own folder under `projects/`. Never put a `.pbip` at the repo root.
- Keep a project's `.pbip`, `.Report` and `.SemanticModel` in the same folder. The report links to its model by relative path in `<Name>.Report/definition.pbir` (`"path": "../<Name>.SemanticModel"`); update that path if anything moves.
- Several reports can share one model: give each report its own `.pbip` + `.Report` in the same project folder, all pointing at the one `.SemanticModel`.
- Keep project names short, without spaces. PBIR nests files deeply (`definition/pages/<id>/visuals/<id>/visual.json`) and Windows' 260-character path limit applies.
- Themes: edit the master in `shared/themes/`, then copy it into the report's `StaticResources/RegisteredResources/`. Reports only read their own copy.

## Working with Power BI Desktop

- Power BI Desktop does not reload files changed on disk. After editing PBIR/TMDL files, close and reopen the `.pbip` to see changes.
- Saving in Desktop overwrites the project files, including any edits made on disk while it was open. Close Desktop before editing files directly, or ask the user to.
- Do not move or rename project folders while Desktop has the project open.

## Git

- `.pbi/localSettings.json` and `.pbi/cache.abf` are local-only and gitignored. Do not commit them.
- Use `git mv` when moving or renaming project folders so history is kept.
