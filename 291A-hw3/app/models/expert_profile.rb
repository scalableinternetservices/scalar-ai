class ExpertProfile < ApplicationRecord
  belongs_to :user

  validates :user_id, presence: true, uniqueness: true

  # Regenerate expertise summary when needed
  def regenerate_summary
    GenerateExpertiseSummaryJob.perform_later(id)
  end
end
