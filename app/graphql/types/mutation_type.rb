# frozen_string_literal: true

module Types
  class MutationType < Types::BaseObject
    field :signup, mutation: Mutations::Auth::Signup
    field :login, mutation: Mutations::Auth::Login
    field :create_ticket, mutation: Mutations::CreateTicket
    field :assign_ticket, mutation: Mutations::AssignTicket
    field :add_comment, mutation: Mutations::AddComment
  end
end
