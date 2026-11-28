# Rawdea status

Last updated: 2026-11-28. Verify with git before starting work. Keep this file under 60 lines.
## Repository
- Branch: feature/rawdea-migration. Graphify ignored 57e4c03; tool rules: AGENTS.md, Tools.
- Lin approved pushing after every batch (2026-11-26). No force-push. Never commit .cursor/.
- Latest code and confirmed pushed commit: 5a50611. Local review data: seed_project_lab.sql.
## Done (verification gaps are under Unverified)
- Milestones 1-14. UI/UX batches 1-10 48884a4 to 72f9b3f; Direction C 0-7 4674049 to 61c0559.
- Accessibility 421046a, icon 68ea27b, cell loader 5580fdd, pull to refresh 4ba8677, Home
  reader c5a645f, auth screens 607dbd3.
- Project Lab data 0b95f6c (hosted database not migrated; older builds cannot unfollow
  Projects; local Supabase tests need TEST_RUNNER_RAWDEA_LOCAL_SERVICE_KEY, else skip),
  UI fbc14b9, Following switch 2a04467, part 2 debee19.
- Prototype 1:1 8f2e19b and 1b4594b; gaps closed 4277017. Like animation b0f184a.
- Stage sweep and Early dots e1980d5; dots on every open 4d7192b; In progress glow and snake
  c7f1229. Shipped animation 5a50611: 65 XCTest pass; 1/8/50 posts, interruption, Reduce Motion.
- Audit fixes 2baadee (follow-once migration, local only; Followers list; usernames):
  56 XCTest pass; main fixes checked, light default and light largest text.
## Standing decisions
- 1:1 with prototype Gkq2TXsyMs7N37rMVunFHx (2026-11-27): show counts; system font; darker
  grey; keep the Following switch; no Apple sign-in, Share links or Terms until real.
- Project timeline posts have no visible buttons (option A); actions on long-press.
- Content loading uses RawdeaLoadingIndicator (the logo cell); buttons and actions keep the
  native spinner. No skeletons or shimmer.
- No repost. No AI attribution.
- Google sign-in parked (2026-11-27). Welcome follows Thread style (Project Lab) and hides
  the Apple and Google stubs. Early dots have no growing stage dot (removed by Lin).
## Next (implementation needs Lin's approval)
- Lin: VoiceOver playback, Reduce Motion and Like haptic on a device. Then App Store prep.
- Release blockers (Lin sets them last): placeholder contact email and privacy URL; no Terms.
## Unverified (device and VoiceOver: unchecked everywhere)
- Prototype parity: largest text in light, Following stage rows. 1:1 part 1: People and About
  tabs, description editing, long-press post actions.
- Project Lab: empty/error states, stage menu failure alert, question in Dark or large text
  and as reader, new counts clearing, Share sheet.
- Home reader: Contrast, Motion, empty/error, own/hidden posts. Pull to refresh: other 9
  screens, iOS 17. Cell loader: other screens, Load More, Contrast.
- Auth: Contrast, iOS 17, small phone, sign-up submit, error/loading states, Reset password;
  some default-dark and scrolled shots predate final tweaks.
- Like: haptic, failed like, light largest text, rows outside Home and detail.
- App icon dark/tinted not supplied. All-pinned Project. Audit: Move to Project, appeals text.
- Stage motion: haptics, Contrast, large counts, sweep in dark or largest text, final Reduce
  Motion list change, every-open dots (Reduce Motion, dark, large), snake backgrounded.
- Shipped: haptics, Contrast, from Early, leaving Shipped, change made from Compose.
## Open observations
- Home stage rows show Shipped as a white last segment, unlike the joined line on the page.
- Simulator languages include Burmese, which loosens line spacing; compare with English.
- Early dots replay when returning to a Home-opened Project (ProjectRouteView rebuilds).
- Early dot haptics uncapped; white current stage faint in light; 50-dot snake never settles.
- Home and Timeline can still say Answered when the best answerer is blocked.
- Largest text: Like heart briefly touches the count. Detail Like count stays grey while the
  feed count turns crimson. Switching the simulator to Dark once did not update the app.
- Explore looks at the newest 100 posts; Home makes one request per followed Project.
- iOS 27 shows confirmation dialogs as centred popovers (native). Project publish returns Home.
- Home header: Project name target under 44 pt; author target overlaps post text; tints can
  repeat (critique P1 not approved). Author name targets 36 pt. Post text labels long.
