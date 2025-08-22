module Resolvers
  class Tickets < BaseResolver
    def self.resolve(id, current_user)
      Ticket.find(id)
    end

    def self.resolve_many(current_user)
      Pundit.policy_scope!(current_user, Ticket)
    end
  end
end
