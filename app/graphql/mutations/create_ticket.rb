module Mutations
  class CreateTicket < BaseMutation
    argument :title, String, required: true
    argument :description, String, required: true
    argument :priority, String, required: false
    argument :category, String, required: false
    argument :attachments, [ ApolloUploadServer::Upload ], required: false

    field :ticket, Types::TicketType, null: true
    field :errors, [ String ], null: false

    MAX_FILE_SIZE = 10.megabytes
    MAX_ATTACHMENT_COUNT = 3
    ALLOWED_TYPES = %w[image/jpeg image/png application/pdf]

    def resolve(**args)
      raw_attachments = Array(args.delete(:attachments)).compact
      ticket = Ticket.new(args.merge(customer_id: current_user.id))
      authorize!(ticket, :create?)

      attachment_errors = validate_attachments(raw_attachments)
      return { ticket: nil, errors: Array(attachment_errors).compact } if attachment_errors.any?

      uploads = build_attachments(raw_attachments)

      Ticket.transaction do
        if ticket.save
          ticket.attachments.attach(uploads) if uploads.any?
          { ticket: ticket, errors: [] }
        else
          { ticket: nil, errors: ticket.errors.full_messages }
        end
      end

    rescue GraphQL::ExecutionError => e
      { ticket: nil, errors: [ e.message ] }

    rescue StandardError => e
      Rails.logger.error("CreateTicket mutation failed: #{e.class}: #{e.message}")
      Rails.logger.error(e.backtrace.first(10).join("\n"))
      { ticket: nil, errors: [ "Unexpected error while creating ticket" ] }
    end

    private

    def build_attachments(files)
      files.map do |file|
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
    end

    def validate_attachments(files)
      errors = []
      if files.size > MAX_ATTACHMENT_COUNT
        errors << "You can upload a maximum of #{MAX_ATTACHMENT_COUNT} files."
      end

      files.each do |file|
        size = if file.respond_to?(:size)
          file.size
        elsif file.respond_to?(:tempfile) && file.tempfile
          file.tempfile.size
        else
          nil
        end
        content_type = if file.respond_to?(:content_type)
          file.content_type
        else
          nil
        end
        if size && size > MAX_FILE_SIZE
          errors << "File #{file.original_filename} is too large. Max size is #{MAX_FILE_SIZE / 1.megabyte} MB."
        end
        if content_type.present? && !ALLOWED_TYPES.include?(content_type)
          errors << "File #{file.original_filename} has an invalid type. Allowed types are: #{ALLOWED_TYPES.join(", ")}."
        end
      end

      errors
    end
  end
end
