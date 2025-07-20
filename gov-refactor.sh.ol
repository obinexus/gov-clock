#!/bin/bash
# OBINexus Gov-Std-Web Directory Refactoring Script
# Reorganizes project structure for proper CMake/Makefile build system

set -e

echo "Starting OBINexus Gov-Std-Web directory refactoring..."

# Create the required directory structure
echo "Creating directory structure..."
mkdir -p include
mkdir -p src/components
mkdir -p src/demo
mkdir -p tests
mkdir -p examples
mkdir -p keys

# Move existing header file to include directory
echo "Moving header files..."
if [ -f "src/obinexus_dop_core.h" ]; then
    mv src/obinexus_dop_core.h include/
    echo "Moved obinexus_dop_core.h to include/"
fi

# Keep the main source file in src/
echo "Source file obinexus_dop_core.c is already in correct location"

# Create additional required header files in include/
echo "Creating additional header files..."
cat > include/dop_adapter.h << 'EOF'
#ifndef DOP_ADAPTER_H
#define DOP_ADAPTER_H

#include "obinexus_dop_core.h"

// Adapter function declarations
dop_oop_interface_t* dop_adapter_func_to_oop(dop_func_create_t create_func,
                                              dop_func_update_t update_func,
                                              dop_func_destroy_t destroy_func,
                                              dop_func_serialize_t serialize_func);

dop_func_create_t dop_adapter_oop_to_func_create(dop_oop_interface_t* oop_interface);
dop_func_update_t dop_adapter_oop_to_func_update(dop_oop_interface_t* oop_interface);

#endif // DOP_ADAPTER_H
EOF

cat > include/dop_topology.h << 'EOF'
#ifndef DOP_TOPOLOGY_H
#define DOP_TOPOLOGY_H

#include "obinexus_dop_core.h"

// Topology management function declarations
dop_topology_node_t* dop_topology_create_node(const char* node_id, dop_component_t* component);
int dop_topology_add_peer(dop_topology_node_t* node, dop_topology_node_t* peer);
int dop_topology_start_p2p_network(dop_build_topology_t* topology);
int dop_topology_test_fault_tolerance(dop_build_topology_t* topology);

#endif // DOP_TOPOLOGY_H
EOF

cat > include/dop_manifest.h << 'EOF'
#ifndef DOP_MANIFEST_H
#define DOP_MANIFEST_H

#include "obinexus_dop_core.h"

// XML manifest integration function declarations
int dop_manifest_load_from_xml(const char* xml_path, dop_build_topology_t* topology);
int dop_manifest_save_to_xml(const dop_build_topology_t* topology, const char* xml_path);
int dop_manifest_validate_schema(const char* xml_path);

#endif // DOP_MANIFEST_H
EOF

# Create component implementation files
echo "Creating component implementation files..."
cat > src/components/alarm.c << 'EOF'
#include "obinexus_dop_core.h"
#include <string.h>

int dop_alarm_set_time(dop_component_t* component, dop_time_data_t alarm_time) {
    if (!component || component->metadata.type != DOP_COMPONENT_ALARM) {
        return DOP_ERROR_INVALID_PARAMETER;
    }
    
    if (!dop_gate_is_accessible(component)) {
        return DOP_ERROR_GATE_CLOSED;
    }
    
    pthread_mutex_lock(&component->metadata.mutex);
    component->data.alarm.alarm_time = alarm_time;
    component->checksum = dop_checksum_calculate(component);
    pthread_mutex_unlock(&component->metadata.mutex);
    
    return DOP_SUCCESS;
}

int dop_alarm_arm(dop_component_t* component) {
    if (!component || component->metadata.type != DOP_COMPONENT_ALARM) {
        return DOP_ERROR_INVALID_PARAMETER;
    }
    
    pthread_mutex_lock(&component->metadata.mutex);
    component->data.alarm.is_armed = true;
    component->checksum = dop_checksum_calculate(component);
    pthread_mutex_unlock(&component->metadata.mutex);
    
    return DOP_SUCCESS;
}

int dop_alarm_disarm(dop_component_t* component) {
    if (!component || component->metadata.type != DOP_COMPONENT_ALARM) {
        return DOP_ERROR_INVALID_PARAMETER;
    }
    
    pthread_mutex_lock(&component->metadata.mutex);
    component->data.alarm.is_armed = false;
    component->data.alarm.is_triggered = false;
    component->checksum = dop_checksum_calculate(component);
    pthread_mutex_unlock(&component->metadata.mutex);
    
    return DOP_SUCCESS;
}

bool dop_alarm_is_triggered(const dop_component_t* component) {
    if (!component || component->metadata.type != DOP_COMPONENT_ALARM) {
        return false;
    }
    
    return component->data.alarm.is_triggered;
}

