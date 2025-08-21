require "rails_helper"

RSpec.describe Mutations::Auth::Signup, type: :mutation do
  let(:query) do
    <<~GRAPHQL
      mutation($first: String!, $last: String!, $email: String!, $password: String!) {
        signup(input: { firstName: $first, lastName: $last, email: $email, password: $password }) {
          token
          user { id email firstName lastName }
          errors
        }
      }
    GRAPHQL
  end

  def exec_mutation(first:, last:, email:, password:)
    gql(
      query,
      variables: { first: first, last: last, email: email, password: password },
      context: {}
    )
  end

  it "creates a user and returns token and user fields" do
    res = exec_mutation(first: "Jane", last: "Doe", email: "jane@example.com", password: "Password1!")
    data = res.dig("data", "signup")

    expect(data["errors"]).to eq([])
    expect(data["token"]).to be_present
    expect(data.dig("user", "email")).to eq("jane@example.com")
    expect(User.find_by(email: "jane@example.com")).to be_present
  end

  it "returns errors when validation fails" do
    res = exec_mutation(first: "", last: "", email: "bademail", password: "")
    data = res.dig("data", "signup")

    expect(data["user"]).to be_nil
    expect(data["token"]).to be_nil
    expect(data["errors"]).to be_present
  end

  it "rejects duplicate email" do
    create(:user, email: "taken@example.com")

    res = exec_mutation(first: "John", last: "Smith", email: "taken@example.com", password: "Password1!")
    data = res.dig("data", "signup")

    expect(data["user"]).to be_nil
    expect(data["token"]).to be_nil
    expect(data["errors"]).to include("Email has already been taken")
  end
end
