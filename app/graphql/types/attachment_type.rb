module Types
  class AttachmentType < Types::BaseObject
    field :id, ID, null: false
    field :filename, String, null: false
    field :content_type, String, null: true
    field :byte_size, Integer, null: true
    field :url, String, null: false
    field :created_at, GraphQL::Types::ISO8601DateTime, null: true


    def filename
      object.filename.to_s
    end

    def content_type
      object.content_type
    end

    def byte_size
      object.byte_size
    end

    def created_at
      object.created_at
    end

    def url
      Rails.application.routes.url_helpers.rails_blob_url(object)
    end
  end
end
