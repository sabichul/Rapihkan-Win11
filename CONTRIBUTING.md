# Contributing to Rapihkan Win11

Use this guide when changing scripts, organization rules, or documentation.

## Keep user files safe

- Design file changes so they can be restored.
- Explain the effect of an action in plain English.
- Keep the three `YES` confirmations before any bulk file-move action.
- Do not add permanent deletion, registry changes, service changes, startup changes, or automatic restarts.
- Protect system folders, reparse points, cloud files that are not available locally, and locked files.

## Keep personal data out of commits

Do not commit `Reports`, `Logs`, `Backup`, or `Quarantine`. Those folders can contain file names, paths, or manifests from a user's computer.

## Test before opening a pull request

Run these scripts from the project folder.

```powershell
& '.\Tests\Toolkit-Tests.ps1'
& '.\Tests\Path-Validation-Tests.ps1'
& '.\Tests\Safety-Tests.ps1'
```

Add a test when a change affects path validation, file moves, quarantine, or user confirmation.
