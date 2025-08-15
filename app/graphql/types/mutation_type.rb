# frozen_string_literal: true

module Types
  class MutationType < Types::BaseObject
    field :signup, mutation: Mutations::Auth::Signup
    field :login, mutation: Mutations::Auth::Login
  end
end
