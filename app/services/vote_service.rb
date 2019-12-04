# frozen_string_literal: true

class VoteService < BaseService
  include Authorization
  include Payloadable

  def call(account, poll, choices)
    authorize_with account, poll, :vote?

    @account = account
    @poll    = poll
    @choices = choices
    @votes   = []

    already_voted = true

    RedisLock.acquire(lock_options) do |lock|
      if lock.acquired?
        already_voted = @poll.votes.where(account: @account).exists?

        ApplicationRecord.transaction do
          @choices.each do |choice|
            @votes << @poll.votes.create!(account: @account, choice: choice)
          end
        end
      else
        raise Mastodon::RaceConditionError
      end
    end

    increment_voters_count! unless already_voted

    ActivityTracker.increment('activity:interactions')

    if @poll.account.local?
      distribute_poll!
    else
      deliver_votes!
      queue_final_poll_check!
    end
  end

  private

  def distribute_poll!
    return if @poll.hide_totals?
    ActivityPub::DistributePollUpdateWorker.perform_in(3.minutes, @poll.status.id)
  end

  def queue_final_poll_check!
    return unless @poll.expires?
    PollExpirationNotifyWorker.perform_at(@poll.expires_at + 5.minutes, @poll.id)
  end

  def deliver_votes!
    @votes.each do |vote|
      ActivityPub::DeliveryWorker.perform_async(
        build_json(vote),
        @account.id,
        @poll.account.inbox_url
      )
    end
  end

  def build_json(vote)
    Oj.dump(serialize_payload(vote, ActivityPub::VoteSerializer))
  end

  def increment_voters_count!
    unless @poll.voters_count.nil?
      @poll.voters_count = @poll.voters_count + 1
      @poll.save
    end
  rescue ActiveRecord::StaleObjectError
    @poll.reload
    retry
  end

  def lock_options
    { redis: Redis.current, key: "vote:#{@poll.id}:#{@account.id}" }
  end
end