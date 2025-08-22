module Resolvers
  class TicketStatCount < BaseResolver
    def self.resolve(current_user)
      scope = Pundit.policy_scope!(current_user, Ticket)
      {
        total: scope.count,
        open: scope.open.count,
        pending: scope.pending.count,
        completed: scope.completed.count
      }
    end
  end
end
