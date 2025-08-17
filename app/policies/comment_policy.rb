class CommentPolicy < ApplicationPolicy
  def index?
    # Listing comments is allowed if the user can view the ticket
    TicketPolicy.new(user, record.ticket).show?
  end
  def create?
    return false if record.ticket.closed?
    return false unless TicketPolicy.new(user, record.ticket).show?

    if agent?
      true
    elsif customer?
      # Customers can create comments if they own the ticket and the agent has replied
      owns_ticket = record.ticket.customer_id == user.id
      owns_ticket && record.ticket.agent_has_replied?
    else
      false
    end
  end

  def show?
    # A comment is visible if the parent ticket is visible
    TicketPolicy.new(user, record.ticket).show?
  end

  class Scope < Scope
    def resolve
      ticket_scope = Pundit.policy_scope!(user, Ticket)
      scope.joins(:ticket).merge(ticket: ticket_scope)
    end
  end
end
