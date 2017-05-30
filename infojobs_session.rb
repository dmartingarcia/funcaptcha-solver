require 'tweakphoeus'
require 'nokogiri'
require_relative 'solver.rb'

class InfojobsSession
  MAIN_URL = "https://www.infojobs.net/distil_verify"

  def initialize
    @http = Tweakphoeus::Client.new
  end

  def obtain_session
    error = false

    request = Nokogiri::HTML(@http.get(MAIN_URL).body)

    distil_form = request.css("form#distilCaptchaForm").first
    pkey = distil_form.css("#funcaptcha").attr("data-pkey").value

    iframe_url = distil_form.css("iframe").attr("src").value

    http_req = @http.get(iframe_url).body
    funcaptcha_frame = Nokogiri::HTML(http_req)
          
    results = []
    
    5.times do

      begin    
        elements = funcaptcha_frame.css("form.imgInput-1")

        captcha_image_1 = funcaptcha_frame.css("input.pic-1").first.attr("src")
      rescue
        puts http_req
        raise
      end
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

        http_req = @http.post(iframe_url, body: body).body
        funcaptcha_frame = Nokogiri::HTML(http_req)
        break if funcaptcha_frame.text.include?("Verificación completa")
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
      token = funcaptcha_frame.css("input").attr("value")
      body = { "fc-token" => token, V: 0, RM: "GET" }
      @http.post("https://www.infojobs.net/distil_verify", body: body)
      return @http
    end 
  end
end
