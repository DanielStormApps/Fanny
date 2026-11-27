---
name: /complete-plan-and-merge
description: move plan to completed, merge into the parent branch, cleanup branch
disable-model-invocation: false
---

The merge target is the branch the task branch was cut from - usually `develop`, but a task cut from a long-lived feature branch merges back into that feature branch, so merging it into `develop` would drag the whole feature branch along. Say in the reply which branch you merged into.

If the branch has a plan md in plans/, move it to plans/completed/ and commit; never move a plan that belongs to other work. Push the current task branch. Checkout the target. Run `git fetch origin && git pull origin <target>` to ensure it is fully up to date with the remote before merging. Merge the task branch into the target using --no-ff. Push the target. Delete the task branch locally and on the remote. Reply here when done.

$ARGUMENTS
