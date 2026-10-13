> **Archived.** Market is now a Libre Publish plugin: [cms-market](https://github.com/Martin-Business-Consultants/cms-market). This Runwell version isn't maintained; don't install it (and never into Libre Publish).

# Market

A plugin for [Runwell](https://github.com/Martin-Business-Consultants/runwellv2): the big picture
behind every client's SEO and marketing, so the work you plan wins their market rather than
filling a month.

- **Industries** group clients and the competitors they share. See a market whole, and plan
  for one client what worked for another in the same industry. NAICS codes optional.
- **Competitors** are watched once, however many clients they compete with. Each one's website
  is read from outside, like any visitor would, and read again every week. Each reading records:
  - pages, posts (and how many in the last 90 days), location and service pages, and when the
    site last changed, all from its sitemap;
  - what its home page runs: Google Ads, the Meta, TikTok, LinkedIn and Microsoft tags,
    Analytics, Tag Manager, call tracking, chat, a reviews widget, online booking, email signup
    and a consent banner;
  - its title, main heading, platform, structured data, social profiles and phone numbers.

  What changed since the last reading is kept: "Now runs Google Ads", "+12 location pages".
- **Each client's market** has a profile, a comparison and a plan:
  - The profile: industry, website, where and whom they serve, what they sell, how they want to
    be seen, and what they're after.
  - The comparison: their own site against each competitor, which is marked direct, indirect or
    aspirational, with a threat level.
  - **The plan**, drafted by the [AI plugin](https://github.com/Martin-Business-Consultants/runwell-ai)
    from all of the above. It gives the state of the market, the angle to win on, an industry
    and competitors worth checking, and **opportunities**. Each opportunity has a channel
    (search, local, content, paid, social, email, reviews, the website's conversion, brand,
    partnerships), an impact, an effort and a horizon, and the evidence for it.
- **Search data from [DataForSEO](https://dataforseo.com)**, on your own account (Settings › Market). Each pull covers the client's site and every competitor's:
  - visibility: keywords in the top 3, 10 and 20, estimated monthly traffic and paid keywords, compared with the pull before;
  - the keywords each site ranks for, by search volume;
  - the sites that share the client's keywords but aren't watched yet;
  - backlinks, if you have DataForSEO's Backlinks subscription;
  - where everyone ranks for the searches you track, checked from the client's own city.

  Pulls run when someone asks, or every week or month. Spending is capped: every request is checked first against the month's budget and refused if it could go over, and every request is kept with its cost. Errors that may pass (timeouts, rate limits, DataForSEO's "try again") are retried with backoff. A wrong login, an empty account or a spent budget stops the pull and keeps what it already got. A part pulled in the last day isn't bought again.
- **Findings** say what all of this data means, with the exact figures and where they came from. Kinds include:
  - search: keywords a competitor is on page one for and the client isn't; search traffic falling, or a competitor's surging; tracked searches dropping, competitors outranking, a map pack on the page; sites competing in search that aren't watched; competitors with far more sites linking to them;
  - websites: competitors running search ads, with a page for each place they serve, or publishing while the client doesn't, or offering booking and chat;
  - housekeeping: profile gaps, and data going stale.

  Each finding has a stable key and is kept while it holds: `changed_at` moves when it appears, changes or comes back, and it's resolved when it stops holding. Dismiss one and it stays dismissed while it holds. Findings are worked out again after every reading and pull, and every night.
- **Opportunities** are listed best first (most impact for least effort, then soonest), per
  client and across every client, by channel and industry. One click plans one as work: a
  Runwell todo on one of the client's open engagements, linking back. Or mark it done, or
  dismiss it.
- **The overview** gives the whole portfolio at a glance:
  - industries and who's in them;
  - the best open opportunities;
  - what competitors changed in the last 30 days;
  - the clients whose market isn't mapped yet.

The AI plugin drafts plans from all of it, findings first. A plan can suggest an industry, competitors and searches to track, and the client's page in Runwell's Ask panel gets two one-click questions. Nothing is recorded from AI without a person. Suggested industries and competitors are leads to
check, taken in one click. Rankings, traffic, review counts and ad spend aren't read, and plans
are told not to claim them.

## For agents and a local harness

Runwell's `runwell` CLI turns every tool into a command (`curl -fsSL https://your-install/install/cli | sh`, then `runwell login`), so a harness on your machine can reason over the same data. Clients can be named instead of numbered:

    runwell list_market_findings --json                          # every open finding, worst first, with evidence and sources
    runwell list_market_findings --since 2026-10-12T09:00:00Z    # only what appeared, changed, resolved or was dismissed since
    runwell list_market_findings --field as_of                   # keep this; pass it as --since next time
    runwell show_client_market --id "Harbor Dental"              # profile, competitors, readings, findings, plan, opportunities
    runwell show_market_search --client_id "Harbor Dental" --keywords 500
    runwell track_market_keywords --client_id "Harbor Dental" --keyword.keywords "dentist grand rapids"
    runwell pull_market_search --client_id "Harbor Dental"       # spends from the month's budget
    runwell add_market_opportunity --client_id "Harbor Dental" --opportunity.title "…" --opportunity.evidence "keyword_gap:aspendental.com"

Errors carry a code and a stable exit status (`runwell help exit-codes`). For example, `refused` (5) means DataForSEO isn't connected or the budget is spent.

Every page is a tool, with JSON for reading: `show_market`, `list_market_clients`,
`show_client_market`, `update_client_market_profile`, `list_industries`, `show_industry`,
`list_competitors`, `show_competitor`, `create_competitor`, `link_market_competitor`,
`check_competitor_website`, `list_market_findings`, `update_market_finding`,
`refresh_market_findings`, `show_market_search`, `pull_market_search`,
`list_market_search_pulls`, `track_market_keywords`, `show_market_settings`,
`check_market_dataforseo`, `plan_market_with_ai`, `show_market_plan`,
`list_market_opportunities`, `add_market_opportunity`, `update_market_opportunity` and
`plan_market_opportunity_as_work`, among others. The plugin's agent workflow, "Planning a
client's SEO and marketing", says in what order to use them.

## Install

Settings › Plugins › Add a plugin: `Martin-Business-Consultants/plugin-market`. Then switch it on.
It needs Runwell 2.21 or newer. Plans need the AI plugin, switched on and set up; search data
needs a DataForSEO account, in Settings › Market (owners). Without either, everything else works.

Owners and managers change industries, competitors, profiles and plans (permission
`manage_market`). Everyone on staff reads them, plans opportunities as work and marks them done.

## Develop

From a Runwell checkout:

    bin/rails "plugins:link[../plugin-market]"
    bin/rails db:migrate
    bin/rails test ../plugin-market/test

To release, bump `lib/market/version.rb` and push a tag like `v0.2.0`. The workflow publishes
the GitHub release, which installs offer as an update.

FSL-1.1-MIT. Copyright Martin Business Consultants.