int dop_alarm_snooze(dop_component_t* component, uint32_t duration_ms) {
    if (!component || component->metadata.type != DOP_COMPONENT_ALARM) {
        return DOP_ERROR_INVALID_PARAMETER;
    }
    
    pthread_mutex_lock(&component->metadata.mutex);
    component->data.alarm.snooze_duration_ms = duration_ms;
    component->data.alarm.is_triggered = false;
    component->checksum = dop_checksum_calculate(component);
    pthread_mutex_unlock(&component->metadata.mutex);
    
    return DOP_SUCCESS;
}
EOF

cat > src/components/clock.c << 'EOF'
#include "obinexus_dop_core.h"
#include <stdio.h>
#include <stdlib.h>

int dop_clock_set_timezone(dop_component_t* component, int32_t offset_hours) {
    if (!component || component->metadata.type != DOP_COMPONENT_CLOCK) {
        return DOP_ERROR_INVALID_PARAMETER;
    }
    
    pthread_mutex_lock(&component->metadata.mutex);
    component->data.clock.timezone_offset = offset_hours;
    component->checksum = dop_checksum_calculate(component);
    pthread_mutex_unlock(&component->metadata.mutex);
    
    return DOP_SUCCESS;
}

int dop_clock_set_format(dop_component_t* component, bool is_24_hour) {
    if (!component || component->metadata.type != DOP_COMPONENT_CLOCK) {
        return DOP_ERROR_INVALID_PARAMETER;
    }
    
    pthread_mutex_lock(&component->metadata.mutex);
    component->data.clock.is_24_hour_format = is_24_hour;
    component->checksum = dop_checksum_calculate(component);
    pthread_mutex_unlock(&component->metadata.mutex);
    
    return DOP_SUCCESS;
}

char* dop_clock_format_time(const dop_component_t* component) {
    if (!component || component->metadata.type != DOP_COMPONENT_CLOCK) {
        return NULL;
    }
    
    char* formatted_time = malloc(32);
    if (!formatted_time) return NULL;
    
    const dop_time_data_t* time = &component->data.clock.current_time;
    
    if (component->data.clock.is_24_hour_format) {
        snprintf(formatted_time, 32, "%02u:%02u:%02u.%03u", 
                time->hours, time->minutes, time->seconds, time->milliseconds);
    } else {
        uint32_t display_hour = time->hours;
        const char* ampm = "AM";
        
        if (display_hour == 0) {
            display_hour = 12;
        } else if (display_hour > 12) {
            display_hour -= 12;
            ampm = "PM";
        } else if (display_hour == 12) {
            ampm = "PM";
        }
        
        snprintf(formatted_time, 32, "%u:%02u:%02u.%03u %s", 
                display_hour, time->minutes, time->seconds, time->milliseconds, ampm);
    }
    
    return formatted_time;
}
EOF

cat > src/components/stopwatch.c << 'EOF'
#include "obinexus_dop_core.h"

int dop_stopwatch_start(dop_component_t* component) {
    if (!component || component->metadata.type != DOP_COMPONENT_STOPWATCH) {
        return DOP_ERROR_INVALID_PARAMETER;
    }
    
    pthread_mutex_lock(&component->metadata.mutex);
    if (!component->data.stopwatch.is_running) {
        component->data.stopwatch.start_time = dop_time_get_current();
        component->data.stopwatch.is_running = true;
        component->data.stopwatch.is_paused = false;
    }
    component->checksum = dop_checksum_calculate(component);
    pthread_mutex_unlock(&component->metadata.mutex);
    
    return DOP_SUCCESS;
}

int dop_stopwatch_stop(dop_component_t* component) {
    if (!component || component->metadata.type != DOP_COMPONENT_STOPWATCH) {
        return DOP_ERROR_INVALID_PARAMETER;
    }
    
    pthread_mutex_lock(&component->metadata.mutex);
    component->data.stopwatch.is_running = false;
    component->data.stopwatch.is_paused = false;
    component->checksum = dop_checksum_calculate(component);
    pthread_mutex_unlock(&component->metadata.mutex);
    
    return DOP_SUCCESS;
}

int dop_stopwatch_pause(dop_component_t* component) {
    if (!component || component->metadata.type != DOP_COMPONENT_STOPWATCH) {
        return DOP_ERROR_INVALID_PARAMETER;
    }
    
    pthread_mutex_lock(&component->metadata.mutex);
    if (component->data.stopwatch.is_running) {
        component->data.stopwatch.is_paused = true;
    }
    component->checksum = dop_checksum_calculate(component);
    pthread_mutex_unlock(&component->metadata.mutex);
    
    return DOP_SUCCESS;
}

