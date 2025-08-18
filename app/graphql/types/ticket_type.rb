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
    field :reopened_at, GraphQL::Types::ISO8601DateTime, null: true
    field :closed_at, GraphQL::Types::ISO8601DateTime, null: true
    field :first_response_at, GraphQL::Types::ISO8601DateTime, null: true
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: false
    field :assigned_to, Types::UserType, null: true
    field :attachments, [ Types::AttachmentType ], null: false

    def attachments
      object.attachments.attached? ? object.attachments : []
    end

    def assigned_to
      object.agent
    end
  end
end
