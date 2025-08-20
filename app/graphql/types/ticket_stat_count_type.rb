module Types
  class TicketStatCountType < Types::BaseObject
    field :total, Integer, null: false, description: "Total number of tickets"
    field :open, Integer, null: false, description: "Number of open tickets"
    field :pending, Integer, null: false, description: "Number of pending tickets (in progress or waiting on customer)"
    field :completed, Integer, null: false, description: "Number of completed tickets"
  end
end