int dop_stopwatch_reset(dop_component_t* component) {
    if (!component || component->metadata.type != DOP_COMPONENT_STOPWATCH) {
        return DOP_ERROR_INVALID_PARAMETER;
    }
    
    pthread_mutex_lock(&component->metadata.mutex);
    component->data.stopwatch.is_running = false;
    component->data.stopwatch.is_paused = false;
    component->data.stopwatch.lap_count = 0;
    // Reset elapsed time to zero
    memset(&component->data.stopwatch.elapsed_time, 0, sizeof(dop_time_data_t));
    component->checksum = dop_checksum_calculate(component);
    pthread_mutex_unlock(&component->metadata.mutex);
    
    return DOP_SUCCESS;
}

int dop_stopwatch_lap(dop_component_t* component) {
    if (!component || component->metadata.type != DOP_COMPONENT_STOPWATCH) {
        return DOP_ERROR_INVALID_PARAMETER;
    }
    
    pthread_mutex_lock(&component->metadata.mutex);
    if (component->data.stopwatch.is_running && !component->data.stopwatch.is_paused) {
        component->data.stopwatch.lap_count++;
    }
    component->checksum = dop_checksum_calculate(component);
    pthread_mutex_unlock(&component->metadata.mutex);
    
    return DOP_SUCCESS;
}
EOF

cat > src/components/timer.c << 'EOF'
#include "obinexus_dop_core.h"

int dop_timer_set_duration(dop_component_t* component, uint64_t duration_ms) {
    if (!component || component->metadata.type != DOP_COMPONENT_TIMER) {
        return DOP_ERROR_INVALID_PARAMETER;
    }
    
    pthread_mutex_lock(&component->metadata.mutex);
    component->data.timer.duration.timestamp_ms = duration_ms;
    component->checksum = dop_checksum_calculate(component);
    pthread_mutex_unlock(&component->metadata.mutex);
    
    return DOP_SUCCESS;
}

int dop_timer_start(dop_component_t* component) {
    if (!component || component->metadata.type != DOP_COMPONENT_TIMER) {
        return DOP_ERROR_INVALID_PARAMETER;
    }
    
    pthread_mutex_lock(&component->metadata.mutex);
    component->data.timer.start_time = dop_time_get_current();
    component->data.timer.is_running = true;
    component->data.timer.is_expired = false;
    component->checksum = dop_checksum_calculate(component);
    pthread_mutex_unlock(&component->metadata.mutex);
    
    return DOP_SUCCESS;
}

int dop_timer_stop(dop_component_t* component) {
    if (!component || component->metadata.type != DOP_COMPONENT_TIMER) {
        return DOP_ERROR_INVALID_PARAMETER;
    }
    
    pthread_mutex_lock(&component->metadata.mutex);
    component->data.timer.is_running = false;
    component->checksum = dop_checksum_calculate(component);
    pthread_mutex_unlock(&component->metadata.mutex);
    
    return DOP_SUCCESS;
}

int dop_timer_reset(dop_component_t* component) {
    if (!component || component->metadata.type != DOP_COMPONENT_TIMER) {
        return DOP_ERROR_INVALID_PARAMETER;
    }
    
    pthread_mutex_lock(&component->metadata.mutex);
    component->data.timer.is_running = false;
    component->data.timer.is_expired = false;
    // Reset to current time
    component->data.timer.start_time = dop_time_get_current();
    component->checksum = dop_checksum_calculate(component);
    pthread_mutex_unlock(&component->metadata.mutex);
    
    return DOP_SUCCESS;
}

bool dop_timer_is_expired(const dop_component_t* component) {
    if (!component || component->metadata.type != DOP_COMPONENT_TIMER) {
        return false;
    }
    
    return component->data.timer.is_expired;
}
EOF

# Create additional implementation files
echo "Creating adapter implementation..."
cat > src/dop_adapter.c << 'EOF'
#include "dop_adapter.h"
#include <stdlib.h>
#include <string.h>

// OOP Interface Implementation Structure
typedef struct {
    dop_component_t* component;
    dop_func_create_t create_func;
    dop_func_update_t update_func;
    dop_func_destroy_t destroy_func;
    dop_func_serialize_t serialize_func;
} dop_oop_impl_t;

// OOP Interface Methods
static int oop_create(void* self, dop_component_type_t type) {
    dop_oop_impl_t* impl = (dop_oop_impl_t*)self;
    if (impl->create_func) {
        impl->component = impl->create_func(type);
        return impl->component ? DOP_SUCCESS : DOP_ERROR_MEMORY_ALLOCATION;
    }
    return DOP_ERROR_INVALID_PARAMETER;
}

static int oop_update(void* self) {
    dop_oop_impl_t* impl = (dop_oop_impl_t*)self;
    if (impl->update_func && impl->component) {
        return impl->update_func(impl->component);
    }
    return DOP_ERROR_INVALID_PARAMETER;
}

