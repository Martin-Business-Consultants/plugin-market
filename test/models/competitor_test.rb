require_relative "../test_helper"

module Market
  class CompetitorTest < ActiveSupport::TestCase
    test "one competitor per website, found by domain or name" do
      rival = Competitor.create!(name: "Rival", website: "https://www.rival.example/")
      assert_equal "rival.example", rival.domain

      duplicate = Competitor.new(name: "Rival again", website: "http://rival.example/contact")
      assert_not duplicate.valid?
      assert_includes duplicate.errors[:website].first, "Rival"

      assert_equal rival, Competitor.matching(name: "Anything", website: "rival.example")
      assert_equal rival, Competitor.matching(name: " rival ")
      assert_nil Competitor.matching(name: "Nobody", website: "nobody.example")
    end

    test "it's due a reading when it has a website and none this week" do
      rival = Competitor.create!(name: "Rival", website: "https://rival.example")
      assert rival.check_due?
      read(rival)
      assert_not rival.reload.check_due?
      assert_not Competitor.create!(name: "No site").check_due?
    end
  end
end
