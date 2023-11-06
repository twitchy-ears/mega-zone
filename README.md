# mega-zone
A wrapper for zone that will effect your other frames and windows as well as the one with focus.

![An emacs window showing two emacs frames next to each other both with zone nyan cats in them](/../screenshots/screenshots/mega-zone-screenshot-2023-11-06.png?raw=true "An example using the excellent https://github.com/emacsmirror/zone-nyan")

Another quick lunchtime (and some evening and other fiddles) hack where the instructions look something like this:

```
;; Load it
(require 'mega-zone)

;; Turn it on
(mega-zone-setup t)

;; Start it off
M-x zone
```

It has three modes by default controlled by settings to the `mega-zone-dispatch-action` variable, there's

* `show-mz-buffer` (default setting): Switches every other window to look at a buffer named in the `mega-zone-buffer-name` variable (defaults to `"*mega-zone*"`) that contains a string stored in the `mega-zone-buffer-text` variable (defaults to `"I AM MEGA ZONING"`).  Should effect console frames.
* `invisible`: Uses `make-frame-invisible` to hide all your other frames, then brings them back after zone has finished.  Doesn't effect console frames.
* `zone-all`: Switches all other windows to look at the `*zone*` buffer before it starts zoning, note this will mean they all reflect the zoned content of the current window rather than have their own zoned content.  Should effect console frames.

Essentially there is a dispatcher function that looks for functions called `mega-zone--%s` with the contents of the `mega-zone-dispatch-action` variable on the end, this means you can easily write your own functions.  The dispatcher wraps the functions in calls to `frameset-save` and `frameset-restore` so hopefully it will preserve whatever setup you had before without mangling it and each function doesn't need to do too much beyond mess with the windows and call `zone`.
