// obinexus_dop_core.c - Fixed enumeration handling
// OBINexus Computing - Data-Oriented Programming Core Module

#include "obinexus_dop_core.h"
#include <assert.h>

// Static assertion to ensure enum consistency
_Static_assert(DOP_COMPONENT_COUNT == 4,
               "DOP_COMPONENT_TYPE enum has changed - update switch statements!");

// Functional Programming Interface Implementation
dop_component_t* dop_func_create_component(dop_component_type_t type) {
    dop_component_t* component = calloc(1, sizeof(dop_component_t));
    if (!component) return NULL;

    // Initialize metadata
    snprintf(component->metadata.component_id, sizeof(component->metadata.component_id),
             "comp_%d_%llu", type, (unsigned long long)time(NULL));

    switch (type) {
        case DOP_COMPONENT_ALARM:
            strcpy(component->metadata.component_name, "Alarm Component");
            component->metadata.component_class = "temporal.alarm";
            component->metadata.hot_swappable = true;
            break;
        case DOP_COMPONENT_CLOCK:
            strcpy(component->metadata.component_name, "Clock Component");
            component->metadata.component_class = "temporal.clock";
            component->metadata.hot_swappable = true;
            break;
        case DOP_COMPONENT_STOPWATCH:
            strcpy(component->metadata.component_name, "Stopwatch Component");
            component->metadata.component_class = "temporal.stopwatch";
            component->metadata.hot_swappable = true;
            break;
        case DOP_COMPONENT_TIMER:
            strcpy(component->metadata.component_name, "Timer Component");
            component->metadata.component_class = "temporal.timer";
            component->metadata.hot_swappable = true;
            break;
        case DOP_COMPONENT_COUNT:
            // Sentinel value - not a valid runtime component type
            // This case prevents compiler warnings while maintaining safety
            fprintf(stderr, "ERROR: DOP_COMPONENT_COUNT is not a valid component type\n");
            free(component);
            return NULL;
        default:
            // Unexpected component type - defensive programming
            fprintf(stderr, "ERROR: Invalid component type %d\n", type);
            free(component);
            return NULL;
    }

    strcpy(component->metadata.version, "1.0.0");
    component->metadata.type = type;
    component->metadata.state = DOP_STATE_READY;
    component->metadata.gate_state = DOP_GATE_CLOSED;
    component->metadata.creation_timestamp = (uint64_t)time(NULL) * 1000;
    component->metadata.last_update_timestamp = component->metadata.creation_timestamp;

    pthread_mutex_init(&component->metadata.mutex, NULL);

    // Initialize component-specific data
    switch (type) {
        case DOP_COMPONENT_CLOCK:
            component->data.clock.current_time = dop_time_get_current();
            component->data.clock.is_running = true;
            component->data.clock.timezone_offset = 0;
            component->data.clock.is_24_hour_format = true;
            break;
        case DOP_COMPONENT_ALARM:
            component->data.alarm.current_time = dop_time_get_current();
            component->data.alarm.is_armed = false;
            component->data.alarm.is_triggered = false;
            component->data.alarm.snooze_duration_ms = 300000; // 5 minutes
            break;
        case DOP_COMPONENT_STOPWATCH:
            component->data.stopwatch.is_running = false;
            component->data.stopwatch.is_paused = false;
            component->data.stopwatch.lap_count = 0;
            break;
        case DOP_COMPONENT_TIMER:
            component->data.timer.is_running = false;
            component->data.timer.is_expired = false;
            component->data.timer.auto_restart = false;
            break;
        case DOP_COMPONENT_COUNT:
            // Already handled above - unreachable
            assert(0 && "DOP_COMPONENT_COUNT should not reach component initialization");
            break;
        default:
            // Already handled above - unreachable
            assert(0 && "Invalid component type should not reach initialization");
            break;
    }

    component->checksum = dop_checksum_calculate(component);
    return component;
}

