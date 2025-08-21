require "rails_helper"

RSpec.describe Mutations::AddComment, type: :mutation do
  let(:agent)    { create(:user, :agent) }
  let(:customer) { create(:user, :customer) }
  let(:ticket)   { create(:ticket, customer: customer, status: :open) }

  let(:query) do
    <<~GRAPHQL
      mutation($input: AddCommentInput!) {
        addComment(input: $input) {
          ticket { id }
          errors
        }
      }
    GRAPHQL
  end

  def exec_mutation(input:, user:)
    gql(query, variables: { input: input }, context: { current_user: user })
  end

  before do
    allow_any_instance_of(TicketPolicy).to receive(:comment?).and_return(true)
  end

  it "requires authentication" do
    res = exec_mutation(input: { ticketId: ticket.id, body: "hello" }, user: nil)
    data = res.dig("data", "addComment")

    expect(data["ticket"]).to be_nil
    expect(data["errors"]).to include("Access denied")
  end

  it "returns not found for unknown ticket" do
    res = exec_mutation(input: { ticketId: "0", body: "hello" }, user: customer)
    data = res.dig("data", "addComment")

    expect(data["ticket"]).to be_nil
    expect(data["errors"]).to include("Ticket not found")
  end

  it "successfully adds comment" do
    res = exec_mutation(input: { ticketId: ticket.id, body: "hello" }, user: customer)
    data = res.dig("data", "addComment")

    expect(data["ticket"]).to include("id" => ticket.id.to_s)
    expect(data["errors"]).to be_empty
  end

  it "denies when policy forbids commenting" do
    allow_any_instance_of(TicketPolicy).to receive(:comment?).and_return(false)

    res = exec_mutation(input: { ticketId: ticket.id, body: "hello" }, user: customer)
    data = res.dig("data", "addComment")

    expect(data["ticket"]).to be_nil
    expect(data["errors"]).to include("Access denied")
  end

  context "state transitions" do
    it "customer reply triggers customer_replies! when waiting_on_customer" do
      ticket.update!(status: :waiting_on_customer)

      # Ensure state machine is called and succeeds
      expect_any_instance_of(Ticket).to receive(:customer_replies!).and_return(true)

      res = exec_mutation(input: { ticketId: ticket.id, body: "customer reply" }, user: customer)
      data = res.dig("data", "addComment")

      expect(data["errors"]).to eq([])
      expect(data["ticket"]).to include("id" => ticket.id.to_s)
    end

    it "agent response triggers agent_responds! when in_progress" do
      ticket.update!(status: :in_progress, agent: agent)

      # Ensure state machine is called and succeeds
      expect_any_instance_of(Ticket).to receive(:agent_responds!).and_return(true)

      res = exec_mutation(input: { ticketId: ticket.id, body: "agent reply" }, user: agent)
      data = res.dig("data", "addComment")

      expect(data["errors"]).to eq([])
      expect(data["ticket"]).to include("id" => ticket.id.to_s)
    end

    it "no transition needed when conditions are not met" do
      # Not waiting_on_customer and not in_progress
      ticket.update!(status: :open)

      # Ensure state machine methods are not called
      expect_any_instance_of(Ticket).not_to receive(:customer_replies!)
      expect_any_instance_of(Ticket).not_to receive(:agent_responds!)

      res = exec_mutation(input: { ticketId: ticket.id, body: "any reply" }, user: customer)
      data = res.dig("data", "addComment")

      expect(data["errors"]).to eq([])
      expect(data["ticket"]).to include("id" => ticket.id.to_s)
    end
  end

  context "unexpected errors" do
    it "returns a stable error and logs when an exception occurs" do
      logger_double = instance_double(Logger)
      allow(Rails).to receive(:logger).and_return(logger_double)
      allow(logger_double).to receive(:warn)
      allow(logger_double).to receive(:error)

      # Force an exception inside the mutation flow
      allow_any_instance_of(Mutations::AddComment).to receive(:create_comment).and_raise(StandardError, "boom")

      res = exec_mutation(input: { ticketId: ticket.id, body: "x" }, user: customer)
      data = res.dig("data", "addComment")

      expect(data["ticket"]).to be_nil
      expect(data["errors"]).to include("An unexpected error occurred. Please try again.")
      expect(logger_double).to have_received(:error).at_least(:once)
    end
  end
end
