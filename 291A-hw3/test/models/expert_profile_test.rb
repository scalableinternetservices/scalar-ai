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
end
