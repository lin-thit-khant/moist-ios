# Rawdea status

Last updated: 2026-11-27. Verify with git before starting work.
Keep this file under 60 lines.

## Repository
- Branch: feature/rawdea-migration. Graphify ignored 57e4c03; tool rules: AGENTS.md, Tools.
- Lin approved pushing after every batch (2026-11-26). No force-push.
- Latest confirmed pushed code commit: 607dbd3.
- Review seed data (supabase/review/) is loaded locally. Never commit .cursor/.

## Done (milestones 1-14, then UI/UX)
- UI/UX batches 1-10: 48884a4 to 72f9b3f. Direction C 0-7: 4674049 to 61c0559, complete.
- Accessibility sweep 421046a: Increase Contrast checked on Home, Discussion, Profile
  and Compose; Welcome, Log in and Sign up checked for Dark Mode and large text.
- App icon 68ea27b: seen on the iOS 27.0 simulator Home Screen.
- Cell loader 5580fdd (F Gather, 1.6 s, 28 pt): Home, Activity and Profile loading
  checked light, dark and largest text; Reduce Motion fade on Home.
- Pull to refresh 4ba8677 (R1, all 12 screens): Home light, dark and Reduce Motion,
  Activity default and largest text, Profile light.
- Home reader layout c5a645f (both feeds, plus critique P2 fixes): default size light
  and dark, largest text light and scrolled dark, tab switching, Project and name taps.
- Welcome, Log in, Create account 607dbd3 (auth "Index" style): default and largest
  text, light and dark; mode switch, legal link, Forgot password, local email login.
- XCTest suite (29) passed on the 607dbd3 changes.

- Project Lab batch 1, data layer 0b95f6c (local, not pushed; hosted database not migrated):
  33 XCTest pass including local Supabase tests (need TEST_RUNNER_RAWDEA_LOCAL_SERVICE_KEY,
  otherwise skipped). Builds from before this migration cannot unfollow or count followers.

## Standing decisions
- Direction C ("like Threads", with Rawdea's Project signatures).
- Content loading uses RawdeaLoadingIndicator (the logo cell); buttons and actions
  keep the native spinner. No skeletons or shimmer.
- No counts in the feed, repost or share. No AI attribution. No new major backend features.
- Google sign-in parked (2026-11-27). Green is for signed-out screens only.

## Direction C rules
- Signed in: red only on the Project name, a liked heart and the loader. SF only, no serif.
- Outside Home: 36 pt avatar column, name and time on one line, Project line under.
- Home (replaces the above there): no grouping; avatar header with Project name above
  author and time, options top right, 16 pt text, actions bottom left.

## Next (implementation needs Lin's approval)
- Project Lab batch 2, UI in Thread style (prototype Gkq2TXsyMs7N37rMVunFHx): Home
  (Following default: Project list), Project timeline, Compose, Question, Explore,
  Activity, Profile, Settings, Welcome. "Remove from Project" now means the default
  "General" Project.
- Lin: VoiceOver playback and Reduce Motion on a device. Then App Store preparation.
- Before release: hide or finish the Apple and Google stubs; add Terms and a privacy URL.

## Unverified
- Home reader: VoiceOver, Contrast, Motion, device, empty/error, own/hidden posts.
- Pull to refresh: other 9 screens, iOS 17. Cell loader: other screens, Load More, Contrast, device.
- VoiceOver playback. Like bounce, haptic, Reduce Motion fade. Reset password screen.
- App icon dark and tinted variants not supplied. Not checked on a device.
- Auth screens: VoiceOver, Contrast, iOS 17, small phone, device, sign-up submit,
  error/loading states. Some default-dark and scrolled shots predate final tweaks.
- Public "Nothing shared yet" and all-pinned Project states. Checked 2026-11-26: owner Project view and post actions, red Project chip,
  rejected post keeps its draft, "Posting…" pill, Project follow toggle.

## Open observations
- iOS 27 shows confirmation dialogs as centred popovers (native). Project publish returns Home.
- Home header: Project name target under 44 pt (avatar is 44); author target overlaps
  post text; tints can repeat. Critique P1 (header colour, repetition) not approved.
- Switching the simulator to Dark while the app ran did not update it once; cause unchecked.
- Accessibility audit: author name targets are 36 pt (the 44 pt avatar also opens
  the profile). Post text labels flagged as long.
