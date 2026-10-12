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
- **Opportunities** are listed best first (most impact for least effort, then soonest), per
  client and across every client, by channel and industry. One click plans one as work: a
  Runwell todo on one of the client's open engagements, linking back. Or mark it done, or
  dismiss it.
- **The overview** gives the whole portfolio at a glance:
  - industries and who's in them;
  - the best open opportunities;
  - what competitors changed in the last 30 days;
  - the clients whose market isn't mapped yet.

Nothing is recorded from AI without a person. Suggested industries and competitors are leads to
check, taken in one click. Rankings, traffic, review counts and ad spend aren't read, and plans
are told not to claim them.

## For agents

Every page is a tool, with JSON for reading: `show_market`, `list_market_clients`,
`show_client_market`, `update_client_market_profile`, `list_industries`, `show_industry`,
`list_competitors`, `show_competitor`, `create_competitor`, `link_market_competitor`,
`check_competitor_website`, `plan_market_with_ai`, `show_market_plan`,
`list_market_opportunities`, `add_market_opportunity`, `update_market_opportunity` and
`plan_market_opportunity_as_work`, among others. The plugin's agent workflow, "Planning a
client's SEO and marketing", says in what order to use them.

## Install

Settings › Plugins › Add a plugin: `Martin-Business-Consultants/plugin-market`. Then switch it on.
It needs Runwell 2.21 or newer. Plans need the AI plugin, switched on and set up. Without it,
everything else works, and opportunities can be added by hand.

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
