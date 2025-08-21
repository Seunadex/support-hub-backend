require "rails_helper"

RSpec.describe Mutations::CreateTicket, type: :mutation do
  let(:customer) { create(:user, :customer) }
  let(:agent)    { create(:user, :agent) }

  let(:query) do
    <<~GRAPHQL
      mutation($input: CreateTicketInput!) {
        createTicket(input: $input) {
          ticket { id title description status priority category attachments { id filename } }
          errors
        }
      }
    GRAPHQL
  end

  def gql_exec(variables:, user:)
    gql(query, variables: variables, context: { current_user: user })
  end

  def fake_upload(name:, size_bytes:, content_type: "image/png")
    double(
      "Upload",
      original_filename: name,
      size: size_bytes,
      content_type: content_type
    )
  end

  it "rejects blank fields" do
    variables = { input: { title: " ", description: " ", priority: "low", category: "billing" } }
    res = gql_exec(variables: variables, user: customer)
    data = res["data"]["createTicket"]

    expect(data["ticket"]).to be_nil
    expect(data["errors"]).to include("Title can't be blank", "Description can't be blank")
  end

  it "denies unauthorized role via policy" do
    variables = { input: { title: "A", description: "B", priority: "normal", category: "billing" } }
    res = gql_exec(variables: variables, user: agent)
    data = res["data"]["createTicket"]

    expect(data["ticket"]).to be_nil
    expect(data["errors"]).to include("Not authorized")
  end

  it "creates a ticket" do
    variables = { input: { title: "A", description: "B", priority: "normal", category: "technical_issues" } }
    res = gql_exec(variables: variables, user: customer)
    data = res["data"]["createTicket"]

    expect(data["errors"]).to eq([])
    expect(data["ticket"]["title"]).to eq("A")
  end

  context "attachments" do
    it "rejects more than the maximum number" do
      allow(ApolloUploadServer::Upload).to receive(:coerce_input).and_return(double("Upload", tempfile: Tempfile.new, original_filename: "test.png", content_type: "image/png"))
      files = [
        fake_upload(name: "a.png", size_bytes: 1000),
        fake_upload(name: "b.png", size_bytes: 1000),
        fake_upload(name: "c.png", size_bytes: 1000),
        fake_upload(name: "d.png", size_bytes: 1000)
      ]
      variables = { input: { title: "A", description: "B", attachments: files, priority: "normal", category: "billing" } }

      res = gql_exec(variables: variables, user: customer)
      data = res["data"]["createTicket"]

      expect(data["ticket"]).to be_nil
      expect(data["errors"]).to include("You can upload a maximum of 3 files.")
    end

    it "rejects unsupported content types" do
      allow(ApolloUploadServer::Upload).to receive(:coerce_input).and_return(double("Upload", tempfile: Tempfile.new, original_filename: "bad.txt", content_type: "text/plain"))
      files = [
        fake_upload(name: "bad.txt", size_bytes: 500, content_type: "text/plain")
      ]
      variables = { input: { title: "A", description: "B", attachments: files, priority: "high", category: "billing" } }

      res = gql_exec(variables: variables, user: customer)
      data = res["data"]["createTicket"]

      expect(data["ticket"]).to be_nil
      expect(data["errors"].join).to include("File bad.txt has an invalid type. Allowed types are: image/jpeg, image/png, application/pdf.")
    end

    it "rejects files that are too large" do
      size = 15 * 1024 * 1024
      allow(ApolloUploadServer::Upload).to receive(:coerce_input).and_return(double("Upload", tempfile: Tempfile.new, original_filename: "huge.pdf", content_type: "application/pdf", size: size))
      files = [ fake_upload(name: "huge.pdf", size_bytes: size, content_type: "application/pdf") ]
      variables = { input: { title: "A", description: "B", attachments: files, priority: "high", category: "billing" } }

      res = gql_exec(variables: variables, user: customer)
      data = res["data"]["createTicket"]

      expect(data["ticket"]).to be_nil
      expect(data["errors"]).to include("File huge.pdf is too large. Max size is 10 MB.")
    end

    it "attaches valid files" do
      allow(ApolloUploadServer::Upload).to receive(:coerce_input).and_return(double("Upload", tempfile: Tempfile.new, original_filename: "tiny.pdf", content_type: "application/pdf"))
      file = fixture_file_upload(Rails.root.join("spec/fixtures/files", "tiny.pdf"), "application/pdf")
      variables = { input: { title: "title", description: "description", attachments: [ file ], priority: "normal", category: "billing" } }

      res = gql_exec(variables: variables, user: customer)
      data = res["data"]["createTicket"]

      expect(data["errors"]).to eq([])
      expect(data["ticket"]).to include("title" => "title")

      ticket_id = data["ticket"]["id"]
      ticket = Ticket.find(ticket_id)
      expect(ticket.attachments.count).to eq(1)
    end
  end


  it "handles unexpected exceptions with a stable error and logs details" do
    variables = { input: { title: "A", description: "B", priority: "normal", category: "billing" } }

    # # Stub logger to avoid noisy output and assert logging happens
    logger_double = instance_double(Logger)
    allow(Rails).to receive(:logger).and_return(logger_double)
    allow(logger_double).to receive(:error)

    # Force a StandardError from inside the mutation body
    allow_any_instance_of(Mutations::CreateTicket).to receive(:build_attachments).and_raise(StandardError, "boom")

    res = gql_exec(variables: variables, user: customer)
    data = res["data"]["createTicket"]

    expect(data["ticket"]).to be_nil
    expect(data["errors"]).to include("Unexpected error while creating ticket")

    # Ensure we logged the exception class/message at least once
    expect(logger_double).to have_received(:error).at_least(:once)
  end
end
