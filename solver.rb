# coding: utf-8
require 'phashion'
require 'mini_magick'
require 'tempfile'
require 'launchy'
require "fileutils"

class Solver
  
  THRESHOLD = 20
  OPTIONS = [40, 80, 120, 160, 200, 240, 280, 320]
  
  class << self

    def solve_image(url)
      image = obtain_image(url)
      
      result = obtain_valid_option(image, obtain_key_frame_array)

      unless result[:error]
        correct_image_path = result[:match].first
        option = correct_image_path.split(".").first.split("-").last.to_i
        return { option: option, rotation: OPTIONS[option] , path: correct_image_path}
      else
        return { error: true , paths: result[:discarded] }
      end
    end

    def check_as_successful(values)
      values.each do |value|
        FileUtils.mv("/tmp/funcaptcha#{value[:id]}-#{value[:option]}.jpg", "candidate_keyframes/")
      end
    end
    
    def check_as_bad_resolved(values)
      values.each do |value|
        value[:paths].each do |path|
          FileUtils.mv(path, "bad/")
        end
      end
    end

    def discard_repeated_key_frames
      key_frame_array = obtain_key_frame_array
      discarded = []

      key_frame_array.each_with_index do |element1, index1|
        key_frame_array.each_with_index do |element2, index2|
          next if index1 <= index2
          puts "x: #{index1}, y: #{index2}"

          if element1.duplicate?(element2, threshold: 3)
            puts "discarded"
            discarded << element1.filename
          end
        end
      end

      `mkdir -p discarded`
      discarded.each do |element|
        FileUtils.mv(element, "discarded/")
      end
    end

    def clean_tmp_files
      `rm /tmp/funcaptcha*`
      `rm /tmp/mini_*`
    end
    
    private

    def obtain_image(url)
      file = Tempfile.new(["funcaptcha#{Time.now.to_i}", ".jpg"])
      tmp_image_path = file.path

      
      image = MiniMagick::Image.open(url)

      image.combine_options do |c|
        c.background '#FFFFFF'
        c.alpha 'remove'
        c.fuzz "5%"
        c.trim "+repage"
      end

      image.format('jpg')
      image.write(tmp_image_path)

      file
    end

    def generate_options(file)
      image_path = file.path
      image_options = []

      OPTIONS.each_with_index do |rotate_option, i|
        dest_path = image_path.split(".")[0] + "-" + i.to_s + ".jpg"
        rotate_image(image_path, dest_path, rotate_option)
        image_options << dest_path
      end

      image_options
    end

    def rotate_image(image_path, dest_path,  deg)
      image = MiniMagick::Image.open(image_path)
      image.combine_options do |c|
        c.rotate(deg)
        c.fuzz "30%"
        c.trim "+repage"
        c.resize "100x100"
      end
      
      image.write(dest_path)
    end

    def phash_from_file(image_path)
      Phashion::Image.new(image_path)
    end

    def obtain_valid_option(file, key_frames)
      options = generate_options(file)
      is_valid = false
      matches = {}
      options.each do |option|
        key_frames.each do |key_frame|
          option_file = phash_from_file(option)

          if option_file.duplicate?(key_frame, threshold: THRESHOLD)
            is_valid ||= true
            matches[option] = { distance: option_file.distance_from(key_frame), file: key_frame.filename }
          end
        end
      end
      if is_valid
        best_match = matches.sort_by{ |key, value| value[:distance] }.first
        best_match.first
        return {error: false, match: best_match}
      else
        puts "NOPE!!! (╯°□°）╯︵ ┻━┻"
        return {error: true, discarded: options}
      end
    end

    def obtain_key_frame_array
      key_files = Dir.entries("key_frames") - ["."] - [".."]

      [].tap do |array|
        key_files.each do |file|
          array << phash_from_file("key_frames/" + file)
        end
      end
    end
  end
end
