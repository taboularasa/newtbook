---
title: Virtual Inventory Location
---

I work on an application that sells Widgets. You as might know, a Widget can be a pretty serious investment. What you might not know is that for people who take Widgets seriously, choosing the right one can be __very__ personal. Because of this reason, the widget application that I work on offers customers the chance to order a home Try-on kit. After supplying some collateral, we will send you a box of six widgets in various configurations. You have a week to live with them in your home. At the end of the trial period you simply keep the one that you love the most and send the rest back to us, postage paid in full both ways! If you happen to be in the market I highly recommend you give it a try!

Naturally, in order to offer this home try-on service we need to have a demo fleet of widgets and a robust inventory management system. We track all the widgets that exist in the warehouse, the factory and in every package that gets sent out for home try-on. One thing that we didn't track however was the aggregate of all the widget inventory thats currently out on demo. And that's what I was tasked with building today!

When Admin users needs to take stock of an inventory location, the Factory for example, they can expect to see something like this:

| Type | Quantity |
| :------------- | :------------- |
| Blue widget | 340 |
| Green widget | 320 |
| Yellow widget | 42 |
| Red widget | 630 |
| Pink widget | 20 |


This gives them a high level view of what Widgets might need to be transferred from another location. This has worked well up to this point but now the problem is our home try-on service is so popular we end up with a significant amount of inventory out in transit. This impacts our ability to forecast inventory needs for manufacturing. So one of our admin users requested that we provide a similar table that reports on the aggregate of all the try-on kits currently out in transit.

When I first designed this inventory system I made a decision that try-on kits should partially implement the interface of an inventory location. This made the flow of inventory in and out of Try-on kits very convenient. Reflecting on that  gave me the idea of creating a virtual inventory location. It would only need an interface that conforms to what is exposed by the views (since this is a read only use case) and a collection from which it could derive calculated properties:

```ruby
describe KitsInventoryLocation do
  before(:each) do
    variant = create(:variant)
    kit_1 = build(:try_on_kit, state: 'shipped')
    kit_1.save validate: false
    kit_1.add_stock(variant, 1)
    kit_1.placements.create(variant_id: variant.id)

    kit_2 = build(:try_on_kit, state: 'shipped')
    kit_2.save validate: false
    kit_2.add_stock(variant, 1)
    kit_2.placements.create(variant_id: variant.id)
  end

  describe '#total_count_on_hand' do
    it 'returns a count of all the products in shipped kits' do
      kits_location = KitsInventoryLocation.new
      expect(kits_location.total_count_on_hand).to eq(2)
    end
  end

  describe '#inventory_items' do
    it 'returns an instance of MockInventoryItemCollection' do
      kits_location = KitsInventoryLocation.new

      expect(kits_location.inventory_items)
        .to be_kind_of(MockInventoryItemCollection)
    end
  end
end
```

The implementation turned out like this:

```ruby
class KitsLocation
  attr_accessor :kits

  def initialize
    self.kits = WidgetKit.shipped
  end

  def name
    'All Try-on Kits'
  end

  def to_param
    'kits_location'
  end

  def total_count_on_hand
    kits.reduce(0) { |a, e| a + e.total_count_on_hand }
  end

  def inventory_items
    @inventory_items ||= MockInventoryItemCollection.new(group_by_variants)
  end

  private

  def group_by_variants
    @group_by_variants ||= kits.flat_map(&:placements).group_by(&:variant)
  end
end
```

Now I can mix this location in with all the others. In their controller:

```ruby
class Admin::InventoryLocationsController < Admin::BaseController
  helper_method :inventory_location, :inventory_locations

  def index; end

  def show; end

  private

  def kits_location
    @kits_location = KitsLocation.new
  end

  def inventory_location
    @inventory_location ||= if params[:id] == 'kits_location'
      kits_location
    else
      InventoryLocation.find(params[:id])
    end
  end

  def inventory_items
    @inventory_items ||= inventory_location.inventory_items.active_items
  end

  def inventory_locations
    @inventory_locations ||=
      InventoryLocation.includes(:inventory_items).all.to_a << kits_location
  end
end
```

