require 'rails_helper'

RSpec.describe Ticket, type: :model do
  describe 'associations' do
    it { should belong_to(:customer) }
    it { should belong_to(:agent).optional }
    it { should have_many(:comments).dependent(:destroy) }
  end

  describe 'validations' do
    it { should validate_presence_of(:title) }
    it { should validate_presence_of(:description) }
  end

  describe 'scopes' do
    before do
      @open_ticket = create(:ticket, status: 'open')
      @closed_ticket = create(:ticket, status: 'closed')
    end

    it 'returns open tickets' do
      expect(Ticket.open).to include(@open_ticket)
      expect(Ticket.open).not_to include(@closed_ticket)
    end

    it 'returns closed tickets' do
      expect(Ticket.closed).to include(@closed_ticket)
      expect(Ticket.closed).not_to include(@open_ticket)
    end
  end

  describe 'callbacks' do
    it 'sets default status to open on create' do
      ticket = Ticket.create(title: 'Test', description: 'Test desc', priority: 'low', customer: create(:user))
      expect(ticket.status).to eq('open')
    end
  end
end
