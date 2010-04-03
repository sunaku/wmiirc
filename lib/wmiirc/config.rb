require 'wmiirc'
require 'yaml'

module Wmiirc
  class Config < Hash

    def initialize name
      @origin_by_value = {}
      import name, self
    end

    def apply
      script 'before'
      display
      control
      script 'after'
    end

    ##
    # Qualifies the given section name with the YAML file
    # from which the given value originated.  If this is
    # not possible, the given section name is returned.
    #
    def origin value, section
      if origin = @origin_by_value[value]
        "#{origin}:#{section}"
      else
        section
      end
    end

    private

    def script key
      Array(self['script']).each do |hash|
        if script = hash[key]
          SANDBOX.eval script, origin(script, "script:#{key}")
        end
      end
    end

    def display
      font   = ENV['WMII_FONT']        = self['display']['font']
      focus  = ENV['WMII_FOCUSCOLORS'] = self['display']['color']['focus']
      normal = ENV['WMII_NORMCOLORS']  = self['display']['color']['normal']

      settings = {
        'font'        => font,
        'focuscolors' => focus,
        'normcolors'  => normal,
        'border'      => self['display']['border'],
        'bar on'      => self['display']['bar'],
        'colmode'     => self['display']['column']['mode'],
        'grabmod'     => self['control']['keyboard']['grabmod'],
      }

      begin
        Rumai.fs.ctl.write settings.map {|pair| pair.join(' ') }.join("\n")
        Rumai.fs.colrules.write self['display']['column']['rule']
      rescue Rumai::IXP::Error => error
        #
        # settings that are not supported in a particular wmii version
        # are ignored, and those that are supported are (silently)
        # applied.  but a "bad command" error is raised nevertheless!
        #
        LOG.warn "could not apply some wmii settings: #{error.inspect}"
      end
    end

    def control
      %w[event action keyboard_action].each do |section|
        if settings = self['control'][section]
          settings.each do |key, code|
            if section == 'keyboard_action'
              # expand ${...} in keyboard shortcuts
              key = key.gsub(/\$\{(.+?)\}/) do
                self['control']['keyboard'][$1]
              end

              meth = 'key'
              name = code
              code = self['control']['action'][name]
            else
              name = key
              meth = section
            end

            SANDBOX.eval(
              "#{meth}(#{key.inspect}) {|*argv| #{code} }",
              origin(code, "control:#{section}:#{name}")
            )
          end
        end
      end

      # register keyboard shortcuts
      SANDBOX.eval do
        fs.keys.write keys.join("\n")
        event('Key') {|*a| key(*a) }
      end
    end

    def import virtual_paths, merged_result = {}, already_imported = [], importer = $0
      Array(virtual_paths).each do |virtual_path|
        begin

          physical_path = Loader.find("#{virtual_path}.yaml")
          config_partial = YAML.load_file(physical_path)
          mark_origin config_partial, physical_path

          imports = Array(config_partial['import']) - already_imported
          already_imported.concat imports

          import imports, merged_result, already_imported, physical_path
          merge merged_result, config_partial, physical_path

        rescue => error
          error.message << ' when importing %s (really %s) into %s' %
          [ virtual_path, physical_path, importer ].map(&:inspect)

          raise error
        end
      end

      merged_result
    end

    def mark_origin config_partial, origin
      if config_partial.kind_of? String
        @origin_by_value[config_partial] = origin

      elsif config_partial.respond_to? :each
        config_partial.each do |*values|
          values.each do |v|
            mark_origin v, origin
          end
        end
      end
    end

    def merge dst_hash, src_hash, src_file, backtrace = []
      src_hash.each_pair do |key, src_val|
        next if src_val.nil?
        backtrace.push key

        catch :merged do
          if dst_hash.key? key
            dst_val = dst_hash[key]

            # merge the values
            if dst_val.is_a? Hash and src_val.is_a? Hash
              merge dst_val, src_val, src_file, backtrace
              throw :merged

            elsif dst_val.is_a? Array
              if src_val.is_a? Array
                dst_val.concat src_val
              else
                dst_val.push src_val
              end

              throw :merged

            elsif dst_val != nil
              dst_file = @origin_by_value[dst_val]
              section = backtrace.join(':')

              LOG.warn 'value %s from %s overrides value %s from %s in section %s' %
              [src_val, src_file, dst_val, dst_file, section].map(&:inspect)
            end
          end

          # override destination
          dst_hash[key] = src_val
        end

        backtrace.pop
      end
    end

  end
end
