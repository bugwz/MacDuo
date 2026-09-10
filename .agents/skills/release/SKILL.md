---
name: release
description: Prepare MacDuo versions, Chinese release notes, release commits, and vX.Y.Z tags; obtain confirmation for remote actions, verify signed and notarized GitHub Actions artifacts, and update draft release descriptions. Use for release preparation, release tags, publication, or release description updates.
---

# MacDuo Release

## Project conventions

Read the current [release documentation](../../../docs/RELEASING.md), [release workflow](../../../.github/workflows/release.yml), [build script](../../../scripts/build-app.sh), and [packaging script](../../../scripts/package-release.sh). Follow their actual implementation if it changes.

- Use `X.Y.Z` for the version value, such as `0.0.1`. **Git tags must use `vX.Y.Z`**, such as `v0.0.1`. This workflow requires the `v` prefix, unlike the reference browser-extension project.
- Store notes at `release/X.Y.Z.md`. Use `release: X.Y.Z` as the commit title and `MacDuo vX.Y.Z` as the GitHub Release title.
- This is a Swift Package project. Do not introduce browser manifests, `package.json`, or `package-lock.json` for version management.
- Official artifacts require an arm64 + x86_64 universal build, Developer ID Application signing, Apple notarization, and stapled tickets. Apple Development and ad hoc signed builds are development artifacts, not official releases.
- The tag workflow creates or updates a **draft Release** and refuses to overwrite a published version. Preparing a draft and publishing it are distinct actions.

## Confirmation policy

Before committing, creating a tag, pushing, or modifying a remote Release, show the exact operation and relevant files or remote targets, then wait for explicit confirmation. Complete read-only inspection, version edits, notes, and validation first so the user reviews concrete results. Do not request confirmation again for the same explicitly approved scope. Explicit user instructions take precedence.

A request to prepare a release does not authorize public publication. If the user requests only a description update, perform the relevant notes preparation, confirmation, update, and verification without changing versions, committing, tagging, or rebuilding assets.

Accept “确认”, “是”, “提交”, “发布”, `yes`, `y`, or `confirm` as confirmation; accept “取消”, “否”, `no`, `n`, or `cancel` as cancellation. For ambiguity, say: “您的回复不明确。请回复‘确认’继续，或回复‘取消’终止。” No reply means pending approval. Stop on cancellation without automatic retries.

## 1. Establish the version and scope

1. Use the target version already supplied by the user. Ask only if it is missing or contradictory. Validate three numeric components and show the version and tag separately in the operation preview.
2. Inspect the branch, remote URL, HEAD, staged changes, unstaged changes, and untracked files. Include hidden directories such as `.agents/skills/` under normal Git rules. Without HEAD, prepare an initial release without treating unavailable history as a fatal error.
3. Check whether the target tag exists locally or remotely. Never force-move, overwrite, or delete an existing tag. For retries, verify that the existing tag points to the same approved commit.
4. Use `git describe --tags --abbrev=0` to find a baseline and verify that it is a relevant release tag. Analyze `LAST_TAG..HEAD` when available, or all history for a first release. Include the actual pending changes, not only previously committed work.
5. Use `git log --pretty=format:'%h|%s|%an' --no-merges <range>` as supporting evidence. Classify prefixes case-insensitively and summarize actual behavior rather than translating commit titles mechanically.

## 2. Prepare versions and release notes

Update the relevant current-version values:

- The default `VERSION` in `scripts/build-app.sh`. Generated `CFBundleShortVersionString` comes from this value or the CI tag; do not treat manual edits inside `dist/` as the source of truth.
- The standalone-executable version fallback in `Sources/MacDuo/ControlPanel.swift`, if still present.
- Current-version badges or text in `README.md` and `README.zh-CN.md`, preserving the English default entry and both language links.
- Current-version examples in `docs/RELEASING.md` and `.github/workflows/release.yml`. Do not replace version references in historical release notes.

Preserve the existing `BUILD_NUMBER` mechanism: local default 1 and the GitHub run number in CI. Do not change the fixed `dev.macduo.app` bundle identifier or signing identity as part of a version bump.

Create `release/X.Y.Z.md`. Summarize user-visible changes in Chinese, merge duplicates, and avoid unsupported claims about hardware compatibility, test coverage, or notarization:

```markdown
# 0.0.1 Release Notes

## ✨ 特性
- [本版本实际新增功能]

## 🐛 问题修复
- 无

## 📋 其他
- [文档、构建或其他实际变更]
```