int dop_func_update_component(dop_component_t* component) {
    if (!component || !dop_gate_is_accessible(component)) {
        return DOP_ERROR_INVALID_PARAMETER;
    }

    pthread_mutex_lock(&component->metadata.mutex);

    dop_time_data_t current_time = dop_time_get_current();

    switch (component->metadata.type) {
        case DOP_COMPONENT_CLOCK:
            component->data.clock.current_time = current_time;
            break;

        case DOP_COMPONENT_ALARM:
            component->data.alarm.current_time = current_time;
            if (component->data.alarm.is_armed &&
                dop_time_is_equal(current_time, component->data.alarm.alarm_time)) {
                component->data.alarm.is_triggered = true;
            }
            break;

        case DOP_COMPONENT_STOPWATCH:
            if (component->data.stopwatch.is_running && !component->data.stopwatch.is_paused) {
                component->data.stopwatch.current_time = current_time;
                component->data.stopwatch.elapsed_time = dop_time_add_duration(
                    component->data.stopwatch.elapsed_time,
                    dop_time_diff_ms(component->data.stopwatch.current_time,
                                   component->data.stopwatch.start_time)
                );
            }
            break;

        case DOP_COMPONENT_TIMER:
            if (component->data.timer.is_running) {
                uint64_t elapsed = dop_time_diff_ms(current_time, component->data.timer.start_time);
                if (elapsed >= component->data.timer.duration.timestamp_ms) {
                    component->data.timer.is_expired = true;
                    component->data.timer.is_running = false;

                    // Handle auto-restart if enabled
                    if (component->data.timer.auto_restart) {
                        component->data.timer.start_time = current_time;
                        component->data.timer.is_running = true;
                        component->data.timer.is_expired = false;
                    }
                }
            }
            break;

        case DOP_COMPONENT_COUNT:
            // Invalid component type for runtime update
            pthread_mutex_unlock(&component->metadata.mutex);
            return DOP_ERROR_INVALID_COMPONENT_TYPE;

        default:
            // Unexpected component type
            pthread_mutex_unlock(&component->metadata.mutex);
            return DOP_ERROR_UNKNOWN_TYPE;
    }

    component->metadata.last_update_timestamp = current_time.timestamp_ms;
    component->checksum = dop_checksum_calculate(component);

    pthread_mutex_unlock(&component->metadata.mutex);
    return DOP_SUCCESS;
}

// Utility function to validate component type at runtime
int dop_validate_component_type(dop_component_type_t type) {
    if (type >= 0 && type < DOP_COMPONENT_COUNT) {
        return DOP_SUCCESS;
    }
    return DOP_ERROR_INVALID_COMPONENT_TYPE;
}

// Enhanced semantic version validation for hot-swappable components
typedef struct {
    uint32_t major;
    uint32_t minor;
    uint32_t patch;
    char prerelease[64];
    char build_metadata[128];
} semantic_version_t;

int dop_parse_semantic_version(const char* version_str, semantic_version_t* version) {
    if (!version_str || !version) {
        return DOP_ERROR_INVALID_PARAMETER;
    }

    // Parse semantic version according to semver 2.0.0 spec
    int matches = sscanf(version_str, "%u.%u.%u",
                        &version->major,
                        &version->minor,
                        &version->patch);

    if (matches != 3) {
        return DOP_ERROR_INVALID_VERSION_FORMAT;
    }

    // Parse prerelease and build metadata if present
    const char* prerelease_start = strchr(version_str, '-');
    const char* build_start = strchr(version_str, '+');

    if (prerelease_start) {
        size_t prerelease_len = build_start ?
            (size_t)(build_start - prerelease_start - 1) :
            strlen(prerelease_start + 1);

        if (prerelease_len >= sizeof(version->prerelease)) {
            return DOP_ERROR_VERSION_STRING_TOO_LONG;
        }

        strncpy(version->prerelease, prerelease_start + 1, prerelease_len);
        version->prerelease[prerelease_len] = '\0';
    } else {
        version->prerelease[0] = '\0';
    }

    if (build_start) {
        strncpy(version->build_metadata, build_start + 1,
                sizeof(version->build_metadata) - 1);
        version->build_metadata[sizeof(version->build_metadata) - 1] = '\0';
    } else {
        version->build_metadata[0] = '\0';
    }

    return DOP_SUCCESS;
}

// Fault tolerance enhancement for component adapters
typedef struct {
    char adapter_id[64];
    semantic_version_t version;
    bool is_hot_swappable;
    uint32_t fault_tolerance_level;  // 0-100 percentage
    uint64_t last_health_check;
    uint32_t consecutive_failures;
    uint32_t max_retry_attempts;
} adapter_metadata_t;

int dop_adapter_validate_health(adapter_metadata_t* adapter) {
    if (!adapter) {
        return DOP_ERROR_INVALID_PARAMETER;
    }

    // Check if adapter requires health validation
    uint64_t current_time_ms = (uint64_t)time(NULL) * 1000;
    uint64_t time_since_last_check = current_time_ms - adapter->last_health_check;

    // Health check every 30 seconds for critical adapters
    if (time_since_last_check > 30000) {
        // Simulate health check (in production, this would query actual adapter)
        bool health_check_passed = (rand() % 100) > 5; // 95% success rate

        if (!health_check_passed) {
            adapter->consecutive_failures++;

            if (adapter->consecutive_failures >= adapter->max_retry_attempts) {
                return DOP_ERROR_ADAPTER_UNHEALTHY;
            }

            // Apply exponential backoff
            usleep(1000 * (1 << adapter->consecutive_failures));
            return DOP_WARNING_ADAPTER_DEGRADED;
        }

        // Reset failure counter on success
        adapter->consecutive_failures = 0;
        adapter->last_health_check = current_time_ms;
    }

    return DOP_SUCCESS;
}
