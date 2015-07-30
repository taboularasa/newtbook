---
title: Testing controller specs with file uploads
---

[RSpec](http://rspec.info/) Controller Specs + [Carrierwave](https://github.com/carrierwaveuploader/carrierwave) file uploads. Heres how to set it up.

Somewhere in your test suite setup you need to configure Carrierwave's root directory, disable processing and use `:file` for storage:

```ruby
CarrierWave.configure do |config|
  config.storage = :file
  config.root = Rails.root.join('tmp/uploads')
  config.enable_processing = false
end
```

You can use any directory for Carrierwave's root as long as Git ignores it.

Now we can write some controller specs. Lets say we're writing a form that edits a resource. The form includes a file picker thats hooked up to a Carrierwave uploader. From the perspective of the controller, we only care that the file got through. We could stub out the collaborators, but I found it simple enough to let everyone do their thing instead. In our context setup we can use `#fixture_file_upload` which is a shortcut for `ActionController::TestUploadedFile#new`. All we need is a path to a file. Heres what the context setup looks like all together:

```ruby
let(:test_image_filename) { 'widget.png' }
let(:test_image_path) do
  Rails.root.join("spec/support/fixtures/images/#{test_image_filename}")
end
let(:expected_image) do
  fixture_file_upload(test_image_path, 'image/png')
end
```

Now we have a file we can include in a params hash:

```ruby
let(:params) do
  {
    id: widget.id,
    widget: {
      name: expected_widget_name,
      coordinator_id: new_coordinator.id,
      image: expected_image
    }
  }
end
```

And when we preform the request, everyone is happy!

```ruby
it 'updates the image' do
  patch :update, params

  expect(widget.reload.image.file.original_filename)
    .to eq(test_image_filename)
end
```

Thanks to [jdwolk](https://github.com/jdwolk) for the tip.
