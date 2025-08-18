class RemoveColumnFromTicket < ActiveRecord::Migration[8.0]
  def change
    remove_reference :tickets, :user, index: true, foreign_key: true
  end
end
