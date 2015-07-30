---
title: Rails 4.2 broke Ngrok
---

[Nrgok](https://ngrok.com/) is awesome. Anytime I need to tunnel my local process out to the real world for a minute, it's my goto. I haven't had the need in a while and was surprised today when I fired it up and I wasn't getting any traffic to go through. Wat? Ngrok never let me down before!

After some google searching I figured out that my question really isn't "Ngrok broken, what gives?" The real question was actually, "Rails not binding to 127.0.0.1", which will lead you to this section of the Rails 4.2 release notes:

[http://guides.rubyonrails.org/4_2_release_notes.html#default-host-for-rails-server](http://guides.rubyonrails.org/4_2_release_notes.html#default-host-for-rails-server)

So what to do? `bin/rails s -b 0.0.0.0` after that run Ngrok as usual. Yay!
