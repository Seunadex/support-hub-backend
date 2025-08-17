module Resolvers
  class CurrentUser < BaseResolver
    def resolve
      context[:current_user]
    end
  end
end
