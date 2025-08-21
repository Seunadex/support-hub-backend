

# spec/graphql/mutations/close_ticket_spec.rb
require "rails_helper"

RSpec.describe Mutations::CloseTicket, type: :mutation do
  let(:agent)    { create(:user, :agent) }
  let(:customer) { create(:user, :customer) }
  let(:ticket)   { create(:ticket, customer: customer, agent: agent, status: :resolved) }

  let(:query) do
    <<~GRAPHQL
      mutation($ticketId: ID!) {
        closeTicket(input: { ticketId: $ticketId }) {
          success
          errors
        }
      }
    GRAPHQL
  end

  def exec_mutation(id:, user:)
    gql(query, variables: { ticketId: id }, context: { current_user: user })
  end

  it "requires authentication" do
    res = exec_mutation(id: ticket.id, user: nil)
    data = res.dig("data", "closeTicket")

    expect(data["success"]).to eq(false)
    expect(data["errors"]).to include("User not found")
  end

  it "returns not found for unknown ticket" do
    res = exec_mutation(id: "0", user: agent)
    data = res.dig("data", "closeTicket")

    expect(data["success"]).to eq(false)
    expect(data["errors"]).to include("Ticket not found")
  end

  it "denies when policy forbids closing" do
    allow_any_instance_of(TicketPolicy).to receive(:can_close?).and_return(false)

    res = exec_mutation(id: ticket.id, user: agent)
    data = res.dig("data", "closeTicket")

    expect(data["success"]).to eq(false)
    expect(data["errors"]).to include("Not authorized")
  end

  it "closes the ticket on success" do
    res = exec_mutation(id: ticket.id, user: agent)
    data = res.dig("data", "closeTicket")

    expect(data["errors"]).to eq([])
    expect(data["success"]).to eq(true)
    ticket.reload
    expect(ticket.status).to eq("closed")
  end

  it "returns model errors when transition is invalid" do
    allow_any_instance_of(Ticket).to receive(:close_ticket!).and_wrap_original do |m, *args|
      t = m.receiver
      t.errors.add(:base, "cannot close")
      raise ActiveRecord::RecordInvalid.new(t)
    end

    res = exec_mutation(id: ticket.id, user: agent)
    data = res.dig("data", "closeTicket")

    expect(data["success"]).to eq(false)
    expect(data["errors"]).to include("cannot close").or include("Unable to transition ticket state")
  end

  it "handles unexpected exceptions with a stable error and logs" do
    logger_double = instance_double(Logger)
    allow(Rails).to receive(:logger).and_return(logger_double)
    allow(logger_double).to receive(:error)

    allow_any_instance_of(Ticket).to receive(:close_ticket!).and_raise(StandardError, "boom")

    res = exec_mutation(id: ticket.id, user: agent)
    data = res.dig("data", "closeTicket")

    expect(data["success"]).to eq(false)
    expect(data["errors"]).to include("Unexpected error while closing ticket")
    expect(logger_double).to have_received(:error).at_least(:once)
  end
end
