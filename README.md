# TweakFunCaptcha
FunCaptcha solver with PHash.
```
sudo apt-get install libjpeg-dev libpng-dev
gem install activesupport mini_magick phashion tweakphoeus launchy rails byebug

require "active_support"
require "launchy"
require 'byebug'
require "tweakphoeus"
require "phashion"
require "rails"
require "./solver.rb"
require "./infojobs_session.rb"
InfojobsSession.new.obtain_session
```
