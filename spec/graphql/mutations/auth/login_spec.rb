require "rails_helper"

RSpec.describe Mutations::Auth::Login, type: :mutation do
  let(:user) { create(:user, password: "Password1!") }

  let(:query) do
    <<~GRAPHQL
      mutation($email: String!, $password: String!) {
        login(input: { email: $email, password: $password }) {
          token
          user { id email }
          errors
        }
      }
    GRAPHQL
  end

  def exec_mutation(email:, password:)
    gql(query, variables: { email: email, password: password }, context: {})
  end

  it "returns token and user when credentials are correct" do
    res = exec_mutation(email: user.email, password: "Password1!")
    data = res.dig("data", "login")

    expect(data["errors"]).to eq([])
    expect(data["token"]).to be_present
    expect(data.dig("user", "id")).to eq(user.id.to_s)
    expect(data.dig("user", "email")).to eq(user.email)
  end

  it "returns error when password is invalid" do
    res = exec_mutation(email: user.email, password: "wrong")
    data = res.dig("data", "login")

    expect(data["token"]).to be_nil
    expect(data["user"]).to be_nil
    expect(data["errors"]).to include("Invalid email or password")
  end

  it "returns error when email not found" do
    res = exec_mutation(email: "noone@example.com", password: "Password1!")
    data = res.dig("data", "login")

    expect(data["token"]).to be_nil
    expect(data["user"]).to be_nil
    expect(data["errors"]).to include("Invalid email or password")
  end
end
