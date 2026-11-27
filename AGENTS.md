# Rawdea

Calm, reading-first, project-centered social app. SwiftUI + Supabase.
Branch: feature/rawdea-migration. Project Rawdea.xcodeproj, scheme Rawdea, config Local.
The Moist folder name is historical. Do not rename it.

## Start
- Run `git status` and `git log -3`. Never discard or stage work you did not make.
- Read RAWDEA_STATUS.md. One batch per session.

## Map
- Moist/App: RawdeaApp.swift
- Moist/Views/<Feature>: Authentication, Home, Profile, Projects, Discovery,
  Following, Notifications, Moderation, Settings, Appearance, Navigation
- Navigation: RawdeaMainTabView.swift, RawdeaPostNavigationStack.swift
- Moist/ViewModels, Moist/Services, Moist/Models: logic, backend calls, data
- Moist/DesignSystem: RawdeaPalette, RawdeaTypography, RawdeaComponents
- RawdeaTests: XCTest. supabase/migrations: schema and RLS
- New Swift files need no pbxproj edit.

## Rules
- Reuse existing components. No new dependencies. Keep scope tight.
- Content loading: RawdeaLoadingIndicator. Buttons and actions: native ProgressView.
- Pull to refresh: rawdeaRefreshable, never plain refreshable.
- 44 pt targets, Dynamic Type, VoiceOver, Light/Dark, Increase Contrast, Reduce Motion.
- Local Supabase only (http://127.0.0.1:54321). Remove only your own fixtures.
  Never weaken Auth, RLS or moderation. Never print keys.
- Leave existing concurrency warnings.
- Commit and push only with Lin's approval. No AI attribution. Stage by path.

## Tools
- Graphify: query the code graph before broad file reads, and verify results against code
  (about 16% of edges are inferred; results cap near 20 nodes). It does not cover
  supabase/*.sql. After each batch run `~/.local/bin/graphify update .`
  (graphify-out/ is gitignored).
- Ponytail (~/.claude/skills): /ponytail-review after big batches, /ponytail-debt before
  App Store prep. Keep /ponytail mode off for design and prototype work.
- Appllama MCP: design research only, 1 credit per call. Study patterns; never copy an
  app's look or features.
- Design skills: critique for UX reviews, prototype for prototype-first design.

## Efficient work
- Search first, then read only the needed line ranges. Do not re-read unchanged files.
- Send xcodebuild output to a log file and print only errors and the summary.
- Build while iterating. Run all tests once before the report, and again after any fix.
- Screenshots: view each once, using a half-size copy (`sips -Z 1311 in.png --out small.png`).
  Use full size to judge fine detail. Check text and element presence with RocketSim elements.
- Sign in: `python3 ~/.config/rawdea/signin.py`. Tests shut the simulator down,
  so boot it and reinstall the app first.
