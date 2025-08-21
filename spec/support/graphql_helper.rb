module GraphqlHelper
  def gql(query, variables: {}, context: {})
    SupportHubBackendSchema.execute(query, variables: variables, context: context).to_h
  end
end

RSpec.configure { |c| c.include GraphqlHelper }
