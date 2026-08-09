# Upstream test mapping

This document records the parity categories used by the Swift test suite. Several source tests were parameterized; the function count is therefore not the same as the number of test cases.

`PORTED / CONSOLIDATED` means several narrow upstream assertions are represented by a smaller number of Swift tests exercising the same wire/parsing behavior. `LIVE HARDWARE` identifies scenarios requiring a real Sonos system.

## `test_alarms.py` — PORTED

Swift coverage: `AlarmsTests.swift`, `CompatibilityTests.swift`

Original functions (5):

- `test_recurrence`
- `test_alarms`
- `test_alarms_skipped`
- `test_alarms_skipped_reuse_object_on_update`
- `test_save_raises_when_zone_is_none`

## `test_cache.py` — PORTED

Swift coverage: `CacheTests.swift`

Original functions (5):

- `test_instance_creation`
- `test_cache_put_get`
- `test_cache_clear_del`
- `test_with_typical_args`
- `test_cache_disable`

## `test_core.py` — PORTED / CONSOLIDATED

Swift coverage: `CoreTests.swift`, `CoreAdvancedTests.swift`, `ZoneGroupStateTests.swift`

Original functions (89):

- `test_only_on_master_true`
- `test_not_on_master_false`
- `test_soco_bad_ip`
- `test_soco_init`
- `test_soco_str`
- `test_soco_repr`
- `test_soco_is_soundbar`
- `test_soco_get_speaker_info_speaker_not_set_refresh`
- `test_soco_get_speaker_info_speaker_set_no_refresh`
- `test_soco_get_speaker_info_speaker_set_refresh`
- `test_soco_speech_enhance_mode`
- `test_soco_play_mode_values`
- `test_soco_play_mode_bad_value`
- `test_soco_play_mode_lowercase`
- `test_available_actions`
- `test_soco_cross_fade2`
- `test_soco_play`
- `test_soco_play_uri`
- `test_soco_play_uri_force_radio`
- `test_soco_play_uri_calls_play`
- `test_soco_play_uri_timeout`
- `test_soco_play_uri_with_title`
- `test_soco_pause`
- `test_soco_stop`
- `test_soco_end_direct_control_session`
- `test_soco_next`
- `test_soco_previous`
- `test_soco_seek_invalid`
- `test_soco_seek_valid`
- `test_soco_current_transport_info`
- `test_soco_get_queue`
- `test_soco_queue_size`
- `test_join`
- `test_join_timeout`
- `test_unjoin`
- `test_unjoin_timeout`
- `test_switch_to_line_in`
- `test_switch_to_tv`
- `test_is_playing_tv`
- `test_is_playing_radio`
- `test_is_playing_line_in`
- `test_create_sonos_playlist`
- `test_create_sonos_playlist_from_queue`
- `test_add_item_to_sonos_playlist`
- `test_soco_cross_fade`
- `test_shuffle`
- `test_repeat`
- `test_set_sleep_timer`
- `test_set_sleep_timer_bad_sleep_time`
- `test_get_sleep_timer`
- `test_remove_sonos_playlist_success`
- `test_soco_mute`
- `test_soco_volume`
- `test_soco_ramp_to_volume`
- `test_set_relative_volume`
- `test_soco_treble`
- `test_soco_loudness`
- `test_soco_trueplay`
- `test_soco_soundbar_audio_input_format`
- `test_soco_audio_delay`
- `test_soco_fixed_volume`
- `test_soco_balance`
- `test_soco_surround_settings`
- `test_soco_status_light`
- `test_buttons_enabled`
- `test_soco_set_player_name`
- `test_create_stereo_pair`
- `test_separate_stereo_pair`
- `test_add_satellite_speakers`
- `test_add_satellite_speakers_not_soundbar`
- `test_separate_satellite_speakers`
- `test_separate_satellite_speakers_not_soundbar`
- `test_get_battery_info`
- `test_soco_uid`
- `test_soco_is_visible`
- `test_soco_is_bridge`
- `test_soco_is_coordinator`
- `test_boot_seqnum`
- `test_all_groups`
- `test_all_groups_have_coordinator`
- `test_group`
- `test_all_zones`
- `test_visible_zones`
- `test_group_label`
- `test_group_short_label`
- `test_group_volume`
- `test_group_mute`
- `test_set_relative_group_volume`
- `test_mic_enabled`

