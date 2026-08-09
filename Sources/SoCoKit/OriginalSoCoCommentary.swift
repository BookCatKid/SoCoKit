// This file preserves the explanatory comments and docstrings from the original SoCo
// Python implementation. The Swift port keeps behavior in the corresponding Swift files;
// this companion source keeps the original rationale, warnings, protocol notes, and usage
// explanations verbatim so they remain available next to the ported library source.
//
// Generated from Reference/SoCo-Python/soco. Do not strip this file when distributing
// SoCoKit: a large amount of Sonos protocol knowledge lives in these notes.


// MARK: - Original commentary: __init__.py
// [__init__.py:1] module docstring:
// SoCo (Sonos Controller) is a simple library to control Sonos speakers.
//
// [__init__.py:3] There is no need for all strings here to be unicode, and Py2 cannot import
// [__init__.py:4] modules with unicode names so do not use from __future__ import
// [__init__.py:5] unicode_literals
// [__init__.py:6] https://github.com/SoCo/SoCo/issues/98
// [__init__.py:7] 
// [__init__.py:16] Will be parsed by setup.py to determine package metadata
// [__init__.py:18] Please increment the version number and add the suffix "-dev" after
// [__init__.py:19] a release, to make it possible to identify in-development code
// [__init__.py:24] You really should not `import *` - it is poor practice
// [__init__.py:25] but if you do, here is what you get:
// [__init__.py:34] http://docs.python.org/2/howto/logging.html#library-config
// [__init__.py:35] Avoids spurious error messages if no logger is configured by the user

// MARK: - Original commentary: alarms.py
// [alarms.py:1] module docstring:
// This module contains classes relating to Sonos Alarms.
//
// [alarms.py:22] is_valid_recurrence docstring:
// Check that ``text`` is a valid recurrence string.
// 
//     A valid recurrence string is  ``DAILY``, ``ONCE``, ``WEEKDAYS``,
//     ``WEEKENDS`` or of the form ``ON_DDDDDD`` where ``D`` is a number from 0-6
//     representing a day of the week (Sunday is 0), e.g. ``ON_034`` meaning
//     Sunday, Wednesday and Thursday
// 
//     Args:
//         text (str): the recurrence string to check.
// 
//     Returns:
//         bool: `True` if the recurrence string is valid, else `False`.
// 
//     Examples:
// 
//         >>> from soco.alarms import is_valid_recurrence
//         >>> is_valid_recurrence('WEEKENDS')
//         True
//         >>> is_valid_recurrence('')
//         False
//         >>> is_valid_recurrence('ON_132')  # Mon, Tue, Wed
//         True
//         >>> is_valid_recurrence('ON_666')  # Sat
//         True
//         >>> is_valid_recurrence('ON_3421') # Mon, Tue, Wed, Thur
//         True
//         >>> is_valid_recurrence('ON_123456789') # Too many digits
//         False
//     
//
// [alarms.py:57] Alarms docstring:
// A class representing all known Sonos Alarms.
// 
//     Is a singleton and every `Alarms()` object will return the same instance.
// 
//     Example use:
// 
//         >>> get_alarms()
//         {469: <Alarm id:469@22:07:41 at 0x7f5198797dc0>,
//          470: <Alarm id:470@22:07:46 at 0x7f5198797d60>}
//         >>> alarms = Alarms()
//         >>> alarms.update()
//         >>> alarms.alarms
//         {469: <Alarm id:469@22:07:41 at 0x7f5198797dc0>,
//          470: <Alarm id:470@22:07:46 at 0x7f5198797d60>}
//         >>> for alarm in alarms:
//         ...     alarm
//         ...
//         <Alarm id:469@22:07:41 at 0x7f5198797dc0>
//         <Alarm id:470@22:07:46 at 0x7f5198797d60>
//         >>> alarms[470]
//         <Alarm id:470@22:07:46 at 0x7f5198797d60>
//         >>> new_alarm = Alarm(zone)
//         >>> new_alarm.save()
//         471
//         >>> new_alarm.recurrence = "ONCE"
//         >>> new_alarm.save()
//         471
//         >>> alarms.alarms
//         {469: <Alarm id:469@22:07:41 at 0x7f5198797dc0>,
//          470: <Alarm id:470@22:07:46 at 0x7f5198797d60>,
//          471: <Alarm id:471@22:08:40 at 0x7f51987f1b50>}
//         >>> alarms[470].remove()
//         >>> alarms.alarms
//         {469: <Alarm id:469@22:07:41 at 0x7f5198797dc0>,
//          471: <Alarm id:471@22:08:40 at 0x7f51987f1b50>}
//         >>> for alarm in alarms:
//         ...     alarm.remove()
//         ...
//         >>> a.alarms
//         {}
//     
//
// [alarms.py:102] Alarms.__init__ docstring:
// Initialize the instance.
//
// [alarms.py:112] Alarms.last_alarm_list_version docstring:
// Return last seen alarm list version.
//
// [alarms.py:117] Alarms.last_alarm_list_version docstring:
// Store alarm list version and store UID/ID values.
//
// [alarms.py:123] Alarms.__iter__ docstring:
// Return an interator for all alarms.
//
// [alarms.py:127] Alarms.__len__ docstring:
// Return the number of alarms.
//
// [alarms.py:131] Alarms.__getitem__ docstring:
// Return the alarm by ID.
//
// [alarms.py:135] Alarms.get docstring:
// Return the alarm by ID or None.
//
// [alarms.py:139] Alarms.update docstring:
// Update all alarms and current alarm list version.
// 
//         Raises:
//             SoCoException: If the 'CurrentAlarmListVersion' value is unexpected.
//                 May occur if the provided zone is from a different household.
//         
//
// [alarms.py:197] Alarms.update_skipped docstring:
// Update the zone for any skipped alarms and move to main list if possible.
//
// [alarms.py:205] Alarms.get_next_alarm_datetime docstring:
// Get the next alarm trigger datetime.
// 
//         Args:
//             from_datetime (datetime, optional): a datetime to reference next
//                 alarms from. This argument filters by alarms on or after this
//                 exact time. Since alarms do not store timezone information,
//                 the output timezone will match this input argument. Defaults
//                 to `datetime.now()`.
//             include_disabled (bool, optional): If `True` then disabled alarms
//                 will be included in searching for the next alarm. Defaults to
//                 `False`.
//             zone_uid (str, optional): If set the alarms will be filtered by
//                 zone with this UID. Defaults to `None`.
// 
//         Returns:
//             datetime: The next alarm trigger datetime or None if disabled
// 
//         Note:
//             Alarms in `alarms_skipped` (whose speaker was not registered at
//             the time of the last `update()`) are not considered.
//         
//
// [alarms.py:248] Alarm docstring:
// A class representing a Sonos Alarm.
// 
//     Alarms may be created or updated and saved to, or removed from the Sonos
//     system. An alarm is not automatically saved. Call `save()` to do that.
//     
//
// [alarms.py:255] Alarm.__init__ docstring:
// 
//         Args:
//             zone (`SoCo`): The soco instance which will play the alarm.
//             start_time (datetime.time, optional): The alarm's start time.
//                 Specify hours, minutes and seconds only. Defaults to the
//                 current time.
//             duration (datetime.time, optional): The alarm's duration. Specify
//                 hours, minutes and seconds only. May be `None` for unlimited
//                 duration. Defaults to `None`.
//             recurrence (str, optional): A string representing how
//                 often the alarm should be triggered. Can be ``DAILY``,
//                 ``ONCE``, ``WEEKDAYS``, ``WEEKENDS`` or of the form
//                 ``ON_DDDDDD`` where ``D`` is a number from 0-6 representing a
//                 day of the week (Sunday is 0), e.g. ``ON_034`` meaning Sunday,
//                 Wednesday and Thursday. Defaults to ``DAILY``.
//             enabled (bool, optional): `True` if alarm is enabled, `False`
//                 otherwise. Defaults to `True`.
//             program_uri(str, optional): The uri to play. If `None`, the
//                 built-in Sonos chime sound will be used. Defaults to `None`.
//             program_metadata (str, optional): The metadata associated with
//                 'program_uri'. Defaults to ''.
//             play_mode(str, optional): The play mode for the alarm. Can be one
//                 of ``NORMAL``, ``SHUFFLE_NOREPEAT``, ``SHUFFLE``,
//                 ``REPEAT_ALL``, ``REPEAT_ONE``, ``SHUFFLE_REPEAT_ONE``.
//                 Defaults to ``NORMAL``.
//             volume (int, optional): The alarm's volume (0-100). Defaults to 20.
//             include_linked_zones (bool, optional): `True` if the alarm should
//                 be played on the other speakers in the same group, `False`
//                 otherwise. Defaults to `False`.
//             room_uuid (str, optional): The UUID of the room/speaker this alarm
//                 belongs to. Set automatically when loading alarms from the
//                 Sonos system. Defaults to `None`.
//         
//
// [alarms.py:324] Alarm.update docstring:
// Update an existing Alarm instance using the same arguments as __init__.
//
// [alarms.py:332] Alarm.play_mode docstring:
// 
//         `str`: The play mode for the alarm.
// 
//             Can be one of ``NORMAL``, ``SHUFFLE_NOREPEAT``, ``SHUFFLE``,
//             ``REPEAT_ALL``, ``REPEAT_ONE``, ``SHUFFLE_REPEAT_ONE``.
//         
//
// [alarms.py:342] Alarm.play_mode docstring:
// See `playmode`.
//
// [alarms.py:350] Alarm.volume docstring:
// `int`: The alarm's volume (0-100).
//
// [alarms.py:355] Alarm.volume docstring:
// See `volume`.
//
// [alarms.py:362] Alarm.recurrence docstring:
// `str`: How often the alarm should be triggered.
// 
//         Can be ``DAILY``, ``ONCE``, ``WEEKDAYS``, ``WEEKENDS`` or of the form
//         ``ON_DDDDDDD`` where ``D`` is a number from 0-7 representing a day of
//         the week (Sunday is 0), e.g. ``ON_034`` meaning Sunday, Wednesday and
//         Thursday.
//         
//
// [alarms.py:373] Alarm.recurrence docstring:
// See `recurrence`.
//
// [alarms.py:380] Alarm.save docstring:
// Save the alarm to the Sonos system.
// 
//         Returns:
//             str: The alarm ID, or `None` if no alarm was saved.
// 
//         Raises:
//             ~soco.exceptions.SoCoUPnPException: if the alarm cannot be created
//                 because there is already an alarm for this room at the specified
//                 time.
//             SoCoException: if `zone` is `None` (alarm was loaded for a speaker
//                 that was not yet registered). Call `Alarms.update_skipped()`
//                 with the zone once it is available before saving.
//         
//
// [alarms.py:434] Alarm.remove docstring:
// Remove the alarm from the Sonos system.
// 
//         There is no need to call `save`. The Python instance is not deleted,
//         and can be saved back to Sonos again if desired.
// 
//         Returns:
//             bool: If the removal was sucessful.
//         
//
// [alarms.py:450] Alarm.alarm_id docstring:
// `str`: The ID of the alarm, or `None`.
//
// [alarms.py:454] Alarm.get_next_alarm_datetime docstring:
// Get the next alarm trigger datetime.
// 
//         Args:
//             from_datetime (datetime, optional): a datetime to reference next
//                 alarms from. This argument filters by alarms on or after this
//                 exact time. Since alarms do not store timezone information,
//                 the output timezone will match this input argument. Defaults
//                 to `datetime.now()`.
//             include_disabled (bool, optional): If `True` then the next datetime
//                 will be computed even if the alarm is disabled. Defaults to
//                 `False`.
// 
//         Returns:
//             datetime: The next alarm trigger datetime or None if disabled
//         
//
// [alarms.py:515] get_alarms docstring:
// Get a set of all alarms known to the Sonos system.
// 
//     Args:
//         zone (soco.SoCo, optional): a SoCo instance to query. If None, a random
//             instance is used. Defaults to `None`.
// 
//     Returns:
//         set: A set of `Alarm` instances
//     
//
// [alarms.py:530] remove_alarm_by_id docstring:
// Remove an alarm from the Sonos system by its ID.
// 
//     Args:
//         zone (`SoCo`): A SoCo instance, which can be any zone that belongs
//             to the Sonos system in which the required alarm is defined.
//         alarm_id (str): The ID of the alarm to be removed.
// 
//     Returns:
//         bool: `True` if the alarm is found and removed, `False` otherwise.
//     
//
// [alarms.py:549] parse_alarm_payload docstring:
// Parse the XML payload response and return a dict of `Alarm` kwargs.
//
// [alarms.py:16] Never reoccurs
// [alarms.py:175] Update existing and create new Alarm instances
// [alarms.py:186] pylint: disable=protected-access
// [alarms.py:192] Prune alarms removed externally
// [alarms.py:357] max 100
// [alarms.py:359] Coerce in range
// [alarms.py:429] The alarm has been saved before. Update it instead.
// [alarms.py:476] Convert helper words to number recurrences
// [alarms.py:481] For the purpose of finding the next alarm a "once" trigger that has
// [alarms.py:482] yet to trigger is everyday (the next possible day)
// [alarms.py:486] Trim the 'ON_' prefix, convert to int, remove duplicates
// [alarms.py:489] Convert Sonos weekdays to Python weekdays
// [alarms.py:490] Sonos starts on Sunday, Python starts on Monday
// [alarms.py:496] Begin search from next day if it would have already triggered today
// [alarms.py:501] Find first day
// [alarms.py:554] An alarm list looks like this:
// [alarms.py:555] <Alarms>
// [alarms.py:556] <Alarm ID="14" StartTime="07:00:00"
// [alarms.py:557] Duration="02:00:00" Recurrence="DAILY" Enabled="1"
// [alarms.py:558] RoomUUID="RINCON_000ZZZZZZ1400"
// [alarms.py:559] ProgramURI="x-rincon-buzzer:0" ProgramMetaData=""
// [alarms.py:560] PlayMode="SHUFFLE_NOREPEAT" Volume="25"
// [alarms.py:561] IncludeLinkedZones="0"/>
// [alarms.py:562] <Alarm ID="15" StartTime="07:00:00"
// [alarms.py:563] Duration="02:00:00" Recurrence="DAILY" Enabled="1"
// [alarms.py:564] RoomUUID="RINCON_000ZZZZZZ01400"
// [alarms.py:565] ProgramURI="x-rincon-buzzer:0" ProgramMetaData=""
// [alarms.py:566] PlayMode="SHUFFLE_NOREPEAT" Volume="25"
// [alarms.py:567] IncludeLinkedZones="0"/>
// [alarms.py:568] </Alarms>
// [alarms.py:581] StartTime not StartLocalTime which is used by CreateAlarm

// MARK: - Original commentary: cache.py
// [cache.py:1] module docstring:
// This module contains the classes underlying SoCo's caching system.
//
// [cache.py:17] _BaseCache docstring:
// An abstract base class for the cache.
//
// [cache.py:28] _BaseCache.put docstring:
// Put an item into the cache.
//
// [cache.py:32] _BaseCache.get docstring:
// Get an item from the cache.
//
// [cache.py:36] _BaseCache.delete docstring:
// Delete an item from the cache.
//
// [cache.py:40] _BaseCache.clear docstring:
// Empty the whole cache.
//
// [cache.py:45] NullCache docstring:
// A cache which does nothing.
// 
//     Useful for debugging.
//     
//
// [cache.py:51] NullCache.put docstring:
// Put an item into the cache.
//
// [cache.py:54] NullCache.get docstring:
// Get an item from the cache.
//
// [cache.py:58] NullCache.delete docstring:
// Delete an item from the cache.
//
// [cache.py:61] NullCache.clear docstring:
// Empty the whole cache.
//
// [cache.py:65] TimedCache docstring:
// A simple thread-safe cache for caching method return values.
// 
//     The cache key is generated by from the given ``*args`` and ``**kwargs``.
//     Items are expired from the cache after a given period of time.
// 
//     Example:
//         >>> from time import sleep
//         >>> cache = TimedCache()
//         >>> cache.put("item", 'some', kw='args', timeout=3)
//         >>> # Fetch the item again, by providing the same args and kwargs.
//         >>> assert cache.get('some', kw='args') == "item"
//         >>> # Providing different args or kwargs will not return the item.
//         >>> assert not cache.get('some', 'otherargs') == "item"
//         >>> # Waiting for less than the provided timeout does not cause the
//         >>> # item to expire.
//         >>> sleep(2)
//         >>> assert cache.get('some', kw='args') == "item"
//         >>> # But waiting for longer does.
//         >>> sleep(2)
//         >>> assert not cache.get('some', kw='args') == "item"
// 
//     Warning:
//         At present, the cache can theoretically grow and grow, since entries
//         are not automatically purged, though in practice this is unlikely
//         since there are not that many different combinations of arguments in
//         the places where it is used in SoCo, so not that many different
//         cache entries will be created. If this becomes a problem,
//         use a thread and timer to purge the cache, or rewrite this to use
//         LRU logic!
//     
//
// [cache.py:97] TimedCache.__init__ docstring:
// 
//         Args:
//             default_timeout (int): The default number of seconds after
//             which items will be expired.
//         
//
// [cache.py:109] TimedCache.get docstring:
// Get an item from the cache for this combination of args and kwargs.
// 
//         Args:
//             *args: any arguments.
//             **kwargs: any keyword arguments.
// 
//         Returns:
//             object: The object which has been found in the cache, or `None` if
//             no unexpired item is found. This means that there is no point
//             storing an item in the cache if it is `None`.
// 
//         
//
// [cache.py:140] TimedCache.put docstring:
// Put an item into the cache, for this combination of args and kwargs.
// 
//         Args:
//             *args: any arguments.
//             **kwargs: any keyword arguments. If ``timeout`` is specified as one
//                  of the keyword arguments, the item will remain available
//                  for retrieval for ``timeout`` seconds. If ``timeout`` is
//                  `None` or not specified, the ``default_timeout`` for this
//                  cache will be used. Specify a ``timeout`` of 0 (or ensure that
//                  the ``default_timeout`` for this cache is 0) if this item is
//                  not to be cached.
//         
//
// [cache.py:164] TimedCache.delete docstring:
// Delete an item from the cache for this combination of args and
//         kwargs.
//
// [cache.py:174] TimedCache.clear docstring:
// Empty the whole cache.
//
// [cache.py:180] TimedCache.make_key docstring:
// Generate a unique, hashable, representation of the args and kwargs.
// 
//         Args:
//             *args: any arguments.
//             **kwargs: any keyword arguments.
// 
//         Returns:
//             str: the key.
//         
//
// [cache.py:199] Cache docstring:
// A factory class which returns an instance of a cache subclass.
// 
//     A `TimedCache` is returned, unless `config.CACHE_ENABLED` is `False`,
//     in which case a `NullCache` will be returned.
//     
//
// [cache.py:1] pylint: disable=not-context-manager,useless-object-inheritance
// [cache.py:3] NOTE: The pylint not-content-manager warning is disabled pending the fix of
// [cache.py:4] a bug in pylint https://github.com/PyCQA/pylint/issues/782
// [cache.py:6] NOTE: useless-object-inheritance needed for Python 2.x compatability
// [cache.py:20] pylint: disable=no-self-use, unused-argument
// [cache.py:25] : `bool`: whether the cache is enabled
// [cache.py:104] : `int`: The default caching expiry interval in seconds.
// [cache.py:106] A thread lock for the cache
// [cache.py:124] Look in the cache to see if there is an unexpired item. If there is
// [cache.py:125] we can just return the cached result.
// [cache.py:127] Lock and load
// [cache.py:135] An expired item is present - delete it
// [cache.py:137] Nothing found
// [cache.py:155] Check for a timeout keyword, store and remove it.
// [cache.py:160] Store the item, along with the time at which it will expire
// [cache.py:190] This is not entirely straightforward, since args and kwargs may
// [cache.py:191] contain mutable items and unicode. Possibilities include using
// [cache.py:192] __repr__, frozensets, and code from Py3's LRU cache. But pickle
// [cache.py:193] works, and although it is not as fast as some methods, it is good
// [cache.py:194] enough at the moment

// MARK: - Original commentary: config.py
// [config.py:1] module docstring:
// This module contains configuration variables.
// 
// They may be set by your code as follows::
// 
//     from soco import config
//     ...
//     config.VARIABLE = value
//

// MARK: - Original commentary: core.py
// [core.py:1] module docstring:
// The core module contains the SoCo class that implements
// the main entry to the SoCo functionality
//
// [core.py:88] _ArgsSingleton docstring:
// A metaclass which permits only a single instance of each derived class
//     sharing the same `_class_group` class attribute to exist for any given set
//     of positional arguments.
// 
//     Attempts to instantiate a second instance of a derived class, or another
//     class with the same `_class_group`, with the same args will return the
//     existing instance.
// 
//     For example:
// 
//     >>> class ArgsSingletonBase(object):
//     ...     __metaclass__ = _ArgsSingleton
//     ...
//     >>> class First(ArgsSingletonBase):
//     ...     _class_group = "greeting"
//     ...     def __init__(self, param):
//     ...         pass
//     ...
//     >>> class Second(ArgsSingletonBase):
//     ...     _class_group = "greeting"
//     ...     def __init__(self, param):
//     ...         pass
//     >>> assert First('hi') is First('hi')
//     >>> assert First('hi') is First('bye')
//     AssertionError
//     >>> assert First('hi') is Second('hi')
//     
//
// [core.py:128] _SocoSingletonBase docstring:
// The base class for the SoCo class.
// 
//     Uses a Python 2 and 3 compatible method of declaring a metaclass. See, eg,
//     here: http://www.artima.com/weblogs/viewpost.jsp?thread=236234 and
//     here: http://mikewatkins.ca/2008/11/29/python-2-and-3-metaclasses/
//     
//
// [core.py:139] only_on_master docstring:
// Decorator that raises SoCoSlaveException on master call on slave.
//
// [core.py:143] only_on_master.inner_function docstring:
// Master checking inner function.
//
// [core.py:156] only_on_soundbars docstring:
// Decorator to raise an exception on soundbar property access on non-soundbars.
//
// [core.py:173] SoCo docstring:
// A simple class for controlling a Sonos speaker.
// 
//     For any given set of arguments to __init__, only one instance of this class
//     may be created. Subsequent attempts to create an instance with the same
//     arguments will return the previously created instance. This means that all
//     SoCo instances created with the same ip address are in fact the *same* SoCo
//     instance, reflecting the real world position.
// 
//     ..  rubric:: Basic Methods
//     ..  autosummary::
// 
//         play_from_queue
//         play
//         play_uri
//         pause
//         stop
//         end_direct_control_session
//         seek
//         next
//         previous
//         mute
//         volume
//         play_mode
//         shuffle
//         repeat
//         cross_fade
//         ramp_to_volume
//         set_relative_volume
//         get_current_track_info
//         get_current_media_info
//         get_speaker_info
//         get_current_transport_info
// 
//     ..  rubric:: Queue Management
//     ..  autosummary::
// 
//         get_queue
//         queue_size
//         add_to_queue
//         add_uri_to_queue
//         add_multiple_to_queue
//         remove_from_queue
//         clear_queue
// 
//     ..  rubric:: Group Management
//     ..  autosummary::
// 
//         group
//         partymode
//         join
//         unjoin
//         all_groups
//         all_zones
//         visible_zones
// 
//     ..  rubric:: Player Identity and Settings
//     ..  autosummary::
// 
//         player_name
//         uid
//         household_id
//         is_visible
//         is_bridge
//         is_coordinator
//         is_soundbar
//         is_satellite
//         has_satellites
//         sub_crossover
//         sub_enabled
//         sub_gain
//         is_subwoofer
//         has_subwoofer
//         channel
//         bass
//         treble
//         loudness
//         balance
//         audio_delay
//         night_mode
//         dialog_mode
//         surround_enabled
//         surround_full_volume_enabled
//         surround_volume_tv
//         surround_volume_music
//         soundbar_audio_input_format
//         supports_fixed_volume
//         fixed_volume
//         soundbar_audio_input_format
//         soundbar_audio_input_format_code
//         trueplay
//         status_light
//         buttons_enabled
//         voice_service_configured
//         mic_enabled
// 
//     ..  rubric:: Playlists and Favorites
//     ..  autosummary::
// 
//         get_sonos_playlists
//         create_sonos_playlist
//         create_sonos_playlist_from_queue
//         remove_sonos_playlist
//         add_item_to_sonos_playlist
//         reorder_sonos_playlist
//         clear_sonos_playlist
//         move_in_sonos_playlist
//         remove_from_sonos_playlist
//         get_sonos_playlist_by_attr
//         get_favorite_radio_shows
//         get_favorite_radio_stations
//         get_sonos_favorites
// 
//     ..  rubric:: Miscellaneous
//     ..  autosummary::
// 
//         music_source
//         music_source_from_uri
//         is_playing_radio
//         is_playing_tv
//         is_playing_line_in
//         switch_to_line_in
//         switch_to_tv
//         available_actions
//         set_sleep_timer
//         get_sleep_timer
//         create_stereo_pair
//         separate_stereo_pair
//         get_battery_info
//         boot_seqnum
// 
//     .. warning::
// 
//         Properties on this object are not generally cached and may obtain
//         information over the network, so may take longer than expected to set
//         or return a value. It may be a good idea for you to cache the value in
//         your own code.
// 
//     .. note::
// 
//         Since all methods/properties on this object will result in an UPnP
//         request, they might result in an exception without it being mentioned
//         in the Raises section.
// 
//         In most cases, the exception will be a
//         :class:`soco.exceptions.SoCoUPnPException`
//         (if the player returns an UPnP error code), but in special cases
//         it might also be another :class:`soco.exceptions.SoCoException`
//         or even a `requests` exception.
// 
//     
//
// [core.py:384] SoCo.boot_seqnum docstring:
// int: The boot sequence number.
//
// [core.py:390] SoCo.player_name docstring:
// str: The speaker's name.
//
// [core.py:401] SoCo.player_name docstring:
// Set the speaker's name.
//
// [core.py:412] SoCo.uid docstring:
// str: A unique identifier.
// 
//         Looks like: ``'RINCON_000XXXXXXXXXX1400'``
//         
//
// [core.py:439] SoCo.household_id docstring:
// str: A unique identifier for all players in a household.
// 
//         Looks like: ``'Sonos_asahHKgjgJGjgjGjggjJgjJG34'``
//         
//
// [core.py:453] SoCo.is_visible docstring:
// bool: Is this zone visible?
// 
//         A zone might be invisible if, for example, it is a bridge, or the slave
//         part of stereo pair.
//         
//
// [core.py:466] SoCo.is_bridge docstring:
// bool: Is this zone a bridge?
//
// [core.py:479] SoCo.is_coordinator docstring:
// bool: Is this zone a group coordinator?
//
// [core.py:489] SoCo.is_satellite docstring:
// bool: Is this zone a satellite in a home theater setup?
//
// [core.py:495] SoCo.has_satellites docstring:
// bool: Is this zone configured with satellites in a home theater setup?
// 
//         Will only return True on the primary device in a home theater configuration.
//         
//
// [core.py:504] SoCo.is_subwoofer docstring:
// bool: Is this zone a subwoofer?
//
// [core.py:511] SoCo.has_subwoofer docstring:
// bool: Is this zone configured with a subwoofer?
// 
//         Only provides reliable results when called on the soundbar
//         or subwoofer devices if configured in a home theater setup.
// 
//         Sonos Amp devices support a directly-connected 3rd party subwoofer
//         connected over RCA. This property is always enabled for those devices.
//         
//
// [core.py:537] SoCo.channel docstring:
// str: Location of this zone in a home theater or paired configuration.
// 
//         Can be one of "LF,RF", "LF", "RF", "LR", "RR", "SW", or None.
//         
//
// [core.py:551] SoCo.is_soundbar docstring:
// bool: Is this zone a soundbar (i.e. has night mode etc.)?
//
// [core.py:563] SoCo.is_arc_ultra_soundbar docstring:
// bool: Is this zone an arc ultra sound bar?
//
// [core.py:571] SoCo.play_mode docstring:
// str: The queue's play mode.
// 
//         Case-insensitive options are:
// 
//         *   ``'NORMAL'`` -- Turns off shuffle and repeat.
//         *   ``'REPEAT_ALL'`` -- Turns on repeat and turns off shuffle.
//         *   ``'SHUFFLE'`` -- Turns on shuffle *and* repeat. (It's
//             strange, I know.)
//         *   ``'SHUFFLE_NOREPEAT'`` -- Turns on shuffle and turns off
//             repeat.
//         *   ``'REPEAT_ONE'`` -- Turns on repeat one and turns off shuffle.
//         *   ``'SHUFFLE_REPEAT_ONE'`` -- Turns on shuffle *and* repeat one. (It's
//             strange, I know.)
// 
//         
//
// [core.py:595] SoCo.play_mode docstring:
// Set the speaker's mode.
//
// [core.py:604] SoCo.shuffle docstring:
// bool: The queue's shuffle option.
// 
//         True if enabled, False otherwise.
//         
//
// [core.py:612] SoCo.shuffle docstring:
// Set the queue's shuffle option.
//
// [core.py:618] SoCo.repeat docstring:
// bool: The queue's repeat option.
// 
//         True if enabled, False otherwise.
// 
//         Can also be the string ``'ONE'`` for play mode
//         ``'REPEAT_ONE'``.
//         
//
// [core.py:629] SoCo.repeat docstring:
// Set the queue's repeat option
//
// [core.py:636] SoCo.cross_fade docstring:
// bool: The speaker's cross fade state.
// 
//         True if enabled, False otherwise
//         
//
// [core.py:652] SoCo.cross_fade docstring:
// Set the speaker's cross fade state.
//
// [core.py:659] SoCo.ramp_to_volume docstring:
// Smoothly change the volume.
// 
//         There are three ramp types available:
// 
//             * ``'SLEEP_TIMER_RAMP_TYPE'`` (default): Linear ramp from the
//               current volume up or down to the new volume. The ramp rate is
//               1.25 steps per second. For example: To change from volume 50 to
//               volume 30 would take 16 seconds.
//             * ``'ALARM_RAMP_TYPE'``: Resets the volume to zero, waits for about
//               30 seconds, and then ramps the volume up to the desired value at
//               a rate of 2.5 steps per second. For example: Volume 30 would take
//               12 seconds for the ramp up (not considering the wait time).
//             * ``'AUTOPLAY_RAMP_TYPE'``: Resets the volume to zero and then
//               quickly ramps up at a rate of 50 steps per second. For example:
//               Volume 30 will take only 0.6 seconds.
// 
//         The ramp rate is selected by Sonos based on the chosen ramp type and
//         the resulting transition time returned.
//         This method is non blocking and has no network overhead once sent.
// 
//         Args:
//             volume (int): The new volume.
//             ramp_type (str, optional): The desired ramp type, as described
//                 above.
// 
//         Returns:
//             int: The ramp time in seconds, rounded down. Note that this does
//             not include the wait time.
//         
//
// [core.py:701] SoCo.set_relative_volume docstring:
// Adjust the volume up or down by a relative amount.
// 
//         If the adjustment causes the volume to overshoot the maximum value
//         of 100, the volume will be set to 100. If the adjustment causes the
//         volume to undershoot the minimum value of 0, the volume will be set
//         to 0.
// 
//         Note that this method is an alternative to using addition and
//         subtraction assignment operators (+=, -=) on the `volume` property
//         of a `SoCo` instance. These operators perform the same function as
//         `set_relative_volume` but require two network calls per operation
//         instead of one.
// 
//         Args:
//             relative_volume (int): The relative volume adjustment. Can be
//                 positive or negative.
// 
//         Returns:
//             int: The new volume setting.
// 
//         Raises:
//             ValueError: If ``relative_volume`` cannot be cast as an integer.
//         
//
// [core.py:733] SoCo.play_from_queue docstring:
// Play a track from the queue by index.
// 
//         The index number is required as an argument, where the first index
//         is 0.
// 
//         Args:
//             index (int): 0-based index of the track to play
//             start (bool): If the item that has been set should start playing
//         
//
// [core.py:764] SoCo.play docstring:
// Play the currently selected track.
// 
//         Args:
//             kwargs: additional arguments such as timeout.
//
// [core.py:772] SoCo.play_uri docstring:
// Play a URI.
// 
//         Playing a URI will replace what was playing with the stream
//         given by the URI. For some streams at least a title is
//         required as metadata.  This can be provided using the ``meta``
//         argument or the ``title`` argument.  If the ``title`` argument
//         is provided minimal metadata will be generated.  If ``meta``
//         argument is provided the ``title`` argument is ignored.
// 
//         Args:
//             uri (str): URI of the stream to be played.
//             meta (str): The metadata to show in the player, DIDL format.
//             title (str): The title to show in the player (if no meta).
//             start (bool): If the URI that has been set should start playing.
//             force_radio (bool): forces a uri to play as a radio stream.
//             kwargs: additional arguments such as timeout.
// 
//         On a Sonos controller music is shown with one of the following display
//         formats and controls:
// 
//         * Radio format: Shows the name of the radio station and other available
//           data. No seek, next, previous, or voting capability.
//           Examples: TuneIn, radioPup
//         * Smart Radio:  Shows track name, artist, and album. Limited seek, next
//           and sometimes voting capability depending on the Music Service.
//           Examples: Amazon Prime Stations, Pandora Radio Stations.
//         * Track format: Shows track name, artist, and album the same as when
//           playing from a queue. Full seek, next and previous capabilities.
//           Examples: Spotify, Napster, Rhapsody.
// 
//         How it is displayed is determined by the URI prefix:
//         ``x-sonosapi-stream:``, ``x-sonosapi-radio:``,
//         ``x-rincon-mp3radio:``, ``hls-radio:`` default to radio or
//         smart radio format depending on the stream. Others default to
//         track format: ``x-file-cifs:``, ``aac:``, ``http:``,
//         ``https:``, ``x-sonos-spotify:`` (used by Spotify),
//         ``x-sonosapi-hls-static:`` (Amazon Prime), ``x-sonos-http:``
//         (Google Play & Napster).
// 
//         Some URIs that default to track format could be radio streams,
//         typically ``http:``, ``https:`` or ``aac:``.  To force display
//         and controls to Radio format set ``force_radio=True``
// 
//         .. note:: Other URI prefixes exist but are less common.
//            If you have information on these please add to this doc string.
// 
//         .. note:: A change in Sonos® (as of at least version 6.4.2)
//            means that the devices no longer accepts ordinary ``http:``
//            and ``https:`` URIs for radio stations. This method has the
//            option to replaces these prefixes with the one that Sonos®
//            expects: ``x-rincon-mp3radio:`` by using the
//            "force_radio=True" parameter.  A few streams may fail if
//            not forced to to Radio format.
// 
//         
//
// [core.py:861] SoCo.pause docstring:
// Pause the currently playing track.
//
// [core.py:866] SoCo.stop docstring:
// Stop the currently playing track.
//
// [core.py:871] SoCo.end_direct_control_session docstring:
// Ends all third-party controlled streaming sessions.
//
// [core.py:876] SoCo.seek docstring:
// Seek to a given position.
// 
//         You can seek both a relative position in the current track and a track
//         number in the queue.
//         It is even possible to seek to a tuple or dict containing the absolute
//         position (relative pos. and track nr.)::
// 
//             t = ('0:00:00', 0)
//             player.seek(*t)
//             d = {'position': '0:00:00', 'track': 0}
//             player.seek(**d)
// 
//         Args:
//             position (str): The desired timestamp in the current track,
//                 specified in the format of HH:MM:SS or H:MM:SS
//             track (int): The (zero-based) track index in the queue
// 
//         Raises:
//             ValueError: If neither position nor track are specified.
//             SoCoUPnPException: UPnP Error 701 if seeking is not supported,
//                 UPnP Error 711 if the target is invalid.
// 
//         Note:
//             The 'track' parameter can only be used if the queue is currently
//             playing. If not, use :py:meth:`play_from_queue`.
// 
//         This is currently faster than :py:meth:`play_from_queue` if already
//         using the queue, as it does not reinstate the queue.
// 
//         If speaker is already playing it will continue to play after
//         seek. If paused it will remain paused.
//         
//
// [core.py:927] SoCo.next docstring:
// Go to the next track.
// 
//         Keep in mind that next() can return errors
//         for a variety of reasons. For example, if the Sonos is streaming
//         Pandora and you call next() several times in quick succession an error
//         code will likely be returned (since Pandora has limits on how many
//         songs can be skipped).
//         
//
// [core.py:939] SoCo.previous docstring:
// Go back to the previously played track.
// 
//         Keep in mind that previous() can return errors
//         for a variety of reasons. For example, previous() will return an error
//         code (error code 701) if the Sonos is streaming Pandora since you can't
//         go back on tracks.
//         
//
// [core.py:950] SoCo.mute docstring:
// bool: The speaker's mute state.
// 
//         True if muted, False otherwise.
//         
//
// [core.py:963] SoCo.mute docstring:
// Mute (or unmute) the speaker.
//
// [core.py:971] SoCo.volume docstring:
// int: The speaker's volume.
// 
//         An integer between 0 and 100.
//         
//
// [core.py:987] SoCo.volume docstring:
// Set the speaker's volume.
//
// [core.py:996] SoCo.bass docstring:
// int: The speaker's bass EQ.
// 
//         An integer between -10 and 10.
//         
//
// [core.py:1012] SoCo.bass docstring:
// Set the speaker's bass.
//
// [core.py:1019] SoCo.treble docstring:
// int: The speaker's treble EQ.
// 
//         An integer between -10 and 10.
//         
//
// [core.py:1035] SoCo.treble docstring:
// Set the speaker's treble.
//
// [core.py:1042] SoCo.loudness docstring:
// bool: The speaker's loudness compensation.
// 
//         True if on, False otherwise.
// 
//         Loudness is a complicated topic. You can read about it on
//         Wikipedia: https://en.wikipedia.org/wiki/Loudness
// 
//         
//
// [core.py:1061] SoCo.loudness docstring:
// Switch on/off the speaker's loudness compensation.
//
// [core.py:1073] SoCo.surround_enabled docstring:
// bool: Reports if the home theater surround speakers are enabled.
// 
//         Should only be called on the primary device in a home theater setup.
// 
//         True if on, False if off, None if not supported.
//         
//
// [core.py:1090] SoCo.surround_enabled docstring:
// Enable/disable the connected surround speakers.
// 
//         :param enable: Enable or disable surround speakers
//         :type enable: bool
//         
//
// [core.py:1105] SoCo.sub_crossover docstring:
// int: Reports the current subwoofer crossover frequency in Hz.
// 
//         Only supported on Amp devices.
//         
//
// [core.py:1120] SoCo.sub_crossover docstring:
// Set the subwoofer crossover frequency. Only supported on Amp devices.
// 
//         :param frequency: Desired subwoofer crossover frequency in Hz
//         :type frequency: int
//         
//
// [core.py:1145] SoCo.sub_enabled docstring:
// bool: Reports if the subwoofer is enabled.
// 
//         True if on, False if off, None if not supported.
//         
//
// [core.py:1159] SoCo.sub_enabled docstring:
// Enable/disable the connected subwoofer.
// 
//         :param enable: Enable or disable the subwoofer
//         :type enable: bool
//         
//
// [core.py:1178] SoCo.sub_gain docstring:
// int: The current subwoofer gain level.
// 
//         Returns the current value or None if not supported.
//         
//
// [core.py:1192] SoCo.sub_gain docstring:
// Set the subwoofer gain level.
// 
//         :param level: Desired subwoofer gain level (-15 to 15)
//         :type level: int
//         
//
// [core.py:1215] SoCo.balance docstring:
// The left/right balance for the speaker(s).
// 
//         Returns:
//             tuple: A 2-tuple (left_channel, right_channel) of integers
//             between 0 and 100, representing the volume of each channel.
//             E.g., (100, 100) represents full volume to both channels,
//             whereas (100, 0) represents left channel at full volume,
//             right channel at zero volume.
//         
//
// [core.py:1243] SoCo.balance docstring:
// Set the left/right balance for the speaker(s).
//
// [core.py:1258] SoCo.audio_delay docstring:
// int: The TV Dialog Sync audio delay.
// 
//         Returns the current value or None if not supported.
//         
//
// [core.py:1272] SoCo.audio_delay docstring:
// Control the delay added to incoming audio sources. Also called
//         TV Dialog Sync in Home Theater settings.
// 
//         :param delay: Delay to apply to audio in the range of 0 to 5
//         :type delay: int
//         :raises NotSupportedException: If device does not support audio delay.
//         :raises ValueError: If provided delay is not an acceptable value.
//         
//
// [core.py:1297] SoCo.night_mode docstring:
// bool: The speaker's night mode.
// 
//         True if on, False if off, None if not supported.
//         
//
// [core.py:1312] SoCo.night_mode docstring:
// Switch on/off the speaker's night mode.
// 
//         :param night_mode: Enable or disable night mode
//         :type night_mode: bool
//         :raises NotSupportedException: If the device does not support
//         night mode.
//         
//
// [core.py:1329] SoCo.dialog_mode docstring:
// bool: The speaker's dialog mode.
// 
//         True if on, False if off, None if not supported.
//         
//
// [core.py:1344] SoCo.dialog_mode docstring:
// Switch on/off the speaker's dialog mode.
// 
//         :param dialog_mode: Enable or disable dialog mode
//         :type dialog_mode: bool
//         :raises NotSupportedException: If the device does not support
//         dialog mode.
//         
//
// [core.py:1361] SoCo.surround_full_volume_enabled docstring:
// Return True if surround full volume is enabled for surround music
//         playback.
// 
//         If False, playback on surround speakers uses ambient volume.
// 
//         Note: does not apply to TV playback.
//         
//
// [core.py:1379] SoCo.surround_full_volume_enabled docstring:
// Toggle surround music playback mode.
// 
//         True = full volume, False = ambient mode.
// 
//         Note: this does not apply to TV playback.
//         
//
// [core.py:1395] SoCo.surround_mode docstring:
// Convenience surround_full_volume_enabled getter to match raw Sonos API.
//
// [core.py:1400] SoCo.surround_mode docstring:
// Convenience surround_full_volume_enabled setter to match raw Sonos API.
//
// [core.py:1405] SoCo.surround_volume_tv docstring:
// Get the relative volume for surround speakers in TV
//         playback mode. Ranges from -15 to +15.
//
// [core.py:1418] SoCo.surround_volume_tv docstring:
// Set the relative volume for surround speakers in TV playback mode,
//         in the range -15 to +15.
//         
//
// [core.py:1434] SoCo.surround_level docstring:
// Convenience getter for surround_volume_tv to match raw Sonos API.
//
// [core.py:1439] SoCo.surround_level docstring:
// Convenience setter for surround_volume_tv to match raw Sonos API.
//
// [core.py:1444] SoCo.surround_volume_music docstring:
// Return the relative volume for surround speakers in music mode,
//         in the range -15 to +15.
//         
//
// [core.py:1458] SoCo.surround_volume_music docstring:
// Set the relative volume for surround speakers in music mode,
//         in the range -15 to +15.
//
// [core.py:1473] SoCo.music_surround_level docstring:
// Convenience getter for surround_volume_music to match raw Sonos API.
//
// [core.py:1478] SoCo.music_surround_level docstring:
// Convenience setter for surround_volume_music to match raw Sonos API.
//
// [core.py:1483] SoCo.dialog_level docstring:
// Convenience wrapper for dialog_mode getter to match raw Sonos API.
//
// [core.py:1488] SoCo.dialog_level docstring:
// Convenience wrapper for dialog_mode setter to match raw Sonos API.
//
// [core.py:1493] SoCo.speech_enhance_enabled docstring:
// bool: The speaker's speech enhancement mode.
// 
//         True if on, False if off, None if not supported.
//         
//
// [core.py:1507] SoCo.speech_enhance_enabled docstring:
// Switch on/off the arc ultra soundbar speech enhancement.
// 
//         :param speech_mode: Enable or disable dialog mode
//         :type speech_mode: bool
//         :raises NotSupportedException: If the device does not support
//         speech enhancement.
//         
//
// [core.py:1528] SoCo.trueplay docstring:
// bool: Whether Trueplay is enabled on this device.
//         True if on, False if off.
// 
//         Devices that do not support Trueplay, or which do not have
//         a current Trueplay calibration, will return `None` on getting
//         the property, and  raise a `NotSupportedException` when
//         setting the property.
// 
//         Can only be set on visible devices. Attempting to set on non-visible
//         devices will raise a `SoCoNotVisibleException`.
//         
//
// [core.py:1547] SoCo.trueplay docstring:
// Toggle the device's TruePlay setting. Only available to
//         Sonos speakers, not the Connect, Amp, etc., and only available to
//         speakers that have a current Trueplay calibration.
// 
//         :param trueplay: Enable or disable Trueplay.
//         :type trueplay: bool
//         :raises NotSupportedException: If the device does not support
//         Trueplay or doesn't have a current calibration.
//         :raises SoCoNotVisibleException: If the device is not visible.
//         
//
// [core.py:1574] SoCo.soundbar_audio_input_format_code docstring:
// Return audio input format code as reported by the device.
// 
//         Returns None when the device is not a soundbar.
// 
//         While the variable is available on non-soundbar devices,
//         it is likely always 0 for devices without audio inputs.
// 
//         See also :func:`soundbar_audio_input_format` for obtaining a
//         human-readable description of the format.
//         
//
// [core.py:1593] SoCo.soundbar_audio_input_format docstring:
// Return a string presentation of the audio input format.
// 
//         Returns None when the device is not a soundbar.
//         Otherwise, this will return the string presentation of the currently
//         active sound format (e.g., "Dolby 5.1" or "No input")
// 
//         See also :func:`soundbar_audio_input_format_code` for the raw value.
//         
//
// [core.py:1615] SoCo.supports_fixed_volume docstring:
// bool: Whether the device supports fixed volume output.
//
// [core.py:1622] SoCo.fixed_volume docstring:
// bool: The device's fixed volume output setting.
// 
//         True if on, False if off. Only applicable to certain
//         Sonos devices (Connect and Port at the time of writing).
//         All other devices always return False.
// 
//         Attempting to set this property for a non-applicable
//         device will raise a `NotSupportedException`.
//         
//
// [core.py:1637] SoCo.fixed_volume docstring:
// Switch on/off the device's fixed volume output setting.
// 
//         Only applicable to certain Sonos devices.
// 
//         :param fixed_volume: Enable or disable fixed volume output mode.
//         :type fixed_volume: bool
//         :raises NotSupportedException: If the device does not support
//         fixed volume output mode.
//         
//
// [core.py:1659] SoCo.zone_group_state docstring:
// Return the assocated ZoneGroupState instance.
//
// [core.py:1667] SoCo.all_groups docstring:
// set of :class:`soco.groups.ZoneGroup`: All available groups.
//
// [core.py:1673] SoCo.group docstring:
// :class:`soco.groups.ZoneGroup`: The Zone Group of which this device
//         is a member.
// 
//         None if this zone is a slave in a stereo pair.
//         
//
// [core.py:1697] SoCo.all_zones docstring:
// set of :class:`soco.groups.ZoneGroup`: All available zones.
//
// [core.py:1703] SoCo.visible_zones docstring:
// set of :class:`soco.groups.ZoneGroup`: All visible zones.
//
// [core.py:1708] SoCo.partymode docstring:
// Put all the speakers in the network in the same group, a.k.a Party
//         Mode.
// 
//         This blog shows the initial research responsible for this:
//         http://blog.travelmarx.com/2010/06/exploring-sonos-via-upnp.html
// 
//         The trick seems to be (only tested on a two-speaker setup) to tell each
//         speaker which to join. There's probably a bit more to it if multiple
//         groups have been defined.
//         Args:
//             kwargs: additional arguments such as timeout.
//         
//
// [core.py:1725] SoCo.join docstring:
// Join this speaker to another "master" speaker.
//
// [core.py:1738] SoCo.unjoin docstring:
// Remove this speaker from a group.
// 
//         Seems to work ok even if you remove what was previously the group
//         master from it's own group. If the speaker was not in a group also
//         returns ok.
//         Args:
//             kwargs: additional arguments such as timeout.
//         
//
// [core.py:1753] SoCo.create_stereo_pair docstring:
// Create a stereo pair.
// 
//         This speaker becomes the master, left-hand speaker of the stereo
//         pair. The ``rh_slave_speaker`` becomes the right-hand speaker.
//         Note that this operation will succeed on dissimilar speakers, unlike
//         when using the official Sonos apps.
// 
//         Args:
//             rh_slave_speaker (SoCo): The speaker that will be added as
//                 the right-hand, slave speaker of the stereo pair.
// 
//         Raises:
//             SoCoUPnPException: if either speaker is already part of a
//                 stereo pair.
//         
//
// [core.py:1776] SoCo.separate_stereo_pair docstring:
// Separate a stereo pair.
// 
//         This can be called on either the master (left-hand) speaker, or on the
//         slave (right-hand) speaker, to create two independent zones.
// 
//         Raises:
//             SoCoUPnPException: if the speaker is not a member of a stereo pair.
//         
//
// [core.py:1790] SoCo._set_satellite_mapping docstring:
// Set the satellite channel mapping for this soundbar.
// 
//         This is used internally by :meth:`add_satellite_speakers`. The
//         channel-map string format is:
//         ``RINCON_<soundbar>:LF,RF;RINCON_<right>:RR;RINCON_<left>:LR``
// 
//         Channel abbreviations:
//         - LF = left front
//         - RF = right front
//         - LR = left rear
//         - RR = right rear
// 
//         Args:
//             channel_map (str): The channel mapping string.
//         
//
// [core.py:1809] SoCo.add_satellite_speakers docstring:
// Add rear satellite speakers to this soundbar.
// 
//         Args:
//             left_rear (SoCo): The speaker to use as the left rear satellite.
//             right_rear (SoCo): The speaker to use as the right rear satellite.
// 
//         Raises:
//             NotSupportedException: If this device is not a soundbar.
//         
//
// [core.py:1825] SoCo.separate_satellite_speakers docstring:
// Remove all satellite speakers from this soundbar.
// 
//         Warning:
//             This will reset the Trueplay tuning for the device.
// 
//         Raises:
//             NotSupportedException: If this device is not a soundbar.
//         
//
// [core.py:1839] SoCo.switch_to_line_in docstring:
// Switch the speaker's input to line-in.
// 
//         Args:
//             source (SoCo): The speaker whose line-in should be played.
//                 Default is line-in from the speaker itself.
//         
//
// [core.py:1860] SoCo.is_playing_radio docstring:
// bool: Is the speaker playing radio?
//
// [core.py:1865] SoCo.is_playing_line_in docstring:
// bool: Is the speaker playing line-in?
//
// [core.py:1870] SoCo.is_playing_tv docstring:
// bool: Is the playbar speaker input from TV?
//
// [core.py:1875] SoCo.music_source_from_uri docstring:
// Determine a music source from a URI.
// 
//         Arguments:
//             uri (str) : The URI representing the music source
// 
//         Returns:
//             str: The current source of music.
// 
//         Possible return values are:
// 
//         *   ``'NONE'`` -- speaker has no music to play.
//         *   ``'LIBRARY'`` -- speaker is playing queued titles from the music
//             library.
//         *   ``'RADIO'`` -- speaker is playing radio.
//         *   ``'WEB_FILE'`` -- speaker is playing a music file via http/https.
//         *   ``'LINE_IN'`` -- speaker is playing music from line-in.
//         *   ``'TV'`` -- speaker is playing input from TV.
//         *   ``'AIRPLAY'`` -- speaker is playing from AirPlay.
//         *   ``'UNKNOWN'`` -- any other input.
// 
//         The strings above can be imported as ``MUSIC_SRC_LIBRARY``,
//         ``MUSIC_SRC_RADIO``, etc.
//         
//
// [core.py:1905] SoCo.music_source docstring:
// str: The current music source (radio, TV, line-in, etc.).
// 
//         Possible return values are the same as used in `music_source_from_uri()`.
//         
//
// [core.py:1915] SoCo.switch_to_tv docstring:
// Switch the playbar speaker's input to TV.
//
// [core.py:1927] SoCo.status_light docstring:
// bool: The white Sonos status light between the mute button and the
//         volume up button on the speaker.
// 
//         True if on, otherwise False.
//         
//
// [core.py:1938] SoCo.status_light docstring:
// Switch on/off the speaker's status light.
//
// [core.py:1948] SoCo.buttons_enabled docstring:
// bool: Whether the control buttons on the device are enabled.
// 
//         `True` if the control buttons are enabled, `False` if disabled.
// 
//         This property can only be set on visible speakers, and will enable
//         or disable the buttons for all speakers in any bonded set (e.g., a
//         stereo pair). Attempting to set it on invisible speakers
//         (e.g., the RH speaker of a stereo pair) will raise a
//         `SoCoNotVisibleException`.
//         
//
// [core.py:1965] SoCo.buttons_enabled docstring:
// Enable or disable the device's control buttons.
// 
//         Args:
//             bool: True to enable the buttons, False to disable.
// 
//         Raises:
//             SoCoNotVisibleException: If the speaker is not visible.
//         
//
// [core.py:1984] SoCo.voice_service_configured docstring:
// bool: Is a voice service configured on this device?
//
// [core.py:1992] SoCo.mic_enabled docstring:
// bool: Is the device's microphone enabled?
// 
//         .. note:: Returns None if the device does not have a microphone
//             or if a voice service is not configured.
// 
//         
//
// [core.py:2004] SoCo.get_current_track_info docstring:
// Get information about the currently playing track.
// 
//         Returns:
//             dict: A dictionary containing information about the currently
//             playing track: playlist_position, duration, title, artist, album,
//             position and an album_art link.
// 
//         If we're unable to return data for a field, we'll return an empty
//         string. This can happen for all kinds of reasons so be sure to check
//         values. For example, a track may not have complete metadata and be
//         missing an album name. In this case track['album'] will be an empty
//         string.
// 
//         .. note:: Calling this method on a slave in a group will not
//             return the track the group is playing, but the last track
//             this speaker was playing.
// 
//         
//
// [core.py:2044] SoCo.get_current_track_info._title_in_uri docstring:
// Returns True if the title contains URI components
//             and the track title is repeated inside the track URI.
// 
//             Used to avoid using invalid values in title metadata.
//             
//
// [core.py:2058] SoCo.get_current_track_info._parse_radio_metadata docstring:
// Try to parse trackinfo from radio metadata.
//
// [core.py:2136] SoCo.get_current_media_info docstring:
// Get information about the currently playing media.
// 
//         Returns:
//             dict: A dictionary containing information about the currently
//             playing media: uri, channel.
// 
//         If we're unable to return data for a field, we'll return an empty
//         string.
//         
//
// [core.py:2161] SoCo.get_speaker_info docstring:
// Get information about the Sonos speaker.
// 
//         Arguments:
//             refresh(bool): Refresh the speaker info cache.
//             timeout: How long to wait for the server to send
//                 data before giving up, as a float, or a
//                 ``(connect timeout, read timeout)`` tuple
//                 e.g. (3, 5). Default is no timeout.
// 
//         Returns:
//             dict: Information about the Sonos speaker, such as the UID,
//             MAC Address, and Zone Name.
//         
//
// [core.py:2224] SoCo.get_current_transport_info docstring:
// Get the current playback state.
// 
//         Returns:
//             dict: The following information about the
//             speaker's playing state:
// 
//             *   current_transport_state (``PLAYING``, ``TRANSITIONING``,
//                 ``PAUSED_PLAYBACK``, ``STOPPED``)
//             *   current_transport_status (OK, ?)
//             *   current_speed(1, ?)
// 
//         This allows us to know if speaker is playing or not. Don't know other
//         states of CurrentTransportStatus and CurrentSpeed.
//         
//
// [core.py:2259] SoCo.available_actions docstring:
// The transport actions that are currently available on the
//         speaker.
// 
//         :returns: list: A list of strings representing the available actions, such as
//                     ['Set', 'Stop', 'Play'].
// 
//         Possible list items are: 'Set', 'Stop', 'Pause', 'Play',
//         'Next', 'Previous', 'SeekTime', 'SeekTrackNr'.
//         
//
// [core.py:2275] SoCo.get_queue docstring:
// Get information about the queue.
// 
//         :param start: Starting number of returned matches
//         :param max_items: Maximum number of returned matches
//         :param full_album_art_uri: If the album art URI should include the
//             IP address
//         :returns: A :py:class:`~.soco.data_structures.Queue` object
// 
//         This method is heavily based on Sam Soffes (aka soffes) ruby
//         implementation
//         
//
// [core.py:2321] SoCo.queue_size docstring:
// int: Size of the queue.
//
// [core.py:2344] SoCo.get_sonos_playlists docstring:
// Convenience method for calling
//         ``soco.music_library.get_music_library_information('sonos_playlists')``
// 
//         Refer to the docstring for that method: `get_music_library_information`
// 
//         
//
// [core.py:2355] SoCo.add_uri_to_queue docstring:
// Add the URI to the queue.
// 
//         For arguments and return value see `add_to_queue`.
//         
//
// [core.py:2367] SoCo.add_to_queue docstring:
// Add a queueable item to the queue.
// 
//         Args:
//             queueable_item (DidlObject or MusicServiceItem): The item to be
//                 added to the queue
//             position (int): The index (1-based) at which the URI should be
//                 added. Default is 0 (add URI at the end of the queue).
//             as_next (bool): Whether this URI should be played as the next
//                 track in shuffle mode. This only works if ``play_mode=SHUFFLE``.
// 
//         Returns:
//             int: The index of the new item in the queue.
//         
//
// [core.py:2395] SoCo.add_multiple_to_queue docstring:
// Add a sequence of items to the queue.
// 
//         Args:
//             items (list): A sequence of items to the be added to the queue
//             container (DidlObject, optional): A container object which
//                 includes the items.
//         
//
// [core.py:2432] SoCo.remove_from_queue docstring:
// Remove a track from the queue by index. The index number is
//         required as an argument, where the first index is 0.
// 
//         Args:
//             index (int): The (0-based) index of the track to remove
//         
//
// [core.py:2451] SoCo.clear_queue docstring:
// Remove all tracks from the queue.
//
// [core.py:2460] SoCo.get_favorite_radio_shows docstring:
// Get favorite radio shows from Sonos' Radio app.
// 
//         Returns:
//             dict: A dictionary containing the total number of favorites, the
//             number of favorites returned, and the actual list of favorite radio
//             shows, represented as a dictionary with ``'title'`` and ``'uri'``
//             keys.
// 
//         Depending on what you're building, you'll want to check to see if the
//         total number of favorites is greater than the amount you
//         requested (``max_items``), if it is, use ``start`` to page through and
//         get the entire list of favorites.
//         
//
// [core.py:2482] SoCo.get_favorite_radio_stations docstring:
// Get favorite radio stations from Sonos' Radio app.
// 
//         See :meth:`get_favorite_radio_shows` for return type and remarks.
//         
//
// [core.py:2495] SoCo.get_sonos_favorites docstring:
// Get Sonos favorites.
// 
//         See :meth:`get_favorite_radio_shows` for return type and remarks.
//         
//
// [core.py:2507] SoCo.__get_favorites docstring:
// Helper method for `get_favorite_radio_*` methods.
// 
//         Args:
//             favorite_type (str): Specify either `RADIO_STATIONS` or
//                 `RADIO_SHOWS`.
//             start (int): Which number to start the retrieval from. Used for
//                 paging.
//             max_items (int): The total number of results to return.
// 
//         
//
// [core.py:2570] SoCo.create_sonos_playlist docstring:
// Create a new empty Sonos playlist.
// 
//         Args:
//             title: Name of the playlist
// 
//         :rtype: :py:class:`~.soco.data_structures.DidlPlaylistContainer`
//         
//
// [core.py:2598] SoCo.create_sonos_playlist_from_queue docstring:
// Create a new Sonos playlist from the current queue.
// 
//         Args:
//             title: Name of the playlist
// 
//         :rtype: :py:class:`~.soco.data_structures.DidlPlaylistContainer`
//         
//
// [core.py:2621] SoCo.remove_sonos_playlist docstring:
// Remove a Sonos playlist.
// 
//         Args:
//             sonos_playlist (DidlPlaylistContainer): Sonos playlist to remove
//                 or the item_id (str).
// 
//         Returns:
//             bool: True if succesful, False otherwise
// 
//         Raises:
//             SoCoUPnPException: If sonos_playlist does not point to a valid
//                 object.
// 
//         
//
// [core.py:2639] SoCo.add_item_to_sonos_playlist docstring:
// Adds a queueable item to a Sonos' playlist.
// 
//         Args:
//             queueable_item (DidlObject): the item to add to the Sonos' playlist
//             sonos_playlist (DidlPlaylistContainer): the Sonos' playlist to
//                 which the item should be added
//         
//
// [core.py:2671] SoCo.set_sleep_timer docstring:
// Sets the sleep timer.
// 
//         Args:
//             sleep_time_seconds (int or NoneType): How long to wait before
//                 turning off speaker in seconds, None to cancel a sleep timer.
//                 Maximum value of 86399
// 
//         Raises:
//             SoCoException: Upon errors interacting with Sonos controller
//             ValueError: Argument/Syntax errors
// 
//         
//
// [core.py:2709] SoCo.get_sleep_timer docstring:
// Retrieves remaining sleep time, if any
// 
//         Returns:
//             int or NoneType: Number of seconds left in timer. If there is no
//                 sleep timer currently set it will return None.
//         
//
// [core.py:2728] SoCo.reorder_sonos_playlist docstring:
// Reorder and/or Remove tracks in a Sonos playlist.
// 
//         The underlying call is quite complex as it can both move a track
//         within the list or delete a track from the playlist.  All of this
//         depends on what tracks and new_pos specify.
// 
//         If a list is specified for tracks, then a list must be used for
//         new_pos. Each list element is a discrete modification and the next
//         list operation must anticipate the new state of the playlist.
// 
//         If a comma formatted string to tracks is specified, then use
//         a similiar string to specify new_pos. Those operations should be
//         ordered from the end of the list to the beginning
// 
//         See the helper methods
//         :py:meth:`clear_sonos_playlist`, :py:meth:`move_in_sonos_playlist`,
//         :py:meth:`remove_from_sonos_playlist` for simplified usage.
// 
//         update_id - If you have a series of operations, tracking the update_id
//         and setting it, will save a lookup operation.
// 
//         Examples:
//           To reorder the first two tracks::
// 
//             # sonos_playlist specified by the DidlPlaylistContainer object
//             sonos_playlist = device.get_sonos_playlists()[0]
//             device.reorder_sonos_playlist(sonos_playlist,
//                                           tracks=[0, ], new_pos=[1, ])
//             # OR specified by the item_id
//             device.reorder_sonos_playlist('SQ:0', tracks=[0, ], new_pos=[1, ])
// 
//           To delete the second track::
// 
//             # tracks/new_pos are a list of int
//             device.reorder_sonos_playlist(sonos_playlist,
//                                           tracks=[1, ], new_pos=[None, ])
//             # OR tracks/new_pos are a list of int-like
//             device.reorder_sonos_playlist(sonos_playlist,
//                                           tracks=['1', ], new_pos=['', ])
//             # OR tracks/new_pos are strings - no transform is done
//             device.reorder_sonos_playlist(sonos_playlist, tracks='1',
//                                           new_pos='')
// 
//           To reverse the order of a playlist with 4 items::
// 
//             device.reorder_sonos_playlist(sonos_playlist, tracks='3,2,1,0',
//                                           new_pos='0,1,2,3')
// 
//         Args:
//             sonos_playlist
//                 (:py:class:`~.soco.data_structures.DidlPlaylistContainer`): The
//                 Sonos playlist object or the item_id (str) of the Sonos
//                 playlist.
//             tracks: (list): list of track indices(int) to reorder. May also be
//                 a list of int like things. i.e. ``['0', '1',]`` OR it may be a
//                 str of comma separated int like things. ``"0,1"``.  Tracks are
//                 **0**-based. Meaning the first track is track 0, just like
//                 indexing into a Python list.
//             new_pos (list): list of new positions (int|None)
//                 corresponding to track_list. MUST be the same type as
//                 ``tracks``. **0**-based, see tracks above. ``None`` is the
//                 indicator to remove the track. If using a list of strings,
//                 then a remove is indicated by an empty string.
//             update_id (int): operation id (default: 0) If set to 0, a lookup
//                 is done to find the correct value.
// 
//         Returns:
//             dict: Which contains 3 elements: change, length and update_id.
//             Change in size between original playlist and the resulting
//             playlist, the length of resulting playlist, and the new
//             update_id.
// 
//         Raises:
//             SoCoUPnPException: If playlist does not exist or if your tracks
//                 and/or new_pos arguments are invalid.
//         
//
// [core.py:2853] SoCo.clear_sonos_playlist docstring:
// Clear all tracks from a Sonos playlist.
//         This is a convenience method for :py:meth:`reorder_sonos_playlist`.
// 
//         Example::
// 
//             device.clear_sonos_playlist(sonos_playlist)
// 
//         Args:
//             sonos_playlist
//                 (:py:class:`~.soco.data_structures.DidlPlaylistContainer`):
//                 Sonos playlist object or the item_id (str) of the Sonos
//                 playlist.
//             update_id (int): Optional update counter for the object. If left
//                 at the default of 0, it will be looked up.
// 
//         Returns:
//             dict: See :py:meth:`reorder_sonos_playlist`
// 
//         Raises:
//             ValueError: If sonos_playlist specified by string and is not found.
//             SoCoUPnPException: See :py:meth:`reorder_sonos_playlist`
//         
//
// [core.py:2888] SoCo.move_in_sonos_playlist docstring:
// Move a track to a new position within a Sonos Playlist.
//         This is a convenience method for :py:meth:`reorder_sonos_playlist`.
// 
//         Example::
// 
//             device.move_in_sonos_playlist(sonos_playlist, track=0, new_pos=1)
// 
//         Args:
//             sonos_playlist
//                 (:py:class:`~.soco.data_structures.DidlPlaylistContainer`):
//                 Sonos playlist object or the item_id (str) of the Sonos
//                 playlist.
//             track (int): **0**-based position of the track to move. The first
//                 track is track 0, just like indexing into a Python list.
//             new_pos (int): **0**-based location to move the track.
//             update_id (int): Optional update counter for the object. If left
//                 at the default of 0, it will be looked up.
// 
//         Returns:
//             dict: See :py:meth:`reorder_sonos_playlist`
// 
//         Raises:
//             SoCoUPnPException: See :py:meth:`reorder_sonos_playlist`
//         
//
// [core.py:2918] SoCo.remove_from_sonos_playlist docstring:
// Remove a track from a Sonos Playlist.
//         This is a convenience method for :py:meth:`reorder_sonos_playlist`.
// 
//         Example::
// 
//             device.remove_from_sonos_playlist(sonos_playlist, track=0)
// 
//         Args:
//             sonos_playlist
//                 (:py:class:`~.soco.data_structures.DidlPlaylistContainer`):
//                 Sonos playlist object or the item_id (str) of the Sonos
//                 playlist.
//             track (int): *0**-based position of the track to move. The first
//                 track is track 0, just like indexing into a Python list.
//             update_id (int): Optional update counter for the object. If left
//                 at the default of 0, it will be looked up.
// 
//         Returns:
//             dict: See :py:meth:`reorder_sonos_playlist`
// 
//         Raises:
//             SoCoUPnPException: See :py:meth:`reorder_sonos_playlist`
//         
//
// [core.py:2945] SoCo.get_sonos_playlist_by_attr docstring:
// Return the first Sonos Playlist DidlPlaylistContainer that
//         matches the attribute specified.
// 
//         Args:
//             attr_name (str): DidlPlaylistContainer attribute to compare. The
//                 most useful being: 'title' and 'item_id'.
//             match (str): Value to match.
// 
//         Returns:
//             (:class:`~.soco.data_structures.DidlPlaylistContainer`): The
//                 first matching playlist object.
// 
//         Raises:
//             (AttributeError): If indicated attribute name does not exist.
//             (ValueError): If a match can not be found.
// 
//         Example::
// 
//             device.get_sonos_playlist_by_attr('title', 'Foo')
//             device.get_sonos_playlist_by_attr('item_id', 'SQ:3')
// 
//         
//
// [core.py:2973] SoCo.get_battery_info docstring:
// Get battery information for a Sonos speaker.
// 
//         Obtains battery information for Sonos speakers that report it. This only
//         applies to Sonos Move speakers at the time of writing.
// 
//         This method may only work on Sonos 'S2' systems.
// 
//         Args:
//             timeout (float, optional): The timeout to use when making the
//                 HTTP request.
// 
//         Returns:
//             dict: A `dict` containing battery status data.
// 
//             Example return value::
// 
//                 {'Health': 'GREEN',
//                  'Level': 100,
//                  'Temperature': 'NORMAL',
//                  'PowerSource': 'SONOS_CHARGING_RING'}
// 
//         Raises:
//             NotSupportedException: If the speaker does not report battery
//                 information.
//             ConnectionError: If the HTTP connection failed, or returned an
//                 unsuccessful status code.
//             TimeoutError: If making the HTTP connection, or reading the
//                 response, timed out.
//         
//
// [core.py:3035] soco_reset docstring:
// Reset the SoCo module.
// 
//     Clears out the singleton instance cache. Use this to reset SoCo state,
//     for example when testing. Note that this does not close any open
//     connections or release other resources. This function is not thread-safe
//     and must not be called while the API is in use from other threads.
//     
//
// [core.py:1] pylint: disable=fixme, protected-access
// [core.py:128] pylint: disable=no-init
// [core.py:172] pylint: disable=R0904
// [core.py:328] pylint: disable=super-on-old-class
// [core.py:330] Note: Creation of a SoCo instance should be as cheap and quick as
// [core.py:331] possible. Do not make any network calls here
// [core.py:333] Check if ip_address is a valid IPv4 representation.
// [core.py:334] Sonos does not (yet) support IPv6
// [core.py:339] : The speaker's ip address
// [core.py:341] Stores information about the current speaker
// [core.py:343] The services which we use
// [core.py:344] pylint: disable=invalid-name
// [core.py:358] Some private attributes
// [core.py:392] We could get the name like this:
// [core.py:393] result = self.deviceProperties.GetZoneAttributes()
// [core.py:394] return result["CurrentZoneName"]
// [core.py:395] but it is probably quicker to get it from the group topology
// [core.py:396] and take advantage of any caching
// [core.py:417] Since this does not change over time (?) check whether we already
// [core.py:418] know the answer. If so, there is no need to go further
// [core.py:421] if not, we have to get it from the zone topology, which
// [core.py:422] is probably quicker than any alternative, since the zgt is probably
// [core.py:423] cached. This will set self._uid for us for next time, so we won't
// [core.py:424] have to do this again
// [core.py:427] An alternative way of getting the uid is as follows:
// [core.py:428] self.device_description_url = \
// [core.py:429] 'http://{0}:1400/xml/device_description.xml'.format(
// [core.py:430] self.ip_address)
// [core.py:431] response = requests.get(self.device_description_url).text
// [core.py:432] tree = XML.fromstring(response.encode('utf-8'))
// [core.py:433] udn = tree.findtext('.//{urn:schemas-upnp-org:device-1-0}UDN')
// [core.py:434] # the udn has a "uuid:" prefix before the uid, so we need to strip it
// [core.py:435] self._uid = uid = udn[5:]
// [core.py:436] return uid
// [core.py:444] Since this does not change over time (?) check whether we already
// [core.py:445] know the answer. If so, return the cached version
// [core.py:459] We could do this:
// [core.py:460] invisible = self.deviceProperties.GetInvisible()['CurrentInvisible']
// [core.py:461] but it is better to do it in the following way, which uses the
// [core.py:462] zone group topology, to capitalise on any caching.
// [core.py:468] Since this does not change over time (?) check whether we already
// [core.py:469] know the answer. If so, there is no need to go further
// [core.py:472] if not, we have to get it from the zone topology. This will set
// [core.py:473] self._is_bridge for us for next time, so we won't have to do this
// [core.py:474] again
// [core.py:481] We could do this:
// [core.py:482] invisible = self.deviceProperties.GetInvisible()['CurrentInvisible']
// [core.py:483] but it is better to do it in the following way, which uses the
// [core.py:484] zone group topology, to capitalise on any caching.
// [core.py:532] pylint: disable=E1135
// [core.py:543] Omit repeated channel entries (e.g., "RF,RF" -> "RF")
// [core.py:635] Only for symmetry with the setter
// [core.py:726] Sonos will automatically handle out-of-range adjustments
// [core.py:743] Grab the speaker's information if we haven't already since we'll need
// [core.py:744] it in the next step.
// [core.py:748] first, set the queue itself as the source URI
// [core.py:754] second, set the track number with a seek command
// [core.py:759] finally, just play what's set if needed
// [core.py:843] Radio stations need to have at least a title to play
// [core.py:846] change uri prefix to force radio style display and commands
// [core.py:855] The track is enqueued, now play it if needed
// [core.py:990] Coerce in range
// [core.py:1015] Coerce in range
// [core.py:1038] Coerce in range
// [core.py:1248] Coerce in range
// [core.py:1249] Coerce in range
// [core.py:1685] To get the group directly from the network, try the code below
// [core.py:1686] though it is probably slower than that above
// [core.py:1687] current_group_id = self.zoneGroupTopology.GetZoneGroupAttributes()[
// [core.py:1688] 'CurrentZoneGroupID']
// [core.py:1689] if current_group_id:
// [core.py:1690] for group in self.all_groups:
// [core.py:1691] if group.uid == current_group_id:
// [core.py:1692] return group
// [core.py:1693] else:
// [core.py:1694] return None
// [core.py:1721] Tell every other visible zone to join this one
// [core.py:1722] pylint: disable = expression-not-assigned
// [core.py:1769] The pairing operation must be applied to the speaker that will
// [core.py:1770] become the master (the left-hand speaker of the pair).
// [core.py:1771] Note that if either speaker is part of a group, the call will
// [core.py:1772] succeed.
// [core.py:1934] pylint: disable=invalid-name
// [core.py:2040] Store the entire Metadata entry in the track, this can then be
// [core.py:2041] used if needed by the client to restart a given URI
// [core.py:2070] Examples from services:
// [core.py:2071] Apple Music radio:
// [core.py:2072] "TYPE=SNG|TITLE Couleurs|ARTIST M83|ALBUM Saturdays = Youth"
// [core.py:2073] SiriusXM:
// [core.py:2074] "BR P|TYPE=SNG|TITLE 7.15.17 LA|ARTIST Eagles|ALBUM "
// [core.py:2086] Might find some kind of title anyway in metadata
// [core.py:2088] Avoid using URIs as the title
// [core.py:2096] If the speaker is playing from the line-in source, querying for track
// [core.py:2097] metadata will return "NOT_IMPLEMENTED".
// [core.py:2103] Duration seems to be '0:00:00' when listening to radio
// [core.py:2107] Track may have been processed as radio, but metadata may still be incomplete.
// [core.py:2108] This is necessary on Sonos Radio as it encodes metadata as a "regular" track.
// [core.py:2110] Track metadata is returned in DIDL-Lite format
// [core.py:2121] Preserve existing values if already processed
// [core.py:2190] no zone icon in device_description.xml -> player icon
// [core.py:2217] no mac address - extract from serial number
// [core.py:2271] The actions might look like 'X_DLNA_SeekTime', but we only want the
// [core.py:2272] last part
// [core.py:2304] I'm not sure this necessary (any more). Even with an empty queue,
// [core.py:2305] there is still a result object. This shoud be investigated.
// [core.py:2307] pylint: disable=star-args
// [core.py:2312] Check if the album art URI should be fully qualified
// [core.py:2317] pylint: disable=star-args
// [core.py:2360] FIXME: The res.protocol_info should probably represent the mime type
// [core.py:2361] etc of the uri. But this seems OK.
// [core.py:2407] Sonos seems to accept this as well
// [core.py:2408] pylint: disable=redefined-variable-type
// [core.py:2410] With each request, we can only add 16 items
// [core.py:2411] List for slicing
// [core.py:2439] TODO: what do these parameters actually do?
// [core.py:2543] Favorites are returned in DIDL-Lite format
// [core.py:2597] pylint: disable=invalid-name
// [core.py:2606] Note: probably same as Queue service method SaveAsSonosPlaylist
// [core.py:2607] but this has not been tested.  This method is what the
// [core.py:2608] controller uses.
// [core.py:2647] Get the update_id for the playlist
// [core.py:2651] Form the metadata for queueable_item
// [core.py:2654] Make the request
// [core.py:2662] 2 ** 32 - 1 = 4294967295, this field has always this value. Most
// [core.py:2663] likely, playlist positions are represented as a 32 bit uint and
// [core.py:2664] this is therefore the largest index possible. Asking to add at
// [core.py:2665] this index therefore probably amounts to adding it "at the end"
// [core.py:2684] Note: A value of None for sleep_time_seconds is valid, and needs to
// [core.py:2685] be preserved distinctly separate from 0. 0 means go to sleep now,
// [core.py:2686] which will immediately start the sound tappering, and could be a
// [core.py:2687] useful feature, while None means cancel the current timer
// [core.py:2805] allow either a string 'SQ:10' or an object with item_id attribute.
// [core.py:2827] track_list = ','.join(track_list)
// [core.py:2828] position_list = ','.join(position_list)
// [core.py:2829] retrieve the update id for the object
// [core.py:2835] there is no move, a no-op
// [core.py:3004] Retrieve information from the speaker's status URL
// [core.py:3018] Convert the XML response and traverse to obtain the battery information
// [core.py:3029] Battery information not supported
// [core.py:3046] definition section
// [core.py:3058] Valid play modes and their meanings as (shuffle, repeat) tuples
// [core.py:3067] Inverse mapping of PLAY_MODES
// [core.py:3070] Music source names
// [core.py:3081] URI prefixes for music sources
// [core.py:3099] Soundbar product names

// MARK: - Original commentary: data_structure_quirks.py
// [data_structure_quirks.py:1] module docstring:
// This module implements 'quirks' for the DIDL-Lite data structures
// 
// A quirk, in this context, means that a specific music service does not follow
// a specific part of the DIDL-Lite specification. In order not to clutter the
// primary implementation of DIDL-Lite for SoCo (in :mod:`soco.data_structures`)
// up with all these service specific exception, they are implemented separately
// in this module. Besides from keeping the main implementation clean and
// following the specification, this has the added advantage of making it easier
// to track how many quiks are out there.
// 
// The implementation of the quirks at this point is just a single function which
// applies quirks to the DIDL-Lite resources, with the options of adding one that
// applies them to DIDL-Lite objects.
// 
//
// [data_structure_quirks.py:22] apply_resource_quirks docstring:
// Apply DIDL-Lite resource quirks
//
// [data_structure_quirks.py:24] At least two music service (Spotify Direct and Amazon in conjunction
// [data_structure_quirks.py:25] with Alexa) has been known not to supply the mandatory protocolInfo, so
// [data_structure_quirks.py:26] if it is missing supply a dummy one
// [data_structure_quirks.py:29] For Spotify direct we have a better idea what it should be, since it
// [data_structure_quirks.py:30] is included in the main element text

// MARK: - Original commentary: data_structures.py
// [data_structures.py:1] module docstring:
// 
// This module contains classes for handling DIDL-Lite metadata.
// 
// `DIDL`_ is the Digital Item Declaration Language , an XML schema which is
// part of MPEG21. `DIDL-Lite`_ is a cut-down version of the schema which is part
// of the UPnP ContentDirectory specification. It is the XML schema used by Sonos
// for carrying metadata representing many items such as tracks, playlists,
// composers, albums etc. Although Sonos uses
// ContentDirectory v1, the `document for v2 [pdf]`_ is more
// helpful.
// 
// .. _DIDL: http://xml.coverpages.org/mpeg21-didl.html
// .. _DIDL-Lite: http://www.upnp.org/schemas/av/didl-lite-v2.xsd
// .. _document for v2 [pdf]: _http://upnp.org/specs/av/UPnP
//      -av-ContentDirectory-v2-Service
// 
//
// [data_structures.py:49] to_didl_string docstring:
// Convert any number of `DidlObjects <DidlObject>` to a unicode xml
//     string.
// 
//     Args:
//         *args (DidlObject): One or more `DidlObject` (or subclass) instances.
// 
//     Returns:
//         str: A unicode string representation of DIDL-Lite XML in the form
//         ``'<DIDL-Lite ...>...</DIDL-Lite>'``.
//     
//
// [data_structures.py:74] didl_class_to_soco_class docstring:
// Translate a DIDL-Lite class to the corresponding SoCo data structures class
//
// [data_structures.py:122] form_name docstring:
// Return an improvised name for vendor extended classes
//
// [data_structures.py:165] DidlResource docstring:
// Identifies a resource, typically some type of a binary asset, such as a
//     song.
// 
//     It is represented in XML by a ``<res>`` element, which contains a uri that
//     identifies the resource.
//     
//
// [data_structures.py:175] DidlResource.__init__ docstring:
// 
//         Args:
//             uri (str): value of the ``<res>`` tag, typically a URI. It
//                 **must** be properly escaped (percent encoded) as
//                 described in :rfc:`3986`
//             protocol_info (str):  a string in the form a:b:c:d that
//                 identifies the streaming or transport protocol for
//                 transmitting the resource. A value is required. For more
//                 information see section 2.5.2 of the `UPnP specification [
//                 pdf]
//                 <http://upnp.org/specs/av/UPnP-av-ConnectionManager-v1-
//                 Service.pdf>`_
//             import_uri (str, optional): uri locator for resource update.
//             size (int, optional): size in bytes.
//             duration (str, optional): duration of the playback of the res
//                 at normal speed (``H*:MM:SS:F*`` or ``H*:MM:SS:F0/F1``)
//             bitrate (int, optional): bitrate in bytes/second.
//             sample_frequency (int, optional): sample frequency in Hz.
//             bits_per_sample (int, optional): bits per sample.
//             nr_audio_channels (int, optional): number of audio channels.
//             resolution (str, optional): resolution of the resource (X*Y).
//             color_depth (int, optional): color depth in bits.
//             protection (str, optional): statement of protection type.
// 
//         Note:
//             Not all of the parameters are used by Sonos. In general, only
//             ``uri``, ``protocol_info`` and ``duration`` seem to be important.
//         
//
// [data_structures.py:240] DidlResource.from_element docstring:
// Set the resource properties from a ``<res>`` element.
// 
//         Args:
//             element (~xml.etree.ElementTree.Element): The ``<res>``
//                 element
// 
//         
//
// [data_structures.py:249] DidlResource.from_element._int_helper docstring:
// Try to convert the name attribute to an int, or None.
//
// [data_structures.py:295] DidlResource.to_element docstring:
// Return an ElementTree Element based on this resource.
// 
//         Returns:
//             ~xml.etree.ElementTree.Element: an Element.
//         
//
// [data_structures.py:336] DidlResource.to_dict docstring:
// Return a dict representation of the `DidlResource`.
// 
//         Args:
//             remove_nones (bool, optional): Optionally remove dictionary
//                 elements when their value is `None`.
// 
//         Returns:
//             dict: a dict representing the `DidlResource`
//         
//
// [data_structures.py:370] DidlResource.from_dict docstring:
// Create an instance from a dict.
// 
//         An alternative constructor. Equivalent to ``DidlResource(**content)``.
// 
//         Args:
//             content (dict): a dict containing metadata information. Required.
//                 Valid keys are the same as the parameters for
//                 `DidlResource`.
//         
//
// [data_structures.py:382] DidlResource.__eq__ docstring:
// Compare with another ``DidlResource``.
// 
//         Returns:
//             (bool): `True` if all items are equal, else `False`.
//         
//
// [data_structures.py:402] DidlMetaClass docstring:
// Meta class for all Didl objects.
//
// [data_structures.py:405] DidlMetaClass.__new__ docstring:
// Create a new instance.
// 
//         Args:
//             name (str): Name of the class.
//             bases (tuple): Base classes.
//             attrs (dict): attributes defined for the class.
//         
//
// [data_structures.py:421] DidlObject docstring:
// Abstract base class for all DIDL-Lite items.
// 
//     You should not need to instantiate this. Its XML representation looks
//     like this:
// 
//     ..  code-block:: xml
// 
//         <DIDL-Lite xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/"
//          xmlns:dc="http://purl.org/dc/elements/1.1/"
//          xmlns:r="urn:schemas-rinconnetworks-com:metadata-1-0/"
//          xmlns:upnp="urn:schemas-upnp-org:metadata-1-0/upnp/">
//           <item id="...self.item_id..." parentID="...cls.parent_id..."
//             restricted="true">
//             <dc:title>...self.title...</dc:title>
//             <upnp:class>...self.item_class...</upnp:class>
//             <desc id="cdudn"
//               nameSpace="urn:schemas-rinconnetworks-com:metadata-1-0/">
//               RINCON_AssociatedZPUDN
//             </desc>
//           </item>
//         </DIDL-Lite>
//     
//
// [data_structures.py:454] DidlObject.__init__ docstring:
// 
//         Args:
//             title (str): the title for the item.
//             parent_id (str): the parent ID for the item.
//             item_id (str): the ID for the item.
//             restricted (bool): whether the item can be modified. Default `True`
//             resources (list, optional): a list of resources for this object.
//             Default `None`.
//             desc (str): A DIDL descriptor, default
//                 ``'RINCON_AssociatedZPUDN'``. This is not the same as
//                 "description". It is used for identifying the relevant
//                 third party music service.
//             **kwargs: Extra metadata. What is allowed depends on the
//                 ``_translation`` class attribute, which in turn depends on the
//                 DIDL class.
// 
// 
// 
//         ..  autoattribute:: item_class
// 
//             str - the DIDL Lite class for this object.
// 
//         ..  autoattribute:: tag
// 
//             str - the XML element tag name used for this instance.
// 
//         ..  autoattribute:: _translation
// 
//             dict - A dict used to translate between instance attribute
//             names and XML tags/namespaces. It also serves to define the
//             allowed tags/attributes for this instance. Each key an attribute
//             name and each key is a ``(namespace, tag)`` tuple.
// 
//         
//
// [data_structures.py:538] DidlObject.from_element docstring:
// Create an instance of this class from an ElementTree xml Element.
// 
//         An alternative constructor. The element must be a DIDL-Lite <item> or
//         <container> element, and must be properly namespaced.
// 
//         Args:
//             xml (~xml.etree.ElementTree.Element): An
//                 :class:`~xml.etree.ElementTree.Element` object.
//         
//
// [data_structures.py:637] DidlObject.from_dict docstring:
// Create an instance from a dict.
// 
//         An alternative constructor. Equivalent to ``DidlObject(**content)``.
// 
//         Args:
//             content (dict): a dict containing metadata information. Required.
//                 Valid keys are the same as the parameters for `DidlObject`.
// 
//         
//
// [data_structures.py:655] DidlObject.__eq__ docstring:
// Compare with another ``playable_item``.
// 
//         Returns:
//             (bool): `True` if all items are equal, else `False`.
//         
//
// [data_structures.py:665] DidlObject.__ne__ docstring:
// Compare with another ``playable_item``.
// 
//         Returns:
//             (bool): `True` if any items is unequal, else `False`.
//         
//
// [data_structures.py:675] DidlObject.__repr__ docstring:
// Get the repr value for the item.
// 
//         Returns:
//             str: A string representation of the instance in the form
//             ``<class_name 'middle_part[0:40]' at id_in_hex>`` where
//             middle_part is either the title item in content, if it is set, or
//             ``str(content)``. The output is also cleared of non-ascii
//             characters.
//         
//
// [data_structures.py:693] DidlObject.__str__ docstring:
// Get the str value for the item.
// 
//         Returns:
//             str: a string representation in the form
//             ``<class_name 'middle_part[0:40]' at id_in_hex>`` where
//             middle_part is either the title item in content, if it is set, or
//             ``str(content)``. The output is also cleared of non-ascii
//             characters.
//         
//
// [data_structures.py:705] DidlObject.to_dict docstring:
// Return the dict representation of the instance.
// 
//         Args:
//              remove_nones (bool, optional): Optionally remove dictionary
//                  elements when their value is `None`.
// 
//          Returns:
//              dict: a dict representation of the `DidlObject`.
//         
//
// [data_structures.py:735] DidlObject.to_element docstring:
// Return an ElementTree Element representing this instance.
// 
//         Args:
//             include_namespaces (bool, optional): If True, include xml
//                 namespace attributes on the root element
// 
//         Return:
//             ~xml.etree.ElementTree.Element: an Element.
//         
//
// [data_structures.py:792] DidlObject.get_uri docstring:
// Return the uri to use for playing this item.
// 
//         Args:
//             resource_nr (int): The index of the resource. Note that there is no
//                 known object with more than one resource, so you can probably
//                 keep the default value (0).
//         Returns:
//             str: The uri.
//         
//
// [data_structures.py:804] DidlObject.set_uri docstring:
// Set a resource uri for this instance. If no resource exists, create
//         a new one with the given protocol info.
// 
//         Args:
//             uri (str): The resource uri.
//             resource_nr (int): The index of the resource on which to set the
//                 uri. If it does not exist, a new resource is added to the list.
//                 Note that by default, only the uri of the first resource is
//                 used for playing the item.
//             protocol_info (str): Protocol info for the resource. If none is
//                 given and the resource does not exist yet, a default protocol
//                 info is constructed as ``'[uri prefix]:*:*:*'``.
//         
//
// [data_structures.py:834] DidlItem docstring:
// A basic content directory item.
//
// [data_structures.py:853] DidlAudioItem docstring:
// An audio item.
//
// [data_structures.py:872] DidlMusicTrack docstring:
// Class that represents a music library track.
//
// [data_structures.py:891] DidlAudioBook docstring:
// Class that represents an audio book.
//
// [data_structures.py:908] DidlAudioBroadcast docstring:
// Class that represents an audio broadcast.
//
// [data_structures.py:924] DidlAudioLineIn docstring:
// Class that represents an audio line in.
//
// [data_structures.py:937] DidlRecentShow docstring:
// Class that represents a recent radio show/podcast.
//
// [data_structures.py:944] DidlAudioBroadcastFavorite docstring:
// Class that represents an audio broadcast Sonos favorite.
//
// [data_structures.py:955] DidlFavorite docstring:
// Class that represents a Sonos favorite.
// 
//     Note that the favorite itself isn't playable in all cases, please use the
//     object returned by :attr:`favorite.reference` instead.
//
// [data_structures.py:977] DidlFavorite.reference docstring:
// The Didl object this favorite refers to.
// 
//         Raises:
//             DIDLMetadataError: If the favorite has no ``resMD`` element, or if
//                 its ``resMD`` element holds no DIDL item.
//         
//
// [data_structures.py:1027] DidlContainer docstring:
// Class that represents a music library container.
//
// [data_structures.py:1037] DidlAlbum docstring:
// A content directory album.
//
// [data_structures.py:1057] DidlMusicAlbum docstring:
// Class that represents a music library album.
//
// [data_structures.py:1081] DidlMusicAlbumFavorite docstring:
// Class that represents a Sonos favorite music library album.
// 
//     This class is not part of the DIDL spec and is Sonos specific.
//     
//
// [data_structures.py:1095] DidlMusicAlbumCompilation docstring:
// Class that represents a Sonos favorite music library compilation.
// 
//     This class is not part of the DIDL spec and is Sonos specific.
//     
//
// [data_structures.py:1109] DidlPerson docstring:
// A content directory class representing a person.
//
// [data_structures.py:1124] DidlComposer docstring:
// Class that represents a music library composer.
//
// [data_structures.py:1133] DidlMusicArtist docstring:
// Class that represents a music library artist.
//
// [data_structures.py:1148] DidlAlbumList docstring:
// Class that represents a music library album list.
//
// [data_structures.py:1157] DidlPlaylistContainer docstring:
// Class that represents a music library play list.
//
// [data_structures.py:1185] DidlSameArtist docstring:
// Class that represents all tracks by a single artist.
// 
//     This type is returned by browsing an artist or a composer
//     
//
// [data_structures.py:1196] DidlPlaylistContainerFavorite docstring:
// Class that represents a Sonos favorite play list.
//
// [data_structures.py:1202] DidlPlaylistContainerTracklist docstring:
// Class that represents a Sonos tracklist.
//
// [data_structures.py:1208] DidlGenre docstring:
// A content directory class representing a general genre.
//
// [data_structures.py:1226] DidlMusicGenre docstring:
// Class that represents a music genre.
//
// [data_structures.py:1234] DidlRadioShow docstring:
// Class that represents a radio show.
//
// [data_structures.py:1247] ListOfMusicInfoItems docstring:
// Abstract container class for a list of music information items.
// 
//     Instances of this class are returned from queries into the music library
//     or to music services. The attributes :attr:`~total_matches` and
//     :attr:`~number_returned` are used to ascertain whether paging is required
//     in order to retrive all elements of the query. :attr:`~total_matches` is
//     the total number of results to the query and :attr:`~number_returned` is
//     the number of results actually returned. If the two differ, paging is
//     required. Paging is typically performed with the ``start`` and
//     ``max_items`` arguments to the query method. See e.g. the
//     :meth:`~soco.music_library.MusicLibrary.get_music_library_information`
//     method for details.
//     
//
// [data_structures.py:1271] ListOfMusicInfoItems.__getitem__ docstring:
// Legacy get metadata by string key or list item(s) by index.
// 
//         .. deprecated:: 0.8
// 
//             This overriding form of __getitem__ will be removed in the 3rd
//             release after 0.8. The metadata can be fetched via the named
//             attributes.
//         
//
// [data_structures.py:1301] ListOfMusicInfoItems.number_returned docstring:
// str: the number of returned matches.
//
// [data_structures.py:1306] ListOfMusicInfoItems.total_matches docstring:
// str: the number of total matches.
//
// [data_structures.py:1311] ListOfMusicInfoItems.update_id docstring:
// str: the update ID.
//
// [data_structures.py:1316] SearchResult docstring:
// Container class that represents a search or browse result.
// 
//     Browse is just a special case of search.
//     
//
// [data_structures.py:1334] SearchResult.search_type docstring:
// str: the search type.
//
// [data_structures.py:1339] Queue docstring:
// Container class that represents a queue.
//
// [data_structures.py:1] pylint: disable=star-args, fixme, import-outside-toplevel
// [data_structures.py:3] Disable while we have Python 2.x compatability
// [data_structures.py:4] pylint: disable=useless-object-inheritance,bad-mcs-classmethod-argument
// [data_structures.py:24] It tries to follow the class hierarchy provided by the DIDL-Lite schema
// [data_structures.py:25] described in the UPnP Spec, especially that for the ContentDirectory Service
// [data_structures.py:27] Although Sonos uses ContentDirectory v1, the document for v2 is more helpful:
// [data_structures.py:28] http://upnp.org/specs/av/UPnP-av-ContentDirectory-v2-Service.pdf
// [data_structures.py:39] Due to cyclic import problems, we only import from_didl_string at runtime.
// [data_structures.py:40] from data_structures_entry import from_didl_string
// [data_structures.py:44] ##############################################################################
// [data_structures.py:45] MISC HELPER FUNCTIONS                                                       #
// [data_structures.py:46] ##############################################################################
// [data_structures.py:78] Certain music services have been observed to sub-class via a .# or # syntax.
// [data_structures.py:79] We simply remove these subclasses.
// [data_structures.py:87] Unknown class, automatically create subclass
// [data_structures.py:127] We know that the string starts with "object." so -1 indexing is safe
// [data_structures.py:129] If it is a Sonos favorite, form the name as the class component
// [data_structures.py:130] before with "Favorite" added. So:
// [data_structures.py:131] object.item.audioItem.audioBroadcast.sonos-favorite
// [data_structures.py:132] turns into
// [data_structures.py:133] DidlAudioBroadcastFavorite
// [data_structures.py:137] For any other class, for the name as the concatenation of all
// [data_structures.py:138] the class components that are not UPnP core classes. So:
// [data_structures.py:139] object.container.playlistContainer.sameArtist
// [data_structures.py:140] Turns into:
// [data_structures.py:141] DidlSameArtist
// [data_structures.py:144] Strip the components one by one and check whether the base is known
// [data_structures.py:152] For class path last parts that contain the word list, capitalize it
// [data_structures.py:160] ##############################################################################
// [data_structures.py:161] DIDL RESOURCE                                                               #
// [data_structures.py:162] ##############################################################################
// [data_structures.py:173] Adapted from a class taken from the Python Brisa project - MIT licence.
// [data_structures.py:218] Of these attributes, only uri, protocol_info and duration have been
// [data_structures.py:219] spotted 'in the wild'
// [data_structures.py:220] : (str): a percent encoded URI
// [data_structures.py:222] Protocol info is in the form a:b:c:d - see
// [data_structures.py:223] sec 2.5.2 at
// [data_structures.py:224] http://upnp.org/specs/av/UPnP-av-ConnectionManager-v1-Service.pdf
// [data_structures.py:225] : (str): protocol information.
// [data_structures.py:229] : str: playback duration
// [data_structures.py:262] Check for and fix non-spec compliant behavior in the incoming data
// [data_structures.py:266] required
// [data_structures.py:273] Optional
// [data_structures.py:309] Required
// [data_structures.py:311] Optional
// [data_structures.py:361] delete any elements that have a value of None to optimize size
// [data_structures.py:362] of the returned structure
// [data_structures.py:363] pylint: disable=C0206
// [data_structures.py:393] ##############################################################################
// [data_structures.py:394] BASE OBJECTS                                                                #
// [data_structures.py:395] ##############################################################################
// [data_structures.py:397] a mapping which will be used to look up the relevant class from the
// [data_structures.py:398] DIDL item class
// [data_structures.py:414] Register all subclasses with the global _DIDL_CLASS_TO_CLASS mapping
// [data_structures.py:445] the DIDL Lite class for this object.
// [data_structures.py:448] key: attribute_name: (ns, tag)
// [data_structures.py:498] All didl objects *must* have a title, a parent_id and an item_id
// [data_structures.py:499] so we specify these as required args in the constructor signature
// [data_structures.py:500] to ensure that we get them. Other didl object properties are
// [data_structures.py:501] optional, so can be passed as kwargs.
// [data_structures.py:502] The content of _translation is adapted from the list in table C at
// [data_structures.py:503] http://upnp.org/specs/av/UPnP-av-ContentDirectory-v2-Service.pdf
// [data_structures.py:504] Not all properties referred to there are catered for, since Sonos
// [data_structures.py:505] does not use some of them.
// [data_structures.py:507] pylint: disable=super-on-old-class
// [data_structures.py:512] Restricted is a compulsory attribute, but is almost always True for
// [data_structures.py:513] Sonos. (Only seen it 'false' when browsing favorites)
// [data_structures.py:516] Resources is multi-valued, and dealt with separately
// [data_structures.py:519] According to the spec, there may be one or more desc values. Sonos
// [data_structures.py:520] only seems to use one, so we won't bother with a list
// [data_structures.py:524] For each attribute, check to see if this class allows it
// [data_structures.py:532] It is an allowed attribute. Set it as an attribute on self, so
// [data_structures.py:533] that it can be accessed as Classname.attribute in the normal
// [data_structures.py:534] way.
// [data_structures.py:538] pylint: disable=R0914
// [data_structures.py:548] We used to check here that we have the right sort of element,
// [data_structures.py:549] ie a container or an item. But Sonos seems to use both
// [data_structures.py:550] indiscriminately, eg a playlistContainer can be an item or a
// [data_structures.py:551] container. So we now just check that it is one or the other.
// [data_structures.py:558] and that the upnp matches what we are expecting
// [data_structures.py:561] In case this class has an # specified unofficial
// [data_structures.py:562] subclass, ignore it by stripping it from item_class
// [data_structures.py:573] parent_id, item_id  and restricted are stored as attributes on the
// [data_structures.py:574] element
// [data_structures.py:584] CAUTION: This implementation deviates from the spec.
// [data_structures.py:585] Elements are normally required to have a `restricted` tag, but
// [data_structures.py:586] Spotify Direct violates this. To make it work, a missing restricted
// [data_structures.py:587] tag is interpreted as `restricted = True`.
// [data_structures.py:591] Similarily, all elements should have a title tag, but Spotify Direct
// [data_structures.py:592] does not comply
// [data_structures.py:599] Deal with any resource elements
// [data_structures.py:602] Not all Favorits have resources, so in case the "res"
// [data_structures.py:603] tage has no attributes, just skip it
// [data_structures.py:608] and the desc element (There is only one in Sonos)
// [data_structures.py:611] Get values of the elements listed in _translation and add them to
// [data_structures.py:612] the content dict
// [data_structures.py:617] We store info as unicode internally.
// [data_structures.py:620] Convert type for original track number
// [data_structures.py:624] Now pass the content dict we have just built to the main
// [data_structures.py:625] constructor, as kwargs, to create the object
// [data_structures.py:647] Do we really need this constructor? Could use DidlObject(**content)
// [data_structures.py:648] instead.  -- We do now
// [data_structures.py:685] 40 originates from terminal width (78) - (15) for address part and
// [data_structures.py:686] (19) for the longest class name and a little left for buffer
// [data_structures.py:716] Get the value of each attribute listed in _translation, and add it
// [data_structures.py:717] to the content dict
// [data_structures.py:721] also add parent_id, item_id, restricted, title and resources because
// [data_structures.py:722] they are not listed in _translation
// [data_structures.py:763] Add the title, which should always come first, according to the spec
// [data_structures.py:766] Add in any resources
// [data_structures.py:770] Add the rest of the metadata attributes (i.e all those listed in
// [data_structures.py:771] _translation) as sub-elements of the item element.
// [data_structures.py:774] Some attributes have a namespace of '', which means they
// [data_structures.py:775] are in the default namespace. We need to handle those
// [data_structures.py:776] carefully
// [data_structures.py:779] Now add in the item class
// [data_structures.py:782] And the desc element
// [data_structures.py:824] create default protcol info
// [data_structures.py:829] ##############################################################################
// [data_structures.py:830] OBJECT.ITEM HIERARCHY                                                       #
// [data_structures.py:831] ##############################################################################
// [data_structures.py:837] The spec allows for an option 'refID' attribute, but we do not handle it
// [data_structures.py:839] the DIDL Lite class for this object.
// [data_structures.py:841] _translation = DidlObject._translation.update({ ...})
// [data_structures.py:842] does not work, but doing it in two steps does
// [data_structures.py:856] the DIDL Lite class for this object.
// [data_structures.py:875] the DIDL Lite class for this object.
// [data_structures.py:877] name: (ns, tag)
// [data_structures.py:894] the DIDL Lite class for this object.
// [data_structures.py:896] name: (ns, tag)
// [data_structures.py:911] the DIDL Lite class for this object.
// [data_structures.py:927] the DIDL Lite class for this object.
// [data_structures.py:940] the DIDL Lite class for this object.
// [data_structures.py:947] Note: The sonos-favorite part of the class spec obviously isn't part of
// [data_structures.py:948] the DIDL spec, so just assume that it has the same definition as the
// [data_structures.py:949] regular object.item.audioItem.audioBroadcast
// [data_structures.py:951] the DIDL Lite class for this object.
// [data_structures.py:961] the DIDL Lite class for this object.
// [data_structures.py:973] The resMD tag contains the metadata of the Didl object referenced by this
// [data_structures.py:974] favorite. For user convenience, we will parse this metadata and make the
// [data_structures.py:975] object available via the 'reference' property.
// [data_structures.py:985] Import from_didl_string if it isn't present already. The import
// [data_structures.py:986] happens here because it would cause cyclic import errors if the
// [data_structures.py:987] import happened at load time.
// [data_structures.py:988] pylint: disable=global-statement
// [data_structures.py:994] Some speakers have been observed to return favorites without any
// [data_structures.py:995] resMD, or with a resMD that holds no item. Raise a SoCoException
// [data_structures.py:996] subclass rather than letting AttributeError or IndexError escape.
// [data_structures.py:1011] The resMD metadata lacks a <res> tag, so we use the resources from
// [data_structures.py:1012] the favorite to make 'reference' playable.
// [data_structures.py:1022] ##############################################################################
// [data_structures.py:1023] OBJECT.CONTAINER HIERARCHY                                                  #
// [data_structures.py:1024] ##############################################################################
// [data_structures.py:1030] the DIDL Lite class for this object.
// [data_structures.py:1033] We do not implement createClass or searchClass. Not used by Sonos??
// [data_structures.py:1034] TODO: handle the 'childCount' element.
// [data_structures.py:1040] the DIDL Lite class for this object.
// [data_structures.py:1042] name: (ns, tag)
// [data_structures.py:1060] the DIDL Lite class for this object.
// [data_structures.py:1062] According to the spec, all musicAlbums should be represented in
// [data_structures.py:1063] XML by a <container> tag. Sonos sometimes uses <container> and
// [data_structures.py:1064] sometimes uses <item>. <container> seems to work here for the moment.
// [data_structures.py:1066] name: (ns, tag)
// [data_structures.py:1067] pylint: disable=protected-access
// [data_structures.py:1068] :
// [data_structures.py:1087] the DIDL Lite class for this object.
// [data_structures.py:1089] Despite the fact that the item derives from object.container, it's
// [data_structures.py:1090] XML does not include a <container> tag, but an <item> tag. This seems
// [data_structures.py:1091] to be an error by Sonos.
// [data_structures.py:1101] These classes appear when browsing the library and Sonos has been set
// [data_structures.py:1102] to group albums using compilations.
// [data_structures.py:1103] See https://github.com/SoCo/SoCo/issues/280
// [data_structures.py:1104] the DIDL Lite class for this object.
// [data_structures.py:1112] the DIDL Lite class for this object.
// [data_structures.py:1115] : dfdf
// [data_structures.py:1127] Not in the DIDL-Lite spec. Sonos specific??
// [data_structures.py:1129] the DIDL Lite class for this object.
// [data_structures.py:1136] the DIDL Lite class for this object.
// [data_structures.py:1138] name: (ns, tag)
// [data_structures.py:1151] This does not appear (that I can find) in the DIDL-Lite specs.
// [data_structures.py:1152] Presumably Sonos specific
// [data_structures.py:1153] the DIDL Lite class for this object.
// [data_structures.py:1160] (str) The DIDL Lite class for this object
// [data_structures.py:1162] Yes, really. Sonos uses the item tag, not the container tag. But
// [data_structures.py:1163] sometimes it uses the container tag, eg:
// [data_structures.py:1164] >>> s=soco.SoCo('192.168.1.102')
// [data_structures.py:1165] >>> s.get_playlists()
// [data_structures.py:1166] See https://github.com/SoCo/SoCo/issues/353
// [data_structures.py:1168] name: (ns, tag)
// [data_structures.py:1191] Not in the DIDL-Lite spec. Sonos specific?
// [data_structures.py:1192] the DIDL Lite class for this object.
// [data_structures.py:1211] the DIDL Lite class for this object.
// [data_structures.py:1213] name: (ns, tag)
// [data_structures.py:1215] :
// [data_structures.py:1229] the DIDL Lite class for this object.
// [data_structures.py:1237] the DIDL Lite class for this object.
// [data_structures.py:1239] A radio show doesn't seem to have any special attributes
// [data_structures.py:1242] ##############################################################################
// [data_structures.py:1243] SPECIAL LISTS                                                               #
// [data_structures.py:1244] ##############################################################################

// MARK: - Original commentary: data_structures_entry.py
// [data_structures_entry.py:1] module docstring:
// This module is for parsing and conversion functions that needs
// objects from both music library and music service data structures
// 
//
// [data_structures_entry.py:20] from_didl_string docstring:
// Convert a unicode xml string to a list of `DIDLObjects <DidlObject>`.
// 
//     Args:
//         string (str): A unicode string containing an XML representation of one
//             or more DIDL-Lite items (in the form  ``'<DIDL-Lite ...>
//             ...</DIDL-Lite>'``)
// 
//     Returns:
//         list: A list of one or more instances of `DidlObject` or a subclass
//     
//
// [data_structures_entry.py:43] <desc> elements are allowed as an immediate child of <DIDL-Lite>
// [data_structures_entry.py:44] according to the spec, but I have not seen one there in Sonos, so
// [data_structures_entry.py:45] we treat them as illegal. May need to fix this if this
// [data_structures_entry.py:46] causes problems.

// MARK: - Original commentary: discovery.py
// [discovery.py:1] module docstring:
// This module contains methods for discovering Sonos devices on the
// network.
//
// [discovery.py:20] discover docstring:
// Discover Sonos zones on the local network.
// 
//     Return a set of `SoCo` instances for each zone found.
//     Include invisible zones (bridges and slave zones in stereo pairs if
//     ``include_invisible`` is `True`. Will block for up to ``timeout`` seconds,
//     after which return `None` if no zones found.
// 
//     Note that the presence of a `SoCo` object in the returned set is not a
//     guarantee that the associated Sonos player is currently contactable. This
//     is because the set of `SoCo` objects is generated by interrogating the
//     first discovered player to determine the current set of players, and this
//     data can lag the actual state of the system, e.g., if a speaker has been
//     recently switched off.
// 
//     Args:
//         timeout (int, optional): block for this many seconds, at most.
//             Defaults to 5.
//         include_invisible (bool, optional): include invisible zones in the
//             return set. Defaults to `False`.
//         interface_addr (str or None): Discovery operates by sending UDP
//             multicast datagrams. ``interface_addr`` is a string (dotted
//             quad) representation of the network interface address to use as
//             the source of the datagrams (i.e., it is a value for
//             `socket.IP_MULTICAST_IF <socket>`). If `None` or not specified,
//             the system default interface(s) for UDP multicast messages will be
//             used. This is probably what you want to happen. Defaults to
//             `None`.
//         household_id (str): Supply a Sonos Household ID to restrict discovery
//             to a specific household. Useful in multi-household networks. In
//             the default case the first player to respond will be used.
//         allow_network_scan (bool, optional): If normal discovery fails, fall
//             back to a scan of the attached network(s) to detect Sonos
//             devices.
//         **network_scan_kwargs: Arguments for the `scan_network` function.
//             See its docstring for details.
//     Returns:
//         set: a set of `SoCo` instances, one for each zone found, or else
//         `None`.
//     
//
// [discovery.py:68] discover.create_socket docstring:
// A helper function for creating a socket for discovery purposes.
// 
//         Create and return a socket with appropriate options set for multicast.
//         
//
// [discovery.py:144] discover.close_sockets docstring:
// Helper function to close all remaining open sockets
//
// [discovery.py:220] any_soco docstring:
// Return any visible soco device, for when it doesn't matter which.
// 
//     Try to obtain an existing instance, or use `discover` if necessary.
//     Note that this assumes that the existing instance has not left
//     the network.
// 
//     Args:
//         allow_network_scan (bool, optional): If normal discovery fails, fall
//             back to a scan of the attached network(s) to detect Sonos
//             devices.
//         **network_scan_kwargs: Arguments for the `scan_network` function.
//             See its docstring for details.
// 
//     Returns:
//         SoCo: A `SoCo` instance (or subclass if `config.SOCO_CLASS` is set),
//         or `None` if no instances are found.
//     
//
// [discovery.py:256] by_name docstring:
// Return a device by name.
// 
//     Args:
//         name (str): The name of the device to return.
//         allow_network_scan (bool, optional): If normal discovery fails, fall
//             back to a scan of the attached network(s) to detect Sonos
//             devices.
//         **network_scan_kwargs: Arguments for the `scan_network` function.
//             See its docstring for details.
// 
//     Returns:
//         SoCo: A `SoCo` instance (or subclass if `config.SOCO_CLASS` is set),
//         or `None` if no instances are found.
//     
//
// [discovery.py:281] scan_network docstring:
// Scan all attached networks for Sonos devices.
// 
//     This function scans the IPv4 networks to which this node is attached,
//     searching for Sonos devices. Multiple parallel threads are used to
//     scan IP addresses in parallel for faster discovery.
// 
//     Public, loopback and link local IP ranges are excluded from the scan,
//     and the scope of the search can be controlled by setting a minimum netmask.
// 
//     Alternatively, a list of networks to scan can be provided.
// 
//     This function is intended for use when the usual discovery function is not
//     working, perhaps due to multicast problems on the network to which the SoCo
//     host is attached. The function can also be used to find a complete list of
//     speakers when there are multiple Sonos households present.
//     For example, this is the case where there are 'split' S1/S2 Sonos systems
//     on the network.
// 
//     Note that this call may fail to find speakers present on the network, and
//     this can be due to ARP cache misses and ARP requests that don't
//     complete within the timeout. The call can be retried with longer values for
//     scan_timeout if necessary.
// 
//     Note also that the presence of a `SoCo` object in the returned set is not a
//     guarantee that the associated Sonos player is currently contactable. This
//     is because the set of `SoCo` objects is partly generated by interrogating
//     discovered players to determine the current set(s) of players, and this can
//     lag the actual state of the system, e.g., if a speaker has been recently
//     switched off.
// 
//     Args:
//         include_invisible (bool, optional): Whether to include invisible Sonos devices
//             in the set of devices returned.
//         multi_household (bool, optional): Whether to find all the speakers on the
//             network exhaustively.
//             If set to `False`, discovery will stop as soon as at least one speaker is
//             found. In the case of multiple households on the attached networks, this
//             means that only the speakers from the first-discovered household will be
//             returned.
//             If set to `True`, discovery will proceed until all speakers, from all
//             households, have been found.
//         max_threads (int, optional): The maximum number of threads to use when
//             scanning the network.
//         scan_timeout (float, optional): The network timeout in seconds to use when
//             checking each IP address for a Sonos device.
//         min_netmask (int, optional): The minimum number of netmask bits. Used to
//             constrain the network search space.
//         networks_to_scan (list, optional): A `list` of IPv4 networks to search,
//             each a `str` of form "192.168.0.1/24". Only the specified networks will
//             be searched. The 'min_netmask' option (if supplied) is ignored.
// 
//     Returns:
//         set: A set of `SoCo` instances, one for each zone found, or else `None`.
//     
//
// [discovery.py:417] scan_network_by_household_id docstring:
// Convenience function to find the zones in a specific Sonos
//     household.
// 
//     Args:
//         household_id (str): The Sonos household ID to search for. IDs take the
//             form 'Sonos_XXXXXXXXXXXXXXXXXXXXXXXXXX'.
//         include_invisible (bool, optional): Whether to include invisible Sonos devices
//             in the set of devices returned.
//         **network_scan_kwargs: Arguments for the `scan_network` function.
//             See its docstring for details. (Note that the argument
//             'multi_household' is forced to `True` when this function is
//             called.)
// 
//     Returns:
//         set: A set of `SoCo` instances, one for each zone found, or else `None`.
//     
//
// [discovery.py:446] scan_network_get_household_ids docstring:
// Convenience function to find the all Sonos households on the attached
//     networks.
// 
//     Args:
//         **network_scan_kwargs: Arguments for the `scan_network` function.
//             See its docstring for details. (Note that the argument
//             'multi_household' is forced to `True` when this function is
//             called.)
// 
//     Returns:
//         set: A set of Sonos household IDs, each in the form of a `str`
//         like 'Sonos_XXXXXXXXXXXXXXXXXXXXXXXXXX'.
//     
//
// [discovery.py:473] scan_network_get_by_name docstring:
// Convenience function to use `scan_network` to find a zone
//     by its name.
// 
//     Note that if there are multiple zones with the same name,
//     then only one of the zones will be returned. Optionally,
//     the search can be constrained to a specific household.
// 
//     Args:
//         name (str): The name of the zone to find.
//         household_id (str, optional): Use this to find the zone in a specific
//              Sonos household.
//         **network_scan_kwargs: Arguments for the `scan_network` function.
//             See its docstring for details. (Note that the argument
//             'multi_household' is forced to `True` when this function is
//             called.)
// 
//     Returns:
//         SoCo: A `SoCo` instance representing the zone, or `None` if no
//         matching zone is found. Only returns visible zones.
//     
//
// [discovery.py:514] scan_network_any_soco docstring:
// Convenience function to use `scan_network` to find any zone,
//     optionally specifying a Sonos household.
// 
//     Args:
//         household_id (str, optional): Use this to find a zone in a specific
//             Sonos household.
//         **network_scan_kwargs: Arguments for the `scan_network` function.
//             See its docstring for details.
// 
//     Returns:
//         SoCo: A `SoCo` instance representing the zone, or `None` if no
//         zone is found (or no zone is found that matches a supplied
//         household_id).
//     
//
// [discovery.py:548] contactable docstring:
// Find only contactable players in a set of `SoCo` objects.
// 
//     This function checks a set of `SoCo` objects to ensure that each
//     associated Sonos player is currently contactable. A new set
//     is returned containing only contactable players.
// 
//     If there are non-contactable players, the function return will
//     be delayed until at least one network timeout has expired (several
//     seconds). Contact attempts run in parallel threads to minimise
//     delays.
// 
//     Args:
//         speakers(set): A set of `SoCo` objects.
// 
//     Returns:
//         set: A set of `SoCo` objects, all of which have been
//         confirmed to be currently contactable. An empty set
//         is returned if no speakers are contactable.
//     
//
// [discovery.py:569] contactable.contactable_worker docstring:
// Worker thread helper function to check whether
//         speakers are contactable and, if so, to add them to
//         the set of contactable speakers.
//         
//
// [discovery.py:611] _find_ipv4_networks docstring:
// Discover attached IP networks.
// 
//     Helper function to return a set of IPv4 networks to which
//     the network interfaces on this node are attached.
//     Exclude public, loopback and link local network ranges.
// 
//     Args:
//         min_netmask(int): The minimum netmask to be used.
// 
//     Returns:
//         set: A set of `ipaddress.ip_network` instances.
//     
//
// [discovery.py:662] _find_ipv4_addresses docstring:
// Discover and return all the host's IPv4 addresses.
// 
//     Helper function to return a set of IPv4 addresses associated
//     with the network interfaces of this host. Loopback and link
//     local addresses are excluded.
// 
//     Returns:
//         set: A set of IPv4 addresses (dotted decimal strings). Empty
//         set if there are no addresses found.
//     
//
// [discovery.py:690] _check_ip_and_port docstring:
// Helper function to check if a port is open.
// 
//     Args:
//         ip_address(str): The IP address to be checked.
//         port(int): The port to be checked.
//         timeout(float): The timeout to use.
// 
//     Returns:
//         bool: True if a connection can be made.
//     
//
// [discovery.py:707] _is_sonos docstring:
// Helper function to check if this is a Sonos device.
// 
//     Args:
//         ip_address(str): The IP address to be checked.
// 
//     Returns:
//         bool: True if there is a Sonos device at the address.
//     
//
// [discovery.py:727] _sonos_scan_worker_thread docstring:
// Helper function worker thread to take IP addresses from a set and
//     test whether there is (1) a device with port 1400 open at that IP
//     address, then (2) check the device is a Sonos device.
// 
//     Once a there is a hit, the set is cleared to prevent any further
//     checking of addresses by any thread, unless 'multi_household' is
//     `True`, in which case all IP addresses will be checked.
//     
//
// [discovery.py:75] UPnP v1.0 requires a TTL of 4
// [discovery.py:84] pylint: disable=invalid-name
// [discovery.py:95] Use the specified interface, if any
// [discovery.py:106] Use all qualified, discovered network interfaces
// [discovery.py:113] Create sockets
// [discovery.py:128] Send a few times to each socket. UDP is unreliable
// [discovery.py:130] Copy the list, because items may be removed
// [discovery.py:152] Check if the timeout is exceeded. We could do this check just
// [discovery.py:153] before the currently only continue statement of this loop,
// [discovery.py:154] but I feel it is safer to do it here, so that we do not forget
// [discovery.py:155] to do it if/when another continue statement is added later.
// [discovery.py:156] Note: this is sensitive to clock adjustments. AFAIK there
// [discovery.py:157] is no monotonic timer available before Python 3.3.
// [discovery.py:164] The timeout of the select call is set to be no greater than
// [discovery.py:165] 100ms, so as not to exceed (too much) the required timeout
// [discovery.py:166] in case the loop is executed more than once.
// [discovery.py:169] Only Zone Players should respond, given the value of ST in the
// [discovery.py:170] PLAYER_SEARCH message. However, to prevent misbehaved devices
// [discovery.py:171] on the network disrupting the discovery process, we check that
// [discovery.py:172] the response contains the "Sonos" string; otherwise we keep
// [discovery.py:173] waiting for a correct response.
// [discovery.py:174] 
// [discovery.py:175] Here is a sample response from a real Sonos device (actual numbers
// [discovery.py:176] have been redacted):
// [discovery.py:177] HTTP/1.1 200 OK
// [discovery.py:178] CACHE-CONTROL: max-age = 1800
// [discovery.py:179] EXT:
// [discovery.py:180] LOCATION: http://***.***.***.***:1400/xml/device_description.xml
// [discovery.py:181] SERVER: Linux UPnP/1.0 Sonos/26.1-76230 (ZPS3)
// [discovery.py:182] ST: urn:schemas-upnp-org:device:ZonePlayer:1
// [discovery.py:183] USN: uuid:RINCON_B8*************00::urn:schemas-upnp-org:device:
// [discovery.py:184] ZonePlayer:1
// [discovery.py:185] X-RINCON-BOOTSEQ: 3
// [discovery.py:186] X-RINCON-HOUSEHOLD: Sonos_7O********************R7eU
// [discovery.py:193] Now we have an IP, we can build a SoCo instance and query
// [discovery.py:194] that player for the topology to find the other players.
// [discovery.py:195] It is much more efficient to rely upon the Zone
// [discovery.py:196] Player's ability to find the others, than to wait for
// [discovery.py:197] query responses from them ourselves.
// [discovery.py:240] pylint: disable=no-member, protected-access
// [discovery.py:242] Try to get the first pre-existing soco instance we know about,
// [discovery.py:243] as long as it is visible (i.e. not a bridge etc). Otherwise,
// [discovery.py:244] perform discovery (again, excluding invisibles) and return one of
// [discovery.py:245] those
// [discovery.py:344] Generate the set of IPs to check
// [discovery.py:352] Ignore the error and continue processing the list
// [discovery.py:359] Find Sonos devices on the list of IPs
// [discovery.py:360] Use threading to scan the list efficiently
// [discovery.py:372] We probably can't start any more threads
// [discovery.py:373] Cease thread creation and continue
// [discovery.py:382] Wait for all threads to finish
// [discovery.py:387] No Sonos devices found
// [discovery.py:392] Collect SoCo instances
// [discovery.py:401] Stop after first zone unless we want exhaustively to find
// [discovery.py:402] all zones across all households
// [discovery.py:437] multi_household must be set to True
// [discovery.py:461] multi_household must be set to True
// [discovery.py:495] multi_household must be set to True
// [discovery.py:580] Try getting a device property
// [discovery.py:584] The exception is unimportant
// [discovery.py:585] pylint: disable=bare-except
// [discovery.py:586] noqa: E722
// [discovery.py:593] Attempt to create one thread per speaker
// [discovery.py:601] Can't create any more threads
// [discovery.py:632] Not an IPv4 address
// [discovery.py:636] Restrict to private networks, and exclude loopback and link local
// [discovery.py:642] Constrain the size of network that will be searched
// [discovery.py:680] Not an IPv4 address
// [discovery.py:718] Try getting a device property
// [discovery.py:721] The exception is unimportant
// [discovery.py:722] pylint: disable=bare-except
// [discovery.py:723] noqa: E722
// [discovery.py:749] With large numbers of threads, we can exceed the file handle limit.
// [discovery.py:750] Put the address back on the list and drop out of this thread.
// [discovery.py:761] Clear the list to eliminate further searching by
// [discovery.py:762] all threads, if we're not doing an exhaustive search

// MARK: - Original commentary: events.py
// [events.py:1] module docstring:
// Classes to handle Sonos UPnP Events and Subscriptions.
// 
// The `Subscription` class from this module will be used in
// :py:mod:`soco.services` unless `config.EVENTS_MODULE` is set to
// point to :py:mod:`soco.events_twisted`, in which case
// :py:mod:`soco.events_twisted.Subscription` will be used.  See the
// Example in :py:mod:`soco.events_twisted`.
// 
// Example:
// 
//     Run this code, and change your volume, tracks etc::
// 
//         from queue import Empty
// 
//         import logging
//         logging.basicConfig()
//         import soco
//         from pprint import pprint
//         from soco.events import event_listener
//         # pick a device at random and use it to get
//         # the group coordinator
//         device = soco.discover().pop().group.coordinator
//         print (device.player_name)
//         sub = device.renderingControl.subscribe()
//         sub2 = device.avTransport.subscribe()
// 
//         while True:
//             try:
//                 event = sub.events.get(timeout=0.5)
//                 pprint (event.variables)
//             except Empty:
//                 pass
//             try:
//                 event = sub2.events.get(timeout=0.5)
//                 pprint (event.variables)
//             except Empty:
//                 pass
// 
//             except KeyboardInterrupt:
//                 sub.unsubscribe()
//                 sub2.unsubscribe()
//                 event_listener.stop()
//                 break
// 
//
// [events.py:80] EventServer docstring:
// A TCP server which handles each new request in a new thread.
//
// [events.py:86] EventNotifyHandler docstring:
// Handles HTTP ``NOTIFY`` Verbs sent to the listener server.
//     Inherits from `soco.events_base.EventNotifyHandlerBase`.
//     
//
// [events.py:99] EventNotifyHandler.do_NOTIFY docstring:
// Serve a ``NOTIFY`` request by calling `handle_notification`
//         with the headers and content.
//         
//
// [events.py:125] EventServerThread docstring:
// The thread in which the event listener server will run.
//
// [events.py:128] EventServerThread.__init__ docstring:
// 
//         Args:
//             address (tuple): The (ip, port) address on which the server
//                 should listen.
//         
//
// [events.py:141] EventServerThread.run docstring:
// Start the server
// 
//         Handling of requests is delegated to an instance of the
//         `EventNotifyHandler` class.
//         
//
// [events.py:152] EventServerThread.stop docstring:
// Stop the server.
//
// [events.py:157] EventListener docstring:
// The Event Listener.
// 
//     Runs an http server in a thread which is an endpoint for ``NOTIFY``
//     requests from Sonos devices. Inherits from
//     `soco.events_base.EventListenerBase`.
//     
//
// [events.py:170] EventListener.listen docstring:
// Start the event listener listening on the local machine at
//         port 1400 (default). If this port is unavailable, the
//         listener will attempt to listen on the next available port,
//         within a range of 100.
// 
//         Make sure that your firewall allows connections to this port.
// 
//         This method is called by `soco.events_base.EventListenerBase.start`
// 
//         Args:
//             ip_address (str): The local network interface on which the server
//                 should start listening.
//         Returns:
//             int: `requested_port_number`. Included for
//             compatibility with `soco.events_twisted.EventListener.listen`
// 
//         Note:
//             The port on which the event listener listens is configurable.
//             See `config.EVENT_LISTENER_PORT`
//         
//
// [events.py:215] EventListener.stop_listening docstring:
// Stop the listener.
//
// [events.py:235] Subscription docstring:
// A class representing the subscription to a UPnP event.
//     Inherits from `soco.events_base.SubscriptionBase`.
//     
//
// [events.py:240] Subscription.__init__ docstring:
// 
//         Args:
//             service (Service): The SoCo `Service` to which the subscription
//                  should be made.
//             event_queue (:class:`~queue.Queue`): A queue on which received
//                 events will be put. If not specified, a queue will be
//                 created and used.
//         
//
// [events.py:263] Subscription.subscribe docstring:
// Subscribe to the service.
// 
//         If requested_timeout is provided, a subscription valid for that number
//         of seconds will be requested, but not guaranteed. Check
//         `timeout` on return to find out what period of validity is
//         actually allocated.
// 
//         This method calls `events_base.SubscriptionBase.subscribe`.
// 
//         Note:
//             SoCo will try to unsubscribe any subscriptions which are still
//             subscribed on program termination, but it is good practice for
//             you to clean up by making sure that you call :meth:`unsubscribe`
//             yourself.
// 
//         Args:
//             requested_timeout(int, optional): The timeout to be requested.
//             auto_renew (bool, optional): If `True`, renew the subscription
//                 automatically shortly before timeout. Default `False`.
//             strict (bool, optional): If True and an Exception occurs during
//                 execution, the Exception will be raised or, if False, the
//                 Exception will be logged and the Subscription instance will be
//                 returned. Default `True`.
// 
//         Returns:
//             `Subscription`: The Subscription instance.
// 
//         
//
// [events.py:295] Subscription.renew docstring:
// renew(requested_timeout=None)
//         Renew the event subscription.
//         You should not try to renew a subscription which has been
//         unsubscribed, or once it has expired.
// 
//         This method calls `events_base.SubscriptionBase.renew`.
// 
//         Args:
//             requested_timeout (int, optional): The period for which a renewal
//                 request should be made. If None (the default), use the timeout
//                 requested on subscription.
//             is_autorenew (bool, optional): Whether this is an autorenewal.
//                 Default 'False'.
//             strict (bool, optional): If True and an Exception occurs during
//                 execution, the Exception will be raised or, if False, the
//                 Exception will be logged and the Subscription instance will be
//                 returned. Default `True`.
// 
//         Returns:
//             `Subscription`: The Subscription instance.
// 
//         
//
// [events.py:321] Subscription.unsubscribe docstring:
// unsubscribe()
//         Unsubscribe from the service's events.
//         Once unsubscribed, a Subscription instance should not be reused
// 
//         This method calls `events_base.SubscriptionBase.unsubscribe`.
// 
//         Args:
//             strict (bool, optional): If True and an Exception occurs during
//                 execution, the Exception will be raised or, if False, the
//                 Exception will be logged and the Subscription instance will be
//                 returned. Default `True`.
// 
//         Returns:
//             `Subscription`: The Subscription instance.
// 
//         
//
// [events.py:341] Subscription._auto_renew_start docstring:
// Starts the auto_renew thread.
//
// [events.py:344] Subscription._auto_renew_start.AutoRenewThread docstring:
// Used by the auto_renew code to renew a subscription from within
//             a thread.
//             
//
// [events.py:368] Subscription._auto_renew_cancel docstring:
// Cancels the auto_renew thread
//
// [events.py:373] Subscription._request docstring:
// Sends an HTTP request.
// 
//         Args:
//             method (str): 'SUBSCRIBE' or 'UNSUBSCRIBE'.
//             url (str): The full endpoint to which the request is being sent.
//             headers (dict): A dict of headers, each key and each value being
//                 of type `str`.
//             success (function): A function to be called if the
//                 request succeeds. The function will be called with a dict
//                 of response headers as its only parameter.
//             unconditional (function): An optional function to be called after
//                 the request is complete, regardless of its success. Takes
//                 no parameters.
// 
//         
//
// [events.py:409] Subscription._wrap docstring:
// This is a wrapper for `Subscription.subscribe`, `Subscription.renew`
//         and `Subscription.unsubscribe` which:
// 
//             * Returns the`Subscription` instance.
//             * If an Exception has occurred:
// 
//                 * Cancels the Subscription (unless the Exception was caused by
//                   a SoCoException upon subscribe).
//                 * On an autorenew, if the strict flag was set to False, calls
//                   the optional self.auto_renew_fail method with the
//                   Exception. This method needs to be threadsafe.
//                 * If the strict flag was set to True (the default), reraises
//                   the Exception or, if the strict flag was set to False, logs
//                   the Exception instead.
// 
//             * Calls the wrapped methods with a threading.Lock, to prevent race
//               conditions (e.g. to prevent unsubscribe and autorenew being
//               called simultaneously).
// 
//         
//
// [events.py:1] pylint: disable=not-context-manager
// [events.py:3] NOTE: The pylint not-content-manager warning is disabled pending the fix of
// [events.py:4] a bug in pylint. See https://github.com/PyCQA/pylint/issues/782
// [events.py:64] Event is imported so that 'from events import Events' still works
// [events.py:65] pylint: disable=unused-import
// [events.py:66] noqa: F401
// [events.py:77] pylint: disable=C0103
// [events.py:92] The SubscriptionsMap instance created when this module is imported.
// [events.py:93] This is referenced by soco.events_base.EventNotifyHandlerBase.
// [events.py:95] super appears at the end of __init__, because
// [events.py:96] BaseHTTPRequestHandler.__init__ does not return.
// [events.py:99] pylint: disable=invalid-name
// [events.py:110] pylint: disable=no-self-use, missing-docstring
// [events.py:120] pylint: disable=arguments-differ
// [events.py:121] Divert standard webserver logging to the debug log
// [events.py:135] : `threading.Event`: Used to signal that the server should stop.
// [events.py:137] : `tuple`: The (ip, port) address on which the server is
// [events.py:138] : configured to listen.
// [events.py:148] Listen for events until told to stop
// [events.py:167] : `EventServerThread`: thread on which to run.
// [events.py:217] Signal the thread to stop before handling the next request
// [events.py:219] Send a dummy request in case the http server is currently listening
// [events.py:221] pylint: disable=R1732
// [events.py:224] If the server is already shut down, we receive a socket error,
// [events.py:225] which we ignore.
// [events.py:227] wait for the thread to finish, with a timeout of one second
// [events.py:228] to ensure the main thread does not hang
// [events.py:230] check if join timed out and issue a warning if it did
// [events.py:250] Used to keep track of the auto_renew thread
// [events.py:253] The SubscriptionsMap instance created when this module is imported.
// [events.py:254] This is referenced by soco.events_base.SubscriptionBase.
// [events.py:256] The EventListener instance created when this module is imported.
// [events.py:257] This is referenced by soco.events_base.SubscriptionBase.
// [events.py:259] Used to stop race conditions, as autorenewal may occur from a thread
// [events.py:262] pylint: disable=arguments-differ
// [events.py:372] pylint: disable=no-self-use
// [events.py:393] Ignore timeout for unsubscribe since we are leaving anyway.
// [events.py:397] Ignore "412 Client Error: Precondition Failed for url:" from
// [events.py:398] rebooted speakers. The reboot will have unsubscribed us which is
// [events.py:399] what we are trying to do.
// [events.py:408] pylint: disable=inconsistent-return-statements
// [events.py:433] A lock is used, because autorenewal occurs in
// [events.py:434] a thread
// [events.py:439] pylint: disable=broad-except
// [events.py:440] If an Exception occurred during execution of subscribe,
// [events.py:441] renew or unsubscribe, set the cancel flag to True unless
// [events.py:442] the Exception was a SoCoException upon subscribe
// [events.py:446] If the cancel flag was set to true, cancel the
// [events.py:447] subscription with an explanation.
// [events.py:456] If we're not being strict, log the Exception
// [events.py:467] If we're not being strict upon a renewal
// [events.py:468] (e.g. an autorenewal) call the optional
// [events.py:469] self.auto_renew_fail method, if it has been set
// [events.py:472] pylint: disable=not-callable
// [events.py:475] If we're being strict, reraise the Exception
// [events.py:477] pylint: disable=raising-bad-type
// [events.py:480] Return the Subscription to the function that
// [events.py:481] called subscribe, renew or unsubscribe (unless an
// [events.py:482] Exception occurred and it was reraised above)
// [events.py:483] pylint: disable=lost-exception
// [events.py:486] pylint: disable=C0103
// [events.py:487] pylint: disable=C0103

// MARK: - Original commentary: events_asyncio.py
// [events_asyncio.py:1] module docstring:
// Classes to handle Sonos UPnP Events and Subscriptions using asyncio.
// 
// The `Subscription` class from this module will be used in
// :py:mod:`soco.services` if `config.EVENTS_MODULE` is set
// to point to this module.
// 
// Example:
// 
//     Run this code, and change your volume, tracks etc::
// 
//         import logging
// 
//         logging.basicConfig()
//         import soco
//         import asyncio
//         from pprint import pprint
// 
//         from soco import events_asyncio
// 
//         soco.config.EVENTS_MODULE = events_asyncio
// 
// 
//         def print_event(event):
//             try:
//                 pprint(event.variables)
//             except Exception as e:
//                 print("There was an error in print_event:", e)
// 
// 
//         def _get_device():
//             device = soco.discover().pop().group.coordinator
//             print(device.player_name)
//             return device
// 
// 
//         async def main():
//             # pick a device at random and use it to get
//             # the group coordinator
//             loop = asyncio.get_event_loop()
//             device = await loop.run_in_executor(None, _get_device)
//             sub = await device.renderingControl.subscribe()
//             sub2 = await device.avTransport.subscribe()
//             sub.callback = print_event
//             sub2.callback = print_event
// 
//             async def before_shutdown():
//                 await sub.unsubscribe()
//                 await sub2.unsubscribe()
//                 await events_asyncio.event_listener.async_stop()
// 
//             await asyncio.sleep(1)
//             print("Renewing subscription..")
//             await sub.renew()
// 
//             await asyncio.sleep(100)
//             await before_shutdown()
// 
// 
//         if __name__ == "__main__":
//             asyncio.run(main())
// 
//
// [events_asyncio.py:99] EventNotifyHandler docstring:
// Handles HTTP ``NOTIFY`` Verbs sent to the listener server.
//     Inherits from `soco.events_base.EventNotifyHandlerBase`.
//     
//
// [events_asyncio.py:111] EventNotifyHandler.notify docstring:
// Serve a ``NOTIFY`` request by calling `handle_notification`
//         with the headers and content.
//         
//
// [events_asyncio.py:163] EventListener docstring:
// The Event Listener.
// 
//     Runs an http server which is an endpoint for ``NOTIFY``
//     requests from Sonos devices. Inherits from
//     `soco.events_base.EventListenerBase`.
//     
//
// [events_asyncio.py:196] EventListener.start docstring:
// A stub since the first subscribe calls async_start.
//
// [events_asyncio.py:200] EventListener.listen docstring:
// A stub since async_listen is used.
//
// [events_asyncio.py:204] EventListener.async_start docstring:
// Start the event listener listening on the local machine under the lock.
// 
//         Args:
//             any_zone (SoCo): Any Sonos device on the network. It does not
//                 matter which device. It is used only to find a local IP
//                 address reachable by the Sonos net.
// 
//         
//
// [events_asyncio.py:250] EventListener.async_listen docstring:
// Start the event listener listening on the local machine at
//         port 1400 (default). If this port is unavailable, the
//         listener will attempt to listen on the next available port,
//         within a range of 100.
// 
//         Make sure that your firewall allows connections to this port.
// 
//         This method is called by `soco.events_base.EventListenerBase.start`
// 
//         Handling of requests is delegated to an instance of the
//         `EventNotifyHandler` class.
// 
//         Args:
//             ip_address (str): The local network interface on which the server
//                 should start listening.
//         Returns:
//             int: The port on which the server is listening.
// 
//         Note:
//             The port on which the event listener listens is configurable.
//             See `config.EVENT_LISTENER_PORT`
//         
//
// [events_asyncio.py:298] EventListener._async_start docstring:
// Start the site.
//
// [events_asyncio.py:309] EventListener.async_stop docstring:
// Stop the listener immediately. Idempotent and concurrency-safe.
// 
//         This is the prompt-shutdown path: resources are closed before the
//         coroutine returns. Callers that want a deterministic teardown at
//         process exit should ``await event_listener.async_stop()``
//         directly; ``stop_listening()`` defers teardown by
//         ``_stop_grace_seconds`` (default 5 s) to support
//         unsubscribe→resubscribe reuse.
// 
//         Snapshots the runtime resources locally and clears the instance
//         attributes inside ``stop_lock``, then closes the snapshots
//         outside the lock. This way a concurrent ``async_start`` never
//         observes a half-torn-down listener, and a second overlapping
//         ``async_stop`` call sees the cleared attrs and returns early.
//         
//
// [events_asyncio.py:370] EventListener._deferred_stop docstring:
// Sleep the grace window; stop only if no resubscribe arrived.
//
// [events_asyncio.py:382] EventListener.stop_listening docstring:
// Stop the listener after a short grace window.
// 
//         Called by ``EventListenerBase.stop()`` when the last subscription
//         is removed. Schedules teardown via ``_deferred_stop`` rather than
//         tearing down immediately: a resubscribe inside the grace window
//         (``_stop_grace_seconds``, default 5 s) cancels the pending stop,
//         so the underlying HTTP server stays up across the
//         unsubscribe→resubscribe cycle. Eliminates teardown/rebuild churn
//         (and the FD races that follow) on every renew.
// 
//         Behaviour notes for callers:
// 
//         * Resources are **not** released by the time this method returns
//           — the deferred task runs ``_stop_grace_seconds`` later.
//         * Consumers that subscribe once and exit (no resubscribe) will
//           see resources released ~``_stop_grace_seconds`` after the last
//           ``unsubscribe()``. For deterministic prompt shutdown at process
//           exit, call ``await event_listener.async_stop()`` directly.
//         * Each call replaces any prior pending stop with a fresh timer,
//           so rapid consecutive ``stop_listening()`` calls coalesce into
//           a single deferred teardown.
//         
//
// [events_asyncio.py:421] Subscription docstring:
// A class representing the subscription to a UPnP event.
//     Inherits from `soco.events_base.SubscriptionBase`.
//     
//
// [events_asyncio.py:426] Subscription.__init__ docstring:
// 
//         Args:
//             service (Service): The SoCo `Service` to which the subscription
//                  should be made.
//             event_queue (:class:`~queue.Queue`): A queue on which received
//                 events will be put. If not specified, a queue will be
//                 created and used.
// 
//         
//
// [events_asyncio.py:452] Subscription.subscribe docstring:
// Subscribe to the service.
// 
//         If requested_timeout is provided, a subscription valid for that number
//         of seconds will be requested, but not guaranteed. Check
//         `timeout` on return to find out what period of validity is
//         actually allocated.
// 
//         This method calls `events_base.SubscriptionBase.subscribe`.
// 
//         Note:
//             SoCo will try to unsubscribe any subscriptions which are still
//             subscribed on program termination, but it is good practice for
//             you to clean up by making sure that you call :meth:`unsubscribe`
//             yourself.
// 
//         Args:
//             requested_timeout(int, optional): The timeout to be requested.
//             auto_renew (bool, optional): If `True`, renew the subscription
//                 automatically shortly before timeout. Default `False`.
//             strict (bool, optional): If True and an Exception occurs during
//                 execution, the Exception will be raised or, if False, the
//                 Exception will be logged and the Subscription instance will be
//                 returned. Default `True`.
// 
//         Returns:
//             `Subscription`: The Subscription instance.
// 
//         
//
// [events_asyncio.py:506] Subscription._log_exception docstring:
// Log an exception during subscription.
//
// [events_asyncio.py:517] Subscription.renew docstring:
// renew(requested_timeout=None)
//         Renew the event subscription.
//         You should not try to renew a subscription which has been
//         unsubscribed, or once it has expired.
// 
//         This method calls `events_base.SubscriptionBase.renew`.
// 
//         Args:
//             requested_timeout (int, optional): The period for which a renewal
//                 request should be made. If None (the default), use the timeout
//                 requested on subscription.
//             is_autorenew (bool, optional): Whether this is an autorenewal.
//                 Default `False`.
//             strict (bool, optional): If True and an Exception occurs during
//                 execution, the Exception will be raised or, if False, the
//                 Exception will be logged and the Subscription instance will be
//                 returned. Default `True`.
// 
//         Returns:
//             `Subscription`: The Subscription instance.
// 
//         
//
// [events_asyncio.py:557] Subscription.unsubscribe docstring:
// unsubscribe()
//         Unsubscribe from the service's events.
//         Once unsubscribed, a Subscription instance should not be reused
// 
//         This method calls `events_base.SubscriptionBase.unsubscribe`.
// 
//         Args:
//             strict (bool, optional): If True and an Exception occurs during
//                 execution, the Exception will be raised or, if False, the
//                 Exception will be logged and the Subscription instance will be
//                 returned. Default `True`.
// 
//         Returns:
//             `Subscription`: The Subscription instance.
//         
//
// [events_asyncio.py:587] Subscription._auto_renew_start docstring:
// Starts the auto_renew loop.
//
// [events_asyncio.py:597] Subscription._auto_renew_cancel docstring:
// Cancels the auto_renew loop
//
// [events_asyncio.py:604] Subscription._request docstring:
// Sends an HTTP request.
// 
//         Args:
//             method (str): 'SUBSCRIBE' or 'UNSUBSCRIBE'.
//             url (str): The full endpoint to which the request is being sent.
//             headers (dict): A dict of headers, each key and each value being
//                 of type `str`.
//             success (function): A function to be called if the
//                 request succeeds. The function will be called with a dict
//                 of response headers as its only parameter.
//             unconditional (function): An optional function to be called after
//                 the request is complete, regardless of its success. Takes
//                 no parameters.
// 
//         
//
// [events_asyncio.py:633] nullcontext docstring:
// Context manager that does no additional processing.
// 
//     Backport from python 3.7+ for older pythons.
//     
//
// [events_asyncio.py:649] SubscriptionsMapAio docstring:
// Maintains a mapping of sids to `soco.events_asyncio.Subscription`
//     instances. Registers each subscription to be unsubscribed at exit.
// 
//     Inherits from `soco.events_base.SubscriptionsMap`.
//     
//
// [events_asyncio.py:664] SubscriptionsMapAio.register docstring:
// Register a subscription by updating local mapping of sid to
//         subscription and registering it to be unsubscribed at exit.
// 
//         Args:
//             subscription(`soco.events_asyncio.Subscription`): the subscription
//                 to be registered.
// 
//         
//
// [events_asyncio.py:678] SubscriptionsMapAio.subscribing docstring:
// Called when the `Subscription.subscribe` method
//         commences execution.
//         
//
// [events_asyncio.py:685] SubscriptionsMapAio.finished_subscribing docstring:
// Called when the `Subscription.subscribe` method
//         completes execution.
//         
//
// [events_asyncio.py:693] SubscriptionsMapAio.count docstring:
// 
//         `int`: The number of active or pending subscriptions.
//         
//
// [events_asyncio.py:81] Event is imported for compatibility with events.py
// [events_asyncio.py:82] pylint: disable=unused-import
// [events_asyncio.py:83] noqa: F401
// [events_asyncio.py:85] noqa: E402
// [events_asyncio.py:94] noqa: E402
// [events_asyncio.py:96] pylint: disable=C0103
// [events_asyncio.py:106] The SubscriptionsMapAio instance created when this module is
// [events_asyncio.py:107] imported. This is referenced by
// [events_asyncio.py:108] soco.events_base.EventNotifyHandlerBase.
// [events_asyncio.py:116] Event sequence number
// [events_asyncio.py:117] Event Subscription Identifier
// [events_asyncio.py:118] find the relevant service from the sid
// [events_asyncio.py:119] pylint: disable=no-member
// [events_asyncio.py:121] It might have been removed by another thread
// [events_asyncio.py:128] parse_event_xml will generate I/O if
// [events_asyncio.py:129] x-sonos-http is in the content
// [events_asyncio.py:137] Pass ZGS payload to associated SoCo instance to update
// [events_asyncio.py:138] attributes. Keeps cache warm and avoids network calls.
// [events_asyncio.py:145] Build the Event object
// [events_asyncio.py:147] pass the event details on to the service so it can update
// [events_asyncio.py:148] its cache.
// [events_asyncio.py:149] pylint: disable=protected-access
// [events_asyncio.py:151] Pass the event on for handling
// [events_asyncio.py:158] pylint: disable=no-self-use, missing-docstring
// [events_asyncio.py:180] async_stop is serialized via stop_lock so overlapping callers
// [events_asyncio.py:181] don't double-close the same resources.
// [events_asyncio.py:183] stop_listening() schedules a deferred teardown via this task.
// [events_asyncio.py:184] A resubscribe within the grace window cancels the task and
// [events_asyncio.py:185] reuses the existing HTTP server, eliminating the
// [events_asyncio.py:186] teardown/rebuild churn (and FD races) on every renew cycle.
// [events_asyncio.py:188] Grace window (seconds) between stop_listening() being called
// [events_asyncio.py:189] and the deferred async_stop() actually running. Intentionally
// [events_asyncio.py:190] an instance attribute so consumers and tests can tune it
// [events_asyncio.py:191] (e.g. shorten for fast unit tests, lengthen for noisy
// [events_asyncio.py:192] resubscribe patterns). 5 s is the default; values < 0 are
// [events_asyncio.py:193] treated as "stop immediately on next event-loop tick".
// [events_asyncio.py:216] If a deferred stop is pending from a recent stop_listening(),
// [events_asyncio.py:217] cancel it — the caller wants the listener up. If the runtime
// [events_asyncio.py:218] resources are still alive (the grace window has not yet
// [events_asyncio.py:219] expired), the listener can simply resume.
// [events_asyncio.py:234] Use configured IP address if there is one, else detect
// [events_asyncio.py:235] automatically.
// [events_asyncio.py:239] Otherwise, no point trying to start server
// [events_asyncio.py:279] pylint: disable=no-member
// [events_asyncio.py:286] pylint: disable=invalid-name
// [events_asyncio.py:335] Already stopped (or never started) — nothing to do.
// [events_asyncio.py:345] Tear down outside the lock; tolerate already-closed state.
// [events_asyncio.py:350] aiohttp's SockSite.stop() ultimately calls
// [events_asyncio.py:351] loop._stop_serving(sock), which raises ValueError on a
// [events_asyncio.py:352] closed fd. Tolerate and continue cleanup.
// [events_asyncio.py:357] pylint: disable=broad-except
// [events_asyncio.py:362] pylint: disable=broad-except
// [events_asyncio.py:381] pylint: disable=unused-argument
// [events_asyncio.py:406] Replace any prior pending stop with a fresh timer.
// [events_asyncio.py:415] pylint: disable=broad-except
// [events_asyncio.py:437] : :py:obj:`function`: callback function to be called whenever an
// [events_asyncio.py:438] : `Event` is received. If it is set and is callable, the callback
// [events_asyncio.py:439] : function will be called with the `Event` as the only parameter and
// [events_asyncio.py:440] : the Subscription's event queue won't be used.
// [events_asyncio.py:442] The SubscriptionsMapAio instance created when this module is
// [events_asyncio.py:443] imported. This is referenced by soco.events_base.SubscriptionBase.
// [events_asyncio.py:445] The EventListener instance created when this module is imported.
// [events_asyncio.py:446] This is referenced by soco.events_base.SubscriptionBase.
// [events_asyncio.py:448] Used to keep track of the auto_renew loop
// [events_asyncio.py:451] pylint: disable=arguments-differ
// [events_asyncio.py:493] pylint: disable=broad-except
// [events_asyncio.py:519] pylint: disable=invalid-overridden-method
// [events_asyncio.py:544] pylint: disable=broad-except
// [events_asyncio.py:549] pylint: disable=not-callable
// [events_asyncio.py:559] pylint: disable=invalid-overridden-method
// [events_asyncio.py:580] pylint: disable=broad-except
// [events_asyncio.py:603] pylint: disable=no-self-use
// [events_asyncio.py:633] pylint: disable=invalid-name
// [events_asyncio.py:658] A counter of calls to Subscription.subscribe
// [events_asyncio.py:659] that have started but not completed. This is
// [events_asyncio.py:660] to prevent the event listener from being stopped prematurely
// [events_asyncio.py:674] Add the subscription to the local dict of subscriptions so it
// [events_asyncio.py:675] can be looked up by sid
// [events_asyncio.py:682] Increment the counter
// [events_asyncio.py:689] Decrement the counter
// [events_asyncio.py:700] pylint: disable=C0103
// [events_asyncio.py:701] pylint: disable=C0103

// MARK: - Original commentary: events_base.py
// [events_base.py:1] module docstring:
// Base classes used by :py:mod:`soco.events` and
// :py:mod:`soco.events_twisted`.
//
// [events_base.py:29] parse_event_xml docstring:
// Parse the body of a UPnP event.
// 
//     Args:
//         xml_event (bytes): bytes containing the body of the event encoded
//             with utf-8.
// 
//     Returns:
//         dict: A dict with keys representing the evented variables. The
//         relevant value will usually be a string representation of the
//         variable's value, but may on occasion be:
// 
//         * a dict (eg when the volume changes, the value will itself be a
//           dict containing the volume for each channel:
//           :code:`{'Volume': {'LF': '100', 'RF': '100', 'Master': '36'}}`)
//         * an instance of a `DidlObject` subclass (eg if it represents
//           track metadata).
//         * a `SoCoFault` (if a variable contains illegal metadata)
//     
//
// [events_base.py:129] Event docstring:
// A read-only object representing a received event.
// 
//     The values of the evented variables can be accessed via the ``variables``
//     dict, or as attributes on the instance itself. You should treat all
//     attributes as read-only.
// 
//     Args:
//         sid (str): the subscription id.
//         seq (str): the event sequence number for that subscription.
//         timestamp (str): the time that the event was received (from Python's
//             `time.time` function).
//         service (str): the service which is subscribed to the event.
//         variables (dict, optional): contains the ``{names: values}`` of the
//             evented variables. Defaults to `None`. The values may be
//             `SoCoFault` objects if the metadata could not be parsed.
// 
//     Raises:
//         AttributeError:  Not all attributes are returned with each event. An
//             `AttributeError` will be raised if you attempt to access as an
//             attribute a variable which was not returned in the event.
// 
//     Example:
// 
//         >>> print event.variables['transport_state']
//         'STOPPED'
//         >>> print event.transport_state
//         'STOPPED'
// 
//     
//
// [events_base.py:175] Event.__setattr__ docstring:
// Disable (most) attempts to set attributes.
// 
//         This is not completely foolproof. It just acts as a warning! See
//         `object.__setattr__`.
//         
//
// [events_base.py:184] EventNotifyHandlerBase docstring:
// Base class for `soco.events.EventNotifyHandler` and
//     `soco.events_twisted.EventNotifyHandler`.
//     
//
// [events_base.py:189] EventNotifyHandlerBase.handle_notification docstring:
// Handle a ``NOTIFY`` request by building an `Event` object and
//         sending it to the relevant Subscription object.
// 
//         A ``NOTIFY`` request will be sent by a Sonos device when a state
//         variable changes. See the `UPnP Spec §4.3 [pdf]
//         <http://upnp.org/specs/arch/UPnP-arch
//         -DeviceArchitecture-v1.1.pdf>`_  for details.
// 
//         Args:
//             headers (dict): A dict of received headers.
//             content (str): A string of received content.
//         Note:
//             Each of the :py:mod:`soco.events` and the
//             :py:mod:`soco.events_twisted` modules has a **subscriptions_map**
//             object which keeps a record of Subscription objects. The
//             *get_subscription* method of the **subscriptions_map** object is
//             used to look up the subscription to which the event relates. When
//             the Event Listener runs in a thread (the default), a lock is
//             used by this method for thread safety. The *send_event*
//             method of the relevant Subscription will first check to see
//             whether the *callback* variable of the Subscription has been
//             set. If it has been and is callable, then the *callback*
//             will be called with the `Event` object. Otherwise, the `Event`
//             object will be sent to the event queue of the Subscription
//             object. The *callback* variable of the Subscription object is
//             intended for use only if :py:mod:`soco.events_twisted` is being
//             used, as calls to it are not threadsafe.
// 
//             This method calls the log_event method, which must be overridden
//             in the class that inherits from this class.
//         
//
// [events_base.py:250] EventListenerBase docstring:
// Base class for `soco.events.EventListener` and
//     `soco.events_twisted.EventListener`.
//     
//
// [events_base.py:266] EventListenerBase.start docstring:
// Start the event listener listening on the local machine.
// 
//         Args:
//             any_zone (SoCo): Any Sonos device on the network. It does not
//                 matter which device. It is used only to find a local IP
//                 address reachable by the Sonos net.
// 
//         
//
// [events_base.py:295] EventListenerBase.stop docstring:
// Stop the Event Listener.
//
// [events_base.py:304] EventListenerBase.listen docstring:
// Start the event listener listening on the local machine.
//         This method is called by `start`.
// 
//         Args:
//             ip_address (str): The local network interface on which the server
//                 should start listening.
//         Returns:
//             int: The port on which the server is listening.
// 
//         Note:
//             This method must be overridden in the class that inherits from
//             this class.
//         
//
// [events_base.py:321] EventListenerBase.stop_listening docstring:
// Stop the listener.
// 
//         Note:
//             This method must be overridden in the class that inherits from
//             this class.
//         
//
// [events_base.py:331] SubscriptionBase docstring:
// Base class for `soco.events.Subscription` and
//     `soco.events_twisted.Subscription`
//     
//
// [events_base.py:336] SubscriptionBase.__init__ docstring:
// 
//         Args:
//             service (Service): The SoCo `Service` to which the subscription
//                  should be made.
//             event_queue (:class:`~queue.Queue`): A queue on which received
//                 events will be put. If not specified, a queue will be
//                 created and used.
//         
//
// [events_base.py:368] SubscriptionBase.subscribe docstring:
// Subscribe to the service.
// 
//         If requested_timeout is provided, a subscription valid for that number
//         of seconds will be requested, but not guaranteed. Check
//         `timeout` on return to find out what period of validity is
//         actually allocated.
// 
//         Note:
//             SoCo will try to unsubscribe any subscriptions which are still
//             subscribed on program termination, but it is good practice for
//             you to clean up by making sure that you call :meth:`unsubscribe`
//             yourself.
// 
//         Args:
//             requested_timeout(int, optional): The timeout to be requested.
//             auto_renew (bool, optional): If `True`, renew the subscription
//                 automatically shortly before timeout. Default `False`.
// 
//         
//
// [events_base.py:470] SubscriptionBase.renew docstring:
// renew(requested_timeout=None)
//         Renew the event subscription.
//         You should not try to renew a subscription which has been
//         unsubscribed, or once it has expired.
// 
//         Args:
//             requested_timeout (int, optional): The period for which a renewal
//                 request should be made. If None (the default), use the timeout
//                 requested on subscription.
//             is_autorenew (bool, optional): Whether this is an autorenewal.
// 
//         
//
// [events_base.py:534] SubscriptionBase.unsubscribe docstring:
// unsubscribe()
//         Unsubscribe from the service's events.
//         Once unsubscribed, a Subscription instance should not be reused
//         
//
// [events_base.py:571] SubscriptionBase.send_event docstring:
// Send an `Event` to self.callback or self.events.
//         If self.callback is set and is callable, it will be called with the
//         `Event` as the only parameter. Otherwise the `Event` will be sent to
//         self.events. As self.callback is not threadsafe, it should be set
//         only if `soco.events_twisted.Subscription` is being used.
// 
//         Args:
//             event(Event): The `Event` to send to self.callback or
//                 self.events.
// 
//         
//
// [events_base.py:598] SubscriptionBase._auto_renew_start docstring:
// Starts the auto_renew thread.
// 
//         Note:
//             This method must be overridden in the class that inherits from
//             this class.
//         
//
// [events_base.py:608] SubscriptionBase._auto_renew_cancel docstring:
// Cancels the auto_renew thread.
// 
//         Note:
//             This method must be overridden in the class that inherits from
//             this class.
//         
//
// [events_base.py:618] SubscriptionBase._request docstring:
// Send a HTTP request
// 
//         Args:
//             method (str): 'SUBSCRIBE' or 'UNSUBSCRIBE'.
//             url (str): The full endpoint to which the request is being sent.
//             headers (dict): A dict of headers, each key and each value being
//                 of type `str`.
//             success (function): A function to be called if the
//                 request succeeds. The function will be called with a dict
//                 of response headers as its only parameter.
//             unconditional (function): An optional function to be called after
//                 the request is complete, regardless of its success. Takes
//                 no parameters.
// 
//         Note:
//             This method must be overridden in the class that inherits from
//             this class.
//         
//
// [events_base.py:663] SubscriptionBase.time_left docstring:
// 
//         `int`: The amount of time left until the subscription expires (seconds)
//         If the subscription is unsubscribed (or not yet subscribed),
//         `time_left` is 0.
//         
//
// [events_base.py:684] SubscriptionsMap docstring:
// Maintains a mapping of sids to `soco.events.Subscription` instances
//     and the thread safe lock to go with it. Registers each subscription to
//     be unsubscribed at exit.
// 
//     `SubscriptionsMapTwisted` inherits from this class.
// 
//     
//
// [events_base.py:706] SubscriptionsMap.register docstring:
// Register a subscription by updating local mapping of sid to
//         subscription and registering it to be unsubscribed at exit.
// 
//         Args:
//             subscription(`soco.events.Subscription`): the subscription
//                 to be registered.
// 
//         
//
// [events_base.py:725] SubscriptionsMap.unregister docstring:
// Unregister a subscription by updating local mapping of sid to
//         subscription instances.
// 
//         Args:
//             subscription(`soco.events.Subscription`): the subscription
//                 to be unregistered.
// 
//         When using :py:mod:`soco.events_twisted`, an instance of
//         `soco.events_twisted.Subscription` will be unregistered.
// 
//         
//
// [events_base.py:743] SubscriptionsMap.get_subscription docstring:
// Look up a subscription from a sid.
// 
//             Args:
//                 sid(str): The sid from which to look up the subscription.
// 
//             Returns:
//                 `soco.events.Subscription`: The subscription relating
//                 to that sid.
// 
//         When using :py:mod:`soco.events_twisted`, an instance of
//         `soco.events_twisted.Subscription` will be returned.
// 
//         
//
// [events_base.py:761] SubscriptionsMap.count docstring:
// 
//         `int`: The number of active subscriptions.
//         
//
// [events_base.py:769] get_listen_ip docstring:
// Find the listen ip address.
//
// [events_base.py:1] pylint: disable=not-context-manager
// [events_base.py:3] NOTE: The pylint not-content-manager warning is disabled pending the fix of
// [events_base.py:4] a bug in pylint. See https://github.com/PyCQA/pylint/issues/782
// [events_base.py:25] pylint: disable=C0103
// [events_base.py:51] property values are just under the propertyset, which
// [events_base.py:52] uses this namespace
// [events_base.py:54] pylint: disable=too-many-nested-blocks
// [events_base.py:56] Special handling for a LastChange event specially. For details on
// [events_base.py:57] LastChange events, see
// [events_base.py:58] http://upnp.org/specs/av/UPnP-av-RenderingControl-v1-Service.pdf
// [events_base.py:59] and http://upnp.org/specs/av/UPnP-av-AVTransport-v1-Service.pdf
// [events_base.py:62] We assume there is only one InstanceID tag. This is true for
// [events_base.py:63] Sonos, as far as we know.
// [events_base.py:64] InstanceID can be in one of two namespaces, depending on
// [events_base.py:65] whether we are looking at an avTransport event, a
// [events_base.py:66] renderingControl event, or a Queue event
// [events_base.py:67] (there, it is named QueueID)
// [events_base.py:79] Look at each variable within the LastChange event
// [events_base.py:82] Remove any namespaces from the tags
// [events_base.py:85] Un-camel case it
// [events_base.py:87] Now extract the relevant value for the variable.
// [events_base.py:88] The UPnP specs suggest that the value of any variable
// [events_base.py:89] evented via a LastChange Event will be in the 'val'
// [events_base.py:90] attribute, but audio related variables may also have a
// [events_base.py:91] 'channel' attribute. In addition, it seems that Sonos
// [events_base.py:92] sometimes uses a text value instead: see
// [events_base.py:93] http://forums.sonos.com/showthread.php?t=34663
// [events_base.py:97] If DIDL metadata is returned, convert it to a music
// [events_base.py:98] library data structure
// [events_base.py:100] Wrap any parsing exception in a SoCoFault, so the
// [events_base.py:101] user can handle it
// [events_base.py:161] Initialisation has to be done like this, because __setattr__ is
// [events_base.py:162] overridden, and will not allow direct setting of attributes
// [events_base.py:223] Event sequence number
// [events_base.py:224] Event Subscription Identifier
// [events_base.py:225] find the relevant service from the sid
// [events_base.py:226] pylint: disable=no-member
// [events_base.py:228] It might have been removed by another thread
// [events_base.py:234] Build the Event object
// [events_base.py:236] pass the event details on to the service so it can update
// [events_base.py:237] its cache.
// [events_base.py:238] pylint: disable=protected-access
// [events_base.py:240] Pass the event on for handling
// [events_base.py:245] pylint: disable=missing-docstring
// [events_base.py:256] : `bool`: Indicates whether the server is currently running
// [events_base.py:259] : `tuple`: The address (ip, port) on which the server is
// [events_base.py:260] : configured to listen.
// [events_base.py:261] Empty for the moment. (It is set in `start`)
// [events_base.py:263] : `int`: Port on which to listen.
// [events_base.py:276] Find our local network IP address which is accessible to the
// [events_base.py:277] Sonos net, see http://stackoverflow.com/q/166506
// [events_base.py:281] Use configured IP address if there is one, else detect
// [events_base.py:282] automatically.
// [events_base.py:286] Otherwise, no point trying to start server
// [events_base.py:303] pylint: disable=missing-docstring
// [events_base.py:320] pylint: disable=missing-docstring
// [events_base.py:346] : `str`: A unique ID for this subscription
// [events_base.py:348] : `int`: The amount of time in seconds until the subscription expires.
// [events_base.py:350] : `bool`: An indication of whether the subscription is subscribed.
// [events_base.py:352] : :class:`~queue.Queue`: The queue on which events are placed.
// [events_base.py:354] : `int`: The period (seconds) for which the subscription is requested
// [events_base.py:356] : :py:obj:`function`: an optional function to be called if an
// [events_base.py:357] : exception occurs upon autorenewal. This will be called with the
// [events_base.py:358] : exception (or failure, when using :py:mod:`soco.events_twisted`)
// [events_base.py:359] : as its only parameter. This function must be threadsafe (unless
// [events_base.py:360] : :py:mod:`soco.events_twisted` is being used).
// [events_base.py:362] A flag to make sure that an unsubscribed instance is not
// [events_base.py:363] resubscribed
// [events_base.py:365] The time when the subscription was made
// [events_base.py:389] TIMEOUT is provided for in the UPnP spec, but it is not clear if
// [events_base.py:390] Sonos pays any attention to it. A timeout of 86400 secs always seems
// [events_base.py:391] to be allocated
// [events_base.py:403] The Event Listener must be running, so start it if not
// [events_base.py:404] pylint: disable=no-member
// [events_base.py:407] an event subscription looks like this:
// [events_base.py:408] SUBSCRIBE publisher path HTTP/1.1
// [events_base.py:409] HOST: publisher host:publisher port
// [events_base.py:410] CALLBACK: <delivery URL>
// [events_base.py:411] NT: upnp:event
// [events_base.py:412] TIMEOUT: Second-requested subscription duration (optional)
// [events_base.py:414] pylint: disable=unbalanced-tuple-unpacking
// [events_base.py:427] pylint: disable=missing-docstring
// [events_base.py:431] According to the spec, timeout can be "infinite" or "second-123"
// [events_base.py:432] where 123 is a number of seconds.  Sonos uses "Second-123"
// [events_base.py:433] (with a capital letter)
// [events_base.py:446] Register the subscription so it can be looked up by sid
// [events_base.py:447] and unsubscribed at exit
// [events_base.py:450] Set up auto_renew
// [events_base.py:453] Autorenew just before expiry, say at 85% of self.timeout seconds
// [events_base.py:457] Lock out EventNotifyHandler during registration.
// [events_base.py:458] If events_twisted is used, this lock should always be
// [events_base.py:459] available, since threading is not being used. This is to prevent
// [events_base.py:460] the EventNotifyHandler from sending a notification before the
// [events_base.py:461] subscription has been registered.
// [events_base.py:483] NB This code may be called from a separate thread when
// [events_base.py:484] subscriptions are auto-renewed. Be careful to ensure thread-safety
// [events_base.py:499] SUBSCRIBE publisher path HTTP/1.1
// [events_base.py:500] HOST: publisher host:publisher port
// [events_base.py:501] SID: uuid:subscription UUID
// [events_base.py:502] TIMEOUT: Second-requested subscription duration (optional)
// [events_base.py:509] pylint: disable=missing-docstring
// [events_base.py:512] According to the spec, timeout can be "infinite" or "second-123"
// [events_base.py:513] where 123 is a number of seconds.  Sonos uses "Second-123"
// [events_base.py:514] (with a capital letter)
// [events_base.py:539] Trying to unsubscribe if already unsubscribed, or not yet
// [events_base.py:540] subscribed, fails silently
// [events_base.py:544] If the subscription has timed out, an attempt to
// [events_base.py:545] unsubscribe from it will fail silently.
// [events_base.py:549] Send an unsubscribe request like this:
// [events_base.py:550] UNSUBSCRIBE publisher path HTTP/1.1
// [events_base.py:551] HOST: publisher host:publisher port
// [events_base.py:552] SID: uuid:subscription UUID
// [events_base.py:555] pylint: disable=missing-docstring, unused-argument
// [events_base.py:584] pylint: disable=no-member
// [events_base.py:593] pylint: disable=broad-except
// [events_base.py:597] pylint: disable=missing-docstring
// [events_base.py:607] pylint: disable=missing-docstring
// [events_base.py:617] pylint: disable=missing-docstring
// [events_base.py:639] pylint: disable=missing-docstring
// [events_base.py:641] unregister subscription
// [events_base.py:642] pylint: disable=no-member
// [events_base.py:644] Stop the event listener, if there are no other subscriptions
// [events_base.py:647] No need to do any more if this flag has been set to True
// [events_base.py:651] Set the self._has_been_unsubscribed flag now
// [events_base.py:652] to prevent reuse of the subscription, even if
// [events_base.py:653] an attempt to unsubscribe fails
// [events_base.py:657] Cancel any auto renew
// [events_base.py:695] : `weakref.WeakValueDictionary`: Thread safe mapping.
// [events_base.py:696] : Used to store a mapping of sid to subscription
// [events_base.py:698] The lock to go with it
// [events_base.py:699] You must only ever access the mapping in the context of this lock,
// [events_base.py:700] eg:
// [events_base.py:701] with self.subscriptions_lock:
// [events_base.py:702] queue = self.subscriptions[sid].events
// [events_base.py:703] : `threading.Lock`: for use with `subscriptions`
// [events_base.py:715] Add the queue to the master dict of subscriptions so it can be
// [events_base.py:716] looked up by sid. The subscriptions_lock is not used here as
// [events_base.py:717] it is used in Subscription.subscribe() in the events_base
// [events_base.py:718] module, from which the register function is called.
// [events_base.py:720] Register subscription to be unsubscribed at exit if still alive
// [events_base.py:721] This will not happen if exit is abnormal (eg in response to a
// [events_base.py:722] signal or fatal interpreter error - see the docs for `atexit`).

// MARK: - Original commentary: events_twisted.py
// [events_twisted.py:1] module docstring:
// Classes to handle Sonos UPnP Events and Subscriptions.
// 
// The `Subscription` class from this module will be used in
// :py:mod:`soco.services` if `config.EVENTS_MODULE` is set
// to point to this module.
// 
// Example:
// 
//     Run this code, and change your volume, tracks etc::
// 
//         from __future__ import print_function
//         import logging
//         logging.basicConfig()
//         import soco
//         from pprint import pprint
// 
//         from soco import events_twisted
//         soco.config.EVENTS_MODULE = events_twisted
//         from twisted.internet import reactor
// 
//         def print_event(event):
//             try:
//                 pprint (event.variables)
//             except Exception as e:
//                 pprint ('There was an error in print_event:', e)
// 
//         def main():
//             # pick a device at random and use it to get
//             # the group coordinator
//             device = soco.discover().pop().group.coordinator
//             print (device.player_name)
//             sub = device.renderingControl.subscribe().subscription
//             sub2 = device.avTransport.subscribe().subscription
//             sub.callback = print_event
//             sub2.callback = print_event
// 
//             def before_shutdown():
//                 sub.unsubscribe()
//                 sub2.unsubscribe()
//                 events_twisted.event_listener.stop()
// 
//             reactor.addSystemEventTrigger(
//                 'before', 'shutdown', before_shutdown)
// 
//         if __name__=='__main__':
//             reactor.callWhenRunning(main)
//             reactor.run()
// 
// .. _Deferred: https://twistedmatrix.com/documents/current/api/twisted.internet.defer.Deferred.html
// .. _Failure: https://twistedmatrix.com/documents/current/api/twisted.python.failure.Failure.html
// 
//
// [events_twisted.py:100] EventNotifyHandler docstring:
// Handles HTTP ``NOTIFY`` Verbs sent to the listener server.
//     Inherits from `soco.events_base.EventNotifyHandlerBase`.
//     
//
// [events_twisted.py:114] EventNotifyHandler.render_NOTIFY docstring:
// Serve a ``NOTIFY`` request by calling `handle_notification`
//         with the headers and content.
//         
//
// [events_twisted.py:132] EventListener docstring:
// The Event Listener.
// 
//     Runs an http server which is an endpoint for ``NOTIFY``
//     requests from Sonos devices. Inherits from
//     `soco.events_base.EventListenerBase`.
//     
//
// [events_twisted.py:145] EventListener.listen docstring:
// Start the event listener listening on the local machine at
//         port 1400 (default). If this port is unavailable, the
//         listener will attempt to listen on the next available port,
//         within a range of 100.
// 
//         Make sure that your firewall allows connections to this port.
// 
//         This method is called by `soco.events_base.EventListenerBase.start`
// 
//         Handling of requests is delegated to an instance of the
//         `EventNotifyHandler` class.
// 
//         Args:
//             ip_address (str): The local network interface on which the server
//                 should start listening.
//         Returns:
//             int: The port on which the server is listening.
// 
//         Note:
//             The port on which the event listener listens is configurable.
//             See `config.EVENT_LISTENER_PORT`
//         
//
// [events_twisted.py:193] EventListener.stop_listening docstring:
// Stop the listener.
//
// [events_twisted.py:199] Subscription docstring:
// A class representing the subscription to a UPnP event.
//     Inherits from `soco.events_base.SubscriptionBase`.
//     
//
// [events_twisted.py:204] Subscription.__init__ docstring:
// 
//         Args:
//             service (Service): The SoCo `Service` to which the subscription
//                  should be made.
//             event_queue (:class:`~queue.Queue`): A queue on which received
//                 events will be put. If not specified, a queue will be
//                 created and used.
// 
//         
//
// [events_twisted.py:232] Subscription.subscribe docstring:
// Subscribe to the service.
// 
//         If requested_timeout is provided, a subscription valid for that number
//         of seconds will be requested, but not guaranteed. Check
//         `timeout` on return to find out what period of validity is
//         actually allocated.
// 
//         This method calls `events_base.SubscriptionBase.subscribe`.
// 
//         Note:
//             SoCo will try to unsubscribe any subscriptions which are still
//             subscribed on program termination, but it is good practice for
//             you to clean up by making sure that you call :meth:`unsubscribe`
//             yourself.
// 
//         Args:
//             requested_timeout(int, optional): The timeout to be requested.
//             auto_renew (bool, optional): If `True`, renew the subscription
//                 automatically shortly before timeout. Default `False`.
//             strict (bool, optional): If True and an Exception occurs during
//                 execution, the returned Deferred_ will fail with a Failure_
//                 which will be passed to the applicable errback (if any has
//                 been set by the calling code) or, if False, the Failure will
//                 be logged and the Subscription instance will be passed to
//                 the applicable callback (if any has
//                 been set by the calling code). Default `True`.
// 
//         Returns:
//             Deferred_: A Deferred_ the result of which will be the
//             Subscription instance and the subscription property of which
//             will point to the Subscription instance.
// 
//         
//
// [events_twisted.py:269] Subscription.renew docstring:
// renew(requested_timeout=None)
//         Renew the event subscription.
//         You should not try to renew a subscription which has been
//         unsubscribed, or once it has expired.
// 
//         This method calls `events_base.SubscriptionBase.renew`.
// 
//         Args:
//             requested_timeout (int, optional): The period for which a renewal
//                 request should be made. If None (the default), use the timeout
//                 requested on subscription.
//             is_autorenew (bool, optional): Whether this is an autorenewal.
//                 Default `False`.
//             strict (bool, optional): If True and an Exception occurs during
//                 execution, the returned Deferred_ will fail with a Failure_
//                 which will be passed to the applicable errback (if any has
//                 been set by the calling code) or, if False, the Failure will
//                 be logged and the Subscription instance will be passed to
//                 the applicable callback (if any has
//                 been set by the calling code). Default `True`.
// 
//         Returns:
//             Deferred_: A Deferred_ the result of which will be the
//             Subscription instance and the subscription property of which
//             will point to the Subscription instance.
// 
//         
//
// [events_twisted.py:300] Subscription.unsubscribe docstring:
// unsubscribe()
//         Unsubscribe from the service's events.
//         Once unsubscribed, a Subscription instance should not be reused
// 
//         This method calls `events_base.SubscriptionBase.unsubscribe`.
// 
//         Args:
//             strict (bool, optional): If True and an Exception occurs during
//                 execution, the returned Deferred_ will fail with a Failure_
//                 which will be passed to the applicable errback (if any has
//                 been set by the calling code) or, if False, the Failure will
//                 be logged and the Subscription instance will be passed to
//                 the applicable callback (if any has
//                 been set by the calling code). Default `True`.
// 
//         Returns:
//             Deferred_: A Deferred_ the result of which will be the
//             Subscription instance and the subscription property of which
//             will point to the Subscription instance.
//         
//
// [events_twisted.py:324] Subscription._auto_renew_start docstring:
// Starts the auto_renew loop.
//
// [events_twisted.py:333] Subscription._auto_renew_cancel docstring:
// Cancels the auto_renew loop
//
// [events_twisted.py:340] Subscription._request docstring:
// Sends an HTTP request.
// 
//         Args:
//             method (str): 'SUBSCRIBE' or 'UNSUBSCRIBE'.
//             url (str): The full endpoint to which the request is being sent.
//             headers (dict): A dict of headers, each key and each value being
//                 of type `str`.
//             success (function): A function to be called if the
//                 request succeeds. The function will be called with a dict
//                 of response headers as its only parameter.
//             unconditional (function): An optional function to be called after
//                 the request is complete, regardless of its success. Takes
//                 no parameters.
// 
//         
//
// [events_twisted.py:387] Subscription._wrap docstring:
// This is a wrapper for `Subscription.subscribe`, `Subscription.renew`
//         and `Subscription.unsubscribe` which:
// 
//             * Returns a deferred, the result of which will be the`Subscription`
//               instance.
//             * Sets deferred.subscription to point to the `Subscription`
//               instance so a calling function can access the Subscription
//               instance immediately without registering a Callback and waiting
//               for it to fire.
//             * Converts an Exception into a twisted.python.failure.Failure.
//             * If a Failure (including an Exception converted into a Failure)
//               has occurred:
// 
//                 * Cancels the Subscription (unless the Failure was caused by a
//                   SoCoException upon subscribe).
//                 * On an autorenew, if the strict flag was set to False, calls
//                   the optional self.auto_renew_fail method with the
//                   Failure.
//                 * If the strict flag was set to True (the default), passes the
//                   Failure to the next Errback for handling or, if the strict
//                   flag was set to False, logs the Failure instead.
// 
//             * Calls the `subscribing` and `finished_subscribing` methods of
//               self.subscriptions_map, so that `count` property of
//               self.subscriptions_map includes pending subscriptions.
//             * Serialises calls to the wrapped methods, so that, for example, a
//               call to unsubscribe will not commence until a call to subscribe
//               has completed.
// 
//         
//
// [events_twisted.py:421] Subscription._wrap.execute docstring:
// Execute method
//
// [events_twisted.py:431] Subscription._wrap.callnext docstring:
// Call the next deferred in the queue.
//
// [events_twisted.py:439] Subscription._wrap.handle_outcome docstring:
// A callback / errback to handle the outcome ofmethod,
//             after it has been executed
//             
//
// [events_twisted.py:517] SubscriptionsMapTwisted docstring:
// Maintains a mapping of sids to `soco.events_twisted.Subscription`
//     instances. Registers each subscription to be unsubscribed at exit.
// 
//     Inherits from `soco.events_base.SubscriptionsMap`.
//     
//
// [events_twisted.py:531] SubscriptionsMapTwisted.register docstring:
// Register a subscription by updating local mapping of sid to
//         subscription and registering it to be unsubscribed at exit.
// 
//         Args:
//             subscription(`soco.events_twisted.Subscription`): the subscription
//                 to be registered.
// 
//         
//
// [events_twisted.py:548] SubscriptionsMapTwisted.subscribing docstring:
// Called when the `Subscription.subscribe` method
//         commences execution.
//         
//
// [events_twisted.py:555] SubscriptionsMapTwisted.finished_subscribing docstring:
// Called when the `Subscription.subscribe` method
//         completes execution.
//         
//
// [events_twisted.py:563] SubscriptionsMapTwisted.count docstring:
// 
//         `int`: The number of active or pending subscriptions.
//         
//
// [events_twisted.py:1] pylint: disable=not-context-manager,import-error,wrong-import-position
// [events_twisted.py:3] NOTE: The pylint not-content-manager warning is disabled pending the fix of
// [events_twisted.py:4] a bug in pylint. See https://github.com/PyCQA/pylint/issues/782
// [events_twisted.py:6] Disable while we have Python 2.x compatability
// [events_twisted.py:7] pylint: disable=useless-object-inheritance
// [events_twisted.py:68] Hack to make docs build without twisted installed
// [events_twisted.py:71] pylint: disable=no-init
// [events_twisted.py:71] Resource docstring:
// Fake Resource class to use when building docs
//
// [events_twisted.py:84] Event is imported for compatibility with events.py
// [events_twisted.py:85] pylint: disable=unused-import
// [events_twisted.py:86] noqa: F401
// [events_twisted.py:88] noqa: E402
// [events_twisted.py:95] noqa: E402
// [events_twisted.py:97] pylint: disable=C0103
// [events_twisted.py:109] The SubscriptionsMapTwisted instance created when this module is
// [events_twisted.py:110] imported. This is referenced by
// [events_twisted.py:111] soco.events_base.EventNotifyHandlerBase.
// [events_twisted.py:114] pylint: disable=invalid-name
// [events_twisted.py:127] pylint: disable=no-self-use, missing-docstring
// [events_twisted.py:142] :  :py:class:`twisted.internet.tcp.Port`: set at `listen`
// [events_twisted.py:168] pylint: disable=possibly-used-before-assignment
// [events_twisted.py:176] pylint: disable=no-member
// [events_twisted.py:181] pylint: disable=invalid-name,used-before-assignment
// [events_twisted.py:192] pylint: disable=unused-argument
// [events_twisted.py:215] : :py:obj:`function`: callback function to be called whenever an
// [events_twisted.py:216] : `Event` is received. If it is set and is callable, the callback
// [events_twisted.py:217] : function will be called with the `Event` as the only parameter and
// [events_twisted.py:218] : the Subscription's event queue won't be used.
// [events_twisted.py:220] The SubscriptionsMapTwisted instance created when this module is
// [events_twisted.py:221] imported. This is referenced by soco.events_base.SubscriptionBase.
// [events_twisted.py:223] The EventListener instance created when this module is imported.
// [events_twisted.py:224] This is referenced by soco.events_base.SubscriptionBase.
// [events_twisted.py:226] Used to keep track of the auto_renew loop
// [events_twisted.py:228] Used to serialise calls to subscribe, renew and unsubscribe
// [events_twisted.py:231] pylint: disable=arguments-differ
// [events_twisted.py:326] pylint: disable=possibly-used-before-assignment
// [events_twisted.py:330] False means wait for the interval to elapse, rather than fire at once
// [events_twisted.py:339] pylint: disable=no-self-use
// [events_twisted.py:356] pylint: disable=possibly-used-before-assignment
// [events_twisted.py:371] pylint: disable=invalid-name
// [events_twisted.py:373] pylint: disable=missing-docstring
// [events_twisted.py:420] pylint: disable=unused-argument
// [events_twisted.py:423] Increment the counter of pending calls to Subscription.subscribe
// [events_twisted.py:424] if method is subscribe
// [events_twisted.py:428] Execute method
// [events_twisted.py:433] If there is another deferred in the queue,
// [events_twisted.py:434] call it
// [events_twisted.py:436] pylint: disable=invalid-name
// [events_twisted.py:443] We start by assuming no Failure occurred
// [events_twisted.py:446] pylint: disable=possibly-used-before-assignment
// [events_twisted.py:449] If a Failure or Exception occurred during execution of
// [events_twisted.py:450] subscribe, renew or unsubscribe, cancel it unless the
// [events_twisted.py:451] Failure or Exception was a SoCoException upon subscribe
// [events_twisted.py:461] If we're not being strict, log the Failure
// [events_twisted.py:473] If we're not being strict upon a renewal
// [events_twisted.py:474] (e.g. an autorenewal) call the optional
// [events_twisted.py:475] self.auto_renew_fail method, if it has been set
// [events_twisted.py:479] pylint: disable=not-callable
// [events_twisted.py:482] Decrement the counter of pending calls to Subscription.subscribe
// [events_twisted.py:483] if completed action was subscribe
// [events_twisted.py:487] Remove the previous deferred from the queue
// [events_twisted.py:490] And call the next deferred in the queue
// [events_twisted.py:493] If a Failure occurred and we're in strict mode, reraise it
// [events_twisted.py:497] Create a deferred
// [events_twisted.py:498] pylint: disable=possibly-used-before-assignment
// [events_twisted.py:499] pylint: disable=invalid-name
// [events_twisted.py:500] Set its subscription property to refer to this Subscription
// [events_twisted.py:502] Set the deferred to execute method, when the
// [events_twisted.py:503] deferred is called
// [events_twisted.py:505] Add handle_outcome as both a callback and errback
// [events_twisted.py:507] Add the deferred to the queue
// [events_twisted.py:509] If this is the only deferred in the queue,
// [events_twisted.py:510] call it
// [events_twisted.py:513] Return the deferred
// [events_twisted.py:526] A counter of calls to Subscription.subscribe
// [events_twisted.py:527] that have started but not completed. This is
// [events_twisted.py:528] to prevent the event listener from being stopped prematurely
// [events_twisted.py:541] Add the subscription to the local dict of subscriptions so it
// [events_twisted.py:542] can be looked up by sid
// [events_twisted.py:544] Register subscription to be unsubscribed at exit if still alive
// [events_twisted.py:545] pylint: disable=no-member
// [events_twisted.py:552] Increment the counter
// [events_twisted.py:559] Decrement the counter
// [events_twisted.py:570] pylint: disable=C0103
// [events_twisted.py:571] pylint: disable=C0103

// MARK: - Original commentary: exceptions.py
// [exceptions.py:1] module docstring:
// Exceptions that are used by SoCo.
//
// [exceptions.py:7] SoCoException docstring:
// Base class for all SoCo exceptions.
//
// [exceptions.py:11] UnknownSoCoException docstring:
// An unknown UPnP error.
// 
//     The exception object will contain the raw response sent back from
//     the speaker as the first of its args.
//     
//
// [exceptions.py:19] SoCoUPnPException docstring:
// A UPnP Fault Code, raised in response to actions sent over the
//     network.
// 
//     
//
// [exceptions.py:25] SoCoUPnPException.__init__ docstring:
// 
//         Args:
//             message (str): The message from the server.
//             error_code (str): The UPnP Error Code as a string.
//             error_xml (str): The xml containing the error, as a utf-8
//                 encoded string.
//             error_description (str): A description of the error. Default is ""
//         
//
// [exceptions.py:44] CannotCreateDIDLMetadata docstring:
// 
//     ..  deprecated:: 0.11
//         Use `DIDLMetadataError` instead.
//     
//
// [exceptions.py:51] DIDLMetadataError docstring:
// Raised if a data container class cannot create the DIDL metadata due to
//     missing information.
// 
//     For backward compatibility, this is currently a subclass of
//     `CannotCreateDIDLMetadata`. In a future version, it will likely become
//     a direct subclass of `SoCoException`.
//     
//
// [exceptions.py:61] MusicServiceException docstring:
// An error relating to a third party music service.
//
// [exceptions.py:65] MusicServiceAuthException docstring:
// An error relating to authentication of a third party music service
//
// [exceptions.py:69] UnknownXMLStructure docstring:
// Raised if XML with an unknown or unexpected structure is returned.
//
// [exceptions.py:73] SoCoSlaveException docstring:
// Raised when a master command is called on a slave.
//
// [exceptions.py:77] SoCoNotVisibleException docstring:
// Raised when a command intended for a visible speaker is called
//     on an invisible one.
//
// [exceptions.py:82] NotSupportedException docstring:
// Raised when something is not supported by the device
//
// [exceptions.py:86] EventParseException docstring:
// Raised when a parsing exception occurs during event handling.
// 
//     Attributes:
//         tag (str): The tag for which the exception occured
//         metadata (str): The metadata which failed to parse
//         __cause__ (Exception): The original exception
//     
//
// [exceptions.py:95] EventParseException.__init__ docstring:
// 
//         Args:
//             tag (str): The tag for which the exception occured
//             metadata (str): The metadata which failed to parse
//             cause (Exception): The original exception
//         
//
// [exceptions.py:111] SoCoFault docstring:
// Class to represent a failed object instantiation.
// 
//     It rethrows the exception on common use.
// 
//     Attributes:
//         exception: The exception which will be thrown on use
//     
//
// [exceptions.py:120] SoCoFault.__init__ docstring:
// 
//         Args:
//             exception (Exception): The exception which should be thrown on use
//         
//
// [exceptions.py:1] Disable while we have Python 2.x compatability
// [exceptions.py:2] pylint: disable=useless-object-inheritance

// MARK: - Original commentary: groups.py
// [groups.py:1] module docstring:
// This module contains classes and functionality relating to Sonos Groups.
//
// [groups.py:7] ZoneGroup docstring:
// 
//     A class representing a Sonos Group. It looks like this::
// 
//         ZoneGroup(
//             uid='RINCON_000FD584236D01400:58',
//             coordinator=SoCo("192.168.1.101"),
//             members={SoCo("192.168.1.101"), SoCo("192.168.1.102")}
//         )
// 
// 
//     Any SoCo instance can tell you what group it is in::
// 
// 
//         >>> device = soco.discovery.any_soco()
//         >>> device.group
//         ZoneGroup(
//             uid='RINCON_000FD584236D01400:58',
//             coordinator=SoCo("192.168.1.101"),
//             members={SoCo("192.168.1.101"), SoCo("192.168.1.102")}
//         )
// 
//     From there, you can find the coordinator for the current group::
// 
//         >>> device.group.coordinator
//         SoCo("192.168.1.101")
// 
//     or, for example, its name::
// 
//         >>> device.group.coordinator.player_name
//         Kitchen
// 
//     or a set of the members::
// 
//         >>> device.group.members
//         {SoCo("192.168.1.101"), SoCo("192.168.1.102")}
// 
//     For convenience, ZoneGroup is also a container::
// 
//         >>> for player in device.group:
//         ...   print player.player_name
//         Living Room
//         Kitchen
// 
//     If you need it, you can get an iterator over all groups on the network::
// 
//         >>> device.all_groups
//         <generator object all_groups at 0x108cf0c30>
// 
//     A consistent readable label for the group members can be returned with
//     the `label` and `short_label` properties.
// 
//     Properties are available to get and set the group `volume` and the group
//     `mute` state, and the `set_relative_volume()` method can be used to make
//     relative adjustments to the group volume, e.g.:
// 
//         >>> device.group.volume = 25
//         >>> device.group.volume
//         25
//         >>> device.group.set_relative_volume(-10)
//         15
//         >>> device.group.mute
//         >>> False
//         >>> device.group.mute = True
//         >>> device.group.mute
//         True
//     
//
// [groups.py:75] ZoneGroup.__init__ docstring:
// 
//         Args:
//             uid (str): The unique Sonos ID for this group, eg
//                 ``RINCON_000FD584236D01400:5``.
//             coordinator (SoCo): The SoCo instance representing the coordinator
//                 of this group.
//             members (Iterable[SoCo]): An iterable containing SoCo instances
//                 which represent the members of this group.
//         
//
// [groups.py:107] ZoneGroup.label docstring:
// str: A description of the group.
// 
//         >>> device.group.label
//         'Kitchen, Living Room'
//         
//
// [groups.py:117] ZoneGroup.short_label docstring:
// str: A short description of the group.
// 
//         >>> device.group.short_label
//         'Kitchen + 1'
//         
//
// [groups.py:130] ZoneGroup.volume docstring:
// int: The volume of the group.
// 
//         An integer between 0 and 100.
//         
//
// [groups.py:151] ZoneGroup.mute docstring:
// bool: The mute state for the group.
// 
//         True or False.
//         
//
// [groups.py:169] ZoneGroup.set_relative_volume docstring:
// Adjust the group volume up or down by a relative amount.
// 
//         If the adjustment causes the volume to overshoot the maximum value
//         of 100, the volume will be set to 100. If the adjustment causes the
//         volume to undershoot the minimum value of 0, the volume will be set
//         to 0.
// 
//         Note that this method is an alternative to using addition and
//         subtraction assignment operators (+=, -=) on the `volume` property
//         of a `ZoneGroup` instance. These operators perform the same function
//         as `set_relative_volume()` but require two network calls per
//         operation instead of one.
// 
//         Args:
//             relative_group_volume (int): The relative volume adjustment. Can be
//                 positive or negative.
// 
//         Returns:
//             int: The new group volume setting.
// 
//         Raises:
//             ValueError: If ``relative_group_volume`` cannot be cast as
//                 an integer.
//         
//
// [groups.py:1] Disable while we have Python 2.x compatability
// [groups.py:2] pylint: disable=useless-object-inheritance
// [groups.py:85] : The unique Sonos ID for this group
// [groups.py:87] : The `SoCo` instance which coordinates this group
// [groups.py:90] : A set of `SoCo` instances which are members of the group
// [groups.py:144] Coerce in range
// [groups.py:195] Sonos automatically handles out-of-range values.

// MARK: - Original commentary: ms_data_structures.py
// [ms_data_structures.py:1] module docstring:
// This module contains all the data structures for music service plugins.
//
// [ms_data_structures.py:17] get_ms_item docstring:
// Return the music service item that corresponds to xml.
// 
//     The class is identified by getting the type from the 'itemType' tag
//     
//
// [ms_data_structures.py:27] tags_with_text docstring:
// Return a list of tags that contain text retrieved recursively from an
//     XML tree.
//
// [ms_data_structures.py:43] MusicServiceItem docstring:
// Class that represents a music service item.
//
// [ms_data_structures.py:56] MusicServiceItem.from_xml docstring:
// Return a Music Service item generated from xml.
// 
//         :param xml: Object XML. All items containing text are added to the
//             content of the item. The class variable ``valid_fields`` of each of
//             the classes list the valid fields (after translating the camel
//             case to underscore notation). Required fields are listed in the
//             class variable by that name (where 'id' has been renamed to
//             'item_id').
//         :type xml: :py:class:`xml.etree.ElementTree.Element`
//         :param service: The music service (plugin) instance that retrieved the
//             element. This service must contain ``id_to_extended_id`` and
//             ``form_uri`` methods and ``description`` and ``service_id``
//             attributes.
//         :type service: Instance of sub-class of
//             :class:`soco.plugins.SoCoPlugin`
//         :param parent_id: The parent ID of the item, will either be the
//             extended ID of another MusicServiceItem or of a search
//         :type parent_id: str
// 
//         For a track the XML can e.g. be on the following form:
// 
//         .. code :: xml
// 
//          <mediaMetadata xmlns="http://www.sonos.com/Services/1.1">
//            <id>trackid_141359</id>
//            <itemType>track</itemType>
//            <mimeType>audio/aac</mimeType>
//            <title>Teacher</title>
//            <trackMetadata>
//              <artistId>artistid_10597</artistId>
//              <artist>Jethro Tull</artist>
//              <composerId>artistid_10597</composerId>
//              <composer>Jethro Tull</composer>
//              <albumId>albumid_141358</albumId>
//              <album>MU - The Best Of Jethro Tull</album>
//              <albumArtistId>artistid_10597</albumArtistId>
//              <albumArtist>Jethro Tull</albumArtist>
//              <duration>229</duration>
//              <albumArtURI>http://varnish01.music.aspiro.com/sca/
//               imscale?h=90&amp;w=90&amp;img=/content/music10/prod/wmg/
//               1383757201/094639008452_20131105025504431/resources/094639008452.
//               jpg</albumArtURI>
//              <canPlay>true</canPlay>
//              <canSkip>true</canSkip>
//              <canAddToFavorites>true</canAddToFavorites>
//            </trackMetadata>
//          </mediaMetadata>
//         
//
// [ms_data_structures.py:147] MusicServiceItem.from_dict docstring:
// Initialize the class from a dict.
// 
//         :param dict_in: The dictionary that contains the item content. Required
//             fields are listed class variable by that name
//         :type dict_in: dict
//         
//
// [ms_data_structures.py:158] MusicServiceItem.__eq__ docstring:
// Return the equals comparison result to another ``playable_item``.
//
// [ms_data_structures.py:164] MusicServiceItem.__ne__ docstring:
// Return the not equals comparison result to another
//         ``playable_item``
//
// [ms_data_structures.py:171] MusicServiceItem.__repr__ docstring:
// Return the repr value for the item.
// 
//         The repr is on the form::
// 
//           <class_name 'middle_part[0:40]' at id_in_hex>
// 
//         where middle_part is either the title item in content, if it is set,
//         or ``str(content)``. The output is also cleared of non-ascii
//         characters.
//         
//
// [ms_data_structures.py:190] MusicServiceItem.__str__ docstring:
// Return the str value for the item::
// 
//          <class_name 'middle_part[0:40]' at id_in_hex>
// 
//         where middle_part is either the title item in content, if it is set, or
//         ``str(content)``. The output is also cleared of non-ascii characters.
// 
//         
//
// [ms_data_structures.py:202] MusicServiceItem.to_dict docstring:
// Return a copy of the content dict.
//
// [ms_data_structures.py:207] MusicServiceItem.didl_metadata docstring:
// Return the DIDL metadata for a Music Service Track.
// 
//         The metadata is on the form:
// 
//         .. code :: xml
// 
//          <DIDL-Lite xmlns:dc="http://purl.org/dc/elements/1.1/"
//               xmlns:upnp="urn:schemas-upnp-org:metadata-1-0/upnp/"
//               xmlns:r="urn:schemas-rinconnetworks-com:metadata-1-0/"
//               xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/">
//            <item id="...self.extended_id..."
//               parentID="...self.parent_id..."
//               restricted="true">
//              <dc:title>...self.title...</dc:title>
//              <upnp:class>...self.item_class...</upnp:class>
//              <desc id="cdudn"
//                 nameSpace="urn:schemas-rinconnetworks-com:metadata-1-0/">
//                self.content['description']
//              </desc>
//            </item>
//          </DIDL-Lite>
//         
//
// [ms_data_structures.py:292] MusicServiceItem.item_id docstring:
// Return the item id.
//
// [ms_data_structures.py:297] MusicServiceItem.extended_id docstring:
// Return the extended id.
//
// [ms_data_structures.py:302] MusicServiceItem.title docstring:
// Return the title.
//
// [ms_data_structures.py:307] MusicServiceItem.service_id docstring:
// Return the service ID.
//
// [ms_data_structures.py:312] MusicServiceItem.can_play docstring:
// Return a boolean for whether the item can be played.
//
// [ms_data_structures.py:317] MusicServiceItem.parent_id docstring:
// Return the extended parent_id, if set, otherwise return None.
//
// [ms_data_structures.py:322] MusicServiceItem.album_art_uri docstring:
// Return the album art URI if set, otherwise return None.
//
// [ms_data_structures.py:327] MSTrack docstring:
// Class that represents a music service track.
//
// [ms_data_structures.py:361] MSTrack.__init__ docstring:
// Initialize MSTrack item.
//
// [ms_data_structures.py:377] MSTrack.album docstring:
// Return the album title if set, otherwise return None.
//
// [ms_data_structures.py:382] MSTrack.artist docstring:
// Return the artist if set, otherwise return None.
//
// [ms_data_structures.py:387] MSTrack.duration docstring:
// Return the duration if set, otherwise return None.
//
// [ms_data_structures.py:392] MSTrack.uri docstring:
// Return the URI.
//
// [ms_data_structures.py:398] MSAlbum docstring:
// Class that represents a Music Service Album.
//
// [ms_data_structures.py:442] MSAlbum.artist docstring:
// Return the artist if set, otherwise return None.
//
// [ms_data_structures.py:447] MSAlbum.uri docstring:
// Return the URI.
//
// [ms_data_structures.py:453] MSAlbumList docstring:
// Class that represents a Music Service Album List.
//
// [ms_data_structures.py:494] MSAlbumList.uri docstring:
// Return the URI.
//
// [ms_data_structures.py:501] MSPlaylist docstring:
// Class that represents a Music Service Play List.
//
// [ms_data_structures.py:542] MSPlaylist.uri docstring:
// Return the URI.
//
// [ms_data_structures.py:549] MSArtistTracklist docstring:
// Class that represents a Music Service Artist Track List.
//
// [ms_data_structures.py:579] MSArtistTracklist.uri docstring:
// Return the URI.
//
// [ms_data_structures.py:585] MSArtist docstring:
// Class that represents a Music Service Artist.
//
// [ms_data_structures.py:617] MSFavorites docstring:
// Class that represents a Music Service Favorite.
//
// [ms_data_structures.py:645] MSCollection docstring:
// Class that represents a Music Service Collection.
//
// [ms_data_structures.py:1] pylint: disable = star-args, unsupported-membership-test
// [ms_data_structures.py:2] pylint: disable = not-an-iterable
// [ms_data_structures.py:4] Disable while we have Python 2.x compatability
// [ms_data_structures.py:5] pylint: disable=useless-object-inheritance
// [ms_data_structures.py:9] This needs to be integrated with Music Library data structures
// [ms_data_structures.py:35] pylint: disable=len-as-condition
// [ms_data_structures.py:46] These fields must be overwritten in the sub classes
// [ms_data_structures.py:105] Add a few extra pieces of information
// [ms_data_structures.py:111] Extract values from the XML
// [ms_data_structures.py:114] Strip namespace
// [ms_data_structures.py:115] Convert to nice names
// [ms_data_structures.py:121] Convert values for known types
// [ms_data_structures.py:127] Rename a single item
// [ms_data_structures.py:129] And get the extended id
// [ms_data_structures.py:131] Add URI if there is one for the relevant class
// [ms_data_structures.py:136] Check for all required values
// [ms_data_structures.py:182] 40 originates from terminal width (78) - (15) for address part and
// [ms_data_structures.py:183] (19) for the longest class name and a little left for buffer
// [ms_data_structures.py:230] Check if this item is meant to be played
// [ms_data_structures.py:237] Check if we have the attributes to create the didl metadata:
// [ms_data_structures.py:254] Main element, ugly? yes! but I have given up on using namespaces
// [ms_data_structures.py:255] with xml.etree.ElementTree
// [ms_data_structures.py:257] Item sub element
// [ms_data_structures.py:259] Only add the parent_id if we have it
// [ms_data_structures.py:268] Add title and class
// [ms_data_structures.py:277] Add the desc element
// [ms_data_structures.py:351] IMPORTANT. Keep this list, __init__ args and content in __init__ in sync
// [ms_data_structures.py:394] x-sonos-http:trackid_19356232.mp4?sid=20&amp;flags=32
// [ms_data_structures.py:417] IMPORTANT. Keep this list, __init__ args and content in __init__ in sync
// [ms_data_structures.py:449] x-rincon-cpcontainer:0004002calbumid_22757081
// [ms_data_structures.py:469] IMPORTANT. Keep this list, __init__ args and content in __init__ in sync
// [ms_data_structures.py:496] x-rincon-cpcontainer:000d006cplaylistid_26b18dbb-fd35-40bd-8d4f-
// [ms_data_structures.py:497] 8669bfc9f712
// [ms_data_structures.py:517] IMPORTANT. Keep this list, __init__ args and content in __init__ in sync
// [ms_data_structures.py:544] x-rincon-cpcontainer:000d006cplaylistid_c86ddf26-8ec5-483e-b292-
// [ms_data_structures.py:545] abe18848e89e
// [ms_data_structures.py:554] IMPORTANT. Keep this list, __init__ args and content in __init__ in sync
// [ms_data_structures.py:581] x-rincon-cpcontainer:100f006cartistpopsongsid_1566
// [ms_data_structures.py:600] Since MSArtist cannot produce didl_metadata, they are not strictly
// [ms_data_structures.py:601] required, but it makes sense to require them anyway, since they are the
// [ms_data_structures.py:602] fields that that describe the item
// [ms_data_structures.py:603] IMPORTANT. Keep this list, __init__ args and content in __init__ in sync
// [ms_data_structures.py:628] Since MSFavorites cannot produce didl_metadata, they are not strictly
// [ms_data_structures.py:629] required, but it makes sense to require them anyway, since they are the
// [ms_data_structures.py:630] fields that that describe the item
// [ms_data_structures.py:631] IMPORTANT. Keep this list, __init__ args and content in __init__ in sync
// [ms_data_structures.py:656] Since MSCollection cannot produce didl_metadata, they are not strictly
// [ms_data_structures.py:657] required, but it makes sense to require them anyway, since they are the
// [ms_data_structures.py:658] fields that that describe the item
// [ms_data_structures.py:659] IMPORTANT. Keep this list, __init__ args and content in __init__ in sync

// MARK: - Original commentary: music_library.py
// [music_library.py:1] module docstring:
// Access to the Music Library.
// 
// The Music Library is the collection of music stored on your local network.
// For access to third party music streaming services, see the
// `music_service` module.
//
// [music_library.py:25] MusicLibrary docstring:
// The Music Library.
//
// [music_library.py:46] MusicLibrary.__init__ docstring:
// 
//         Args:
//             soco (`SoCo`, optional): A `SoCo` instance to query for music
//                 library information. If `None`, or not supplied, a random
//                 `SoCo` instance will be used.
//         
//
// [music_library.py:56] MusicLibrary.build_album_art_full_uri docstring:
// Ensure an Album Art URI is an absolute URI.
// 
//         Args:
//              url (str): the album art URI.
// 
//         Returns:
//             str: An absolute URI.
//         
//
// [music_library.py:71] MusicLibrary._update_album_art_to_full_uri docstring:
// Update an item's Album Art URI to be an absolute URI.
// 
//         Args:
//             item: The item to update the URI for
//         
//
// [music_library.py:80] MusicLibrary.get_artists docstring:
// Convenience method for `get_music_library_information`
//         with ``search_type='artists'``. For details of other arguments,
//         see `that method
//         <#soco.music_library.MusicLibrary.get_music_library_information>`_.
// 
//         
//
// [music_library.py:90] MusicLibrary.get_album_artists docstring:
// Convenience method for `get_music_library_information`
//         with ``search_type='album_artists'``. For details of other arguments,
//         see `that method
//         <#soco.music_library.MusicLibrary.get_music_library_information>`_.
// 
//         
//
// [music_library.py:100] MusicLibrary.get_albums docstring:
// Convenience method for `get_music_library_information`
//         with ``search_type='albums'``. For details of other arguments,
//         see `that method
//         <#soco.music_library.MusicLibrary.get_music_library_information>`_.
// 
//         
//
// [music_library.py:110] MusicLibrary.get_genres docstring:
// Convenience method for `get_music_library_information`
//         with ``search_type='genres'``. For details of other arguments,
//         see `that method
//         <#soco.music_library.MusicLibrary.get_music_library_information>`_.
// 
//         
//
// [music_library.py:120] MusicLibrary.get_composers docstring:
// Convenience method for `get_music_library_information`
//         with ``search_type='composers'``. For details of other arguments,
//         see `that method
//         <#soco.music_library.MusicLibrary.get_music_library_information>`_.
// 
//         
//
// [music_library.py:130] MusicLibrary.get_tracks docstring:
// Convenience method for `get_music_library_information`
//         with ``search_type='tracks'``. For details of other arguments,
//         see `that method
//         <#soco.music_library.MusicLibrary.get_music_library_information>`_.
// 
//         
//
// [music_library.py:140] MusicLibrary.get_playlists docstring:
// Convenience method for `get_music_library_information`
//         with ``search_type='playlists'``. For details of other arguments,
//         see `that method
//         <#soco.music_library.MusicLibrary.get_music_library_information>`_.
// 
//         Note:
//             The playlists that are referred to here are the playlists imported
//             from the music library, they are not the Sonos playlists.
// 
//         
//
// [music_library.py:154] MusicLibrary.get_sonos_favorites docstring:
// Convenience method for `get_music_library_information`
//         with ``search_type='sonos_favorites'``. For details of other arguments,
//         see `that method
//         <#soco.music_library.MusicLibrary.get_music_library_information>`_.
//         
//
// [music_library.py:163] MusicLibrary.get_favorite_radio_stations docstring:
// Convenience method for `get_music_library_information`
//         with ``search_type='radio_stations'``. For details of other arguments,
//         see `that method
//         <#soco.music_library.MusicLibrary.get_music_library_information>`_.
//         
//
// [music_library.py:172] MusicLibrary.get_favorite_radio_shows docstring:
// Convenience method for `get_music_library_information`
//         with ``search_type='radio_stations'``. For details of other arguments,
//         see `that method
//         <#soco.music_library.MusicLibrary.get_music_library_information>`_.
//         
//
// [music_library.py:181] MusicLibrary.get_music_library_information docstring:
// Retrieve music information objects from the music library.
// 
//         This method is the main method to get music information items, like
//         e.g. tracks, albums etc., from the music library with. It can be used
//         in a few different ways:
// 
//         The ``search_term`` argument performs a fuzzy search on that string in
//         the results, so e.g calling::
// 
//             get_music_library_information('artists', search_term='Metallica')
// 
//         will perform a fuzzy search for the term 'Metallica' among all the
//         artists.
// 
//         Using the ``subcategories`` argument, will jump directly into that
//         subcategory of the search and return results from there. So. e.g
//         knowing that among the artist is one called 'Metallica', calling::
// 
//             get_music_library_information('artists',
//                                           subcategories=['Metallica'])
// 
//         will jump directly into the 'Metallica' sub category and return the
//         albums associated with Metallica and::
// 
//             get_music_library_information('artists',
//                                           subcategories=['Metallica', 'Black'])
// 
//         will return the tracks of the album 'Black' by the artist 'Metallica'.
//         The order of sub category types is: Genres->Artists->Albums->Tracks.
//         It is also possible to combine the two, to perform a fuzzy search in a
//         sub category.
// 
//         The ``start``, ``max_items`` and ``complete_result`` arguments all
//         have to do with paging of the results. By default the searches are
//         always paged, because there is a limit to how many items we can get at
//         a time. This paging is exposed to the user with the ``start`` and
//         ``max_items`` arguments. So calling::
// 
//             get_music_library_information('artists', start=0, max_items=100)
//             get_music_library_information('artists', start=100, max_items=100)
// 
//         will get the first and next 100 items, respectively. It is also
//         possible to ask for all the elements at once::
// 
//             get_music_library_information('artists', complete_result=True)
// 
//         This will perform the paging internally and simply return all the
//         items.
// 
//         Args:
// 
//             search_type (str):
//                 The kind of information to retrieve. Can be one of:
//                 ``'artists'``, ``'album_artists'``, ``'albums'``,
//                 ``'genres'``, ``'composers'``, ``'tracks'``, ``'share'``,
//                 ``'sonos_playlists'``, or ``'playlists'``, where playlists
//                 are the imported playlists from the music library.
//             start (int, optional): starting number of returned matches
//                 (zero based). Default 0.
//             max_items (int, optional): Maximum number of returned matches.
//                 Default 100.
//             full_album_art_uri (bool):
//                 whether the album art URI should be absolute (i.e. including
//                 the IP address). Default `False`.
//             search_term (str, optional):
//                 a string that will be used to perform a fuzzy search among the
//                 search results. If used in combination with subcategories,
//                 the fuzzy search will be performed in the subcategory.
//             subcategories (str, optional):
//                 A list of strings that indicate one or more subcategories to
//                 dive into.
//             complete_result (bool): if `True`, will disable
//                 paging (ignore ``start`` and ``max_items``) and return all
//                 results for the search.
// 
//         Warning:
//             Getting e.g. all the tracks in a large collection might
//             take some time.
// 
// 
//         Returns:
//              `SearchResult`: an instance of `SearchResult`.
// 
//         Note:
//             * The maximum numer of results may be restricted by the unit,
//               presumably due to transfer size consideration, so check the
//               returned number against that requested.
// 
//             * The playlists that are returned with the ``'playlists'`` search,
//               are the playlists imported from the music library, they
//               are not the Sonos playlists.
// 
//         Raises:
//              `SoCoException` upon errors.
//         
//
// [music_library.py:339] MusicLibrary.browse docstring:
// Browse (get sub-elements from) a music library item.
// 
//         Args:
//             ml_item (`DidlItem`): the item to browse, if left out or
//                 `None`, items at the root level will be searched.
//             start (int): the starting index of the results.
//             max_items (int): the maximum number of items to return.
//             full_album_art_uri (bool): whether the album art URI should be
//                 fully qualified with the relevant IP address.
//             search_term (str): A string that will be used to perform a fuzzy
//                 search among the search results. If used in combination with
//                 subcategories, the fuzzy search will be performed on the
//                 subcategory. Note: Searching will not work if ``ml_item`` is
//                 `None`.
//             subcategories (list): A list of strings that indicate one or more
//                 subcategories to descend into. Note: Providing sub categories
//                 will not work if ``ml_item`` is `None`.
// 
//         Returns:
//             A `SearchResult` instance.
// 
//         Raises:
//             AttributeError: if ``ml_item`` has no ``item_id`` attribute.
//             SoCoUPnPException: with ``error_code='701'`` if the item cannot be
//                 browsed.
//         
//
// [music_library.py:409] MusicLibrary.browse_by_idstring docstring:
// Browse (get sub-elements from) a given music library item,
//         specified by a string.
// 
//         Args:
//             search_type (str): The kind of information to retrieve. Can be
//                 one of: ``'artists'``, ``'album_artists'``, ``'albums'``,
//                 ``'genres'``, ``'composers'``, ``'tracks'``, ``'share'``,
//                 ``'sonos_playlists'``, and ``'playlists'``, where
//                 playlists are the imported file based playlists from the
//                 music library.
//             idstring (str): a term to search for.
//             start (int): starting number of returned matches. Default 0.
//             max_items (int): Maximum number of returned matches. Default 100.
//             full_album_art_uri (bool): whether the album art URI should be
//                 absolute (i.e. including the IP address). Default `False`.
// 
//         Returns:
//             `SearchResult`: a `SearchResult` instance.
// 
//         Note:
//             The maximum numer of results may be restricted by the unit,
//             presumably due to transfer size consideration, so check the
//             returned number against that requested.
//         
//
// [music_library.py:455] MusicLibrary._music_lib_search docstring:
// Perform a music library search and extract search numbers.
// 
//         You can get an overview of all the relevant search prefixes (like
//         'A:') and their meaning with the request:
// 
//         .. code ::
// 
//          response = device.contentDirectory.Browse([
//              ('ObjectID', '0'),
//              ('BrowseFlag', 'BrowseDirectChildren'),
//              ('Filter', '*'),
//              ('StartingIndex', 0),
//              ('RequestedCount', 100),
//              ('SortCriteria', '')
//          ])
// 
//         Args:
//             search (str): The ID to search.
//             start (int): The index of the forst item to return.
//             max_items (int): The maximum number of items to return.
// 
//         Returns:
//             tuple: (response, metadata) where response is the returned metadata
//                 and metadata is a dict with the 'number_returned',
//                 'total_matches' and 'update_id' integers
//         
//
// [music_library.py:500] MusicLibrary.library_updating docstring:
// bool: whether the music library is in the process of being updated.
//
// [music_library.py:505] MusicLibrary.start_library_update docstring:
// Start an update of the music library.
// 
//         Args:
//             album_artist_display_option (str): a value for the album artist
//                 compilation setting (see `album_artist_display_option`).
//         
//
// [music_library.py:518] MusicLibrary.search_track docstring:
// Search for an artist, an artist's albums, or specific track.
// 
//         Args:
//             artist (str): an artist's name.
//             album (str, optional): an album name. Default `None`.
//             track (str, optional): a track name. Default `None`.
//             full_album_art_uri (bool): whether the album art URI should be
//                 absolute (i.e. including the IP address). Default `False`.
// 
//         Returns:
//             A `SearchResult` instance.
//         
//
// [music_library.py:544] MusicLibrary.get_albums_for_artist docstring:
// Get an artist's albums.
// 
//         Args:
//             artist (str): an artist's name.
//             full_album_art_uri: whether the album art URI should be
//                 absolute (i.e. including the IP address). Default `False`.
// 
//         Returns:
//             A `SearchResult` instance.
//         
//
// [music_library.py:576] MusicLibrary.get_tracks_for_album docstring:
// Get the tracks of an artist's album.
// 
//         Args:
//             artist (str): an artist's name.
//             album (str): an album name.
//             full_album_art_uri: whether the album art URI should be
//                 absolute (i.e. including the IP address). Default `False`.
// 
//         Returns:
//             A `SearchResult` instance.
//         
//
// [music_library.py:598] MusicLibrary.album_artist_display_option docstring:
// str: The current value of the album artist compilation setting.
// 
//         Possible values are:
// 
//         * ``'WMP'`` - use Album Artists
//         * ``'ITUNES'`` - use iTunes® Compilations
//         * ``'NONE'`` - do not group compilations
// 
//         See Also:
//             The Sonos `FAQ <https://sonos.custhelp.com
//             /app/answers/detail/a_id/3056/kw/artist%20compilation>`_ on
//             compilation albums.
// 
//         To change the current setting, call `start_library_update` and
//         pass the new setting.
//         
//
// [music_library.py:618] MusicLibrary.list_library_shares docstring:
// Return a list of the music library shares.
// 
//         Returns:
//             list: The music library shares, which are strings of the form
//             ``'//hostname_or_IP/share_path'``.
//         
//
// [music_library.py:651] MusicLibrary.delete_library_share docstring:
// Delete a music library share.
// 
//         Args:
//             share_name (str): the name of the share to be deleted, which
//                 should be of the form ``'//hostname_or_IP/share_path'``.
// 
//         :raises: `SoCoUPnPException`
//         
//
// [music_library.py:1] Disable while we have Python 2.x compatability
// [music_library.py:2] pylint: disable=useless-object-inheritance
// [music_library.py:28] Key words used when performing searches
// [music_library.py:45] pylint: disable=invalid-name, protected-access
// [music_library.py:65] Add on the full album art link, as the URI version
// [music_library.py:66] does not include the ipaddress
// [music_library.py:288] Add sub categories
// [music_library.py:289] sub categories are not allowed when searching shares
// [music_library.py:293] Add fuzzy search
// [music_library.py:296] Don't insert ":" and don't escape "/" (so can't use url_escape_path)
// [music_library.py:304] Change start and max for complete searches
// [music_library.py:308] Try and get this batch of results
// [music_library.py:312] 'No such object' UPnP errors
// [music_library.py:318] Parse the results
// [music_library.py:321] Check if the album art URI should be fully qualified
// [music_library.py:324] Append the item to the list
// [music_library.py:327] If we are not after the complete results, the stop after 1
// [music_library.py:328] iteration
// [music_library.py:336] pylint: disable=star-args
// [music_library.py:379] Add sub categories
// [music_library.py:383] Add fuzzy search
// [music_library.py:390] 'No such object' UPnP errors
// [music_library.py:397] Parse the results
// [music_library.py:401] Check if the album art URI should be fully qualified
// [music_library.py:406] pylint: disable=star-args
// [music_library.py:438] Check if the string ID already has the type, if so we do not want to
// [music_library.py:439] add one also Imported playlist have a full path to them, so they do
// [music_library.py:440] not require the A:PLAYLISTS part first
// [music_library.py:446] Not sure about the res protocol. But this seems to work
// [music_library.py:452] Call the base version
// [music_library.py:493] Get result information
// [music_library.py:534] Perform the search
// [music_library.py:563] It is necessary to update the list of items in two places, due to
// [music_library.py:564] a bug in SearchResult
// [music_library.py:637] Zero matches
// [music_library.py:642] One match
// [music_library.py:646] Otherwise it's multiple matches
// [music_library.py:660] share_name must be prefixed with 'S:'

// MARK: - Original commentary: music_services/__init__.py
// [music_services/__init__.py:1] module docstring:
// This package provides the MusicService class and related functionality,
// which allows access to the various third party music services which can be used
// with Sonos.
//

// MARK: - Original commentary: music_services/accounts.py
// [music_services/accounts.py:1] module docstring:
// This module contains classes relating to Third Party music services.
//
// [music_services/accounts.py:17] Account docstring:
// An account for a Music Service.
// 
//     Each service may have more than one account: see the `Sonos release notes
//     for version 5-2 <http://www.sonos.com/en-gb/software/release/5-2>`_
//     
//
// [music_services/accounts.py:59] Account._get_account_xml docstring:
// Fetch the account data from a Sonos device.
// 
//         Args:
//             soco (SoCo): a SoCo instance to query. If soco is `None`, a
//                 random device will be used.
// 
//         Returns:
//             str: a byte string containing the account data xml
//         
//
// [music_services/accounts.py:81] Account.get_accounts docstring:
// Get all accounts known to the Sonos system.
// 
//         Args:
//             soco (`SoCo`, optional): a `SoCo` instance to query. If `None`, a
//                 random instance is used. Defaults to `None`.
// 
//         Returns:
//             dict: A dict containing account instances. Each key is the
//             account's serial number, and each value is the related Account
//             instance. Accounts which have been marked as deleted are excluded.
// 
//         Note:
//             Any existing Account instance will have its attributes updated
//             to those currently stored on the Sonos system.
//         
//
// [music_services/accounts.py:181] Account.get_accounts_for_service docstring:
// Get a list of accounts for a given music service.
// 
//         Args:
//             service_type (str): The service_type to use.
// 
//         Returns:
//             list: A list of `Account` instances.
//         
//
// [music_services/accounts.py:1] Disable while we have Python 2.x compatability
// [music_services/accounts.py:2] pylint: disable=useless-object-inheritance,no-else-continue
// [music_services/accounts.py:14] pylint: disable=C0103
// [music_services/accounts.py:28] : str: A unique identifier for the music service to which this
// [music_services/accounts.py:29] : account relates, eg ``'2311'`` for Spotify.
// [music_services/accounts.py:31] : str: A unique identifier for this account
// [music_services/accounts.py:33] : str: The account's nickname
// [music_services/accounts.py:35] : bool: `True` if this account has been deleted
// [music_services/accounts.py:37] : str: The username used for logging into the music service
// [music_services/accounts.py:39] : str: Metadata for the account
// [music_services/accounts.py:41] : str: Used for OpenAuth id for some services
// [music_services/accounts.py:43] : str: Used for OpenAuthid for some services
// [music_services/accounts.py:69] It is likely that the same information is available over UPnP as well
// [music_services/accounts.py:70] via a call to
// [music_services/accounts.py:71] systemProperties.GetStringX([('VariableName','R_SvcAccounts')]))
// [music_services/accounts.py:72] This returns an encrypted string, and, so far, we cannot decrypt it
// [music_services/accounts.py:99] _get_account_xml returns an ElementTree element like this:
// [music_services/accounts.py:101] <ZPSupportInfo type="User">
// [music_services/accounts.py:102] <Accounts
// [music_services/accounts.py:103] LastUpdateDevice="RINCON_000XXXXXXXX400"
// [music_services/accounts.py:104] Version="8" NextSerialNum="5">
// [music_services/accounts.py:105] <Account Type="2311" SerialNum="1">
// [music_services/accounts.py:106] <UN>12345678</UN>
// [music_services/accounts.py:107] <MD>1</MD>
// [music_services/accounts.py:108] <NN></NN>
// [music_services/accounts.py:109] <OADevID></OADevID>
// [music_services/accounts.py:110] <Key></Key>
// [music_services/accounts.py:111] </Account>
// [music_services/accounts.py:112] <Account Type="41735" SerialNum="3" Deleted="1">
// [music_services/accounts.py:113] <UN></UN>
// [music_services/accounts.py:114] <MD>1</MD>
// [music_services/accounts.py:115] <NN>Nickname</NN>
// [music_services/accounts.py:116] <OADevID></OADevID>
// [music_services/accounts.py:117] <Key></Key>
// [music_services/accounts.py:118] </Account>
// [music_services/accounts.py:119] ...
// [music_services/accounts.py:120] <Accounts />
// [music_services/accounts.py:127] cls._all_accounts is a weakvaluedict keyed by serial number.
// [music_services/accounts.py:128] We use it as a database to store details of the accounts we
// [music_services/accounts.py:129] know about. We need to update it with info obtained from the
// [music_services/accounts.py:130] XML just obtained, so (1) check to see if we already have an
// [music_services/accounts.py:131] entry in cls._all_accounts for the account we have found in
// [music_services/accounts.py:132] XML; (2) if so, delete it if the XML says it has been deleted;
// [music_services/accounts.py:133] and (3) if not, create an entry for it
// [music_services/accounts.py:135] We have an existing entry in our database. Do we need to
// [music_services/accounts.py:136] delete it?
// [music_services/accounts.py:138] Yes, so delete it and move to the next XML account
// [music_services/accounts.py:142] No, so load up its details, ready to update them
// [music_services/accounts.py:145] We have no existing entry for this account
// [music_services/accounts.py:147] but it is marked as deleted, so we don't need one
// [music_services/accounts.py:149] If it is not marked as deleted, we need to create an entry
// [music_services/accounts.py:154] Now, update the entry in our database with the details from XML
// [music_services/accounts.py:158] Not sure what 'MD' stands for.  Metadata? May Delete?
// [music_services/accounts.py:164] There is always a TuneIn account, but it is handled separately
// [music_services/accounts.py:165] by Sonos, and does not appear in the xml account data. We
// [music_services/accounts.py:166] need to add it ourselves.
// [music_services/accounts.py:168] Is this always the case?

// MARK: - Original commentary: music_services/data_structures.py
// [music_services/data_structures.py:1] module docstring:
// Data structures for music service items
// 
// The basis for this implementation is this page in the Sonos API
// documentation: http://musicpartners.sonos.com/node/83
// 
// A note about naming. The Sonos API uses camel case with starting lower
// case. These names have been adapted to match general Python class
// naming conventions.
// 
// MediaMetadata:
//     Track
//     Stream
//     Show
//     Other
// 
// MediaCollection:
//     Artist
//     Album
//     Genre
//     Playlist
//     Search
//     Program
//     Favorites
//     Favorite
//     Collection
//     Container
//     AlbumList
//     TrackList
//     StreamList
//     ArtistTrackList
//     Other
// 
// NOTE: "Other" is allowed under both.
// 
// Class overview:
// 
// +----------------+   +----------------+   +---------------+
// |MetadataDictBase+-->+MusicServiceItem+-->+MediaCollection|
// +-----+----------+   +--------+-------+   +---------------+
//       |                       |
//       |                       |     +------------------+
//       |                       +---->+  MediaMetadata   |
//       |                             |                  |
//       |                             | +-------------+  |
//       +------------------------------>+TrackMetadata|  |
//       |                             | +-------------+  |
//       |                             |                  |
//       |                             | +--------------+ |
//       +------------------------------>+StreamMetadata| |
//                                     | +--------------+ |
//                                     |                  |
//                                     +------------------+
// 
// 
//
// [music_services/data_structures.py:75] get_class docstring:
// Form a music service data structure class from the class key
// 
//     Args:
//         class_key (str): A concatenation of the base class (e.g. MediaMetadata)
//             and the class name
// 
//     Returns:
//         class: Subclass of MusicServiceItem
//     
//
// [music_services/data_structures.py:95] parse_response docstring:
// Parse the response to a music service query and return a SearchResult
// 
//     Args:
//         service (MusicService): The music service that produced the response
//         response (dict): The response from the soap client call
//         search_type (str): A string that indicates the search type that the
//             response is from
// 
//     Returns:
//         SearchResult: A SearchResult object
//     
//
// [music_services/data_structures.py:151] form_uri docstring:
// Form and return a music service item uri
// 
//     Args:
//         item_id (str): The item id
//         service (MusicService): The music service that the item originates from
//         is_track (bool): Whether the item_id is from a track or not
// 
//     Returns:
//         str: The music service item uri
//     
//
// [music_services/data_structures.py:173] bool_str docstring:
// Returns a boolean from a string imput of 'true' or 'false'
//
// [music_services/data_structures.py:181] MetadataDictBase docstring:
// Class used to parse metadata from kwargs
//
// [music_services/data_structures.py:193] MetadataDictBase.__init__ docstring:
// Initialize local variables
//
// [music_services/data_structures.py:213] MetadataDictBase.__getattr__ docstring:
// Return item from metadata in case of unknown attribute
//
// [music_services/data_structures.py:224] MusicServiceItem docstring:
// A base class for all music service items
//
// [music_services/data_structures.py:231] MusicServiceItem.__init__ docstring:
// Init music service item
// 
//         Args:
//             item_id (str): This is the Didl compatible id NOT the music item id
//             desc (str): A DIDL descriptor, default ``'RINCON_AssociatedZPUDN'
//             resources (list): List of DidlResource
//             uri (str): The uri for the location of the item
//             metdata_dict (dict): Mapping of metadata
//             music_service (MusicService): The MusicService instance the item
//                 originates from
//         
//
// [music_services/data_structures.py:269] MusicServiceItem.from_music_service docstring:
// Return an element instantiated from the information that a music
//         service has (alternative constructor)
// 
//         Args:
//             music_service (MusicService): The music service that content_dict
//                 originated from
//             content_dict (dict): The data to instantiate the music
//                 service item from
// 
//         Returns:
//             MusicServiceItem: A MusicServiceItem instance
//         
//
// [music_services/data_structures.py:296] MusicServiceItem.__str__ docstring:
// Return custom string representation
//
// [music_services/data_structures.py:302] MusicServiceItem.to_element docstring:
// Return an ElementTree Element representing this instance.
// 
//         Args:
//             include_namespaces (bool, optional): If True, include xml
//                 namespace attributes on the root element
// 
//         Return:
//             ~xml.etree.ElementTree.Element: The (XML) Element representation of
//                 this object
//         
//
// [music_services/data_structures.py:325] TrackMetadata docstring:
// Track metadata class
//
// [music_services/data_structures.py:362] StreamMetadata docstring:
// Stream metadata class
//
// [music_services/data_structures.py:389] MediaMetadata docstring:
// Base class for all media metadata items
//
// [music_services/data_structures.py:414] MediaCollection docstring:
// Base class for all mediaCollection items
//
// [music_services/data_structures.py:1] Disable while we have Python 2.x compatability
// [music_services/data_structures.py:2] pylint: disable=useless-object-inheritance
// [music_services/data_structures.py:70] For now we generate classes dynamically. This is shorter, but
// [music_services/data_structures.py:71] provides no custom documentation for all the different types.
// [music_services/data_structures.py:88] So MediaMetadataTrack turns into MSTrack
// [music_services/data_structures.py:114] The result to be parsed is in either searchResult or getMetadataResult
// [music_services/data_structures.py:125] Form the search metadata
// [music_services/data_structures.py:134] Upper case the first letter (used for the class_key)
// [music_services/data_structures.py:137] If there is only 1 result, it is not put in an array
// [music_services/data_structures.py:142] Form the class_key, which is a unique string for this type,
// [music_services/data_structures.py:143] formed by concatenating the result type with the item type. Turns
// [music_services/data_structures.py:144] into e.g: MediaMetadataTrack
// [music_services/data_structures.py:169] Type Helper
// [music_services/data_structures.py:180] Music Service item base classes
// [music_services/data_structures.py:184] The following two fields should be overwritten in subclasses
// [music_services/data_structures.py:186] _valid_fields is a set of valid fields
// [music_services/data_structures.py:189] _types is a dict of fields with non-string types and their convertion
// [music_services/data_structures.py:190] callables
// [music_services/data_structures.py:197] Check for invalid fields
// [music_services/data_structures.py:200] Really wanted to raise exceptions here, but as it
// [music_services/data_structures.py:201] turns out I have already encountered invalid fields
// [music_services/data_structures.py:202] from music services.
// [music_services/data_structures.py:205] Convert names and create metadata dict
// [music_services/data_structures.py:227] See comment in MetadataDictBase for explanation of these two attributes
// [music_services/data_structures.py:282] Form the item_id
// [music_services/data_structures.py:284] The hex prefix remains a mistery for now
// [music_services/data_structures.py:286] Form the uri
// [music_services/data_structures.py:289] Form resources and get desc
// [music_services/data_structures.py:313] We piggy back on the implementation in DidlItem
// [music_services/data_structures.py:316] This is ignored. Sonos gets the title from the item_id
// [music_services/data_structures.py:317] Ditto
// [music_services/data_structures.py:328] _valid_fields is a set of valid fields
// [music_services/data_structures.py:349] _types is a dict of fields with non-string types and their
// [music_services/data_structures.py:350] convertion callables
// [music_services/data_structures.py:365] _valid_fields is a set of valid fields
// [music_services/data_structures.py:378] _types is a dict of fields with non-string types and their
// [music_services/data_structures.py:379] convertion callables
// [music_services/data_structures.py:392] _valid_fields is a set of valid fields
// [music_services/data_structures.py:404] _types is a dict of fields with non-string types and their
// [music_services/data_structures.py:405] convertion callables
// [music_services/data_structures.py:409] We ignore types on the dynamic field
// [music_services/data_structures.py:410] 'dynamic': ???,
// [music_services/data_structures.py:417] _valid_fields is a set of valid fields
// [music_services/data_structures.py:436] _types is a dict of fields with non-string types and their
// [music_services/data_structures.py:437] convertion callables

// MARK: - Original commentary: music_services/music_service.py
// [music_services/music_service.py:1] module docstring:
// Sonos Music Services interface.
// 
// This module provides the MusicService class and related functionality.
// 
// Known problems:
// 
// 1. Not all music services follow the pattern layout for the
//    authentication information completely. This means that it might be
//    necessary to tweak the code for individual services. This is an
//    unfortunate result of Sonos not enforcing data hygiene of its
//    services. The implication for SoCo is that getting all services
//    to work will require more effort and the kind of broader testing we
//    will only get by putting the code out there. Hence, if you are an
//    early adopter of the music service code (added in version 0.26)
//    consider yourselves guinea pigs.
// 2. There currently is no way to reset an authentication, at least when
//    authentication has been performed for TIDAL (which uses device link
//    authentication), after it has been done once for a particular
//    household ID, it fails on subsequent attempts. What this might mean
//    is that if you lose the authentication tokens for such a service,
//    it may not be possible to generate new ones. Obviously, some method
//    must exist to reset this, but it is not presently implemented.
// 
//
// [music_services/music_service.py:45] MusicServiceSoapClient docstring:
// A SOAP client for accessing Music Services.
// 
//     This class handles all the necessary authentication for accessing
//     third party music services. You are unlikely to need to use it
//     yourself.
//     
//
// [music_services/music_service.py:53] MusicServiceSoapClient.__init__ docstring:
// 
//         Args:
//             endpoint (str): The SOAP endpoint. A url.
//             timeout (int): Timeout the connection after this number of
//                 seconds
//             music_service (`MusicService`): The MusicService object to which
//                 this client belongs.
//             token_store (`TokenStoreBase`): A token store instance. The token store is
//                 an instance of a subclass of `TokenStoreBase`
//             device (SoCo): (Optional) If provided this device will be used for the
//                 communication; if not, the device returned by `discovery.any_soco` will
//                 be used
//         
//
// [music_services/music_service.py:101] MusicServiceSoapClient.get_soap_header docstring:
// Generate the SOAP authentication header for the related service.
// 
//         This header contains all the necessary authentication details.
// 
//         Returns:
//             str: A string representation of the XML content of the SOAP
//                 header.
//         
//
// [music_services/music_service.py:157] MusicServiceSoapClient.call docstring:
// Call a method on the server.
// 
//         Args:
//             method (str): The name of the method to call.
//             args (List[Tuple[str, str]] or None): A list of (parameter,
//                 value) pairs representing the parameters of the method.
//                 Defaults to `None`.
// 
//         Returns:
//             ~collections.OrderedDict: An OrderedDict representing the response.
// 
//         Raises:
//             `MusicServiceException`: containing details of the error
//                 returned by the music service.
//         
//
// [music_services/music_service.py:287] MusicServiceSoapClient.begin_authentication docstring:
// Perform the first part of a Device or App Link authentication session
// 
//         See `begin_authentication` for details
// 
//         
//
// [music_services/music_service.py:317] MusicServiceSoapClient.complete_authentication docstring:
// Completes a previously initiated authentication session
// 
//         See `complete_authentication` for details
// 
//         
//
// [music_services/music_service.py:340] MusicService docstring:
// The MusicService class provides access to third party music services.
// 
//     Example:
// 
//         List all the services Sonos knows about:
// 
//         >>> from soco.music_services import MusicService
//         >>> print(MusicService.get_all_music_services_names())
//         ['Spotify', 'The Hype Machine', 'Saavn', 'Bandcamp',
//          'Stitcher SmartRadio', 'Concert Vault',
//          ...
//          ]
// 
//         Interact with TuneIn:
// 
//         >>> tunein = MusicService('TuneIn')
//         >>> print (tunein)
//         <MusicService 'TuneIn' at 0x10ad84e10>
// 
//         Browse an item. By default, the root item is used. An
//         :class:`~soco.data_structures.SearchResult` is returned (the output of print is
//         here indented for easier reading):
// 
//         >>> print(tunein.get_metadata())
//         SearchResult(
//           items=[
//             <soco.music_services.data_structures.MSContainer object at 0x7f58b038ac10>,
//             <soco.music_services.data_structures.MSContainer object at 0x7f58b038a340>,
//             <soco.music_services.data_structures.MSContainer object at 0x7f58b038a6d0>,
//             <soco.music_services.data_structures.MSContainer object at 0x7f58b038a310>,
//             <soco.music_services.data_structures.MSContainer object at 0x7f58b038a100>,
//             <soco.music_services.data_structures.MSContainer object at 0x7f58b038a910>
//           ],
//           search_type='browse'
//         )
// 
// 
//         Interact with Spotify (assuming you are subscribed):
// 
//         >>> spotify = MusicService('Spotify')
// 
//         Get some metadata about a specific track:
// 
//         >>> response =  spotify.get_media_metadata(
//         ... item_id='spotify:track:6NmXV4o6bmp704aPGyTVVG')
//         >>> print(dumps(response, indent=4))
//         {
//             "mediaMetadata": {
//                 "id": "spotify:track:6NmXV4o6bmp704aPGyTVVG",
//                 "itemType": "track",
//                 "title": "Bøn Fra Helvete (Live)",
//                 "mimeType": "audio/x-spotify",
//                 "trackMetadata": {
//                     "artistId": "spotify:artist:1s1DnVoBDfp3jxjjew8cBR",
//                     "artist": "Kaizers Orchestra",
//                     "albumId": "spotify:album:6K8NUknbPh5TGaKeZdDwSg",
//                     "album": "Mann Mot Mann (Ep)",
//                     "duration": "317",
//                     "albumArtURI":
//                     "http://o.scdn.co/image/7b76a5074416e83fa3f3cd...9",
//                     "canPlay": "true",
//                     "canSkip": "true",
//                     "canAddToFavorites": "true"
//                 }
//             }
//         }
//         or even a playlist:
// 
//         >>> response =  spotify.get_metadata(
//         ...    item_id='spotify:user:spotify:playlist:0FQk6BADgIIYd3yTLCThjg')
// 
//         Find the available search categories, and use them:
// 
//         >>> print(spotify.available_search_categories)
//         ['albums', 'tracks', 'artists']
//         >>> result =  spotify.search(category='artists', term='miles')
// 
// 
//     Note:
//         Some of this code is still unstable, and in particular the data
//         structures returned by methods such as `get_metadata` may change in
//         future.
//     
//
// [music_services/music_service.py:427] MusicService.__init__ docstring:
// 
//         Args:
//             service_name (str): The name of the music service, as returned by
//                 `get_all_music_services_names()`, eg 'Spotify', or 'TuneIn'
//             token_store (`TokenStoreBase`): A token store instance. If none is given,
//                 it will default to an instance of the `JsonFileTokenStore` using the
//                 'default' token collection. The token store must be an instance of a
//                 subclass of `TokenStoreBase`.
//             device (SoCo): (Optional) If provided this device will be used for the
//                 communication, if not the device returned by `discovery.any_soco` will
//                 be used
// 
//         Raises:
//             `MusicServiceException`
//         
//
// [music_services/music_service.py:489] MusicService._get_music_services_data_xml docstring:
// Fetch the music services data xml from a Sonos device.
// 
//         Args:
//             soco (SoCo): a SoCo instance to query. If none is specified, a
//                 random device will be used. Defaults to `None`.
// 
//         Returns:
//             str: a string containing the music services data xml
//         
//
// [music_services/music_service.py:507] MusicService._get_music_services_data docstring:
// Parse raw account data xml into a useful python datastructure.
// 
//         Returns:
//             dict: Each key is a service_type, and each value is a
//             `dict` containing relevant data.
//         
//
// [music_services/music_service.py:583] MusicService.get_all_music_services_names docstring:
// Get a list of the names of all available music services.
// 
//         These services have not necessarily been subscribed to.
// 
//         Returns:
//             list: A list of strings.
//         
//
// [music_services/music_service.py:594] MusicService.get_data_for_name docstring:
// Get the data relating to a named music service.
// 
//         Args:
//             service_name (str): The name of the music service for which data
//                 is required.
// 
//         Returns:
//             dict: Data relating to the music service.
// 
//         Raises:
//             `MusicServiceException`: if the music service cannot be found.
//         
//
// [music_services/music_service.py:612] MusicService._get_search_prefix_map docstring:
// Fetch and parse the service search category mapping.
// 
//         Standard Sonos search categories are 'all', 'artists', 'albums',
//         'tracks', 'playlists', 'genres', 'stations', 'tags'. Not all are
//         available for each music service
//         
//
// [music_services/music_service.py:679] MusicService.available_search_categories docstring:
// list:  The list of search categories (each a string) supported.
// 
//         May include ``'artists'``, ``'albums'``, ``'tracks'``, ``'playlists'``,
//         ``'genres'``, ``'stations'``, ``'tags'``, or others depending on the
//         service. Some services, such as Spotify, support ``'all'``, but do not
//         advertise it.
// 
//         Any of the categories in this list may be used as a value for
//         ``category`` in :meth:`search`.
// 
//         Example:
// 
//             >>> print(spotify.available_search_categories)
//             ['albums', 'tracks', 'artists']
//             >>> result =  spotify.search(category='artists', term='miles')
// 
// 
//         
//
// [music_services/music_service.py:700] MusicService.sonos_uri_from_id docstring:
// Get a uri which can be sent for playing.
// 
//         Args:
//             item_id (str): The unique id of a playable item for this music
//                 service, such as that returned in the metadata from
//                 `get_metadata`, eg ``spotify:track:2qs5ZcLByNTctJKbhAZ9JE``
// 
//         Returns:
//             str: A URI of the form: ``soco://spotify%3Atrack
//             %3A2qs5ZcLByNTctJKbhAZ9JE?sid=2311&sn=1`` which encodes the
//             ``item_id``, and relevant data from the account for the music
//             service. This URI can be sent to a Sonos device for playing,
//             and the device itself will retrieve all the necessary metadata
//             such as title, album etc.
//         
//
// [music_services/music_service.py:744] MusicService.desc docstring:
// str: The Sonos descriptor to use for this service.
// 
//         The Sonos descriptor is used as the content of the <desc> tag in
//         DIDL metadata, to indicate the relevant music service id.
//         
//
// [music_services/music_service.py:760] MusicService.begin_authentication docstring:
// Perform the first part of a Device or App Link authentication session
// 
//         This result of this is an authentication URL, which a user needs visit and
//         complete the necessary authentication on and then proceed to
//         `complete_authentication`
// 
//         .. note::
//            The `begin_authentication` and `complete_authentication` methods must be
//            completed **on the same `MusicService` instance** unless the `link_code`
//            and `link_device_id` values are passed to `complete_authentication`. These
//            two values can be found as attributes on the `MusicService` instance after
//            `begin_authentication` has been executed.
// 
//         Returns:
//             str: Registration URL used for service linking.
// 
//         
//
// [music_services/music_service.py:788] MusicService.complete_authentication docstring:
// Completes a previously initiated device or app link authentication session
// 
//         This method is the second part of a two-step authentication process, see
//         `begin_authentication` for details on the first part.
// 
//         Args:
//             link_code (str, optional): A link code generated from begin_authentication.
//                 If not provided, cached code will be used.
//             link_device_id (str, optional): A link device ID generated from
//                 begin_authentication. If not provided, cached device ID will be used.
// 
//         
//
// [music_services/music_service.py:842] MusicService.get_metadata docstring:
// Get metadata for a container or item.
// 
//         Args:
//             item (str or MusicServiceItem): The container or item to browse
//                 given either as a MusicServiceItem instance or as a str.
//                 Defaults to the root item.
//             index (int): The starting index. Default 0.
//             count (int): The maximum number of items to return. Default 100.
//             recursive (bool): Whether the browse should recurse into sub-items
//                 (Does not always work). Defaults to `False`.
// 
//         Returns:
//             ~collections.OrderedDict: The item or container's metadata,
//             or `None`.
// 
//         See also:
//             The Sonos `getMetadata API
//             <http://musicpartners.sonos.com/node/83>`_.
// 
//         
//
// [music_services/music_service.py:878] MusicService.search docstring:
// Search for an item in a category.
// 
//         Args:
//             category (str): The search category to use. Standard Sonos search
//                 categories are 'artists', 'albums', 'tracks', 'playlists',
//                 'genres', 'stations', 'tags'. Not all are available for each
//                 music service. Call available_search_categories for a list for
//                 this service.
//             term (str): The term to search for.
//             index (int): The starting index. Default 0.
//             count (int): The maximum number of items to return. Default 100.
// 
//         Returns:
//             ~collections.OrderedDict: The search results, or `None`.
// 
//         See also:
//             The Sonos `search API <http://musicpartners.sonos.com/node/86>`_
//         
//
// [music_services/music_service.py:916] MusicService.get_media_metadata docstring:
// Get metadata for a media item.
// 
//         Args:
//             item_id (str): The item for which metadata is required.
// 
//         Returns:
//             ~collections.OrderedDict: The item's metadata, or `None`
// 
//         See also:
//             The Sonos `getMediaMetadata API
//             <http://musicpartners.sonos.com/node/83>`_
//         
//
// [music_services/music_service.py:932] MusicService.get_media_uri docstring:
// Get a streaming URI for an item.
// 
//         Note:
//            You should not need to use this directly. It is used by the Sonos
//            players (not the controllers) to obtain the uri of the media
//            stream. If you want to have a player play a media item,
//            you should add it to the queue using its id and let the
//            player work out where to get the stream from (see `On Demand
//            Playback <http://musicpartners.sonos.com/node/421>`_ and
//            `Programmed Radio <http://musicpartners.sonos.com/node/422>`_)
// 
//         Args:
//             item_id (str): The item for which the URI is required
// 
//         Returns:
//             str: The item's streaming URI.
//         
//
// [music_services/music_service.py:953] MusicService.get_last_update docstring:
// Get last_update details for this music service.
// 
//         Returns:
//             ~collections.OrderedDict: A dict with keys 'catalog',
//             and 'favorites'. The value of each is a string which changes
//             each time the catalog or favorites change. You can use this to
//             detect when any caches need to be updated.
//         
//
// [music_services/music_service.py:967] MusicService.get_extended_metadata docstring:
// Get extended metadata for a media item, such as related items.
// 
//         Args:
//             item_id (str): The item for which metadata is required.
// 
//         Returns:
//             ~collections.OrderedDict: The item's extended metadata or None.
// 
//         See also:
//             The Sonos `getExtendedMetadata API
//             <http://musicpartners.sonos.com/node/128>`_
//         
//
// [music_services/music_service.py:983] MusicService.get_extended_metadata_text docstring:
// Get extended metadata text for a media item.
// 
//         Args:
//             item_id (str): The item for which metadata is required
//             metadata_type (str): The type of text to return, eg
//             ``'ARTIST_BIO'``, or ``'ALBUM_NOTES'``. Calling
//             `get_extended_metadata` for the item will show which extended
//             metadata_types are available (under relatedBrowse and relatedText).
// 
//         Returns:
//             str: The item's extended metadata text or None
// 
//         See also:
//             The Sonos `getExtendedMetadataText API
//             <http://musicpartners.sonos.com/node/127>`_
//         
//
// [music_services/music_service.py:1] pylint: disable=fixme
// [music_services/music_service.py:41] pylint: disable=C0103
// [music_services/music_service.py:44] pylint: disable=protected-access
// [music_services/music_service.py:76] Spotify uses gzip. Others may do so as well. Unzipping is handled
// [music_services/music_service.py:77] for us by the requests library. Google Play seems to be very fussy
// [music_services/music_service.py:78] about the user-agent string. The firmware release number (after
// [music_services/music_service.py:79] 'Sonos/') has to be '26' for some reason to get Google Play to
// [music_services/music_service.py:80] work. Although we have access to a real SONOS user agent
// [music_services/music_service.py:81] string (one is returned, eg, in the SERVER header of discovery
// [music_services/music_service.py:82] packets and looks like this: Linux UPnP/1.0 Sonos/29.5-91030 (
// [music_services/music_service.py:83] ZPS3)) it is a bit too much trouble here to access it, and Google
// [music_services/music_service.py:84] Play does not like it anyway.
// [music_services/music_service.py:111] According to the SONOS SMAPI, this header must be sent with all
// [music_services/music_service.py:112] SOAP requests. Building this is an expensive operation (though
// [music_services/music_service.py:113] occasionally necessary), so if we have a cached value, return it.
// [music_services/music_service.py:124] Add context
// [music_services/music_service.py:128] If no existing authentication is known, we do not add 'token' and 'key'
// [music_services/music_service.py:129] elements and the only operation the service can perform is to authenticate
// [music_services/music_service.py:135] Fill in from saved tokens
// [music_services/music_service.py:148] TODO Implement UserID with user provided account, since we can't get the
// [music_services/music_service.py:149] accounts from the device anymore
// [music_services/music_service.py:151] Anonymous auth. No need for anything further.
// [music_services/music_service.py:209] Remove any cached value for the SOAP header
// [music_services/music_service.py:212] Extract new token and key from the error message
// [music_services/music_service.py:213] <detail xmlns:ms="http://www.sonos.com/Services/1.1">
// [music_services/music_service.py:214] <ms:RefreshAuthTokenResult>
// [music_services/music_service.py:215] <ms:authToken>xxxxxxx</ms:authToken>
// [music_services/music_service.py:216] <ms:privateKey>yyyyyy</ms:privateKey>
// [music_services/music_service.py:217] </ms:RefreshAuthTokenResult>
// [music_services/music_service.py:218] </detail>
// [music_services/music_service.py:235] If we didn't find the tokens, raise
// [music_services/music_service.py:241] Create new token pair and save it
// [music_services/music_service.py:249] With the new token pair in hand, attempt a new call
// [music_services/music_service.py:275] The top key in the OrderedDict will be the methodResult. Its
// [music_services/music_service.py:276] value may be None if no results were returned.
// [music_services/music_service.py:336] Delete the soap header, which will force it to rebuild
// [music_services/music_service.py:449] Look up the data for this service
// [music_services/music_service.py:457] Auth_type can be 'Anonymous', 'UserId, 'DeviceLink' and 'AppLink'
// [music_services/music_service.py:460] Certain music services doesn't have a PresentationMapUri element, but
// [music_services/music_service.py:461] deliver it instead through a manifest. Get the URI for it to prepare
// [music_services/music_service.py:462] for parsing.
// [music_services/music_service.py:468] Cached values used between begin_authentication and complete_authentication
// [music_services/music_service.py:475] The default is 60
// [music_services/music_service.py:514] Return from cache if we have it
// [music_services/music_service.py:520] <Services SchemaVersion="1">
// [music_services/music_service.py:521] <Service Id="163" Name="Spreaker" Version="1.1"
// [music_services/music_service.py:522] Uri="http://sonos.spreaker.com/sonos/service/v1"
// [music_services/music_service.py:523] SecureUri="https://sonos.spreaker.com/sonos/service/v1"
// [music_services/music_service.py:524] ContainerType="MService"
// [music_services/music_service.py:525] Capabilities="513"
// [music_services/music_service.py:526] MaxMessagingChars="0">
// [music_services/music_service.py:527] <Policy Auth="Anonymous" PollInterval="30" />
// [music_services/music_service.py:528] <Presentation>
// [music_services/music_service.py:529] <Strings
// [music_services/music_service.py:530] Version="1"
// [music_services/music_service.py:531] Uri="https:...string_table.xml" />
// [music_services/music_service.py:532] <PresentationMap Version="2"
// [music_services/music_service.py:533] Uri="https://...presentation_map.xml" />
// [music_services/music_service.py:534] </Presentation>
// [music_services/music_service.py:535] </Service>
// [music_services/music_service.py:536] ...
// [music_services/music_service.py:537] </ Services>
// [music_services/music_service.py:539] Ideally, the search path should be './/Service' to find Service
// [music_services/music_service.py:540] elements at any level, but Python 2.6 breaks with this if Service
// [music_services/music_service.py:541] is a child of the current element. Since 'Service' works here, we use
// [music_services/music_service.py:542] that instead
// [music_services/music_service.py:552] Get presentation map
// [music_services/music_service.py:556] FIXME these strings seems to have definitions of
// [music_services/music_service.py:557] custom search categories, check whether it is
// [music_services/music_service.py:558] implemented
// [music_services/music_service.py:559] FIXME is this right, or are we getting the same element twice?
// [music_services/music_service.py:562] Get manifest information if available
// [music_services/music_service.py:568] ServiceType is used elsewhere in Sonos, eg to form tokens,
// [music_services/music_service.py:569] and get_subscribed_music_services() below. It is also the
// [music_services/music_service.py:570] 'Type' used in account_xml (see above). Its value always
// [music_services/music_service.py:571] seems to be (ID*256) + 7. Some serviceTypes are also
// [music_services/music_service.py:572] listed in available_services['AvailableServiceTypeList']
// [music_services/music_service.py:573] but this does not seem to be comprehensive
// [music_services/music_service.py:578] Cache this so we don't need to do it again
// [music_services/music_service.py:619] TuneIn does not have a pmap. Its search keys are is search:station,
// [music_services/music_service.py:620] search:show, search:host
// [music_services/music_service.py:622] Presentation maps can also define custom categories. See eg
// [music_services/music_service.py:623] http://sonos-pmap.ws.sonos.com/hypemachine_pmap.6.xml
// [music_services/music_service.py:624] <SearchCategories>
// [music_services/music_service.py:625] ...
// [music_services/music_service.py:626] <CustomCategory mappedId="SBLG" stringId="Blogs"/>
// [music_services/music_service.py:627] </SearchCategories>
// [music_services/music_service.py:628] Is it already cached? If so, return it
// [music_services/music_service.py:631] Not cached. Fetch and parse presentation map
// [music_services/music_service.py:633] Tunein is a special case. It has no pmap, but supports searching
// [music_services/music_service.py:642] Certain music services delivers the presentation map not in an
// [music_services/music_service.py:643] information field of its own, but in a JSON 'manifest'. Get it
// [music_services/music_service.py:644] and extract the needed values.
// [music_services/music_service.py:656] Assume not searchable?
// [music_services/music_service.py:661] Search translations can appear in Category or CustomCategory elements
// [music_services/music_service.py:666] The latter part `or cat.get("id")` is added as a workaround for a
// [music_services/music_service.py:667] Navidrome + bonob setup, where the category ids are delivered on this key
// [music_services/music_service.py:668] instead of `mappedId` like for most other services. Reference:
// [music_services/music_service.py:669] https://github.com/SoCo/SoCo/pull/869#issuecomment-991353397
// [music_services/music_service.py:716] Real Sonos URIs look like this:
// [music_services/music_service.py:717] x-sonos-http:tr%3a92352286.mp3?sid=2&flags=8224&sn=4 The
// [music_services/music_service.py:718] extension (.mp3) presumably comes from the mime-type returned in a
// [music_services/music_service.py:719] MusicService.get_metadata() result (though for Spotify the mime-type
// [music_services/music_service.py:720] is audio/x-spotify, and there is no extension. See
// [music_services/music_service.py:721] http://musicpartners.sonos.com/node/464 for supported mime-types and
// [music_services/music_service.py:722] related extensions). The scheme (x-sonos-http) presumably
// [music_services/music_service.py:723] indicates how the player is to obtain the stream for playing. It
// [music_services/music_service.py:724] is not clear what the flags param is used for (perhaps bitrate,
// [music_services/music_service.py:725] or certain metadata such as canSkip?). Fortunately, none of these
// [music_services/music_service.py:726] seems to be necessary. We can leave them out, (or in the case of
// [music_services/music_service.py:727] the scheme, use 'soco' as dummy text, and the players still seem
// [music_services/music_service.py:728] to do the right thing.
// [music_services/music_service.py:730] quote_url will break if given unicode on Py2.6, and early 2.7. So
// [music_services/music_service.py:731] we need to encode.
// [music_services/music_service.py:733] Add the account info to the end as query params
// [music_services/music_service.py:735] FIXME we no longer have accounts, so for now the serial
// [music_services/music_service.py:736] numbers is assumed to be 0. Originally it was read from
// [music_services/music_service.py:737] account.serial_numbers
// [music_services/music_service.py:738] account = self.account
// [music_services/music_service.py:751] It used to be that the second part (after the second _ was the username
// [music_services/music_service.py:756] This seems to at least be the case for TuneIn
// [music_services/music_service.py:811] #######################################################################
// [music_services/music_service.py:812] #
// [music_services/music_service.py:813] SOAP METHODS.                              #
// [music_services/music_service.py:814] #
// [music_services/music_service.py:815] #######################################################################
// [music_services/music_service.py:817] Looking at various services, we see that the following SOAP methods
// [music_services/music_service.py:818] are implemented, but not all in each service. Probably, the
// [music_services/music_service.py:819] Capabilities property indicates which features are implemented, but
// [music_services/music_service.py:820] it is not clear precisely how. Some of the more common/useful
// [music_services/music_service.py:821] features have been wrapped into instance methods, below.
// [music_services/music_service.py:822] See generally: http://musicpartners.sonos.com/node/81
// [music_services/music_service.py:824] createItem(xs:string favorite)
// [music_services/music_service.py:825] createTrialAccount(xs:string deviceId)
// [music_services/music_service.py:826] deleteItem(xs:string favorite)
// [music_services/music_service.py:827] getAccount()
// [music_services/music_service.py:828] getExtendedMetadata(xs:string id)
// [music_services/music_service.py:829] getExtendedMetadataText(xs:string id, xs:string Type)
// [music_services/music_service.py:830] getLastUpdate()
// [music_services/music_service.py:831] getMediaMetadata(xs:string id)
// [music_services/music_service.py:832] getMediaURI(xs:string id)
// [music_services/music_service.py:833] getMetadata(xs:string id, xs:int index, xs:int count,xs:boolean
// [music_services/music_service.py:834] recursive)
// [music_services/music_service.py:835] getScrollIndices(xs:string id)
// [music_services/music_service.py:836] getSessionId(xs:string username, xs:string password)
// [music_services/music_service.py:837] mergeTrialccount(xs:string deviceId)
// [music_services/music_service.py:838] rateItem(id id, xs:integer rating)
// [music_services/music_service.py:839] search(xs:string id, xs:string term, xs:string index, xs:int count)
// [music_services/music_service.py:840] setPlayedSeconds(id id, xs:int seconds)
// [music_services/music_service.py:864] pylint: disable=no-member
// [music_services/music_service.py:962] TODO: Maybe create a favorites/catalog cache which is invalidated
// [music_services/music_service.py:963] TODO: when these values change?

// MARK: - Original commentary: music_services/token_store.py
// [music_services/token_store.py:1] module docstring:
// This module implements token stores for the music services
// 
// A user can provide their own token store depending on how that person
// wishes to save the tokens, or use the builtin token store (the default)
// which saves the tokens in a config file.
// 
//
// [music_services/token_store.py:14] TokenStoreBase docstring:
// Token store base class
//
// [music_services/token_store.py:17] TokenStoreBase.__init__ docstring:
// Instantiate instance variables
// 
//         Args:
//             token_collection (str): The name of the token collection to use. This may be
//                 used to store different token collections for different client programs.
//         
//
// [music_services/token_store.py:26] TokenStoreBase.save_token_pair docstring:
// Save a token value pair (token, key) which is a 2 item sequence
//
// [music_services/token_store.py:30] TokenStoreBase.load_token_pair docstring:
// Load a token pair (token, key) which is a 2 item sequence
//
// [music_services/token_store.py:34] TokenStoreBase.has_token docstring:
// Return True if a token is stored for the music service and household ID
//
// [music_services/token_store.py:39] JsonFileTokenStore docstring:
// Implementation of a token store around a JSON file
//
// [music_services/token_store.py:42] JsonFileTokenStore.__init__ docstring:
// Instantiate instance variables
// 
//         Args:
//             token_collection (str): The name of the token collection to use. This may be
//                 used to store different token collections for different client programs.
// 
//         
//
// [music_services/token_store.py:59] JsonFileTokenStore.from_config_file docstring:
// Load from file in config directory location
// 
//         Args:
//             token_collection (str): The name of the token collection to use. This may be
//                 used to store different token collections for different client programs.
//         
//
// [music_services/token_store.py:70] JsonFileTokenStore.save_collection docstring:
// Save the collection to a config file
//
// [music_services/token_store.py:78] JsonFileTokenStore.save_token_pair docstring:
// Save a token value pair (token, key) which is a 2 item sequence
//
// [music_services/token_store.py:87] JsonFileTokenStore.load_token_pair docstring:
// Load a token pair (token, key) which is a 2 item sequence
//
// [music_services/token_store.py:93] JsonFileTokenStore.has_token docstring:
// Return True if a token is stored for the music service
//
// [music_services/token_store.py:100] JsonFileTokenStore._create_jsonable_key docstring:
// Return a JSON-able dictionary key created from music_service_id and
//         household_id
//

// MARK: - Original commentary: plugins/__init__.py
// [plugins/__init__.py:1] module docstring:
// This is the __init__ module for the plugins.
// 
// It contains the base class for all plugins
//
// [plugins/__init__.py:17] SoCoPlugin docstring:
// The base class for SoCo plugins.
//
// [plugins/__init__.py:26] SoCoPlugin.name docstring:
// Human-readable name of the plugin
//
// [plugins/__init__.py:31] SoCoPlugin.from_name docstring:
// Instantiate a plugin by its full name.
//
// [plugins/__init__.py:1] pylint: disable=R0201,E0711
// [plugins/__init__.py:3] Disable while we have Python 2.x compatability
// [plugins/__init__.py:4] pylint: disable=useless-object-inheritance

// MARK: - Original commentary: plugins/example.py
// [plugins/example.py:1] module docstring:
// Example implementation of a plugin.
//
// [plugins/example.py:8] ExamplePlugin docstring:
// This file serves as an example of a SoCo plugin.
//
// [plugins/example.py:11] ExamplePlugin.__init__ docstring:
// Initialize the plugin.
// 
//         The plugin can accept any arguments it requires. It should at
//         least accept a soco instance which it passes on to the base
//         class when calling super's __init__.
//         
//
// [plugins/example.py:25] ExamplePlugin.music_plugin_play docstring:
// Play some music.
// 
//         This is just a reimplementation of the ordinary play function,
//         to show how we can use the general upnp methods from soco
//         
//
// [plugins/example.py:36] ExamplePlugin.music_plugin_stop docstring:
// Stop the music.
// 
//         This methods shows how, if we need it, we can use the soco
//         functionality from inside the plugins
//         
//

// MARK: - Original commentary: plugins/plex.py
// [plugins/plex.py:1] module docstring:
// This plugin supports playback from a linked Plex music service.
// See: https://support.plex.tv/articles/218168898-installing-plex-for-sonos/
// 
// Requires:
//     * Plex music service must be linked in the Sonos app
//     * Use of 'plexapi' library (https://github.com/pkkid/python-plexapi)
//     * Plex server URI used in 'plexapi' must be reachable from Sonos speakers
// 
//     Example usage:
// 
//         >>> from plexapi.server import PlexServer
//         >>> from soco import SoCo
//         >>> from soco.plugins.plex import PlexPlugin
//         >>>
//         >>> s = SoCo("<SPEAKER_IP>")
//         >>> plugin = PlexPlugin(s)
//         >>>
//         >>> plex_uri = "http://1.2.3.4:32400"
//         >>> plex_token = "<YOUR_PLEX_TOKEN>"
//         >>> plex = PlexServer(plex_uri, token=plex_token)
//         >>> music = plex.library.section("Music")
//         >>> artist = music.get("Stevie Wonder")
//         >>> album = artist.album("Innervisions")
//         >>> track = album.tracks()[4]
//         >>> playlist = plex.playlist("My Playlist")
//         >>>
//         >>> plugin.play_now(artist)     # Play all tracks from an artist
//         >>> plugin.add_to_queue(track)  # Add track to the end of queue
//         >>> pos = plugin.add_to_queue([album, playlist])  # Enqueue multiple
//         >>> s.play_from_queue(pos)      # Play items just enqueued
//
// [plugins/plex.py:71] PlexPlugin docstring:
// A SoCo plugin for playing Plex media using the plexapi library.
//
// [plugins/plex.py:74] PlexPlugin.__init__ docstring:
// Initialize the plugin.
//
// [plugins/plex.py:80] PlexPlugin.name docstring:
// Return the name of the plugin.
//
// [plugins/plex.py:85] PlexPlugin.service_name docstring:
// Return the service name of the Plex music service.
//
// [plugins/plex.py:90] PlexPlugin.service_info docstring:
// Cache and return the service info of the Plex music service.
//
// [plugins/plex.py:97] PlexPlugin.service_id docstring:
// Return the service ID of the Plex music service.
//
// [plugins/plex.py:102] PlexPlugin.service_type docstring:
// Return the service type of the Plex music service.
//
// [plugins/plex.py:106] PlexPlugin.play_now docstring:
// Add the media to the end of the queue and immediately begin playback.
//
// [plugins/plex.py:111] PlexPlugin.add_to_queue docstring:
// Add the provided media to the speaker's playback queue.
// 
//         Args:
//             plex_media (plexapi): The plexapi object representing the Plex media
//                 to be enqueued. Can be one of plexapi.audio.Track,
//                 plexapi.audio.Album, plexapi.audio.Artist or
//                 plexapi.playlist.Playlist. Can also be a list of the above items.
//             position (int): The index (1-based) at which the media should be
//                 added. Default is 0 (append to the end of the queue).
//             as_next (bool): Whether this media should be played as the next
//                 track in shuffle mode. This only works if "play_mode=SHUFFLE".
// 
//                 Note: Enqueuing multi-track items like albums or playlists will
//                 select one track randomly as the next item and shuffle the
//                 remaining tracks throughout the queue.
// 
//         Returns:
//             int: The index of the first item added to the queue.
//         
//
// [plugins/plex.py:131] Handle a list of Plex media items
// [plugins/plex.py:135] If inserting into the queue, repeatedly insert the items in reverse order
// [plugins/plex.py:140] Insert each item at the initial queue position in reverse order
// [plugins/plex.py:147] Append each item to the end of the queue in order
// [plugins/plex.py:155] pylint: disable=protected-access
// [plugins/plex.py:188] pylint: disable=possibly-used-before-assignment

// MARK: - Original commentary: plugins/sharelink.py
// [plugins/sharelink.py:1] module docstring:
// ShareLink Plugin.
//
// [plugins/sharelink.py:9] ShareClass docstring:
// Base class for supported services.
//
// [plugins/sharelink.py:12] ShareClass.canonical_uri docstring:
// Recognize a share link and return its canonical representation.
// 
//         Args:
//             uri (str): A URI like "https://tidal.com/browse/album/157273956".
// 
//         Returns:
//             str: The canonical URI or None if not recognized.
//         
//
// [plugins/sharelink.py:23] ShareClass.service_number docstring:
// Return the service number.
// 
//         Returns:
//             int: A number identifying the supported music service.
//         
//
// [plugins/sharelink.py:32] ShareClass.magic docstring:
// Return magic.
// 
//         Returns:
//             dict: Magic prefix/key/class values for each share type.
//         
//
// [plugins/sharelink.py:71] ShareClass.extract docstring:
// Extract the share type and encoded URI from a share link.
// 
//         Returns:
//             share_type: The shared type, like "album" or "track".
//             encoded_uri: An escaped URI with a service-specific format.
//         
//
// [plugins/sharelink.py:81] SpotifyShare docstring:
// Spotify share class.
//
// [plugins/sharelink.py:103] SpotifyUSShare docstring:
// Spotify US share class.
//
// [plugins/sharelink.py:110] TIDALShare docstring:
// TIDAL share class.
//
// [plugins/sharelink.py:130] DeezerShare docstring:
// Deezer share class.
//
// [plugins/sharelink.py:152] AppleMusicShare docstring:
// Apple Music share class.
//
// [plugins/sharelink.py:190] ShareLinkPlugin docstring:
// A SoCo plugin for playing music service share links.
//
// [plugins/sharelink.py:193] ShareLinkPlugin.__init__ docstring:
// Initialize the plugin.
//
// [plugins/sharelink.py:208] ShareLinkPlugin.is_share_link docstring:
// bool: Is the URI for a supported music service.
//
// [plugins/sharelink.py:216] ShareLinkPlugin.add_share_link_to_queue docstring:
// Add a Spotify/Tidal/... item to the queue.
// 
//         This is similar to soco.add_uri_to_queue() but will work with
//         music service share links that do not directly point to sound
//         files.
// 
//         Args:
//             uri (str): A URI like "spotify:album:6wiUBliPe76YAVpNEdidpY".
//             position (int): The index (1-based) at which the URI should be
//                 added. Default is 0 (add URI at the end of the queue).
//             as_next (bool): Whether this URI should be played as the next
//                 track in shuffle mode. This only works if "play_mode=SHUFFLE".
//             **kwargs: any keyword arguments. If ``dc_title`` is specified,
//                 this will be used as the dc:title of the metadata_template.
//                 If not specified, the dc:title will be empty.
// 
//         Returns:
//             int: The index of the new item in the queue.
//         
//
// [plugins/sharelink.py:156] https://music.apple.com/dk/album/black-velvet/217502930?i=217503142
// [plugins/sharelink.py:163] https://music.apple.com/dk/album/amused-to-death/975952384
// [plugins/sharelink.py:168] Apple-created playlist
// [plugins/sharelink.py:169] https://music.apple.com/dk/playlist/power-ballads-essentials/pl.92e04ee75ed64804b9df468b5f45a161
// [plugins/sharelink.py:170] User-created playlist
// [plugins/sharelink.py:171] https://music.apple.com/de/playlist/unnamed-playlist/pl.u-rR2PCrLdLJk
// [plugins/sharelink.py:281] Try remaining services on failure but keep the exception
// [plugins/sharelink.py:282] around in case nothing succeeds.

// MARK: - Original commentary: plugins/spotify.py
// [plugins/spotify.py:1] module docstring:
// The Spotify plugin has been DEPRECATED
// 
// The Spotify Plugin has been immediately deprecated (August 2016),
// because the API it was based on (The Spotify Metadata API) has been
// ended. Since this rendered the plug-in broken, there was no need to
// forewarn of the deprecation.
// 
// Please consider moving to the new general music services code (in
// soco.music_services.music_service), that makes it possible to
// retrived information about the available media from all music
// services. A short intro for how to use the new code is available
// in the API documentation:
// 
//  * http://docs.python-soco.com/en/latest/api/soco.music_services.music_service.html
// 
// and for some information about how to add items from the music
// services to the queue, see this gist:
// 
//  * https://gist.github.com/lawrenceakka/2d21dca590b4fa7e3af2"
// 
// This deprecation notification will be deleted for the second release
// after 0.12.
// 
//
// [plugins/spotify.py:30] Only raise this import error if we are not building the docs

// MARK: - Original commentary: plugins/wimp.py
// [plugins/wimp.py:1] module docstring:
// Plugin for the Wimp music service (Service ID 20)
//
// [plugins/wimp.py:30] _post docstring:
// Try 3 times to request the content.
// 
//     :param headers: The HTTP headers
//     :type headers: dict
//     :param body: The body of the HTTP post
//     :type body: str
//     :param retries: The number of times to retry before giving up
//     :type retries: int
//     :param timeout: The time to wait for the post to complete, before timing
//         out
//     :type timeout: float
//     
//
// [plugins/wimp.py:60] _ns_tag docstring:
// Return a namespace/tag item. The ns_id is translated to a full name
//     space via the NS module variable.
// 
//     :param ns_id: The name space ID. Translated to a namespace via the module
//         variable NS
//     :type ns_id: str
//     :param tag: The tag
//     :type str: str
//     
//
// [plugins/wimp.py:73] _get_header docstring:
// Return the HTTP for SOAP Action.
// 
//     :param soap_action: The soap action to include in the header. Can be either
//         'search' or 'get_metadata'
//     :type soap_action: str
//     
//
// [plugins/wimp.py:100] Wimp docstring:
// Class that implements a Wimp plugin.
// 
//     Note:
//         There is an (apparent) in-consistency in the use of one data
//         type from the Wimp service. When searching for playlists, the XML
//         returned by the Wimp server indicates, that the type is an 'album
//         list', and it thus suggest, that this type is used for a list of
//         tracks (as expected for a playlist), and this data type is reported
//         to be playable. However, when browsing the music tree, the Wimp
//         server will return items of 'album list' type, but in this case it
//         is used for a list of albums and it is not playable. This plugin
//         maintains this (apparent) in-consistency to stick as close to the
//         reported data as possible, so search for playlists returns
//         MSAlbumList that are playable and while browsing the content tree
//         the MSAlbumList items returned to you are not playable.
// 
// 
//     Note:
//        Wimp in some cases lists tracks that are not available. In these
//        cases, while it will correctly report these tracks as not being
//        playable, the containing data structure like e.g. the album they are
//        on may report that they are playable. Trying to add one of these to
//        the queue will return a SoCoUPnPException with error code '802'.
// 
//     
//
// [plugins/wimp.py:127] Wimp.__init__ docstring:
// Initialize the plugin.
// 
//         :param soco: The soco instance to retrieve the session ID for the music
//             service
//         :type: :py:class:`soco.SoCo`
//         :param username: The username for the music service
//         :type username: str
//         :param retries: The number of times to retry before giving up
//         :type retries: int
//         :param timeout: The time to wait for the post to complete, before
//             timing out. The Wimp server seems either slow to respond or to
//             make the queries internally, so the timeout should probably not be
//             shorter than 3 seconds.
//         :type timeout: float
// 
//         Note:
// 
//             If you are using a phone number as the username and are
//             experiencing problems connecting, then try to prepend the area
//             code (no + or 00). I.e. if your phone number is 12345678 and you
//             are from denmark, then use 4512345678. This must be set up the
//             same way in the Sonos device.  For details see `here
//             <https://wimp.zendesk.com/hc/da/articles/204311810-Hvorfor-kan
//             -jeg-ikke-logge-p%C3%A5-WiMP-med-min-Sonos-n%C3%A5r-jeg-har-et
//             -gyldigt-abonnement->`_ (In Danish)
//         
//
// [plugins/wimp.py:171] Wimp.name docstring:
// Return the human read-able name for the plugin
//
// [plugins/wimp.py:176] Wimp.username docstring:
// Return the username.
//
// [plugins/wimp.py:181] Wimp.service_id docstring:
// Return the service id.
//
// [plugins/wimp.py:186] Wimp.description docstring:
// Return the music service description for the DIDL metadata on the
//         form ``'SA_RINCON5127_...self.username...'``
//
// [plugins/wimp.py:191] Wimp.get_tracks docstring:
// Search for tracks.
// 
//         See get_music_service_information for details on the arguments
//         
//
// [plugins/wimp.py:198] Wimp.get_albums docstring:
// Search for albums.
// 
//         See get_music_service_information for details on the arguments
//         
//
// [plugins/wimp.py:205] Wimp.get_artists docstring:
// Search for artists.
// 
//         See get_music_service_information for details on the arguments
//         
//
// [plugins/wimp.py:212] Wimp.get_playlists docstring:
// Search for playlists.
// 
//         See get_music_service_information for details on the arguments.
// 
//         Note:
// 
//             Un-intuitively this method returns MSAlbumList items. See
//             note in class doc string for details.
//         
//
// [plugins/wimp.py:224] Wimp.get_music_service_information docstring:
// Search for music service information items.
// 
//         :param search_type: The type of search to perform, possible values are:
//             'artists', 'albums', 'tracks' and 'playlists'
//         :type search_type: str
//         :param search: The search string to use
//         :type search: str
//         :param start: The starting index of the returned items
//         :type start: int
//         :param max_items: The maximum number of returned items
//         :type max_items: int
// 
//         Note:
//             Un-intuitively the playlist search returns MSAlbumList
//             items. See note in class doc string for details.
//         
//
// [plugins/wimp.py:273] Wimp.browse docstring:
// Return the sub-elements of item or of the root if item is None
// 
//         :param item: Instance of sub-class of
//             :py:class:`soco.data_structures.MusicServiceItem`. This object must
//             have item_id, service_id and extended_id properties
// 
//         Note:
//             Browsing a MSTrack item will return itself.
// 
//         Note:
//             This plugin cannot yet set the parent ID of the results
//             correctly when browsing
//             :py:class:`soco.data_structures.MSFavorites` and
//             :py:class:`soco.data_structures.MSCollection` elements.
// 
//         
//
// [plugins/wimp.py:336] Wimp.id_to_extended_id docstring:
// Return the extended ID from an ID.
// 
//         :param item_id: The ID of the music library item
//         :type item_id: str
//         :param cls: The class of the music service item
//         :type cls: Sub-class of
//             :py:class:`soco.data_structures.MusicServiceItem`
// 
//         The extended id can be something like 00030020trackid_22757082
//         where the id is just trackid_22757082. For classes where the prefix is
//         not known returns None.
//         
//
// [plugins/wimp.py:355] Wimp.form_uri docstring:
// Form the URI for a music service element.
// 
//         :param item_content: The content dict of the item
//         :type item_content: dict
//         :param item_class: The class of the item
//         :type item_class: Sub-class of
//             :py:class:`soco.data_structures.MusicServiceItem`
//         
//
// [plugins/wimp.py:372] Wimp._search_body docstring:
// Return the search XML body.
// 
//         :param search_type: The search type
//         :type search_type: str
//         :param search_term: The search term e.g. 'Jon Bon Jovi'
//         :type search_term: str
//         :param start: The start index of the returned results
//         :type start: int
//         :param max_items: The maximum number of returned results
//         :type max_items: int
// 
//         The XML is formed by adding, to the envelope of the XML returned by
//         ``self._base_body``, the following ``Body`` part:
// 
//         .. code :: xml
// 
//          <s:Body>
//            <search xmlns="http://www.sonos.com/Services/1.1">
//              <id>search_type</id>
//              <term>search_term</term>
//              <index>start</index>
//              <count>max_items</count>
//            </search>
//          </s:Body>
//         
//
// [plugins/wimp.py:411] Wimp._browse_body docstring:
// Return the browse XML body.
// 
//         The XML is formed by adding, to the envelope of the XML returned by
//         ``self._base_body``, the following ``Body`` part:
// 
//         .. code :: xml
// 
//          <s:Body>
//            <getMetadata xmlns="http://www.sonos.com/Services/1.1">
//              <id>root</id>
//              <index>0</index>
//              <count>100</count>
//            </getMetadata>
//          </s:Body>
// 
//         .. note:: The XML contains index and count, but the service does not
//         seem to respect them, so therefore they have not been included as
//         arguments.
//         
//
// [plugins/wimp.py:444] Wimp._base_body docstring:
// Return the base XML body, which has the following form:
// 
//         .. code :: xml
// 
//          <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/">
//            <s:Header>
//              <credentials xmlns="http://www.sonos.com/Services/1.1">
//                <sessionId>self._session_id</sessionId>
//                <deviceId>self._serial_number</deviceId>
//                <deviceProvider>Sonos</deviceProvider>
//              </credentials>
//            </s:Header>
//          </s:Envelope>
//         
//
// [plugins/wimp.py:474] Wimp._check_for_errors docstring:
// Check a response for errors.
// 
//         :param response: the response from requests.post()
//         
//
// [plugins/wimp.py:1] pylint: disable=star-args
// [plugins/wimp.py:48] Due to a bug in requests, the post command will sometimes fail to
// [plugins/wimp.py:49] properly wrap a socket.timeout exception in requests own exception.
// [plugins/wimp.py:50] See https://github.com/kennethreitz/requests/issues/2045
// [plugins/wimp.py:51] Until this is fixed, we need to catch both types of exceptions
// [plugins/wimp.py:55] pylint: disable=maybe-no-member
// [plugins/wimp.py:80] This way of setting accepted language is obviously flawed, in that it
// [plugins/wimp.py:81] depends on the locale settings of the system. However, I'm unsure if
// [plugins/wimp.py:82] they are actually used. The character coding is set elsewhere and I think
// [plugins/wimp.py:83] the available music in each country is bound to the account.
// [plugins/wimp.py:156] Instantiate variables
// [plugins/wimp.py:163] Get a session id for the searches
// [plugins/wimp.py:243] Check input
// [plugins/wimp.py:247] Transform search: tracks -> tracksearch
// [plugins/wimp.py:251] Perform search
// [plugins/wimp.py:258] Parse results
// [plugins/wimp.py:290] Check for correct service
// [plugins/wimp.py:295] Form HTTP body and set parent_id
// [plugins/wimp.py:305] Get HTTP header and post
// [plugins/wimp.py:309] Check for errors and get XML
// [plugins/wimp.py:312] Find the getMetadataResult item ...
// [plugins/wimp.py:315] ... and make sure there is exactly 1
// [plugins/wimp.py:323] Browse the children of metadata result
// [plugins/wimp.py:400] Add the Body part
// [plugins/wimp.py:433] Add the Body part
// [plugins/wimp.py:438] Investigate this index, count stuff more
// [plugins/wimp.py:464] Add the Header part
// [plugins/wimp.py:500] Note UPnP exception 802 while trying to add a Wimp track indicates that these
// [plugins/wimp.py:501] are tracks that not available in Wimp. Do something with that.
// [plugins/wimp.py:511] This one is unknown
// [plugins/wimp.py:512] This one is unknown

// MARK: - Original commentary: services.py
// [services.py:1] module docstring:
// Classes representing Sonos UPnP services.
// 
// >>> import soco
// >>> device = soco.SoCo('192.168.1.102')
// >>> print(RenderingControl(device).GetMute([('InstanceID', 0),
// ...     ('Channel', 'Master')]))
// {'CurrentMute': '0'}
// >>> r = ContentDirectory(device).Browse([
// ...    ('ObjectID', 'Q:0'),
// ...    ('BrowseFlag', 'BrowseDirectChildren'),
// ...    ('Filter', '*'),
// ...    ('StartingIndex', '0'),
// ...    ('RequestedCount', '100'),
// ...    ('SortCriteria', '')
// ...    ])
// >>> print(r['Result'])
// <?xml version="1.0" ?><DIDL-Lite xmlns="urn:schemas-upnp-org:metadata ...
// >>> for action, in_args, out_args in AlarmClock(device).iter_actions():
// ...    print(action, in_args, out_args)
// ...
// SetFormat [Argument(name='DesiredTimeFormat', vartype='string'), Argument(
// name='DesiredDateFormat', vartype='string')] []
// GetFormat [] [Argument(name='CurrentTimeFormat', vartype='string'),
// Argument(name='CurrentDateFormat', vartype='string')] ...
//
// [services.py:69] Action docstring:
// A UPnP Action and its arguments.
//
// [services.py:78] Argument docstring:
// A UPnP Argument and its type.
//
// [services.py:88] Vartype docstring:
// An argument type with default value and range.
//
// [services.py:99] Service docstring:
// A class representing a UPnP service.
// 
//     This is the base class for all Sonos Service classes. This class has a
//     dynamic method dispatcher. Calls to methods which are not explicitly
//     defined here are dispatched automatically to the service action with the
//     same name.
//     
//
// [services.py:122] Service.__init__ docstring:
// 
//         Args:
//             soco (SoCo): A `SoCo` instance to which the UPnP Actions will be
//             sent
//         
//
// [services.py:192] Service.__getattr__ docstring:
// Called when a method on the instance cannot be found.
// 
//         Causes an action to be sent to UPnP server. See also
//         `object.__getattr__`.
// 
//         Args:
//             action (str): The name of the unknown method.
//         Returns:
//             callable: The callable to be invoked. .
//         
//
// [services.py:206] Service.__getattr__._dispatcher docstring:
// Dispatch to send_command.
//
// [services.py:228] Service.wrap_arguments docstring:
// Wrap a list of tuples in xml ready to pass into a SOAP request.
// 
//         Args:
//             args (list):  a list of (name, value) tuples specifying the
//                 name of each argument and its value, eg
//                 ``[('InstanceID', 0), ('Speed', 1)]``. The value
//                 can be a string or something with a string representation. The
//                 arguments are escaped and wrapped in <name> and <value> tags.
// 
//         Example:
// 
//             >>> from soco import SoCo
//             >>> device = SoCo('192.168.1.101')
//             >>> s = Service(device)
//             >>> print(s.wrap_arguments([('InstanceID', 0), ('Speed', 1)]))
//             <InstanceID>0</InstanceID><Speed>1</Speed>'
//         
//
// [services.py:262] Service.unwrap_arguments docstring:
// Extract arguments and their values from a SOAP response.
// 
//         Args:
//             xml_response (str):  SOAP/xml response text (unicode,
//                 not utf-8).
//         Returns:
//              dict: a dict of ``{argument_name: value}`` items.
//         
//
// [services.py:316] Service.compose_args docstring:
// Compose the argument list from an argument dictionary, with
//         respect for default values.
// 
//         Args:
//             action_name (str): The name of the action to be performed.
//             in_argdict (dict): Arguments as a dict, e.g.
//                 ``{'InstanceID': 0, 'Speed': 1}``. The values
//                 can be a string or something with a string representation.
// 
//         Returns:
//             list: a list of ``(name, value)`` tuples.
// 
//         Raises:
//             AttributeError: If this service does not support the action.
//             ValueError: If the argument lists do not match the action
//                 signature.
//         
//
// [services.py:372] Service.build_command docstring:
// Build a SOAP request.
// 
//         Args:
//             action (str): the name of an action (a string as specified in the
//                 service description XML file) to be sent.
//             args (list, optional): Relevant arguments as a list of (name,
//                 value) tuples.
// 
//         Returns:
//             tuple: a tuple containing the POST headers (as a dict) and a
//             string containing the relevant SOAP body. Does not set
//             content-length, or host headers, which are completed upon
//             sending.
//         
//
// [services.py:434] Service.send_command docstring:
// Send a command to a Sonos device.
// 
//         Args:
//             action (str): the name of an action (a string as specified in the
//                 service description XML file) to be sent.
//             args (list, optional): Relevant arguments as a list of (name,
//                 value) tuples, as an alternative to ``kwargs``.
//             cache (Cache): A cache is operated so that the result will be
//                 stored for up to ``cache_timeout`` seconds, and a subsequent
//                 call with the same arguments within that period will be
//                 returned from the cache, saving a further network call. The
//                 cache may be invalidated or even primed from another thread
//                 (for example if a UPnP event is received to indicate that
//                 the state of the Sonos device has changed). If
//                 ``cache_timeout`` is missing or `None`, the cache will use a
//                 default value (which may be 0 - see
//                 :attr:`~soco.services.Service.cache`). By default, the cache
//                 identified by the service's
//                 :attr:`~soco.services.Service.cache` attribute will
//                 be used, but a different cache object may be specified in
//                 the ``cache`` parameter.
//             kwargs: Relevant arguments for the command.
// 
//         Returns:
//              dict: a dict of ``{argument_name, value}`` items.
// 
//         Raises:
//             AttributeError: If this service does not support the action.
//             ValueError: If the argument lists do not match the action
//                 signature.
//             `SoCoUPnPException`: if a SOAP error occurs.
//             `UnknownSoCoException`: if an unknown UPnP error occurs.
//             `requests.exceptions.HTTPError`: if an http error occurs.
// 
//         
//
// [services.py:526] Service.handle_upnp_error docstring:
// Disect a UPnP error, and raise an appropriate exception.
// 
//         Args:
//             xml_error (str):  a unicode string containing the body of the
//                 UPnP/SOAP Fault response. Raises an exception containing the
//                 error code.
//         
//
// [services.py:591] Service.subscribe docstring:
// Subscribe to the service's events.
// 
//         Args:
//             requested_timeout (int, optional): If requested_timeout is
//                 provided, a subscription valid for that
//                 number of seconds will be requested, but not guaranteed. Check
//                 :attr:`~soco.events.Subscription.timeout` on return to find out
//                 what period of validity is actually allocated.
//             auto_renew (bool): If auto_renew is `True`, the subscription will
//                 automatically be renewed just before it expires, if possible.
//                 Default is `False`.
//             event_queue (:class:`~queue.Queue`): a thread-safe queue object on
//                 which received events will be put. If not specified,
//                 a (:class:`~queue.Queue`) will be created and used.
//             strict (bool, optional): If True and an Exception occurs during
//                 execution, the Exception will be raised or, if False, the
//                 Exception will be logged and the Subscription instance will be
//                 returned. Default `True`.
// 
//         Returns:
//             :class:`~soco.events.Subscription`: an instance of
//             :class:`~soco.events.Subscription`, representing the new
//             subscription. If config.EVENTS_MODULE has
//             been set to refer to :py:mod:`events_twisted`, a deferred will
//             be returned with the Subscription as its result and
//             deferred.subscription will be set to refer to the Subscription.
// 
//         To unsubscribe, call the :meth:`~soco.events.Subscription.unsubscribe`
//         method on the returned object.
//         
//
// [services.py:629] Service._update_cache_on_event docstring:
// Update the cache when an event is received.
// 
//         This will be called before an event is put onto the event queue. Events
//         will often indicate that the Sonos device's state has changed, so this
//         opportunity is made available for the service to update its cache. The
//         event will be put onto the event queue once this method returns.
// 
//         `event` is an Event namedtuple: ('sid', 'seq', 'service', 'variables')
// 
//         ..  warning:: This method will not be called from the main thread but
//             by one or more threads, which handle the events as they come in.
//             You *must not* access any class, instance or global variables
//             without appropriate locks. Treat all parameters passed to this
//             method as read only.
//         
//
// [services.py:647] Service.actions docstring:
// The service's actions with their arguments.
// 
//         Returns:
//             list(`Action`): A list of Action namedtuples, consisting of
//             action_name (str), in_args (list of Argument namedtuples,
//             consisting of name and argtype), and out_args (ditto).
// 
//         The return value looks like this:
// 
//         .. code-block:: python
// 
//            [
//                Action(
//                    name='GetMute',
//                    in_args=[
//                        Argument(name='InstanceID', ...),
//                        Argument(
//                            name='Channel',
//                            vartype='string',
//                            list=['Master', 'LF', 'RF', 'SpeakerOnly'],
//                            range=None
//                        )
//                    ],
//                    out_args=[
//                        Argument(name='CurrentMute, ...)
//                    ]
//                )
//                Action(...)
//            ]
// 
//         Its string representation will look like this:
// 
//         .. code-block:: text
// 
//            GetMute(InstanceID: ui4, Channel: [Master, LF, RF, SpeakerOnly])
// 
//            -> {CurrentMute: boolean}
//         
//
// [services.py:689] Service.iter_actions docstring:
// Yield the service's actions with their arguments.
// 
//         Yields:
//             `Action`: the next action.
// 
//         Each action is an Action namedtuple, consisting of action_name
//         (a string), in_args (a list of Argument namedtuples consisting of name
//         and argtype), and out_args (ditto), eg::
// 
//             Action(
//                 name='SetFormat',
//                 in_args=[
//                     Argument(name='DesiredTimeFormat', vartype=<Vartype>),
//                     Argument(name='DesiredDateFormat', vartype=<Vartype>)],
//                 out_args=[]
//             )
//         
//
// [services.py:759] Service.event_vars docstring:
// The service's eventable variables.
// 
//         Returns:
//             list(tuple): A list of (variable name, data type) tuples.
//         
//
// [services.py:769] Service.iter_event_vars docstring:
// Yield the services eventable variables.
// 
//         Yields:
//             `tuple`: a tuple of (variable name, data type).
//         
//
// [services.py:791] AlarmClock docstring:
// Sonos alarm service, for setting and getting time and alarms.
//
// [services.py:803] MusicServices docstring:
// Sonos music services service, for functions related to 3rd party music
//     services.
//
// [services.py:808] AudioIn docstring:
// Sonos audio in service, for functions related to RCA audio input.
//
// [services.py:812] DeviceProperties docstring:
// Sonos device properties service, for functions relating to zones, LED
//     state, stereo pairs etc.
//
// [services.py:817] SystemProperties docstring:
// Sonos system properties service, for functions relating to
//     authentication etc.
//
// [services.py:822] ZoneGroupTopology docstring:
// Sonos zone group topology service, for functions relating to network
//     topology, diagnostics and updates.
//
// [services.py:827] GroupManagement docstring:
// Sonos group management service, for services relating to groups.
//
// [services.py:831] QPlay docstring:
// Sonos Tencent QPlay service (a Chinese music service)
//
// [services.py:835] ContentDirectory docstring:
// UPnP standard Content Directory service, for functions relating to
//     browsing, searching and listing available music.
//
// [services.py:871] MS_ConnectionManager docstring:
// UPnP standard connection manager service for the media server.
//
// [services.py:881] RenderingControl docstring:
// UPnP standard rendering control service, for functions relating to
//     playback rendering, eg bass, treble, volume and EQ.
//
// [services.py:892] MR_ConnectionManager docstring:
// UPnP standard connection manager service for the media renderer.
//
// [services.py:902] AVTransport docstring:
// UPnP standard AV Transport service, for functions relating to transport
//     management, eg play, stop, seek, playlists etc.
//
// [services.py:940] Queue docstring:
// Sonos queue service, for functions relating to queue management, saving
//     queues etc.
//
// [services.py:950] GroupRenderingControl docstring:
// Sonos group rendering control service, for functions relating to group
//     volume etc.
//
// [services.py:1] pylint: disable=fixme, invalid-name
// [services.py:3] Disable while we have Python 2.x compatability
// [services.py:4] pylint: disable=useless-object-inheritance
// [services.py:32] UPnP Spec at http://upnp.org/specs/arch/UPnP-arch-DeviceArchitecture-v1.0.pdf
// [services.py:49] UNICODE NOTE
// [services.py:50] UPnP requires all XML to be transmitted/received with utf-8 encoding. All
// [services.py:51] strings used in this module are unicode. The Requests library should take
// [services.py:52] care of all of the necessary encoding (on sending) and decoding (on
// [services.py:53] receiving) for us, provided that we specify the correct encoding headers
// [services.py:54] (which, hopefully, we do).
// [services.py:55] But since ElementTree seems to prefer being fed bytes to unicode, at least
// [services.py:56] for Python 2.x, we have to encode strings specifically before using it. see
// [services.py:57] http://bugs.python.org/issue11033 TODO: Keep an eye on this when it comes to
// [services.py:58] Python 3 compatibility
// [services.py:61] pylint: disable=C0103
// [services.py:62] logging.basicConfig()
// [services.py:63] log.setLevel(logging.INFO)
// [services.py:108] pylint: disable=bad-continuation
// [services.py:120] noqa PEP8
// [services.py:129] : `SoCo`: The `SoCo` instance to which UPnP Actions are sent
// [services.py:131] Some defaults. Some or all these will need to be overridden
// [services.py:132] specifically in a sub-class. There is other information we could
// [services.py:133] record, but this will do for the moment. Info about a Sonos device is
// [services.py:134] available at <IP_address>/xml/device_description.xml in the
// [services.py:135] <service> tags
// [services.py:137] : str: The UPnP service type.
// [services.py:139] : str: The UPnP service version.
// [services.py:142] : str: The base URL for sending UPnP Actions.
// [services.py:144] : str: The UPnP Control URL.
// [services.py:146] : str: The service control protocol description URL.
// [services.py:148] : str: The service eventing subscription URL.
// [services.py:150] : A cache for storing the result of network calls. By default, this is
// [services.py:151] : a `TimedCache` with a default timeout=0.
// [services.py:154] Caching variables for actions and event_vars, will be filled when
// [services.py:155] they are requested for the first time
// [services.py:159] From table 3.3 in
// [services.py:160] http://upnp.org/specs/arch/UPnP-arch-DeviceArchitecture-v1.1.pdf
// [services.py:161] This list may not be complete, but should be good enough to be going
// [services.py:162] on with.  Error codes between 700-799 are defined for particular
// [services.py:163] services, and may be overriden in subclasses. Error codes >800
// [services.py:164] are generally SONOS specific. NB It may well be that SONOS does not
// [services.py:165] use some of these error codes.
// [services.py:167] pylint: disable=invalid-name
// [services.py:204] Define a function to be invoked as the method, which calls
// [services.py:205] send_command.
// [services.py:210] rename the function so it appears to be the called method. We
// [services.py:211] probably don't need this, but it doesn't harm
// [services.py:214] _dispatcher is now an unbound menthod, but we need a bound method.
// [services.py:215] This turns an unbound method into a bound method (i.e. one that
// [services.py:216] takes self - an instance of the class - as the first parameter)
// [services.py:217] pylint: disable=no-member
// [services.py:219] Now we have a bound method, we cache it on this instance, so that
// [services.py:220] next time we don't have to go through this again
// [services.py:224] return our new bound method, which will be called by Python
// [services.py:254] % converts to unicode because we are using unicode literals.
// [services.py:255] Avoids use of 'unicode' function which does not exist in python 3
// [services.py:272] A UPnP SOAP response (including headers) looks like this:
// [services.py:274] HTTP/1.1 200 OK
// [services.py:275] CONTENT-LENGTH: bytes in body
// [services.py:276] CONTENT-TYPE: text/xml; charset="utf-8" DATE: when response was
// [services.py:277] generated
// [services.py:278] EXT:
// [services.py:279] SERVER: OS/version UPnP/1.0 product/version
// [services.py:280] 
// [services.py:281] <?xml version="1.0"?>
// [services.py:282] <s:Envelope
// [services.py:283] xmlns:s="http://schemas.xmlsoap.org/soap/envelope/"
// [services.py:284] s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
// [services.py:285] <s:Body>
// [services.py:286] <u:actionNameResponse
// [services.py:287] xmlns:u="urn:schemas-upnp-org:service:serviceType:v">
// [services.py:288] <argumentName>out arg value</argumentName>
// [services.py:289] ... other out args and their values go here, if any
// [services.py:290] </u:actionNameResponse>
// [services.py:291] </s:Body>
// [services.py:292] </s:Envelope>
// [services.py:294] Get all tags in order. Elementree (in python 2.x) seems to prefer to
// [services.py:295] be fed bytes, rather than unicode
// [services.py:300] Try to filter illegal xml chars (as unicode), in case that is
// [services.py:301] the reason for the parse error
// [services.py:307] Get the first child of the <Body> tag which will be
// [services.py:308] <{actionNameResponse}> (depends on what actionName is). Turn the
// [services.py:309] children of this into a {tagname, content} dict. XML unescaping
// [services.py:310] is carried out for us by elementree.
// [services.py:337] The found 'action' will be visible from outside the loop
// [services.py:342] Check for given argument names which do not occur in the expected
// [services.py:343] argument list
// [services.py:344] pylint: disable=undefined-loop-variable
// [services.py:353] List the (name, value) tuples for each argument in the argument list
// [services.py:388] A complete request should look something like this:
// [services.py:390] POST path of control URL HTTP/1.1
// [services.py:391] HOST: host of control URL:port of control URL
// [services.py:392] CONTENT-LENGTH: bytes in body
// [services.py:393] CONTENT-TYPE: text/xml; charset="utf-8"
// [services.py:394] SOAPACTION: "urn:schemas-upnp-org:service:serviceType:v#actionName"
// [services.py:395] 
// [services.py:396] <?xml version="1.0"?>
// [services.py:397] <s:Envelope
// [services.py:398] xmlns:s="http://schemas.xmlsoap.org/soap/envelope/"
// [services.py:399] s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
// [services.py:400] <s:Body>
// [services.py:401] <u:actionName
// [services.py:402] xmlns:u="urn:schemas-upnp-org:service:serviceType:v">
// [services.py:403] <argumentName>in arg value</argumentName>
// [services.py:404] ... other in args and their values go here, if any
// [services.py:405] </u:actionName>
// [services.py:406] </s:Body>
// [services.py:407] </s:Envelope>
// [services.py:429] Note that although we set the charset to utf-8 here, in fact the
// [services.py:430] body is still unicode. It will only be converted to bytes when it
// [services.py:431] is set over the network
// [services.py:470] Determine the timeout for the request: use the value of
// [services.py:471] config.REQUEST_TIMEOUT unless overridden by 'timeout'
// [services.py:472] being provided as a kwarg by the caller, in which case
// [services.py:473] use this and remove it from kwargs.
// [services.py:486] Cache miss, so go ahead and make a network call
// [services.py:490] Convert the body to bytes, and send it.
// [services.py:502] The response is good. Get the output params, and return them.
// [services.py:503] NB an empty dict is a valid result. It just means that no
// [services.py:504] params are returned. By using response.text, we rely upon
// [services.py:505] the requests library to convert to unicode for us.
// [services.py:507] Store in the cache. There is no need to do this if there was an
// [services.py:508] error, since we would want to try a network call again.
// [services.py:516] Internal server error. UPnP requires this to be returned if the
// [services.py:517] device does not like the action for some reason. The returned
// [services.py:518] content will be a SOAP Fault. Parse it and raise an error.
// [services.py:521] Something else has gone wrong. Probably a network error. Let
// [services.py:522] Requests handle it
// [services.py:535] An error code looks something like this:
// [services.py:537] HTTP/1.1 500 Internal Server Error
// [services.py:538] CONTENT-LENGTH: bytes in body
// [services.py:539] CONTENT-TYPE: text/xml; charset="utf-8"
// [services.py:540] DATE: when response was generated
// [services.py:541] EXT:
// [services.py:542] SERVER: OS/version UPnP/1.0 product/version
// [services.py:544] <?xml version="1.0"?>
// [services.py:545] <s:Envelope
// [services.py:546] xmlns:s="http://schemas.xmlsoap.org/soap/envelope/"
// [services.py:547] s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
// [services.py:548] <s:Body>
// [services.py:549] <s:Fault>
// [services.py:550] <faultcode>s:Client</faultcode>
// [services.py:551] <faultstring>UPnPError</faultstring>
// [services.py:552] <detail>
// [services.py:553] <UPnPError xmlns="urn:schemas-upnp-org:control-1-0">
// [services.py:554] <errorCode>error code</errorCode>
// [services.py:555] <errorDescription>error string</errorDescription>
// [services.py:556] </UPnPError>
// [services.py:557] </detail>
// [services.py:558] </s:Fault>
// [services.py:559] </s:Body>
// [services.py:560] </s:Envelope>
// [services.py:561] 
// [services.py:562] All that matters for our purposes is the errorCode.
// [services.py:563] errorDescription is not required, and Sonos does not seem to use it.
// [services.py:565] NB need to encode unicode strings before passing to ElementTree
// [services.py:586] Unknown error, so just return the entire response
// [services.py:708] pylint: disable=invalid-name
// [services.py:710] get the scpd body as bytes, and feed directly to elementtree
// [services.py:711] which likes to receive bytes
// [services.py:714] parse the state variables to get the relevant variable types
// [services.py:736] find all the actions
// [services.py:776] pylint: disable=invalid-name
// [services.py:780] parse the state variables to get the relevant variable types
// [services.py:783] We are only interested if 'sendEvents' is 'yes', i.e this
// [services.py:784] is an eventable variable
// [services.py:843] For error codes, see table 2.7.16 in
// [services.py:844] http://upnp.org/specs/av/UPnP-av-ContentDirectory-v1-Service.pdf
// [services.py:871] pylint: disable=invalid-name
// [services.py:892] pylint: disable=invalid-name
// [services.py:910] For error codes, see
// [services.py:911] http://upnp.org/specs/av/UPnP-av-AVTransport-v1-Service.pdf

// MARK: - Original commentary: snapshot.py
// [snapshot.py:1] module docstring:
// Functionality to support saving and restoring the current Sonos state.
// 
// This is useful for scenarios such as when you want to switch to radio
// or an announcement and then back again to what was playing previously.
// 
// Warning:
//     Sonos has introduced control via Amazon Alexa. A new cloud queue is
//     created and at present there appears no way to restart this
//     queue from snapshot. Currently if a cloud queue was playing it will
//     not restart.
// 
// Warning:
//     This class is designed to be created used and destroyed. It is not
//     designed to be reused or long lived. The init sets up defaults for
//     one use.
//
// [snapshot.py:22] Snapshot docstring:
// A snapshot of the current state.
// 
//     Note:
//         This does not change anything to do with the configuration
//         such as which group the speaker is in, just settings that impact
//         what is playing, or how it is played.
// 
//         List of sources that may be playing using root of media_uri:
// 
//         | ``x-rincon-queue``: playing from Queue
//         | ``x-sonosapi-stream``: playing a stream (eg radio)
//         | ``x-file-cifs``: playing file
//         | ``x-rincon``: slave zone (only change volume etc. rest from
//           coordinator)
//     
//
// [snapshot.py:39] Snapshot.__init__ docstring:
// 
//         Args:
//             device (SoCo): The device to snapshot
//             snapshot_queue (bool): Whether the queue should be snapshotted.
//                 Defaults to `False`.
// 
//         Warning:
//             It is strongly advised that you do not snapshot the queue unless
//             you really need to as it takes a very long time to restore large
//             queues as it is done one track at a time.
//         
//
// [snapshot.py:84] Snapshot.snapshot docstring:
// Record and store the current state of a device.
// 
//         Returns:
//             bool: `True` if the device is a coordinator, `False` otherwise.
//             Useful for determining whether playing an alert on a device
//             will ungroup it.
//         
//
// [snapshot.py:156] Snapshot.restore docstring:
// Restore the state of a device to that which was previously saved.
// 
//         For coordinator devices restore everything. For slave devices
//         only restore volume etc., not transport info (transport info
//         comes from the slave's coordinator).
// 
//         Args:
//             fade (bool): Whether volume should be faded up on restore.
//         
//
// [snapshot.py:180] Snapshot._restore_coordinator docstring:
// Do the coordinator-only part of the restore.
//
// [snapshot.py:226] Snapshot._restore_volume docstring:
// Reinstate volume.
// 
//         Args:
//             fade (bool): Whether volume should be faded up on restore.
//         
//
// [snapshot.py:258] Snapshot._save_queue docstring:
// Save the current state of the queue.
//
// [snapshot.py:279] Snapshot._restore_queue docstring:
// Restore the previous state of the queue.
// 
//         Note:
//             The restore currently adds the items back into the queue
//             using the URI, for items the Sonos system already knows about
//             this is OK, but for other items, they may be missing some of
//             their metadata as it will not be automatically picked up.
//         
//
// [snapshot.py:1] Disable while we have Python 2.x compatability
// [snapshot.py:2] pylint: disable=useless-object-inheritance
// [snapshot.py:51] The device that will be snapshotted
// [snapshot.py:54] The values that will be stored
// [snapshot.py:55] For all zones:
// [snapshot.py:67] For coordinator zone playing from Queue:
// [snapshot.py:73] For coordinator zone playing a Stream:
// [snapshot.py:76] For all coordinator zones
// [snapshot.py:80] Only set the queue as a list if we are going to save it
// [snapshot.py:92] get if device coordinator (or slave) True (or False)
// [snapshot.py:95] Get information about the currently playing media
// [snapshot.py:98] Extract source from media uri - below some media URI value examples:
// [snapshot.py:99] 'x-rincon-queue:RINCON_000E5859E49601400#0'
// [snapshot.py:100] - playing a local queue always #0 for local queue)
// [snapshot.py:101] 
// [snapshot.py:102] 'x-rincon-queue:RINCON_000E5859E49601400#6'
// [snapshot.py:103] - playing a cloud queue where #x changes with each queue)
// [snapshot.py:104] 
// [snapshot.py:105] -'x-rincon:RINCON_000E5859E49601400'
// [snapshot.py:106] - a slave player pointing to coordinator player
// [snapshot.py:109] The pylint error below is a false positive, see about removing it
// [snapshot.py:110] in the future
// [snapshot.py:111] pylint: disable=simplifiable-if-statement
// [snapshot.py:113] playing local queue
// [snapshot.py:116] playing cloud queue - started from Alexa
// [snapshot.py:119] Save the volume, mute and other sound settings
// [snapshot.py:126] get details required for what's playing:
// [snapshot.py:128] playing from queue - save repeat, random, cross fade, track, etc.
// [snapshot.py:132] Get information about the currently playing track
// [snapshot.py:137] save as integer
// [snapshot.py:141] playing from a stream - save media metadata
// [snapshot.py:144] Work out what the playing state is - if a coordinator
// [snapshot.py:150] Save of the current queue if we need to
// [snapshot.py:153] return if device is a coordinator (helps usage)
// [snapshot.py:172] Now everything is set, see if we need to be playing, stopped
// [snapshot.py:173] or paused ( only for coordinators)
// [snapshot.py:182] Start by ensuring that the speaker is paused as we don't want
// [snapshot.py:183] things all rolling back when we are changing them, as this could
// [snapshot.py:184] include things like audio
// [snapshot.py:190] Check if the queue should be restored
// [snapshot.py:193] Reinstate what was playing
// [snapshot.py:196] was playing from playlist
// [snapshot.py:199] The position in the playlist returned by
// [snapshot.py:200] get_current_track_info starts at 1, but when
// [snapshot.py:201] playing from playlist, the index starts at 0
// [snapshot.py:202] if position > 0:
// [snapshot.py:210] reinstate track, position, play mode, cross fade
// [snapshot.py:211] Need to make sure there is a proper track selected first
// [snapshot.py:216] was playing a cloud queue started by Alexa
// [snapshot.py:217] No way yet to re-start this so prevent it throwing an error!
// [snapshot.py:221] was playing a stream (radio station, file, or nothing)
// [snapshot.py:222] reinstate uri and meta data
// [snapshot.py:234] Can only change volume on device with fixed volume set to False
// [snapshot.py:235] otherwise get uPnP error, so check first. Before issuing a network
// [snapshot.py:236] command to check, fixed volume always has volume set to 100.
// [snapshot.py:237] So only checked fixed volume if volume is 100.
// [snapshot.py:243] now set volume if not fixed
// [snapshot.py:250] if fade requested in restore
// [snapshot.py:251] set volume to 0 then fade up to saved volume (non blocking)
// [snapshot.py:255] set volume
// [snapshot.py:261] Maximum batch is 486, anything larger will still only
// [snapshot.py:262] return 486
// [snapshot.py:267] Need to get all the tracks in batches, but Only get the next
// [snapshot.py:268] batch if all the items requested were in the last batch
// [snapshot.py:271] Check how many entries were returned
// [snapshot.py:273] Make sure the queue is not empty
// [snapshot.py:276] Update the total that have been processed
// [snapshot.py:289] Clear the queue so that it can be reset
// [snapshot.py:291] Now loop around all the queue entries adding them

// MARK: - Original commentary: soap.py
// [soap.py:1] module docstring:
// Classes for handling SoCo's basic SOAP requirements.
// 
// This module does not handle anything like the full `SOAP Specification
// <http://www.w3.org/TR/soap/>`_ , but is enough for SoCo's needs. Sonos uses
// SOAP for UPnP communications, and for communication with third party music
// services.
//
// [soap.py:43] SoapFault docstring:
// An exception encapsulating a SOAP Fault.
//
// [soap.py:46] SoapFault.__init__ docstring:
// 
//         Args:
//             faultcode (str): The SOAP faultcode.
//             faultstring (str): The SOAP faultstring.
//             detail (:obj:`~xml.etree.ElementTree.Element`): The SOAP fault
//                 detail, as an ElementTree
//                 :obj:`~xml.etree.ElementTree.Element`. Defaults to `None`.
//         
//
// [soap.py:97] SoapMessage docstring:
// A SOAP Message representing a remote procedure call.
// 
//     Uses the `Requests <http://www.python-requests.org/en/latest/>`_ library
//     for communication with a SOAP server.
//     
//
// [soap.py:104] SoapMessage.__init__ docstring:
// 
//         Args:
//             endpoint (str): The SOAP endpoint URL for this client.
//             method (str): The name of the method to call.
//             parameters (list): A list of (name, value) tuples containing
//                 the parameters to pass to the method. Default `None`.
//             http_headers (dict): A dict in the form ``{'Header': 'Value,..}``
//                 containing http headers to use for the http request.
//                 ``Content-type`` and ``SOAPACTION`` headers will be created
//                 automatically, so do not include them here. Use this, for
//                 example, to set a user-agent.
//             soap_action (str): The value of the ``SOAPACTION`` header.
//                 Default 'None`.
//             soap_header (str): A string representation of the XML to be
//                 used for the SOAP Header. Default `None`.
//             namespace (str): The namespace URI to use for the method and
//                 parameters. `None`, by default.
//             **request_args: Other keyword parameters will be passed to the
//                 Requests request which is used to handle the http
//                 communication. For example, a timeout value can be set.
//         
//
// [soap.py:146] SoapMessage.prepare_headers docstring:
// Prepare the http headers for sending.
// 
//         Add the ``SOAPACTION`` header to the others.
// 
//         Args:
//             http_headers (dict): A dict in the form ``{'Header': 'Value,..}``
//                 containing http headers to use for the http request.
//             soap_action (str): The value of the ``SOAPACTION`` header.
// 
//         Returns:
//             dict: headers including the ``SOAPACTION`` header.
//         
//
// [soap.py:168] SoapMessage.prepare_soap_header docstring:
// Prepare the SOAP header for sending.
// 
//         Wraps the soap header in appropriate tags.
// 
//         Args:
//             soap_header (str): A string representation of the XML to be
//                 used for the SOAP Header
// 
//         Returns:
//             str: The soap header wrapped in appropriate tags.
//         
//
// [soap.py:186] SoapMessage.prepare_soap_body docstring:
// Prepare the SOAP message body for sending.
// 
//         Args:
//             method (str): The name of the method to call.
//             parameters (list): A list of (name, value) tuples containing
//                 the parameters to pass to the method.
//             namespace (str): The XML namespace to use for the method.
// 
//         Returns:
//             str: A properly formatted SOAP Body.
//         
//
// [soap.py:227] SoapMessage.prepare_soap_envelope docstring:
// Prepare the SOAP Envelope for sending.
// 
//         Args:
//             prepared_soap_header (str): A SOAP Header prepared by
//                 `prepare_soap_header`
//             prepared_soap_body (str): A SOAP Body prepared by
//                 `prepare_soap_body`
// 
//         Returns:
//             str: A prepared SOAP Envelope
//         
//
// [soap.py:255] SoapMessage.prepare docstring:
// Prepare the SOAP message for sending to the server.
//
// [soap.py:264] SoapMessage.call docstring:
// Call the SOAP method on the server.
// 
//         Returns:
//             str: the decapusulated SOAP response from the server,
//             still encoded as utf-8.
// 
//         Raises:
//              SoapFault: if a SOAP error occurs.
//              ~requests.exceptions.HTTPError: if an http error occurs.
//              xml.etree.ElementTree.ParseError: If the response cannot be parsed as XML
// 
//         
//
// [soap.py:1] pylint: disable=fixme
// [soap.py:3] Disable while we have Python 2.x compatability
// [soap.py:4] pylint: disable=useless-object-inheritance
// [soap.py:14] The state of Python's SOAP libraries is poor. In any event, the two main
// [soap.py:15] libraries, PySimpleSOAP and SUDS (or the more up-to-date SUDS-Jurko),
// [soap.py:16] are too complex for our needs. SUDS requires a WSDL file to be parsed,
// [soap.py:17] and although SONOS provides one in relation to music services (at
// [soap.py:18] http://musicpartners.sonos.com/sites/default/files/Sonos.wsdl) the various
// [soap.py:19] music services themselves provide buggy, incomplete or old
// [soap.py:20] implementations which cause SUDS to break. PySimpleSOAP can work without a
// [soap.py:21] WSDL file, but contains various bugs which mean that we would have to use
// [soap.py:22] a patched version (upstream releases are infrequent).  Since SONOS only
// [soap.py:23] appears to use basic SOAP features, and after experimenting with other
// [soap.py:24] libraries, it seems best to write our own.
// [soap.py:26] Some is the same as that in services.py.
// [soap.py:27] TODO: refactor services.py to depend on this code
// [soap.py:70] Sonos uses SOAP to send commands in the RPC form. A complete RPC SOAP
// [soap.py:71] message should look something like this. See generally
// [soap.py:72] http://www.w3.org/TR/2000/NOTE-SOAP-20000508/
// [soap.py:74] POST Endpoint URL HTTP/1.1
// [soap.py:75] HOST: Host of Endpoint URL:port
// [soap.py:76] CONTENT-LENGTH: bytes in body
// [soap.py:77] CONTENT-TYPE: text/xml; charset="utf-8"
// [soap.py:78] SOAPACTION: URI
// [soap.py:79] 
// [soap.py:80] <?xml version="1.0"?>
// [soap.py:81] <s:Envelope
// [soap.py:82] xmlns:s="http://schemas.xmlsoap.org/soap/envelope/"
// [soap.py:83] s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
// [soap.py:84] <s:Header>
// [soap.py:85] </Header elements go here>
// [soap.py:86] </s:Header>
// [soap.py:87] <s:Body>
// [soap.py:88] <ns:MethodName xmlns:ns="MethodNamespace>"
// [soap.py:89] <param1>value</param1>
// [soap.py:90] ...
// [soap.py:91] <param_n>value</param_n>
// [soap.py:92] </ns:MethodName>
// [soap.py:93] </s:Body>
// [soap.py:94] </s:Envelope>
// [soap.py:145] pylint:disable=no-self-use
// [soap.py:162] FIXME The successful auth was with SOAP-Action
// [soap.py:204] % converts to unicode because we are using unicode literals.
// [soap.py:205] Avoids use of 'unicode' function which does not exist in python 3
// [soap.py:209] Prepare the SOAP Body
// [soap.py:240] pylint: disable=bad-continuation
// [soap.py:250] noqa PEP8
// [soap.py:279] Here could potentially go a Accept-Language header. See e.g. here for a
// [soap.py:280] description of how to do that for a music service:
// [soap.py:281] https://developer.sonos.com/build/content-service-get-started/
// [soap.py:282] soap-requests-and-responses/
// [soap.py:284] Check log level before logging XML, since prettifying it is
// [soap.py:285] expensive
// [soap.py:301] The response is good. Extract the Body
// [soap.py:303] Check for faults in the content
// [soap.py:310] Get the first child of the <Body> tag. NB There should only be
// [soap.py:311] one if the RPC standard is followed.
// [soap.py:315] We probably have a SOAP Fault
// [soap.py:319] Not a SOAP fault. Must be something else.
// [soap.py:326] Something else has gone wrong. Probably a network error. Let
// [soap.py:327] Requests handle it

// MARK: - Original commentary: utils.py
// [utils.py:1] module docstring:
// This class contains utility functions used internally by SoCo.
//
// [utils.py:14] really_unicode docstring:
// Make a string unicode. Really.
// 
//     Ensure ``in_string`` is returned as unicode through a series of
//     progressively relaxed decodings.
// 
//     Args:
//         in_string (str): The string to convert.
// 
//     Returns:
//         str: Unicode.
// 
//     Raises:
//         ValueError
//     
//
// [utils.py:42] really_utf8 docstring:
// Encode a string with utf-8. Really.
// 
//      First decode ``in_string`` via `really_unicode` to ensure it can
//      successfully be encoded as utf-8. This is required since just calling
//      encode on a string will often cause Python 2 to perform a coerced strict
//      auto-decode as ascii first and will result in a `UnicodeDecodeError` being
//      raised. After `really_unicode` returns a safe unicode string, encode as
//      utf-8 and return the utf-8 encoded string.
// 
//     Args:
//          in_string (str): The string to convert.
// 
//      Returns:
//          str: utf-encoded data.
//     
//
// [utils.py:65] camel_to_underscore docstring:
// Convert camelcase to lowercase and underscore.
// 
//     Recipe from http://stackoverflow.com/a/1176023
// 
//     Args:
//         string (str): The string to convert.
// 
//     Returns:
//         str: The converted string.
//     
//
// [utils.py:80] prettify docstring:
// Return a pretty-printed version of a unicode XML string.
// 
//     Useful for debugging.
// 
//     Args:
//         unicode_text (str): A text representation of XML (unicode,
//             *not* utf-8).
// 
//     Returns:
//         str: A pretty-printed version of the input.
// 
//     
//
// [utils.py:99] show_xml docstring:
// Pretty print an :class:`~xml.etree.ElementTree.ElementTree` XML object.
// 
//     Args:
//         xml (:class:`~xml.etree.ElementTree.ElementTree`): The
//             :class:`~xml.etree.ElementTree.ElementTree` to pretty print
// 
//     Note:
//         This is used a convenience function used during development. It
//         is not used anywhere in the main code base.
//     
//
// [utils.py:114] deprecated docstring:
// A decorator for marking deprecated objects.
// 
//     Used internally by SoCo to cause a warning to be issued when the object
//     is used, and marks the object as deprecated in the Sphinx documentation.
// 
//     Args:
//         since (str): The version in which the object is deprecated.
//         alternative (str, optional): The name of an alternative object to use
//         will_be_removed_in (str, optional): The version in which the object is
//             likely to be removed.
//         alternative_not_referable (bool): (optional) Indicate that
//             ``alternative`` cannot be used as a sphinx reference
// 
//     Example:
//         ..  code-block:: python
// 
//             @deprecated(since="0.7", alternative="new_function")
//             def old_function(args):
//                 pass
//     
//
// [utils.py:182] url_escape_path docstring:
// Escape a string value for a URL request path.
// 
//     Args:
//         str: The path to escape
// 
//     Returns:
//         str: The escaped path
// 
//     >>> url_escape_path("Foo, bar & baz / the hackers")
//     u'Foo%2C%20bar%20%26%20baz%20%2F%20the%20hackers'
//     
//
// [utils.py:198] first_cap docstring:
// Return upper cased first character
//
// [utils.py:1] Disable while we have Python 2.x compatability
// [utils.py:2] pylint: disable=useless-object-inheritance,import-outside-toplevel
// [utils.py:32] pylint: disable=star-args
// [utils.py:136] pylint really doesn't like decorators!
// [utils.py:137] pylint: disable=invalid-name
// [utils.py:138] pylint: disable=missing-docstring
// [utils.py:194] Using 'safe' arg does not seem to work for python 2.6

// MARK: - Original commentary: xml.py
// [xml.py:1] module docstring:
// This class contains XML related utility functions.
//
// [xml.py:63] ns_tag docstring:
// Return a namespace/tag item.
// 
//     Args:
//         ns_id (str): A namespace id, eg ``"dc"`` (see `NAMESPACES`)
//         tag (str): An XML tag, eg ``"author"``
// 
//     Returns:
//         str: A fully qualified tag.
// 
//     The ns_id is translated to a full name space via the :const:`NAMESPACES`
//     constant::
// 
//         >>> xml.ns_tag('dc','author')
//         '{http://purl.org/dc/elements/1.1/}author'
//     
//
// [xml.py:1] pylint: disable=invalid-name,wrong-import-position,redefined-builtin
// [xml.py:10] Create regular expression for filtering invalid characters, from:
// [xml.py:11] http://stackoverflow.com/questions/1707890/
// [xml.py:12] fast-way-to-filter-illegal-xml-unicode-chars-in-python
// [xml.py:48] : Commonly used namespaces, and abbreviations, used by `ns_tag`.
// [xml.py:57] Register common namespaces to assist in serialisation (avoids the ns:0
// [xml.py:58] prefixes in XML output )

// MARK: - Original commentary: zonegroupstate.py
// [zonegroupstate.py:1] module docstring:
// Provides handling for ZoneGroupState information.
// 
// ZoneGroupState XML payloads are received from both:
// * zoneGroupTopology.GetZoneGroupState()['ZoneGroupState']
// * zoneGroupTopology subscription event callbacks
// 
// The ZoneGroupState payloads are identical between all speakers in a
// household, but may be generated with differing orders for contained
// ZoneGroup or ZoneGroupMember elements and children. To benefit from
// similar contents, payloads are passed through an XSL transformation
// to normalize the data, to allow simple equality comparisons, and to
// avoid unnecessary reprocessing of identical data.
// 
// Since the payloads are identical between all speakers, we can use a
// common cache per household.
// 
// As satellites can sometimes deliver outdated payloads when they are
// directly polled, these requests are instead forwarded to the parent
// device.
// 
// Example payload contents:
// 
//   <ZoneGroupState>
//     <ZoneGroups>
//       <ZoneGroup Coordinator="RINCON_000XXX1400" ID="RINCON_000XXXX1400:0">
//         <ZoneGroupMember
//             BootSeq="33"
//             Configuration="1"
//             Icon="x-rincon-roomicon:zoneextender"
//             Invisible="1"
//             IsZoneBridge="1"
//             Location="http://192.168.1.100:1400/xml/device_description.xml"
//             MinCompatibleVersion="22.0-00000"
//             SoftwareVersion="24.1-74200"
//             UUID="RINCON_000ZZZ1400"
//             ZoneName="BRIDGE"/>
//       </ZoneGroup>
//       <ZoneGroup Coordinator="RINCON_000XXX1400" ID="RINCON_000XXX1400:46">
//         <ZoneGroupMember
//             BootSeq="44"
//             Configuration="1"
//             Icon="x-rincon-roomicon:living"
//             Location="http://192.168.1.101:1400/xml/device_description.xml"
//             MinCompatibleVersion="22.0-00000"
//             SoftwareVersion="24.1-74200"
//             UUID="RINCON_000XXX1400"
//             ZoneName="Living Room"/>
//         <ZoneGroupMember
//             BootSeq="52"
//             Configuration="1"
//             Icon="x-rincon-roomicon:kitchen"
//             Location="http://192.168.1.102:1400/xml/device_description.xml"
//             MinCompatibleVersion="22.0-00000"
//             SoftwareVersion="24.1-74200"
//             UUID="RINCON_000YYY1400"
//             ZoneName="Kitchen"/>
//       </ZoneGroup>
//     </ZoneGroups>
//     <VanishedDevices/>
//   </ZoneGroupState>
// 
//
// [zonegroupstate.py:106] ZoneGroupState docstring:
// Handles processing and caching of ZoneGroupState payloads.
// 
//     Only one ZoneGroupState instance is created per Sonos household.
//     
//
// [zonegroupstate.py:112] ZoneGroupState.__init__ docstring:
// Initialize the ZoneGroupState instance.
//
// [zonegroupstate.py:126] ZoneGroupState.clear_cache docstring:
// Clear the cache timestamp.
//
// [zonegroupstate.py:130] ZoneGroupState.add_subscription docstring:
// Start tracking a ZoneGroupTopology subscription.
//
// [zonegroupstate.py:143] ZoneGroupState.remove_subscription docstring:
// Stop tracking a ZoneGroupTopology subscription.
//
// [zonegroupstate.py:155] ZoneGroupState.has_subscriptions docstring:
// Return True if active subscriptions are updating this ZoneGroupState.
//
// [zonegroupstate.py:163] ZoneGroupState.clear_zone_groups docstring:
// Clear all known group sets.
//
// [zonegroupstate.py:169] ZoneGroupState.poll docstring:
// Poll using the provided SoCo instance and process the payload.
//
// [zonegroupstate.py:229] ZoneGroupState.update_zgs_by_event docstring:
// 
//         Fall back to updating the ZGS using a ZGT event.
//         Use of the 'events_twisted' module is not currently supported.
//         
//
// [zonegroupstate.py:263] ZoneGroupState.update_zgs_by_event_default docstring:
// 
//         Update the ZGS using the default events module.
//         
//
// [zonegroupstate.py:274] ZoneGroupState.update_zgs_by_event_asyncio docstring:
// 
//         Update ZGS using events_asyncio. When the event is received,
//         the events_asyncio notify handler will call 'process_payload' with
//         the updated ZGS.
//         
//
// [zonegroupstate.py:291] ZoneGroupState.process_payload docstring:
// Update using the provided XML payload.
//
// [zonegroupstate.py:314] ZoneGroupState.parse_zone_group_member docstring:
// Parse a ZoneGroupMember or Satellite element from Zone Group
//         State, create a SoCo instance for the member, set basic attributes
//         and return it.
//
// [zonegroupstate.py:351] ZoneGroupState.update_soco_instances docstring:
// Update all SoCo instances with the provided payload.
//
// [zonegroupstate.py:396] normalize_zgs_xml docstring:
// Normalize the ZoneGroupState payload and return an lxml ElementTree instance.
//
// [zonegroupstate.py:101] pylint:disable=I1101
// [zonegroupstate.py:122] Statistics
// [zonegroupstate.py:171] pylint: disable=protected-access
// [zonegroupstate.py:190] Satellites can return outdated information, use the parent
// [zonegroupstate.py:198] On large (about 20+ players) systems, GetZoneGroupState() can cause
// [zonegroupstate.py:199] the target Sonos player to return an HTTP 501 error, raising a
// [zonegroupstate.py:200] SoCoUPnPException.
// [zonegroupstate.py:207] In the event of failure, we fall back to using a ZGT event to
// [zonegroupstate.py:208] determine the ZGS. Fallback behaviour can be disabled by setting the
// [zonegroupstate.py:209] config.ZGT_EVENT_FALLBACK flag to False.
// [zonegroupstate.py:240] Explicit asyncio event loop control required for Python 3.6
// [zonegroupstate.py:246] From Python 3.7, we can just use the single statement:
// [zonegroupstate.py:247] asyncio.run(ZoneGroupState.update_zgs_events_asyncio(speaker))
// [zonegroupstate.py:250] Future: Insert code here to handle the 'events_twisted' case
// [zonegroupstate.py:257] In case any additional events frameworks come along ...
// [zonegroupstate.py:280] pylint: disable=C0415
// [zonegroupstate.py:287] The event listener was started as a result of our
// [zonegroupstate.py:288] subscribe() call, so stop it
// [zonegroupstate.py:318] pylint: disable=protected-access
// [zonegroupstate.py:320] Create a SoCo instance for each member. Because SoCo
// [zonegroupstate.py:321] instances are singletons, this is cheap if they have already
// [zonegroupstate.py:322] been created, and useful if they haven't. We can then
// [zonegroupstate.py:323] update various properties for that instance.
// [zonegroupstate.py:326] Example Location contents:
// [zonegroupstate.py:327] http://192.168.1.100:1400/xml/device_description.xml
// [zonegroupstate.py:333] Example ChannelMapSet (stereo pair) contents:
// [zonegroupstate.py:334] RINCON_001XXX1400:LF,LF;RINCON_002XXX1400:RF,RF
// [zonegroupstate.py:335] Example HTSatChanMapSet (home theater) contents:
// [zonegroupstate.py:336] RINCON_001XXX1400:LF,RF;RINCON_002XXX1400:LR;RINCON_003XXX1400:RR
// [zonegroupstate.py:344] Add the zone to the set of all members, and to the set
// [zonegroupstate.py:345] of visible members if appropriate
// [zonegroupstate.py:353] pylint: disable=protected-access
// [zonegroupstate.py:356] Compatibility fallback for pre-10.1 firmwares
// [zonegroupstate.py:357] where a "ZoneGroups" element is not used
// [zonegroupstate.py:376] is_bridge doesn't change, but it does no real harm to
// [zonegroupstate.py:377] set/reset it here, just in case the zone has not been seen
// [zonegroupstate.py:378] before
// [zonegroupstate.py:380] add the zone to the members for this group
// [zonegroupstate.py:382] Loop over Satellite elements if present, and process as for
// [zonegroupstate.py:383] ZoneGroup elements
// [zonegroupstate.py:390] Assume a satellite can't be a bridge or coordinator, so
// [zonegroupstate.py:391] no need to check.
// [zonegroupstate.py:398] pylint:disable=I1101
// [zonegroupstate.py:399] pylint:disable=I1101
