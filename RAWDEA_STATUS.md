# Rawdea status

Last updated: 2026-11-27. Verify with git before starting work.
Keep this file under 60 lines.

## Repository
- Branch: feature/rawdea-migration. Graphify ignored 57e4c03; tool rules: AGENTS.md, Tools.
- Lin approved pushing after every batch (2026-11-26). No force-push.
- Latest code commit: fbc14b9.
- Review seed data (supabase/review/) is loaded locally. Never commit .cursor/.

## Done (milestones 1-14, then UI/UX)
- UI/UX batches 1-10: 48884a4 to 72f9b3f. Direction C 0-7: 4674049 to 61c0559, complete.
- Accessibility sweep 421046a: Increase Contrast on Home, Discussion, Profile, Compose;
  auth screens Dark and large text. App icon 68ea27b: seen on the simulator Home Screen.
- Cell loader 5580fdd and pull to refresh 4ba8677: checked on Home, Activity and Profile
  (not every appearance on each); Home Reduce Motion.
- Home reader c5a645f: default and largest text, light and dark, tabs, Project/name taps.
- Welcome, Log in, Create account 607dbd3: default and largest text, light and dark,
  mode switch, legal link, Forgot password, local email login.
- Project Lab data layer 0b95f6c (hosted database not migrated). Local Supabase tests need
  TEST_RUNNER_RAWDEA_LOCAL_SERVICE_KEY, else skip. Older builds cannot unfollow Projects.
- Project Lab UI part 1 fbc14b9 (Home list, timeline, compose, question): 37 XCTest pass;
  light default and Dark largest text partly checked on the simulator.

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
- Project Lab UI part 2 (prototype Gkq2TXsyMs7N37rMVunFHx): Explore, Activity, Profile,
  Settings, Welcome. New notification types and toggles need a database change first.
- Lin: VoiceOver playback and Reduce Motion on a device. Then App Store preparation.
- Before release: hide or finish the Apple and Google stubs; add Terms and a privacy URL.

## Unverified
- Project Lab: VoiceOver, device, empty/error states, stage menu and failure alert,
  question in Dark or large text and as reader, public profile, new counts clearing.
- Home reader: VoiceOver, Contrast, Motion, device, empty/error, own/hidden posts.
- Pull to refresh: other 9 screens, iOS 17. Cell loader: other screens, Load More, Contrast, device.
- VoiceOver playback. Like bounce, haptic, Reduce Motion fade. Reset password screen.
- App icon dark and tinted variants not supplied. Not checked on a device.
- Auth screens: VoiceOver, Contrast, iOS 17, small phone, device, sign-up submit,
  error/loading states. Some default-dark and scrolled shots predate final tweaks.
- Public "Nothing shared yet" and all-pinned Project states.

## Open observations
- Following with any followed Project hides followed people's posts (All Ideas only).
- iOS 27 shows confirmation dialogs as centred popovers (native). Project publish returns Home.
- Home header: Project name target under 44 pt (avatar is 44); author target overlaps
  post text; tints can repeat. Critique P1 (header colour, repetition) not approved.
- Switching the simulator to Dark while the app ran did not update it once; cause unchecked.
- Accessibility audit: author name targets are 36 pt (the 44 pt avatar also opens
  the profile). Post text labels flagged as long.
