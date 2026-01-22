#!/bin/bash
# Setup script to initialize a 3-node Couchbase cluster
# This script should be run after docker-compose up -d

set -e

COUCHBASE_USER="${COUCHBASE_USER:-admin}"
COUCHBASE_PASSWORD="${COUCHBASE_PASSWORD:-csfb2010}"
BUCKET_NAME="${COUCHBASE_BUCKET:-test}"

echo "Waiting for Couchbase nodes to be ready..."
# Wait for all nodes to be healthy
for i in {1..30}; do
    if docker exec couchbase-node1 curl -sf http://localhost:8091/ui/index.html > /dev/null 2>&1; then
        echo "Node 1 is ready"
        break
    fi
    echo "Waiting for node 1... ($i/30)"
    sleep 2
done

# Initialize first node
echo "Initializing first node (couchbase1)..."
docker exec couchbase-node1 couchbase-cli cluster-init \
  -c localhost:8091 \
  --cluster-username "$COUCHBASE_USER" \
  --cluster-password "$COUCHBASE_PASSWORD" \
  --services data,index,query \
  --cluster-ramsize 512 \
  --cluster-index-ramsize 256 \
  --cluster-fts-ramsize 256 \
  --index-storage-setting default || {
    echo "Cluster may already be initialized, continuing..."
}

# Wait for first node to be fully initialized
echo "Waiting for first node to be ready..."
sleep 15

# Wait for node 2 to be ready
for i in {1..30}; do
    if docker exec couchbase-node2 curl -sf http://localhost:8091/ui/index.html > /dev/null 2>&1; then
        echo "Node 2 is ready"
        break
    fi
    echo "Waiting for node 2... ($i/30)"
    sleep 2
done

# Add second node to cluster
echo "Adding second node (couchbase2) to cluster..."
docker exec couchbase-node1 couchbase-cli server-add \
  -c localhost:8091 \
  --username "$COUCHBASE_USER" \
  --password "$COUCHBASE_PASSWORD" \
  --server-add couchbase2:8091 \
  --server-add-username "$COUCHBASE_USER" \
  --server-add-password "$COUCHBASE_PASSWORD" \
  --services data,index,query || {
    echo "Node 2 may already be in cluster, checking status..."
    docker exec couchbase-node1 couchbase-cli server-list \
      -c localhost:8091 \
      --username "$COUCHBASE_USER" \
      --password "$COUCHBASE_PASSWORD"
}

# Rebalance to include second node
echo "Rebalancing cluster to include second node..."
docker exec couchbase-node1 couchbase-cli rebalance \
  -c localhost:8091 \
  --username "$COUCHBASE_USER" \
  --password "$COUCHBASE_PASSWORD" || {
    echo "Rebalance may already be in progress or complete"
}

# Wait for rebalance to complete
echo "Waiting for rebalance to complete..."
sleep 20

# Wait for node 3 to be ready
for i in {1..30}; do
    if docker exec couchbase-node3 curl -sf http://localhost:8091/ui/index.html > /dev/null 2>&1; then
        echo "Node 3 is ready"
        break
    fi
    echo "Waiting for node 3... ($i/30)"
    sleep 2
done

# Add third node to cluster
echo "Adding third node (couchbase3) to cluster..."
docker exec couchbase-node1 couchbase-cli server-add \
  -c localhost:8091 \
  --username "$COUCHBASE_USER" \
  --password "$COUCHBASE_PASSWORD" \
  --server-add couchbase3:8091 \
  --server-add-username "$COUCHBASE_USER" \
  --server-add-password "$COUCHBASE_PASSWORD" \
  --services data,index,query || {
    echo "Node 3 may already be in cluster, checking status..."
    docker exec couchbase-node1 couchbase-cli server-list \
      -c localhost:8091 \
      --username "$COUCHBASE_USER" \
      --password "$COUCHBASE_PASSWORD"
}

# Rebalance to include third node
echo "Rebalancing cluster to include third node..."
docker exec couchbase-node1 couchbase-cli rebalance \
  -c localhost:8091 \
  --username "$COUCHBASE_USER" \
  --password "$COUCHBASE_PASSWORD" || {
    echo "Rebalance may already be in progress or complete"
}

# Wait for rebalance to complete
echo "Waiting for final rebalance to complete..."
sleep 30

# Check if bucket already exists
BUCKET_EXISTS=$(docker exec couchbase-node1 couchbase-cli bucket-list \
  -c localhost:8091 \
  --username "$COUCHBASE_USER" \
  --password "$COUCHBASE_PASSWORD" 2>/dev/null | grep -c "$BUCKET_NAME" || echo "0")

if [ "$BUCKET_EXISTS" = "0" ]; then
    # Create bucket
    echo "Creating bucket '$BUCKET_NAME'..."
    docker exec couchbase-node1 couchbase-cli bucket-create \
      -c localhost:8091 \
      --username "$COUCHBASE_USER" \
      --password "$COUCHBASE_PASSWORD" \
      --bucket "$BUCKET_NAME" \
      --bucket-type couchbase \
      --bucket-ramsize 128 \
      --bucket-replica 2 \
      --enable-flush 1

    # Wait for bucket to be ready
    echo "Waiting for bucket to be ready..."
    sleep 15
else
    echo "Bucket '$BUCKET_NAME' already exists, skipping creation"
fi

# Create primary index (ignore errors if it already exists)
echo "Creating primary index on '$BUCKET_NAME'..."
docker exec couchbase-node1 cbq -u "$COUCHBASE_USER" -p "$COUCHBASE_PASSWORD" \
  -e "http://localhost:8093" \
  --script "CREATE PRIMARY INDEX ON \`$BUCKET_NAME\`;" 2>/dev/null || {
    echo "Primary index may already exist, continuing..."
}

echo ""
echo "=========================================="
echo "Cluster setup complete!"
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
echo "Or use single node (for non-durability tests):"
echo "  export COUCHBASE_HOST=\"couchbase://localhost:11210\""
echo ""
