# coding: utf-8
require 'tweakphoeus'
require 'nokogiri'
require 'byebug'
require_relative 'solver.rb'

class Trainer

  MAIN_URL = "https://www.funcaptcha.com/demo/"
  
  class << self
    def train
      loop do
        resolve_captcha
      end
    end

    private

    def resolve_captcha
      http = Tweakphoeus::Client.new

      request = Nokogiri::HTML(http.get(MAIN_URL).body)
      iframe_url = request.css("iframe").attr("src").value

      http_req = http.get(iframe_url).body
      funcaptcha_frame = Nokogiri::HTML(http_req)

      error = false
      
      results = []
      5.times do
        body = funcaptcha_frame.css("//input[@type=hidden]").map{|e| [e.attr("name"),e.attr("value")]}.to_h

        http_req = http.post(iframe_url, body: body).body
        funcaptcha_frame = Nokogiri::HTML(http_req)
        
        elements = funcaptcha_frame.css("form.imgInput-1")
        captcha_image_1 = funcaptcha_frame.css("input.pic-1").first.attr("src")

        result = Solver.solve_image(captcha_image_1)

        results << result

        if result[:error].nil?
      
          correct_option = result[:option]
          correct_entry = elements[correct_option]
          x = rand(50..100)
          y = rand(50..100)
      
          body = { x: x,
                   y: y,
                   "fc-game[session_token]" => correct_entry.css("input")[1].attr("value"),
                   "fc-game[data]" => correct_entry.css("input")[2].attr("value") }

          http_req = http.post(iframe_url, body: body).body
          funcaptcha_frame = Nokogiri::HTML(http_req)
          funcaptcha_frame2 = funcaptcha_frame.css(".intro-txt")
          byebug
          break if funcaptcha_frame2.text.include?("Verificación completa")
          puts funcaptcha_frame2
          error = false if funcaptcha_frame.text.include?("no es del todo correcta")
          break if error == false
        else
          error = true
          break
        end
      end

      if error || funcaptcha_frame.text.include?("Al menos una de tus respuestas no es del todo correcta")
        Solver.check_as_bad_resolved(results)
        return false
      else
        Solver.check_as_successful(results)
        return true
      end
    end
  end
end
