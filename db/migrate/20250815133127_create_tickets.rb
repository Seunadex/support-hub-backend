class CreateTickets < ActiveRecord::Migration[8.0]
  def change
    create_table :tickets do |t|
      t.string :title, null: false
      t.text :description, null: false
      t.integer :status, default: 0
      t.integer :priority, default: 0
      t.integer :category, default: 0
      t.string :number, null: false
      t.datetime :closed_at
      t.datetime :first_response_at
      t.datetime :reopened_at
      t.boolean :agent_has_replied, default: false
      t.references :user, null: false, foreign_key: true
      t.references :customer, null: false, foreign_key: { to_table: :users }
      t.references :agent, foreign_key: { to_table: :users }

      t.timestamps
    end

    add_index :tickets, :status
    add_index :tickets, :priority
    add_index :tickets, :category
    add_index :tickets, :number, unique: true
  end
end
