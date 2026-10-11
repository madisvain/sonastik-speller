---
name: prdesc
description: >
  Fill the repo pull request template and update the open PR body.
  Use when the user runs /prdesc, or asks for a PR description, PR body,
  or to fill the pull request template.
metadata:
  short-description: "Write the PR description"
argument-hint: "[base branch]"
---

# Pull request description

Write the PR body from `.github/pull_request_template.md`. That file is the section list and the rules. Do not add sections it does not have.

## Gather

In the repo root:

- Read `.github/pull_request_template.md`. If it is missing, stop and say so.
- Base: `$ARGUMENTS` when it names a branch. Otherwise the open PR base from `gh pr view --json baseRefName`. Otherwise the default branch.
- `git log --oneline --no-merges <base>..HEAD`
- `git diff --stat <base>...HEAD`, plus enough of the diff to name the areas.
- For each commit, keep `(#N)` when the subject already has it. Otherwise run `gh api "repos/{owner}/{repo}/commits/{sha}/pulls" --jq '.[0].number'` and append `(#N)` when a number comes back. Otherwise append the short SHA.

## Write

Follow the template comments. Strip every HTML comment from the body you submit.

- Summary: 1–3 sentences. What changed, why, and whether behavior or the API changed. For a refactor or chore, say "no behavior change".
- Changes: one bullet per commit, using its subject. Group under Features (`feat`), Fixes (`fix`), Refactors (`refactor`), Docs (`docs`), and Other (everything else). Omit empty groups. Include every commit in `<base>..HEAD`.
- What changed: one bullet per area or important file.
- Design notes: only a non-obvious decision. Omit the heading when there is nothing to say.
- Before / after: only when a short comparison explains a refactor or API change. Omit the heading when the diff is enough.
- Testing: commands that were actually run, and the outcome. Do not claim a command that was not run. Drop the template's sample `make signoff` line unless that command was run.

## Update

If this branch has an open PR, write the body to a temp file and run `gh pr edit --body-file` on it. Do not change the title. Do not push.

If there is no open PR, show the body in the reply. Do not open a PR unless the user asked.

Delete the temp file when done.
