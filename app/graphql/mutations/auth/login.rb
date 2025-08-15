module Mutations
  module Auth
    class Login < Mutations::BaseMutation
      argument :email, String, required: true
      argument :password, String, required: true

      field :token, String, null: true
      field :user, Types::UserType, null: true
      field :errors, [ String ], null: false

      def resolve(email:, password:)
        user = User.find_for_database_authentication(email: email)

        if user&.valid_password?(password)
          token = Warden::JWTAuth::UserEncoder.new.call(user, :user, nil).first
          { user: user, token: token, errors: [] }
        else
          { user: nil, token: nil, errors: [ "Invalid email or password" ] }
        end
      end
    end
  end
end
