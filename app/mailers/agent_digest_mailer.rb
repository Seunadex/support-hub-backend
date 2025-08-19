class AgentDigestMailer < ApplicationMailer
  default from: "support@gmail.com"

  def daily_open_tickets(agent, assigned_ids:, unassigned_ids:)
    @agent = agent
    @assigned = Ticket.where(id: assigned_ids).order(:created_at)
    @unassigned = Ticket.where(id: unassigned_ids).order(:created_at)
    subject = "Daily Open Support Tickets: #{@assigned.count} open assigned (+#{@unassigned.count} unassigned)"
    mail to: agent.email, subject: subject
  end
end
