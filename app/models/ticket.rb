class Ticket < ApplicationRecord
  belongs_to :user
  belongs_to :customer, class_name: "User"
  belongs_to :agent, class_name: "User", optional: true
end