## `test_data_structures_entry_integration.py` — PORTED

Swift coverage: `DIDLTests.swift`

Original functions (3):

- `test_items`
- `test_vendor_extended_didl_class`
- `test_from_didl_string_missing_upnp_class_raises`

## `test_discovery.py` — PORTED

Swift coverage: `DiscoveryTests.swift`

Original functions (8):

- `test_by_name`
- `test__find_ipv4_networks`
- `test__find_ipv4_addresses`
- `test__check_ip_and_port`
- `test__is_sonos`
- `test__sonos_scan_worker_thread`
- `test_scan_network`
- `test_discover`

## `test_events.py` — PORTED

Swift coverage: `EventsTests.swift`

Original functions (4):

- `test_event_object`
- `test_event_parsing`
- `test_event_parsing_linein`
- `test_event_parsing_null_value`

## `test_events_asyncio.py` — NATIVE-BACKEND ADAPTATION

Swift coverage: Swift has one native listener; functional subscription lifecycle is in `EventsTests.swift`. Python asyncio task/socket race internals are not reproduced.

Original functions (6):

- `test_async_stop_tolerates_closed_socket`
- `test_stop_listening_swallows_task_exception`
- `test_async_start_cancels_pending_deferred_stop_and_resumes`
- `test_deferred_stop_runs_when_grace_expires_and_count_zero`
- `test_deferred_stop_aborts_when_subscription_appears_in_grace`
- `test_async_stop_idempotent_under_parallel_calls`

## `test_integration.py` — LIVE HARDWARE / PROTOCOL EQUIVALENTS

Swift coverage: command/parsing contracts are covered by `CoreTests.swift`, `CoreAdvancedTests.swift`, `MusicLibraryTests.swift`, and topology tests. Live hardware procedures require an external Sonos system.

Original functions (42):

- `test_get_and_set`
- `test_invalid_arguments`
- `test_set_0`
- `test_get_and_set`
- `test_invalid_arguments`
- `test_get_and_set`
- `test_invalid_arguments`
- `test_pause_and_play`
- `test_stop`
- `test_seek_valid`
- `test_seek_invald`
- `test_get`
- `test_get`
- `test_get`
- `test_add_to_queue`
- `test_create`
- `test_create_from_queue`
- `test_remove_playlist`
- `test_remove_playlist_itemid`
- `test_remove_playlist_bad_id`
- `test_get_set_timer`
- `test_reverse_track_order`
- `test_swap_first_two_items`
- `test_remove_first_track`
- `test_remove_first_track_full`
- `test_remove_last_track`
- `test_remove_between_track`
- `test_remove_some_tracks`
- `test_remove_all_tracks`
- `test_reorder_and_remove_track`
- `test_object_id_is_object`
- `test_remove_all_string`
- `test_remove_and_reorder_string`
- `test_move_track_string`
- `test_move_track_int`
- `test_clear_sonos_playlist`
- `test_clear_empty_sonos_playlist`
- `test_move_in_sonos_playlist`
- `test_remove_from_sonos_playlist`
- `test_get_sonos_playlist_by_attr`
- `test_from_specific_search_methods`
- `test_music_library_information`

## `test_metadata_parsing.py` — PORTED / CONSOLIDATED

Swift coverage: `EventsTests.swift`, `DIDLTests.swift`

Original functions (1):

- `test_metadata_parsing`

## `test_ms_data_structures.py` — PORTED

Swift coverage: `LegacyMusicServiceDataTests.swift`

Original functions (4):

- `test_ms_track_search`
- `test_ms_album_search`
- `test_ms_artist_search`
- `test_ms_playlist_search`

## `test_music_library.py` — PORTED

Swift coverage: `MusicLibraryTests.swift`

Original functions (9):

- `test_search_track_no_result`
- `test_search_track_no_artist_album_track`
- `test_search_track_artist_albums`
- `test_search_track_artist_album_tracks`
- `test_soco_library_updating`
- `test_soco_start_library_update`
- `test_soco_list_library_shares`
- `test_soco_delete_library_share`
- `test_get_albums_for_artist_includes_subclasses`

## `test_music_service_data_structures.py` — PORTED

Swift coverage: `SMAPITests.swift`

