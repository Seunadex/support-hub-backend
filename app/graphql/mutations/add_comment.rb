module Mutations
  class AddComment < BaseMutation
    argument :ticket_id, ID, required: true
    argument :body, String, required: true

    field :ticket, Types::TicketType, null: true
    field :errors, [ String ], null: false

    def resolve(ticket_id:, body:)
      ticket = find_ticket(ticket_id)
      return ticket_not_found_response unless ticket

      return unauthorized_response unless current_user

      # Use Pundit for authorization
      unless TicketPolicy.new(current_user, ticket).comment?
        return unauthorized_response
      end

      # Process comment creation and state transitions
      process_comment_and_transitions(ticket, current_user, body)
    end

    private

    def find_ticket(ticket_id)
      Ticket.find_by(id: ticket_id)
    end

    def customer?(ticket, user)
      ticket.customer_id == user.id
    end

    def process_comment_and_transitions(ticket, user, body)
      result = { ticket: nil, errors: [] }

      Ticket.transaction do
        # Create comment - let model handle validation
        comment = create_comment(ticket, user, body)
        return rollback_with_errors(comment.errors.full_messages) unless comment.persisted?

        # Handle state transitions
        transition_result = execute_state_transition(ticket, user)

        if transition_result[:success]
          result = {
            ticket: ticket.reload,
            errors: []
          }
        else
          # Comment was saved but transition failed - log warning but don't rollback
          Rails.logger.warn(
            "Comment #{comment.id} created but state transition failed for ticket #{ticket.id}: " \
            "#{transition_result[:errors].join(', ')}"
          )
          result = {
            ticket: ticket.reload,
            errors: transition_result[:errors]
          }
        end
      end

      result
    rescue StandardError => e
      Rails.logger.error("Unexpected error in AddComment mutation: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      { ticket: nil, errors: [ "An unexpected error occurred. Please try again." ] }
    end

    def create_comment(ticket, user, body)
      ticket.comments.create!(
        body: body,
        author: user
      )
    rescue ActiveRecord::RecordInvalid => e
      # Return invalid record so we can check errors
      e.record
    end

    def execute_state_transition(ticket, user)
      return customer_state_transition(ticket) if customer?(ticket, user)
      return agent_state_transition(ticket) if user.agent?

      { success: true, errors: [] }
    end

    def customer_state_transition(ticket)
      return no_transition_needed unless ticket.waiting_on_customer?

      if ticket.customer_replies!
        { success: true, errors: [] }
      else
        { success: false, errors: ticket.errors.full_messages }
      end
    end

    def agent_state_transition(ticket)
      return no_transition_needed unless ticket.in_progress?

      if ticket.agent_responds!
        { success: true, errors: [] }
      else
        { success: false, errors: ticket.errors.full_messages }
      end
    end

    def rollback_with_errors(errors)
      raise ActiveRecord::Rollback, errors.join(", ")
    end

    def no_transition_needed
      { success: true, errors: [] }
    end

    # Response helpers
    def ticket_not_found_response
      { ticket: nil, errors: [ "Ticket not found" ] }
    end

    def unauthorized_response(message = "Access denied")
      { ticket: nil, errors: [ message ] }
    end
  end
end
