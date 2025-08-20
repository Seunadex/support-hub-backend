require "csv"

module Exports
  class ClosedTicketsCsv
    HEADERS = [
          "Ticket ID",
          "Reference Number",
          "Title",
          "Description",
          "Customer Email",
          "Agent Email",
          "Status",
          "Created At",
          "First Response At",
          "Closed At",
          "Priority",
          "Category"
        ].freeze

    def initialize(scope:, start_date:, end_date:)
      @scope = scope
      @start_date = start_date
      @end_date = end_date
    end

    def call
      count = @scope.count
      csv = CSV.generate(headers: true) do |row|
        row << HEADERS
        @scope.find_each do |t|
          row << [
            t.id,
            t.number,
            t.title,
            t.description,
            t.customer&.email,
            t.agent&.email,
            t.status.humanize,
            t.created_at&.strftime("%Y-%m-%d %H:%M:%S"),
            t.first_response_at&.strftime("%Y-%m-%d %H:%M:%S"),
            t.closed_at&.strftime("%Y-%m-%d %H:%M:%S"),
            t.priority,
            t.category
          ]
        end
      end


      [ csv, count ]
    rescue StandardError => e
      Rails.logger.error("CSV export error: #{e.message}")
      []
    end
  end
end
