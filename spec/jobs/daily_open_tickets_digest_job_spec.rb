require "rails_helper"

RSpec.describe DailyOpenTicketsDigestJob, type: :job do
  include ActiveJob::TestHelper

  let!(:agent1)   { create(:user, :agent, email: "a1@example.com") }
  let!(:agent2)   { create(:user, :agent, email: "a2@example.com") }
  let!(:customer) { create(:user, :customer) }

  let!(:t_assigned_open)   { create(:ticket, status: :open, agent_id: agent1.id, customer: customer) }
  let!(:t_assigned_prog)   { create(:ticket, status: :in_progress, agent_id: agent1.id, customer: customer) }
  let!(:t_unassigned_wait) { create(:ticket, status: :waiting_on_customer, agent_id: nil, customer: customer) }
  let!(:t_resolved)        { create(:ticket, status: :resolved, agent_id: agent2.id, customer: customer) }
  let!(:t_closed)          { create(:ticket, status: :closed, agent_id: nil, customer: customer) }

  before do
    clear_enqueued_jobs
  end

  it "sends a digest to each agent with assigned and unassigned open tickets" do
    mail_double = instance_double(ActionMailer::MessageDelivery, deliver_later: true)

    # Unassigned open tickets list is the same for all agents
    unassigned_ids = [ t_unassigned_wait.id ]

    expect(AgentDigestMailer).to receive(:daily_open_tickets)
      .with(agent1, assigned_ids: contain_exactly(t_assigned_open.id, t_assigned_prog.id), unassigned_ids: unassigned_ids)
      .and_return(mail_double)

    expect(AgentDigestMailer).to receive(:daily_open_tickets)
      .with(agent2, assigned_ids: [], unassigned_ids: unassigned_ids)
      .and_return(mail_double)

    perform_enqueued_jobs { described_class.perform_now }
  end

  it "skips agents when there are no assigned or unassigned open tickets" do
    # Remove open statuses for a clean run
    Ticket.where(id: [ t_assigned_open.id, t_assigned_prog.id, t_unassigned_wait.id ]).delete_all

    expect(AgentDigestMailer).not_to receive(:daily_open_tickets)

    perform_enqueued_jobs { described_class.perform_now }
  end

  it "logs errors and continues with other agents when mailer raises" do
    mail_double = instance_double(ActionMailer::MessageDelivery, deliver_later: true)

    logger_double = instance_double(Logger)
    allow(Rails).to receive(:logger).and_return(logger_double)
    allow(logger_double).to receive(:info)
    allow(logger_double).to receive(:error)

    # First agent raises, second still gets a mail scheduled
    allow(AgentDigestMailer).to receive(:daily_open_tickets)
      .with(agent1, assigned_ids: contain_exactly(t_assigned_open.id, t_assigned_prog.id), unassigned_ids: [ t_unassigned_wait.id ])
      .and_raise(StandardError, "boom")

    expect(AgentDigestMailer).to receive(:daily_open_tickets)
      .with(agent2, assigned_ids: [], unassigned_ids: [ t_unassigned_wait.id ])
      .and_return(mail_double)

    perform_enqueued_jobs { described_class.perform_now }

    expect(logger_double).to have_received(:error).with(/Error sending digest to a1@example.com: boom/)
  end

  it "uses the mailers queue" do
    expect(described_class.queue_name).to eq("mailers")
  end

  it "filters only open statuses" do
    expect(%w[open in_progress waiting_on_customer]).to include(*DailyOpenTicketsDigestJob::OPEN_STATUSES)
    expect(DailyOpenTicketsDigestJob::OPEN_STATUSES).not_to include("closed")
    expect(DailyOpenTicketsDigestJob::OPEN_STATUSES).not_to include("resolved")
  end
end
