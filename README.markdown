sunaku's wmii configuration in Ruby and YAML
==============================================================================

[![January 2012](http://omploader.org/tYzBqcQ)](http://omploader.org/vYzBqcQ)
[![September 2011](http://omploader.org/tYWg1eQ)](http://omploader.org/vYWg1eQ)
[![August 2011](http://omploader.org/tOXJjcg)](http://omploader.org/vOXJjcg)
[![July 2011](http://omploader.org/tOWk0Zw)](http://omploader.org/vOWk0Zw)
[![June 2011](http://omploader.org/tOHZzcw)](http://omploader.org/vOHZzcw)
[![May 2011](http://omploader.org/tOGxyZQ)](http://omploader.org/vOGxyZQ)
[![April 2011](http://omploader.org/tODNuag)](http://omploader.org/vODNuag)
[![March 2011](http://omploader.org/tN3l2bQ)](http://omploader.org/vN3l2bQ)

This is a [Ruby] and [YAML] based configuration of the [wmii] window manager.
It manipulates wmii through the [Rumai] library (which speaks directly to wmii
via the 9P2000 protocol and features [an interactive Ruby shell][RumaiShell]
for live experimentation) and offers a near "Desktop Environment" experience:

  * Status bar applets with mouse, keyboard, and menu access.
  * System, dialog, and menu (with history) integration.
  * Client grouping and mass manipulation thereof.
  * View and client access by menu and alphanumeric keys.
  * Automated client arrangements with optional persistence.
  * Detaching clients from current view and restoring them.
  * Zooming clients to temporary views and restoring them.
  * Closing all clients before exiting the window manager.
  * Script and stdout/err logging with automatic rotation.
  * Crash handling with error trace and recovery console.
  * Session state propagation between wmiirc instances.
  * And oh so much more... :-]

All of this can be configured to suit your needs, of course.  This wmii
configuration was also described in the following articles in the past:

  * <http://snk.tuxfamily.org/log/wmii-3.1-ruby-config.html>
  * <http://wmii.suckless.org/alternative_wmiirc_scripts>

[Ruby]: http://ruby-lang.org
[YAML]: http://yaml.org
[wmii]: http://wmii.suckless.org
[Rumai]: http://snk.tuxfamily.org/lib/rumai/
[RumaiShell]: http://snk.tuxfamily.org/lib/rumai/#EXAMPLES
[Kwalify]: http://www.kuwata-lab.com/kwalify/

------------------------------------------------------------------------------
Prerequisites
------------------------------------------------------------------------------

  * [wmii] 3.9 or newer.  I recommend [my personal branch of wmii-hg](
    https://github.com/sunaku/wmii/commits/personal ) for best results.

    Note that the `display/status/arrange` status bar applet requires a
    [patched version of wmii-hg revision 2758 or greater](
    https://github.com/sunaku/wmii/commit/33bf199436213788078581a8a94c2dcc98d6af16
    ) in order to *persist* automated client arrangements.

  * [Ruby] 1.9.2 or newer.

    I recommend using Ruby 1.9.3-p0 because it is [significantly more
    power-efficient](
    http://snk.tuxfamily.org/log/ruby-1.9.3-p0-power-efficiency.html ) than
    previous Ruby 1.9.x releases.

  * [Rumai] 4.1.3 or newer:

        gem install rumai -v '>= 4.1.3'

  * [Kwalify] 0.7.2 or newer:

        gem install kwalify -v '>= 0.7.2'

  * If you want to use the `status/weather.yaml` status bar applet:

        gem install barometer -v '~> 0.7.3'

  * If you want to use the `status/music/mpd.yaml` status bar applet:

        gem install librmpd -v '~> 0.1'

------------------------------------------------------------------------------
Installing
------------------------------------------------------------------------------

Backup:

    mv ~/.wmii ~/.wmii.backup
    mv ~/.wmii-hg ~/.wmii-hg.backup

Install:

    git clone git://github.com/sunaku/wmiirc.git ~/.wmii
    ln -s ~/.wmii ~/.wmii-hg

Branch:

    cd ~/.wmii
    make branch

------------------------------------------------------------------------------
Configuring
------------------------------------------------------------------------------

  * Edit the `~/.wmii/config.yaml` file (see the "Configuration File Format"
    section below) to suit your needs.  See [my personal configuration file](
    https://github.com/sunaku/wmiirc/blob/personal/config.yaml ) for example.

  * If wmii is already running, run `~/.wmii/wmiirc` or invoke the "reload"
    action from within an existing wmiirc instance to apply your changes.

### Configuration File Format

All Ruby code snippets in the configuration file have access to a `CONFIG`
constant which contains the data from the fully expanded configuration.  They
also have access to a `SESSION` constant which is a hash that is automatically
persisted across multiple instances of the wmiirc.

  * **import:** A list of files to inject into this one before evaluating it.
    Imported files may themselves import other files, recursively.  The
    contents of each successive imported file are merged with the previous
    one while *overwriting* the imported content in the following manner:

      * If the object being overwritten is a hash, then:

        * For keys that are present in the old hash but absent in the new
          hash, key-value pairs from the old hash are retained.

        * For keys that are present in the new hash but absent in the old
          hash, key-value pairs from the new hash are added.

        * For keys in common between the old and new hashes, key-value pairs
          from the old hash are replaced by key-value pairs from the new hash.

      * If the object being overwritten is an array, then items from the new
        array are appended to end of the old array.

      * If the object being overwritten is a scalar value such as a string,
        integer, or boolean, then the old value is replaced by the new value.

  * **require:** A list of Ruby libraries to load before evaluating this
    configuration file.  If a library is a RubyGem, you can constrain its
    version number like this:

          require:
            - some_gem
            - another_gem: '>= 1.0.9'
            - yet_another_gem: ['>= 1.0.9', '< 2']
            - some_ruby_library

  * **script:** Arbitrary logic to evaluate while processing this file.

    * **before:** Array of Ruby code snippets to evaulate before processing
      the overall configuration.

    * **after:** Array of Ruby code snippets to evaulate after processing the
      overall configuration.

  * **status:** Status bar applet definitions.

      All Ruby code snippets that are evaluated inside a `Wmiirc::Status`
      object have access to a `refresh` method that triggers redrawing of
      the label of that status bar applet.  They also have access to a `@id`
      variable which is a sequence number counting the number of instances of
      this particular status bar applet that have been created thus far.

      * **_name of the status bar applet that you want to define_:**

        * **params:** Hash of parameters to pass to the constructor.  These
          are later available as instance variables in the Ruby code
          snippets that are evaluated inside this status bar applet.

        * **refresh:** Number of seconds to wait before updating the label.
          To disable automatic refreshing, set this parameter to 0 (zero).

        * **script:** Ruby code to evaluate in the `Wmiirc::Status` object.

        * **label:** Ruby code whose result is displayed as the content.
          This code is placed in a `label()` method in the `Wmiirc::Status`
          object.

        * **control:**

          * **event:** Hash of event name to Ruby code to evaluate in the
            `Wmiirc::Status` object.

          * **action:** Hash of action name to Ruby code to evaluate in
            the `Wmiirc::Status` object.

          * **mouse_action:** Hash of mouse event name to action name.

  * **display:** Appearance settings.

    * **bar:** Where to display the horizontal status bar?

    * **font:** Font to use in all text drawn by wmii.

    * **border:** Thickness of client border (measured in pixels).

    * **color:** Color schemes for everything drawn by wmii.  These are
      expressed in `#foreground #background #border` format, where
      *foreground*, *background*, and *border* are 6-digit HEX values.

      * **desktop:** Color of the desktop background (single color only).

      * **focus:** Colors of things that have focus.

      * **normal:** Colors of things that do not have focus.

    * **columns:** Settings for columns drawn by wmii.

        * **mode:** The wmii "colmode" setting.

        * **rule:** The wmii "colrules" setting.

    * **client:** Settings for clients handled by wmii.  See the documentation
      for the underlying wmii "rules" setting for more information.

        * **_rule to apply_:** Array of strings that represent regular
          expressions to match against a string containing a newly created
          client's WM_CLASS and WM_NAME attributes separated by a colon (:).

    * **refresh:** Refresh rate for status bar applets (measured in seconds).

    * **status:** Status bar applet instances.

        All Ruby code snippets that are evaluated inside a `Wmiirc::Status`
        object have access to a `refresh` method that triggers redrawing of
        the label of that status bar applet.  They also have access to a `@id`
        variable which is a sequence number counting the number of instances
        of this particular status bar applet that have been created thus far.

        * **- _name of the status bar applet that you want to instantiate_:**

          * **params:** Hash of parameters to pass to the constructor.  These
            are later available as instance variables in the Ruby code
            snippets that are evaluated inside this status bar applet.

          * **refresh:** Number of seconds to wait before updating the label.
            To disable automatic refreshing, set this parameter to 0 (zero).

          * **script:** Ruby code to evaluate in the `Wmiirc::Status` object.

          * **label:** Ruby code whose result is displayed as the content.
            This code is placed in a `label()` method in the `Wmiirc::Status`
            object.

            * **control:**

              * **event:** Hash of event name to Ruby code to evaluate in the
                `Wmiirc::Status` object.

              * **action:** Hash of action name to Ruby code to evaluate in
                the `Wmiirc::Status` object.

              * **mouse_action:** Hash of mouse event name to action name.

  * **control:** Interaction settings.

    * **action:** Hash of action name to Ruby code to evaluate.

    * **event:** Hash of event name to Ruby code to evaluate.

        The Ruby code has access to an "argv" variable which is a list of
        arguments that were passed to the event.

        Keep in mind that these event handlers *block* the wmiirc event loop.
        In other words, no new events can be handled until the current one
        finishes. So try to keep your event handlers short and quick.

        If your event handler needs to perform a long-running operation, then be
        sure to wrap that operation inside a Ruby thread.

    * **mouse:** Mapping from X mouse codes to event names.

      * **grab:** The wmii "grabmod" setting.

    * **keyboard:** Hash of shortcut prefix name to shortcut key sequence.

    * **keyboard_action:** Hash of shortcut key sequence to action name.

        A key sequence may contain `${...}` expressions which are replaced
        with the value corresponding to `...` in the "control:keyboard"
        section of this configuration.

        For example, if the "control:keyboard" section was defined as follows,
        then the `${d},${c}` key sequence would be expanded into `Mod4-y,y`.

            control:
              keyboard:
                a: 4
                b: Mod${a}
                c: y
                d: ${b}-${c}

------------------------------------------------------------------------------
Running
------------------------------------------------------------------------------

  * Ensure that your `~/.xinitrc` allows you to restart wmii without having to
    lose your running applications if wmii crashes or is accidentally killed:

        xterm -e tail -f ~/.wmii/wmiirc.log &
        while true; do wmii
          xmessage 'INSERT COIN TO CONTINUE' \
          -buttons 'Insert Coin:0,Game Over' \
          -default 'Insert Coin' -timeout 30 \
          -center || break
        done

    For a working example, see [my personal configuration file](
    https://github.com/sunaku/home/blob/master/.xinitrc ).

  * Run `startx` and wmii will automatically find and load this configuration.

------------------------------------------------------------------------------
Upgrading
------------------------------------------------------------------------------

    cd ~/.wmii
    make rebase

If this fails because Git reports that you have unstaged changes, you can
stash your changes away temporarily and restore them after the upgrade:

    git stash
    make rebase # now it works
    git stash apply

------------------------------------------------------------------------------
Hacking
------------------------------------------------------------------------------

To use the development version of [Rumai] directly from its source code
repository (instead of the currently published gem version), run this:

    cd ~/.wmii
    make rumai

------------------------------------------------------------------------------
Contributing
------------------------------------------------------------------------------

Fork this project on GitHub and send pull requests.

------------------------------------------------------------------------------
Bugs, Features, Issues, Questions
------------------------------------------------------------------------------

File a report on [the issue tracker](http://github.com/sunaku/wmiirc/issues/).

------------------------------------------------------------------------------
License
------------------------------------------------------------------------------

Released under the ISC license.  See the LICENSE file for details.
