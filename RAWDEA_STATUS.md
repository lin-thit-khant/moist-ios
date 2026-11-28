# Rawdea status

Last updated: 2026-11-28. Verify with git before starting work.
Keep this file under 60 lines.

## Repository
- Branch: feature/rawdea-migration. Graphify ignored 57e4c03; tool rules: AGENTS.md, Tools.
- Lin approved pushing after every batch (2026-11-26). No force-push.
- Latest code commit: 4d7192b. Latest confirmed pushed commit: 4d7192b.
- Review data: seed_project_lab.sql.
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

- Prototype 1:1 part 2 1b4594b (other screens, Home stage rows, Password): 44 XCTest pass;
  checked on the simulator in light, default size.

- Prototype gaps closed 4277017 (answer likes, usernames, removed extras, appearance follows
  the system): 45 XCTest pass; light default, Dark and largest text partly checked.
- Like animation b0f184a (Classic pop, approved): 45 XCTest pass; feed and detail checked
  by simulator recordings; dark and largest text predate the last Reduce Motion/count edit.
- Stage sweep and Early dots e1980d5: 49 XCTest pass on the committed files; dots and sweep
  recorded in the simulator, partly in dark, largest text and Reduce Motion.

## Standing decisions
- 1:1 with prototype Gkq2TXsyMs7N37rMVunFHx (2026-11-27): show counts; system font; darker
  grey; keep the Following switch; no Apple sign-in, Share links or Terms until real.
- Project timeline posts have no visible buttons (option A); actions on long-press.
- Content loading uses RawdeaLoadingIndicator (the logo cell); buttons and actions
  keep the native spinner. No skeletons or shimmer.
- No repost. No AI attribution.
- Google sign-in parked (2026-11-27). Welcome follows Thread style (Project Lab).

## Next (implementation needs Lin's approval)
- Lin: VoiceOver playback, Reduce Motion and Like haptic on a device. Then App Store prep.
- Early dots: no growing stage dot (removed by Lin); haptics are not capped for many posts.
- Early dots replay when returning to a Home-opened Project (ProjectRouteView rebuilds).
- Welcome hides the Apple and Google stubs.
- Before release: add Terms and a privacy URL.

## Unverified
- Prototype parity: VoiceOver, device, largest text in light, Following stage rows.
- Simulator languages include Burmese, which loosens line spacing; compare with English.
- 1:1 part 1: People and About tabs, description editing, long-press post actions
  (timeline rows have no visible buttons).
- Project Lab: VoiceOver, device, empty/error states, stage menu and failure alert,
  question in Dark or large text and as reader, new counts clearing, Share sheet.
- Home reader: VoiceOver, Contrast, Motion, device, empty/error, own/hidden posts.
- Pull to refresh: other 9 screens, iOS 17. Cell loader: other screens, Load More, Contrast, device.
- VoiceOver playback. Reset password screen.
- Like: haptic, device, failed like, light largest text, rows outside Home and detail.
- App icon dark and tinted variants not supplied. Not checked on a device.
- Auth screens: VoiceOver, Contrast, iOS 17, small phone, device, sign-up submit,
  error/loading states. Some default-dark and scrolled shots predate final tweaks.
- Public "Nothing shared yet" and all-pinned Project states.
- Early dots on every open (4d7192b, 48 XCTest pass): Reduce Motion, dark and large text not
  rechecked.
- Stage motion: haptics, VoiceOver, device, Contrast, large counts, sweep in dark or largest
  text, final Reduce Motion list change. White current stage is faint in light.
- Largest text: heart briefly touches the count; stage pill overflows; username wraps
  mid-word. Post detail Like count stays grey while the feed count turns crimson.

## Open observations
- Explore looks at the newest 100 posts; Home makes one request per followed Project.
- iOS 27 shows confirmation dialogs as centred popovers (native). Project publish returns Home.
- Home header: Project name target under 44 pt (avatar is 44); author target overlaps
  post text; tints can repeat. Critique P1 (header colour, repetition) not approved.
- Switching the simulator to Dark while the app ran did not update it once; cause unchecked.
- Accessibility audit: author name targets are 36 pt (the 44 pt avatar also opens
  the profile). Post text labels flagged as long.
