---
name: custom-workflow-maintain-reviews
description: Show in-flight PR reviews (started but not resolved), with cleanup options for merged/closed PRs.
user-invocable: true
allowed-tools: Bash(gh pr view:*), Bash(gh pr list:*), Bash(git worktree list:*), Bash(git worktree remove:*), Bash(git push:*), Bash(git branch:*), Bash(ls:*), Bash(curl:*), mcp__friday__friday_pr_review_resolve
---

# Review Status

## Step 1: Fetch all `pr.review.started` events

Use `curl` to GET `$FRIDAY_API_URL/v1/events?type=pr.review.started` with `Authorization: Bearer $FRIDAY_API_TOKEN`. The response is a plain JSON array (not a paginated object). Extract all `source_id` values (PR URLs) with their `payload` and `occurred_at`.

## Step 2: Fetch all `pr.review.resolved` events

Same approach for `type=pr.review.resolved`. The response is also a plain array. Collect resolved `source_id` values.

## Step 3: Derive in-flight reviews

Subtract resolved source_ids from started source_ids. The remainder is the in-flight set. If there are none, report "No in-flight PR reviews." and stop.

## Step 4: For each in-flight PR, gather state

For each in-flight PR URL:
- Run `gh pr view <pr-url> --json state,title,number,headRepositoryOwner,headRepository,mergedAt,closedAt` to get current PR state (open / merged / closed).
- Extract `repo` as `<headRepositoryOwner.login>/<headRepository.name>` from the response.
- Extract `number` from the response (or parse it from the URL as fallback).
- Check worktree: run `ls /tmp/review-<number>` — note whether it exists (✓) or not (—).
- Check branch: run `git -C /home/friday/Code/friday.assertchris.dev branch --list "review/<number>-*"` — note whether any match (✓) or not (—).

## Step 5: Render summary

Print a markdown table with columns: `PR`, `State`, `Worktree`, `Branch`, `Started`.

Example:
```
| PR | State | Worktree | Branch | Started |
|---|---|---|---|---|
| [fix-auth #42](https://...) | merged | /tmp/review-42 ✓ | review/42-fix-auth ✓ | 2026-08-20 |
| [add-search #51](https://...) | open | — | — | 2026-08-22 |
```

Use the PR title and number from the `gh pr view` output. Format the `Started` date as `YYYY-MM-DD` from `occurred_at`.

## Step 6: Offer cleanup for completed PRs

For each PR whose state is `merged` or `closed`, list the available cleanup actions:
- If worktree exists: `rm -rf /tmp/review-<number>` (these are plain checkout directories, not registered git worktrees)
- If branch exists: `git -C /home/friday/Code/friday.assertchris.dev branch -D review/<number>-<slug>` and `git push origin --delete review/<number>-<slug>` (only if the remote branch exists)
- Call `friday_pr_review_resolve` with the PR URL to drop it from future status runs

Ask Chris which cleanups to perform, then execute only the approved ones.
