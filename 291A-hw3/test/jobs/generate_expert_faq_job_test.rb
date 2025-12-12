# frozen_string_literal: true

require "test_helper"

class GenerateExpertFaqJobTest < ActiveJob::TestCase
  def setup
    @user = User.create!(username: "expert2", password: "password")
    @profile = ExpertProfile.create!(
      user: @user,
      knowledge_base_links: [ "https://example.com" ]
    )
  end

  def teardown
    clear_enqueued_jobs
    ExpertProfile.delete_all
    User.delete_all
  end

  test "updates expert_faq from generated content" do
    ExpertFaqService.expects(:generate_faq).with(@profile).returns("Generated FAQ")

    perform_enqueued_jobs do
      GenerateExpertFaqJob.perform_later(@profile.id)
    end

    assert_equal "Generated FAQ", @profile.reload.expert_faq
  end

  test "does nothing when profile is missing" do
    ExpertFaqService.expects(:generate_faq).never

    perform_enqueued_jobs do
      GenerateExpertFaqJob.perform_later("non-existent-id")
    end
  end
end
