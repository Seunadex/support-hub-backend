

# spec/policies/comment_policy_spec.rb
require "rails_helper"

RSpec.describe CommentPolicy do
  subject(:policy) { described_class.new(user, comment) }

  let(:agent)    { create(:user, :agent) }
  let(:customer) { create(:user, :customer) }
  let(:stranger) { create(:user, :customer) }

  let(:ticket)   { create(:ticket, customer: customer, status: :open) }
  let(:comment)  { create(:comment, ticket: ticket, author: customer) }

  describe "index?" do
    it "delegates to TicketPolicy#show?" do
      expect(TicketPolicy).to receive(:new).with(agent, ticket).and_call_original
      described_class.new(agent, comment).index?
    end

    it "allows when TicketPolicy#show? allows" do
      expect(described_class.new(customer, comment).index?).to eq(true)
    end

    it "denies when TicketPolicy#show? denies" do
      other_ticket = create(:ticket, customer: stranger)
      other_comment = create(:comment, ticket: other_ticket, author: stranger)
      expect(described_class.new(customer, other_comment).index?).to eq(false)
    end
  end

  describe "create?" do
    it "delegates to TicketPolicy#comment?" do
      expect(TicketPolicy).to receive(:new).with(customer, ticket).and_call_original
      described_class.new(customer, comment).create?
    end

    it "allows when TicketPolicy#comment? allows" do
      # Place ticket in a state where comment is allowed for customer
      ticket.update!(status: :waiting_on_customer)
      expect(described_class.new(customer, comment).create?).to eq(true)
    end

    it "denies when TicketPolicy#comment? denies" do
      expect(described_class.new(customer, comment).create?).to eq(false)
    end
  end

  describe "show?" do
    it "delegates to TicketPolicy#show?" do
      expect(TicketPolicy).to receive(:new).with(agent, ticket).and_call_original
      described_class.new(agent, comment).show?
    end

    it "allows when TicketPolicy#show? allows" do
      expect(described_class.new(customer, comment).show?).to eq(true)
    end

    it "denies when TicketPolicy#show? denies" do
      other_ticket = create(:ticket, customer: stranger)
      other_comment = create(:comment, ticket: other_ticket, author: stranger)
      expect(described_class.new(customer, other_comment).show?).to eq(false)
    end
  end

  describe "Scope" do
    it "returns only comments for tickets within TicketPolicy scope" do
      my_ticket = create(:ticket, customer: customer)
      my_comment = create(:comment, ticket: my_ticket, author: customer)
      other_ticket = create(:ticket, customer: stranger)
      other_comment = create(:comment, ticket: other_ticket, author: stranger)

      scope = Pundit.policy_scope!(customer, Comment)
      expect(scope).to include(my_comment)
      expect(scope).not_to include(other_comment)
    end
  end
end
