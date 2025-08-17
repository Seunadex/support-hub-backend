class Ticket < ApplicationRecord
  belongs_to :user
  belongs_to :customer, class_name: "User"
  belongs_to :agent, class_name: "User", optional: true
  has_many :comments, dependent: :destroy

  validates :title, presence: true
  validates :description, presence: true
  validates :number, presence: true, uniqueness: true

  enum :status, { open: 0, pending: 1, closed: 2 }
  enum :priority, { low: 0, normal: 1, high: 2, urgent: 3 }
  enum :category, { feature: 0, bug: 1, support: 2 }
end
