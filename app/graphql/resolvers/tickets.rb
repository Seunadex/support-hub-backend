module Resolvers
  class Tickets < BaseResolver
    def self.resolve(id, current_user)
      return unless TicketPolicy.new(current_user, Ticket).show?
      Ticket.find(id)
    end

    def self.resolve_many(current_user)
      TicketPolicy::Scope.new(current_user, Ticket).resolve
    end
  end
end
