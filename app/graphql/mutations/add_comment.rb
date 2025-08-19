module Mutations
  class AddComment < BaseMutation
    argument :ticket_id, String, required: true
    argument :body, String, required: true

    field :ticket, Types::TicketType, null: true
    field :errors, [ String ], null: false

    def resolve(ticket_id:, body:)
      ticket = Ticket.find_by(id: ticket_id)
      current_user = context[:current_user]

      if ticket.nil?
        return { ticket: nil, errors: [ "Ticket not found" ] }
      end

      # Check permissions and business rules
      permission_check = can_comment_on_ticket?(ticket, current_user)
      unless permission_check[:allowed]
        return { ticket: nil, errors: [ permission_check[:error] ] }
      end

      # Use transaction to ensure consistency between comment creation and state changes
      result = nil

      Ticket.transaction do
        # Create the comment
        comment = ticket.comments.build(body: body, author: current_user)

        unless comment.save
          raise ActiveRecord::Rollback, comment.errors.full_messages
        end

        # Handle state transition and agent_has_replied field updates
        state_change_result = handle_comment_and_state_transition(ticket, current_user)

        unless state_change_result[:success]
          Rails.logger.warn("Comment added but state/field updates failed for ticket #{ticket.id}: #{state_change_result[:errors]}")
        end

        result = {
          comment: comment,
          ticket: ticket.reload,
          errors: state_change_result[:errors] || []
        }
      end

      result || { ticket: nil, errors: [ "Failed to add comment" ] }

    rescue ActiveRecord::Rollback => e
      { ticket: nil, errors: Array(e.message).flatten }
    rescue StandardError => e
      { ticket: nil, errors: [ "An unexpected error occurred: #{e.message}" ] }
    end

    private

    def can_comment_on_ticket?(ticket, user)
      # Customer-specific rules
      if user_is_customer?(ticket, user)
        return check_customer_comment_permissions(ticket, user)
      end

      # Agent-specific rules
      if user.agent?
        return check_agent_comment_permissions(ticket, user)
      end

      # Other roles cannot comment
      { allowed: false, error: "You don't have permission to comment on this ticket" }
    end

    def check_customer_comment_permissions(ticket, user)
      # Customer can only comment on their own tickets
      unless ticket.customer == user
        return { allowed: false, error: "You can only comment on your own tickets" }
      end

      # Customer cannot comment on in_progress ticket unless agent has replied
      if ticket.in_progress? && !ticket.agent_has_replied?
        return {
          allowed: false,
          error: "You cannot comment on this ticket until an agent has responded"
        }
      end

      { allowed: true, error: nil }
    end

    def check_agent_comment_permissions(ticket, user)
      # Agent must be assigned to the ticket to comment
      unless ticket.agent == user
        if ticket.agent.present?
          return {
            allowed: false,
            error: "This ticket is assigned to #{ticket.agent.name}. Only the assigned agent can comment."
          }
        else
          return {
            allowed: false,
            error: "You must assign this ticket to yourself before commenting."
          }
        end
      end

      { allowed: true, error: nil }
    end

    def user_can_access_ticket?(ticket, user)
      # Customer can view their own tickets
      return true if ticket.customer == user

      # Assigned agent can access
      return true if ticket.agent == user

      # Any agent/admin can VIEW tickets (but commenting has separate rules)
      return true if user.agent?

      false
    end

    def user_is_customer?(ticket, user)
      ticket.customer == user
    end

    def handle_comment_and_state_transition(ticket, user)
      if user_is_customer?(ticket, user)
        handle_customer_comment(ticket)
      elsif user.agent?
        handle_agent_comment(ticket, user)
      else
        # Other roles don't trigger changes
        { success: true, errors: [] }
      end
    end

    def handle_customer_comment(ticket)
      errors = []

      # Customer replied - trigger state transition based on current state
      case ticket.status.to_sym
      when :waiting_on_customer
        # Customer replied while we were waiting - move to in_progress
        unless ticket.customer_replies!
          errors.concat(ticket.errors.full_messages)
        end
      when :resolved
        # Customer replied to resolved ticket - reopen it
        unless ticket.customer_replies!
          errors.concat(ticket.errors.full_messages)
        end
      end

      { success: errors.empty?, errors: errors }
    end

    def handle_agent_comment(ticket, agent)
      errors = []

      # Double-check agent assignment (should be caught by permissions but extra safety)
      unless ticket.agent == agent
        return { success: false, errors: [ "Agent must be assigned to ticket before commenting" ] }
      end

      # Agent responded - update agent_has_replied and trigger state transition
      ticket.agent_has_replied = true
      ticket.first_response_at = Time.current

      unless ticket.save
        errors.concat(ticket.errors.full_messages)
        return { success: false, errors: errors }
      end

      # Trigger state transition based on current state
      case ticket.status.to_sym
      when :in_progress, :reopened
        # Agent responded during in_progress or reopened - move to waiting_on_customer
        unless ticket.agent_responds!(agent)
          errors.concat(ticket.errors.full_messages)
        end
      when :open
        # This shouldn't happen since we check assignment, but handle gracefully
        errors << "Cannot comment on unassigned ticket"
        return { success: false, errors: errors }
      else
        # Other states - no transition needed but agent_has_replied is still updated
      end

      { success: errors.empty?, errors: errors }
    end
  end
end