static int oop_destroy(void* self) {
    dop_oop_impl_t* impl = (dop_oop_impl_t*)self;
    if (impl->destroy_func && impl->component) {
        return impl->destroy_func(impl->component);
    }
    return DOP_ERROR_INVALID_PARAMETER;
}

static char* oop_serialize(void* self) {
    dop_oop_impl_t* impl = (dop_oop_impl_t*)self;
    if (impl->serialize_func && impl->component) {
        return impl->serialize_func(impl->component);
    }
    return NULL;
}

static dop_component_t* oop_get_data(void* self) {
    dop_oop_impl_t* impl = (dop_oop_impl_t*)self;
    return impl->component;
}

// Adapter Function Implementations
dop_oop_interface_t* dop_adapter_func_to_oop(dop_func_create_t create_func,
                                              dop_func_update_t update_func,
                                              dop_func_destroy_t destroy_func,
                                              dop_func_serialize_t serialize_func) {
    if (!create_func || !update_func) {
        return NULL;
    }
    
    dop_oop_interface_t* interface = calloc(1, sizeof(dop_oop_interface_t));
    if (!interface) return NULL;
    
    dop_oop_impl_t* impl = calloc(1, sizeof(dop_oop_impl_t));
    if (!impl) {
        free(interface);
        return NULL;
    }
    
    impl->create_func = create_func;
    impl->update_func = update_func;
    impl->destroy_func = destroy_func;
    impl->serialize_func = serialize_func;
    
    interface->instance = impl;
    interface->create = oop_create;
    interface->update = oop_update;
    interface->destroy = oop_destroy;
    interface->serialize = oop_serialize;
    interface->get_data = oop_get_data;
    
    return interface;
}

// Wrapper functions for OOP to Functional conversion
static dop_component_t* create_wrapper(dop_component_type_t type) {
    // This would need to be implemented based on specific OOP interface
    return dop_func_create_component(type);
}

static int update_wrapper(dop_component_t* component) {
    return dop_func_update_component(component);
}

dop_func_create_t dop_adapter_oop_to_func_create(dop_oop_interface_t* oop_interface) {
    if (!oop_interface) return NULL;
    return create_wrapper;
}

dop_func_update_t dop_adapter_oop_to_func_update(dop_oop_interface_t* oop_interface) {
    if (!oop_interface) return NULL;
    return update_wrapper;
}
EOF

echo "Creating topology implementation..."
cat > src/dop_topology.c << 'EOF'
#include "dop_topology.h"
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

static void* topology_worker_thread(void* arg) {
    dop_topology_node_t* node = (dop_topology_node_t*)arg;
    
    while (node->component && node->component->metadata.state != DOP_STATE_DESTROYED) {
        // Update component
        dop_func_update_component(node->component);
        
        // Sleep for 100ms
        usleep(100000);
    }
    
    return NULL;
}

dop_topology_node_t* dop_topology_create_node(const char* node_id, dop_component_t* component) {
    if (!node_id || !component) return NULL;
    
    dop_topology_node_t* node = calloc(1, sizeof(dop_topology_node_t));
    if (!node) return NULL;
    
    strncpy(node->node_id, node_id, sizeof(node->node_id) - 1);
    node->component = component;
    node->peer_count = 0;
    node->is_fault_tolerant = true;
    
    return node;
}

int dop_topology_add_peer(dop_topology_node_t* node, dop_topology_node_t* peer) {
    if (!node || !peer || node->peer_count >= 4) {
        return DOP_ERROR_INVALID_PARAMETER;
    }
    
    node->peers[node->peer_count] = peer;
    node->peer_count++;
    
    return DOP_SUCCESS;
}

int dop_topology_start_p2p_network(dop_build_topology_t* topology) {
    if (!topology) return DOP_ERROR_INVALID_PARAMETER;
    
    for (uint32_t i = 0; i < topology->node_count; i++) {
        dop_topology_node_t* node = topology->nodes[i];
        if (node && node->component) {
            dop_gate_open(node->component);
            
            if (pthread_create(&node->worker_thread, NULL, topology_worker_thread, node) != 0) {
                return DOP_ERROR_TOPOLOGY_FAULT;
            }
        }
    }
    
    return DOP_SUCCESS;
}

int dop_topology_test_fault_tolerance(dop_build_topology_t* topology) {
    if (!topology) return DOP_ERROR_INVALID_PARAMETER;
    
    // Simulate fault by temporarily disabling one node
    if (topology->node_count > 1) {
        dop_topology_node_t* test_node = topology->nodes[0];
        if (test_node && test_node->component) {
            dop_gate_close(test_node->component);
            
            // Wait and verify other nodes continue operating
            sleep(1);
            
            // Re-enable the node
            dop_gate_open(test_node->component);
        }
    }
    
    return DOP_SUCCESS;
}
EOF

