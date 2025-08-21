# spec/policies/ticket_policy_spec.rb
require "rails_helper"

RSpec.describe TicketPolicy do
  subject(:policy) { described_class.new(user, ticket) }

  let(:agent)    { create(:user, :agent) }
  let(:agent2)   { create(:user, :agent) }
  let(:customer) { create(:user, :customer) }
  let(:stranger) { create(:user, :customer) }

  let(:ticket)   { create(:ticket, customer: customer, status: :open) }

  describe "index?" do
    it "allows any logged in user" do
      expect(described_class.new(agent, ticket).index?).to eq(true)
      expect(described_class.new(customer, ticket).index?).to eq(true)
    end

    it "denies guests" do
      expect(described_class.new(nil, ticket).index?).to eq(false)
    end
  end

  describe "show?" do
    it "allows an agent" do
      expect(described_class.new(agent, ticket).show?).to eq(true)
    end

    it "allows the ticket owner" do
      expect(described_class.new(customer, ticket).show?).to eq(true)
    end

    it "denies other customers" do
      expect(described_class.new(stranger, ticket).show?).to eq(false)
    end
  end

  describe "create?" do
    it "allows customers" do
      expect(described_class.new(customer, Ticket.new).class).to eq(described_class)
      expect(described_class.new(customer, Ticket.new).create?).to eq(true)
    end

    it "denies agents" do
      expect(described_class.new(agent, Ticket.new).create?).to eq(false)
    end
  end

  describe "update?/assign?/destroy?" do
    it "allows agents" do
      p = described_class.new(agent, ticket)
      expect(p.update?).to eq(true)
      expect(p.assign?).to eq(true)
      expect(p.destroy?).to eq(true)
    end

    it "denies customers" do
      p = described_class.new(customer, ticket)
      expect(p.update?).to eq(false)
      expect(p.assign?).to eq(false)
      expect(p.destroy?).to eq(false)
    end
  end

  describe "comment?" do
    context "closed ticket" do
      let(:user) { agent }
      let(:ticket) { create(:ticket, customer: customer, status: :closed, agent_id: agent.id) }
      it { is_expected.to have_attributes(comment?: false) }
    end

    context "agent rules" do
      let(:user) { agent }

      it "denies when open and unassigned" do
        t = create(:ticket, customer: customer, status: :open)
        expect(described_class.new(agent, t).comment?).to eq(false)
      end

      it "allows assigned agent in in_progress" do
        t = create(:ticket, customer: customer, status: :in_progress, agent_id: agent.id)
        expect(described_class.new(agent, t).comment?).to eq(true)
      end

      it "denies other agents in in_progress" do
        other = create(:user, :agent)
        t = create(:ticket, customer: customer, status: :in_progress, agent_id: other.id)
        expect(described_class.new(agent, t).comment?).to eq(false)
      end

      it "allows assigned agent when resolved" do
        t = create(:ticket, customer: customer, status: :resolved, agent_id: agent.id)
        expect(described_class.new(agent, t).comment?).to eq(true)
      end
    end

    context "customer rules" do
      let(:user) { customer }

      it "denies when not owner" do
        t = create(:ticket, customer: stranger, status: :waiting_on_customer)
        expect(described_class.new(customer, t).comment?).to eq(false)
      end

      it "denies when open" do
        t = create(:ticket, customer: customer, status: :open)
        expect(described_class.new(customer, t).comment?).to eq(false)
      end

      it "allows when waiting_on_customer" do
        t = create(:ticket, customer: customer, status: :waiting_on_customer)
        expect(described_class.new(customer, t).comment?).to eq(true)
      end

      it "allows in in_progress only after agent replied" do
        t = create(:ticket, customer: customer, agent: agent, status: :in_progress, agent_has_replied: true)
        expect(described_class.new(customer, t).comment?).to eq(true)
      end

      it "denies in in_progress before agent reply" do
        t = create(:ticket, customer: customer, agent: agent, status: :in_progress, agent_has_replied: false)
        expect(described_class.new(customer, t).comment?).to eq(false)
      end

      it "denies when resolved or closed" do
        t1 = create(:ticket, customer: customer, agent: agent, status: :resolved)
        t2 = create(:ticket, customer: customer, status: :closed)
        expect(described_class.new(customer, t1).comment?).to eq(false)
        expect(described_class.new(customer, t2).comment?).to eq(false)
      end
    end
  end

  describe "can_close?" do
    it "allows assigned agent from any non-closed state" do
      %i[open in_progress waiting_on_customer resolved].each do |st|
        t = create(:ticket, customer: customer, status: st, agent_id: agent.id)
        expect(described_class.new(agent, t).can_close?).to eq(true)
      end
    end

    it "allows customer when resolved and owner" do
      t = create(:ticket, customer: customer, status: :resolved)
      expect(described_class.new(customer, t).can_close?).to eq(true)
    end

    it "denies customer when not owner or not resolved" do
      t1 = create(:ticket, customer: stranger, status: :resolved)
      t2 = create(:ticket, customer: customer, agent: agent, status: :in_progress)
      expect(described_class.new(customer, t1).can_close?).to eq(false)
      expect(described_class.new(customer, t2).can_close?).to eq(false)
    end

    it "denies when already closed" do
      t = create(:ticket, customer: customer, status: :closed, agent_id: agent.id)
      expect(described_class.new(agent, t).can_close?).to eq(false)
    end
  end

  describe "can_resolve?" do
    it "allows assigned agent from allowed states" do
      %i[in_progress waiting_on_customer].each do |st|
        t = create(:ticket, customer: customer, status: st, agent_id: agent.id)
        expect(described_class.new(agent, t).can_resolve?).to eq(true)
      end
    end

    it "denies agent when not assigned" do
      t = create(:ticket, customer: customer, status: :in_progress, agent_id: agent2.id)
      expect(described_class.new(agent, t).can_resolve?).to eq(false)
    end

    it "denies when already resolved or closed" do
      %i[resolved closed].each do |st|
        t = create(:ticket, customer: customer, status: st, agent_id: agent.id)
        expect(described_class.new(agent, t).can_resolve?).to eq(false)
      end
    end

    it "denies customers" do
      t = create(:ticket, customer: customer, status: :in_progress, agent_id: agent.id)
      expect(described_class.new(customer, t).can_resolve?).to eq(false)
    end
  end

  describe "Scope" do
    it "returns all tickets for agents, ordered by created_at desc" do
      old = create(:ticket, created_at: 3.days.ago)
      mid = create(:ticket, created_at: 2.days.ago)
      recent = create(:ticket, created_at: 1.day.ago)

      scope = described_class::Scope.new(agent, Ticket.all).resolve
      expect(scope.pluck(:id)).to eq([ recent.id, mid.id, old.id ])
    end

    it "returns only own tickets for customers in desc order" do
      mine1 = create(:ticket, customer: customer, created_at: 1.day.ago)
      mine2 = create(:ticket, customer: customer, created_at: 2.days.ago)
      _others = create_list(:ticket, 2, customer: stranger)

      scope = described_class::Scope.new(customer, Ticket.all).resolve
      expect(scope.pluck(:id)).to eq([ mine1.id, mine2.id ])
    end
  end
end
