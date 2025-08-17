class TickerPolicy < ApplicationPolicy
  def index?
    user.present?
  end

  def show?
    agent? || own_ticket?
  end

  def create?
    # Both agents and customers can create tickets
    # Agents may create on behalf of customers or file internal tickets
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

  def own_ticket?
    user.present? && record.customer_id == user.id
  end

  class Scope < Scope
    def resolve
      return scope.all if user&.agent?

      # Customers can only see their own tickets
      scope.where(customer_id: user&.id)
    end
  end
end
