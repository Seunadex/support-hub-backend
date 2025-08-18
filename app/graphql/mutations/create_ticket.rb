module Mutations
  class CreateTicket < BaseMutation
    include Authorization
    argument :title, String, required: true
    argument :description, String, required: true
    argument :priority, String, required: false
    argument :category, String, required: false

    field :ticket, Types::TicketType, null: true
    field :errors, [ String ], null: false

    def resolve(**args)
      ticket = Ticket.new(args.merge(customer_id: current_user.id))
      authorize!(ticket, :create?)
      if ticket.save
        { ticket: ticket, errors: [] }
      else
        { ticket: nil, errors: ticket.errors.full_messages }
      end
    end
  end
end
