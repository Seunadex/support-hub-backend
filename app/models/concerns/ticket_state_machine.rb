module TicketStateMachine
  extend ActiveSupport::Concern

  included do
    include AASM
    enum :status, { open: 0, in_progress: 1, waiting_on_customer: 2, resolved: 3, closed: 4 }

    aasm column: :status, enum: true do
      state :open, initial: true
      state :in_progress, :waiting_on_customer, :resolved, :closed

      # Open → In Progress: Agent assigns ticket to themselves
      event :assign do
        transitions from: :open, to: :in_progress
      end

      # In Progress → Waiting on Customer: Agent sends first response
      event :agent_respond do
        transitions from: [ :in_progress ], to: :waiting_on_customer

        after do
          # Mark first agent response only once
          self.first_response_at ||= Time.current
          self.agent_has_replied = true unless agent_has_replied?
        end
      end

      # Waiting on Customer → In Progress: Customer replies back
      event :customer_reply do
        transitions from: :waiting_on_customer, to: :in_progress
      end

      # In Progress → Resolved: Agent marks as resolved
      event :resolve do
        transitions from: :in_progress, to: :resolved
      end

      # Resolved → Closed: Formal closure
      # In Progress → Closed: Early closure without resolution
      # Waiting on Customer → Closed: Closure due to inactivity
      event :close do
        transitions from: [ :resolved, :in_progress, :waiting_on_customer ], to: :closed

        after do
          self.closed_at = Time.current
        end
      end
    end

    # Method to assign agent and transition state
    def assign_to_agent!(agent)
      with_lock do
        if may_assign?
          self.agent = agent
          assign!
          save!
          true
        else
          errors.add(:base, "Cannot assign ticket in current state: #{status}")
          false
        end
      end
    rescue AASM::InvalidTransition => e
      errors.add(:base, "Invalid state transition: #{e.message}")
      false
    end

    # Method to handle agent response and state transition
    def agent_responds!
      with_lock do
        if may_agent_respond?
          agent_respond!
          save!
          true
        else
          errors.add(:base, "Cannot respond in current state: #{status}")
          false
        end
      end
    rescue AASM::InvalidTransition => e
      errors.add(:base, "Invalid state transition: #{e.message}")
      false
    end

    # Method to handle customer reply and state transition
    def customer_replies!
      with_lock do
        if may_customer_reply?
          customer_reply!
          save!
          true
        else
          errors.add(:base, "Cannot reply in current state: #{status}")
          false
        end
      end
    rescue AASM::InvalidTransition => e
      errors.add(:base, "Invalid state transition: #{e.message}")
      false
    end

    # Method to resolve ticket
    def resolve_ticket!(resolved_by_agent = nil)
      with_lock do
        if may_resolve?
          resolve!(resolved_by_agent)
          save!
          true
        else
          errors.add(:base, "Cannot resolve ticket in current state: #{status}")
          false
        end
      end
    rescue AASM::InvalidTransition => e
      errors.add(:base, "Invalid state transition: #{e.message}")
      false
    end

    # Method to close ticket
    def close_ticket!
      with_lock do
        if may_close?
          close!
          save!
          true
        else
          errors.add(:base, "Cannot close ticket in current state: #{status}")
          false
        end
      end
    rescue AASM::InvalidTransition => e
      errors.add(:base, "Invalid state transition: #{e.message}")
      false
    end

    # Status helper methods
    def active?
      !closed?
    end

    def needs_agent_attention?
      open? || in_progress?
    end

    def completed?
      resolved? || closed?
    end
  end
end
