# Search data from DataForSEO: the connection (one row, its password encrypted), every request
# made with what it cost, the pulls that make them, what each pull found per website, the
# keywords tracked for a client and where each website ranked for them. A client's profile gets
# the place its searches are checked from. Findings are what all of it says.
class CreateMarketSearch < ActiveRecord::Migration[8.1]
  def change
    create_table :market_settings do |t|
      t.string :dataforseo_login
      t.text :dataforseo_password
      t.integer :monthly_budget_cents, null: false, default: 2500
      t.string :country, null: false, default: "United States"
      t.string :language_code, null: false, default: "en"
      t.string :refresh, null: false, default: "off"
      t.integer :keyword_limit, null: false, default: 200
      t.boolean :backlinks, null: false, default: false
      t.decimal :balance, precision: 12, scale: 4
      t.datetime :checked_at
      t.text :last_error
      t.timestamps
    end

    create_table :market_search_pulls do |t|
      t.integer :client_id, null: false, index: true
      t.integer :user_id
      t.string :state, null: false, default: "queued"
      t.boolean :force, null: false, default: false
      t.decimal :cost, precision: 12, scale: 4, null: false, default: 0
      t.text :notes
      t.text :error
      t.datetime :started_at
      t.datetime :finished_at
      t.timestamps
    end

    create_table :market_search_requests do |t|
      t.references :pull, foreign_key: { to_table: :market_search_pulls }
      t.string :endpoint, null: false
      t.string :target
      t.integer :status_code
      t.string :status_message
      t.decimal :cost, precision: 12, scale: 4, null: false, default: 0
      t.integer :attempts, null: false, default: 1
      t.integer :duration_ms
      t.text :error
      t.datetime :created_at, null: false
      t.index :created_at
    end

    create_table :market_search_snapshots do |t|
      t.string :subject_type, null: false
      t.integer :subject_id, null: false
      t.references :pull, foreign_key: { to_table: :market_search_pulls }
      t.string :domain, null: false
      t.string :kind, null: false
      t.string :location
      t.text :data
      t.datetime :taken_at, null: false
      t.timestamps
      t.index %i[subject_type subject_id kind taken_at], name: "index_market_search_snapshots_on_subject_kind"
    end

    create_table :market_keywords do |t|
      t.integer :client_id, null: false
      t.string :keyword, null: false
      t.string :source, null: false, default: "manual"
      t.timestamps
      t.index %i[client_id keyword], unique: true
    end

    create_table :market_rankings do |t|
      t.references :keyword, null: false, foreign_key: { to_table: :market_keywords }
      t.references :pull, foreign_key: { to_table: :market_search_pulls }
      t.string :location, null: false
      t.integer :client_position
      t.string :client_url
      t.text :results
      t.text :features
      t.datetime :checked_at, null: false
      t.timestamps
      t.index %i[keyword_id checked_at]
    end

    # What the data says about a client's market, worked out after every reading and pull: one
    # row per finding (key is stable, e.g. "keyword_gap:rival.example"), kept while it holds and
    # marked resolved when it stops, so a harness can ask what's new since it last looked.
    create_table :market_findings do |t|
      t.integer :client_id, null: false
      t.string :key, null: false
      t.string :kind, null: false
      t.string :severity, null: false
      t.string :channel
      t.string :title, null: false
      t.text :detail
      t.text :evidence
      t.text :sources
      t.datetime :first_seen_at, null: false
      t.datetime :last_seen_at, null: false
      t.datetime :changed_at, null: false
      t.datetime :resolved_at
      t.datetime :dismissed_at
      t.string :dismissed_by_name
      t.timestamps
      t.index %i[client_id key], unique: true
      t.index :changed_at
    end

    add_column :market_profiles, :search_location, :string
    add_column :market_plans, :keyword_suggestions, :text
  end
end
