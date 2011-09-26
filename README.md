sunaku's wmii configuration in Ruby and YAML
==============================================================================

[![September 2011 screenshot](http://ompldr.org/tYWg1eQ)](http://ompldr.org/vYWg1eQ)
[![August 2011 screenshot](http://ompldr.org/tOXJjcg)](http://ompldr.org/vOXJjcg)
[![July 2011 screenshot](http://ompldr.org/tOWk0Zw)](http://ompldr.org/vOWk0Zw)
[![June 2011 screenshot](http://ompldr.org/tOHZzcw)](http://ompldr.org/vOHZzcw)
[![May 2011 screenshot](http://ompldr.org/tOGxyZQ)](http://ompldr.org/vOGxyZQ)
[![April 2011 screenshot](http://ompldr.org/tODNuag)](http://ompldr.org/vODNuag)
[![March 2011 screenshot](http://ompldr.org/tN3l2bQ)](http://ompldr.org/vN3l2bQ)

This is a [Ruby] and [YAML] based configuration of the [wmii] window manager.
It manipulates wmii through the [Rumai] library (which speaks directly to wmii
via the 9P2000 protocol and features [an interactive Ruby shell][RumaiShell]
for live experimentation) and offers a near "Desktop Environment" experience:

* Status bar applets with mouse, keyboard, and menu access.
* System, dialog, and menu (with history) integration.
* QWERTY, Dvorak, and Neo2 keyboard layouts.
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

All of this can be configured to suit your needs, of course.

[Ruby]: http://ruby-lang.org
[YAML]: http://yaml.org
[wmii]: http://wmii.suckless.org
[Rumai]: http://snk.tuxfamily.org/lib/rumai/
[RumaiShell]: http://snk.tuxfamily.org/lib/rumai/#EXAMPLES

In the past, this configuration was described in the following articles:

* <http://snk.tuxfamily.org/log/wmii-3.1-ruby-config.html>
* <http://wmii.suckless.org/alternative_wmiirc_scripts>

------------------------------------------------------------------------------
Prerequisites
------------------------------------------------------------------------------

* [wmii] 3.9 or newer.  Note that the `display/status/arrange` status bar
  applet requires a [patched version of wmii-hg revision 2758 or greater](
  http://code.google.com/p/wmii/issues/detail?id=232 ) in order to *persist*
  automated client arrangements.

* [Ruby] 1.9.2 or newer.

* [Rumai] 4.1.3 or newer:

      gem install rumai -v '>= 4.1.3'

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

* Read the inline documentation in the `~/.wmii/EXAMPLE.config.yaml` file to
  familiarize yourself with the configuration file's format and its sections.

* Edit the `~/.wmii/config.yaml` file to suit your needs.  For a working
  example, see [my personal configuration file](
  https://github.com/sunaku/wmiirc/blob/personal/config.yaml ).

* If wmii is already running, run `~/.wmii/wmiirc` or
  invoke the "reload" action to apply your changes.

------------------------------------------------------------------------------
Running
------------------------------------------------------------------------------

* Ensure that your `~/.xinitrc` allows you to restart wmii without having to
  lose your running applications if wmii crashes or is accidentally killed:

        xterm -e tail -F ~/.wmii/wmiirc.log &

        while true; do wmii
          xmessage 'Do you really want to quit wmii?' \
                   -buttons 'Yes:0,No:1' -center \
                   -default 'No' -timeout 30 \
          && break
        done
  For a working example, see [my personal configuration file](
  https://github.com/sunaku/home/blob/master/.xinitrc ).

* Run `startx` and wmii will automatically find and load this configuration.

------------------------------------------------------------------------------
Upgrading
------------------------------------------------------------------------------

    cd ~/.wmii
    make rebase

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
