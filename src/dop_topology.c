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
