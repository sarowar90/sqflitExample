---
name: commit-push
description: Stage changes, write a Conventional Commits message from the actual diff, commit, and push to GitHub. Use when the user asks to "commit and push", wants a conventional commit, or says things like "commit this", "push my changes", "make a commit message".
---

# Commit & Push (Conventional Commits)

Generate a commit message that follows the [Conventional Commits](https://www.conventionalcommits.org/) spec from the real diff, commit, and push to the remote.

## Steps

1. **Inspect state.** Run these together:
   - `git status --short` — see what changed and what is staged.
   - `git diff --stat` and `git diff` (unstaged) + `git diff --cached` (staged) — read the actual changes. Never write a message from file names alone.
   - `git log --oneline -10` — match the repo's existing message style.

2. **Decide what to stage.**
   - If nothing is staged, stage the changes relevant to this commit. Prefer `git add <specific paths>` over `git add -A` so unrelated files (e.g. `.claude/settings.local.json`, stray artifacts) are not swept in.
   - If the working tree mixes unrelated changes, commit only the coherent set and tell the user what you left out.
   - Do NOT commit secrets, `.env` files, or large binaries. If you see one staged, stop and ask.

3. **Write the message** in Conventional Commits format:

   ```
   <type>(<optional scope>): <short summary in imperative mood, lowercase, no trailing period>

   <optional body: what & why, wrapped ~72 cols>

   <optional footer: BREAKING CHANGE: ... / Refs #123>
   ```

   - **type** (required) — pick from the diff's intent:
     | type | use for |
     |------|---------|
     | `feat` | a new feature / user-facing capability |
     | `fix` | a bug fix |
     | `docs` | docs only (README, CLAUDE.md, comments) |
     | `style` | formatting/whitespace, no logic change |
     | `refactor` | code change that neither fixes a bug nor adds a feature |
     | `perf` | performance improvement |
     | `test` | adding or fixing tests |
     | `build` | build system, dependencies (pubspec.yaml) |
     | `ci` | CI config |
     | `chore` | maintenance, tooling, misc |
     | `revert` | reverting a previous commit |
   - **scope** (optional) — a short area of the codebase. For this Flutter app, prefer the feature/file: `dashboard`, `sales`, `inventory`, `db`, `providers`, `theme`, `deps`, etc.
   - **summary** — imperative mood ("add", not "added"/"adds"), ≤ ~72 chars, lowercase start, no period.
   - **body** — only when the change needs a "why". Skip for trivial one-liners.
   - Use `BREAKING CHANGE:` in the footer (or `!` after type/scope, e.g. `feat!:`) for incompatible changes.

   If the staged changes span multiple unrelated types, that's a sign they should be separate commits — surface that to the user rather than forcing one message.

4. **Commit.** Use a heredoc so multi-line messages and the trailer are preserved:

   ```bash
   git commit -m "$(cat <<'EOF'
   <type>(<scope>): <summary>

   <body>

   Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
   EOF
   )"
   ```

   Never use `--no-verify`; if a hook fails, fix the underlying issue.

5. **Push.** Run `git push`. If the branch has no upstream, use `git push -u origin <branch>`. Report the resulting ref range and remote URL back to the user.

## Notes

- If not in a git repo, tell the user (offer `git init`).
- If there is nothing to commit, say so — don't create an empty commit.
- Show the user the final message you committed.
