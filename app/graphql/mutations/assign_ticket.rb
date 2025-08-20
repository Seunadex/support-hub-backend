module Mutations
  class AssignTicket < BaseMutation
    argument :ticket_id, String, required: true

    field :ticket, Types::TicketType, null: true
    field :errors, [ String ], null: false

    def resolve(ticket_id:)
      user = context[:current_user]
      return unauthorized_response unless user

      ticket = Ticket.find_by(id: ticket_id)
      return not_found_error(ticket_id) unless ticket

      unless TicketPolicy.new(user, ticket).assign?
        return unauthorized_response
      end

      # Prevent race conditions where two agents try to assign at once
      ticket.with_lock do
        # Block assignment if already owned by someone else
        if ticket.respond_to?(:agent_id) && ticket.agent_id.present? && ticket.agent_id != user.id
          return already_assigned_error
        end

        is_ok = begin
          ticket.assign_to_agent!(user)
          true
        rescue ActiveRecord::RecordInvalid
          false
        end

        is_ok ? success(ticket) : failure(ticket)
      end
    rescue StandardError => e
      Rails.logger.error("AssignTicket mutation failed: #{e.class}: #{e.message}")
      Rails.logger.error(e.backtrace.first(10).join("\n"))
      { ticket: nil, errors: [ "Unexpected error while assigning ticket" ] }
    end

    private

    def success(ticket)
      { ticket: ticket, errors: [] }
    end

    def failure(ticket)
      { ticket: nil, errors: state_transition_error(ticket) }
    end

    def unauthorized_response
      { ticket: nil, errors: [ "Access denied" ] }
    end

    def not_found_error(_ticket_id)
      { ticket: nil, errors: [ "Ticket not found" ] }
    end

    def already_assigned_error
      { ticket: nil, errors: [ "Ticket already assigned to another agent" ] }
    end

    def state_transition_error(ticket)
      ticket.errors.full_messages.presence || [ "Unable to transition ticket state" ]
    end
  end
end
