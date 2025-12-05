class ExpertAssignment < ApplicationRecord
  # Associations
  belongs_to :conversation
  belongs_to :expert, class_name: "User", foreign_key: "expert_id"

  # Validations
  validates :status, presence: true, inclusion: { in: %w[active resolved] }
  validates :assigned_at, presence: true

  # Callbacks
  before_validation :set_assigned_at, on: :create
  after_update :regenerate_expert_summary, if: :became_resolved?

  private

  def set_assigned_at
    self.assigned_at ||= Time.current
  end

  def became_resolved?
    saved_change_to_status? && status == "resolved"
  end

  def regenerate_expert_summary
    # Regenerate expert summary only when assignment becomes resolved
    expert_profile = ExpertProfile.find_by(user_id: expert_id)
    expert_profile&.regenerate_summary
  end
end
