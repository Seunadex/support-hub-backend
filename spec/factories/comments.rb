FactoryBot.define do
  factory :comment do
    body { Faker::Lorem.sentence }
    association :author
    association :ticket
  end
end
