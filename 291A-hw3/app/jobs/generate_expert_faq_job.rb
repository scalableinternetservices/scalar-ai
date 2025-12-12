# frozen_string_literal: true

# Job to generate an expert FAQ based on the expert's knowledge base links.
class GenerateExpertFaqJob < ApplicationJob
  queue_as :default

  def perform(expert_profile_id)
    expert_profile = ExpertProfile.find_by(id: expert_profile_id)
    return unless expert_profile

    faq_text = ExpertFaqService.generate_faq(expert_profile)
    expert_profile.update!(expert_faq: faq_text)
  end
end
