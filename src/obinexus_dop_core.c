// Implementation File: obinexus_dop_core.c
#include "obinexus_dop_core.h"
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <sys/time.h>

// Data-Oriented Implementation: Pure Functions Operating on Data

// Time Utilities Implementation
dop_time_data_t dop_time_get_current(void) {
    struct timeval tv;
    gettimeofday(&tv, NULL);
    
    time_t seconds = tv.tv_sec;
    struct tm* tm_info = localtime(&seconds);
    
    dop_time_data_t time_data = {
        .timestamp_ms = (uint64_t)tv.tv_sec * 1000 + tv.tv_usec / 1000,
        .hours = tm_info->tm_hour,
        .minutes = tm_info->tm_min,
        .seconds = tm_info->tm_sec,
        .milliseconds = tv.tv_usec / 1000,
        .is_valid = true
    };
    
    return time_data;
}

uint32_t dop_checksum_calculate(const dop_component_t* component) {
    if (!component) return 0;
    
    // Simple CRC32-like checksum for demo
    uint32_t checksum = 0xFFFFFFFF;
    const uint8_t* data = (const uint8_t*)&component->data;
    size_t size = sizeof(dop_component_data_t);
    
    for (size_t i = 0; i < size; i++) {
        checksum ^= data[i];
        for (int j = 0; j < 8; j++) {
            if (checksum & 1) {
                checksum = (checksum >> 1) ^ 0xEDB88320;
            } else {
                checksum >>= 1;
            }
        }
    }
    
    return ~checksum;
}

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
            break;
        case DOP_COMPONENT_CLOCK:
            strcpy(component->metadata.component_name, "Clock Component");
            break;
        case DOP_COMPONENT_STOPWATCH:
            strcpy(component->metadata.component_name, "Stopwatch Component");
            break;
        case DOP_COMPONENT_TIMER:
            strcpy(component->metadata.component_name, "Timer Component");
            break;
        default:
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
                }
            }
            break;
    }
    
    component->metadata.last_update_timestamp = current_time.timestamp_ms;
    component->checksum = dop_checksum_calculate(component);
    
    pthread_mutex_unlock(&component->metadata.mutex);
    return DOP_SUCCESS;
}

// Governance Gate Implementation
int dop_gate_open(dop_component_t* component) {
    if (!component) return DOP_ERROR_INVALID_PARAMETER;
    
    pthread_mutex_lock(&component->metadata.mutex);
    component->metadata.gate_state = DOP_GATE_OPEN;
    pthread_mutex_unlock(&component->metadata.mutex);
    
    return DOP_SUCCESS;
}

int dop_gate_close(dop_component_t* component) {
    if (!component) return DOP_ERROR_INVALID_PARAMETER;
    
    pthread_mutex_lock(&component->metadata.mutex);
    component->metadata.gate_state = DOP_GATE_CLOSED;
    pthread_mutex_unlock(&component->metadata.mutex);
    
    return DOP_SUCCESS;
}

bool dop_gate_is_accessible(const dop_component_t* component) {
    if (!component) return false;
    return component->metadata.gate_state == DOP_GATE_OPEN;
}

// Error Handling
const char* dop_error_to_string(dop_error_code_t error) {
    switch (error) {
        case DOP_SUCCESS: return "Success";
        case DOP_ERROR_INVALID_PARAMETER: return "Invalid parameter";
        case DOP_ERROR_INVALID_STATE: return "Invalid state";
        case DOP_ERROR_MEMORY_ALLOCATION: return "Memory allocation failed";
        case DOP_ERROR_GATE_CLOSED: return "Component gate is closed";
        case DOP_ERROR_CHECKSUM_FAILED: return "Checksum verification failed";
        case DOP_ERROR_TOPOLOGY_FAULT: return "Topology fault detected";
        case DOP_ERROR_XML_PARSING: return "XML parsing error";
        default: return "Unknown error";
    }
}
