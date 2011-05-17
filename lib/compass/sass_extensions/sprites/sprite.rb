module Compass
  module SassExtensions
    module Sprites
      module Sprite
        
        # Changing this string will invalidate all previously generated sprite images.
        # We should do so only when the packing algorithm changes
        SPRITE_VERSION = "1"
        
        # Calculates the overal image dimensions
        # collects image sizes and input parameters for each sprite
        # Calculates the height
        def compute_image_metadata!
          @width = 0
          init_images
          compute_image_positions!
          @height = @images.last.top + @images.last.height
        end
        
        # Creates the Sprite::Image objects for each image and calculates the width
        def init_images
          @images = image_names.collect do |relative_file|
            image = Compass::SassExtensions::Sprites::Image.new(self, relative_file, kwargs)
            @width = [ @width, image.width + image.offset ].max
            image
          end
        end
        
        # Calculates the overal image dimensions
        # collects image sizes and input parameters for each sprite
        def compute_image_positions!
          if kwargs.get_var('smart-pack').value
            smart_packing
          else
            legacy_packing
          end
        end
        
        # Validates that the sprite_names are valid sass
        def validate!
          for sprite_name in sprite_names
            unless sprite_name =~ /\A#{Sass::SCSS::RX::IDENT}\Z/
              raise Sass::SyntaxError, "#{sprite_name} must be a legal css identifier"
            end
          end
        end

        # The on-the-disk filename of the sprite
        def filename
          File.join(Compass.configuration.images_path, "#{path}-#{uniqueness_hash}.png")
        end

        # Generate a sprite image if necessary
        def generate
          if generation_required?
            if kwargs.get_var('cleanup').value
              cleanup_old_sprites
            end
            sprite_data = construct_sprite
            save!(sprite_data)
            Compass.configuration.run_callback(:sprite_generated, sprite_data)
          end
        end
        
        def cleanup_old_sprites
          Dir[File.join(Compass.configuration.images_path, "#{path}-*.png")].each do |file|
            FileUtils.rm file
          end
        end
        
        # Does this sprite need to be generated
        def generation_required?
          !File.exists?(filename) || outdated?
        end

        # Returns the uniqueness hash for this sprite object
        def uniqueness_hash
          @uniqueness_hash ||= begin
            sum = Digest::MD5.new
            sum << SPRITE_VERSION
            sum << path
            images.each do |image|
              [:relative_file, :height, :width, :repeat, :spacing, :position, :digest].each do |attr|
                sum << image.send(attr).to_s
              end
            end
            sum.hexdigest[0...10]
          end
          @uniqueness_hash
        end

        # Saves the sprite engine
        def save!(output_png)
          saved = output_png.save filename
          Compass.configuration.run_callback(:sprite_saved, filename)
          saved
        end

        # All the full-path filenames involved in this sprite
        def image_filenames
          @images.map(&:file)
        end

        # Checks whether this sprite is outdated
        def outdated?
          if File.exists?(filename)
            return @images.map(&:mtime).any? { |imtime| imtime.to_i > self.mtime.to_i }
          end
          true
        end

        # Mtime of the sprite file
        def mtime
          @mtime ||= File.mtime(filename)
        end
        
       # Calculate the size of the sprite
        def size
          [width, height]
        end

      end
    end
  end
end