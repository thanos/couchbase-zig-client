#!/usr/bin/env python3
"""
Simple Couchbase CRUD test script
Tests basic operations to verify Couchbase is working correctly
"""
import os
import sys
from datetime import datetime, timedelta

try:
    from couchbase.cluster import Cluster
    from couchbase.options import ClusterOptions, GetOptions, UpsertOptions
    from couchbase.auth import PasswordAuthenticator
except ImportError:
    print("ERROR: couchbase package not installed")
    print("Install with: pip install couchbase")
    sys.exit(1)

def main():
    # Get connection details from environment
    host = os.getenv("COUCHBASE_HOST", "127.0.0.1:11211")
    username = os.getenv("COUCHBASE_USER", "test")
    password = os.getenv("COUCHBASE_PASSWORD", "testtest")
    bucket_name = os.getenv("COUCHBASE_BUCKET", "default")
    
    # Build connection string
    # For Couchbase SDK, use the management port (8091) or just hostname
    # The SDK will discover the KV ports automatically
    if "://" in host:
        connection_string = host
    elif ":" in host:
        # If port is specified, extract just the hostname
        # SDK will use default ports
        hostname = host.split(":")[0]
        connection_string = f"couchbase://{hostname}"
    else:
        connection_string = f"couchbase://{host}"
    
    print(f"Connecting to Couchbase...")
    print(f"  Connection: {connection_string}")
    print(f"  Username: {username}")
    print(f"  Bucket: {bucket_name}")
    print()
    
    try:
        # Connect to cluster
        print(f"  Attempting connection to: {connection_string}")
        auth = PasswordAuthenticator(username, password)
        
        # Try with explicit timeout
        from couchbase.options import ClusterTimeoutOptions
        timeout_opts = ClusterTimeoutOptions(
            kv_timeout=timedelta(seconds=30),
            connect_timeout=timedelta(seconds=30)
        )
        cluster_opts = ClusterOptions(auth, timeout_options=timeout_opts)
        
        cluster = Cluster(connection_string, cluster_opts)
        bucket = cluster.bucket(bucket_name)
        collection = bucket.default_collection()
        
        # Wait for bucket to be ready (try different API versions)
        print("  Waiting for bucket to be ready...")
        try:
            bucket.wait_until_ready(30)
        except AttributeError:
            # Older SDK versions might not have wait_until_ready
            # Try to open the bucket explicitly
            try:
                bucket.on_connect()
            except:
                pass
        print("✓ Connected successfully!")
        print()
        
        test_key = "test_python_crud"
        passed = 0
        failed = 0
        
        # Test 1: Upsert
        print("1. Testing upsert... ", end="", flush=True)
        try:
            test_value = {"test": "upsert", "timestamp": datetime.now().isoformat()}
            result = collection.upsert(test_key, test_value)
            print(f"PASSED (CAS: {result.cas})")
            passed += 1
        except Exception as e:
            print(f"FAILED: {e}")
            failed += 1
        
        # Test 2: Get
        print("2. Testing get... ", end="", flush=True)
        try:
            result = collection.get(test_key)
            print(f"PASSED (Value: {result.content_as[dict]})")
            passed += 1
        except Exception as e:
            print(f"FAILED: {e}")
            failed += 1
        
        # Test 3: Replace
        print("3. Testing replace... ", end="", flush=True)
        try:
            new_value = {"test": "replace", "timestamp": datetime.now().isoformat()}
            result = collection.replace(test_key, new_value)
            print(f"PASSED (CAS: {result.cas})")
            passed += 1
        except Exception as e:
            print(f"FAILED: {e}")
            failed += 1
        
        # Test 4: Get after replace
        print("4. Testing get after replace... ", end="", flush=True)
        try:
            result = collection.get(test_key)
            value = result.content_as[dict]
            if value["test"] == "replace":
                print(f"PASSED (Value: {value})")
                passed += 1
            else:
                print(f"FAILED: Expected 'replace', got '{value.get('test')}'")
                failed += 1
        except Exception as e:
            print(f"FAILED: {e}")
            failed += 1
        
        # Test 5: Remove
        print("5. Testing remove... ", end="", flush=True)
        try:
            result = collection.remove(test_key)
            print(f"PASSED (CAS: {result.cas})")
            passed += 1
        except Exception as e:
            print(f"FAILED: {e}")
            failed += 1
        
        # Test 6: Get after remove (should fail)
        print("6. Testing get after remove (should fail)... ", end="", flush=True)
        try:
            result = collection.get(test_key)
            print(f"UNEXPECTED SUCCESS: Document still exists")
            failed += 1
        except Exception as e:
            if "not found" in str(e).lower() or "does not exist" in str(e).lower():
                print(f"PASSED (correctly failed with: {type(e).__name__})")
                passed += 1
            else:
                print(f"FAILED: Unexpected error: {e}")
                failed += 1
        
        # Test 7: Counter
        print("7. Testing counter (increment)... ", end="", flush=True)
        try:
            counter_key = "test_counter"
            result = collection.binary().increment(counter_key, initial=0, delta=10)
            print(f"PASSED (Value: {result.content}, CAS: {result.cas})")
            passed += 1
            # Cleanup
            try:
                collection.remove(counter_key)
            except:
                pass
        except Exception as e:
            print(f"FAILED: {e}")
            failed += 1
        
        # Test 8: Exists
        print("8. Testing exists... ", end="", flush=True)
        try:
            exists_key = "test_exists"
            collection.upsert(exists_key, {"test": "exists"})
            result = collection.exists(exists_key)
            if result.exists:
                print(f"PASSED (Exists: {result.exists})")
                passed += 1
            else:
                print(f"FAILED: Expected exists=True, got {result.exists}")
                failed += 1
            # Cleanup
            try:
                collection.remove(exists_key)
            except:
                pass
        except Exception as e:
            print(f"FAILED: {e}")
            failed += 1
        
        print()
        print("=== Results ===")
        print(f"Passed: {passed}")
        print(f"Failed: {failed}")
        print(f"Total: {passed + failed}")
        
        if failed == 0:
            print("\n✓ All tests passed!")
            return 0
        else:
            print(f"\n✗ {failed} test(s) failed")
            return 1
            
    except Exception as e:
        print(f"\n✗ Connection failed: {e}")
        print(f"  Type: {type(e).__name__}")
        import traceback
        traceback.print_exc()
        return 1

if __name__ == "__main__":
    sys.exit(main())
