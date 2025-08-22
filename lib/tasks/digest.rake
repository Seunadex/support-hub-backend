namespace :digest do
  desc "Send daily open-tickets digest to agents"
  task daily: :environment do
    DailyOpenTicketsDigestJob.perform_later
  end
end