Original functions (13):

- `test_get_class`
- `test_parse_response`
- `test_parse_response_plain_dict_fields`
- `test_parse_response_bad_type`
- `test_form_uri`
- `test_bool_str`
- `test_init`
- `test_conversion`
- `test_get_attr`
- `test_init`
- `test_from_music_service`
- `test_str_`
- `test_to_element`

## `test_musicservices.py` — PORTED / CONSOLIDATED

Swift coverage: `MusicServiceTests.swift`

Original functions (11):

- `test_initialise_account`
- `test_get_all_accounts`
- `test_get_accounts_for_service`
- `test_initialise_services`
- `test_get_data_for_name`
- `test_get_names`
- `test_create_music_service`
- `test_tunein`
- `test_search`
- `test_sonos_uri_from_id`
- `test_desc`

## `test_new_datastructures.py` — PORTED / CONSOLIDATED

Swift coverage: `DIDLTests.swift`, `CompatibilityTests.swift`

Original functions (30):

- `test_didl_object_inheritance`
- `test_didl_class_to_soco_class_none_raises`
- `test_didl_class_to_soco_class_generated_class_has_docstring`
- `test_create_didl_resource_with_no_params`
- `test_create_didl_resource`
- `test_create_didl_resource_to_from_element`
- `test_didl_resource_to_dict`
- `test_didl_resource_to_dict_remove_nones`
- `test_didl_resource_from_dict`
- `test_didl_resource_from_dict_remove_nones`
- `test_didl_resource_eq`
- `test_create_didl_object_with_no_params`
- `test_create_didl_object_with_disallowed_params`
- `test_create_didl_object_with_good_params`
- `test_didl_object_from_wrong_element`
- `test_didl_object_from_element`
- `test_didl_object_from_element_unoff_subelement`
- `test_didl_object_from_wrong_class`
- `test_didl_object_from_dict`
- `test_didl_object_from_dict_resources`
- `test_didl_object_from_dict_resources_remove_nones`
- `test_didl_comparisons`
- `test_didl_object_to_dict`
- `test_didl_object_to_dict_resources`
- `test_didl_object_to_dict_resources_remove_nones`
- `test_didl_object_to_element`
- `test_reference_returns_referenced_object`
- `test_reference_setter_round_trips`
- `test_reference_without_resource_meta_data_raises`
- `test_reference_with_empty_resource_meta_data_raises`

## `test_services.py` — PORTED

Swift coverage: `ServicesTests.swift`

Original functions (13):

- `test_init_defaults`
- `test_method_dispatcher_function_creation`
- `test_method_dispatcher_arg_count`
- `test_wrap`
- `test_unwrap`
- `test_unwrap_invalid_char`
- `test_compose`
- `test_build_command`
- `test_send_command`
- `test_build_command_content_directory`
- `test_handle_upnp_error`
- `test_handle_upnp_error_with_no_error_code`
- `test_handle_upnp_error_with_empty_response`

## `test_singleton.py` — SWIFT ADAPTATION

Swift coverage: `CompatibilityTests.swift`; constructor identity cannot exist in Swift, so latest-live-wrapper-per-IP registry/reset semantics are tested.

Original functions (4):

- `test_singleton`
- `test_singleton_inherit`
- `test_class_group_singleton`
- `test_soco_reset_clears_instances`

## `test_snapshot.py` — PORTED + EXPANDED

Swift coverage: `SnapshotTests.swift`

Original functions (3):

- `test_restore_queue_calls_add_uri_to_queue`
- `test_restore_queue_http_uri`
- `test_restore_queue_skipped_when_none`

## `test_soap.py` — PORTED

Swift coverage: `SOAPTests.swift`

Original functions (6):

- `test_init`
- `test_prepare_headers`
- `test_prepare_soap_header`
- `test_prepare_soap_body`
- `test_prepare`
- `test_call`

## `test_utils.py` — SWIFT ADAPTATION

Swift coverage: Runtime Python deprecation decorator is replaced with Swift availability attributes; other utility behavior is in `UtilitiesTests.swift`.

Original functions (1):

- `test_deprecation`

## `test_xml.py` — PORTED + EXPANDED

Swift coverage: `XMLTests.swift`, `CompatibilityTests.swift`

Original functions (1):

- `test_ns_tag`
