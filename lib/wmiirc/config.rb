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
          SANDBOX.eval script.to_s, origin(script, "script:#{key}")
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
        Rumai.fs.rules.write self['display']['client']['rule']
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
              key = expand_keyboard_shortcut(key)
              meth = 'key'
              code = self['control']['action'][code] || "action #{code.inspect}"
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

    # Expands symbolic references in the given keyboard shortcut.
    def expand_keyboard_shortcut key
      key = key.dup
      while key.gsub!(/\$\{(\w+)\}/){ self['control']['keyboard'][$1] }
        # continue
      end
      key
    end

    def import virtual_paths, merged_result = {}, already_imported = [], importer = $0
      Array(virtual_paths).each do |virtual_path|
        Dir["#{DIR}/#{virtual_path}.yaml"].each do |physical_path|
          if already_imported.include? physical_path
            next
          else
            already_imported << physical_path
          end

          begin
            config_partial = YAML.load_file(physical_path).to_hash
            mark_origin config_partial, physical_path

            import Array(config_partial['import']), merged_result,
              already_imported, physical_path

            merge merged_result, config_partial, physical_path
          rescue => error
            error.message << ' when importing %s (really %s) into %s' %
            [ virtual_path, physical_path, importer ].map(&:inspect)

            raise error
          end
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

    public

    def merge dst_hash, src_hash, src_file, backtrace = []
      src_hash.each do |key, src_val|
        backtrace.push key

        catch :merged do
          if dst_hash.key? key
            dst_val = dst_hash[key]

            dst_file = @origin_by_value[dst_val]
            section = backtrace.join(':')

            if src_val.nil?
              LOG.warn 'empty section %s in %s removes value %s from %s' %
              [section, src_file, dst_val, dst_file].map(&:inspect)

              dst_hash.delete key
              throw :merged

            # merge the values
            elsif dst_val.is_a? Hash and src_val.is_a? Hash
              merge dst_val, src_val, src_file, backtrace
              throw :merged

            elsif dst_val.is_a? Array
              dst_val.concat Array(src_val)
              throw :merged

            elsif dst_val != nil
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
