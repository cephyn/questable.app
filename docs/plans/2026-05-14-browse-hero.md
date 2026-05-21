# Browse Hero Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace the public browse page's generic welcome banner with a responsive, polished hero that uses existing brand assets more cleanly and reduces the visual weight of the app-bar logo.

**Architecture:** Keep the change local to the public browsing surface by replacing `_buildWelcomeBanner` in the public list view with a responsive hero widget and lightly tightening the shared branding widget used by the app bar. Preserve existing auth actions and asset usage so the update is visual/layout-only and can be validated with focused UI checks.

**Tech Stack:** Flutter, Material 3, existing asset pipeline, Firebase Hosting preview deploy

---

### Task 1: Baseline The Existing Browse Header

**Files:**
- Modify: `lib/src/quest_card/public_quest_card_list_view.dart`
- Modify: `lib/src/widgets/branding.dart`

**Step 1: Inspect the current welcome banner and branding widget**

Review the current `_buildWelcomeBanner` implementation and the app-bar branding widget.

**Step 2: Verify current validation baseline**

Run: `flutter analyze lib/src/quest_card/public_quest_card_list_view.dart lib/src/widgets/branding.dart`
Expected: no new errors in these files before editing

**Step 3: Commit checkpoint**

No commit yet; this task is baseline only.

### Task 2: Add A Responsive Browse Hero

**Files:**
- Modify: `lib/src/quest_card/public_quest_card_list_view.dart`
- Test: `test/` existing Flutter test suite

**Step 1: Add a small layout helper for responsive hero composition**

Implement a helper that switches between stacked and split layout using available width.

**Step 2: Replace `_buildWelcomeBanner` with a hero card**

Include:
- eyebrow label using the Questable brand name
- stronger browse/discovery headline
- supporting copy reused from the current banner
- `Sign In` and `Create Account` actions using existing auth helpers
- framed `samples/questable_concept.png` artwork with constrained height and rounded corners

**Step 3: Keep mobile behavior compact**

Ensure the stacked layout places copy/actions before the artwork and limits visual height.

**Step 4: Run focused analysis**

Run: `flutter analyze lib/src/quest_card/public_quest_card_list_view.dart`
Expected: PASS with no new issues

**Step 5: Commit**

```bash
git add lib/src/quest_card/public_quest_card_list_view.dart
git commit -m "feat: add responsive browse hero"
```

### Task 3: Reduce App-Bar Branding Weight

**Files:**
- Modify: `lib/src/widgets/branding.dart`

**Step 1: Tighten the branding widget**

Reduce logo height, refine spacing, and keep title text aligned with the lighter visual treatment.

**Step 2: Run focused analysis**

Run: `flutter analyze lib/src/widgets/branding.dart`
Expected: PASS with no new issues

**Step 3: Commit**

```bash
git add lib/src/widgets/branding.dart
git commit -m "refactor: soften app bar branding"
```

### Task 4: Validate The UI End-To-End

**Files:**
- Modify: `lib/src/quest_card/public_quest_card_list_view.dart`
- Modify: `lib/src/widgets/branding.dart`
- Test: `test/`

**Step 1: Run the Flutter test suite**

Run: `flutter test`
Expected: PASS

**Step 2: Run focused analysis on both touched files**

Run: `flutter analyze lib/src/quest_card/public_quest_card_list_view.dart lib/src/widgets/branding.dart`
Expected: PASS with no new issues

**Step 3: Build web output**

Run: `flutter build web --no-tree-shake-icons`
Expected: PASS and refreshed output in `build/web`

**Step 4: Deploy preview for visual review**

Run: `firebase hosting:channel:deploy ui_preview --project quest-cards-3c47a`
Expected: PASS and a fresh preview URL

**Step 5: Commit**

```bash
git add lib/src/quest_card/public_quest_card_list_view.dart lib/src/widgets/branding.dart
git commit -m "feat: refresh browse page hero"
```