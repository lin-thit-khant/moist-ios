# Rawdea status

Last updated: 2026-11-26. Verify with git before starting work.
Keep this file under 60 lines.

## Repository
- Branch: feature/rawdea-migration. Direction C Batch 0+1: 4674049.
- Lin approved pushing after every batch (2026-11-26). No force-push.
- Latest confirmed pushed code commit: c5a645f.
- Review seed data (supabase/review/) is loaded in the local database.
- .cursor/ is local tool config. Never commit it.

## Done (milestones 1-14, then UI/UX)
- Earlier UI/UX batches 1-10: 48884a4 to 72f9b3f (see git log).
- Direction C Batches 0-1 4674049, 2 28fded8, 3 3e30d5b, 4 7a5afa1, 5 869e7ba,
  6 e6bdec6, 7 61c0559. Direction C is complete.
- Accessibility sweep 421046a: Increase Contrast checked on Home, Discussion, Profile
  and Compose; Welcome, Log in and Sign up checked for Dark Mode and large text.
- App icon 68ea27b: seen on the iOS 27.0 simulator Home Screen.
- Cell loader 5580fdd (F Gather, 1.6 s, 28 pt): Home, Activity and Profile loading
  checked light, dark and largest text; Reduce Motion fade on Home.
- Pull to refresh 4ba8677 (R1, all 12 screens): Home light, dark and Reduce Motion,
  Activity default and largest text, Profile light.
- Home reader layout c5a645f (both feeds, plus critique P2 fixes): default size light
  and dark, largest text light and scrolled dark, tab switching, Project and name taps.
- XCTest suite (29; five grouping tests removed) passed as of c5a645f.

## Standing decisions
- Direction C ("like Threads", with Rawdea's Project signatures).
- Content loading uses RawdeaLoadingIndicator (the logo cell); buttons and actions
  keep the native spinner. No skeletons or shimmer.
- No counts in the feed. No repost or share.
- No AI attribution on commits. No new major backend features planned.

## Direction C rules
- Red only on the Project name, a liked heart and the loader. SF only, no serif.
- Outside Home: 36 pt avatar column, name and time on one line, Project line under.
- Home (replaces the above there): no grouping; avatar header with Project name above
  author and time, options top right, 16 pt text, actions bottom left.

## Next
- Lin: VoiceOver playback pass and Reduce Motion on a device.
- Then App Store preparation. Needs Lin's scope.

## Unverified
- Home reader: VoiceOver, Increase Contrast,
  Reduce Motion, a device, empty and error states, own and hidden posts.
- Pull to refresh on the other 9 screens and iOS 17 (system spinner fallback).
- Cell loader on other screens, Load More, Increase Contrast and a real device.
- VoiceOver playback. Like bounce, haptic and Reduce Motion fade.
- App icon dark and tinted variants not supplied. Not checked on a device.
- Reset password screen. Public "Nothing shared yet" and all-pinned Project states.
- Checked 2026-11-26: owner Project view and post actions, red Project chip,
  rejected post keeps its draft, "Posting…" pill, Project follow toggle.

## Open observations
- Confirmation dialogs show as centred popovers on iOS 27 (native behaviour).
- Publishing from a Project returns to Home.
- Home two-line header: Project name target is under 44 pt (its avatar is 44 pt);
  the author target overlaps the top of the post text. Avatar tints can repeat.
- Critique P1 (header colour and repetition) is not approved.
- Switching the simulator to Dark while the app ran did not update it once; cause unchecked.
- Accessibility audit: author name targets are 36 pt (the 44 pt avatar also opens
  the profile). Post text labels flagged as long.
