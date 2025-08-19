module Types
  class TicketStatCountType < Types::BaseObject
    field :total, Integer, null: false, description: "Total number of tickets"
    field :open, Integer, null: false, description: "Number of open tickets"
    field :pending, Integer, null: false, description: "Number of pending tickets (in progress or waiting on customer)"
    field :resolved, Integer, null: false, description: "Number of resolved tickets"
  end
end