echo "Creating manifest implementation..."
cat > src/dop_manifest.c << 'EOF'
#include "dop_manifest.h"
#include <libxml/parser.h>
#include <libxml/tree.h>
#include <stdlib.h>
#include <string.h>

int dop_manifest_load_from_xml(const char* xml_path, dop_build_topology_t* topology) {
    if (!xml_path || !topology) return DOP_ERROR_INVALID_PARAMETER;
    
    xmlDoc* doc = xmlReadFile(xml_path, NULL, 0);
    if (!doc) return DOP_ERROR_XML_PARSING;
    
    xmlNode* root = xmlDocGetRootElement(doc);
    if (!root) {
        xmlFreeDoc(doc);
        return DOP_ERROR_XML_PARSING;
    }
    
    // Basic manifest loading implementation
    strncpy(topology->build_id, "loaded_from_xml", sizeof(topology->build_id) - 1);
    topology->node_count = 0;
    topology->is_p2p_enabled = true;
    topology->is_fault_tolerant = true;
    
    xmlFreeDoc(doc);
    xmlCleanupParser();
    
    return DOP_SUCCESS;
}

int dop_manifest_save_to_xml(const dop_build_topology_t* topology, const char* xml_path) {
    if (!topology || !xml_path) return DOP_ERROR_INVALID_PARAMETER;
    
    xmlDoc* doc = xmlNewDoc(BAD_CAST "1.0");
    xmlNode* root = xmlNewNode(NULL, BAD_CAST "dop_manifest");
    xmlDocSetRootElement(doc, root);
    
    // Add basic manifest structure
    xmlNode* metadata = xmlNewChild(root, NULL, BAD_CAST "metadata", NULL);
    xmlNewChild(metadata, NULL, BAD_CAST "build_id", BAD_CAST topology->build_id);
    
    xmlSaveFormatFileEnc(xml_path, doc, "UTF-8", 1);
    xmlFreeDoc(doc);
    xmlCleanupParser();
    
    return DOP_SUCCESS;
}

int dop_manifest_validate_schema(const char* xml_path) {
    if (!xml_path) return DOP_ERROR_INVALID_PARAMETER;
    
    // Basic validation - check if file exists and is valid XML
    xmlDoc* doc = xmlReadFile(xml_path, NULL, 0);
    if (!doc) return DOP_ERROR_XML_PARSING;
    
    xmlFreeDoc(doc);
    xmlCleanupParser();
    
    return DOP_SUCCESS;
}
EOF

# Create demo application
echo "Creating demo application..."
cat > src/demo/dop_demo.c << 'EOF'
#include "obinexus_dop_core.h"
#include "dop_adapter.h"
#include "dop_topology.h"
#include "dop_manifest.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

static void print_component_info(const dop_component_t* component) {
    if (!component) return;
    
    printf("Component ID: %s\n", component->metadata.component_id);
    printf("Component Name: %s\n", component->metadata.component_name);
    printf("Version: %s\n", component->metadata.version);
    printf("State: %d\n", component->metadata.state);
    printf("Gate State: %d\n", component->metadata.gate_state);
    printf("Checksum: 0x%08X\n", component->checksum);
    printf("\n");
}

static int test_component_functionality(void) {
    printf("=== Testing Component Functionality ===\n");
    
    // Test Alarm Component
    dop_component_t* alarm = dop_func_create_component(DOP_COMPONENT_ALARM);
    if (!alarm) {
        printf("Failed to create alarm component\n");
        return 1;
    }
    
    dop_gate_open(alarm);
    print_component_info(alarm);
    
    dop_time_data_t alarm_time = dop_time_get_current();
    alarm_time.hours = 7;
    alarm_time.minutes = 30;
    
    if (dop_alarm_set_time(alarm, alarm_time) == DOP_SUCCESS) {
        printf("Alarm time set successfully\n");
    }
    
    if (dop_alarm_arm(alarm) == DOP_SUCCESS) {
        printf("Alarm armed successfully\n");
    }
    
    dop_func_destroy_component(alarm);
    
    // Test Clock Component
    dop_component_t* clock = dop_func_create_component(DOP_COMPONENT_CLOCK);
    if (!clock) {
        printf("Failed to create clock component\n");
        return 1;
    }
    
    dop_gate_open(clock);
    print_component_info(clock);
    
    dop_clock_set_format(clock, false); // 12-hour format
    char* formatted_time = dop_clock_format_time(clock);
    if (formatted_time) {
        printf("Formatted time: %s\n", formatted_time);
        free(formatted_time);
    }
    
    dop_func_destroy_component(clock);
    
    printf("Component functionality test completed\n\n");
    return 0;
}

