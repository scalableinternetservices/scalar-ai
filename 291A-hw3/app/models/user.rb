class User < ApplicationRecord
  has_secure_password

  # Associations
  has_one :expert_profile, dependent: :destroy
  has_many :initiated_conversations, class_name: "Conversation", foreign_key: "initiator_id", dependent: :destroy
  has_many :assigned_conversations, class_name: "Conversation", foreign_key: "assigned_expert_id"
  has_many :messages, foreign_key: "sender_id", dependent: :destroy
  has_many :expert_assignments, foreign_key: "expert_id", dependent: :destroy

  # Validations
  validates :username, presence: true, uniqueness: true
  validates :password, length: { minimum: 6 }, if: -> { new_record? || !password.nil? }

  # Callbacks
  before_create :set_last_active_at

  def is_expert?
    expert_profile.present?
  end

  private

  def set_last_active_at
    self.last_active_at = Time.current
  end
end
