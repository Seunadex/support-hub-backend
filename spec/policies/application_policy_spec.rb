

# spec/policies/application_policy_spec.rb
require "rails_helper"

RSpec.describe ApplicationPolicy do
  let(:user) { build_stubbed(:user) }
  let(:record) { double(:record) }

  subject(:policy) { described_class.new(user, record) }

  describe "default actions" do
    it { expect(policy.index?).to eq(false) }
    it { expect(policy.show?).to eq(false) }
    it { expect(policy.create?).to eq(false) }
    it { expect(policy.new?).to eq(false) }
    it { expect(policy.update?).to eq(false) }
    it { expect(policy.edit?).to eq(false) }
    it { expect(policy.destroy?).to eq(false) }
  end

  describe "role helpers" do
    it "returns true for agent when user is agent" do
      agent = build_stubbed(:user, role: :agent)
      expect(described_class.new(agent, record).agent?).to eq(true)
      expect(described_class.new(agent, record).customer?).to eq(false)
    end

    it "returns true for customer when user is customer" do
      customer = build_stubbed(:user, role: :customer)
      expect(described_class.new(customer, record).customer?).to eq(true)
      expect(described_class.new(customer, record).agent?).to eq(false)
    end
  end

  describe "Scope" do
    let(:scope) { Ticket.all }

    it "returns none by default" do
      resolved = ApplicationPolicy::Scope.new(user, scope).resolve
      expect(resolved).to eq(Ticket.none)
    end
  end
end
