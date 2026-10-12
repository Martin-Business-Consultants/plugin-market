module Market
  # What the data says, across every client or for one: the findings, worst first, each with
  # its evidence and sources, a stable key and when it last changed. `since` answers only what
  # changed after a time, so a harness that remembers when it last looked hears each change once.
  class FindingsController < ApplicationController
    allow_staff
    agent_tool :list_market_findings, on: :index, title: "List market findings",
      description: "What the data says about clients' markets, worked out from the website readings, the DataForSEO search data and the tracked rankings: each finding's stable key, kind, severity (high, medium, low, info), channel, title, detail, evidence (the exact figures) and sources (the readings, snapshots and rankings it came from, with ids and dates), and when it was first seen and last changed. state: open (the default), resolved, dismissed or all. Narrow by client_id, industry_id, severity, kind or channel. since: an ISO time; only findings that appeared, changed, resolved or were dismissed after it (pass back the answer's `as_of` next time).",
      params: { state: Finding::STATES + [ "all" ], client_id: "integer", industry_id: "integer", severity: Finding::SEVERITIES, kind: "string",
                channel: Opportunity::CHANNELS.keys, since: "string" },
      next_tools: %i[show_client_market show_market_search add_market_opportunity update_market_finding]
    agent_tool :update_market_finding, on: :update, title: "Dismiss or reopen a market finding",
      description: "state: dismissed (it stays dismissed while it holds) or open.", params: { finding: { state: %w[dismissed open] } }
    agent_tool :refresh_market_findings, on: :create, title: "Work out a client's findings again",
      description: "Recomputes a client's findings from what's stored now (no outside calls). They're refreshed after every reading and pull anyway.",
      params: { client_id: "integer!" }, next_tools: %i[list_market_findings]

    def index
      @as_of = Time.current
      if params[:since].present?
        @since = Time.zone.parse(params[:since].to_s) rescue nil
        return render(json: { status: "error", code: "usage", summary: "since isn't a time: use ISO 8601, like 2026-10-12T09:00:00Z" }, status: :unprocessable_entity) unless @since
      end
      # Since a time, every state by default: a finding resolved or dismissed since is news too.
      @state = params[:state].presence_in(Finding::STATES + [ "all" ]) || (@since ? "all" : "open")
      @client = Client.find(params[:client_id]) if params[:client_id].present?
      @industry = Industry.find(params[:industry_id]) if params[:industry_id].present?
      scope = Finding.includes(:client).in_state(@state).by_severity
      scope = scope.where(client: @client) if @client
      scope = scope.where(client_id: Profile.where(industry: @industry).select(:client_id)) if @industry
      scope = scope.where(severity: params[:severity]) if params[:severity].in?(Finding::SEVERITIES)
      scope = scope.where(kind: params[:kind]) if params[:kind].present?
      scope = scope.where(channel: params[:channel]) if params[:channel].in?(Opportunity::CHANNELS.keys)
      scope = scope.where(changed_at: @since..) if @since
      @findings = scope.limit(500).to_a
    end

    def create
      client = Client.find(params[:client_id])
      found = Finding.refresh(client)
      redirect_to market_findings_path(client_id: client.id), notice: "#{client.name}: #{found.size} open #{"finding".pluralize(found.size)}."
    end

    def update
      finding = Finding.find(params[:id])
      case params.expect(finding: [ :state ])[:state]
      when "dismissed" then finding.dismiss(by: Current.user)
      when "open" then finding.reopen
      end
      redirect_back_or_to market_findings_path(client_id: finding.client_id), notice: "“#{finding.title}” #{finding.state}."
    end
  end
end
