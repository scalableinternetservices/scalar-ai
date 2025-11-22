class ExpertAssignment < ApplicationRecord
  # Associations
  belongs_to :conversation
  belongs_to :expert, class_name: "User", foreign_key: "expert_id"

  # Validations
  validates :status, presence: true, inclusion: { in: %w[active resolved] }
  validates :assigned_at, presence: true

  # Callbacks
  before_validation :set_assigned_at, on: :create

  private

  def set_assigned_at
    self.assigned_at ||= Time.current
  end
end
