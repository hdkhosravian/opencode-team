---
description: Review the current uncommitted or last commit changes (reviewer, read-only)
agent: reviewer
subtask: true
---
Review these changes: $ARGUMENTS

If no range is given, review `git diff HEAD` (uncommitted) or, if empty, `git show HEAD`. Find the task card from the commit message or the changed paths if one exists.
