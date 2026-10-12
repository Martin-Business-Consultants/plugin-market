# Market, a Runwell plugin — guide for AI agents

This repository is a plugin for Runwell (a Rails 8.1 engine loaded into a Runwell install). It is
not an app on its own: run it from a Runwell checkout with `bin/rails "plugins:link[path]"`.

Read first, in Runwell's repository:
- `docs/plugin-contract.md`: everything a plugin may rely on, with versions. Use nothing else of
  the core's. Raise `requires:` in the manifest to the newest version you use.
- `AGENTS.md`: the core's conventions, which plugin code follows too.

## Rules

- Own your tables, prefixed with the key (`market_*`), pointing at core records by id. Never
  add columns to core tables or write core rows except through core model verbs (a todo is made
  through `engagement.todos` and `record_event!`, as the core does).
- Register everything in `config.to_prepare`, keyed by `:market`. Controllers inherit
  `Market::ApplicationController` (404 while switched off).
- Every controller action declares an authorization rule (`allow_staff`, `require_permission
  :manage_market`) and an `agent_tool`. Reads get a `.json.jbuilder` view with `agent_ref` and a
  `summary`. Write notices an AI can act on.
- Views follow the core's ReActionView rules: strict locals on every partial's first line,
  `<%# herb:key %>` before each loop row, no partials inside `form_with`. ReActionView renders
  `<%= a || tag.span(…) %>` as the span whatever `a` is: write a ternary or an if.
- No query per row: lists load what they show once (`Snapshot.latest_for`, grouped counts);
  the core's N+1 detection runs in tests.
- CSS uses Runwell's design tokens (`docs/theming.md`), in `@layer components`, `market-*`.
- Use only gems Runwell bundles: plugins load outside Bundler.

## This plugin

- `Industry` groups `Profile`s (one per client: industry, website, service area, offerings,
  audience, positioning, goals) and `Competitor`s. `Profile#revise(industry_name:)` finds or
  makes the industry.
- `Competitor` is one per website domain, shared by every client it competes with through
  `Rivalry` (kind: direct, indirect, aspirational; threat: high, medium, low).
- `Watched` (Competitor, Profile): a website read by `Probe` into a `Snapshot`. The probe reads
  the home page and the sitemap from outside: public addresses only, timeouts, size caps, the
  first 5 sitemaps of an index (the counts are then a floor, `partial_sitemap?`). Each part
  fails on its own. `Snapshot.take` keeps the facts and the `differences` from the reading
  before, in plain words (`Snapshot::Changes`). `WeeklyCheckJob` (nightly) queues a `CheckJob`
  for every site not read in 7 days.
- `Plan` (a client's) is drafted in `PlanJob` by the AI plugin's `Ai.structured` (checked with
  `Plan.ai_available_for?`, so the plugin works without it) from `Plan::Brief`. It answers a
  strict schema: summary, positioning, an industry and competitors to check (suggestions, never
  recorded on their own), and `Opportunity`s, which are added unless one with the same title
  exists.
- `Opportunity`: channel, impact, effort, horizon, state (open, planned, done, dismissed).
  `by_priority` is the order everywhere. `plan_as_work` makes the core todo and links it.
  Staff may change only its state; anything else needs `manage_market`.
