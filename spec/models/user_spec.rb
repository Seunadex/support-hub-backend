require 'rails_helper'

RSpec.describe User, type: :model do
    # Associations
    it { should have_many(:requested_tickets).class_name('Ticket').with_foreign_key('customer_id').inverse_of(:customer).dependent(:nullify) }
  it { should have_many(:assigned_tickets).class_name('Ticket').with_foreign_key('agent_id').inverse_of(:agent).dependent(:nullify) }
  it { should have_many(:comments).with_foreign_key('author_id').inverse_of(:author).dependent(:destroy) }

  # Validations
  it { should validate_presence_of(:email) }
  it { should validate_uniqueness_of(:email).case_insensitive }
  it { should validate_presence_of(:first_name) }
  it { should validate_length_of(:first_name).is_at_least(2).is_at_most(50) }
  it { should validate_presence_of(:last_name) }
  it { should validate_length_of(:last_name).is_at_least(2).is_at_most(50) }
  it { should validate_presence_of(:password) }
  it { should validate_length_of(:password).is_at_least(6) }

  describe 'email format' do
    it 'is invalid with incorrect email format' do
      user = User.new(email: 'invalid_email', first_name: 'Test', last_name: 'User', password: 'password')
      expect(user).not_to be_valid
      expect(user.errors[:email]).to include('is invalid')
    end

    it 'is valid with correct email format' do
      user = User.new(email: 'test@example.com', first_name: 'Test', last_name: 'User', password: 'password')
      user.validate
      expect(user.errors[:email]).to be_empty
    end
  end
end
