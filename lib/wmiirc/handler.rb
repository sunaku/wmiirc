# DSL for wmiirc configuration.
module Wmiirc

  class Handler < Hash
    def initialize
      super {|h,k| h[k] = [] }
    end

    ##
    # Registers the given block as a handler for the given key
    # and returns that handler, or if a block is not given,
    # executes all handlers registered for the given key.
    #
    def handle key, *args, &block
      if block
        self[key] << block

      elsif key? key
        self[key].each do |block|
          block.call(*args)
        end
      end

      block
    end
  end

  EVENTS  = Handler.new
  ACTIONS = Handler.new
  KEYS    = Handler.new

  ##
  # If a block is given, registers a handler
  # for the given event and returns the handler.
  #
  # Otherwise, executes all handlers for the given event.
  #
  def event(*a, &b)
    EVENTS.handle(*a, &b)
  end

  ##
  # Returns a list of registered event names.
  #
  def events
    EVENTS.keys
  end

  ##
  # If a block is given, registers a handler for
  # the given action and returns the handler.
  #
  # Otherwise, executes all handlers for the given action.
  #
  def action(*a, &b)
    ACTIONS.handle(*a, &b)
  end

  ##
  # Returns a list of registered action names.
  #
  def actions
    ACTIONS.keys
  end

  ##
  # If a block is given, registers a handler for
  # the given keypress and returns the handler.
  #
  # Otherwise, executes all handlers for the given keypress.
  #
  def key(*a, &b)
    KEYS.handle(*a, &b)
  end

  ##
  # Returns a list of registered keypress names.
  #
  def keys
    KEYS.keys
  end

end
