module Mutations
  module Auth
    class Signup < Mutations::BaseMutation
      argument :first_name, String, required: true
      argument :last_name, String, required: true
      argument :email, String, required: true
      argument :password, String, required: true

      field :token, String, null: true
      field :user, Types::UserType, null: true
      field :errors, [ String ], null: false

      def resolve(first_name:, last_name:, email:, password:)
        user = User.new(first_name: first_name, last_name: last_name, email: email, password: password)

        if user.save
          token = JWT.encode(user.jwt_payload, Warden::JWTAuth.config.secret, "HS256")
          { user: user, token: token, errors: [] }
        else
          { user: nil, token: nil, errors: user.errors.full_messages }
        end
      end
    end
  end
end
