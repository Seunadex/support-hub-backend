module Resolvers
  class TicketStatCount < BaseResolver
    def self.resolve(current_user)
      scope = TicketPolicy::Scope.new(current_user, Ticket).resolve
      {
        total: scope.count,
        open: scope.open.count,
        pending: scope.pending.count,
        resolved: scope.resolved.count
      }
    end
  end
end
