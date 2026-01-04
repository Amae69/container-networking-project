from flask import Flask, jsonify, request
import psycopg2
from datetime import datetime
import json
import requests
import time

import os
import socket

app = Flask(__name__)

# =========================
# SERVICE REGISTRY CONFIG
# =========================
SERVICE_REGISTRY = os.getenv("SERVICE_REGISTRY", "http://10.0.0.70:8500")
SERVICE_NAME = "order-service"
SERVICE_IP = os.getenv("SERVICE_IP", "10.0.0.40")
SERVICE_PORT = int(os.getenv("SERVICE_PORT", 5000))

# =========================
# STARTUP REGISTRATION
# =========================
def register_with_registry():
    payload = {
        "name": SERVICE_NAME,
        "ip": SERVICE_IP,
        "port": SERVICE_PORT
    }

    for attempt in range(5):
        try:
            r = requests.post(
                f"{SERVICE_REGISTRY}/register",
                json=payload,
                timeout=2
            )
            if r.status_code == 200:
                print(f"✅ Registered {SERVICE_NAME} with service registry")
                return
        except Exception as e:
            print(f"⏳ Registry not ready (attempt {attempt + 1}/5): {e}")
            time.sleep(2)

    print("❌ Failed to register order-service")

# =========================
# DATABASE CONNECTION
# =========================
def get_db():
    return psycopg2.connect(
        host=os.getenv('DB_HOST', '10.0.0.1'),
        database='orders',
        user='postgres',
        password='postgres'
    )

# =========================
# INITIALIZE DATABASE
# =========================
def init_db():
    conn = get_db()
    cur = conn.cursor()
    cur.execute('''
        CREATE TABLE IF NOT EXISTS orders (
            id SERIAL PRIMARY KEY,
            customer_id VARCHAR(100),
            product_id VARCHAR(100),
            quantity INTEGER,
            total_price DECIMAL(10, 2),
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ''')
    conn.commit()
    cur.close()
    conn.close()

# =========================
# HEALTH ENDPOINT
# =========================
@app.route('/health')
def health():
    return jsonify({"status": "healthy", "service": "order-service"})

# =========================
# ORDER ENDPOINTS
# =========================
@app.route('/orders', methods=['POST'])
def create_order():
    data = request.json
    
    conn = get_db()
    cur = conn.cursor()
    
    cur.execute(
        '''INSERT INTO orders (customer_id, product_id, quantity, total_price)
           VALUES (%s, %s, %s, %s) RETURNING id''',
        (data['customer_id'], data['product_id'], 
         data['quantity'], data['total_price'])
    )
    
    order_id = cur.fetchone()[0]
    conn.commit()
    cur.close()
    conn.close()
    
    return jsonify({"order_id": order_id, "status": "created"}), 201

@app.route('/orders/<order_id>', methods=['GET'])
def get_order(order_id):
    conn = get_db()
    cur = conn.cursor()
    
    cur.execute('SELECT * FROM orders WHERE id = %s', (order_id,))
    order = cur.fetchone()
    
    cur.close()
    conn.close()
    
    if not order:
        return jsonify({"error": "Order not found"}), 404
    
    return jsonify({
        "id": order[0],
        "customer_id": order[1],
        "product_id": order[2],
        "quantity": order[3],
        "total_price": float(order[4]),
        "created_at": order[5].isoformat()
    })

# =========================
# MAIN
# =========================
if __name__ == '__main__':
    init_db()
    register_with_registry()
    # Bind to 0.0.0.0 so health checks (on localhost) work inside the container
    app.run(host='0.0.0.0', port=SERVICE_PORT)