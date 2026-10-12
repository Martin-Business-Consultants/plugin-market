module Market
  module Opportunities
    # An opportunity made work: a core todo on one of its client's open engagements, whose
    # description links back to the client's market page.
    class TodosController < ApplicationController
      allow_staff
      agent_tool :plan_market_opportunity_as_work, on: :create, title: "Plan a market opportunity as work",
        description: "A todo on one of the opportunity's client's open engagements (engagement_id), from the opportunity: its title and detail unless given, with a link back. The opportunity becomes planned. owner_id leads it.",
        params: { todo: { engagement_id: "integer!", title: "string", description: "text", owner_id: "integer", due_on: "date" } },
        next_tools: %i[show_client_market list_market_opportunities]

      def create
        opportunity = Opportunity.find(params[:opportunity_id])
        attributes = params.expect(todo: %i[engagement_id title description owner_id due_on])
        engagement = opportunity.client.engagements.open.find_by(id: attributes[:engagement_id])
        back = market_client_path(opportunity.client, anchor: "opportunities")
        return redirect_to(back, alert: "Choose one of #{opportunity.client.name}'s open #{helpers.term(:engagement, count: 2).downcase}.") unless engagement

        link = helpers.link_to("#{opportunity.client.name}'s market", market_client_url(opportunity.client, anchor: "opportunities"))
        todo = opportunity.plan_as_work(engagement: engagement, by: Current.user, link: link, **attributes.except(:engagement_id).to_h.symbolize_keys)
        redirect_to back, notice: "Added “#{todo.title}” to #{engagement.ref} #{engagement.title}."
      rescue ActiveRecord::RecordInvalid => error
        redirect_to back, alert: error.record.errors.full_messages.to_sentence
      end
    end
  end
end
