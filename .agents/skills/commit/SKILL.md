---
name: commit
description: Analyze MacDuo Git changes and prepare English Conventional Commits-style messages, with Chinese change summaries, complete file lists, and explicit confirmation before committing. Use when the user requests a commit or help preparing a commit message.
---

# MacDuo Commit

## Scope and confirmation

Create local commits. Pushing and publishing are separate operations. If the user requests only a commit message, return a draft without committing.

Before running `git add` or `git commit`, show the complete message, a Chinese summary, and every file to be committed, then wait for explicit confirmation. A general request to commit does not approve contents that have not yet been shown. Do not ask again when the user has already explicitly approved the same message and file scope. Explicit user instructions overriding this workflow take precedence.

Approval covers only the reviewed changes. Recheck the working tree after confirmation and exclude newly introduced, unreviewed changes. Read-only inspection and validation may proceed before confirmation. No reply means pending approval, never consent. If the user cancels, stop without repeated reminders.

## Inspect and validate

1. From the repository root, inspect `git status --short --untracked-files=all`, `git diff --cached`, and `git diff`. Read untracked files. Account for additions, modifications, deletions, renames, and binary assets. Treat hidden directories, including `.agents` and `.opencode`, like other files while respecting `.gitignore`.
2. Check the current branch and existing staged changes. Handle a repository without HEAD as an initial commit. Do not clear or overwrite the user's index. If staged changes fall outside the requested scope, resolve that scope before committing; do not accidentally include the entire index.
3. Review relevant changes and run `git diff --check`. Run `swift test` for Swift logic changes. Run `./scripts/build-app.sh` when app resources, packaging, or UI compilation need verification. For documentation or skill-only edits, check formatting and references. Reuse successful checks that apply to the final contents.
4. If Swift cannot write its default module cache, use repository-local caches:

   ```sh
   CLANG_MODULE_CACHE_PATH="$PWD/.build/module-cache" SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/module-cache" swift test --disable-sandbox --cache-path "$PWD/.build/cache"
   ```

5. Exclude `.build/`, `dist/`, `.swiftpm/`, `.local-signing-identity`, exported signing certificates, private keys, and credentials. Do not force-add ignored files. Icons in `assets/` are source resources and may accompany their relevant changes.
6. If there are no changes, report that no commit is needed. Report validation failures accurately rather than describing incomplete checks as successful.

## Message format

Write the complete commit message in English with a lowercase prefix:

- `feat:` for new functionality.
- `fix:` for bug fixes.
- `chore:` for documentation, skills, dependencies, formatting, refactoring, tests, and other maintenance.
- `release: X.Y.Z` for the project's release commit convention; also consult the [release skill](../release/SKILL.md).

For `feat:`, `fix:`, and `chore:`, begin the description with a lowercase letter and keep the description within 50 characters. Use English `- ` bullets in the body, each beginning with a lowercase letter. Describe the final changes precisely instead of merely listing filenames.

## Present the commit for confirmation

Use the following Chinese template. Put the entire message in its own `text` fence. Replace all placeholders and list every actual file without ellipses:

````markdown
=== 需要确认提交 ===

提交信息：
```text
feat: add interface language selection

- support english and simplified chinese
- persist the selected interface language
```

变更摘要：
- [中文说明实际变更]

将提交的文件：
- [逐项列出真实文件路径及新增、修改或删除状态]

验证结果：
- [实际执行的检查及结果，说明未完成的必要检查]

确认提交吗？请回复“确认”继续，或回复“取消”终止。
````

Accept “确认”, “是”, “提交”, including their punctuated forms, and `yes`, `y`, or `confirm` as confirmation. Accept “取消”, “否”, `no`, `n`, or `cancel` as cancellation. For an ambiguous reply, say: “您的回复不明确。请回复‘确认’继续提交，或回复‘取消’终止。” Wait for a clear answer; silence is not confirmation.

## Commit and verify

1. After confirmation, recheck that the files and contents match the reviewed scope.
2. Prefer `git add -- <approved paths>`, including approved deletions. Use `git add .` only when all repository changes were shown and approved.
3. Inspect the final staged diff and `git diff --cached --stat` to exclude unrelated content.
4. Write the approved message verbatim to a temporary UTF-8 file and use `git commit -F <message-file>`. Preserve real newlines and avoid shell expansion of message text.
5. Verify with `git log -1 --format=fuller`, `git show --stat --oneline HEAD`, and `git status --short`. Report the hash, title, and remaining changes in Chinese. Do not imply that the commit was pushed.

If a commit or hook fails, preserve the state and explain the cause. Do not bypass hooks, force a commit, or rewrite history. On cancellation, say: “提交已取消。如需继续，请重新发起提交请求。”