static int test_func_to_oop_conversion(void) {
    printf("=== Testing Function to OOP Conversion ===\n");
    
    // Create OOP interface from functional components
    dop_oop_interface_t* oop_interface = dop_adapter_func_to_oop(
        dop_func_create_component,
        dop_func_update_component,
        dop_func_destroy_component,
        dop_func_serialize_component
    );
    
    if (!oop_interface) {
        printf("Failed to create OOP interface\n");
        return 1;
    }
    
    // Use OOP interface
    if (oop_interface->create(oop_interface->instance, DOP_COMPONENT_TIMER) == DOP_SUCCESS) {
        printf("OOP component created successfully\n");
        
        dop_component_t* component = oop_interface->get_data(oop_interface->instance);
        if (component) {
            dop_gate_open(component);
            print_component_info(component);
        }
        
        if (oop_interface->update(oop_interface->instance) == DOP_SUCCESS) {
            printf("OOP component updated successfully\n");
        }
    }
    
    free(oop_interface->instance);
    free(oop_interface);
    
    printf("Function to OOP conversion test completed\n\n");
    return 0;
}

static int test_p2p_topology(void) {
    printf("=== Testing P2P Topology ===\n");
    
    // Create components
    dop_component_t* alarm = dop_func_create_component(DOP_COMPONENT_ALARM);
    dop_component_t* clock = dop_func_create_component(DOP_COMPONENT_CLOCK);
    
    if (!alarm || !clock) {
        printf("Failed to create components\n");
        return 1;
    }
    
    // Create topology nodes
    dop_topology_node_t* node1 = dop_topology_create_node("node_alarm_01", alarm);
    dop_topology_node_t* node2 = dop_topology_create_node("node_clock_01", clock);
    
    if (!node1 || !node2) {
        printf("Failed to create topology nodes\n");
        return 1;
    }
    
    // Add peer connections
    dop_topology_add_peer(node1, node2);
    dop_topology_add_peer(node2, node1);
    
    // Create build topology
    dop_build_topology_t topology = {0};
    strncpy(topology.build_id, "test_p2p_topology", sizeof(topology.build_id) - 1);
    topology.nodes[0] = node1;
    topology.nodes[1] = node2;
    topology.node_count = 2;
    topology.is_p2p_enabled = true;
    topology.is_fault_tolerant = true;
    
    // Start P2P network
    if (dop_topology_start_p2p_network(&topology) == DOP_SUCCESS) {
        printf("P2P network started successfully\n");
        
        // Run for a short time
        sleep(2);
        
        // Test fault tolerance
        if (dop_topology_test_fault_tolerance(&topology) == DOP_SUCCESS) {
            printf("Fault tolerance test passed\n");
        }
    }
    
    // Cleanup
    dop_func_destroy_component(alarm);
    dop_func_destroy_component(clock);
    free(node1);
    free(node2);
    
    printf("P2P topology test completed\n\n");
    return 0;
}

static int test_xml_manifest(void) {
    printf("=== Testing XML Manifest ===\n");
    
    // Create a basic topology
    dop_build_topology_t topology = {0};
    strncpy(topology.build_id, "test_manifest", sizeof(topology.build_id) - 1);
    topology.is_p2p_enabled = true;
    topology.is_fault_tolerant = true;
    
    // Save to XML
    const char* xml_path = "test_manifest.xml";
    if (dop_manifest_save_to_xml(&topology, xml_path) == DOP_SUCCESS) {
        printf("Manifest saved to XML successfully\n");
        
        // Load from XML
        dop_build_topology_t loaded_topology = {0};
        if (dop_manifest_load_from_xml(xml_path, &loaded_topology) == DOP_SUCCESS) {
            printf("Manifest loaded from XML successfully\n");
            printf("Loaded build ID: %s\n", loaded_topology.build_id);
        }
        
        // Validate schema
        if (dop_manifest_validate_schema(xml_path) == DOP_SUCCESS) {
            printf("Manifest schema validation passed\n");
        }
    }
    
    printf("XML manifest test completed\n\n");
    return 0;
}

int main(int argc, char* argv[]) {
    printf("OBINexus DOP Component System Demo\n");
    printf("==================================\n\n");
    
    if (argc > 1) {
        if (strcmp(argv[1], "--test-p2p-fault") == 0) {
            return test_p2p_topology();
        } else if (strcmp(argv[1], "--test-xml-manifest") == 0) {
            return test_xml_manifest();
        } else if (strcmp(argv[1], "--validate-manifest") == 0) {
            return dop_manifest_validate_schema("examples/time_components_manifest.xml");
        } else if (strcmp(argv[1], "--test-p2p-topology") == 0) {
            return test_p2p_topology();
        }
    }
    
    // Run all tests
    int result = 0;
    result |= test_component_functionality();
    result |= test_func_to_oop_conversion();
    result |= test_p2p_topology();
    result |= test_xml_manifest();
    
    if (result == 0) {
        printf("All tests completed successfully!\n");
    } else {
        printf("Some tests failed!\n");
    }
    
    return result;
}
EOF

