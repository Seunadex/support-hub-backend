module Authorization
  extend ActiveSupport::Concern

  private

  def current_user
    context[:current_user]
  end

  def authorize!(record, query = nil)
    policy = Pundit.policy!(current_user, record)
    allowed = policy.public_send("#{query}")
    raise GraphQL::ExecutionError, "Not authorized" unless allowed
  end

  def policy_scope!(scope_klass)
    Pundit.policy_scope!(current_user, scope_klass)
  end
end
