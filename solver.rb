require 'phashion'
require 'mini_magick'
require 'tempfile'
require 'launchy'
require "fileutils"

class Solver
  
  THRESHOLD = 15
  OPTIONS = [40, 80, 120, 160, 200, 240, 280, 320]
  
  class << self

    def solve_image(url)
      path = obtain_image(url)
      correct_image_path = obtain_valid_option(path, obtain_key_frame_array)
      puts path
      if correct_image_path
        option = correct_image_path.split(".").first.split("-").last.to_i
        id = correct_image_path.split("/").last[10..-7]
        return { option: option, rotation: OPTIONS[option] , id: id}
      else
        id = path.split("/").last[10..-7]
        return { error: true , id: id }
      end
    end

    def check_as_successful(values)
      values.each do |value|
        FileUtils.mv("/tmp/funcaptcha#{value[:id]}-#{value[:option]}.jpg", "candidate_keyframes/")
      end
    end
    
    def check_as_bad_resolved(values)
      values.each do |value|
        Dir.glob("/tmp/funcaptcha#{value[:id]}*").each do |file|
          FileUtils.mv(file, "bad/")
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

          if element1.duplicate?(element2, threshold: 1)
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
      file.close
      
      image = MiniMagick::Image.open(url)

      image.combine_options do |c|
        c.background '#FFFFFF'
        c.alpha 'remove'
        c.fuzz "30%"
        c.trim "+repage"
      end

      image.format('jpg')
      image.write(tmp_image_path)

      tmp_image_path
    end

    def generate_options(image_path)
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

    def obtain_valid_option(path, key_frames)
      options = generate_options(path)
      is_valid = false
      matches = {}
      options.each do |option|
        key_frames.each do |key_frame|
          option_file = phash_from_file(option)
          
          if option_file.duplicate?(key_frame, threshold: THRESHOLD)
            is_valid ||= true
            matches[option] = option_file.distance_from(key_frame)
          end
        end
      end
      if is_valid
        best_match = matches.sort_by{|key, value| value}.first
        return best_match.first
      else
        puts "NOPE!!! (╯°□°）╯︵ ┻━┻"
        return nil
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

    def open_file(path)
      Launchy.open(path)
    end

  end
end
