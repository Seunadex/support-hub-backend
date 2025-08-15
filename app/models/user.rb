class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :jwt_authenticatable, jwt_revocation_strategy: JwtDenylist

  enum :role, { customer: 0, agent: 1 }

  def self.jwt_revoked?(payload, user)
    user.jwt_denylist.exist?(jti: payload["jti"])
  end

  def jwt_payload
    {
      sub: id,
      email: email,
      role: role,
      exp: 1.hour.from_now.to_i,
      jti: SecureRandom.uuid,
      aud: "support-hub"
    }
  end
end
