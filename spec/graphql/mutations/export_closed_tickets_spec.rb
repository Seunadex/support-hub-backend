require "rails_helper"

RSpec.describe Mutations::ExportClosedTickets, type: :mutation do
  let(:agent)    { create(:user, :agent) }
  let(:customer) { create(:user, :customer) }

  let(:query) do
    <<~GRAPHQL
      mutation($start: ISO8601DateTime!, $end: ISO8601DateTime!) {
        exportClosedTickets(input: { startDate: $start, endDate: $end }) {
          filename
          count
          csvUrl
          errors
        }
      }
    GRAPHQL
  end

  def exec_mutation(start_time:, end_time:, user:)
    gql(
      query,
      variables: { start: start_time.iso8601, end: end_time.iso8601 },
      context: { current_user: user }
    )
  end

  it "requires an agent" do
    start_time = 1.month.ago
    end_time   = Time.zone.now

    res = exec_mutation(start_time: start_time, end_time: end_time, user: nil)
    data = res.dig("data", "exportClosedTickets")

    expect(data["filename"]).to be_nil
    expect(data["csvUrl"]).to be_nil
    expect(data["count"]).to eq(0)
    expect(data["errors"]).to include("Unauthorized")

    res2 = exec_mutation(start_time: start_time, end_time: end_time, user: customer)
    data2 = res2.dig("data", "exportClosedTickets")
    expect(data2["errors"]).to include("Unauthorized")
  end

  it "returns no data when no closed tickets are found" do
    start_time = 2.days.ago.change(usec: 0)
    end_time   = Time.zone.now.change(usec: 0)

    res = exec_mutation(start_time: start_time, end_time: end_time, user: agent)
    data = res.dig("data", "exportClosedTickets")

    expect(data["filename"]).to be_nil
    expect(data["csvUrl"]).to be_nil
    expect(data["count"]).to eq(0)
    expect(data["errors"]).to include("No closed tickets found")
  end

  it "exports closed tickets in range and returns filename, count, and url" do
    t1 = create(:ticket, status: :closed, closed_at: 3.days.ago)
    t2 = create(:ticket, status: :closed, closed_at: 2.days.ago)
    _t3 = create(:ticket, status: :closed, closed_at: 10.days.ago) # out of range

    start_time = 4.days.ago.change(usec: 0)
    end_time   = 1.day.ago.change(usec: 0)

    generator_double = instance_double(Exports::ClosedTicketsCsv)
    allow(Exports::ClosedTicketsCsv).to receive(:new).and_return(generator_double)
    allow(generator_double).to receive(:call).and_return([ "id,title\n#{t1.id},A\n#{t2.id},B\n", 2 ])

    blob_double = instance_double(ActiveStorage::Blob)
    allow(ActiveStorage::Blob).to receive(:create_and_upload!).and_return(blob_double)
    allow(Rails.application.routes.url_helpers).to receive(:rails_blob_url).with(blob_double).and_return("http://test.local/blobs/csv")

    allow(SecureRandom).to receive(:hex).with(4).and_return("etl4")

    res = exec_mutation(start_time: start_time, end_time: end_time, user: agent)
    data = res.dig("data", "exportClosedTickets")

    expect(data["errors"]).to eq([])
    expect(data["count"]).to eq(2)
    expect(data["csvUrl"]).to eq("http://test.local/blobs/csv")

    from_ts = start_time.strftime("%Y%m%d%H%M%S")
    to_ts   = end_time.strftime("%Y%m%d%H%M%S")
    expect(data["filename"]).to eq("closed_tickets_#{from_ts}_to_#{to_ts}_etl4.csv")
  end

  it "returns a failure when CSV generation returns nil" do
    create(:ticket, status: :closed, closed_at: 2.days.ago)

    start_time = 3.days.ago
    end_time   = 1.day.ago

    generator_double = instance_double(Exports::ClosedTicketsCsv)
    allow(Exports::ClosedTicketsCsv).to receive(:new).and_return(generator_double)
    allow(generator_double).to receive(:call).and_return([ nil, 0 ])

    res = exec_mutation(start_time: start_time, end_time: end_time, user: agent)
    data = res.dig("data", "exportClosedTickets")

    expect(data["filename"]).to be_nil
    expect(data["csvUrl"]).to be_nil
    expect(data["count"]).to eq(0)
    expect(data["errors"]).to include("Failed to generate closed tickets CSV")
  end

  it "handles unexpected exceptions with a stable error and logs" do
    create(:ticket, status: :closed, closed_at: 2.days.ago)

    start_time = 3.days.ago
    end_time   = 1.day.ago

    logger_double = instance_double(Logger)
    allow(Rails).to receive(:logger).and_return(logger_double)
    allow(logger_double).to receive(:error)

    allow(Exports::ClosedTicketsCsv).to receive(:new).and_raise(StandardError, "boom")

    res = exec_mutation(start_time: start_time, end_time: end_time, user: agent)
    data = res.dig("data", "exportClosedTickets")

    expect(data["filename"]).to be_nil
    expect(data["csvUrl"]).to be_nil
    expect(data["count"]).to eq(0)
    expect(data["errors"]).to include("Failed to generate closed tickets CSV")
    expect(logger_double).to have_received(:error).at_least(:once)
  end

  it "filters by closed_at range only" do
    in_range  = create(:ticket, status: :closed, closed_at: 10.hours.ago)
    out_range = create(:ticket, status: :closed, closed_at: 20.days.ago)

    start_time = 2.days.ago
    end_time   = Time.zone.now

    seen_scope = nil
    allow(Exports::ClosedTicketsCsv).to receive(:new) do |args|
      seen_scope = args[:scope]
      instance_double(Exports::ClosedTicketsCsv, call: [ "csv", 1 ])
    end

    allow(ActiveStorage::Blob).to receive(:create_and_upload!).and_return(instance_double(ActiveStorage::Blob))
    allow(Rails.application.routes.url_helpers).to receive(:rails_blob_url).and_return("http://x")

    res = exec_mutation(start_time: start_time, end_time: end_time, user: agent)

    # The scope should include the in_range ticket and exclude the out_range ticket
    expect(seen_scope).to be_present
    ids = seen_scope.pluck(:id)
    expect(ids).to include(in_range.id)
    expect(ids).not_to include(out_range.id)

    data = res.dig("data", "exportClosedTickets")
    expect(data["errors"]).to eq([])
  end
end
