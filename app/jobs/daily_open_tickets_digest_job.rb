class DailyOpenTicketsDigestJob < ApplicationJob
  queue_as :mailers

  OPEN_STATUSES = %w[open in_progress waiting_on_customer].freeze

  def perform
    Rails.logger.info "[DailyOpenTicketsDigestJob] Starting digest job..."

    open_scope = Ticket.where(status: OPEN_STATUSES).order(:created_at)

    Rails.logger.info "[DailyOpenTicketsDigestJob] Found #{open_scope.count} open tickets"

    User.where(role: :agent).where.not(email: nil).find_each do |agent|
      begin
        assigned   = open_scope.where(agent_id: agent.id)
        unassigned = open_scope.where(agent_id: nil)

        next if assigned.none? && unassigned.none?
        assigned_ids   = assigned.pluck(:id)
        unassigned_ids = unassigned.pluck(:id)

        Rails.logger.info "[DailyOpenTicketsDigestJob] Sending digest to #{agent.email} with #{assigned_ids.size} assigned, #{unassigned_ids.size} unassigned tickets"

        AgentDigestMailer
          .daily_open_tickets(agent, assigned_ids:, unassigned_ids:)
          .deliver_later
      rescue StandardError => e
        Rails.logger.error "[DailyOpenTicketsDigestJob] Error sending digest to #{agent.email}: #{e.message}"
      end
    end

    Rails.logger.info "[DailyOpenTicketsDigestJob] Finished digest job."
  end
end
