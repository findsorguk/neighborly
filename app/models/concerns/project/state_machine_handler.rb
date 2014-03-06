module Project::StateMachineHandler
  extend ActiveSupport::Concern

  included do
    #NOTE: state machine things
    #
     state_machine :campaign_type, initial: :flexible do
      state :all_or_none, value: 'all_or_none'
      state :flexible, value: 'flexible'
    end

    state_machine :state, initial: :draft do
      state :draft, value: 'draft'
      state :soon, value: 'soon'
      state :rejected, value: 'rejected'
      state :online, value: 'online'
      state :successful, value: 'successful'
      state :waiting_funds, value: 'waiting_funds'
      state :failed, value: 'failed'
      state :deleted, value: 'deleted'
      state :in_analysis, value: 'in_analysis'

      event :push_to_draft do
        transition all => :draft #NOTE: when use 'all' we can't use new hash style ;(
      end

      event :push_to_soon do
        transition all => :soon #NOTE: when use 'all' we can't use new hash style ;(
      end

      event :push_to_trash do
        transition [:draft, :rejected, :in_analysis] => :deleted
      end

      event :send_to_analysis do
        transition draft: :in_analysis
      end

      event :reject do
        transition [:draft, :in_analysis] =>  :rejected
      end

      event :approve do
        transition [:draft, :soon, :in_analysis] => :online
      end

      event :finish do
        transition online: :failed,             if: ->(project) {
          !project.flexible? && project.expired? && !project.pending_contributions_reached_the_goal?
        }

        transition online: :waiting_funds,      if: ->(project) {
          project.expired? && (project.pending_contributions_reached_the_goal? || project.flexible?)
        }

        transition waiting_funds: :successful,  if: ->(project) {
          (project.reached_goal? || project.flexible?) && !project.in_time_to_wait?
        }

        transition waiting_funds: :failed,      if: ->(project) {
          !project.flexible? && project.expired? && !project.reached_goal? && !project.in_time_to_wait?
        }

        transition waiting_funds: :waiting_funds,      if: ->(project) {
          project.expired? && !project.reached_goal? && (project.in_time_to_wait?)
        }
      end

      after_transition do |project, transition|
        project.notify_observers :"from_#{transition.from}_to_#{transition.to}"
      end

      after_transition any => [:failed, :successful] do |project, transition|
        project.notify_observers :sync_with_mailchimp
      end

      after_transition [:draft, :rejected] => :deleted do |project, transition|
        project.update_attributes({ permalink: "deleted_project_#{project.id}"})
      end
    end
  end
end