Use `- 无` when a category has no changes. Release note entries are Chinese; commit messages remain English. Retain the first H1 in the file, but remove it and following leading blank lines when preparing the GitHub description.

## 3. Validate and prepare the release commit

Apply the relevant checks from the [commit skill](../commit/SKILL.md), including `swift test` and a universal app build. Reuse successful checks that cover the final content. Verify bundle version, `lipo -archs` output, bilingual resources, and signature validation. A successful development build does not establish official signing or notarization success.

Check whether the GitHub `release` Environment and the secret names documented for publication are configured. Check names or presence only; never read or print passwords, private keys, or certificate contents. Missing official signing prerequisites block official packaging, not local version and notes preparation. Never substitute ad hoc signing for a release.

Show the complete file list, check results, and English message using this Chinese template:

````markdown
=== 需要确认发布提交 ===

本操作将提交以下文件：
- [逐项列出真实路径及状态]

提交信息：
```text
release: 0.0.1

- update macduo version to 0.0.1
- add release notes for version 0.0.1
```

验证结果：
- [实际结果]

确认创建发布提交吗？请回复“确认”继续，或回复“取消”终止。
````

After approval, stage the exact scope and commit with `git commit -F` as described in the commit skill. Exclude `dist/`, caches, `.local-signing-identity`, and signing materials. If no new commit is needed, show the existing target commit instead of creating an empty release commit.

## 4. Create the tag

Show the exact `vX.Y.Z` tag, full target commit SHA, and commit title:

```text
=== 需要确认创建标签 ===

本操作将创建 Git 标签：vX.Y.Z
目标提交：[完整 SHA 与标题]

确认创建该标签吗？请回复“确认”继续，或回复“取消”终止。
```

After approval, recheck that HEAD matches the target and create the tag, for example with `git tag -a vX.Y.Z <SHA> -m 'MacDuo vX.Y.Z'`. Never use `-f`. Verify that the tag resolves to the approved release commit.

## 5. Push, follow CI, and update the draft

Under the Chinese heading “=== 需要确认发布到远端 ===”, show the current branch, actual remote URL, tag, commit SHA, and notes path. Explain that the push triggers signing, notarization, and draft Release creation. Ask for confirmation to push and update that draft's description; do not describe this as public publication.

After approval:

1. Push only the exact current branch and `vX.Y.Z` tag. Do not force-push or use `--tags` to include unrelated tags. After partial success, inspect remote state before deciding the next step.
2. Identify the `release.yml` run for that tag and commit SHA, then wait for completion. Use bounded waits and meaningful progress updates. Do not select an unrelated latest run. Report pending environment approval without bypassing it.
3. On CI failure, report the failing step and run URL. Preserve the tag and artifacts; do not create replacement tags or delete published assets. Establish the cause and authorization scope before retrying.
4. On success, inspect the matching Release and verify that it is still a draft. Stop the overwrite workflow if it is already public. An explicit request to edit published notes authorizes only that description change, not asset replacement.
5. Remove the first H1 and subsequent leading blank lines from `release/X.Y.Z.md`, write the result to a temporary UTF-8 file, and use `gh release edit vX.Y.Z --notes-file <file>`. Do not interpolate multiline text into shell arguments or substitute automatically generated notes for the version file.
6. Use `gh release view vX.Y.Z --json body,url,assets,isDraft,tagName` to verify that the body matches the prepared text, the tag and draft state are correct, and all required assets exist:
   - `MacDuo-X.Y.Z-universal.zip`
   - `MacDuo-X.Y.Z-universal.dmg`
   - `SHA256SUMS.txt`
7. Download the matching assets into a temporary directory and verify checksums, including coverage of both ZIP and DMG. Verify the extracted app's version, architectures, Developer ID signature, and notarization ticket, plus the DMG signature and ticket. If verification fails, retain the draft and report the failure instead of publishing.

## 6. Publish only within the approved scope

Once the draft and assets pass verification, show the final draft URL, version, notes, and asset verification results. Ask for public-publication confirmation if it has not already been explicitly granted for this version. Do not repeat an existing explicit approval.

Only after authorization and successful verification, run `gh release edit vX.Y.Z --draft=false`. Verify that `isDraft` is false and the tag and assets remain correct. A successful push, CI run, or draft creation is not proof of public publication.

Report the version, commit SHA, tag, workflow URL, Release URL, draft/published state, and outstanding items in Chinese. Identify `release/X.Y.Z.md` as the notes source and accurately disclose failures or unverified results.