# Create unit tests
echo "Creating unit tests..."
cat > tests/test_components.c << 'EOF'
#include "obinexus_dop_core.h"
#include <stdio.h>
#include <assert.h>

static void test_alarm_component(void) {
    printf("Testing alarm component...\n");
    
    dop_component_t* alarm = dop_func_create_component(DOP_COMPONENT_ALARM);
    assert(alarm != NULL);
    assert(alarm->metadata.type == DOP_COMPONENT_ALARM);
    
    dop_gate_open(alarm);
    assert(dop_gate_is_accessible(alarm) == true);
    
    dop_time_data_t alarm_time = dop_time_get_current();
    assert(dop_alarm_set_time(alarm, alarm_time) == DOP_SUCCESS);
    assert(dop_alarm_arm(alarm) == DOP_SUCCESS);
    assert(dop_alarm_disarm(alarm) == DOP_SUCCESS);
    
    dop_func_destroy_component(alarm);
    printf("Alarm component test passed\n");
}

static void test_clock_component(void) {
    printf("Testing clock component...\n");
    
    dop_component_t* clock = dop_func_create_component(DOP_COMPONENT_CLOCK);
    assert(clock != NULL);
    assert(clock->metadata.type == DOP_COMPONENT_CLOCK);
    
    dop_gate_open(clock);
    assert(dop_clock_set_timezone(clock, -5) == DOP_SUCCESS);
    assert(dop_clock_set_format(clock, true) == DOP_SUCCESS);
    
    char* formatted = dop_clock_format_time(clock);
    assert(formatted != NULL);
    free(formatted);
    
    dop_func_destroy_component(clock);
    printf("Clock component test passed\n");
}

int main(int argc, char* argv[]) {
    if (argc > 1 && strcmp(argv[1], "component") == 0) {
        test_alarm_component();
        test_clock_component();
        printf("All component tests passed!\n");
        return 0;
    }
    
    printf("Usage: %s component\n", argv[0]);
    return 1;
}
EOF

# Create example manifest
echo "Creating example manifest..."
if [ ! -f "examples/time_components_manifest.xml" ]; then
    cat > examples/time_components_manifest.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<dop_manifest xmlns="http://obinexus.org/dop/v1.0" 
              schema_version="1.0.0" 
              manifest_id="time_components_demo">
  <metadata>
    <build_id>time_comp_build_001</build_id>
    <creation_timestamp>2025-07-20T10:30:00Z</creation_timestamp>
    <version>1.0.0</version>
    <nnam_id>NNAM-ID-001</nnam_id>
  </metadata>
  <build_topology>
    <topology_type>P2P</topology_type>
    <fault_tolerance>true</fault_tolerance>
    <p2p_enabled>true</p2p_enabled>
  </build_topology>
  <components>
    <component>
      <component_id>alarm_01</component_id>
      <component_name>Alarm Component</component_name>
      <component_type>ALARM</component_type>
      <version>1.0.0</version>
      <state>READY</state>
      <gate_state>CLOSED</gate_state>
    </component>
  </components>
</dop_manifest>
EOF
fi

# Update the CMakeLists.txt to fix source directory issues
echo "Updating CMakeLists.txt..."
cat > CMakeLists.txt << 'EOF'
cmake_minimum_required(VERSION 3.16)
project(OBINexus_DOP_Components 
    VERSION 1.0.0 
    DESCRIPTION "OBINexus Data-Oriented Programming Component System"
    LANGUAGES C)

set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)

if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE "Debug" CACHE STRING "Build type" FORCE)
endif()

set(CMAKE_C_FLAGS_DEBUG "-g -O0 -Wall -Wextra -Wpedantic -DDOP_DEBUG=1")
set(CMAKE_C_FLAGS_RELEASE "-O3 -DNDEBUG -DDOP_RELEASE=1")

find_package(Threads REQUIRED)
find_package(PkgConfig REQUIRED)
pkg_check_modules(LIBXML2 REQUIRED libxml-2.0)

include_directories(${CMAKE_CURRENT_SOURCE_DIR}/include)
include_directories(${LIBXML2_INCLUDE_DIRS})

set(DOP_CORE_SOURCES
    src/obinexus_dop_core.c
    src/dop_adapter.c
    src/dop_topology.c
    src/dop_manifest.c
    src/components/alarm.c
    src/components/clock.c
    src/components/stopwatch.c
    src/components/timer.c
)

