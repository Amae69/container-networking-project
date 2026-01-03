from flask import Flask, jsonify
import redis
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
SERVICE_NAME = "product-service"
SERVICE_IP = os.getenv("SERVICE_IP", "10.0.0.30")
SERVICE_PORT = int(os.getenv("SERVICE_PORT", 5000))
INSTANCE_ID = os.getenv("INSTANCE_ID", socket.gethostname())

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

    print("❌ Failed to register product-service")

# =========================
# REDIS CONNECTION
# =========================
try:
    redis_host = os.getenv('REDIS_HOST', '10.0.0.50')
    cache = redis.Redis(host=redis_host, port=6379, decode_responses=True)
except:
    cache = None

# =========================
# MOCK PRODUCT DATABASE
# =========================
PRODUCTS = {
    "1": {"id": "1", "name": "Laptop", "price": 999.99, "stock": 50},
    "2": {"id": "2", "name": "Mouse", "price": 29.99, "stock": 200},
    "3": {"id": "3", "name": "Keyboard", "price": 79.99, "stock": 150},
}

# =========================
# HEALTH ENDPOINT
# =========================
@app.route('/health')
def health():
    return jsonify({
        "status": "healthy",
        "service": "product-service",
        "instance": INSTANCE_ID,
        "ip": SERVICE_IP,
        "port": SERVICE_PORT
    })
# =========================
# PRODUCT ENDPOINTS
# =========================
@app.errorhandler(Exception)
def handle_exception(e):
    return jsonify({"error": str(e), "type": type(e).__name__}), 500

@app.route('/products', methods=['GET'])
def get_products():
    try:
        #if cache:
        #    cached = cache.get('all_products')
        #    if cached:
        #        return jsonify(json.loads(cached))

        products = list(PRODUCTS.values())
        #if cache:
        #    cache.setex('all_products', 300, json.dumps(products))

        return jsonify({
            "instance": INSTANCE_ID,
            "products": products
        })
    except Exception as e:
        return jsonify({"error": str(e), "trace": "get_products failed"}), 500

@app.route('/products/<product_id>', methods=['GET'])
def get_product(product_id):
    # Try cache first
    if cache:
        try:
            cached = cache.get(f'product_{product_id}')
            if cached:
                return jsonify(json.loads(cached))
        except:
            pass
    
    product = PRODUCTS.get(product_id)
    if not product:
        return jsonify({"error": "Product not found"}), 404
    
    if cache:
        try:
            cache.setex(f'product_{product_id}', 300, json.dumps(product))
        except:
            pass
    
    return jsonify(product)

# =========================
# MAIN
# =========================
if __name__ == '__main__':
    register_with_registry()
    app.run(host=SERVICE_IP, port=SERVICE_PORT)