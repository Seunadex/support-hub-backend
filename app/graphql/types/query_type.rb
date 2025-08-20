# frozen_string_literal: true

module Types
  class QueryType < Types::BaseObject
    field :current_user, Types::UserType, null: true

    def current_user
      context[:current_user]
    end

    field :tickets, [ Types::TicketType ], null: false
    description "Fetch all tickets scoped to the current user"

    def tickets
      Resolvers::Tickets.resolve_many(context[:current_user])
    end

    field :ticket, Types::TicketType, null: true do
      argument :id, ID, required: true
    end

    def ticket(id:)
      Resolvers::Tickets.resolve(id, context[:current_user])
    end

    field :ticket_stat_count, Types::TicketStatCountType, null: false
    description "Fetch ticket statistics for the current user"

    def ticket_stat_count
      Resolvers::TicketStatCount.resolve(context[:current_user])
    end
  end
end