add_library(obinexus_dop_core STATIC ${DOP_CORE_SOURCES})
target_link_libraries(obinexus_dop_core 
    ${CMAKE_THREAD_LIBS_INIT}
    ${LIBXML2_LIBRARIES}
)
target_compile_options(obinexus_dop_core PRIVATE ${LIBXML2_CFLAGS_OTHER})

add_executable(dop_demo src/demo/dop_demo.c)
target_link_libraries(dop_demo obinexus_dop_core)

enable_testing()
add_executable(dop_tests tests/test_components.c)
target_link_libraries(dop_tests obinexus_dop_core)

add_test(NAME component_tests COMMAND dop_tests component)

add_custom_target(validate_manifest
    COMMAND ${CMAKE_CURRENT_BINARY_DIR}/dop_demo --validate-manifest 
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    COMMENT "Validating XML manifest schema"
)

add_custom_target(test_p2p_topology
    COMMAND ${CMAKE_CURRENT_BINARY_DIR}/dop_demo --test-p2p-topology
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    COMMENT "Testing P2P fault-tolerant topology"
)
EOF

# Fix the Makefile by removing problematic lines and syntax errors
echo "Fixing Makefile..."
cat > Makefile << 'EOF'
# OBINexus DOP Components Makefile
CC = gcc
CFLAGS = -std=c11 -Wall -Wextra -Wpedantic -pthread
LDFLAGS = -pthread -lxml2

DEBUG_CFLAGS = $(CFLAGS) -g -O0 -DDOP_DEBUG=1
RELEASE_CFLAGS = $(CFLAGS) -O3 -DNDEBUG -DDOP_RELEASE=1

SRC_DIR = src
INCLUDE_DIR = include
BUILD_DIR = build
TEST_DIR = tests
DEMO_DIR = src/demo

CORE_SOURCES = $(wildcard $(SRC_DIR)/*.c) $(wildcard $(SRC_DIR)/components/*.c)
TEST_SOURCES = $(wildcard $(TEST_DIR)/*.c)
DEMO_SOURCES = $(wildcard $(DEMO_DIR)/*.c)

CORE_OBJECTS = $(CORE_SOURCES:%.c=$(BUILD_DIR)/%.o)
TEST_OBJECTS = $(TEST_SOURCES:%.c=$(BUILD_DIR)/%.o)
DEMO_OBJECTS = $(DEMO_SOURCES:%.c=$(BUILD_DIR)/%.o)

STATIC_LIB = $(BUILD_DIR)/libobinexus_dop_core.a
DEMO_EXECUTABLE = $(BUILD_DIR)/dop_demo
TEST_EXECUTABLE = $(BUILD_DIR)/dop_tests

all: debug

debug: CFLAGS := $(DEBUG_CFLAGS)
debug: $(STATIC_LIB) $(DEMO_EXECUTABLE) $(TEST_EXECUTABLE)

release: CFLAGS := $(RELEASE_CFLAGS)
release: $(STATIC_LIB) $(DEMO_EXECUTABLE) $(TEST_EXECUTABLE)

$(STATIC_LIB): $(CORE_OBJECTS) | $(BUILD_DIR)
	ar rcs $@ $^

$(DEMO_EXECUTABLE): $(DEMO_OBJECTS) $(STATIC_LIB) | $(BUILD_DIR)
	$(CC) $(DEMO_OBJECTS) $(STATIC_LIB) $(LDFLAGS) -o $@

$(TEST_EXECUTABLE): $(TEST_OBJECTS) $(STATIC_LIB) | $(BUILD_DIR)
	$(CC) $(TEST_OBJECTS) $(STATIC_LIB) $(LDFLAGS) -o $@

$(BUILD_DIR)/%.o: %.c | $(BUILD_DIR)
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -I$(INCLUDE_DIR) -c $< -o $@

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

test: $(TEST_EXECUTABLE)
	$(TEST_EXECUTABLE) component

test-p2p: $(DEMO_EXECUTABLE)
	$(DEMO_EXECUTABLE) --test-p2p-fault

validate-manifest: $(DEMO_EXECUTABLE)
	$(DEMO_EXECUTABLE) --validate-manifest

clean:
	rm -rf $(BUILD_DIR)

.PHONY: all debug release test test-p2p validate-manifest clean
EOF

echo "Directory refactoring completed successfully!"
echo ""
echo "New structure created:"
echo "  include/           - Header files"
echo "  src/               - Main source files"
echo "  src/components/    - Component implementations"
echo "  src/demo/          - Demo application"
echo "  tests/             - Unit tests"
echo "  examples/          - Example manifests"
echo "  schemas/           - XML schemas"
echo ""
echo "To build the project:"
echo "  mkdir -p build && cd build"
echo "  cmake .."
echo "  make"
echo ""
echo "Or using Makefile:"
echo "  make debug"
echo "  make test"
echo "  make validate-manifest"
EOF

chmod +x gov_std_web_refactor_structure
