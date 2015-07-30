---
title: Class Extraction
---

As time passes on a project, some classes have a tendency accumulate too many
responsibilities. Take the following, simplified for example:

```ruby

class WidgetKit < ActiveRecord::Base
  def total
    ...
  end

  def multi_type?
    ...
  end

  def single_type?
    ...
  end

  def more_widgets_allowed?(widget)
    ...
  end

  def add_widget(widget_kit_widget)
    ...
  end
end

```

Multiple methods are concerned with type issues. We can extract related
methods into their own class which holds a reference to the shopping widget_kit:

```ruby

class WidgetTypeManager
  attr_accessor :widget_kit

  def initialize(widget_kit)
    self.widget_kit = widget_kit
  end

  def multi_type?
    ...
  end

  def single_type?
    ...
  end
end

```

Then we can delegate to the new class without affecting the rest of the system:

```ruby

class WidgetKit < ActiveRecord::Base
  delegate :multi_type?, :single_type?
           to: :widget_type_manager

  def total
    ...
  end

  def more_widgets_allowed?(widget)
    ...
  end

  def add_widget(widget_kit_widget)
    ...
  end

  private

  def widget_type_manager
    @widget_type_manager ||= WidgetTypeManager.new(self)
  end
end

```

This is a good first step to decoupling the type concern altogether.
