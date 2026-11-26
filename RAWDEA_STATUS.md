# Rawdea status

Last updated: 2026-11-26. Verify with git before starting work.
Keep this file under 60 lines.

## Repository
- Branch: feature/rawdea-migration. Direction C Batch 0+1: 4674049.
- Lin approved pushing after every batch (2026-11-26). No force-push.
- Review seed data (supabase/review/) is loaded in the local database.
- .cursor/ is local tool config. Never commit it.

## Done (milestones 1-14, then UI/UX)
- Earlier UI/UX batches 1-10: 48884a4 to 72f9b3f (see git log).
- Direction C Batches 0-1 4674049, 2 28fded8, 3 3e30d5b, 4 7a5afa1, 5 869e7ba,
  6 e6bdec6, 7 61c0559. Direction C is complete.
- Accessibility sweep 421046a: Increase Contrast checked on Home, Discussion, Profile
  and Compose; Welcome, Log in and Sign up checked for Dark Mode and large text.
- XCTest suite (34) passed as of 421046a.

## Standing decisions
- Direction C ("like Threads", with Rawdea's Project signatures).
- Native spinner only, no skeletons. No counts in the feed. No repost or share.
- No AI attribution on commits. No new major backend features planned.

## Direction C rules
- Red only on the Project line and a liked heart. SF only, no serif.
- 36 pt avatar column, name and time on one line, Project line under the name.
  Home joins neighbouring posts of a Project and ends "N more in <Project>".

## Next
- Lin: VoiceOver playback pass and Reduce Motion on a device.
- Then App Store preparation. Needs Lin's scope.

## Unverified
- VoiceOver playback. Like bounce, haptic and Reduce Motion fade.
- Compose "Posting…" pill (too fast to capture), red Project chip, rejected post.
- Reset password screen. Owner view of a Project. Project follow toggle.
- Public "Nothing shared yet" and all-pinned Project states.

## Open observations
- Confirmation dialogs show as centred popovers on iOS 27 (native behaviour).
- Publishing from a Project returns to Home.
- "N more" counts only loaded posts, so it can grow after Load More.
- Accessibility audit: author name targets are 36 pt (the 44 pt avatar also opens
  the profile). Post text labels flagged as long.
