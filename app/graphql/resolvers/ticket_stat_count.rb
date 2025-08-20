module Resolvers
  class TicketStatCount < BaseResolver
    def self.resolve(current_user)
      scope = TicketPolicy::Scope.new(current_user, Ticket).resolve
      {
        total: scope.count,
        open: scope.open.count,
        pending: scope.pending.count,
        completed: scope.completed.count
      }
    end
  end
end
