FactoryBot.define do
  factory :user do
    first_name { Faker::Name.first_name }
    last_name  { Faker::Name.last_name }
    email      { Faker::Internet.unique.email }
    password   { "Password1!" }

    trait :agent do
      role { :agent }
    end

    trait :customer do
      role { :customer }
    end
  end
end
