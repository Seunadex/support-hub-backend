module Mutations
  class CloseTicket < BaseMutation
    argument :ticket_id, ID, required: true

    field :success, Boolean, null: false
    field :errors, [ String ], null: false

    def resolve(ticket_id:)
      return unauthorized_response("User not found") unless current_user

      ticket = Ticket.find_by(id: ticket_id)
      return not_found_error unless ticket

      authorize!(ticket, :can_close?)

      result = false

      ticket.with_lock do
        begin
          result = ticket.close_ticket!
        rescue ActiveRecord::RecordInvalid
          result = false
        end
      end

      if result
        { success: true, errors: [] }
      else
        { success: false, errors: state_transition_error(ticket) }
      end
    rescue GraphQL::ExecutionError => e
      unauthorized_response(e.message)
    rescue StandardError => e
      Rails.logger.error("CloseTicket mutation failed: #{e.class}: #{e.message}")
      Rails.logger.error(e.backtrace.first(10).join("\n"))
      { success: false, errors: [ "Unexpected error while closing ticket" ] }
    end

    private

    def not_found_error
      { success: false, errors: [ "Ticket not found" ] }
    end

    def unauthorized_response(message)
      { success: false, errors: [ message ] }
    end

    def state_transition_error(ticket)
      ticket.errors.full_messages.presence || [ "Unable to transition ticket state" ]
    end
  end
end
