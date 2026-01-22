#!/bin/sh
# Cluster initialization script for sidecar container
# This script runs inside the init container and waits for all nodes to be ready

set -e

COUCHBASE_USER="${COUCHBASE_USER:-admin}"
COUCHBASE_PASSWORD="${COUCHBASE_PASSWORD:-csfb2010}"
BUCKET_NAME="${COUCHBASE_BUCKET:-test}"

# Helper function to wait for a node to be ready
wait_for_node() {
    local node=$1
    local max_attempts=60
    local attempt=1
    
    echo "Waiting for $node to be ready..."
    while [ $attempt -le $max_attempts ]; do
        if curl -sf "http://$node:8091/ui/index.html" > /dev/null 2>&1; then
            echo "$node is ready"
            return 0
        fi
        if [ $attempt -eq $max_attempts ]; then
            echo "Timeout waiting for $node after $max_attempts attempts"
            return 1
        fi
        echo "Waiting for $node... ($attempt/$max_attempts)"
        sleep 2
        attempt=$((attempt + 1))
    done
    return 1
}

# Helper function to check if cluster is initialized
is_cluster_initialized() {
    local response
    response=$(curl -s -u "$COUCHBASE_USER:$COUCHBASE_PASSWORD" "http://couchbase1:8091/pools/default" 2>/dev/null || echo "")
    if [ -n "$response" ] && echo "$response" | grep -q "clusterName"; then
        return 0
    fi
    return 1
}

# Helper function to check if node is in cluster
is_node_in_cluster() {
    local node=$1
    local response
    response=$(curl -s -u "$COUCHBASE_USER:$COUCHBASE_PASSWORD" "http://couchbase1:8091/pools/default" 2>/dev/null || echo "")
    if echo "$response" | grep -q "$node"; then
        return 0
    fi
    return 1
}

# Helper function to check if bucket exists
bucket_exists() {
    local bucket=$1
    if [ -z "$bucket" ]; then
        bucket="$BUCKET_NAME"
    fi
    local response
    response=$(curl -s -u "$COUCHBASE_USER:$COUCHBASE_PASSWORD" "http://couchbase1:8091/pools/default/buckets/$bucket" 2>/dev/null || echo "")
    if [ -n "$response" ] && echo "$response" | grep -q "\"name\""; then
        return 0
    fi
    return 1
}

# Helper function to install sample bucket
install_sample_bucket() {
    local bucket_name=$1
    echo "Installing sample bucket '$bucket_name'..."
    
    # Check if bucket already exists
    if bucket_exists "$bucket_name"; then
        echo "Sample bucket '$bucket_name' already exists, skipping installation"
        return 0
    fi
    
    # Install sample bucket via REST API
    local response
    response=$(curl -X POST "http://couchbase1:8091/sampleBuckets/install" \
      -u "$COUCHBASE_USER:$COUCHBASE_PASSWORD" \
      -H "Content-Type: application/json" \
      -d "[\"$bucket_name\"]" \
      -w "\n%{http_code}" \
      -s 2>&1)
    
    local http_code=$(echo "$response" | tail -n 1)
    local body=$(echo "$response" | sed '$d')
    
    if [ "$http_code" = "200" ] || [ "$http_code" = "202" ]; then
        echo "Sample bucket '$bucket_name' installation started (HTTP $http_code)"
        # Wait for bucket to be created and loaded
        echo "Waiting for sample bucket '$bucket_name' to be loaded..."
        local max_wait=300  # 5 minutes max wait
        local waited=0
        while [ $waited -lt $max_wait ]; do
            if bucket_exists "$bucket_name"; then
                echo "Sample bucket '$bucket_name' is ready"
                # Additional wait for data to be fully loaded
                sleep 10
                return 0
            fi
            sleep 5
            waited=$((waited + 5))
            if [ $((waited % 30)) -eq 0 ]; then
                echo "Still waiting for sample bucket '$bucket_name'... (${waited}s/${max_wait}s)"
            fi
        done
        echo "Warning: Sample bucket '$bucket_name' may not be fully loaded yet"
        return 0
    elif echo "$body" | grep -qi "already"; then
        echo "Sample bucket '$bucket_name' may already be installed (HTTP $http_code)"
        return 0
    else
        echo "Failed to install sample bucket '$bucket_name' (HTTP $http_code): $body"
        return 1
    fi
}

echo "=========================================="
echo "Couchbase Cluster Initialization"
echo "=========================================="
echo ""

# Wait for all nodes to be ready
wait_for_node "couchbase1" || exit 1
wait_for_node "couchbase2" || exit 1
wait_for_node "couchbase3" || exit 1

# Additional wait for nodes to be fully initialized
echo "Waiting for nodes to be fully initialized..."
sleep 15

# Initialize first node if not already initialized
if is_cluster_initialized; then
    echo "Cluster is already initialized"