And in their views. E.g. index:

```html
<table class="table table-bordered table-striped">
  <thead>
    <tr>
      <th>Name</th>
      <th>Total count on hand</th>
      <th></th>
    </tr>
  </thead>
  <tbody>
    <% inventory_locations.each do |location| %>
      <tr>
        <td><%= location.name %></td>
        <td><%= location.total_count_on_hand %></td>
        <td width="200">
          <%= link_to "Show", admin_inventory_location_path(location), class: "btn btn-primary" %>
        </td>
      </tr>
    <% end %>
  </tbody>
</table>
```

E.g. show:

```html
<table class="table table-bordered table-striped">
  <tr>
    <th>Product</th>
    <th>Variant</th>
    <th>SKU</th>
    <th>Quantity</th>
  </tr>
  <% @inventory_items.each do |item| %>
    <tr>
      <td><%= item.variant.product.name %></td>
      <td><%= item.variant.name %></td>
      <td><%= item.variant.sku %></td>
      <td><%= item.count_on_hand_less_backorders %></td>
    </tr>
  <% end %>
</table>
```

`KitsInventoryLocation#total_count_on_hand` is used to show our virtual inventory location in a collection with real inventory locations, e.g. a index of inventory locations:

| Location | Total Quantity     |
| :------------- | :------------- |
| The Factory       | 34,982       |
| The Warehouse       | 80,6543       |
| All Try-on Kits       | 113,486       |

`KitsInventoryLocation#inventory_items` is a collection of virtual inventory items. I needed a simple collection thats would accept a hash of inventory grouped by Widget type and build out `MockInventoryItem`s which represent the count. That's why we have that private method, `KitsLocation#group_by_variants`

```ruby
describe MockInventoryItemCollection do
  describe '#initialize' do
    let(:variant) { create(:variant) }
    let(:placement) { create(:kit).placements.create(variant_id: variant.id) }
    let(:valid_argument) { { variant => [placement] } }

    it 'expects a hash of kits grouped by variants' do
      expect { MockInventoryItemCollection.new(nil) }
        .to raise_error(ArgumentError)

      expect { MockInventoryItemCollection.new(valid_argument) }
        .to_not raise_error
    end

    it 'assigns an array of MockInventoryItems to @active_items' do
      collection = MockInventoryItemCollection.new(valid_argument)
      expect(collection.active_items).to be_a(Array)
      expect(
        collection.active_items.all? do |item|
          item.is_a?(MockInventoryItemCollection::MockInventoryItem)
        end
      ).to eq(true)
    end

    it 'sets the properties on the MockInventoryItems' do
      item = MockInventoryItemCollection.new(valid_argument).active_items.first
      expect(item.variant).to eq(variant)
      expect(item.count_on_hand_less_backorders).to eq(1)
    end
  end
end
```

I found `Struct` to be really handy in this case for building data types needed:

```ruby
class MockInventoryItemCollection
  MockInventoryItem = Struct.new(:variant, :count_on_hand_less_backorders)
  attr_accessor :active_items

  def initialize(group)
    fail ArgumentError unless valid_argument(group)
    self.active_items = group.map { |k, v| MockInventoryItem.new(k, v.length) }
  end

  private

  def valid_argument(arg)
    return false unless arg.try(:is_a?, Hash)
    return false unless arg.keys.first.is_a? Product::Variant
    return false unless arg.values.first.is_a? Array
    arg.values.first[0].is_a? Kit::Placement
  end
end
```

You can see here that the implementation of `MockInventoryItemCollection` and `MockInventoryItemCollection::MockInventoryItem` really is just a simple collection of data types that are tailored to adapt to an existing interface. The meat of the problem was taken care of by passing the results of `KitsLocation#group_by_variants` into the initializer of `MockInventoryItemCollection`
