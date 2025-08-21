require "rails_helper"

RSpec.describe TicketStateMachine, type: :model do
  include ActiveSupport::Testing::TimeHelpers

  let(:agent)    { create(:user, :agent) }
  let(:customer) { create(:user, :customer) }

  describe "enum and initial state" do
    it "defines the status enum and starts as open" do
      t = create(:ticket, customer: customer)
      expect(t.status).to eq("open")
      expect(Ticket.statuses.keys).to contain_exactly("open", "in_progress", "waiting_on_customer", "resolved", "closed")
    end
  end

  describe "assign_to_agent!" do
    it "moves open to in_progress and sets agent" do
      t = create(:ticket, customer: customer, status: :open)
      ok = t.assign_to_agent!(agent)
      expect(ok).to eq(true)
      expect(t.reload.status).to eq("in_progress")
      expect(t.agent_id).to eq(agent.id)
    end

    it "fails outside open state and adds error" do
      t = create(:ticket, customer: customer, status: :in_progress, agent_id: agent.id)
      ok = t.assign_to_agent!(agent)
      expect(ok).to eq(false)
      expect(t.errors.full_messages.join).to include("Cannot assign ticket in current state")
      expect(t.reload.status).to eq("in_progress")
    end
  end

  describe "agent_responds!" do
    it "moves in_progress to waiting_on_customer and sets first_response_at and agent_has_replied" do
      freeze_time do
        t = create(:ticket, customer: customer, status: :in_progress, agent_id: agent.id, agent_has_replied: false, first_response_at: nil)
        ok = t.agent_responds!
        expect(ok).to eq(true)
        expect(t.reload.status).to eq("waiting_on_customer")
        expect(t.first_response_at).to be_within(1.second).of(Time.current)
        expect(t.agent_has_replied).to eq(true)
      end
    end

    it "does not change first_response_at if set previously" do
      t = create(:ticket, customer: customer, status: :in_progress, agent_id: agent.id, first_response_at: 1.day.ago, agent_has_replied: false)
      previous = t.first_response_at
      t.agent_responds!
      expect(t.first_response_at).to eq(previous)
      expect(t.agent_has_replied).to eq(true)
    end

    it "fails outside in_progress and adds error" do
      t = create(:ticket, customer: customer, status: :open)
      ok = t.agent_responds!
      expect(ok).to eq(false)
      expect(t.errors.full_messages.join).to include("Cannot respond in current state")
    end
  end

  describe "customer_replies!" do
    it "moves waiting_on_customer to in_progress" do
      t = create(:ticket, customer: customer, status: :waiting_on_customer, agent_id: agent.id)
      ok = t.customer_replies!
      expect(ok).to eq(true)
      expect(t.reload.status).to eq("in_progress")
    end

    it "fails from other states" do
      t = create(:ticket, customer: customer, status: :open)
      ok = t.customer_replies!
      expect(ok).to eq(false)
      expect(t.errors.full_messages.join).to include("Cannot reply in current state")
    end
  end

  describe "resolve_ticket!" do
    it "moves in_progress to resolved" do
      t = create(:ticket, customer: customer, status: :in_progress, agent_id: agent.id)
      ok = t.resolve_ticket!(agent)
      expect(ok).to eq(true)
      expect(t.reload.status).to eq("resolved")
    end

    it "fails from open state" do
      t = create(:ticket, customer: customer, status: :open)
      ok = t.resolve_ticket!(agent)
      expect(ok).to eq(false)
      expect(t.errors.full_messages.join).to include("Cannot resolve ticket in current state")
    end
  end

  describe "close_ticket!" do
    it "moves resolved to closed and sets closed_at" do
      freeze_time do
        t = create(:ticket, customer: customer, status: :resolved)
        ok = t.close_ticket!
        expect(ok).to eq(true)
        expect(t.reload.status).to eq("closed")
        expect(t.closed_at).to be_within(1.second).of(Time.current)
      end
    end

    it "also closes from in_progress and waiting_on_customer" do
      %i[in_progress waiting_on_customer].each do |st|
        t = create(:ticket, customer: customer, status: st, agent_id: agent.id)
        expect(t.close_ticket!).to eq(true)
        expect(t.status).to eq("closed")
      end
    end

    it "fails from open" do
      t = create(:ticket, customer: customer, status: :open)
      ok = t.close_ticket!
      expect(ok).to eq(false)
      expect(t.errors.full_messages.join).to include("Cannot close ticket in current state")
    end
  end

  describe "helpers" do
    it "active? is false only when closed" do
      t1 = create(:ticket, status: :closed)
      t2 = create(:ticket, status: :resolved)
      expect(t1.active?).to eq(false)
      expect(t2.active?).to eq(true)
    end

    it "needs_agent_attention? is true for open or in_progress only" do
      t_open = create(:ticket, status: :open)
      t_prog = create(:ticket, status: :in_progress, agent: agent)
      t_wait = create(:ticket, status: :waiting_on_customer)
      expect(t_open.needs_agent_attention?).to eq(true)
      expect(t_prog.needs_agent_attention?).to eq(true)
      expect(t_wait.needs_agent_attention?).to eq(false)
    end

    it "completed? is true for resolved or closed" do
      t_res = create(:ticket, status: :resolved)
      t_clo = create(:ticket, status: :closed)
      t_open = create(:ticket, status: :open)
      expect(t_res.completed?).to eq(true)
      expect(t_clo.completed?).to eq(true)
      expect(t_open.completed?).to eq(false)
    end
  end
end
