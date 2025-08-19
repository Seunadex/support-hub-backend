class Ticket < ApplicationRecord
  include TicketStateMachine

  belongs_to :customer, class_name: "User"
  belongs_to :agent, class_name: "User", optional: true
  has_many :comments, dependent: :destroy
  has_many_attached :attachments

  before_validation :set_number, on: :create

  validates :title, presence: true
  validates :description, presence: true
  validates :number, presence: true, uniqueness: true
  validate :attachment_constraints
  validate :agent_required_for_in_progress

  enum :priority, { low: 0, normal: 1, high: 2, urgent: 3 }
  enum :category, { technical_issues: 0, billing: 1, account: 2, feature_request: 3, feedback: 4, other: 5 }

  # Scopes for different states
  scope :active, -> { where.not(status: :closed) }
  scope :needs_attention, -> { where(status: [ :open, :reopened, :in_progress ]) }
  scope :waiting_for_customer, -> { where(status: :waiting_on_customer) }
  scope :pending, -> { where(status: [ :in_progress, :waiting_on_customer ]) }
  scope :completed, -> { where(status: [ :resolved, :closed ]) }

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

  def agent_required_for_in_progress
    if in_progress? && agent.blank?
      errors.add(:agent, "must be assigned when ticket is in progress")
    end
  end
end
