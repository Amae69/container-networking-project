#!/usr/bin/env python3
# service-registry.py

from flask import Flask, jsonify, request
import json
import time

app = Flask(__name__)

# Service registry
services = {}

@app.route('/register', methods=['POST'])
def register_service():
    """Register a service"""
    data = request.json
    service_name = data['name']
    service_ip = data['ip']
    service_port = data['port']
    
    services[service_name] = {
        'ip': service_ip,
        'port': service_port,
        'registered_at': time.time(),
        'health': 'unknown'
    }
    
    # Store multiple instances if needed, but for now simple overwrite or append?
    # The prompt implies simple key-value for "simple DNS-like".
    # But later for LB we might need lists. 
    # However, standard simple registry usually overwrites or uses unique IDs.
    # The provided code uses `services[service_name] = ...`, which OVERWRITES.
    # For Load Balancing (Task 4.2), we need multiple instances.
    # But Task 4.1 prompt provides the code that overwrites! 
    # "services[service_name] = {...}"
    # So I will stick to that for 4.1.
    # For 4.2, the Load Balancer is in the *Gateway*, not the registry necessarily, or the registry needs to change.
    
    return jsonify({"status": "registered", "service": service_name})

@app.route('/discover/<service_name>', methods=['GET'])
def discover_service(service_name):
    """Discover a service"""
    if service_name in services:
        return jsonify(services[service_name])
    else:
        return jsonify({"error": "Service not found"}), 404

@app.route('/services', methods=['GET'])
def list_services():
    """List all services"""
    return jsonify(services)

@app.route('/deregister/<service_name>', methods=['DELETE'])
def deregister_service(service_name):
    """Deregister a service"""
    if service_name in services:
        del services[service_name]
        return jsonify({"status": "deregistered"})
    else:
        return jsonify({"error": "Service not found"}), 404

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8500)
