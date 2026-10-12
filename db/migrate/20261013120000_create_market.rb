# The Market plugin's tables, prefixed with its key. Clients, users and todos are the core's,
# pointed at by id.
class CreateMarket < ActiveRecord::Migration[8.1]
  def change
    create_table :market_industries do |t|
      t.string :name, null: false
      t.string :naics_code
      t.text :description
      t.text :notes
      t.timestamps
      t.index :name, unique: true
    end

    create_table :market_profiles do |t|
      t.integer :client_id, null: false, index: { unique: true }
      t.references :industry, foreign_key: { to_table: :market_industries }
      t.string :website
      t.string :domain
      t.text :service_area
      t.text :offerings
      t.text :audience
      t.text :positioning
      t.text :goals
      t.text :notes
      t.timestamps
    end

    create_table :market_competitors do |t|
      t.string :name, null: false
      t.string :website
      t.string :domain, index: true
      t.references :industry, foreign_key: { to_table: :market_industries }
      t.text :strengths
      t.text :weaknesses
      t.text :notes
      t.timestamps
    end

    create_table :market_rivalries do |t|
      t.integer :client_id, null: false
      t.references :competitor, null: false, foreign_key: { to_table: :market_competitors }
      t.string :kind, null: false, default: "direct"
      t.string :threat, null: false, default: "medium"
      t.text :notes
      t.timestamps
      t.index %i[client_id competitor_id], unique: true
    end

    create_table :market_snapshots do |t|
      t.string :subject_type, null: false
      t.integer :subject_id, null: false
      t.string :domain, null: false
      t.text :facts
      t.text :differences
      t.text :error
      t.datetime :taken_at, null: false
      t.timestamps
      t.index %i[subject_type subject_id taken_at]
    end

    create_table :market_plans do |t|
      t.integer :client_id, null: false, index: true
      t.integer :user_id, null: false
      t.string :state, null: false, default: "queued"
      t.text :summary
      t.text :positioning
      t.text :industry_suggestion
      t.text :competitor_suggestions
      t.text :error
      t.datetime :started_at
      t.datetime :finished_at
      t.timestamps
    end

    create_table :market_opportunities do |t|
      t.integer :client_id, null: false, index: true
      t.references :plan, foreign_key: { to_table: :market_plans }
      t.string :channel, null: false
      t.string :title, null: false
      t.text :detail
      t.text :evidence
      t.string :impact, null: false, default: "medium"
      t.string :effort, null: false, default: "medium"
      t.string :horizon, null: false, default: "next"
      t.string :state, null: false, default: "open"
      t.integer :todo_id, index: true
      t.string :decided_by_name
      t.datetime :decided_at
      t.timestamps
    end
  end
end
