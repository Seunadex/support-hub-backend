FactoryBot.define do
  factory :ticket do
    title       { Faker::Lorem.sentence(word_count: 4) }
    description { Faker::Lorem.paragraph(sentence_count: 3) }
    priority    { %i[low normal high urgent].sample }
    category    { %i[billing technical_issues account feature_request feedback other].sample }
    status      { :open }

    association :customer, factory: [ :user, :customer ]
  end
end
