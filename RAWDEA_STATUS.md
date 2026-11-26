# Rawdea status

Last updated: 2026-11-26. Verify with git before starting work.
Keep this file under 60 lines.

## Repository
- Branch: feature/rawdea-migration. Direction C Batch 0+1: 4674049.
- Lin approved pushing after every batch (2026-11-26). No force-push.
- Review seed data (supabase/review/) is loaded in the local database.
- .cursor/ is local tool config. Never commit it.

## Done (milestones 1-14, then UI/UX)
- Batch 1 Home visuals 48884a4. Batch 2 Home experience e540c83 (committed first).
- Batch 3 Profile 53c7016, 44ce58e, cda53ab.
- Batch 4A Project e2ce076. Copy fixes 59c9c25. 4B owner actions db3710b.
- Batch 5 Compose 3b0fca1. Batch 6 Explore 9e7d69d. Batch 7 Discussion b6368f4.
- Batch 8 Activity and Saved fd84c99. Display-name wrap 881dc8f.
- Batch 9 Authentication: reviewed, no changes.
- Batch 10 partial: profile-load retry 72f9b3f, Profile checked in Dark Mode.
- Direction C Batch 0 review content + Batch 1 monochrome foundations 4674049.
- Direction C Batch 2 post row 28fded8.
- Direction C Batch 3 Home 3e30d5b. Re-tap scroll is native.
- Direction C Batch 4 Compose 7a5afa1.
- Direction C Batch 5 Discussion thread 869e7ba.
- Direction C Batch 6 Profile and Project pages e6bdec6. Account follow toggle checked.
- XCTest suite (34) passed as of e6bdec6.

## Standing decisions
- Direction C ("like Threads", with Rawdea's Project signatures).
- Native spinner only, no skeletons. No counts in the feed. No repost or share.
- No AI attribution on commits. No new major backend features planned.

## Direction C plan (each batch needs approval)
- Red only on the Project line and a liked heart. SF only, no serif.
- Posts: 32-36 pt avatar column, name + time on one line, Project line under the name.
  Thread line joins consecutive posts in the same Project, ending "N more in <Project>".
- 2 Post row + like pop (symbolEffect .bounce, sensoryFeedback, Reduce Motion fade).
- 3 Home: wordmark token, tabs, Project thread grouping (FeedViewModel), Home re-tap scrolls up.
- 4 Compose: full-height sheet, keyboard up, Project chip; "Posting…" pill, "Posted" only after server OK.
- 5 Discussion as a thread. 6 Profile and Project pages, compact Follow pill.
- 7 Post options sheet; Reduce Motion, Dynamic Type, VoiceOver sweep.

## Next
- Direction C Batch 7: post options sheet; Reduce Motion, Dynamic Type, VoiceOver sweep.
  Red remains in auth, Activity, Appearance preview and design preview.
- Roadmap 10 remaining: VoiceOver pass, Dark Mode on Project, Discussion and Compose,
  Increase Contrast.

## Unverified
- Compose "Posting…" pill (too fast to capture), red Project chip, rejected post.
- Batch 1-6 Increase Contrast and VoiceOver. Like bounce, haptic, Reduce Motion fade.
- VoiceOver playback. Dark Mode across newer states. Project follow toggle.
- Owner view of a Project (test account owns none).
- Public "Nothing shared yet" and all-pinned Project states.

## Open observations
- Confirmation dialogs show as centred popovers on iOS 27 (native behaviour).
- Publishing from a Project returns to Home.
- Dragging down on a screen with a similar post=nil reload may need the same
  unstructured-task fix.
- "N more" counts only loaded posts, so it can grow after Load More.
