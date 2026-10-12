require_relative "../test_helper"

module Market
  class ProbeTest < ActiveSupport::TestCase
    HTML = <<~HTML
      <html><head><title> Rival Plumbing |  Emergency plumbers </title>
      <meta name="description" content="24/7 plumbers in Springfield.">
      <meta name="generator" content="WordPress 6.6">
      <script async src="https://www.googletagmanager.com/gtag/js?id=AW-123456789"></script>
      <script>fbq('init', '123');</script>
      <script src="https://cdn.callrail.com/swap.js"></script>
      <script type="application/ld+json">{"@context":"https://schema.org","@graph":[{"@type":"Plumber"},{"@type":"WebSite"}]}</script>
      </head><body><h1>Plumbers <em>you</em> can trust</h1>
      <a href="tel:+1 (555) 010-0100">Call</a>
      <a href="https://www.facebook.com/rivalplumbing">Facebook</a><a href="https://www.facebook.com/sharer/sharer.php">Share</a>
      <a href="https://instagram.com/rival">Instagram</a>
      <form action="/contact"></form></body></html>
    HTML

    test "domains come without the scheme, path or www" do
      assert_equal "example.com", Probe.normalize("https://www.Example.com/about")
      assert_equal "example.com", Probe.normalize("example.com")
      assert_nil Probe.normalize(" ")
    end

    test "a home page says what it runs and how it presents itself" do
      home = Probe.new("rival.example").read_home(HTML)

      assert_equal "Rival Plumbing | Emergency plumbers", home["title"]
      assert_equal "24/7 plumbers in Springfield.", home["description"]
      assert_equal [ "Plumbers you can trust" ], home["headings"]
      assert_equal "WordPress 6.6", home["platform"]
      assert_equal %w[google_ads meta_pixel call_tracking], home["tools"]
      assert_equal %w[facebook instagram], home["socials"].keys
      assert_equal "https://www.facebook.com/rivalplumbing", home["socials"]["facebook"]
      assert_equal %w[Plumber WebSite], home["schema_types"]
      assert_equal [ "15550100100" ], home["phone_numbers"]
      assert_equal 1, home["forms"]
    end

    test "a sitemap counts pages, posts, locations and services, and how fresh they are" do
      today = Date.new(2026, 10, 13)
      entries = [
        [ "https://rival.example/", today - 2 ],
        [ "https://rival.example/blog/winter-pipes", today - 10 ],
        [ "https://rival.example/blog/old-news", today - 400 ],
        [ "https://rival.example/locations/springfield", nil ],
        [ "https://rival.example/services/drains", nil ]
      ]
      sitemap = Probe.new("rival.example", today: today).read_sitemap(entries, url: "https://rival.example/sitemap.xml")

      assert_equal 5, sitemap["pages"]
      assert_equal 2, sitemap["posts"]
      assert_equal 1, sitemap["posts_last_90_days"]
      assert_equal 1, sitemap["locations"]
      assert_equal 1, sitemap["services"]
      assert_equal "2026-10-11", sitemap["last_changed"]
    end
  end
end
