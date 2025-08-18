module Mutations
  class CreateTicket < BaseMutation
    include Authorization
    argument :title, String, required: true
    argument :description, String, required: true
    argument :priority, String, required: false
    argument :category, String, required: false
    argument :attachments, [ ApolloUploadServer::Upload ], required: false

    field :ticket, Types::TicketType, null: true
    field :errors, [ String ], null: false

    def resolve(**args)
      attachments = args.delete(:attachments)
      ticket = Ticket.new(args.merge(customer_id: current_user.id))
      authorize!(ticket, :create?)

      if attachments&.any?
        uploads = Array(attachments).compact.map do |file|
          if file.respond_to?(:tempfile) && file.respond_to?(:original_filename)
            {
              io: file.tempfile,
              filename: file.original_filename,
              content_type: file.content_type
            }
          elsif file.respond_to?(:to_io) && file.respond_to?(:original_filename)
            {
              io: file.to_io,
              filename: file.original_filename,
              content_type: file.content_type
            }
          else
            file
          end
        end

        ticket.attachments.attach(uploads)
      end
      if ticket.save
        { ticket: ticket, errors: [] }
      else
        { ticket: nil, errors: ticket.errors.full_messages }
      end
    end
  end
end
