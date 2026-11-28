# Rawdea status

Last updated: 2026-11-28. Verify with git before starting work. Keep this file under 60 lines.
## Repository
- Branch: feature/rawdea-migration. Graphify ignored 57e4c03; tool rules: AGENTS.md, Tools.
- Lin approved pushing after every batch (2026-11-26). No force-push. Never commit .cursor/.
- Latest code and confirmed pushed commit: f599bd7. Local review data: seed_project_lab.sql.
## Done (verification gaps are under Unverified)
- Milestones 1-14. UI/UX batches 1-10 48884a4 to 72f9b3f; Direction C 0-7 4674049 to 61c0559.
- Accessibility 421046a, icon 68ea27b, cell loader 5580fdd, pull to refresh 4ba8677, Home
  reader c5a645f, auth screens 607dbd3.
- Project Lab data 0b95f6c (hosted database not migrated; older builds cannot unfollow
  Projects; local Supabase tests need TEST_RUNNER_RAWDEA_LOCAL_SERVICE_KEY, else skip),
  UI fbc14b9, Following switch 2a04467, part 2 debee19.
- Prototype 1:1 8f2e19b and 1b4594b; gaps closed 4277017. Like animation b0f184a.
- Stage motion e1980d5, 4d7192b, c7f1229, 5a50611 (Shipped checked: 1/8/50 posts,
  interruption, Reduce Motion).
- Audit fixes 2baadee (follow-once migration local only; Followers list; usernames).
- Guideline 1.2 option A f599bd7: moderator entry in Settings, terms tick at sign-up, release
  check (TEST_RUNNER_RAWDEA_RELEASE_CHECK=1; fails until set). 68 XCTest, 1 skipped.
## Standing decisions
- 1:1 with prototype Gkq2TXsyMs7N37rMVunFHx (2026-11-27): show counts; system font; darker
  grey; keep the Following switch; no Apple sign-in, Share links or Terms link until real.
- Project timeline posts have no visible buttons (option A); actions on long-press.
- Content loading uses RawdeaLoadingIndicator (the logo cell); buttons and actions keep the
  native spinner. No skeletons or shimmer.
- No repost. No AI attribution. Google sign-in parked (2026-11-27).
- Welcome follows Thread style, hides Apple and Google stubs. No growing Early stage dot.
## Next (implementation needs Lin's approval)
- Lin: VoiceOver playback, Reduce Motion and Like haptic on a device. Then App Store prep.
- Release blockers (Lin sets them last): contact email, support, privacy and Terms URLs empty;
  hosted moderator row needs an admin. Terms tick is app-only, not recorded on the server.
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
- Guideline 1.2: VoiceOver, account creation, report actions, inbox replies, Resolved list,
  failed moderator check, tick reset on mode switch, live Terms link. No waiting-count badges.
- Stage motion: haptics, Contrast, large counts, sweep in dark or largest text, final Reduce
  Motion list change, every-open dots (Reduce Motion, dark, large), snake backgrounded.
  Shipped: haptics, Contrast, from Early, leaving Shipped, change made from Compose.
## Open observations
- Moderation: old grey style; queue titled "Moderation"; inbox tab change during a load is
  ignored (from code). Inline guidelines link is under 44 pt.
- Home stage rows show Shipped as a white last segment, unlike the page. Burmese in simulator
  languages loosens line spacing. Home makes one request per followed Project.
- Early dots replay returning to a Home-opened Project (ProjectRouteView rebuilds); haptics
  uncapped; white current stage faint in light; 50-dot snake never settles.
- Home and Timeline can say Answered when the best answerer is blocked. Explore: newest 100.
- Largest text: Like heart touches the count; detail Like count stays grey (feed crimson). One
  Dark switch did not update the app. iOS 27 confirmations are popovers. Publish returns Home.
- Home header: Project name target under 44 pt; author target overlaps post text; tints can
  repeat (critique P1 not approved). Author targets 36 pt. Post text labels long.
