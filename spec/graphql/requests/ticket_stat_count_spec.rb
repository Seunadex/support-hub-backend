require "rails_helper"

RSpec.describe Resolvers::TicketStatCount do
  let(:agent)    { create(:user, :agent) }
  let(:customer) { create(:user, :customer) }
  let(:other)    { create(:user, :customer) }

  def call(user)
    described_class.resolve(user)
  end

  context "when there are no tickets" do
    it "returns zeros" do
      result = call(agent)
      expect(result).to eq({ total: 0, open: 0, pending: 0, completed: 0 })
    end
  end

  context "with mixed statuses" do
    before do
      create(:ticket, customer: customer, status: :open)
      create(:ticket, customer: customer, status: :in_progress, agent: agent)
      create(:ticket, customer: customer, status: :waiting_on_customer, agent: agent)
      create(:ticket, customer: customer, status: :resolved, agent: agent)
      create(:ticket, customer: customer, status: :closed, agent: agent)

      create(:ticket, customer: other, status: :open)
      create(:ticket, customer: other, status: :in_progress, agent: agent)
      create(:ticket, customer: other, status: :closed, agent: agent)
    end

    it "counts using the policy scope for an agent (sees all)" do
      result = call(agent)

      # Totals across all eight tickets created above
      expect(result[:total]).to eq(8)

      # By design in this app:
      # open => status: open
      # pending => statuses: in_progress, waiting_on_customer
      # completed => statuses: resolved, closed
      expect(result[:open]).to eq(2)
      expect(result[:pending]).to eq(3)
      expect(result[:completed]).to eq(3)
    end

    it "counts only the current customer's tickets for a customer" do
      result = call(customer)

      expect(result[:total]).to eq(5)
      expect(result[:open]).to eq(1)
      expect(result[:pending]).to eq(2)
      expect(result[:completed]).to eq(2)
    end
  end

  context "policy scope integration" do
    it "delegates to TicketPolicy::Scope" do
      expect(TicketPolicy::Scope).to receive(:new).with(agent, Ticket).and_call_original
      call(agent)
    end
  end
end
