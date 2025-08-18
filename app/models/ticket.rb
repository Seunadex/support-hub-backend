class Ticket < ApplicationRecord
  belongs_to :customer, class_name: "User"
  belongs_to :agent, class_name: "User", optional: true
  has_many :comments, dependent: :destroy

  before_validation :set_number, on: :create

  validates :title, presence: true
  validates :description, presence: true
  validates :number, presence: true, uniqueness: true

  enum :status, { open: 0, in_progress: 1, waiting_on_customer: 2, resolved: 3, closed: 4, reopened: 5 }
  enum :priority, { low: 0, normal: 1, high: 2, urgent: 3 }
  enum :category, { technical_issues: 0, billing: 1, account: 2, feature_request: 3, feedback: 4, other: 5 }


  def set_number
    self.number = "SPT-#{SecureRandom.hex(5)}"
  end
end
