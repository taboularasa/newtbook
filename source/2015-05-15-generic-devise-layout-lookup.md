---
title: Generic Devise Layout Lookup
---

I always forget this kind of stuff so I'll put it here for next time. If you want your devise views to share the same layout as the resource's namespace you might do something like this:

```ruby
def layout_by_resource
  if devise_controller? && resource_name == :teacher && current_teacher
    'teacher_layout'
  elsif devise_controller? && resource_name == :student && current_student
    'student_layout'
  else
    'application'
  end
end
```

Instead you should do this:

```ruby
def layout_by_resource
  if devise_controller? && signed_in?
    "#{resource_name}_layout"
  else
    'application'
  end
end
```
