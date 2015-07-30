---
title: Delegation
---

[Wai-Yin](https://github.com/wykhuh) and I were thinking about implementing Stripe Webhooks in one of our projects to help us keep our records in sync when users preformed actions in the Stripe dashboard (e.g. deleting a credit card or refunding a charge).

[Stripe Webhooks](https://stripe.com/docs/webhooks) offers a choice of adding a new endpoint for each type of event you want to handle or sending all events to a single endpoint. We decided to go with a single endpoint. To make that happen it would be nice if there were someone who could take care of any kind of event, maybe `StripeEventManager` could do it?

This will involve handling multiple message types through the same interface using delegation and custom event classes.

```ruby
module Api
  module Admins
    class StripeHooksController < ActionController::Base
      def create
        event_manager = StripeEventManager.new stripe_payload
        event_manager.process_event
        render event_manager.response_body, status: event_manager.response_code
      end

      private

      def stripe_payload
        JSON.parse(request.body.read)
      end
    end
  end
end
```

Jim Gay has an interesting rant about the [modern misconception of delegation](http://www.saturnflyer.com/blog/jim/2012/07/06/the-gang-of-four-is-wrong-and-you-dont-understand-delegation/). TL;DR: what most people think of delegation is actually *message forwarding*. He goes on to explain that in true delegation *self* will always refer to the original message recipient:

>[W]hen you send a message to an object, it has a notion of “self” where it can find attributes and other methods. When that object delegates to another, then any reference to “self” always refers to the original message recipient. Always.

Turns out we just need the fake kind of delegation that's provided by [Active Support](http://apidock.com/rails/v4.2.1/Module/delegate)

```ruby
class StripeEventManager
  attr_accessor :request
  delegate :process_event, :response_body, :response_code, to: :event_handler

  def initialize(request)
    self.request = request
  end

  private

  def event_handler
    @event_hander ||= events_map[request[:type]].to_s.constantize.new(request)
  end

  def events_map
    event_handlers.map { |klass| [klass.event_name, klass] }.to_h
  end

  def event_handlers
    StripeEvents.constants.select { |c| StripeEvents.const_get(c).is_a? Class }
  end
end
```

And heres an example of an event handler:

```ruby
module StripeEvents
  class CardDeleted
    EVENT_NAME = 'customer.card.deleted'
    attr_accssor :request, :response_body, :response_code

    def self.event_name
      EVENT_NAME
    end

    def initialize(request)
      fail StandardError, 'bad Stripe request' unless valid_request
      self.request = request
    end

    def process_event
      card = CreditCard.find_by(token: cart_token)
      card.update(deleted_at: Time.zone.now) if card
      self.response_code = 200
    end

    private

    def valid_request
      request.try(:[], :data).try(:[], :object).try(:[], :id)
    end

    def cart_token
      request[:data][:object][:id]
    end
  end
end
```
