require "stringio"

module Mutations
  class ExportClosedTickets < BaseMutation
    argument :start_date, GraphQL::Types::ISO8601DateTime, required: true
    argument :end_date, GraphQL::Types::ISO8601DateTime, required: true

    field :filename, String, null: true
    field :count, Integer, null: false
    field :csv_url, String, null: true
    field :errors, [ String ], null: false

    def resolve(start_date:, end_date:)
      current_user = context[:current_user]
      return unauthorized_response unless current_user&.agent?

      to   = end_date
      from = start_date

      closed_tickets = fetch_closed_tickets(from, to)
      return { filename: nil, csv_url: nil, count: 0, errors: [ "No closed tickets found" ] } if closed_tickets.empty?

      csv, count = Exports::ClosedTicketsCsv.new(scope: closed_tickets, start_date: from, end_date: to).call
      return { filename: nil, csv_url: nil, count: 0, errors: [ "Failed to generate closed tickets CSV" ] } if csv.nil?

      from_ts = from.strftime("%Y%m%d%H%M%S")
      to_ts = to.strftime("%Y%m%d%H%M%S")
      random_hex = SecureRandom.hex(4)
      filename = "closed_tickets_#{from_ts}_to_#{to_ts}_#{random_hex}.csv"
      io = StringIO.new(csv)
      blob = ActiveStorage::Blob.create_and_upload!(io: io, filename: filename, content_type: "text/csv")

      url = Rails.application.routes.url_helpers.rails_blob_url(blob)

      {
        filename: filename,
        count: count,
        csv_url: url,
        errors: []
      }
    rescue StandardError => e
      Rails.logger.error("CSV export error: #{e.message}")
      { filename: nil, csv_url: nil, count: 0, errors: [ "Failed to generate closed tickets CSV" ] }
    end

    private

    def fetch_closed_tickets(from, to)
      Ticket.includes(:customer, :agent)
          .closed
          .where(closed_at: from..to)
          .order(closed_at: :desc)
    end

    def unauthorized_response
      { filename: nil, csv_url: nil, count: 0, errors: [ "Unauthorized" ] }
    end
  end
end
