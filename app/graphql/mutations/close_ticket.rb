module Mutations
  class CloseTicket < BaseMutation
    argument :ticket_id, String, required: true

    field :success, Boolean, null: false
    field :errors, [ String ], null: false

    def resolve(ticket_id:)
      ticket = Ticket.find_by(id: ticket_id)

      return not_found_error(ticket_id) unless ticket

      authorize!(ticket, :can_close?)

      if ticket.close_ticket!
        { success: true, errors: [] }
      else
        { success: false, errors: state_transition_error(ticket) }
      end
    end

    private

    def not_found_error(ticket_id)
      { ticket: nil, errors: [ "Ticket not found" ] }
    end

    def state_transition_error(ticket)
      ticket.errors.full_messages.presence || [ "Unable to transition ticket state" ]
    end
  end
end
