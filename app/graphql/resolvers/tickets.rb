module Resolvers
  class Tickets < BaseResolver
    def self.resolve_many(current_user)
      TicketPolicy::Scope.new(current_user, Ticket).resolve
    end
  end
end
