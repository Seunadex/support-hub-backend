require "rails_helper"

RSpec.describe Mutations::AssignTicket, type: :mutation do
  let(:agent)      { create(:user, :agent) }
  let(:agent2)     { create(:user, :agent) }
  let(:customer)   { create(:user, :customer) }
  let(:ticket)     { create(:ticket, customer: customer, status: :open) }

  let(:query) do
    <<~GRAPHQL
      mutation($ticketId: ID!) {
        assignTicket(input: { ticketId: $ticketId }) {
          ticket { id }
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
    data = res.dig("data", "assignTicket")

    expect(data["ticket"]).to be_nil
    expect(data["errors"]).to include("User not found")
  end

  it "returns not found for unknown ticket" do
    res = exec_mutation(id: 0, user: agent)
    data = res.dig("data", "assignTicket")

    expect(data["ticket"]).to be_nil
    expect(data["errors"]).to include("Ticket not found")
  end

  it "denies when policy forbids assignment" do
    allow_any_instance_of(TicketPolicy).to receive(:assign?).and_return(false)

    res = exec_mutation(id: ticket.id, user: agent)
    data = res.dig("data", "assignTicket")

    expect(data["ticket"]).to be_nil
    expect(data["errors"]).to include("Access denied")
  end

  it "blocks when already assigned to another agent" do
    ticket.update!(agent_id: agent2.id)

    res = exec_mutation(id: ticket.id, user: agent)
    data = res.dig("data", "assignTicket")

    expect(data["ticket"]).to be_nil
    expect(data["errors"]).to include("Ticket already assigned to another agent")
  end

  it "succeeds and returns the ticket" do
    allow_any_instance_of(Ticket).to receive(:assign_to_agent!).and_wrap_original do |m, *args|
      t = m.receiver
      t.update!(agent_id: agent.id)
      true
    end

    res = exec_mutation(id: ticket.id, user: agent)
    data = res.dig("data", "assignTicket")

    expect(data["errors"]).to eq([])
    expect(data.dig("ticket", "id")).to eq(ticket.id.to_s)
    ticket.reload
    expect(ticket.agent_id).to eq(agent.id)
  end

  it "returns model errors when assignment is invalid" do
    allow_any_instance_of(Ticket).to receive(:assign_to_agent!).and_wrap_original do |m, *args|
      t = m.receiver
      t.errors.add(:base, "cannot assign")
      raise ActiveRecord::RecordInvalid.new(t)
    end

    res = exec_mutation(id: ticket.id, user: agent)
    data = res.dig("data", "assignTicket")

    expect(data["ticket"]).to be_nil
    expect(data["errors"]).to include("cannot assign").or include("Unable to transition ticket state")
  end

  it "handles unexpected exceptions with a stable error and logs" do
    logger_double = instance_double(Logger)
    allow(Rails).to receive(:logger).and_return(logger_double)
    allow(logger_double).to receive(:error)

    allow_any_instance_of(Ticket).to receive(:assign_to_agent!).and_raise(StandardError, "boom")

    res = exec_mutation(id: ticket.id, user: agent)
    data = res.dig("data", "assignTicket")

    expect(data["ticket"]).to be_nil
    expect(data["errors"]).to include("Unexpected error while assigning ticket")
    expect(logger_double).to have_received(:error).at_least(:once)
  end

  it "does not block if already assigned to the same agent" do
    ticket.update!(agent_id: agent.id)

    allow_any_instance_of(Ticket).to receive(:assign_to_agent!).and_return(true)

    res = exec_mutation(id: ticket.id, user: agent)
    data = res.dig("data", "assignTicket")

    expect(data["errors"]).to eq([])
    expect(data.dig("ticket", "id")).to eq(ticket.id.to_s)
  end
end
