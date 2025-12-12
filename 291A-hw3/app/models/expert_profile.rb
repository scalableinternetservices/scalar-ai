class ExpertProfile < ApplicationRecord
  belongs_to :user

  validates :user_id, presence: true, uniqueness: true

  after_commit :enqueue_expert_faq_generation, on: [ :create, :update ]
  after_commit :clear_experts_with_bios_cache, on: [ :create, :update, :destroy ]

  # Cache key for experts with bios
  EXPERTS_WITH_BIOS_CACHE_KEY = "expert_profiles/with_bios"
  CACHE_TTL = 5.minutes

  # Returns all expert profiles with non-empty bios (cached)
  def self.cached_experts_with_bios
    Rails.cache.fetch(EXPERTS_WITH_BIOS_CACHE_KEY, expires_in: CACHE_TTL) do
      # Load experts with their associated users
      ExpertProfile.includes(:user).where.not(bio: [ nil, "" ]).to_a
    end
  end

  # Clear the experts with bios cache
  def self.clear_experts_with_bios_cache
    Rails.cache.delete(EXPERTS_WITH_BIOS_CACHE_KEY)
  end

  private

  def enqueue_expert_faq_generation
    if saved_change_to_id? || saved_change_to_knowledge_base_links?
      GenerateExpertFaqJob.perform_later(id)
    end
  end

  def clear_experts_with_bios_cache
    self.class.clear_experts_with_bios_cache
  end
end