else
    echo "Initializing first node (couchbase1)..."
    # Wait a bit more for Couchbase to be fully ready
    sleep 10
    
    # Use sequential REST API calls for cluster initialization (more reliable)
    # Step 1: Setup services
    echo "Setting up services..."
    curl -X POST "http://couchbase1:8091/node/controller/setupServices" \
      -H "Content-Type: application/x-www-form-urlencoded" \
      -d "services=kv%2Cn1ql%2Cindex" \
      -f -s > /dev/null || {
        echo "Failed to setup services"
        exit 1
    }
    
    # Step 2: Set memory quotas
    echo "Setting memory quotas..."
    curl -X POST "http://couchbase1:8091/pools/default" \
      -H "Content-Type: application/x-www-form-urlencoded" \
      -d "memoryQuota=512" \
      -d "indexMemoryQuota=256" \
      -d "ftsMemoryQuota=256" \
      -f -s > /dev/null || {
        echo "Failed to set memory quotas"
        exit 1
    }
    
    # Step 3: Setup admin credentials
    echo "Setting up admin credentials..."
    curl -X POST "http://couchbase1:8091/settings/web" \
      -H "Content-Type: application/x-www-form-urlencoded" \
      -d "username=$COUCHBASE_USER" \
      -d "password=$COUCHBASE_PASSWORD" \
      -d "port=8091" \
      -f -s > /dev/null || {
        echo "Failed to setup admin credentials"
        exit 1
    }
    
    echo "Cluster initialized successfully"
    
    # Wait for cluster to be fully ready
    echo "Waiting for cluster to be fully ready..."
    sleep 20
    
    # Verify cluster is initialized
    if ! is_cluster_initialized; then
        echo "Warning: Cluster initialization may not have completed"
        sleep 10
    fi
fi

# Add second node if not already in cluster
if is_node_in_cluster "couchbase2"; then
    echo "Node 2 (couchbase2) is already in cluster"
else
    echo "Adding second node (couchbase2) to cluster..."
    # Couchbase requires FQDN or IP address, not short hostname
    # Resolve IP address dynamically
    node2_ip=$(ping -c 1 couchbase2 2>/dev/null | grep -oP '(\d+\.){3}\d+' | head -1)
    if [ -z "$node2_ip" ]; then
        # Fallback: try to get from /etc/hosts or use hostname resolution
        node2_ip=$(getent hosts couchbase2 2>/dev/null | awk '{print $1}' | head -1)
    fi
    if [ -z "$node2_ip" ]; then
        echo "Warning: Could not resolve IP for couchbase2, using hostname with network"
        node2_host="couchbase2"
    else
        node2_host="$node2_ip"
        echo "Using IP address for node 2: $node2_host"
    fi
    
    response=$(curl -X POST "http://couchbase1:8091/controller/addNode" \
      -u "$COUCHBASE_USER:$COUCHBASE_PASSWORD" \
      -H "Content-Type: application/x-www-form-urlencoded" \
      -d "hostname=$node2_host" \
      -d "user=$COUCHBASE_USER" \
      -d "password=$COUCHBASE_PASSWORD" \
      -d "services=kv%2Cn1ql%2Cindex" \
      -w "\n%{http_code}" \
      -s 2>&1)
    
    http_code=$(echo "$response" | tail -n 1)
    body=$(echo "$response" | sed '$d')
    
    if [ "$http_code" = "200" ] || [ "$http_code" = "202" ]; then
        echo "Node 2 added successfully (HTTP $http_code)"
    elif echo "$body" | grep -q "already"; then
        echo "Node 2 may already be in cluster (HTTP $http_code)"
    else
        echo "Failed to add node 2 (HTTP $http_code): $body"
        # Continue anyway - might be a transient error
    fi
    
    sleep 5
    
    # Get list of nodes for rebalance
    echo "Getting node list for rebalance..."
    node_list=$(curl -s -u "$COUCHBASE_USER:$COUCHBASE_PASSWORD" "http://couchbase1:8091/pools/default" | grep -o '"otpNode":"[^"]*"' | sed 's/"otpNode":"//;s/"//' | tr '\n' ',' | sed 's/,$//' | sed 's/,/%2C/g')
    
    if [ -n "$node_list" ]; then
        echo "Rebalancing cluster with nodes: $node_list"
        curl -X POST "http://couchbase1:8091/controller/rebalance" \
          -u "$COUCHBASE_USER:$COUCHBASE_PASSWORD" \
          -H "Content-Type: application/x-www-form-urlencoded" \
          -d "knownNodes=$node_list" \
          -f -s > /dev/null || {
            echo "Rebalance may already be in progress or complete"
        }
    else
        echo "Could not determine node list for rebalance"
    fi
    
    echo "Waiting for rebalance to complete..."
    sleep 30
fi

# Add third node if not already in cluster
if is_node_in_cluster "couchbase3"; then
    echo "Node 3 (couchbase3) is already in cluster"
