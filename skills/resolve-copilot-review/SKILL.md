---
name: resolve-copilot-review
description: Triage GitHub Copilot's automated PR review comments, fix the confirmed issues, and resolve the review threads. Use when the user mentions Copilot review findings/comments, asks to address or clear PR feedback, or wants Copilot's review threads resolved.
---

# Resolve Copilot Review

## Step 1 — Identify the PR

Get `owner`/`repo` from the base repository (where the PR and its threads live —
`gh pr view` only exposes the *head* repo, which differs on fork PRs):

    gh repo view --json owner,name -q '.owner.login + "/" + .name'

Then get the PR `number` — the one the user named, or the open PR for the current branch:

    gh pr view --json number,url,headRefName

Completion: you have `owner`, `repo`, and PR `number`.

## Step 2 — Fetch Copilot's review threads

REST's `pulls/{n}/comments` endpoint carries neither thread-resolution state nor a resolvable thread id — both only exist via GraphQL's `reviewThreads`. Fetch threads there:

    gh api graphql -f query='
      query($owner:String!,$repo:String!,$pr:Int!){
        repository(owner:$owner,name:$repo){
          pullRequest(number:$pr){
            reviewThreads(first:100){
              nodes{
                id isResolved path line
                comments(first:10){nodes{id databaseId author{login} body path line}}
              }
            }
          }
        }
      }' -f owner=OWNER -f repo=REPO -F pr=NUMBER

Filter to threads where `isResolved` is false and the first comment's `author.login` contains "copilot" (case-insensitive — the exact login string has varied). Completion: for every open Copilot thread you have the GraphQL thread `id`, the file `path`/`line`, the finding text, and the first comment's `databaseId`.

`id` (GraphQL node id, used to resolve the thread) and `databaseId` (REST numeric id, used to reply) are different id spaces for the same comment — don't cross them.

If there are zero open Copilot threads, say so and stop here.

## Step 3 — Triage every finding before touching code

For each open thread, read the referenced file at that line and judge it: **valid** (a real defect) or **not applicable** (already handled, out of scope, or the bot is wrong). Report the full list with a one-line verdict and reason per finding — this is the "tell me if they're valid" step, and it happens before any edit.

Completion: every open thread has a stated verdict, reported to the user.

## Step 4 — Fix, reply, resolve

For each thread, in verdict order:

1. **Valid** — make the fix. Reply on the thread naming what changed:
   `gh api repos/OWNER/REPO/pulls/NUMBER/comments/DATABASE_ID/replies -f body="..."`
2. **Not applicable** — reply explaining why, same endpoint, no code change.
3. Resolve the thread either way:
   `gh api graphql -f query='mutation($id:ID!){resolveReviewThread(input:{threadId:$id}){thread{isResolved}}}' -f id=THREAD_ID`

Completion: every thread from Step 3 has a reply and is resolved; every valid fix is staged.

## Step 5 — Commit and push

Commit the fixes (skip if none were needed) and push to the PR's branch, so the diff Copilot reviewed actually reflects the fixes.

Completion: working tree clean, branch pushed, PR updated.
