class ExpertProfile < ApplicationRecord
  belongs_to :user

  validates :user_id, presence: true, uniqueness: true

  after_commit :enqueue_expert_faq_generation, on: [ :create, :update ]

  private

  def enqueue_expert_faq_generation
    if saved_change_to_id? || saved_change_to_knowledge_base_links?
      GenerateExpertFaqJob.perform_later(id)
    end
  end
end
