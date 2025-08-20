module Types
  class TicketType < Types::BaseObject
    field :id, ID, null: false
    field :title, String, null: false
    field :description, String, null: false
    field :priority, String, null: true
    field :status, String, null: false
    field :number, String, null: false
    field :category, String, null: false
    field :customer, Types::UserType, null: false
    field :agent_has_replied, Boolean, null: false
    field :reopened_at, GraphQL::Types::ISO8601DateTime, null: true
    field :closed_at, GraphQL::Types::ISO8601DateTime, null: true
    field :first_response_at, GraphQL::Types::ISO8601DateTime, null: true
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false
    field :assigned_to, Types::UserType, null: true
    field :attachments, [ Types::AttachmentType ], null: false
    field :comments, [ Types::CommentType ], null: false
    field :can_close, Boolean, null: false
    field :can_resolve, Boolean, null: false
    field :agent_can_comment, Boolean, null: false
    field :customer_can_comment, Boolean, null: false

    def attachments
      object.attachments.attached? ? object.attachments : []
    end

    def assigned_to
      object.agent
    end

    def can_close
      TicketPolicy.new(context[:current_user], object).can_close?
    end

    def can_resolve
      TicketPolicy.new(context[:current_user], object).can_resolve?
    end

    def agent_can_comment
      TicketPolicy.new(context[:current_user], object).agent_can_comment?
    end

    def customer_can_comment
      TicketPolicy.new(context[:current_user], object).customer_can_comment?
    end
  end
end
