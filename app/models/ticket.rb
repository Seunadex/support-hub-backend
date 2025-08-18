class Ticket < ApplicationRecord
  belongs_to :customer, class_name: "User"
  belongs_to :agent, class_name: "User", optional: true
  has_many :comments, dependent: :destroy
  has_many_attached :attachments

  before_validation :set_number, on: :create

  validates :title, presence: true
  validates :description, presence: true
  validates :number, presence: true, uniqueness: true
  validate :attachment_constraints

  enum :status, { open: 0, in_progress: 1, waiting_on_customer: 2, resolved: 3, closed: 4, reopened: 5 }
  enum :priority, { low: 0, normal: 1, high: 2, urgent: 3 }
  enum :category, { technical_issues: 0, billing: 1, account: 2, feature_request: 3, feedback: 4, other: 5 }

  private

  def set_number
    self.number = "SPT-#{SecureRandom.hex(5)}"
  end


  def attachment_constraints
    return unless attachments.attached?

    if attachments.count > 3
      errors.add(:attachments, "You can only upload a maximum of 3 attachments")
    end

    attachments.each do |att|
      if att.blob.byte_size > 10.megabytes
        errors.add(:attachments, "each attachment must be less than 10MB")
      end

      acceptable_types = %w[image/jpeg image/png application/pdf]
      unless att.content_type.in?(acceptable_types)
        errors.add(:attachments, "must be a JPEG, PNG, or PDF file")
      end
    end
  end
end
