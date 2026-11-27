# Rawdea status

Last updated: 2026-11-27. Verify with git before starting work.
Keep this file under 60 lines.

## Repository
- Branch: feature/rawdea-migration. Graphify ignored 57e4c03; tool rules: AGENTS.md, Tools.
- Lin approved pushing after every batch (2026-11-26). No force-push.
- Latest code commit: 8f2e19b. Review data: seed_project_lab.sql (474b2d6).
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
- Following switch 2a04467; part 2 debee19 (Explore, profile, settings, welcome, Activity):
  39 XCTest pass; light default and Dark largest text partly checked on the simulator.

- Prototype 1:1 part 1 8f2e19b (style, tab bar, Home, Project, description migration):
  40 XCTest pass; partly checked on the simulator, light and Dark.

## Standing decisions
- 1:1 with prototype Gkq2TXsyMs7N37rMVunFHx (2026-11-27): show counts; system font; darker
  grey; keep the Following switch; no Apple sign-in, Share links or Terms until real.
- Content loading uses RawdeaLoadingIndicator (the logo cell); buttons and actions
  keep the native spinner. No skeletons or shimmer.
- No repost. No AI attribution.
- Google sign-in parked (2026-11-27). Welcome follows Thread style (Project Lab).

## Next (implementation needs Lin's approval)
- 1:1 part 2: Compose, Question, Explore, Activity, Profile (remove Share), Settings
  (Password), Welcome (remove Terms wording), stage rows in the Home feed.
- Lin: VoiceOver playback and Reduce Motion on a device. Then App Store preparation.
- Welcome hides the Apple and Google stubs.
- Before release: add Terms and a privacy URL.

## Unverified
- 1:1 part 1: People and About tabs, description editing, long-press post actions
  (timeline rows have no visible buttons).
- Project Lab: VoiceOver, device, empty/error states, stage menu and failure alert,
  question in Dark or large text and as reader, new counts clearing, Share sheet.
- Home reader: VoiceOver, Contrast, Motion, device, empty/error, own/hidden posts.
- Pull to refresh: other 9 screens, iOS 17. Cell loader: other screens, Load More, Contrast, device.
- VoiceOver playback. Like bounce, haptic, Reduce Motion fade. Reset password screen.
- App icon dark and tinted variants not supplied. Not checked on a device.
- Auth screens: VoiceOver, Contrast, iOS 17, small phone, device, sign-up submit,
  error/loading states. Some default-dark and scrolled shots predate final tweaks.
- Public "Nothing shared yet" and all-pinned Project states.

## Open observations
- Explore looks at the newest 100 posts; Home makes one request per followed Project.
- iOS 27 shows confirmation dialogs as centred popovers (native). Project publish returns Home.
- Home header: Project name target under 44 pt (avatar is 44); author target overlaps
  post text; tints can repeat. Critique P1 (header colour, repetition) not approved.
- Switching the simulator to Dark while the app ran did not update it once; cause unchecked.
- Accessibility audit: author name targets are 36 pt (the 44 pt avatar also opens
  the profile). Post text labels flagged as long.
