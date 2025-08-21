class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :jwt_authenticatable, jwt_revocation_strategy: self

  has_many :tickets, dependent: :destroy
  has_many :requested_tickets, class_name: "Ticket", foreign_key: "customer_id", inverse_of: :customer, dependent: :nullify
  has_many :assigned_tickets, class_name: "Ticket", foreign_key: "agent_id", inverse_of: :agent, dependent: :nullify
  has_many :comments, foreign_key: "author_id", inverse_of: :author, dependent: :destroy

  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :first_name, presence: true, length: { minimum: 2, maximum: 50 }
  validates :last_name, presence: true, length: { minimum: 2, maximum: 50 }
  validates :password, presence: true, length: { minimum: 6 }

  enum :role, { customer: 0, agent: 1 }

  def self.jwt_revoked?(payload, user)
    user.jwt_denylist.exist?(jti: payload["jti"])
  end

  def jwt_payload
    {
      sub: id,
      email: email,
      role: role,
      exp: 24.hours.from_now.to_i,
      jti: SecureRandom.uuid,
      aud: "support-hub"
    }
  end

  def full_name
    "#{first_name} #{last_name}"
  end
end
