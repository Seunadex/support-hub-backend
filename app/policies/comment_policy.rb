class CommentPolicy < ApplicationPolicy
  def index?
    TicketPolicy.new(user, record.ticket).show?
  end

  def create?
    # Use the ticket policy's comment? method for authorization
    TicketPolicy.new(user, record.ticket).comment?
  end

  def show?
    TicketPolicy.new(user, record.ticket).show?
  end

  class Scope < Scope
    def resolve
      ticket_scope = Pundit.policy_scope!(user, Ticket)
      scope.joins(:ticket).merge(ticket_scope)
    end
  end
end
