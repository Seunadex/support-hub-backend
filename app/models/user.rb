class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :jwt_authenticatable, jwt_revocation_strategy: JwtDenylist

  has_many :tickets, dependent: :destroy
  has_many :requested_tickets, class_name: "Ticket", foreign_key: "customer_id", dependent: :nullify
  has_many :assigned_tickets, class_name: "Ticket", foreign_key: "agent_id", dependent: :nullify
  has_many :comments, dependent: :destroy

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
