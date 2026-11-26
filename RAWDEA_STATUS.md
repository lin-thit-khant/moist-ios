# Rawdea status

Last updated: 2026-11-26. Verify with git before starting work.
Keep this file under 60 lines.

## Repository
- Branch: feature/rawdea-migration. Latest pushed commit: 72f9b3f.
- Uncommitted, awaiting Lin's screenshot review: Direction C Batch 0 and 1
  (monochrome tint and buttons, avatar tint by user id, 10 Swift files, supabase/review/).
  Review seed data is loaded in the local database.
  Screenshots: ~/Desktop/Rawdea-UI-Reviews/direction-c-batch-0-1/.
- .cursor/ is local tool config. Never commit it.

## Done (milestones 1-14, then UI/UX)
- Batch 1 Home visuals 48884a4. Batch 2 Home experience e540c83 (committed first).
- Batch 3 Profile 53c7016, 44ce58e, cda53ab.
- Batch 4A Project e2ce076. Copy fixes 59c9c25. 4B owner actions db3710b.
- Batch 5 Compose 3b0fca1. Batch 6 Explore 9e7d69d. Batch 7 Discussion b6368f4.
- Batch 8 Activity and Saved fd84c99. Display-name wrap 881dc8f.
- Batch 9 Authentication: reviewed, no changes.
- Batch 10 partial: profile-load retry 72f9b3f, Profile checked in Dark Mode.
- 29 XCTests passed as of 72f9b3f.

## Standing decisions
- Direction C ("like Threads", with Rawdea's Project signatures).
- Native spinner only, no skeletons. No counts in the feed. No repost or share.
- No AI attribution on commits. No new major backend features planned.

## Next
- Review Direction C Batch 0 and 1. Later batches need approval.
- Roadmap 10 remaining: VoiceOver pass, Dark Mode on Project, Discussion and Compose,
  Increase Contrast.

## Unverified
- VoiceOver playback. Dark Mode across newer states. Follow toggles.
- Public "Nothing shared yet" and all-pinned Project states.

## Open observations
- Confirmation dialogs show as centred popovers on iOS 27 (native behaviour).
- Publishing from a Project returns to Home.
