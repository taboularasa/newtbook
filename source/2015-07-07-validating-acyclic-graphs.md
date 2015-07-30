---
title: Validating acyclic graphs
---

[Alexis King](https://github.com/lexi-lambda) and I were building an inventory management system for a Widget factory. In the warehouse they have a variety of containers that can hold either widgets or other containers. We needed to provide an inventory management system for the warehouse manager to keep track of the whereabouts of each container and widget. Here's how it needed to work:

1. Manager logs into the inventory management system
1. Manager navigates to the show view for an Inventory Location (i.e. a warehouse)
1. Manager clicks on manage containers
1. From this form the Manager can specify the location of Containers using a drag and drop style interface.

So based on these requirements we know that a `Container` should `belong_to :parent_container` and inversely `have_many :child_containers`:

```ruby
class Container < ActiveRecord::Base
  belongs_to :inventory_location
  belongs_to :parent_container, class_name: 'Container', foreign_key: :container_id
  has_many :child_containers, class_name: 'Container', foreign_key: :container_id
end
```

Sounds great so far! Wait, one problem is we want to make sure that a warehouse manager can't define a cyclic relationship of containers. Container *A* can not be inside of container *B* if container *B* is already inside of container *A*.

```ruby
describe Container do
  it 'can add child containers' do
    location = InventoryLocation.create
    container_a = location.containers.create
    container_b = location.containers.create
    expect(container_a.child_containers << container_b).to eq(true)
  end

  it 'does not add a child container if a cycle would be formed' do
    location = InventoryLocation.create
    container_a = location.containers.create
    container_b = location.containers.create
    container_a.child_containers << container_b
    container_b.child_containers << container_a
    expect(container_b.errors[:base])
      .to include('Creates cyclic container relationship')
  end
end
```

Sounds obvious but finding a way to validate that for any case turns out to be a little complicated. Luckily we don't need to figure that out because [Robert Tarjan](https://en.wikipedia.org/wiki/Robert_Tarjan) already [did](https://en.wikipedia.org/wiki/Tarjan%27s_strongly_connected_components_algorithm) and Ruby makes it available in the `TSort` module. This is the same module that [Bundler](http://bundler.io/) uses to resolve dependancies in a Gemfile. If it's good enough for Bundler it should be good enough for this!

We don't really need all the functionality of the `TSort` module but if we include it in our model and call it's `#tsort` method, we'll conveniently raise a `TSort::Cyclic` error if any closed loops exist in the tree! Great. `TSort` expects the including class to implement an interface of `#tsort_each_node` and `#tsort_each_child`. The implementation depends on your use case but in this scenario it looks like this:

```ruby
class InventoryLocation < ActiveRecord::Base
  include TSort

  has_many :containers

  validate :acyclic

  private

  def acyclic
    tsort
  rescue TSort::Cyclic
    errors.add(:base, 'Creates cyclic container relationship')
  end

  def tsort_each_node(&block)
    containers.each(&block)
  end

  def tsort_each_child(container, &block)
    container.child_containers.each(&block)
  end
end
```

Now the problem is we want to interact with a tree of `Container`s but when we modify their relationship we need to check for cycles in the tree through the `InventoryLocation`. For that to work `InventoryLocation#valid?` needs to be called _after_ the update. This can be accomplished by combining the update and the check for validity in a transaction. It's essential this transaction is run anytime a container is added to another container. We can accomplish that with an extension to the `ActiveRecord_Associations_CollectionProxy` like so:

```ruby
module ValidateAcyclicInventoryLocation
  def with_location_validation
    transaction do
      yield
      owner = proxy_association.owner
      location = owner.inventory_location.reload
      return true if location.valid?

      location.errors.full_messages_for(:base).each do |error|
        owner.errors.add(:base, error)
      end
    end
  end

  def <<(value)
    with_location_validation { super(value) }
  end
end
```

Then we can mix that extension into the `has_many` call on `Container`:

```ruby
class Container < ActiveRecord::Base
  belongs_to :inventory_location

  belongs_to(
    :parent_container,
    class_name: 'Container',
    foreign_key: :container_id
  )

  has_many(
    :child_containers,
    (-> { extending ValidateAcyclicInventoryLocation }),
    class_name: 'Container',
    foreign_key: :container_id
  )
end
```

And with that our tests should be passing! Good work :+1:

p.s. If you're interested I've posted the example repo [here](https://github.com/taboularasa/tsort_test)
