
#include "dop_adapter.h"
#include <stdlib.h>
#include <string.h>

// Simple adapter implementations for demo purposes
dop_oop_interface_t* dop_adapter_func_to_oop(dop_func_create_t create_func,
                                              dop_func_update_t update_func,
                                              dop_func_destroy_t destroy_func,
                                              dop_func_serialize_t serialize_func) {
    // Simplified implementation for demo
    (void)create_func;
    (void)update_func;
    (void)destroy_func;
    (void)serialize_func;
    
    // Return NULL for now - full implementation would create OOP wrapper
    return NULL;
}

dop_func_create_t dop_adapter_oop_to_func_create(dop_oop_interface_t* oop_interface) {
    (void)oop_interface;
    return dop_func_create_component;
}

dop_func_update_t dop_adapter_oop_to_func_update(dop_oop_interface_t* oop_interface) {
    (void)oop_interface;
    return dop_func_update_component;
}

// ==========================================
// Create src/dop_topology.c file with this content:
// ==========================================

#include "dop_topology.h"
#include <stdlib.h>
#include <string.h>

// Topology Node Structure (simplified for demo)
typedef struct dop_topology_node {
    char node_id[64];
    dop_component_t* component;
    struct dop_topology_node* peers[4];
    uint32_t peer_count;
    bool is_fault_tolerant;
} dop_topology_node_t;

// Build Topology Structure (simplified for demo)
typedef struct {
    char build_id[64];
    dop_topology_node_t* nodes[16];
    uint32_t node_count;
    bool is_p2p_enabled;
    bool is_fault_tolerant;
} dop_build_topology_t;

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
        }
    }
    
    return DOP_SUCCESS;
}

int dop_topology_test_fault_tolerance(dop_build_topology_t* topology) {
    if (!topology) return DOP_ERROR_INVALID_PARAMETER;
    
    // Simulate fault tolerance test
    if (topology->node_count > 1) {
        dop_topology_node_t* test_node = topology->nodes[0];
        if (test_node && test_node->component) {
            dop_gate_close(test_node->component);
            // Re-enable the node
            dop_gate_open(test_node->component);
        }
    }
    
    return DOP_SUCCESS;
}
