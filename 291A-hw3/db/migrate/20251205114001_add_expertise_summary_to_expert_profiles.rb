class AddExpertiseSummaryToExpertProfiles < ActiveRecord::Migration[8.1]
  def change
    add_column :expert_profiles, :expertise_summary, :text
  end
end
