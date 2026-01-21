#!/usr/bin/env python3
"""
Simple Couchbase CRUD test using HTTP REST API
No external dependencies required (uses standard library only)
"""
import os
import sys
import json
import base64
import urllib.request
import urllib.error
from datetime import datetime

def make_request(url, method="GET", data=None, username=None, password=None):
    """Make an HTTP request to Couchbase REST API"""
    req = urllib.request.Request(url)
    req.get_method = lambda: method
    
    if data:
        req.add_header('Content-Type', 'application/json')
        req.data = json.dumps(data).encode('utf-8')
    
    if username and password:
        credentials = base64.b64encode(f"{username}:{password}".encode()).decode()
        req.add_header('Authorization', f'Basic {credentials}')
    
    try:
        with urllib.request.urlopen(req, timeout=10) as response:
            return response.read().decode('utf-8'), response.status
    except urllib.error.HTTPError as e:
        return e.read().decode('utf-8'), e.code
    except Exception as e:
        return str(e), 0

def main():
    # Get connection details from environment
    host = os.getenv("COUCHBASE_HOST", "127.0.0.1:11211")
    username = os.getenv("COUCHBASE_USER", "test")
    password = os.getenv("COUCHBASE_PASSWORD", "testtest")
    bucket_name = os.getenv("COUCHBASE_BUCKET", "default")
    
    # Extract hostname and port
    if ":" in host:
        hostname, port = host.split(":", 1)
    else:
        hostname = host
        port = "8091"  # Default REST port
    
    # Use REST API port (8091) for HTTP requests
    rest_port = "8091"
    base_url = f"http://{hostname}:{rest_port}"
    
    print(f"Testing Couchbase REST API...")
    print(f"  Host: {hostname}:{rest_port}")
    print(f"  Username: {username}")
    print(f"  Bucket: {bucket_name}")
    print()
    
    passed = 0
    failed = 0
    
    # Test 1: Cluster info (verify connection)
    print("1. Testing cluster connection... ", end="", flush=True)
    url = f"{base_url}/pools"
    response, status = make_request(url, username=username, password=password)
    if status == 200:
        print("PASSED")
        passed += 1
    else:
        print(f"FAILED (Status: {status})")
        print(f"  Response: {response[:200]}")
        failed += 1
    
    # Test 2: Bucket info
    print("2. Testing bucket access... ", end="", flush=True)
    url = f"{base_url}/pools/default/buckets/{bucket_name}"
    response, status = make_request(url, username=username, password=password)
    if status == 200:
        bucket_info = json.loads(response)
        print(f"PASSED (Bucket: {bucket_info.get('name', 'unknown')})")
        passed += 1
    else:
        print(f"FAILED (Status: {status})")
        print(f"  Response: {response[:200]}")
        failed += 1
    
    # Test 3: N1QL query (if available)
    print("3. Testing N1QL query... ", end="", flush=True)
    url = f"{base_url}/query/service"
    query_data = {
        "statement": "SELECT 1 as test",
        "timeout": "10s"
    }
    response, status = make_request(url, method="POST", data=query_data, username=username, password=password)
    if status == 200:
        result = json.loads(response)
        if result.get("status") == "success":
            print("PASSED")
            passed += 1
        else:
            print(f"FAILED (Query error: {result.get('errors', [])})")
            failed += 1
    else:
        print(f"FAILED (Status: {status})")
        print(f"  Response: {response[:200]}")
        failed += 1
    
    # Note: Direct KV operations via REST API are limited
    # For full CRUD testing, you need the SDK or N1QL
    
    print()
    print("=== Results ===")
    print(f"Passed: {passed}")
    print(f"Failed: {failed}")
    print(f"Total: {passed + failed}")
    print()
    print("Note: Full CRUD testing requires the Couchbase SDK.")
    print("Install with: pip install couchbase")
    print("Then run: python3 test_couchbase.py")
    
    if failed == 0:
        print("\n✓ All REST API tests passed!")
        return 0
    else:
        print(f"\n✗ {failed} test(s) failed")
        return 1

if __name__ == "__main__":
    sys.exit(main())
