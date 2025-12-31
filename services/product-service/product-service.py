from flask import Flask, jsonify
import redis
import json
import os

app = Flask(__name__)

# Connect to Redis cache
try:
    # Allow overriding Redis host via env var
    redis_host = os.environ.get('REDIS_HOST', '10.0.0.50')
    cache = redis.Redis(host=redis_host, port=6379, decode_responses=True)
except:
    cache = None

# Mock product database
PRODUCTS = {
    "1": {"id": "1", "name": "Laptop", "price": 999.99, "stock": 50},
    "2": {"id": "2", "name": "Mouse", "price": 29.99, "stock": 200},
    "3": {"id": "3", "name": "Keyboard", "price": 79.99, "stock": 150},
}

@app.route('/health')
def health():
    return jsonify({"status": "healthy", "service": "product-service"})

@app.route('/products', methods=['GET'])
def get_products():
    # Try cache first
    if cache:
        try:
            cached = cache.get('all_products')
            if cached:
                return jsonify(json.loads(cached))
        except:
            pass
    
    # Return products and cache
    products = list(PRODUCTS.values())
    if cache:
        try:
            cache.setex('all_products', 300, json.dumps(products))
        except:
            pass
    
    return jsonify(products)

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

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
