require "rails_helper"

RSpec.describe Mutations::ResolveTicket, type: :mutation do
  let(:agent)    { create(:user, :agent) }
  let(:agent2)    { create(:user, :agent) }
  let(:customer) { create(:user, :customer) }
  let(:ticket)   { create(:ticket, customer: customer, agent: agent, status: :in_progress) }

  let(:query) do
    <<~GRAPHQL
      mutation($ticketId: ID!) {
        resolveTicket(input: { ticketId: $ticketId }) {
          success
          errors
        }
      }
    GRAPHQL
  end

  def exec_mutation(id:, user:)
    gql(query, variables: { ticketId: id }, context: { current_user: user })
  end

  it "returns not found for unknown ticket" do
    res = exec_mutation(id: 0, user: agent)
    data = res.dig("data", "resolveTicket")

    expect(data["success"]).to eq(false)
    expect(data["errors"]).to include("Ticket not found")
  end

  it "denies when policy forbids resolution" do
    allow_any_instance_of(TicketPolicy).to receive(:can_resolve?).and_return(false)

    res = exec_mutation(id: ticket.id, user: agent2)
    data = res.dig("data", "resolveTicket")

    expect(data["success"]).to eq(false)
    expect(data["errors"]).to include("Not authorized")
  end

  it "resolves the ticket on success" do
    allow_any_instance_of(Ticket).to receive(:resolve_ticket!).and_wrap_original do |m, *args|
      t = m.receiver
      t.update!(status: :resolved)
      true
    end

    res = exec_mutation(id: ticket.id, user: agent)
    data = res.dig("data", "resolveTicket")

    expect(data["errors"]).to eq([])
    expect(data["success"]).to eq(true)
    ticket.reload
    expect(ticket.status).to eq("resolved")
  end
end
