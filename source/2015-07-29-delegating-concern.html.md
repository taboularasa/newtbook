---
title: delegating-concern
date: 2015-07-29 20:14 UTC
tags:
---

It's was the end of the quarter and we needed to build out some sweet reports to show off awesome widget sales performance. There's going to be all kinds of charts and graphs going on. The good news is we get them all for [free!](http://www.chartjs.org/) I only need to provide a suite of API endpoints for Chart.js to load the data from. Having a wide variety of charts and graphs is only part of the equation. If you're going gor *maximum* impact you're going to need some radical colors to fill up the page. And thats why I created `ColorSampler`, behold:

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
