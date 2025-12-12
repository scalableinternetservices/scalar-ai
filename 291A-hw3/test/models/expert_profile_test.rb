# frozen_string_literal: true

require "test_helper"

class ExpertProfileTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  def setup
    @user = User.create!(username: "expert3", password: "password")
  end

  def teardown
    clear_enqueued_jobs
    ExpertProfile.delete_all
    User.delete_all
  end

  test "enqueues FAQ generation on create" do
    assert_enqueued_with(job: GenerateExpertFaqJob) do
      ExpertProfile.create!(user: @user, knowledge_base_links: [ "https://example.com" ])
    end
  end

  test "enqueues FAQ generation when knowledge_base_links change" do
    profile = ExpertProfile.create!(user: @user, knowledge_base_links: [ "https://example.com" ])

    assert_enqueued_with(job: GenerateExpertFaqJob, args: [ profile.id ]) do
      profile.update!(knowledge_base_links: [ "https://example.com/updated" ])
    end
  end

  test "does not enqueue FAQ generation when unrelated attributes change" do
    profile = ExpertProfile.create!(user: @user, knowledge_base_links: [ "https://example.com" ])

    assert_no_enqueued_jobs(only: GenerateExpertFaqJob) do
      profile.update!(bio: "New bio")
    end
  end

  test "cached_experts_with_bios returns experts with non-empty bios" do
    # Create experts with and without bios
    user1 = User.create!(username: "expert_with_bio", password: "password")
    user2 = User.create!(username: "expert_without_bio", password: "password")

    profile1 = ExpertProfile.create!(user: user1, bio: "I am an expert")
    profile2 = ExpertProfile.create!(user: user2, bio: nil)

    Rails.cache.clear
    cached_experts = ExpertProfile.cached_experts_with_bios

    assert_equal 1, cached_experts.size
    assert_equal profile1.id, cached_experts.first.id
  end

  test "cached_experts_with_bios uses cache on subsequent calls" do
    user1 = User.create!(username: "expert1", password: "password")
    ExpertProfile.create!(user: user1, bio: "Expert 1")

    Rails.cache.clear

    # First call should populate cache
    first_call = ExpertProfile.cached_experts_with_bios

    # Second call should use cache (verified by checking cache hit)
    assert Rails.cache.exist?(ExpertProfile::EXPERTS_WITH_BIOS_CACHE_KEY)
    second_call = ExpertProfile.cached_experts_with_bios

    assert_equal first_call.size, second_call.size
  end

  test "cache is cleared when expert profile is created" do
    user1 = User.create!(username: "expert1", password: "password")
    ExpertProfile.create!(user: user1, bio: "Expert 1")

    Rails.cache.clear
    ExpertProfile.cached_experts_with_bios
    assert Rails.cache.exist?(ExpertProfile::EXPERTS_WITH_BIOS_CACHE_KEY)

    # Create new profile should clear cache
    user2 = User.create!(username: "expert2", password: "password")
    ExpertProfile.create!(user: user2, bio: "Expert 2")

    assert_not Rails.cache.exist?(ExpertProfile::EXPERTS_WITH_BIOS_CACHE_KEY)
  end

  test "cache is cleared when expert profile is updated" do
    profile = ExpertProfile.create!(user: @user, bio: "Original bio")

    Rails.cache.clear
    ExpertProfile.cached_experts_with_bios
    assert Rails.cache.exist?(ExpertProfile::EXPERTS_WITH_BIOS_CACHE_KEY)

    # Update should clear cache
    profile.update!(bio: "Updated bio")

    assert_not Rails.cache.exist?(ExpertProfile::EXPERTS_WITH_BIOS_CACHE_KEY)
  end

  test "cache is cleared when expert profile is destroyed" do
    profile = ExpertProfile.create!(user: @user, bio: "Bio")

    Rails.cache.clear
    ExpertProfile.cached_experts_with_bios
    assert Rails.cache.exist?(ExpertProfile::EXPERTS_WITH_BIOS_CACHE_KEY)

    # Destroy should clear cache
    profile.destroy!

    assert_not Rails.cache.exist?(ExpertProfile::EXPERTS_WITH_BIOS_CACHE_KEY)
  end
end
