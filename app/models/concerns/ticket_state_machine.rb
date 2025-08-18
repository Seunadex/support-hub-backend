module TicketStateMachine
  extend ActiveSupport::Concern

  included do
    include AASM
    enum :status, { open: 0, in_progress: 1, waiting_on_customer: 2, resolved: 3, closed: 4, reopened: 5 }

    aasm column: :status, enum: true do
      state :open, initial: true
      state :in_progress, :waiting_on_customer, :resolved, :closed, :reopened

      # Assign ticket to agent
      event :assign do
        transitions from: [ :open, :reopened ], to: :in_progress

        after do
          # Any additional logic after assignment
        end
      end

      # Agent responds to customer
      event :agent_respond do
        transitions from: [ :in_progress, :reopened ], to: :waiting_on_customer

        after do
          # Log agent response, send notification to customer
        end
      end

      # Customer replies back
      event :customer_reply do
        transitions from: [ :waiting_on_customer, :resolved ], to: :in_progress

        after do
          # Log customer response, notify agent
        end
      end

      # Mark ticket as resolved
      event :resolve do
        transitions from: [ :in_progress, :waiting_on_customer ], to: :resolved

        after do |*args|
          self.resolved_at = Time.current
          self.resolved_by = args.first if args.first
        end
      end

      # Close resolved ticket
      event :close do
        transitions from: [ :resolved, :in_progress, :waiting_on_customer ], to: :closed

        after do
          self.closed_at = Time.current
        end
      end

      # Reopen closed ticket
      event :reopen do
        transitions from: [ :closed, :resolved ], to: :reopened

        after do
          self.reopened_at = Time.current
          self.closed_at = nil
          self.resolved_at = nil
          self.resolved_by = nil
        end
      end
    end

    # Fixed assign_agent method
    def assign_agent(agent)
      with_lock do
        if may_assign?
          self.agent = agent
          assign!
          save!
        else
          errors.add(:base, "Cannot assign ticket in current state: #{status}")
          false
        end
      end
    rescue AASM::InvalidTransition => e
      errors.add(:base, "Invalid state transition: #{e.message}")
      false
    end

    # Method to handle agent responses
    def agent_responds!(agent = nil)
      with_lock do
        if may_agent_respond?
          agent_respond!
          save!
        else
          errors.add(:base, "Cannot mark agent response in current state: #{status}")
          false
        end
      end
    rescue AASM::InvalidTransition => e
      errors.add(:base, "Invalid state transition: #{e.message}")
      false
    end

    # Method to handle customer replies
    def customer_replies!
      with_lock do
        if may_customer_reply?
          customer_reply!
          save!
        else
          errors.add(:base, "Cannot mark customer reply in current state: #{status}")
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
        else
          errors.add(:base, "Cannot close ticket in current state: #{status}")
          false
        end
      end
    rescue AASM::InvalidTransition => e
      errors.add(:base, "Invalid state transition: #{e.message}")
      false
    end

    # Method to reopen ticket
    def reopen_ticket!(reason = nil)
      with_lock do
        if may_reopen?
          reopen!
          self.reopen_reason = reason if reason
          save!
        else
          errors.add(:base, "Cannot reopen ticket in current state: #{status}")
          false
        end
      end
    rescue AASM::InvalidTransition => e
      errors.add(:base, "Invalid state transition: #{e.message}")
      false
    end

    # Query methods for UI/business logic
    def assignable?
      may_assign?
    end

    def can_agent_respond?
      may_agent_respond?
    end

    def can_customer_reply?
      may_customer_reply?
    end

    def resolvable?
      may_resolve?
    end

    def closable?
      may_close?
    end

    def reopenable?
      may_reopen?
    end

    # Status helper methods
    def active?
      !closed?
    end

    def needs_agent_attention?
      open? || reopened? || in_progress?
    end

    def waiting_for_customer?
      waiting_on_customer?
    end

    def completed?
      resolved? || closed?
    end
  end
end
