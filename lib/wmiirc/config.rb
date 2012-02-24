require 'wmiirc'
require 'yaml'

module Wmiirc
class Config < Hash

  attr_reader :origins

  def initialize file
    Import.import self, file, @origins={}
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
    if origin = @origins[value]
      "#{origin}:#{section}"
    else
      section
    end
  end

  private

  def script key
    if scripts = self['script']
      scripts[key].each do |code|
        SANDBOX.eval code.to_s, origin(code, "script:#{key}")
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
      'grabmod'     => self['control']['mouse']['grab'],
    }

    begin
      Rumai.fs.ctl.write settings.map {|pair| pair.join(' ') }.join("\n")
      Rumai.fs.colrules.write self['display']['column']['rule']
      Rumai.fs.rules.write self['display']['client'].
        map {|rule, regexps| "/#{regexps.join('|')}/ #{rule}" }.join("\n")
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

            # expand symbolic references in the keyboard shortcut
            if keyboard = self['control']['keyboard']
              key = key.dup
              nil while key.gsub!(/\$\{(\w+)\}/){ keyboard[$1] }
            end

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

end
end
