---
title: Delegating Concern
date: 2015-07-29 20:14 UTC
---


It's was the end of the quarter and we needed to build out some sweet reports to show off our awesome widget sales performance. There's going to be all kinds of charts and graphs going on. The good news is we get them all for [free!](http://www.chartjs.org/) I only need to provide a suite of API endpoints for Chart.js to load the data from. Having a wide variety of charts and graphs is only part of the equation. If you want *maximum* impact you're going to need some radical colors to fill up the page. So as you would expect Chart.js accepts colors as attributes of every datapoint. e.g.:

```json
var data = {
  labels: ["January", "February", "March", "April", "May", "June", "July"],
  datasets: [
    {
      label: "My First dataset",
      fillColor: "rgba(220,220,220,0.5)",
      strokeColor: "rgba(220,220,220,0.8)",
      highlightFill: "rgba(220,220,220,0.75)",
      highlightStroke: "rgba(220,220,220,1)",
      data: [65, 59, 80, 81, 56, 55, 40]
    },
    {
      label: "My Second dataset",
      fillColor: "rgba(151,187,205,0.5)",
      strokeColor: "rgba(151,187,205,0.8)",
      highlightFill: "rgba(151,187,205,0.75)",
      highlightStroke: "rgba(151,187,205,1)",
      data: [28, 48, 40, 19, 86, 27, 90]
    }
  ]
};
```

Colors can be supplied in various formats but for my purposes _HSL_ was going to work out best. See, the number of data points for a given graph is going to be variable, but no matter what I want to have greatest differentiation between each color. That makes graphs and charts easier to read. And more colorful equals better!

 And thats why I created `ColorSampler`, which works like this:

 ```ruby
 describe ColorSampler do
  describe '::hue_collection' do
    it 'returns an evenly stepped collection of hsb values' do
      expect(ColorSampler.hue_collection(quantity: 3)).to eq([0, 120, 240, 360])
    end
  end

  describe '::hsl_collection' do
    it 'returns hsl values from a collection of hues' do
      expect(ColorSampler.hsl_collection(quantity: 3)).to eq(
        [
          'hsl(0, 50%, 50%)',
          'hsl(120, 50%, 50%)',
          'hsl(240, 50%, 50%)',
          'hsl(360, 50%, 50%)'
        ]
      )
    end
  end

  describe '::adjust_hsl_lightness' do
    it 'adjusts the lightness of an hsl value' do
      expect(ColorSampler.adjust_hsl_lightness(hsl: 'hsl(0, 50%, 50%)'))
        .to eq('hsl(0, 50%, 60%)')
    end

    it 'accepts a value to lighten by' do
      expect(
        ColorSampler.adjust_hsl_lightness(
          hsl: 'hsl(0, 50%, 50%)',
          lightness: 25)
        ).to eq('hsl(0, 50%, 25%)')
    end
  end
end
 ```

 I can pass in a quantity I want and get back an array of strings representing _HSL_ colors. I can also get just the hue, or I can get a lighter version of an _HSL_ color (which I need for the rollover states). Thanks to Ruby implementation is a snap:

```ruby
class ColorSampler
  def self.hue_collection(quantity:)
    full_range = 360
    steps = full_range / quantity
    [].tap { |r| (0..full_range).step(steps) { |n| r << n } }
  end

  def self.hsl_collection(quantity:, saturation: 50, lightness: 50)
    hue_collection(quantity: quantity).map do |hue|
      "hsl(#{hue}, #{saturation}%, #{lightness}%)"
    end
  end

  def self.adjust_hsl_lightness(hsl:, lightness: 60)
    hsl.gsub(/\s\d+%\)/, " #{lightness}%)")
  end
end
```

Right about now you're thinking, "Wait a minute, the title of this blog post was saying something about Delegating Concerns or some such nonsense but this guy just keeps talking about his silly color picking class. What the heck?" Ok, fair enough. I guess like how that turned out a little too much.

But wait, theres really a point to all this and here it is. Now that I have this nifty thing all setup, I need to hook it up with some collaborators and get some business done. And here is where the title of this post comes from.

The problem with Rails' brand of concern is that their a pain in the butt to test. They need to be included in an instance of another class before they can do their thing so the test always reads with a fair bit of confusing indirection.

In this case the entire interface for `ColorSampler` is stateless and I find it annoying to have to be referencing the class constant or an instance method representing the class constant anytime I want to get at one of these methods. So in that respect what I really wanted was something that acted like a mixin or a concern.

I found a solution that gives the best of both worlds. It's as simple as this:

```ruby
module ColorSamplerDelegate
  extend ActiveSupport::Concern

  delegate :hsl_collection, :adjust_hsl_lightness, to: :ColorSampler
end
```

Now when I include that in a collaborator I can reference the interface without having to reference the class constant. But when it comes to testing I can just ignore the concern all together an be testing in lovely PORO land! :dancer:

So when I want to use this thing it looks like this:

```ruby
module SalesOverview
  class JSONFormatter
    include ColorSamplerDelegate

    def initialize(sales_fields:, widgets:)
      @sales_fields = sales_fields
      @widget_sales = widgets
    end

    def payload
      @payload ||= {
        data: {
          labels: @sales_fields.map(&:titleize),
          datasets: @widget_sales.map { |e| data_set e, colors.pop }
        }
      }
    end

    def data_length
      @widget_sales.length
    end

    private

    def data_set(widget_sale, color)
      {
        label: widget_sale.title,
        fillColor: color,
        strokeColor: adjust_hsl_lightness(hsl: color, lightness: 45),
        highlightFill: adjust_hsl_lightness(hsl: color, lightness: 60),
        highlightStroke: adjust_hsl_lightness(hsl: color, lightness: 55),
        data: data_points_for(widget_sale: widget_sale)
      }
    end

    def data_points_for(widget_sale:)
      @sales_fields.map { |f| widget_sale.grade.send(f) }
    end

    def colors
      @colors ||= hsl_collection(quantity: data_length)
    end
  end
end
```

As a bonus I can use it as a mechanism for limiting the surface area of the interface for specific context, say for example in another context I wanted to limit the interface to hues only, easy!

```ruby
module ColorSamplerDelegate::HueEdition
  extend ActiveSupport::Concern

  delegate :hue_collection, to: :ColorSampler
end
```

Kind of reminds me of a protocol in Swift, only not as helpful.
