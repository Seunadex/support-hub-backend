class TicketPolicy < ApplicationPolicy
  def index?
    user.present?
  end

  def show?
    agent? || own_ticket?
  end

  def create?
    user.present?
  end

  def update?
    agent?
  end

  def assign?
    agent?
  end

  def destroy?
    agent?
  end

  def comment?
    return false unless show? # Must be able to view ticket to comment
    return false if record.closed? # No comments on closed tickets

    if agent?
      agent_can_comment?
    elsif customer?
      customer_can_comment?
    else
      false
    end
  end

  def can_close?
    return false unless show?
    return false if record.closed?

    if agent?
      record.agent_id == user.id # Only assigned agent can close from any non-closed state
    elsif customer?
      own_ticket? && record.resolved? # Customer can only close their own ticket if it's resolved
    else
      false
    end
  end

  def can_resolve?
    return false unless show?
    return false if record.resolved? || record.closed?

    if agent?
      record.agent_id == user.id && [ :in_progress, :waiting_on_customer, :reopened ].include?(record.status.to_sym)
    else
      false
    end
  end

  def agent_can_comment?
    case record.status.to_sym
    when :open
      false # Agent must assign ticket first
    when :in_progress, :waiting_on_customer
      record.agent_id == user.id # Only assigned agent can comment
    when :resolved
      record.agent_id == user.id # Only assigned agent can comment on resolved tickets
    when :closed
      false # No comments on closed tickets
    else
      false
    end
  end

  def customer_can_comment?
    return false unless own_ticket?

    case record.status.to_sym
    when :open
      false # Ticket must be assigned first
    when :in_progress
      record.agent_has_replied? # Must wait for agent's first response
    when :waiting_on_customer
      true # Customer can reply
    when :resolved, :closed
      false # No comments on resolved/closed tickets
    else
      false
    end
  end

  private

  def own_ticket?
    user.present? && record.customer_id == user.id
  end


  class Scope < Scope
    def resolve
      return scope.all.order(created_at: :desc) if user&.agent?
      scope.where(customer_id: user&.id).order(created_at: :desc)
    end
  end
end
