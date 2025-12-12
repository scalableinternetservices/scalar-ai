class AddExpertFaqToExpertProfiles < ActiveRecord::Migration[8.1]
  def change
    add_column :expert_profiles, :expert_faq, :text
  end
end
