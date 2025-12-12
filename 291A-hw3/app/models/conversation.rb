class Conversation < ApplicationRecord
  # Associations
  belongs_to :initiator, class_name: "User", foreign_key: "initiator_id"
  belongs_to :assigned_expert, class_name: "User", foreign_key: "assigned_expert_id", optional: true
  has_many :messages, dependent: :destroy
  has_many :expert_assignments, dependent: :destroy

  # Validations
  validates :title, presence: true
  validates :status, presence: true, inclusion: { in: %w[waiting active resolved] }

  # Callbacks
  before_validation :set_default_status, on: :create

  def unread_count_for(user)
    messages.where.not(sender_id: user.id).where(is_read: false).count
  end

  private

  def set_default_status
    self.status ||= "waiting"
  end
end
