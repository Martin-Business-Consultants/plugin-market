require_relative "../test_helper"

module Market
  class ProfileTest < ActiveSupport::TestCase
    test "an industry by name is found or made, and cleared with a blank" do
      profile = Profile.for(clients(:acme))
      assert profile.revise(industry_name: "Residential  plumbing", website: "https://www.acme.example/")
      assert_equal "Residential plumbing", profile.industry.name
      assert_equal "acme.example", profile.domain

      other = Profile.for(clients(:globex))
      other.revise(industry_name: "residential plumbing")
      assert_equal profile.industry, other.industry
      assert_equal 1, Industry.count

      profile.revise(industry_name: "")
      assert_nil profile.reload.industry
    end

    test "gaps say what a good plan still needs" do
      profile = Profile.for(clients(:acme))
      assert_equal [ "industry", "website", "service area", "what they sell", "who they serve", "goals" ], profile.gaps

      profile.revise(industry_name: "Plumbing", website: "https://acme.example", service_area: "Springfield", offerings: "Drains", audience: "Homeowners", goals: "More calls")
      assert_empty profile.gaps
    end
  end
end
