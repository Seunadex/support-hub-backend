module Mutations
  class AssignTicket < BaseMutation
    argument :ticket_id, String, required: true

    field :ticket, Types::TicketType, null: true
    field :errors, [ String ], null: false

    def resolve(ticket_id:)
      ticket = Ticket.find_by(id: ticket_id)

      if ticket.nil?
        return { ticket: nil, errors: [ "Ticket not found" ] }
      end

      if ticket.assign_agent(context[:current_user])
        { ticket: ticket, errors: [] }
      else
        { ticket: nil, errors: state_transition_error(ticket) }
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
