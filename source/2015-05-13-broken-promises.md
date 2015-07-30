---
title: Broken Promises
---

I love automated tests, and I rely on them as a source of confidence in the face of daunting change to complex systems. And that's why it is so heart breaking to experience those times when things are just not as true as they claim to be, the __false positive__. While false negatives can be annoying and erode confidence in a test suite, the false positive can be absolutely disastrous when it helps to ship mission critical bugs to production.

>*WARNING:* The following is a tale of time lost and frustration gained, people with a sensitive disposition should consider skimming the article or just going somewhere else on the Internet instead.

I suspect that finding false positives is a pretty common event, but I wouldn't be able to say for sure because I have rarely heard of anyone bragging about how they found one (unless it's something they were not the author of). I'm going to go out on a limb here and confess my mistake in hopes that I can liberate those who have not yet found the courage within themselves to come forward:

__I am guilty of creating tests that produce false positive results__

I am not proud of this, nor is it ever intentional. It's something that happens from time to time and it's worth reconciliation.

Take this sweet PORO that I made today as an example:

```ruby
class StripeRefundManager
  attr_accessor :charges

  def initialize(stripe_charges)
    self.charges = stripe_charges
  end

  def refund
    charges.map(&:refund)
    charges.all?(&:refunded?)
  end
end
```


Seems reasonable enough. First we know we need to send `refund` to each charge that we were initialized with. And after that, `Charge` is considerate enough to offer a `#refunded?` predicate. Easy peasy!

This is just the kernel of a class that will someday grow up to be a much depended on and probably over bloated pillar of responsibility. So while it's not doing much at the moment, my future self is going to thank my current self when he doesn't need to worry about breaking stuff that's not a part of what he's building.

It's important that this functionality complains loudly when it decides to stop working. That's why it's also important to see the __red__ in the *red, green, refactor* cycle. It's one way to test the possibility of your assertion to be negative.

There are lots ways to see red and sometimes when you're busy its easy to feel like any red counts. And that's how I ended up with a test that looks like this:

```ruby
require 'rails_helper'

describe StripeRefundManager do
  describe '#refund' do
    it "sends #refund to all it's charges" do
      charge = StripeCharge.create
      expect(charge).to receive(:refund)
      StripeRefundManager.new([charge]).refund
    end

    it 'returns true when all charges are refunded' do
      charge = StripeCharge.create
      allow(charge).to receive(:refund)
      allow(charge).to receive(:refunded?) { true }
      expect(StripeRefundManager.new([charge]).refund).to eq(true)
    end
  end
end
```

Not much going on here as of yet. We just initialize with a collection of charges, call `#refund` and we get back `true` if all is good for us to move on. Whats the catch? You probably didn't guess because I didn't give you any details about `Charge` but I should have known since I wrote `Charge`. And once I knew there was a problem it was easy enough to figure it out.

My downfall today is that I had my red, then I went on and got my green, even had a little refactor. Done and done, on with my next todo. One hour later I'm already victim of my own trap, wasting time with unexpected behavior elsewhere because this `refund` method is not returning the `true` value that I expect! What the heck, I just built that thing with awesome test coverage and everything. What gives?

Turns out that `Charge` decides that it's refunded if it's `charged_amount` is equal to the sum of all it's refund's `amounts`. My test doesn't cover that at all since I've stubbed out `#refunded?`, which often times should be harmless since it's not the part of the system under test, but in this case it's covering up the bug that brought this false positive to my attention:

```ruby
def refund
  charges.map(&:refund)
  charges.all?(&:refunded?)
end
```

`Charge` `has_many: :refunds`. So as long as we have a reference to `Charge` in memory before there are any `Refund`s pointing to it, then we’re always going to calculate the refunded amount as 0. The fix for this bug is also very simple, but not easy to see if you aren't looking for it:

```ruby
def refund
  charges.map { |c| c.refund }
  charges.all? { |c| c.reload.refunded? }
end
```

This kind of problem brings into question the practice of stubbing. This wouldn't have been a problem if there were no stubs involved. On the other hand, the test suite would become too slow to be productive eventually if we were unable to isolate parts of the system from their collaborators. There are many pros and cons but at the end of the day it makes sense to use stubbing in a unit test.

When using stubs it's especially important to use some exploratory testing to ensure that the red is meaningful. That means thinking critically about the outcome of the assertion and verifying that it's relevant to expected functionality. Once a test is merged into master it's unusual that anyone will think about the validity of your assertions. It doesn't matter if you're super busy, super lazy or have some other important excuse. You owe it to yourself, your team and the success of the project to take a moment on every expectation's red phase. Ask yourself, "Is this test failing for a relevant reason, does it's failure align with the docstring?"
