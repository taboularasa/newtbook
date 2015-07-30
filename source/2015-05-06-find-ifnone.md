---
title: Enumerable#find ifnone
---

I have a `WidgetKitManager` who needs to make sure that `WidgetKit`'s have homogenous widget types. When adding a widget, it should either be added to a widget_kit with it's family or a new widget_kit should be created for it to live alone:

```ruby

describe WidgetKitManager do
  describe '#widget_kit_for_new_widget' do
    it 'returns a widget_kit with the same type as the new widget' do
      user = create(:user)

      expected_widget_kit = create(
        :widget_kit, :with_complete_widgets, user: user
      )

      new_widget = build(
        :widget,
        date_package: expected_widget_kit.widgets.first.date_package
      )

      widget_kit_manager = WidgetKitManager.new(user.reload)

      expect(widget_kit_manager.widget_kit_for_new_widget(new_widget))
        .to eq(expected_widget_kit)
    end

    it 'creates a new widget_kit if no suitable widget_kit exists' do
      user = create(:user)
      new_widget = build(
        :widget, :widget_with_required_associations
      )
      widget_kit_manager = WidgetKitManager.new(user.reload)

      expect { widget_kit_manager.widget_kit_for_new_widget(new_widget)  }
        .to change { user.widget_kits.count }.by(1)
    end

    it 'adds the new widget to the widget_kit' do
      user = create(:user)
      new_widget = build(
        :widget, :widget_with_required_associations
      )
      widget_kit_manager = WidgetKitManager.new(user.reload)

      widget_kit = widget_kit_manager.widget_kit_for_new_widget(new_widget)
      expect(widget_kit.widgets).to include(new_widget)
    end
  end
end

```

When implementing `WidgetKitManager#widget_kit_for_new_widget` I noticed a nice feature in `Enumerable#find`, the optional __ifnone__ argument:

*`find(ifnone = nil) { |obj| block } → obj or nil`*

>Passes each entry in enum to block. Returns the first for which block is not false. If no object matches, calls ifnone and returns its result when it is specified, or returns nil otherwise.

I don't know why, but until today my eyes just glossed over that little optional argument detail. Conveniently I noticed today and it was just what I needed! Look through a collection finding a match to some condition, if you don't find anything do some other business instead. Awesome:

```ruby
class WidgetKitManager
  attr_accessor :current_user

  delegate :widget_kits, to: :current_user

  def initialize(current_user)
    self.current_user = current_user
  end

  def widget_kit_for_new_widget(widget)
    found_kit =
      widget_kits.detect(-> { create_widget_kit(widget) }) do |kit|
        kit.type_id == widget.type_id
      end

    found_kit.widgets << widget

    found_kit
  end

  ...

  private

  def create_widget_kit(widget)
    current_user.widget_kits.create(
      type_id: widget.type_id
    )
  end
end
```