else
    echo "Adding third node (couchbase3) to cluster..."
    # Couchbase requires FQDN or IP address, not short hostname
    # Resolve IP address dynamically
    node3_ip=$(ping -c 1 couchbase3 2>/dev/null | grep -oP '(\d+\.){3}\d+' | head -1)
    if [ -z "$node3_ip" ]; then
        # Fallback: try to get from /etc/hosts or use hostname resolution
        node3_ip=$(getent hosts couchbase3 2>/dev/null | awk '{print $1}' | head -1)
    fi
    if [ -z "$node3_ip" ]; then
        echo "Warning: Could not resolve IP for couchbase3, using hostname with network"
        node3_host="couchbase3"
    else
        node3_host="$node3_ip"
        echo "Using IP address for node 3: $node3_host"
    fi
    
    response=$(curl -X POST "http://couchbase1:8091/controller/addNode" \
      -u "$COUCHBASE_USER:$COUCHBASE_PASSWORD" \
      -H "Content-Type: application/x-www-form-urlencoded" \
      -d "hostname=$node3_host" \
      -d "user=$COUCHBASE_USER" \
      -d "password=$COUCHBASE_PASSWORD" \
      -d "services=kv%2Cn1ql%2Cindex" \
      -w "\n%{http_code}" \
      -s 2>&1)
    
    http_code=$(echo "$response" | tail -n 1)
    body=$(echo "$response" | sed '$d')
    
    if [ "$http_code" = "200" ] || [ "$http_code" = "202" ]; then
        echo "Node 3 added successfully (HTTP $http_code)"
    elif echo "$body" | grep -q "already"; then
        echo "Node 3 may already be in cluster (HTTP $http_code)"
    else
        echo "Failed to add node 3 (HTTP $http_code): $body"
        # Continue anyway - might be a transient error
    fi
    
    sleep 5
    
    # Get list of nodes for rebalance
    echo "Getting node list for rebalance..."
    node_list=$(curl -s -u "$COUCHBASE_USER:$COUCHBASE_PASSWORD" "http://couchbase1:8091/pools/default" | grep -o '"otpNode":"[^"]*"' | sed 's/"otpNode":"//;s/"//' | tr '\n' ',' | sed 's/,$//' | sed 's/,/%2C/g')
    
    if [ -n "$node_list" ]; then
        echo "Rebalancing cluster with nodes: $node_list"
        curl -X POST "http://couchbase1:8091/controller/rebalance" \
          -u "$COUCHBASE_USER:$COUCHBASE_PASSWORD" \
          -H "Content-Type: application/x-www-form-urlencoded" \
          -d "knownNodes=$node_list" \
          -f -s > /dev/null || {
            echo "Rebalance may already be in progress or complete"
        }
    else
        echo "Could not determine node list for rebalance"
    fi
    
    echo "Waiting for final rebalance to complete..."
    sleep 30
fi

# Create bucket if it doesn't exist
if bucket_exists; then
    echo "Bucket '$BUCKET_NAME' already exists"
else
    echo "Creating bucket '$BUCKET_NAME'..."
    curl -X POST "http://couchbase1:8091/pools/default/buckets" \
      -u "$COUCHBASE_USER:$COUCHBASE_PASSWORD" \
      -H "Content-Type: application/x-www-form-urlencoded" \
      -d "name=$BUCKET_NAME" \
      -d "bucketType=couchbase" \
      -d "ramQuotaMB=128" \
      -d "replicaNumber=2" \
      -d "flushEnabled=1" \
      -f -s > /dev/null || {
        echo "Failed to create bucket"
        exit 1
    }
    echo "Waiting for bucket to be ready..."
    sleep 15
fi

# Create primary index (ignore errors if it already exists)
echo "Creating primary index on '$BUCKET_NAME'..."
curl -X POST "http://couchbase1:8093/query/service" \
  -u "$COUCHBASE_USER:$COUCHBASE_PASSWORD" \
  -H "Content-Type: application/json" \
  -d "{\"statement\":\"CREATE PRIMARY INDEX ON \`$BUCKET_NAME\`;\"}" \
  -f -s 2>/dev/null | grep -q "success" || {
    echo "Primary index may already exist or query service not ready"
}

# Install sample buckets for tests
echo ""
echo "Installing sample buckets for tests..."
echo "=========================================="

# Wait a bit more to ensure cluster is fully ready before installing samples
sleep 10

# Install travel-sample bucket
install_sample_bucket "travel-sample" || {
    echo "Warning: Failed to install travel-sample bucket, but continuing..."
}

# Install gamesim-sample bucket
install_sample_bucket "gamesim-sample" || {
    echo "Warning: Failed to install gamesim-sample bucket, but continuing..."
}

echo ""
echo "=========================================="
echo "Cluster initialization complete!"
echo "=========================================="
echo ""
echo "Cluster nodes:"
echo "  - Node 1: http://localhost:8091 (KV: localhost:11210)"
echo "  - Node 2: http://localhost:8097 (KV: localhost:11211)"
echo "  - Node 3: http://localhost:8103 (KV: localhost:11212)"
echo ""
echo "Connection string for tests:"
echo "  export COUCHBASE_HOST=\"couchbase://localhost:11210,localhost:11211,localhost:11212\""
echo "  export COUCHBASE_USER=\"$COUCHBASE_USER\""
echo "  export COUCHBASE_PASSWORD=\"$COUCHBASE_PASSWORD\""
echo "  export COUCHBASE_BUCKET=\"$BUCKET_NAME\""
echo ""
